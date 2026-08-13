import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

void main() {
  test('owner invitation accepts matching account atomically and is idempotent only for that account', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family = await families.createFamily(familyName: 'Family', parentName: 'Owner');
    final owner = (await FamilyMembershipRepository(database).activeOwnerForFamily(family.id));
    final members = FamilyMembershipRepository(database);
    final invitation = await members.inviteAdult(
        familyId: family.id, actorMemberId: owner.id, targetEmail: 'second@example.test', proposedRole: FamilyRole.coParent);
    expect(invitation.status, FamilyInvitationStatus.pending);
    final accepted = await members.acceptInvitation(
        invitationId: invitation.id, accountUid: 'second-uid', accountEmail: 'SECOND@example.test', displayName: 'Second');
    expect(accepted.role, FamilyRole.coParent);
    expect(accepted.status, FamilyMemberStatus.active);
    expect(accepted.accountUid, 'second-uid');
    final replay = await members.acceptInvitation(
        invitationId: invitation.id, accountUid: 'second-uid', accountEmail: 'second@example.test', displayName: 'Other Name');
    expect(replay.id, accepted.id);
    await expectLater(members.acceptInvitation(
        invitationId: invitation.id, accountUid: 'wrong-uid', accountEmail: 'second@example.test', displayName: 'Wrong'), throwsA(isA<StateError>()));
    final rows = await (await database.database).query('outbox',
        where: 'operation = ?', whereArgs: ['family.member.accepted']);
    expect(rows, hasLength(1));
    await database.close();
  });

  test('invitation expiry and cancellation prevent acceptance without a worker', () async {
    var now = DateTime.utc(2026, 8, 12, 12);
    final database = await openTestDatabase();
    final family = await FamilyRepository(database).createFamily(familyName: 'Family', parentName: 'Owner');
    final members = FamilyMembershipRepository(database, clock: () => now);
    final owner = await members.activeOwnerForFamily(family.id);
    final expired = await members.inviteAdult(
        familyId: family.id, actorMemberId: owner.id, targetEmail: 'expired@example.test', proposedRole: FamilyRole.parent,
        validity: const Duration(minutes: 1));
    now = now.add(const Duration(minutes: 2));
    await expectLater(members.acceptInvitation(
        invitationId: expired.id, accountUid: 'expired-uid', accountEmail: 'expired@example.test', displayName: 'Expired'), throwsA(isA<StateError>()));
    expect((await members.invitationsForFamily(family.id)).single.status, FamilyInvitationStatus.expired);
    final pending = await members.inviteAdult(
        familyId: family.id, actorMemberId: owner.id, targetEmail: 'cancel@example.test', proposedRole: FamilyRole.parent);
    await members.cancelInvitation(familyId: family.id, invitationId: pending.id, actorMemberId: owner.id);
    await expectLater(members.acceptInvitation(
        invitationId: pending.id, accountUid: 'cancel-uid', accountEmail: 'cancel@example.test', displayName: 'Cancel'), throwsA(isA<StateError>()));
    await database.close();
  });

  test('only owner manages adult membership and revocation revokes associated adult devices', () async {
    final database = await openTestDatabase();
    final families = FamilyRepository(database);
    final family = await families.createFamily(familyName: 'Family', parentName: 'Owner');
    final members = FamilyMembershipRepository(database);
    final owner = await members.activeOwnerForFamily(family.id);
    final invitation = await members.inviteAdult(
        familyId: family.id, actorMemberId: owner.id, targetEmail: 'parent@example.test', proposedRole: FamilyRole.parent);
    final parent = await members.acceptInvitation(
        invitationId: invitation.id, accountUid: 'parent-uid', accountEmail: 'parent@example.test', displayName: 'Parent');
    await expectLater(members.inviteAdult(
        familyId: family.id, actorMemberId: parent.id, targetEmail: 'third@example.test', proposedRole: FamilyRole.coParent), throwsA(isA<StateError>()));
    await expectLater(members.updateAdultRole(
        familyId: family.id, actorMemberId: parent.id, targetMemberId: owner.id, role: FamilyRole.coParent), throwsA(isA<StateError>()));
    final pairing = PairingRepository(database);
    final pairingRequest = await pairing.createParentAuthorizedRequest(
        familyId: family.id, requestedRole: DeviceRole.parentDevice, targetMemberId: parent.id);
    final enrollment = await pairing.verifyAndEnroll(
        requestId: pairingRequest.id, code: pairingRequest.code, memberId: parent.id, ownerMemberId: owner.id);
    expect(enrollment.succeeded, isTrue);
    await members.revokeMember(familyId: family.id, actorMemberId: owner.id, targetMemberId: parent.id);
    final after = (await members.membersForFamily(family.id)).singleWhere((item) => item.id == parent.id);
    expect(after.status, FamilyMemberStatus.revoked);
    final device = (await (await database.database).query('devices', where: 'id = ?', whereArgs: [enrollment.deviceId])).single;
    expect(device['revoked_at'], isNotNull);
    await database.close();
  });

  test('permission matrix grants safety work to parent and co-parent but not owner-only membership control', () {
    const authorization = FamilyAuthorization();
    expect(authorization.permissionsFor(FamilyRole.parent).contains(FamilyPermission.reviewExceptionRequests), isTrue);
    expect(authorization.permissionsFor(FamilyRole.coParent).contains(FamilyPermission.managePolicies), isTrue);
    expect(authorization.permissionsFor(FamilyRole.parent).contains(FamilyPermission.inviteMembers), isFalse);
    expect(authorization.permissionsFor(FamilyRole.child).contains(FamilyPermission.manageMembers), isFalse);
  });
}
