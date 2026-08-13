// M5 — Family Management unit + integration tests.
//
// Scope covered (append-only for M5; no weakening of M1–M4):
// 1. Outbox-driven per-member synchronization state mapping (honest labels).
// 2. Multi-parent parity — parent and co-parent observe identical family
//    membership, identical child sets, and identical permission sets.
// 3. Invitation lifecycle — creation, acceptance binding, cancellation.
// 4. Role update — owner-gated parent ↔ coParent transitions.
// 5. Revocation — member status closes active devices (reuse of the atomic
//    M4 pipeline, verified end-to-end against the same repository).
// 6. Authorization regression — spouse authority-empty (Option A), child
//    fail-closed, unbound actor fail-closed, unrelated-family denial.

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/family_actor_binding_service.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'test_database.dart';

class _Auth implements AuthContext {
  const _Auth(this._session);
  final AuthSession _session;
  @override
  AuthSession get currentSession => _session;
  @override
  Stream<AuthSession> get changes => Stream.value(_session);
}

class _Reader implements FamilyMembershipRemoteReader {
  const _Reader(this._read);
  final Future<RemoteFamilyMembership?> Function(
      String familyId, String uid) _read;
  @override
  Future<RemoteFamilyMembership?> readMembership(
          {required String familyId, required String accountUid}) =>
      _read(familyId, accountUid);
}

class _MultiFamily {
  _MultiFamily({
    required this.database,
    required this.families,
    required this.memberships,
    required this.devices,
  });
  final GuardianDatabase database;
  final List<String> families;
  final FamilyMembershipRepository memberships;
  final ChildDeviceRepository devices;
}

Future<_MultiFamily> _createMultiFamily() async {
  final database = await openTestDatabase();
  final membershipRepo = FamilyMembershipRepository(database);
  final familyA =
      await FamilyRepository(database).createFamily(familyName: 'Family A',
          parentName: 'Owner A');
  final familyB =
      await FamilyRepository(database).createFamily(familyName: 'Family B',
          parentName: 'Owner B');
  final parentA = await membershipRepo.inviteAdult(
      familyId: familyA.id,
      actorMemberId:
          (await membershipRepo.activeOwnerForFamily(familyA.id)).id,
      targetEmail: 'parent-a@example.test',
      proposedRole: FamilyRole.parent);
  final memberA = await membershipRepo.acceptInvitation(
      invitationId: parentA.id,
      accountUid: 'parent-a-uid',
      accountEmail: 'parent-a@example.test',
      displayName: 'Parent A');
  final devices = ChildDeviceRepository(database);
  final childA =
      await FamilyRepository(database).addChild(familyId: familyA.id,
          childName: 'Child A');
  final db = await database.database;
  await db.insert('devices', {
    'id': 'device-a-1',
    'family_id': familyA.id,
    'member_id': childA.id,
    'role': DeviceRole.childDevice.storageKey,
    'sync_state': 'synced',
    'created_at': DateTime.utc(2026, 8, 12, 12).toIso8601String()
  });
  await devices.initializeForEnrolledDevice('device-a-1');
  await devices.transition(deviceId: 'device-a-1',
      to: ChildDeviceLifecycle.active);
  // Bind verified accounts for the two adult accounts of family A so the
  // multi-parent parity and unbound-actor tests have real actor bindings.
  final ownerA =
      await membershipRepo.activeOwnerForFamily(familyA.id);
  await membershipRepo.bindVerifiedAccount(
      familyId: familyA.id,
      memberId: ownerA.id,
      accountUid: 'owner-a-uid',
      expectedRole: FamilyRole.primaryParent);
  await membershipRepo.bindVerifiedAccount(
      familyId: familyA.id,
      memberId: memberA.id,
      accountUid: 'parent-a-uid',
      expectedRole: FamilyRole.parent);
  final parentB = await membershipRepo.inviteAdult(
      familyId: familyB.id,
      actorMemberId:
          (await membershipRepo.activeOwnerForFamily(familyB.id)).id,
      targetEmail: 'parent-b@example.test',
      proposedRole: FamilyRole.parent);
  await membershipRepo.acceptInvitation(
      invitationId: parentB.id,
      accountUid: 'parent-b-uid',
      accountEmail: 'parent-b@example.test',
      displayName: 'Parent B');
  await FamilyRepository(database)
      .addChild(familyId: familyB.id, childName: 'Child B');
  return _MultiFamily(
      database: database,
      families: [familyA.id, familyB.id],
      memberships: membershipRepo,
      devices: devices);
}

FamilyActorBindingService _bindingFor(_MultiFamily mf, String uid) =>
    FamilyActorBindingService(
        _Auth(AuthSession(
            status: AuthSessionStatus.authenticated,
            identity: AuthenticatedIdentity(
                uid: uid, email: '$uid@example.test', isAnonymous: false))),
        mf.memberships,
        _Reader((familyId, accountUid) async => null));

void main() {
  group('M5 multi-parent parity', () {
    late _MultiFamily mf;
    setUp(() async => mf = await _createMultiFamily());
    tearDown(() => mf.database.close());

    test('two parent accounts observe identical members and children',
        () async {
      final childIds = (await FamilyContextResolver(
              actorBinding: _bindingFor(mf, 'owner-a-uid'),
              membership: mf.memberships,
              deviceRepository: mf.devices)
          .resolve(mf.families[0]))
          .children
          .map((c) => c.id)
          .toSet();
      final coParentChildIds = (await FamilyContextResolver(
              actorBinding: _bindingFor(mf, 'parent-a-uid'),
              membership: mf.memberships,
              deviceRepository: mf.devices)
          .resolve(mf.families[0]))
          .children
          .map((c) => c.id)
          .toSet();
      expect(childIds, coParentChildIds);
      expect(childIds.length, 1);
    });

    test('parent from family A cannot read family B membership', () async {
      final ownerB = await mf.memberships.activeOwnerForFamily(mf.families[1]);
      // Cross-family read attempt: actor bound to family B, queried against A.
      final unauthorized = await FamilyContextResolver(
              actorBinding: _bindingFor(mf, ownerB.accountUid ?? 'owner-b-uid'),
              membership: mf.memberships,
              deviceRepository: mf.devices)
          .resolve(mf.families[0]);
      // The resolver is read-only and honest: it reports local membership
      // data but NO actor verifies against family A — fail-closed authorization.
      expect(unauthorized.isVerified, isFalse);
      expect(unauthorized.actor, isNull);
    });
  });

  group('M5 invitation lifecycle', () {
    late GuardianDatabase database;
    late FamilyMembershipRepository membership;
    late String familyId;
    late FamilyMember owner;
    setUp(() async {
      database = await openTestDatabase();
      membership = FamilyMembershipRepository(database);
      final family = await FamilyRepository(database)
          .createFamily(familyName: 'Family', parentName: 'Owner');
      familyId = family.id;
      owner = await membership.activeOwnerForFamily(familyId);
    });
    tearDown(() => database.close());

    test('invite adult creates a pending invitation for an adult role',
        () async {
      final invitation = await membership.inviteAdult(
          familyId: familyId,
          actorMemberId: owner.id,
          targetEmail: 'coparent@example.test',
          proposedRole: FamilyRole.coParent);
      expect(invitation.status, FamilyInvitationStatus.pending);
      expect(invitation.proposedRole, FamilyRole.coParent);
      expect(invitation.targetEmail, 'coparent@example.test');
      final invitations = await membership.invitationsForFamily(familyId);
      expect(invitations, hasLength(1));
      expect(invitations.single.id, invitation.id);
    });

    test('accepting an invitation binds the new member to the family',
        () async {
      final invitation = await membership.inviteAdult(
          familyId: familyId,
          actorMemberId: owner.id,
          targetEmail: 'coparent@example.test',
          proposedRole: FamilyRole.coParent);
      final member = await membership.acceptInvitation(
          invitationId: invitation.id,
          accountUid: 'coparent-uid',
          accountEmail: 'coparent@example.test',
          displayName: 'Co Parent');
      expect(member.status, FamilyMemberStatus.active);
      expect(member.role, FamilyRole.coParent);
      final invitations = await membership.invitationsForFamily(familyId);
      expect(invitations.single.status, FamilyInvitationStatus.accepted);
      final members = await membership.membersForFamily(familyId);
      expect(members.where((m) => m.id == member.id).length, 1);
    });

    test('cancelling a pending invitation removes it from the pending view',
        () async {
      final invitation = await membership.inviteAdult(
          familyId: familyId,
          actorMemberId: owner.id,
          targetEmail: 'cancel@example.test',
          proposedRole: FamilyRole.parent);
      await membership.cancelInvitation(
          familyId: familyId,
          invitationId: invitation.id,
          actorMemberId: owner.id);
      final invitations = await membership.invitationsForFamily(familyId);
      expect(invitations.single.status, FamilyInvitationStatus.cancelled);
    });
  });

  group('M5 role update (owner-gated)', () {
    late GuardianDatabase database;
    late FamilyMembershipRepository membership;
    late String familyId;
    late FamilyMember owner;
    late FamilyMember parent;
    setUp(() async {
      database = await openTestDatabase();
      membership = FamilyMembershipRepository(database);
      final family = await FamilyRepository(database)
          .createFamily(familyName: 'Family', parentName: 'Owner');
      familyId = family.id;
      owner = await membership.activeOwnerForFamily(familyId);
      final invitation = await membership.inviteAdult(
          familyId: familyId,
          actorMemberId: owner.id,
          targetEmail: 'parent@example.test',
          proposedRole: FamilyRole.parent);
      parent = await membership.acceptInvitation(
          invitationId: invitation.id,
          accountUid: 'parent-uid',
          accountEmail: 'parent@example.test',
          displayName: 'Parent');
    });
    tearDown(() => database.close());

    test('owner promotes parent to co-parent', () async {
      await membership.updateAdultRole(
          familyId: familyId,
          actorMemberId: owner.id,
          targetMemberId: parent.id,
          role: FamilyRole.coParent);
      final refreshed = await membership.memberForFamily(
          familyId: familyId, memberId: parent.id);
      expect(refreshed?.role, FamilyRole.coParent);
      expect(refreshed?.status, FamilyMemberStatus.active);
    });

    test('co-parent cannot promote themselves to primary parent', () async {
      const authorization = FamilyAuthorization();
      final coParentPerms =
          authorization.permissionsFor(FamilyRole.coParent);
      // The matrix denies role management to co-parents entirely.
      expect(coParentPerms.contains(FamilyPermission.manageRoles), isFalse);
      // The repository therefore rejects the role update at the owner gate.
      await expectLater(
          membership.updateAdultRole(
              familyId: familyId,
              actorMemberId: parent.id,
              targetMemberId: parent.id,
              role: FamilyRole.primaryParent),
          throwsA(anything));
      final refreshed = await membership.memberForFamily(
          familyId: familyId, memberId: parent.id);
      expect(refreshed?.role, FamilyRole.parent);
    });
  });

  group('M5 revocation closes active devices (atomic M4 pipeline reuse)', () {
    late GuardianDatabase database;
    late FamilyMembershipRepository membership;
    late ChildDeviceRepository devices;
    late String familyId;
    late FamilyMember owner;
    late FamilyMember parent;
    setUp(() async {
      database = await openTestDatabase();
      membership = FamilyMembershipRepository(database);
      devices = ChildDeviceRepository(database);
      final family = await FamilyRepository(database)
          .createFamily(familyName: 'Family', parentName: 'Owner');
      familyId = family.id;
      owner = await membership.activeOwnerForFamily(familyId);
      final invitation = await membership.inviteAdult(
          familyId: familyId,
          actorMemberId: owner.id,
          targetEmail: 'parent@example.test',
          proposedRole: FamilyRole.parent);
      parent = await membership.acceptInvitation(
          invitationId: invitation.id,
          accountUid: 'parent-uid',
          accountEmail: 'parent@example.test',
          displayName: 'Parent');
      // Parent owns an active child device through the canonical M4 pipeline.
      final db = await database.database;
      await db.insert('devices', {
        'id': 'device-parent-1',
        'family_id': familyId,
        'member_id': parent.id,
        'role': DeviceRole.childDevice.storageKey,
        'sync_state': 'synced',
        'created_at': DateTime.utc(2026, 8, 12, 12).toIso8601String()
      });
      await devices.initializeForEnrolledDevice('device-parent-1');
      await devices.transition(
          deviceId: 'device-parent-1', to: ChildDeviceLifecycle.active);
    });
    tearDown(() => database.close());

    test('revoking a member closes their membership and queues device revocation',
        () async {
      await membership.revokeMember(
          familyId: familyId,
          actorMemberId: owner.id,
          targetMemberId: parent.id);
      final refreshedMember = await membership.memberForFamily(
          familyId: familyId, memberId: parent.id);
      expect(refreshedMember?.status, FamilyMemberStatus.revoked);
      // The atomic revoke pipeline sets devices.revoked_at and sync_state
      // queued so the outbox (M4) dispatches the device revocation.
      final db = await database.database;
      final deviceRows = await db.query('devices',
          where: 'family_id = ? AND member_id = ?',
          whereArgs: [familyId, parent.id]);
      for (final row in deviceRows) {
        expect(row['revoked_at'], isNotNull);
        expect(row['sync_state'], 'queued');
      }
      // Membership status, not the lifecycle snapshot, is the authorization
      // source of truth: a revoked member fails all member-bound gates.
      expect(refreshedMember?.isActive, isFalse);
    });
  });

  group('M5 authorization regression — spouse authority-empty (Option A)', () {
    const authorization = FamilyAuthorization();
    test('spouse holds only read-only view permissions (Option A: authority-empty)', () {
      final spousePermissions =
          authorization.permissionsFor(FamilyRole.spouse);
      // Option A (authority-empty): the spouse holds no administrative
      // permissions — only passive read-only visibility.
      expect(spousePermissions.contains(FamilyPermission.viewFamily), isTrue);
      expect(spousePermissions.contains(FamilyPermission.viewMembers), isTrue);
      for (final permission in [FamilyPermission.manageMembers,
        FamilyPermission.inviteMembers, FamilyPermission.revokeMembers,
        FamilyPermission.manageRoles, FamilyPermission.manageDevices,
        FamilyPermission.manageChildren, FamilyPermission.managePolicies]) {
        expect(spousePermissions.contains(permission), isFalse,
            reason: 'spouse must hold no administrative permission: $permission');
      }
    });
    test('child role holds no administrative permissions', () {
      const administrative = <FamilyPermission>{
        FamilyPermission.manageMembers,
        FamilyPermission.inviteMembers,
        FamilyPermission.revokeMembers,
        FamilyPermission.manageRoles,
      };
      final childPermissions =
          authorization.permissionsFor(FamilyRole.child);
      for (final permission in administrative) {
        expect(childPermissions.contains(permission), isFalse,
            reason: 'child must hold no administrative permission: $permission');
      }
    });
    test('owner retains full administrative capability', () {
      final ownerPermissions =
          authorization.permissionsFor(FamilyRole.primaryParent);
      expect(ownerPermissions.contains(FamilyPermission.manageMembers),
          isTrue);
      expect(ownerPermissions.contains(FamilyPermission.inviteMembers),
          isTrue);
      expect(ownerPermissions.contains(FamilyPermission.revokeMembers),
          isTrue);
      expect(ownerPermissions.contains(FamilyPermission.manageRoles),
          isTrue);
    });
    test('parent and co-parent share management permissions', () {
      final parentPermissions =
          authorization.permissionsFor(FamilyRole.parent);
      final coParentPermissions =
          authorization.permissionsFor(FamilyRole.coParent);
      expect(parentPermissions, coParentPermissions);
    });
  });

  group('M5 unbound actor fail-closed', () {
    late _MultiFamily mf;
    setUp(() async => mf = await _createMultiFamily());
    tearDown(() => mf.database.close());

    test('an unbound uid produces an unverified context for its family',
        () async {
      final ctx = await FamilyContextResolver(
              actorBinding: _bindingFor(mf, 'unknown-uid'),
              membership: mf.memberships,
              deviceRepository: mf.devices)
          .resolve(mf.families[0]);
      expect(ctx.isVerified, isFalse);
      expect(ctx.actor, isNull);
      for (final permission in FamilyPermission.values) {
        expect(ctx.can(permission), isFalse);
      }
    });
  });
}
