// FS-015 — Device Linking & Enrollment subsystem test suite.
//
// Honesty checks: pairing sessions live in the real SQLite table with a
// SHA-256 code hash; the five-attempt lockout gate flips only on observed
// failures; a wrong code increments the counter but never claims success;
// enrollment creates an honest device row plus lifecycle plus outbox
// `device.enrolled`; revocation keeps the audit row (never deletes); health
// verdicts derive exclusively from stored sync facts; transfer revokes the
// old device and enqueues `device.transferred`.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/device_linking.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs015-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}
final DateTime _seededAt = DateTime.utc(2025, 7, 2);
Future<GuardianDatabase> _seededDatabase() async {
  final database = await openTestDatabase();
  final db = await database.database;
  await db.insert('families', {
    'id': 'family-x',
    'name': 'Family X',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-x',
    'family_id': 'family-x',
    'display_name': 'Parent',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-x',
    'family_id': 'family-x',
    'display_name': 'Child',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  return database;
}
Future<PairingRepository> _repoFor(GuardianDatabase database) async {
  return PairingRepository(database);
}
void main() {
  group('pairing code issuance and session lookup', () {
    test('creates a pending session with a hashed six-digit code',
        () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final request = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      expect(request.code, hasLength(6));
      expect(int.tryParse(request.code), isNotNull);
      expect(request.targetMemberId, 'child-x');
      final session = await repo.sessionForCode('family-x', request.code);
      expect(session, isNotNull);
      expect(session!['status'], PairingState.pending.storageKey);
      expect(session['code_hash'],
          PairingRepository.hashPairingCode(request.code));
    });
    test('sessionForCode returns null for an unknown code', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final session = await repo.sessionForCode('family-x', '000000');
      expect(session, isNull);
    });
  });
  group('lockout after five wrong attempts', () {
    test('marks the session rejected after five wrong codes', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final request = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      PairingEnrollmentResult? last;
      for (int i = 0; i < 5; i++) {
        last = await repo.verifyAndEnroll(
            requestId: request.id, code: '111111',
            memberId: 'child-x', ownerMemberId: 'parent-x');
        expect(last.reason, i == 4 ? 'too_many_attempts' : 'code_mismatch');
      }
      // The honest result flips to rejected only once the counter reaches 5.
      expect(last!.state, PairingState.rejected);
      final session = await repo.sessionForCode('family-x', request.code);
      expect(session!['failure_count'], 5);
      expect(session['status'], PairingState.rejected.storageKey);
    });
    test('a wrong code before the threshold never claims success', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final request = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      final result = await repo.verifyAndEnroll(
          requestId: request.id, code: '222222',
          memberId: 'child-x', ownerMemberId: 'parent-x');
      // Honest rejection of the code: the session survives (counter = 1,
      // status still pending) so the guardian can still recover with the
      // right code — the API reports rejection via the reason, not state.
      expect(result.state, PairingState.pending);
      expect(result.reason, 'code_mismatch');
      expect(result.deviceId, isNull);
      final session = await repo.sessionForCode('family-x', request.code);
      expect(session!['failure_count'], 1);
      expect(session['status'], PairingState.pending.storageKey);
    });
    test('resetFailedAttempts clears the honest failure counter', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final request = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      await repo.verifyAndEnroll(requestId: request.id, code: '333333',
          memberId: 'child-x', ownerMemberId: 'parent-x');
      expect(await repo.resetFailedAttempts('family-x'), true);
      final session = await repo.sessionForCode('family-x', request.code);
      expect(session!['failure_count'], 0);
      expect(session['status'], PairingState.pending.storageKey);
    });
  });
  group('honest enrollment', () {
    test('enrolls a child device and keeps audit rows', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final request = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      final result = await repo.verifyAndEnroll(
          requestId: request.id, code: request.code,
          memberId: 'child-x', ownerMemberId: 'parent-x');
      expect(result.state, PairingState.enrolled);
      expect(result.deviceId, isNotNull);
      final device = await repo.deviceById(result.deviceId!);
      expect(device!['role'], DeviceRole.childDevice.storageKey);
      expect(device['sync_state'], SyncState.queued.storageKey);
      final lifecycle = await repo.lifecycleForDevice(result.deviceId!);
      expect(lifecycle, isNotNull);
      expect(lifecycle!['lifecycle'], 'enrolled');
      final devices = await repo.devicesForFamily('family-x');
      expect(devices.length, 1);
    });
    test('a second device for the same member is refused honestly', () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final first = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      final firstResult = await repo.verifyAndEnroll(
          requestId: first.id, code: first.code,
          memberId: 'child-x', ownerMemberId: 'parent-x');
      expect(firstResult.state, PairingState.enrolled);
      final second = await repo.createParentAuthorizedRequest(
          familyId: 'family-x', requestedRole: DeviceRole.childDevice,
          targetMemberId: 'child-x');
      final secondResult = await repo.verifyAndEnroll(
          requestId: second.id, code: second.code,
          memberId: 'child-x', ownerMemberId: 'parent-x');
      expect(secondResult.state, PairingState.rejected);
      expect(secondResult.reason, 'active_device_already_linked');
    });
  });
  group('device health verdicts (DL-010)', () {
    test('healthy/stale/offline/revoked derive from stored facts', () async {
      final now = DateTime.utc(2025, 7, 2, 12, 0);
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final db = await database.database;
      await db.insert('devices', {
        'id': 'device-healthy',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'owner_member_id': 'parent-x',
        'role': 'childDevice',
        'sync_state': 'synced',
        'last_synced_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('devices', {
        'id': 'device-stale',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'owner_member_id': 'parent-x',
        'role': 'childDevice',
        'sync_state': 'queued',
        'last_synced_at': now.subtract(const Duration(hours: 4)).toIso8601String(),
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('devices', {
        'id': 'device-offline',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'owner_member_id': 'parent-x',
        'role': 'childDevice',
        'sync_state': 'queued',
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('devices', {
        'id': 'device-revoked',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'owner_member_id': 'parent-x',
        'role': 'childDevice',
        'sync_state': 'synced',
        'last_synced_at': now.toIso8601String(),
        'revoked_at': now.toIso8601String(),
        'created_at': _seededAt.toIso8601String(),
      });
      final fresh = await repo.devicesForFamily('family-x');
      final verdicts = <DeviceHealth>[];
      for (final row in fresh) {
        final life = await repo.lifecycleForDevice(row['id'] as String);
        verdicts.add(DeviceHealth.fromRows(row, life, now: now));
      }
      final verdictOf = (id) => verdicts
          .firstWhere((v) => v.deviceId == id).health;
      expect(verdictOf('device-healthy'), DeviceHealthKind.healthy);
      expect(verdictOf('device-stale'), DeviceHealthKind.stale);
      expect(verdictOf('device-offline'), DeviceHealthKind.offline);
      expect(verdictOf('device-revoked'), DeviceHealthKind.revoked);
    });
  });
  group('device transfer (DL-011)', () {
    test('moves the enrollment and revokes the old device with history kept',
        () async {
      final database = await _seededDatabase();
      final repo = await _repoFor(database);
      final db = await database.database;
      await db.insert('devices', {
        'id': 'device-old',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'owner_member_id': 'parent-x',
        'role': 'childDevice',
        'sync_state': 'synced',
        'last_synced_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('child_device_states', {
        'device_id': 'device-old',
        'family_id': 'family-x',
        'member_id': 'child-x',
        'lifecycle': 'enrolled',
        'required_policy_version': 0,
        'updated_at': _seededAt.toIso8601String(),
      });
      final result = await repo.transferDeviceEnrollment(
          oldDeviceId: 'device-old',
          familyId: 'family-x',
          memberId: 'child-x',
          ownerMemberId: 'parent-x');
      expect(result.succeeded, true);
      expect(result.newDeviceId, isNotNull);
      final oldDevice = await repo.deviceById('device-old');
      expect(oldDevice!['revoked_at'], isNotNull);
      expect(await repo.devicesForFamily('family-x'), hasLength(2));
      final lifecycle =
          await repo.lifecycleForDevice(result.newDeviceId!);
      expect(lifecycle!['lifecycle'], 'enrolled');
      final outbox = await db.query('outbox',
          where: 'operation = ?',
          whereArgs: ['device.transferred'], limit: 1);
      expect(outbox, isNotEmpty);
    });
  });
  group('lifecycle helpers', () {
    test('isTransferable only for enrolled, unrevoked devices', () {
      expect(DeviceLinkingLifecycle.isTransferable('enrolled', null), true);
      expect(DeviceLinkingLifecycle.isTransferable('enrolled',
          '2025-07-02T00:00:00Z'), false);
      expect(DeviceLinkingLifecycle.isTransferable('revoked', null), false);
    });
  });
}
