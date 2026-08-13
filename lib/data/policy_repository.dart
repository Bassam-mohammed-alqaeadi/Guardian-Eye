import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import '../domain/policy_engine.dart';

class PolicyRepository {
  PolicyRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;

  Future<DigitalPolicy> save(
      {required String familyId,
      required String name,
      required int priority,
      required bool enabled,
      required int startMinute,
      required int endMinute,
      required Set<String> restrictedTargets,
      int? dailyLimitMinutes}) async {
    if (name.trim().isEmpty ||
        priority < 0 ||
        startMinute < 0 ||
        startMinute >= 1440 ||
        endMinute < 0 ||
        endMinute >= 1440) {
      throw ArgumentError('Invalid policy values.');
    }
    final policy = DigitalPolicy(
        id: _uuid.v4(),
        familyId: familyId,
        name: name.trim(),
        priority: priority,
        enabled: enabled,
        startMinute: startMinute,
        endMinute: endMinute,
        restrictedTargets: restrictedTargets,
        dailyLimitMinutes: dailyLimitMinutes,
        syncState: SyncState.queued);
    _validatePolicy(policy);
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('policies', {
        'id': policy.id,
        'family_id': familyId,
        'name': policy.name,
        'priority': priority,
        'enabled': enabled ? 1 : 0,
        'schedule_json':
            jsonEncode({'startMinute': startMinute, 'endMinute': endMinute}),
        'rules_json':
            jsonEncode({
              'restrictedTargets': restrictedTargets.toList(),
              'dailyLimitMinutes': dailyLimitMinutes
            }),
        'version': 1,
        'updated_at': now.toIso8601String()
      });
      await _enqueue(
          tx, 'policy', policy.id, 'policy.created', _policyPayload(policy));
    });
    return policy;
  }

  Future<List<DigitalPolicy>> forFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db
        .query('policies', where: 'family_id = ?', whereArgs: [familyId]);
    return Future.wait(rows.map((row) async {
      final schedule =
          jsonDecode(row['schedule_json'] as String) as Map<String, dynamic>;
      final rules =
          jsonDecode(row['rules_json'] as String) as Map<String, dynamic>;
      final policyId = row['id'] as String;
      return DigitalPolicy(
          id: policyId,
          familyId: row['family_id'] as String,
          name: row['name'] as String,
          priority: row['priority'] as int,
          enabled: (row['enabled'] as int) == 1,
          startMinute: schedule['startMinute'] as int,
          endMinute: schedule['endMinute'] as int,
          restrictedTargets:
              Set<String>.from(rules['restrictedTargets'] as List),
          dailyLimitMinutes: rules['dailyLimitMinutes'] as int?,
          version: row['version'] as int,
          syncState: await _syncStateFor('policy', policyId));
    }));
  }

  Future<DigitalPolicy> update({
    required DigitalPolicy existing,
    required String name,
    required int priority,
    required bool enabled,
      required int startMinute,
      required int endMinute,
      required Set<String> restrictedTargets,
      int? dailyLimitMinutes,
  }) async {
    final policy = DigitalPolicy(
        id: existing.id,
        familyId: existing.familyId,
        name: name.trim(),
        priority: priority,
        enabled: enabled,
        startMinute: startMinute,
        endMinute: endMinute,
        restrictedTargets: restrictedTargets,
        dailyLimitMinutes: dailyLimitMinutes,
        version: existing.version + 1,
        syncState: SyncState.queued);
    _validatePolicy(policy);
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      final changed = await tx.update(
          'policies',
          {
            'name': policy.name,
            'priority': policy.priority,
            'enabled': policy.enabled ? 1 : 0,
            'schedule_json': jsonEncode({
              'startMinute': policy.startMinute,
              'endMinute': policy.endMinute
            }),
            'rules_json': jsonEncode({
              'restrictedTargets': policy.restrictedTargets.toList(),
              'dailyLimitMinutes': policy.dailyLimitMinutes
            }),
            'version': policy.version,
            'updated_at': now.toIso8601String()
          },
          where: 'id = ? AND family_id = ?',
          whereArgs: [policy.id, policy.familyId]);
      if (changed != 1) throw StateError('policy_not_found');
      await _enqueue(
          tx, 'policy', policy.id, 'policy.updated', _policyPayload(policy));
    });
    return policy;
  }

  Future<DigitalPolicy> setEnabled(
          {required DigitalPolicy existing, required bool enabled}) =>
      update(
          existing: existing,
          name: existing.name,
          priority: existing.priority,
          enabled: enabled,
          startMinute: existing.startMinute,
          endMinute: existing.endMinute,
          restrictedTargets: existing.restrictedTargets,
          dailyLimitMinutes: existing.dailyLimitMinutes);

  Future<StoredPolicyOverride> createOverride(
      {required String familyId,
      required String createdByMemberId,
      required String target,
      required bool allowed,
      required DateTime expiresAt,
      String? childDeviceId}) async {
    if (target.trim().isEmpty || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw ArgumentError(
          'Override must target an item and expire in the future.');
    }
    final id = _uuid.v4();
    final db = await _database.database;
    final now = DateTime.now().toUtc();
    await db.transaction((tx) async {
      await createOverrideInTransaction(tx,
          id: id,
          familyId: familyId,
          createdByMemberId: createdByMemberId,
          target: target,
          allowed: allowed,
          expiresAt: expiresAt,
          createdAt: now,
          childDeviceId: childDeviceId);
    });
    return StoredPolicyOverride(
        id: id,
        familyId: familyId,
        target: target.trim(),
        allowed: allowed,
        expiresAt: expiresAt.toUtc(),
        createdByMemberId: createdByMemberId,
        createdAt: now,
        childDeviceId: childDeviceId,
        syncState: SyncState.queued);
  }

  Future<StoredPolicyOverride> createOverrideInTransaction(Transaction tx,
      {required String id,
      required String familyId,
      required String createdByMemberId,
      required String target,
      required bool allowed,
      required DateTime expiresAt,
      required DateTime createdAt,
      String? childDeviceId}) async {
    if (target.trim().isEmpty || !expiresAt.isAfter(createdAt.toUtc())) {
      throw ArgumentError('Override must target an item and expire in the future.');
    }
    final override = StoredPolicyOverride(
        id: id,
        familyId: familyId,
        target: target.trim(),
        allowed: allowed,
        expiresAt: expiresAt.toUtc(),
        createdByMemberId: createdByMemberId,
        childDeviceId: childDeviceId,
        createdAt: createdAt.toUtc(),
        syncState: SyncState.queued);
    await tx.insert('policy_overrides', {
      'id': id,
      'family_id': familyId,
      'target': override.target,
      'allowed': allowed ? 1 : 0,
      'expires_at': override.expiresAt.toIso8601String(),
      'created_by_member_id': createdByMemberId,
      'child_device_id': childDeviceId,
      'created_at': createdAt.toUtc().toIso8601String()
    });
    await _enqueue(tx, 'policyOverride', id, 'policy.override.created', {
      'familyId': familyId,
      'overrideId': id,
      'target': override.target,
        'allowed': override.allowed,
        'childDeviceId': childDeviceId,
      'expiresAt': override.expiresAt.toIso8601String(),
      'createdByMemberId': createdByMemberId
    });
    return override;
  }

  Future<List<StoredPolicyOverride>> overridesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('policy_overrides',
        where: 'family_id = ? AND revoked_at IS NULL',
        whereArgs: [familyId],
        orderBy: 'expires_at ASC');
    return Future.wait(rows.map((row) async {
      final id = row['id'] as String;
      return StoredPolicyOverride(
          id: id,
          familyId: row['family_id'] as String,
          target: row['target'] as String,
          allowed: (row['allowed'] as int) == 1,
          expiresAt: DateTime.parse(row['expires_at'] as String),
          createdByMemberId: row['created_by_member_id'] as String,
          childDeviceId: row['child_device_id'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          syncState: await _syncStateFor('policyOverride', id));
    }));
  }

  Future<String> primaryParentMemberId(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('family_members',
        columns: ['id'],
        where: 'family_id = ? AND role = ?',
        whereArgs: [familyId, 'primaryParent'],
        limit: 1);
    if (rows.isEmpty) throw StateError('primary_parent_not_found');
    return rows.single['id'] as String;
  }

  void _validatePolicy(DigitalPolicy policy) {
    if (policy.familyId.isEmpty ||
        policy.name.isEmpty ||
        policy.priority < 0 ||
        policy.startMinute < 0 ||
        policy.startMinute >= 1440 ||
        policy.endMinute < 0 ||
        policy.endMinute >= 1440 ||
        policy.restrictedTargets.isEmpty ||
        policy.restrictedTargets.any((target) => target.trim().isEmpty) ||
        (policy.dailyLimitMinutes != null &&
            (policy.dailyLimitMinutes! <= 0 ||
                policy.dailyLimitMinutes! > 1440))) {
      throw ArgumentError('Invalid policy values.');
    }
  }

  Map<String, Object?> _policyPayload(DigitalPolicy policy) => {
        'familyId': policy.familyId,
        'policyId': policy.id,
        'name': policy.name,
        'priority': policy.priority,
        'enabled': policy.enabled,
        'startMinute': policy.startMinute,
        'endMinute': policy.endMinute,
        'restrictedTargets': policy.restrictedTargets.toList(),
        'dailyLimitMinutes': policy.dailyLimitMinutes,
        'version': policy.version
      };

  Future<SyncState> _syncStateFor(
      String aggregateType, String aggregateId) async {
    final db = await _database.database;
    final rows = await db.query('outbox',
        columns: ['state'],
        where: 'aggregate_type = ? AND aggregate_id = ?',
        whereArgs: [aggregateType, aggregateId],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return SyncState.localOnly;
    final state = rows.single['state'] as String;
    return switch (state) {
      'queued' || 'syncing' => SyncState.queued,
      'synced' => SyncState.synced,
      'blocked' => SyncState.blocked,
      'failed' => SyncState.failed,
      _ => SyncState.localOnly
    };
  }

  Future<void> _enqueue(Transaction tx, String type, String aggregateId,
      String operation, Map<String, Object?> payload) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await tx.insert('outbox', {
      'id': id,
      'aggregate_type': type,
      'aggregate_id': aggregateId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'idempotency_key': id,
      'state': SyncState.queued.storageKey,
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String()
    });
  }
}
