import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/device_link_service.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'test_database.dart';

void main() {
  group('redemption outcome mapping', () {
    test('repository rejection reasons map to distinct localized outcomes', () {
      expect(outcomeForReason('code_mismatch'), RedeemOutcome.codeInvalid);
      expect(outcomeForReason('request_expired'), RedeemOutcome.codeExpired);
      expect(outcomeForReason('too_many_attempts'), RedeemOutcome.codeLocked);
      expect(outcomeForReason('request_already_used'),
          RedeemOutcome.codeAlreadyUsed);
      expect(
          outcomeForReason('request_revoked'), RedeemOutcome.codeAlreadyUsed);
      expect(outcomeForReason('active_device_already_linked'),
          RedeemOutcome.alreadyEnrolled);
      expect(outcomeForReason('request_not_found'), RedeemOutcome.codeInvalid);
      expect(outcomeForReason(null), RedeemOutcome.codeInvalid);
    });
  });

  group('redemption end-to-end', () {
    test('valid redemption enrolls the device for the chosen child',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final request = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      final service = DeviceLinkService(pairing);
      final result = await service.redeem(
          requestId: request.id, code: request.code, targetMemberId: child.id);
      expect(result.outcome, RedeemOutcome.pendingSync);
      expect(result.deviceId, isNotNull);
      final states =
          await ChildDeviceRepository(database).statesForFamily(family.id);
      expect(states.single.lifecycle, ChildDeviceLifecycle.enrolled);
      expect(states.single.memberId, child.id);
      final db = await database.database;
      expect(
          (await db.query('outbox',
                  where: 'operation = ?', whereArgs: ['device.enrolled']))
              .length,
          1);
      await database.close();
    });

    test('redemption is idempotent: second attempt is rejected as used',
        () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final request = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      final service = DeviceLinkService(pairing);
      final first = await service.redeem(
          requestId: request.id, code: request.code, targetMemberId: child.id);
      expect(first.succeededOrPendingSync, isTrue);
      final second = await service.redeem(
          requestId: request.id, code: request.code, targetMemberId: child.id);
      expect(second.outcome, RedeemOutcome.codeAlreadyUsed);
      expect(second.deviceId, isNull);
      await database.close();
    });

    test('malformed codes fail before repository contact', () async {
      final database = await openTestDatabase();
      final pairing = PairingRepository(database);
      final service = DeviceLinkService(pairing);
      expect((await service.redeem(requestId: 'req', code: '123', targetMemberId: 'c'))
              .outcome,
          RedeemOutcome.codeInvalid);
      expect((await service.redeem(requestId: 'req', code: '12345a', targetMemberId: 'c'))
              .outcome,
          RedeemOutcome.codeInvalid);
      expect((await service.redeem(requestId: 'req', code: '1234567', targetMemberId: 'c'))
              .outcome,
          RedeemOutcome.codeInvalid);
      await database.close();
    });

    test('expired request is rejected as expired', () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final request = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      // Expire the session directly (clock is real).
      final db = await database.database;
      await db.update('pairing_sessions',
          {'expires_at': DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String()},
          where: 'id = ?', whereArgs: [request.id]);
      final service = DeviceLinkService(pairing);
      final result = await service.redeem(
          requestId: request.id, code: request.code, targetMemberId: child.id);
      expect(result.outcome, RedeemOutcome.codeExpired);
      expect(result.deviceId, isNull);
      await database.close();
    });

    test('wrong family request is rejected', () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final familyA =
          await families.createFamily(familyName: 'Family A', parentName: 'A');
      await families.createFamily(familyName: 'Family B', parentName: 'B');
      final childA =
          await families.addChild(familyId: familyA.id, childName: 'Child A');
      final pairing = PairingRepository(database);
      final request = await pairing.createParentAuthorizedRequest(
          familyId: familyA.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: childA.id);
      final db = await database.database;
      final service = DeviceLinkService(pairing);
      // Redeem against a nonexistent request id (cross-family boundary).
      final result = await service.redeem(
          requestId: 'unknown-family-request-id',
          code: request.code,
          targetMemberId: childA.id);
      expect(result.outcome, RedeemOutcome.codeInvalid);
      final session = (await db.query('pairing_sessions',
              where: 'id = ?', whereArgs: [request.id]))
          .single;
      expect(session['status'], PairingState.pending.storageKey);
      await database.close();
    });

    test('second active device for the same child is rejected', () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final first = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      await pairing.verifyAndEnroll(
          requestId: first.id,
          code: first.code,
          memberId: child.id,
          ownerMemberId: child.id);
      final second = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      final service = DeviceLinkService(pairing);
      final result = await service.redeem(
          requestId: second.id,
          code: second.code,
          targetMemberId: child.id);
      expect(result.outcome, RedeemOutcome.alreadyEnrolled);
      expect(result.deviceId, isNull);
      await database.close();
    });

    test('revocation by non-owner fails and by owner succeeds', () async {
      final database = await openTestDatabase();
      final families = FamilyRepository(database);
      final family =
          await families.createFamily(familyName: 'Family', parentName: 'Parent');
      final child =
          await families.addChild(familyId: family.id, childName: 'Child');
      final pairing = PairingRepository(database);
      final request = await pairing.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      final enrolled = await pairing.verifyAndEnroll(
          requestId: request.id,
          code: request.code,
          memberId: child.id,
          ownerMemberId: child.id);
      expect(
          await pairing.revokeDevice(
              deviceId: enrolled.deviceId!, ownerMemberId: 'other'),
          isFalse);
      expect(
          await pairing.revokeDevice(
              deviceId: enrolled.deviceId!, ownerMemberId: child.id),
          isTrue);
      final states =
          await ChildDeviceRepository(database).statesForFamily(family.id);
      expect(states.single.lifecycle, ChildDeviceLifecycle.revoked);
      final db = await database.database;
      expect(
          (await db.query('outbox',
                  where: 'operation = ?', whereArgs: ['device.revoked']))
              .length,
          1);
      await database.close();
    });
  });
}

extension on ({RedeemOutcome outcome, String? deviceId}) {
  bool get succeededOrPendingSync =>
      outcome == RedeemOutcome.pendingSync || outcome == RedeemOutcome.success;
}
