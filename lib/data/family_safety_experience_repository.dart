import 'dart:convert';

import '../core/database/guardian_database.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/child_exception_request.dart';
import '../domain/family_safety_experience.dart';
import '../domain/guardian_models.dart';
import '../domain/screen_time.dart';
import 'child_exception_request_repository.dart';
import 'policy_repository.dart';

class FamilySafetyExperienceRepository {
  FamilySafetyExperienceRepository(this._database, this._policies, this._requests,
      {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final GuardianDatabase _database;
  final PolicyRepository _policies;
  final ChildExceptionRequestRepository _requests;
  final DateTime Function() _clock;

  Future<List<ChildDailySafetySnapshot>> childrenForFamily(String familyId) async {
    final db = await _database.database;
    final now = _clock().toUtc();
    final dayStart = _dayStart(now);
    final childrenRows = await db.query('family_members',
        where: 'family_id = ? AND role = ?',
        whereArgs: [familyId, FamilyRole.child.name]);
    final policies = await _policies.forFamily(familyId);
    final overrides = (await _policies.overridesForFamily(familyId))
        .where((item) => item.isActiveAt(now))
        .toList(growable: false);
    final requests = await _requests.forFamily(familyId);
    final stateRows = await db.query('child_device_states',
        where: 'family_id = ?', whereArgs: [familyId]);
    final states = {
      for (final row in stateRows) row['device_id']! as String: ChildDeviceState.fromMap(row)
    };
    final deviceRows = await db.query('devices',
        where: 'family_id = ? AND role = ?',
        whereArgs: [familyId, DeviceRole.childDevice.name]);
    final usageRows = await db.query('child_usage_summaries',
        where: 'family_id = ? AND day_start = ?',
        whereArgs: [familyId, dayStart.toIso8601String()]);
    final queuedRows = await db.query('outbox',
        columns: ['payload_json', 'state'],
        where: "state IN ('queued', 'syncing', 'failed', 'blocked')");
    final queueByDevice = <String, int>{};
    for (final row in queuedRows) {
      final payload = jsonDecode(row['payload_json']! as String);
      if (payload is Map && payload['familyId'] == familyId && payload['deviceId'] is String) {
        final id = payload['deviceId'] as String;
        queueByDevice[id] = (queueByDevice[id] ?? 0) + 1;
      }
    }
    return childrenRows.map((childRow) {
      final child = FamilyMember.fromMap(childRow);
      final devices = deviceRows
          .where((device) => device['member_id'] == child.id)
          .map((device) {
        final deviceId = device['id']! as String;
        final usage = usageRows
            .where((row) => row['device_id'] == deviceId)
            .map(_usageFromMap)
            .toList(growable: false);
        final pending = requests
            .where((request) =>
                request.childDeviceId == deviceId &&
                request.status == ChildExceptionRequestStatus.pending)
            .toList(growable: false);
        return ChildDeviceDailySafety(
            deviceId: deviceId,
            state: states[deviceId],
            usage: usage,
            pendingRequests: pending);
      }).toList(growable: false);
      final childDeviceIds = devices.map((device) => device.deviceId).toSet();
      return ChildDailySafetySnapshot(
          child: child,
          devices: devices,
          policies: policies,
          activeOverrides: overrides,
          pendingRequests: requests
              .where((request) =>
                  childDeviceIds.contains(request.childDeviceId) &&
                  request.status == ChildExceptionRequestStatus.pending)
              .toList(growable: false),
          queuedOperations: childDeviceIds.fold<int>(
              0, (count, id) => count + (queueByDevice[id] ?? 0)));
    }).toList(growable: false);
  }

  Future<List<SafetyTimelineEvent>> timelineForFamily(String familyId,
      {int limit = 80}) async {
    final db = await _database.database;
    final events = <SafetyTimelineEvent>[];
    final outbox = await db.query('outbox',
        orderBy: 'created_at DESC', limit: limit * 3);
    for (final row in outbox) {
      final payload = jsonDecode(row['payload_json']! as String);
      if (payload is! Map || payload['familyId'] != familyId) continue;
      final operation = row['operation']! as String;
      final created = DateTime.parse(row['created_at']! as String);
      events.add(SafetyTimelineEvent(
          id: row['id']! as String,
          familyId: familyId,
          kind: _timelineKind(operation),
          occurredAt: created,
          titleKey: _timelineTitle(operation),
          detail: payload['target'] as String? ?? payload['policyId'] as String?,
          syncState: _syncState(row['state']! as String)));
    }
    events.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return events.take(limit).toList(growable: false);
  }

  DateTime _dayStart(DateTime moment) {
    final local = moment.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  DailyUsageSummary _usageFromMap(Map<String, Object?> map) => DailyUsageSummary(
      deviceId: map['device_id']! as String,
      familyId: map['family_id']! as String,
      target: map['target']! as String,
      dayStart: DateTime.parse(map['day_start']! as String),
      totalMilliseconds: map['total_milliseconds']! as int,
      capturedAt: DateTime.parse(map['captured_at']! as String),
      lastUsedAt: map['last_used_at'] == null
          ? null
          : DateTime.parse(map['last_used_at']! as String));

  SafetyTimelineKind _timelineKind(String operation) => switch (operation) {
        'policy.created' => SafetyTimelineKind.policyCreated,
        'policy.updated' => SafetyTimelineKind.policyUpdated,
        'child.policy.delivered' => SafetyTimelineKind.policyDelivered,
        'child.usage.observed' => SafetyTimelineKind.usageMeasured,
        'child.exception.requested' => SafetyTimelineKind.exceptionRequested,
        'child.exception.approved' => SafetyTimelineKind.exceptionApproved,
        'child.exception.denied' => SafetyTimelineKind.exceptionDenied,
        'child.exception.cancelled' => SafetyTimelineKind.exceptionCancelled,
        'device.revoked' || 'child.device.state.updated' => SafetyTimelineKind.deviceChanged,
        _ => SafetyTimelineKind.other
      };

  String _timelineTitle(String operation) => switch (operation) {
        'policy.created' => 'timelinePolicyCreated',
        'policy.updated' => 'timelinePolicyUpdated',
        'child.policy.delivered' => 'timelinePolicyDelivered',
        'child.usage.observed' => 'timelineUsageMeasured',
        'child.exception.requested' => 'timelineRequestCreated',
        'child.exception.approved' => 'timelineRequestApproved',
        'child.exception.denied' => 'timelineRequestDenied',
        'child.exception.cancelled' => 'timelineRequestCancelled',
        'device.revoked' => 'timelineDeviceRevoked',
        'child.device.state.updated' => 'timelineDeviceChanged',
        _ => 'timelineOther'
      };

  SyncState _syncState(String value) => switch (value) {
        'queued' || 'syncing' => SyncState.queued,
        'synced' => SyncState.synced,
        'blocked' => SyncState.blocked,
        'failed' => SyncState.failed,
        _ => SyncState.localOnly
      };
}
