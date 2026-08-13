import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/child_exception_request.dart';
import '../domain/family_authorization.dart';
import '../domain/guardian_models.dart';
import 'policy_repository.dart';

class ChildExceptionRequestRepository {
  ChildExceptionRequestRepository(this._database, this._policyRepository,
      {Uuid? uuid, DateTime Function()? clock, FamilyAuthorization? authorization})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now,
        _authorization = authorization ?? const FamilyAuthorization();

  final GuardianDatabase _database;
  final PolicyRepository _policyRepository;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final FamilyAuthorization _authorization;
  final _machine = const ChildExceptionRequestStateMachine();

  Future<ChildExceptionRequest> create(
      {required String familyId,
      required String childDeviceId,
      required String childUid,
      required String target,
      required Duration duration,
      required ChildExceptionReason reason,
      String? reasonDetail,
      String? policyId,
      Duration requestWindow = const Duration(hours: 24)}) async {
    _machine.validateCreate(
        target: target,
        childUid: childUid,
        duration: duration,
        reason: reason,
        detail: reasonDetail);
    final now = _clock().toUtc();
    final db = await _database.database;
    return db.transaction((tx) async {
      final device = await _activeChildDevice(tx, familyId, childDeviceId);
      final duplicate = await tx.query('child_exception_requests',
          columns: ['id'],
          where: "child_device_id = ? AND target = ? AND status = 'pending'",
          whereArgs: [childDeviceId, target.trim()],
          limit: 1);
      if (duplicate.isNotEmpty) {
        throw StateError('duplicate_pending_exception_request');
      }
      final request = ChildExceptionRequest(
          id: _uuid.v4(),
          familyId: familyId,
          childDeviceId: childDeviceId,
          childMemberId: device['member_id']! as String,
          childUid: childUid.trim(),
          target: target.trim(),
          policyId: policyId,
          requestedDuration: duration,
          reason: reason,
          reasonDetail: reasonDetail?.trim(),
          createdAt: now,
          requestExpiresAt: now.add(requestWindow),
          status: ChildExceptionRequestStatus.pending,
          syncState: SyncState.queued);
      await tx.insert('child_exception_requests', _toMap(request));
      await _enqueue(tx, request, 'child.exception.requested');
      return request;
    });
  }

  Future<ChildExceptionRequest> approve(
      {required String requestId,
      required String parentMemberId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _clock().toUtc();
      final request = await _requiredRequest(tx, requestId);
      await _expireRequestIfDue(tx, request, now);
      final current = await _requiredRequest(tx, requestId);
      _machine.requireTransition(
          current.status, ChildExceptionRequestStatus.approved);
      await _requireParent(tx, current.familyId, parentMemberId);
      await _activeChildDevice(tx, current.familyId, current.childDeviceId);
      final overrideId = _uuid.v4();
      final expiry = now.add(current.requestedDuration);
      await _policyRepository.createOverrideInTransaction(tx,
          id: overrideId,
          familyId: current.familyId,
          createdByMemberId: parentMemberId,
          target: current.target,
          allowed: true,
          expiresAt: expiry,
          createdAt: now,
          childDeviceId: current.childDeviceId);
      final approved = _copy(current,
          status: ChildExceptionRequestStatus.approved,
          reviewedByMemberId: parentMemberId,
          reviewedAt: now,
          overrideId: overrideId,
          expiresAt: expiry,
          syncState: SyncState.queued);
      await tx.update('child_exception_requests', _reviewMap(approved),
          where: 'id = ?', whereArgs: [requestId]);
      await _enqueue(tx, approved, 'child.exception.approved');
      return approved;
    });
  }

  Future<ChildExceptionRequest> deny(
      {required String requestId, required String parentMemberId}) async =>
      _review(requestId, parentMemberId, ChildExceptionRequestStatus.denied);

  Future<ChildExceptionRequest> cancel(
      {required String requestId, required String childUid}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _clock().toUtc();
      final request = await _requiredRequest(tx, requestId);
      await _expireRequestIfDue(tx, request, now);
      final current = await _requiredRequest(tx, requestId);
      _machine.requireTransition(
          current.status, ChildExceptionRequestStatus.cancelled);
      if (current.childUid != childUid.trim()) {
        throw StateError('exception_request_child_not_authorized');
      }
      final cancelled = _copy(current,
          status: ChildExceptionRequestStatus.cancelled,
          reviewedAt: now,
          syncState: SyncState.queued);
      await tx.update('child_exception_requests', _reviewMap(cancelled),
          where: 'id = ?', whereArgs: [requestId]);
      await _enqueue(tx, cancelled, 'child.exception.cancelled');
      return cancelled;
    });
  }

  Future<List<ChildExceptionRequest>> forFamily(String familyId) async {
    await expireDue(familyId: familyId);
    final db = await _database.database;
    final rows = await db.query('child_exception_requests',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC');
    return Future.wait(rows.map((row) async => _fromMap(row,
        syncState: await _syncStateFor(row['id']! as String))));
  }

  Future<List<ChildExceptionRequest>> forChild(
      {required String familyId,
      required String childDeviceId,
      required String childUid}) async {
    await expireDue(familyId: familyId);
    final db = await _database.database;
    final rows = await db.query('child_exception_requests',
        where: 'family_id = ? AND child_device_id = ? AND child_uid = ?',
        whereArgs: [familyId, childDeviceId, childUid.trim()],
        orderBy: 'created_at DESC');
    return Future.wait(rows.map((row) async => _fromMap(row,
        syncState: await _syncStateFor(row['id']! as String))));
  }

  Future<int> expireDue({required String familyId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _clock().toUtc();
      final rows = await tx.query('child_exception_requests',
          where: 'family_id = ? AND status IN (?, ?)',
          whereArgs: [
            familyId,
            ChildExceptionRequestStatus.pending.name,
            ChildExceptionRequestStatus.approved.name
          ]);
      var changed = 0;
      for (final row in rows) {
        final request = _fromMap(row);
        if (request.isExpiredAt(now)) {
          await _expireRequestIfDue(tx, request, now);
          changed++;
        }
      }
      return changed;
    });
  }

  Future<ChildExceptionRequest> _review(String requestId,
      String parentMemberId, ChildExceptionRequestStatus status) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _clock().toUtc();
      final request = await _requiredRequest(tx, requestId);
      await _expireRequestIfDue(tx, request, now);
      final current = await _requiredRequest(tx, requestId);
      _machine.requireTransition(current.status, status);
      await _requireParent(tx, current.familyId, parentMemberId);
      final reviewed = _copy(current,
          status: status,
          reviewedByMemberId: parentMemberId,
          reviewedAt: now,
          syncState: SyncState.queued);
      await tx.update('child_exception_requests', _reviewMap(reviewed),
          where: 'id = ?', whereArgs: [requestId]);
      await _enqueue(tx, reviewed, 'child.exception.denied');
      return reviewed;
    });
  }

  Future<void> _expireRequestIfDue(Transaction tx,
      ChildExceptionRequest request, DateTime now) async {
    if (!request.isExpiredAt(now)) return;
    _machine.requireTransition(request.status, ChildExceptionRequestStatus.expired);
    final expired = _copy(request,
        status: ChildExceptionRequestStatus.expired,
        reviewedAt: request.reviewedAt ?? now,
        syncState: SyncState.queued);
    await tx.update('child_exception_requests', _reviewMap(expired),
        where: 'id = ?', whereArgs: [request.id]);
  }

  Future<Map<String, Object?>> _activeChildDevice(
      Transaction tx, String familyId, String deviceId) async {
    final rows = await tx.query('devices',
        where: 'id = ? AND family_id = ? AND role = ? AND revoked_at IS NULL',
        whereArgs: [deviceId, familyId, DeviceRole.childDevice.name],
        limit: 1);
    if (rows.isEmpty) throw StateError('exception_request_child_device_invalid');
    final states = await tx.query('child_device_states',
        where: 'device_id = ?', whereArgs: [deviceId], limit: 1);
    if (states.isEmpty ||
        states.single['lifecycle'] == ChildDeviceLifecycle.revoked.name) {
      throw StateError('exception_request_child_device_revoked');
    }
    return rows.single;
  }

  Future<void> _requireParent(
      Transaction tx, String familyId, String memberId) async {
    final rows = await tx.query('family_members',
        where: 'id = ? AND family_id = ?', whereArgs: [memberId, familyId],
        limit: 1);
    if (rows.isEmpty) throw StateError('exception_request_parent_not_authorized');
    try {
      _authorization.require(
          FamilyMember.fromMap(rows.single), FamilyPermission.reviewExceptionRequests);
    } on StateError {
      throw StateError('exception_request_parent_not_authorized');
    }
  }

  Future<ChildExceptionRequest> _requiredRequest(
      Transaction tx, String requestId) async {
    final rows = await tx.query('child_exception_requests',
        where: 'id = ?', whereArgs: [requestId], limit: 1);
    if (rows.isEmpty) throw StateError('exception_request_not_found');
    return _fromMap(rows.single);
  }

  ChildExceptionRequest _fromMap(Map<String, Object?> row,
      {SyncState syncState = SyncState.localOnly}) {
    return ChildExceptionRequest(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        childDeviceId: row['child_device_id']! as String,
        childMemberId: row['child_member_id']! as String,
        childUid: row['child_uid']! as String,
        target: row['target']! as String,
        policyId: row['policy_id'] as String?,
        requestedDuration:
            Duration(minutes: row['requested_duration_minutes']! as int),
        reason: ChildExceptionReason.values.byName(row['reason']! as String),
        reasonDetail: row['reason_detail'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
        requestExpiresAt: DateTime.parse(row['request_expires_at']! as String),
        status: ChildExceptionRequestStatus.values
            .byName(row['status']! as String),
        reviewedByMemberId: row['reviewed_by_member_id'] as String?,
        reviewedAt: row['reviewed_at'] == null
            ? null
            : DateTime.parse(row['reviewed_at']! as String),
        overrideId: row['override_id'] as String?,
        expiresAt: row['expires_at'] == null
            ? null
            : DateTime.parse(row['expires_at']! as String),
        syncState: syncState);
  }

  ChildExceptionRequest _copy(ChildExceptionRequest source,
          {ChildExceptionRequestStatus? status,
          String? reviewedByMemberId,
          DateTime? reviewedAt,
          String? overrideId,
          DateTime? expiresAt,
          SyncState? syncState}) =>
      ChildExceptionRequest(
          id: source.id,
          familyId: source.familyId,
          childDeviceId: source.childDeviceId,
          childMemberId: source.childMemberId,
          childUid: source.childUid,
          target: source.target,
          policyId: source.policyId,
          requestedDuration: source.requestedDuration,
          reason: source.reason,
          reasonDetail: source.reasonDetail,
          createdAt: source.createdAt,
          requestExpiresAt: source.requestExpiresAt,
          status: status ?? source.status,
          reviewedByMemberId: reviewedByMemberId ?? source.reviewedByMemberId,
          reviewedAt: reviewedAt ?? source.reviewedAt,
          overrideId: overrideId ?? source.overrideId,
          expiresAt: expiresAt ?? source.expiresAt,
          syncState: syncState ?? source.syncState);

  Map<String, Object?> _toMap(ChildExceptionRequest request) => {
        'id': request.id,
        'family_id': request.familyId,
        'child_device_id': request.childDeviceId,
        'child_member_id': request.childMemberId,
        'child_uid': request.childUid,
        'target': request.target,
        'policy_id': request.policyId,
        'requested_duration_minutes': request.requestedDuration.inMinutes,
        'reason': request.reason.name,
        'reason_detail': request.reasonDetail,
        'status': request.status.name,
        'created_at': request.createdAt.toIso8601String(),
        'request_expires_at': request.requestExpiresAt.toIso8601String(),
        'reviewed_by_member_id': request.reviewedByMemberId,
        'reviewed_at': request.reviewedAt?.toIso8601String(),
        'override_id': request.overrideId,
        'expires_at': request.expiresAt?.toIso8601String()
      };

  Map<String, Object?> _reviewMap(ChildExceptionRequest request) => {
        'status': request.status.name,
        'reviewed_by_member_id': request.reviewedByMemberId,
        'reviewed_at': request.reviewedAt?.toIso8601String(),
        'override_id': request.overrideId,
        'expires_at': request.expiresAt?.toIso8601String()
      };

  Future<SyncState> _syncStateFor(String requestId) async {
    final db = await _database.database;
    final rows = await db.query('outbox',
        columns: ['state'],
        where: 'aggregate_type = ? AND aggregate_id = ?',
        whereArgs: ['childExceptionRequest', requestId],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return SyncState.localOnly;
    return switch (rows.single['state'] as String) {
      'queued' || 'syncing' => SyncState.queued,
      'synced' => SyncState.synced,
      'blocked' => SyncState.blocked,
      'failed' => SyncState.failed,
      _ => SyncState.localOnly
    };
  }

  Future<void> _enqueue(Transaction tx, ChildExceptionRequest request,
      String operation) async {
    final now = _clock().toUtc();
    final eventId = _uuid.v4();
    await tx.insert('outbox', {
      'id': eventId,
      'aggregate_type': 'childExceptionRequest',
      'aggregate_id': request.id,
      'operation': operation,
      'payload_json': jsonEncode({
        'familyId': request.familyId,
        'requestId': request.id,
        'childDeviceId': request.childDeviceId,
        'childMemberId': request.childMemberId,
        'childUid': request.childUid,
        'target': request.target,
        'policyId': request.policyId,
        'requestedDurationMinutes': request.requestedDuration.inMinutes,
        'reason': request.reason.name,
        'reasonDetail': request.reasonDetail,
        'createdAt': request.createdAt.toIso8601String(),
        'requestExpiresAt': request.requestExpiresAt.toIso8601String(),
        'status': request.status.name,
        'reviewedByMemberId': request.reviewedByMemberId,
        'reviewedAt': request.reviewedAt?.toIso8601String(),
        'overrideId': request.overrideId,
        'expiresAt': request.expiresAt?.toIso8601String()
      }),
      'idempotency_key': eventId,
      'state': SyncState.queued.name,
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String()
    });
  }
}
