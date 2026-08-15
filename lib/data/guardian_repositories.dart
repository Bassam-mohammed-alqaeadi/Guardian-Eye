import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';

class FamilyRepository {
  FamilyRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;

  Future<GuardianFamily> createFamily(
      {required String familyName, required String parentName}) async {
    final name = familyName.trim();
    final parent = parentName.trim();
    if (name.isEmpty || parent.isEmpty) {
      throw ArgumentError('Family and parent names are required.');
    }
    final family = GuardianFamily(
        id: _uuid.v4(), name: name, createdAt: DateTime.now().toUtc());
    final parentId = _uuid.v4();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('families', {
        'id': family.id,
        'name': family.name,
        'created_at': family.createdAt.toIso8601String()
      });
      await tx.insert('family_members', {
        'id': parentId,
        'family_id': family.id,
        'display_name': parent,
        'role': FamilyRole.primaryParent.storageKey,
        'created_at': family.createdAt.toIso8601String()
      });
      await _enqueue(tx,
          aggregateType: 'family',
          aggregateId: family.id,
          operation: 'family.created',
          payload: {
            'familyId': family.id,
            'name': family.name,
            'createdAt': family.createdAt.toIso8601String(),
            'primaryParentId': parentId,
            'primaryParentName': parent
          });
    });
    return family;
  }

  Future<FamilyMember> addChild(
      {required String familyId, required String childName}) async {
    final name = childName.trim();
    if (name.isEmpty) throw ArgumentError('Child name is required.');
    final child = FamilyMember(
        id: _uuid.v4(),
        familyId: familyId,
        displayName: name,
        role: FamilyRole.child,
        createdAt: DateTime.now().toUtc());
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('family_members', {
        'id': child.id,
        'family_id': familyId,
        'display_name': name,
        'role': child.role.storageKey,
        'created_at': child.createdAt.toIso8601String()
      });
      // M5 Option D: a child is local-only until trusted device provisioning.
      // No remote-syncable `member.created` operation is enqueued here — the
      // UID-keyed remote member document is created by the trusted backend
      // inside redeemChildDeviceProvisioning. This removes the previously
      // doomed members/{localUuid} remote write that the deployed rules reject.
    });
    return child;
  }

  Future<GuardianDashboard> loadDashboard() async {
    final db = await _database.database;
    final rows =
        await db.query('families', where: 'archived_at IS NULL', limit: 1);
    if (rows.isEmpty) {
      return const GuardianDashboard(
          family: null, children: [], incidentsToday: 0, queuedOperations: 0);
    }
    final family = GuardianFamily.fromMap(rows.first);
    final children = await db.query('family_members',
        where: 'family_id = ? AND role = ?',
        whereArgs: [family.id, FamilyRole.child.storageKey]);
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day).toIso8601String();
    final incidents = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM incidents WHERE family_id=? AND observed_at>=?',
            [family.id, start])) ??
        0;
    final queued = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM outbox WHERE state IN ('queued','failed','blocked')")) ??
        0;
    return GuardianDashboard(
        family: family,
        children: children.map(FamilyMember.fromMap).toList(),
        incidentsToday: incidents,
        queuedOperations: queued);
  }

  Future<void> _enqueue(Transaction tx,
      {required String aggregateType,
      required String aggregateId,
      required String operation,
      required Map<String, Object?> payload}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await tx.insert('outbox', {
      'id': id,
      'aggregate_type': aggregateType,
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

class PairingRepository {
  PairingRepository(this._database, {Uuid? uuid, Random? random})
      : _uuid = uuid ?? const Uuid(),
        _random = random ?? Random.secure();
  final GuardianDatabase _database;
  final Uuid _uuid;
  final Random _random;
  Future<PairingRequest> createParentAuthorizedRequest(
      {required String familyId,
      required DeviceRole requestedRole,
      String? targetMemberId}) async {
    final code = _random.nextInt(1000000).toString().padLeft(6, '0');
    final request = PairingRequest(
        id: _uuid.v4(),
        code: code,
        targetMemberId: targetMemberId,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
    final db = await _database.database;
    await db.insert('pairing_sessions', {
      'id': request.id,
      'family_id': familyId,
      'target_member_id': targetMemberId,
      'code_hash': hashPairingCode(code),
      'requested_role': requestedRole.storageKey,
      'status': PairingState.pending.storageKey,
      'expires_at': request.expiresAt.toIso8601String(),
      'created_at': DateTime.now().toUtc().toIso8601String()
    });
    return request;
  }

  static String hashPairingCode(String rawCode) =>
      sha256.convert(utf8.encode(rawCode)).toString();

  Future<PairingEnrollmentResult> verifyAndEnroll(
      {required String requestId,
      required String code,
      required String memberId,
      required String ownerMemberId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('pairing_sessions',
          where: 'id = ?', whereArgs: [requestId], limit: 1);
      if (rows.isEmpty) {
        return const PairingEnrollmentResult(
            state: PairingState.rejected, reason: 'request_not_found');
      }
      final session = rows.single;
      final state = PairingState.values.byName(session['status'] as String);
      final now = DateTime.now().toUtc();
      if (state == PairingState.revoked || session['revoked_at'] != null) {
        return const PairingEnrollmentResult(
            state: PairingState.revoked, reason: 'request_revoked');
      }
      if (DateTime.parse(session['expires_at'] as String).isBefore(now)) {
        await tx.update(
            'pairing_sessions', {'status': PairingState.expired.storageKey},
            where: 'id = ?', whereArgs: [requestId]);
        return const PairingEnrollmentResult(
            state: PairingState.expired, reason: 'request_expired');
      }
      if (state != PairingState.pending && state != PairingState.verified) {
        return const PairingEnrollmentResult(
            state: PairingState.rejected, reason: 'request_already_used');
      }
      if (hashPairingCode(code) != session['code_hash']) {
        final failures = (session['failure_count'] as int) + 1;
        final next =
            failures >= 5 ? PairingState.rejected : PairingState.pending;
        await tx.update('pairing_sessions',
            {'failure_count': failures, 'status': next.storageKey},
            where: 'id = ?', whereArgs: [requestId]);
        return PairingEnrollmentResult(
            state: next,
            reason: failures >= 5 ? 'too_many_attempts' : 'code_mismatch');
      }
      final existing = await tx.query('devices',
          where:
              'family_id = ? AND member_id = ? AND role = ? AND revoked_at IS NULL',
          whereArgs: [
            session['family_id'],
            memberId,
            session['requested_role']
          ],
          limit: 1);
      if (existing.isNotEmpty) {
        return const PairingEnrollmentResult(
            state: PairingState.rejected,
            reason: 'active_device_already_linked');
      }
      final deviceId = _uuid.v4();
      await tx.insert('devices', {
        'id': deviceId,
        'family_id': session['family_id'],
        'member_id': memberId,
        'owner_member_id': ownerMemberId,
        'role': session['requested_role'],
        'sync_state': SyncState.queued.storageKey,
        'created_at': now.toIso8601String()
      });
      if (session['requested_role'] == DeviceRole.childDevice.storageKey) {
        await tx.insert('child_device_states', {
          'device_id': deviceId,
          'family_id': session['family_id'],
          'member_id': memberId,
          'lifecycle': 'enrolled',
          'required_policy_version': 0,
          'updated_at': now.toIso8601String()
        });
      }
      await tx.update(
          'pairing_sessions',
          {
            'status': PairingState.enrolled.storageKey,
            'verified_at': now.toIso8601String(),
            'enrolled_device_id': deviceId
          },
          where: 'id = ?',
          whereArgs: [requestId]);
      await _enqueue(tx,
          aggregateType: 'device',
          aggregateId: deviceId,
          operation: 'device.enrolled',
          payload: {
            'familyId': session['family_id'],
            'deviceId': deviceId,
            'memberId': memberId,
            'ownerMemberId': ownerMemberId,
            'role': session['requested_role'],
            'createdAt': now.toIso8601String()
          });
      return PairingEnrollmentResult(
          state: PairingState.enrolled, deviceId: deviceId);
    });
  }

  /// M5 Option D — mirrors a server-confirmed remote enrollment into local
  /// SQLite so the child-device UI truthfully reflects the linked device.
  ///
  /// The trusted backend already created `members/{childUid}` and
  /// `devices/{deviceId}` inside the redemption transaction, so no outbox
  /// operation is enqueued here (delivery is already confirmed server-side).
  /// The local device row is recorded with `synced` state and the child device
  /// lifecycle is set to `enrolled`.
  Future<PairingEnrollmentResult> recordRemoteEnrollment({
    required String familyId,
    required String deviceId,
    required String memberId,
    required String ownerMemberId,
    required String role,
  }) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final existing = await tx.query('devices',
          where: 'id = ?', whereArgs: [deviceId], limit: 1);
      if (existing.isNotEmpty) {
        return PairingEnrollmentResult(
            state: PairingState.enrolled, deviceId: deviceId);
      }
      final now = DateTime.now().toUtc();
      await tx.insert('devices', {
        'id': deviceId,
        'family_id': familyId,
        'member_id': memberId,
        'owner_member_id': ownerMemberId,
        'role': role,
        'sync_state': SyncState.synced.storageKey,
        'created_at': now.toIso8601String()
      });
      if (role == DeviceRole.childDevice.storageKey) {
        await tx.insert('child_device_states', {
          'device_id': deviceId,
          'family_id': familyId,
          'member_id': memberId,
          'lifecycle': 'enrolled',
          'required_policy_version': 0,
          'updated_at': now.toIso8601String()
        });
      }
      return PairingEnrollmentResult(
          state: PairingState.enrolled, deviceId: deviceId);
    });
  }

  Future<bool> revokeDevice(
      {required String deviceId, required String ownerMemberId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final updated = await tx.update(
          'devices',
          {
            'revoked_at': DateTime.now().toUtc().toIso8601String(),
            'sync_state': SyncState.queued.storageKey
          },
          where: 'id = ? AND owner_member_id = ? AND revoked_at IS NULL',
          whereArgs: [deviceId, ownerMemberId]);
      if (updated == 0) return false;
      final device = (await tx.query('devices',
              where: 'id = ?', whereArgs: [deviceId], limit: 1))
          .single;
      if (device['role'] == DeviceRole.childDevice.storageKey) {
        await tx.update(
            'child_device_states',
            {
              'lifecycle': 'revoked',
              'failure_code': 'device_revoked',
              'updated_at': DateTime.now().toUtc().toIso8601String()
            },
            where: 'device_id = ?',
            whereArgs: [deviceId]);
      }
      await _enqueue(tx,
          aggregateType: 'device',
          aggregateId: deviceId,
          operation: 'device.revoked',
          payload: {
            'familyId': device['family_id'],
            'deviceId': deviceId,
            'ownerMemberId': ownerMemberId,
            'revokedAt': DateTime.now().toUtc().toIso8601String()
          });
      return true;
    });
  }

  Future<void> _enqueue(Transaction tx,
      {required String aggregateType,
      required String aggregateId,
      required String operation,
      required Map<String, Object?> payload}) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await tx.insert('outbox', {
      'id': id,
      'aggregate_type': aggregateType,
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
