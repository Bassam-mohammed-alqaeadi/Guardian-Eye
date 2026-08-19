import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/guardian_models.dart';
import '../domain/policy_engine.dart';
import '../domain/screen_time.dart';

enum ChildPolicyDeliveryResult { applied, ignoredOlder, idempotent }

class ChildDeviceRepository {
  ChildDeviceRepository(this._database,
      {Uuid? uuid, DateTime Function()? clock})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final GuardianDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final _machine = const ChildDeviceStateMachine();

  Future<ChildDeviceState> initializeForEnrolledDevice(String deviceId) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final existing = await tx.query('child_device_states',
          where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
      if (existing.isNotEmpty) return ChildDeviceState.fromMap(existing.single);
      final device = await _childDevice(tx, deviceId);
      final now = _clock().toUtc();
      final state = ChildDeviceState(
          deviceId: deviceId,
          familyId: device['family_id']! as String,
          memberId: device['member_id']! as String,
          lifecycle: device['revoked_at'] == null
              ? ChildDeviceLifecycle.enrolled
              : ChildDeviceLifecycle.revoked,
          requiredPolicyVersion: 0,
          updatedAt: now);
      await _writeState(tx, state);
      await _enqueue(tx,
          aggregateId: deviceId,
          operation: 'child.device.state.updated',
          payload: _statePayload(state));
      return state;
    });
  }

  Future<ChildDeviceState?> getState(String deviceId) async {
    final db = await _database.database;
    final rows = await db.query('child_device_states',
        where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
    return rows.isEmpty ? null : ChildDeviceState.fromMap(rows.single);
  }

  Future<List<ChildDeviceState>> statesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('child_device_states',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'updated_at DESC');
    return rows.map(ChildDeviceState.fromMap).toList();
  }

  Future<ChildDeviceState> transition(
      {required String deviceId,
      required ChildDeviceLifecycle to,
      String? failureCode}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      final next = _machine.transition(state, to,
          at: _clock().toUtc(), failureCode: failureCode);
      await _writeState(tx, next);
      if (next.lifecycle != state.lifecycle) {
        await _enqueue(tx,
            aggregateId: deviceId,
            operation: 'child.device.state.updated',
            payload: _statePayload(next));
      }
      return next;
    });
  }

  Future<ChildPolicyDeliveryResult> deliverPolicy(
      {required String deviceId,
      required DigitalPolicy policy,
      required int knownMinimumVersion}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      if (state.lifecycle == ChildDeviceLifecycle.revoked) {
        throw StateError('child_device_revoked');
      }
      if (policy.familyId != state.familyId || policy.version <= 0) {
        throw ArgumentError('policy_scope_or_version_invalid');
      }
      final existing = await tx.query('child_device_policies',
          where: 'device_id = ? AND policy_id = ?',
          whereArgs: [deviceId, policy.id],
          limit: 1);
      if (existing.isNotEmpty) {
        final existingVersion = existing.single['version']! as int;
        if (existingVersion > policy.version) {
          return ChildPolicyDeliveryResult.ignoredOlder;
        }
        if (existingVersion == policy.version) {
          final payload = existing.single['payload_json']! as String;
          if (payload != jsonEncode(_policyPayload(policy))) {
            throw StateError('equal_policy_version_payload_conflict');
          }
          return ChildPolicyDeliveryResult.idempotent;
        }
      }
      final now = _clock().toUtc();
      await tx.insert(
          'child_device_policies',
          {
            'device_id': deviceId,
            'policy_id': policy.id,
            'family_id': policy.familyId,
            'version': policy.version,
            'payload_json': jsonEncode(_policyPayload(policy)),
            'delivered_at': now.toIso8601String()
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final nextLifecycle = state.lifecycle == ChildDeviceLifecycle.enrolled ||
              state.lifecycle == ChildDeviceLifecycle.recovering ||
              state.lifecycle == ChildDeviceLifecycle.offline
          ? ChildDeviceLifecycle.active
          : state.lifecycle;
      final next = ChildDeviceState(
          deviceId: state.deviceId,
          familyId: state.familyId,
          memberId: state.memberId,
          lifecycle: nextLifecycle,
          requiredPolicyVersion:
              knownMinimumVersion > state.requiredPolicyVersion
                  ? knownMinimumVersion
                  : state.requiredPolicyVersion,
          updatedAt: now,
          lastValidPolicyAt: now,
          lastEvaluationAt: state.lastEvaluationAt,
          lastDecision: state.lastDecision,
          lastSyncAt: state.lastSyncAt,
          failureCode: null);
      await _writeState(tx, next);
      await _enqueue(tx,
          aggregateId: deviceId,
          operation: 'child.policy.delivered',
          payload: {
            ..._statePayload(next),
            'policyId': policy.id,
            'policyVersion': policy.version,
            'knownMinimumVersion': knownMinimumVersion
          });
      return ChildPolicyDeliveryResult.applied;
    });
  }

  Future<List<DeliveredChildPolicy>> deliveredPolicies(String deviceId) async {
    final db = await _database.database;
    final rows = await db.query('child_device_policies',
        where: 'device_id = ?', whereArgs: [deviceId]);
    return rows.map((row) {
      final payload =
          jsonDecode(row['payload_json']! as String) as Map<String, dynamic>;
      return DeliveredChildPolicy(
          deviceId: deviceId,
          deliveredAt: DateTime.parse(row['delivered_at']! as String),
          policy: DigitalPolicy(
              id: row['policy_id']! as String,
              familyId: row['family_id']! as String,
              name: payload['name']! as String,
              priority: payload['priority']! as int,
              enabled: payload['enabled']! as bool,
              startMinute: payload['startMinute']! as int,
              endMinute: payload['endMinute']! as int,
              restrictedTargets:
                  Set<String>.from(payload['restrictedTargets']! as List),
              dailyLimitMinutes: payload['dailyLimitMinutes'] as int?,
              version: row['version']! as int));
    }).toList();
  }

  Future<ChildDeviceState> recordEvaluation(
      {required String deviceId, required EnforcementDecision decision}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      final lifecycle = switch (decision.outcome) {
        EnforcementOutcome.deviceRevoked => ChildDeviceLifecycle.revoked,
        EnforcementOutcome.restrict => ChildDeviceLifecycle.restricted,
        EnforcementOutcome.allow ||
        EnforcementOutcome.temporaryAllow =>
          state.lifecycle == ChildDeviceLifecycle.restricted
              ? ChildDeviceLifecycle.active
              : state.lifecycle,
        _ => state.lifecycle,
      };
      final next = ChildDeviceState(
          deviceId: state.deviceId,
          familyId: state.familyId,
          memberId: state.memberId,
          lifecycle: lifecycle,
          requiredPolicyVersion: state.requiredPolicyVersion,
          updatedAt: _clock().toUtc(),
          lastValidPolicyAt: state.lastValidPolicyAt,
          lastEvaluationAt: decision.evaluatedAt,
          lastDecision: decision.outcome,
          lastSyncAt: state.lastSyncAt,
          failureCode: decision.outcome == EnforcementOutcome.policyStale
              ? decision.reason
              : null);
      await _writeState(tx, next);
      await tx.insert('child_enforcement_evaluations', {
        'id': _uuid.v4(),
        'device_id': deviceId,
        'family_id': state.familyId,
        'outcome': decision.outcome.name,
        'reason': decision.reason,
        'policy_id': decision.policyId,
        'policy_version': decision.policyVersion,
        'evaluated_at': decision.evaluatedAt.toUtc().toIso8601String()
      });
      return next;
    });
  }

  Future<DailyUsageSummary> upsertUsageSummary(
      {required String deviceId,
      required String target,
      required int cumulativeMilliseconds,
      required DateTime observedAt,
      DateTime? lastUsedAt,
      String source = 'android_usage_stats'}) async {
    if (target.trim().isEmpty || cumulativeMilliseconds < 0) {
      throw ArgumentError('usage_summary_invalid');
    }
    final db = await _database.database;
    return db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      if (state.lifecycle == ChildDeviceLifecycle.revoked) {
        throw StateError('child_device_revoked');
      }
      final day = _localDayStart(observedAt);
      final rows = await tx.query('child_usage_summaries',
          where: 'device_id = ? AND day_start = ? AND target = ?',
          whereArgs: [deviceId, day.toIso8601String(), target.trim()],
          limit: 1);
      final previous =
          rows.isEmpty ? 0 : rows.single['total_milliseconds'] as int;
      final total = cumulativeMilliseconds < previous
          ? previous
          : cumulativeMilliseconds;
      final now = _clock().toUtc();
      await tx.insert(
          'child_usage_summaries',
          {
            'device_id': deviceId,
            'family_id': state.familyId,
            'day_start': day.toIso8601String(),
            'target': target.trim(),
            'total_milliseconds': total,
            'last_used_at': lastUsedAt?.toUtc().toIso8601String(),
            'captured_at': now.toIso8601String()
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final observationId = _uuid.v4();
      await tx.insert('child_usage_observations', {
        'id': observationId,
        'device_id': deviceId,
        'family_id': state.familyId,
        'target': target.trim(),
        'total_milliseconds': total,
        'observed_at': observedAt.toUtc().toIso8601String(),
        'source': source,
        'captured_at': now.toIso8601String()
      });
      final summary = DailyUsageSummary(
          deviceId: deviceId,
          familyId: state.familyId,
          target: target.trim(),
          dayStart: day,
          totalMilliseconds: total,
          capturedAt: now,
          lastUsedAt: lastUsedAt?.toUtc());
      await _enqueue(tx,
          aggregateId: deviceId,
          operation: 'child.usage.observed',
          payload: _usagePayload(summary, observationId));
      return summary;
    });
  }

  Future<DailyUsageSummary?> usageForTarget(
      {required String deviceId,
      required String target,
      required DateTime day}) async {
    final db = await _database.database;
    final dayStart = _localDayStart(day);
    final rows = await db.query('child_usage_summaries',
        where: 'device_id = ? AND day_start = ? AND target = ?',
        whereArgs: [deviceId, dayStart.toIso8601String(), target],
        limit: 1);
    return rows.isEmpty ? null : _summaryFromMap(rows.single);
  }

  Future<List<DailyUsageSummary>> usageForDeviceDay(
      {required String deviceId, required DateTime day}) async {
    final db = await _database.database;
    final dayStart = _localDayStart(day);
    final rows = await db.query('child_usage_summaries',
        where: 'device_id = ? AND day_start = ?',
        whereArgs: [deviceId, dayStart.toIso8601String()],
        orderBy: 'total_milliseconds DESC');
    return rows.map(_summaryFromMap).toList();
  }

  /// FS-003 — Application Control. Latest daily usage summary per target
  /// across every child device in the family, collapsed per target so the
  /// parent app-protection dashboard can rank the family's most-used apps
  /// without re-aggregating. Honest and local: derived only from synced
  /// usage summaries written by the child devices themselves.
  Future<List<DailyUsageSummary>> summariesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT cs.* FROM child_usage_summaries cs '
        'INNER JOIN (SELECT family_id, target, MAX(captured_at) AS latest '
        'FROM child_usage_summaries WHERE family_id = ? '
        'GROUP BY target) latest ON latest.family_id = cs.family_id '
        'AND latest.target = cs.target AND latest.latest = cs.captured_at '
        'ORDER BY cs.total_milliseconds DESC',
        [familyId]);
    return rows.map(_summaryFromMap).toList();
  }

  /// Honest sync evidence for the device's usage observations. Returns the
  /// outbox rows that are still queued, failed, syncing, or blocked — the only
  /// evidence the measurement UI may use to claim that a usage observation is
  /// pending synchronization or has a recorded failure. Never interprets
  /// absence as failure.
  Future<List<Map<String, Object?>>> pendingUsageSyncRowsForDevice(
      {required String deviceId}) async {
    final db = await _database.database;
    return db.rawQuery(
        "SELECT state, last_error FROM outbox WHERE aggregate_type = 'childDevice' "
        "AND aggregate_id = ? AND operation = 'child.usage.observed' "
        "AND state IN ('queued', 'failed', 'syncing', 'blocked') "
        "ORDER BY created_at DESC",
        [deviceId]);
  }

  Future<void> recordScreenTimeEvaluation(
      {required String deviceId,
      required ScreenTimeEvaluation evaluation,
      required DateTime evaluatedAt}) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      await tx.insert('child_usage_evaluations', {
        'id': _uuid.v4(),
        'device_id': deviceId,
        'family_id': state.familyId,
        'target': evaluation.target,
        'status': evaluation.status.name,
        'reason': evaluation.reason,
        'used_milliseconds': evaluation.used.inMilliseconds,
        'limit_milliseconds': evaluation.limit?.inMilliseconds,
        'policy_id': evaluation.policyId,
        'policy_version': evaluation.policyVersion,
        'evaluated_at': evaluatedAt.toUtc().toIso8601String()
      });
    });
  }

  /// M8 durable enforcement state. Written inside a transaction together
  /// with the local lifecycle state so offline enforcement always has a
  /// single consistent truth on the device.
  Future<void> recordEnforcementState(EnforcementStateRecord record) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final lifecycleState = await _requiredState(tx, record.deviceId); // ensures offline-safe lifecycle row exists
      await tx.insert('child_enforcement_states',
          record.toRow()
            ..['id'] = _uuid.v4()
            ..['family_id'] = lifecycleState.familyId);
    });
  }

  /// Most recent enforcement record for the device (offline-safe read).
  Future<EnforcementStateRecord?> activeEnforcementState(
      String deviceId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        "SELECT * FROM child_enforcement_states WHERE device_id = ? "
        "ORDER BY decided_at DESC LIMIT 1",
        [deviceId]);
    if (rows.isEmpty) return null;
    return EnforcementStateRecord.fromRow(rows.single);
  }


  Future<EnforcementStateRecord?> _activeEnforcementStateTx(
      Transaction tx, String deviceId) async {
    final rows = await tx.rawQuery(
        "SELECT * FROM child_enforcement_states WHERE device_id = ? "
        "ORDER BY decided_at DESC LIMIT 1",
        [deviceId]);
    if (rows.isEmpty) return null;
    return EnforcementStateRecord.fromRow(rows.single);
  }

  /// Enqueues the enforcement state for remote delivery through the
  /// existing outbox (path /devices/{deviceId}/enforcement_status).
  Future<void> queueEnforcementSync(String deviceId) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final state = await _requiredState(tx, deviceId);
      final record = await _activeEnforcementStateTx(tx, deviceId);
      await _enqueue(tx,
          aggregateId: deviceId,
          operation: 'child.enforcement.applied',
          payload: {
            'familyId': state.familyId,
            'deviceId': deviceId,
            'state': record?.state.name,
            'outcome': record?.outcome?.name,
            'reason': record?.reason,
            'decidedAt': record?.decidedAt.toIso8601String(),
            'appliedAt': record?.appliedAt?.toIso8601String(),
            'policyVersion': record?.policyVersion
          });
    });
  }

  /// Outbox rows proving (or disproving) that the latest enforcement
  /// record reached the parent backend. Mirrors the M7 usage pattern.
  Future<List<Map<String, Object?>>> pendingEnforcementSyncRowsForDevice(
      {required String deviceId}) async {
    final db = await _database.database;
    return db.rawQuery(
        "SELECT state, last_error FROM outbox WHERE aggregate_type = 'childDevice' "
        "AND aggregate_id = ? AND operation = 'child.enforcement.applied' "
        "AND state IN ('queued', 'failed', 'syncing', 'blocked') "
        "ORDER BY created_at DESC",
        [deviceId]);
  }

  Future<Map<String, Object?>> _childDevice(
      Transaction tx, String deviceId) async {
    final rows = await tx.query('devices',
        where: 'id = ? AND role = ?',
        whereArgs: [deviceId, DeviceRole.childDevice.name],
        limit: 1);
    if (rows.isEmpty) throw StateError('child_device_not_enrolled');
    return rows.single;
  }

  Future<ChildDeviceState> _requiredState(
      Transaction tx, String deviceId) async {
    final rows = await tx.query('child_device_states',
        where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
    if (rows.isEmpty) throw StateError('child_device_state_missing');
    return ChildDeviceState.fromMap(rows.single);
  }

  Future<void> _writeState(Transaction tx, ChildDeviceState state) => tx.insert(
      'child_device_states',
      {
        'device_id': state.deviceId,
        'family_id': state.familyId,
        'member_id': state.memberId,
        'lifecycle': state.lifecycle.name,
        'required_policy_version': state.requiredPolicyVersion,
        'last_valid_policy_at': state.lastValidPolicyAt?.toIso8601String(),
        'last_evaluation_at': state.lastEvaluationAt?.toIso8601String(),
        'last_decision': state.lastDecision?.name,
        'last_sync_at': state.lastSyncAt?.toIso8601String(),
        'failure_code': state.failureCode,
        'updated_at': state.updatedAt.toIso8601String()
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _enqueue(Transaction tx,
      {required String aggregateId,
      required String operation,
      required Map<String, Object?> payload}) async {
    final now = _clock().toUtc();
    final id = _uuid.v4();
    await tx.insert('outbox', {
      'id': id,
      'aggregate_type': 'childDevice',
      'aggregate_id': aggregateId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'idempotency_key': id,
      'state': SyncState.queued.name,
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String()
    });
  }

  Map<String, Object?> _statePayload(ChildDeviceState state) => {
        'familyId': state.familyId,
        'deviceId': state.deviceId,
        'memberId': state.memberId,
        'lifecycle': state.lifecycle.name,
        'requiredPolicyVersion': state.requiredPolicyVersion,
        'lastValidPolicyAt': state.lastValidPolicyAt?.toIso8601String(),
        'lastDecision': state.lastDecision?.name,
        'updatedAt': state.updatedAt.toIso8601String()
      };

  Map<String, Object?> _policyPayload(DigitalPolicy policy) => {
        'name': policy.name,
        'priority': policy.priority,
        'enabled': policy.enabled,
        'startMinute': policy.startMinute,
        'endMinute': policy.endMinute,
        'restrictedTargets': policy.restrictedTargets.toList()..sort(),
        'dailyLimitMinutes': policy.dailyLimitMinutes
      };

  DateTime _localDayStart(DateTime moment) {
    final local = moment.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  DailyUsageSummary _summaryFromMap(Map<String, Object?> map) =>
      DailyUsageSummary(
          deviceId: map['device_id']! as String,
          familyId: map['family_id']! as String,
          target: map['target']! as String,
          dayStart: DateTime.parse(map['day_start']! as String),
          totalMilliseconds: map['total_milliseconds']! as int,
          capturedAt: DateTime.parse(map['captured_at']! as String),
          lastUsedAt: map['last_used_at'] == null
              ? null
              : DateTime.parse(map['last_used_at']! as String));

  Map<String, Object?> _usagePayload(
          DailyUsageSummary summary, String observationId) =>
      {
        'familyId': summary.familyId,
        'deviceId': summary.deviceId,
        'usageId': observationId,
        'dayStart': summary.dayStart.toIso8601String(),
        'target': summary.target,
        'totalMilliseconds': summary.totalMilliseconds,
        'lastUsedAt': summary.lastUsedAt?.toIso8601String(),
        'capturedAt': summary.capturedAt.toIso8601String()
      };
}
