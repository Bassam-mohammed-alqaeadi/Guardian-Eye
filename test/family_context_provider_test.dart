import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/family_actor_binding_service.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
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
  final Future<RemoteFamilyMembership?> Function(String familyId, String uid) _read;
  @override
  Future<RemoteFamilyMembership?> readMembership(
          {required String familyId, required String accountUid}) =>
      _read(familyId, accountUid);
}

class _Fixture {
  const _Fixture({
    required this.database,
    required this.familyId,
    required this.memberships,
    required this.devices,
    required this.owner,
    required this.parent,
    required this.coParent,
    required this.child,
  });
  final GuardianDatabase database;
  final String familyId;
  final FamilyMembershipRepository memberships;
  final ChildDeviceRepository devices;
  final FamilyMember owner;
  final FamilyMember parent;
  final FamilyMember coParent;
  final FamilyMember child;
}

Future<_Fixture> _createFixture() async {
  final database = await openTestDatabase();
  final family = await FamilyRepository(database)
      .createFamily(familyName: 'Family', parentName: 'Owner');
  final memberships = FamilyMembershipRepository(database);
  final owner = await memberships.activeOwnerForFamily(family.id);
  final parentInvitation = await memberships.inviteAdult(
      familyId: family.id,
      actorMemberId: owner.id,
      targetEmail: 'parent@example.test',
      proposedRole: FamilyRole.parent);
  final parent = await memberships.acceptInvitation(
      invitationId: parentInvitation.id,
      accountUid: 'parent-uid',
      accountEmail: 'parent@example.test',
      displayName: 'Parent');
  final coParentInvitation = await memberships.inviteAdult(
      familyId: family.id,
      actorMemberId: owner.id,
      targetEmail: 'coparent@example.test',
      proposedRole: FamilyRole.coParent);
  final coParent = await memberships.acceptInvitation(
      invitationId: coParentInvitation.id,
      accountUid: 'coparent-uid',
      accountEmail: 'coparent@example.test',
      displayName: 'Co Parent');
  final child =
      await FamilyRepository(database).addChild(familyId: family.id, childName: 'Child');
  final devices = ChildDeviceRepository(database);
  return _Fixture(
      database: database,
      familyId: family.id,
      memberships: memberships,
      devices: devices,
      owner: owner,
      parent: parent,
      coParent: coParent,
      child: child);
}

Future<FamilyActorBindingService> _serviceFor(
    _Fixture fixture, FamilyMember actor, String uid) async {
  // Look the member up fresh so role/account updates made after fixture
  // creation (such as a bound account uid) are reflected in the reader.
  final fresh = await fixture.memberships
      .memberForFamily(familyId: fixture.familyId, memberId: actor.id);
  final actorSnapshot = fresh ?? actor;
  final reader = _Reader((familyId, accountUid) async {
    if (actorSnapshot.accountUid != accountUid) return null;
    return RemoteFamilyMembership(
        path: FirestorePaths.member(familyId, accountUid),
        familyId: familyId,
        memberId: actorSnapshot.id,
        memberUid: accountUid,
        role: actorSnapshot.role.name,
        status: actorSnapshot.status.name);
  });
  return FamilyActorBindingService(
      _Auth(AuthSession(
          status: AuthSessionStatus.authenticated,
          identity: AuthenticatedIdentity(
              uid: uid, email: '$uid@example.test', isAnonymous: false))),
      fixture.memberships,
      reader);
}

Future<ChildDeviceState> _insertDevice(
    _Fixture fixture, String deviceId) async {
  final db = await fixture.database.database;
  final existing = await db.query('devices',
      where: 'id = ?', whereArgs: [deviceId], limit: 1);
  if (existing.isEmpty) {
    await db.insert('devices', {
      'id': deviceId,
      'family_id': fixture.familyId,
      'member_id': fixture.child.id,
      'role': DeviceRole.childDevice.storageKey,
      'sync_state': 'synced',
      'created_at': DateTime.utc(2026, 8, 12, 12).toIso8601String()
    });
  }
  return await fixture.devices
      .initializeForEnrolledDevice(deviceId)
      .then((state) =>
          fixture.devices.transition(deviceId: deviceId, to: ChildDeviceLifecycle.active));
}

Future<FamilyRuntimeContext> _contextFor(
    _Fixture fixture, FamilyMember actor, String uid, {String? deviceId}) async {
  if (actor.role == FamilyRole.child) {
    final db = await fixture.database.database;
    await db.update('family_members', {'account_uid': uid},
        where: 'family_id = ? AND id = ?',
        whereArgs: [fixture.familyId, actor.id]);
  } else {
    await fixture.memberships.bindVerifiedAccount(
        familyId: fixture.familyId,
        memberId: actor.id,
        accountUid: uid,
        expectedRole: actor.role);
  }
  final childDeviceId = deviceId ?? 'child-device-1';
  final device = await _insertDevice(fixture, childDeviceId)
      .then((state) => fixture.devices.transition(
          deviceId: childDeviceId, to: ChildDeviceLifecycle.active));
  expect(device.memberId, isNotNull);
  return FamilyContextResolver(
          actorBinding: await _serviceFor(fixture, actor, uid),
          membership: fixture.memberships,
          deviceRepository: fixture.devices)
      .resolve(fixture.familyId);
}

void main() {
  late _Fixture fixture;
  setUp(() async => fixture = await _createFixture());
  tearDown(() => fixture.database.close());

  group('canonical family runtime context', () {
    test('verified parent sees the same family, children and devices as the verified co-parent',
        () async {
      final parentCtx = await _contextFor(fixture, fixture.parent, 'parent-uid');
      final coParentCtx =
          await _contextFor(fixture, fixture.coParent, 'coparent-uid');
      expect(parentCtx.isVerified, isTrue);
      expect(coParentCtx.isVerified, isTrue);
      expect(parentCtx.familyId, coParentCtx.familyId);
      expect(parentCtx.allMembers.map((m) => m.id).toSet(),
          coParentCtx.allMembers.map((m) => m.id).toSet());
      expect(parentCtx.children.map((c) => c.id).toSet(),
          coParentCtx.children.map((c) => c.id).toSet());
      expect(parentCtx.children.single.role, FamilyRole.child);
      expect(parentCtx.devices.single.deviceId, 'child-device-1');
      expect(parentCtx.devices.single.familyId, fixture.familyId);
      // Centralized permission matrix: both roles get the same management set.
      for (final permission in [
        FamilyPermission.viewPolicies,
        FamilyPermission.managePolicies,
        FamilyPermission.manageDevices,
        FamilyPermission.reviewExceptionRequests,
      ]) {
        expect(parentCtx.can(permission), isTrue);
        expect(coParentCtx.can(permission), isTrue);
      }
    });

    test('child identity never verifies — isolation view denies every action',
        () async {
      final childCtx =
          await _contextFor(fixture, fixture.child, 'child-uid');
      // Trusted Actor Binding is fail-closed: a child member is explicitly
      // rejected as an actor (remoteChildIdentity / localChildIdentity),
      // so no signed-in child can ever act as a verified actor.
      expect(childCtx.isVerified, isFalse);
      expect(childCtx.actor, isNull);
      expect(childCtx.can(FamilyPermission.managePolicies), isFalse);
      expect(childCtx.can(FamilyPermission.manageDevices), isFalse);
      expect(childCtx.can(FamilyPermission.requestOwnException), isFalse);
      // The family contents are still readable for rendering the child
      // view: the family exposes the same child members to everyone.
      expect(childCtx.allMembers.map((m) => m.role),
          contains(FamilyRole.child));
      expect(childCtx.children, hasLength(1));
    });

    test('unverified actor receives a closed context and no privileged action',
        () async {
      await fixture.memberships.bindVerifiedAccount(
          familyId: fixture.familyId,
          memberId: fixture.parent.id,
          accountUid: 'parent-uid',
          expectedRole: FamilyRole.parent);
      await _insertDevice(fixture, 'child-device-2');
      // A signed-in account that is NOT bound to any family member role
      // (no membership for this uid) must resolve to an unverified context.
      const wrongSession = AuthSession(
          status: AuthSessionStatus.authenticated,
          identity: AuthenticatedIdentity(
              uid: 'wrong-uid',
              email: 'wrong-uid@example.test',
              isAnonymous: false));
      // ignore: prefer_const_constructors
      final wrong = FamilyActorBindingService(const _Auth(wrongSession),
          fixture.memberships, _Reader((_, __) => Future.value(null)));
      final ctx = await FamilyContextResolver(
              actorBinding: wrong,
              membership: fixture.memberships,
              deviceRepository: fixture.devices)
          .resolve(fixture.familyId);
      expect(ctx.isVerified, isFalse);
      expect(ctx.actor, isNull);
      expect(ctx.can(FamilyPermission.managePolicies), isFalse);
    });

    test('empty family id returns the unverified closed context', () async {
      final ctx = await FamilyContextResolver(
              actorBinding: await _serviceFor(fixture, fixture.parent, 'parent-uid'),
              membership: fixture.memberships,
              deviceRepository: fixture.devices)
          .resolve('   ');
      expect(ctx.isVerified, isFalse);
      expect(ctx.familyId, isEmpty);
    });
  });

  group('canonical device context', () {
    test('device context resolves owner, family and active state without duplication',
        () async {
      await _insertDevice(fixture, 'child-device-3');
      final resolver = DeviceContextResolver(
          deviceRepository: fixture.devices, membership: fixture.memberships);
      final deviceCtx = await resolver.resolve(
          familyId: fixture.familyId, deviceId: 'child-device-3');
      expect(deviceCtx, isNotNull);
      expect(deviceCtx!.state.memberId, fixture.child.id);
      expect(deviceCtx.member!.id, fixture.child.id);
      expect(deviceCtx.memberRole, FamilyRole.child);
      expect(deviceCtx.isChildDevice, isTrue);
      expect(deviceCtx.isActive, isTrue);
      expect(deviceCtx.state.familyId, fixture.familyId);
    });

    test('device context is rejected across families and for unknown devices',
        () async {
      final resolver = DeviceContextResolver(
          deviceRepository: fixture.devices, membership: fixture.memberships);
      final deviceCtx = await resolver.resolve(
          familyId: fixture.familyId, deviceId: 'child-device-3');
      expect(deviceCtx, isNull);
      await _insertDevice(fixture, 'child-device-4');
      final crossFamily = await resolver.resolve(
          familyId: 'other-family', deviceId: 'child-device-4');
      expect(crossFamily, isNull);
    });

    test('revocation closes the device while offline keeps it enrolled', () async {
      await _insertDevice(fixture, 'child-device-5');
      await fixture.devices.transition(
          deviceId: 'child-device-5', to: ChildDeviceLifecycle.offline);
      final offline = await DeviceContextResolver(
              deviceRepository: fixture.devices,
              membership: fixture.memberships)
          .resolve(familyId: fixture.familyId, deviceId: 'child-device-5');
      expect(offline!.isActive, isTrue);
      await fixture.devices.transition(
          deviceId: 'child-device-5', to: ChildDeviceLifecycle.revoked);
      final revoked = await DeviceContextResolver(
              deviceRepository: fixture.devices,
              membership: fixture.memberships)
          .resolve(familyId: fixture.familyId, deviceId: 'child-device-5');
      expect(revoked!.isActive, isFalse);
      expect(revoked.isChildDevice, isTrue);
    });
  });
}
