import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/family_actor_binding_service.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

class _Auth implements AuthContext {
  const _Auth(this.session);
  final AuthSession session;
  @override
  AuthSession get currentSession => session;
  @override
  Stream<AuthSession> get changes => Stream.value(session);
}

class _Reader implements FamilyMembershipRemoteReader {
  const _Reader(this._read);
  final Future<RemoteFamilyMembership?> Function(String familyId, String uid)
      _read;

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
    required this.owner,
    required this.parent,
    required this.coParent,
    required this.child,
  });

  final GuardianDatabase database;
  final String familyId;
  final FamilyMembershipRepository memberships;
  final FamilyMember owner;
  final FamilyMember parent;
  final FamilyMember coParent;
  final FamilyMember child;
}

void main() {
  late _Fixture fixture;

  setUp(() async => fixture = await _createFixture());
  tearDown(() => fixture.database.close());

  test('valid parent binding verifies server path and persists only the matching UID',
      () async {
    final result = await _serviceFor(fixture, fixture.parent, 'parent-uid')
        .resolveForFamily(fixture.familyId);

    expect(result.isVerified, isTrue);
    expect(result.binding!.member.id, fixture.parent.id);
    expect(result.binding!.member.role, FamilyRole.parent);
    expect(result.binding!.remotePath,
        FirestorePaths.member(fixture.familyId, 'parent-uid'));
    final local = await fixture.memberships.memberForFamily(
        familyId: fixture.familyId, memberId: fixture.parent.id);
    expect(local!.accountUid, 'parent-uid');
  });

  test('valid co-parent binding resolves the active co-parent actor', () async {
    final result = await _serviceFor(fixture, fixture.coParent, 'coparent-uid')
        .resolveForFamily(fixture.familyId);

    expect(result.isVerified, isTrue);
    expect(result.binding!.member.role, FamilyRole.coParent);
  });

  test('unknown UID and missing remote membership fail closed', () async {
    final service = FamilyActorBindingService(
        _authenticated('unknown-uid'), fixture.memberships, const _Reader(_missing));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.remoteMembershipMissing);
  });

  test('inactive local member is denied even when remote membership reports active',
      () async {
    await _setLocalStatus(fixture, fixture.parent.id, FamilyMemberStatus.revoked);

    final result = await _serviceFor(fixture, fixture.parent, 'parent-uid')
        .resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.localMemberInactive);
  });

  test('revoked remote member is denied even when local member remains active',
      () async {
    final service = FamilyActorBindingService(
        _authenticated('coparent-uid'),
        fixture.memberships,
        _Reader((familyId, uid) async => _remote(
            fixture.coParent, uid, status: FamilyMemberStatus.revoked.name)));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.remoteMembershipInactive);
  });

  test('cross-family remote document is denied before local binding', () async {
    final service = FamilyActorBindingService(
        _authenticated('parent-uid'),
        fixture.memberships,
        _Reader((familyId, uid) async => RemoteFamilyMembership(
            path: FirestorePaths.member(familyId, uid),
            familyId: 'another-family',
            memberId: fixture.parent.id,
            memberUid: uid,
            role: FamilyRole.parent.name,
            status: FamilyMemberStatus.active.name)));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.remoteFamilyMismatch);
  });

  test('child identity cannot resolve as an adult actor', () async {
    await _setLocalAccountUid(fixture, fixture.child.id, 'child-uid');
    final child = (await fixture.memberships.memberForFamily(
        familyId: fixture.familyId, memberId: fixture.child.id))!;
    final service = FamilyActorBindingService(
        _authenticated('child-uid'),
        fixture.memberships,
        _Reader((familyId, uid) async => _remote(child, uid)));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.remoteChildIdentity);
  });

  test('remote and local member IDs must match exactly', () async {
    final service = FamilyActorBindingService(
        _authenticated('parent-uid'),
        fixture.memberships,
        _Reader((familyId, uid) async => RemoteFamilyMembership(
            path: FirestorePaths.member(familyId, uid),
            familyId: familyId,
            memberId: 'forged-local-member-id',
            memberUid: uid,
            role: FamilyRole.parent.name,
            status: FamilyMemberStatus.active.name)));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.localMemberMissing);
  });

  test('mismatched remote and local roles fail closed', () async {
    final service = FamilyActorBindingService(
        _authenticated('parent-uid'),
        fixture.memberships,
        _Reader((familyId, uid) async => _remote(fixture.parent, uid,
            role: FamilyRole.coParent.name)));

    final result = await service.resolveForFamily(fixture.familyId);

    expect(result.isVerified, isFalse);
    expect(result.failure, FamilyActorBindingFailure.localRoleMismatch);
  });

  test('unauthenticated, anonymous, malformed UID, and remote read failure fail closed',
      () async {
    final unauthenticated = await FamilyActorBindingService(
            const _Auth(AuthSession(status: AuthSessionStatus.unauthenticated)),
            fixture.memberships,
            const _Reader(_missing))
        .resolveForFamily(fixture.familyId);
    final anonymous = await FamilyActorBindingService(
            const _Auth(AuthSession(
                status: AuthSessionStatus.authenticated,
                identity: AuthenticatedIdentity(
                    uid: 'anonymous', email: null, isAnonymous: true))),
            fixture.memberships,
            const _Reader(_missing))
        .resolveForFamily(fixture.familyId);
    final malformedUid = await FamilyActorBindingService(
            const _Auth(AuthSession(
                status: AuthSessionStatus.authenticated,
                identity: AuthenticatedIdentity(
                    uid: '  ', email: 'p@example.test', isAnonymous: false))),
            fixture.memberships,
            const _Reader(_missing))
        .resolveForFamily(fixture.familyId);
    final remoteFailure = await FamilyActorBindingService(
            _authenticated('parent-uid'),
            fixture.memberships,
            _Reader((_, __) => Future<RemoteFamilyMembership?>.error(
                StateError('network denied'))))
        .resolveForFamily(fixture.familyId);

    expect(unauthenticated.failure, FamilyActorBindingFailure.unauthenticated);
    expect(anonymous.failure, FamilyActorBindingFailure.anonymousIdentity);
    expect(malformedUid.failure, FamilyActorBindingFailure.invalidAuthenticatedUid);
    expect(remoteFailure.failure, FamilyActorBindingFailure.remoteReadFailed);
  });
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
  final child = await FamilyRepository(database)
      .addChild(familyId: family.id, childName: 'Child');
  return _Fixture(
      database: database,
      familyId: family.id,
      memberships: memberships,
      owner: owner,
      parent: parent,
      coParent: coParent,
      child: child);
}

AuthContext _authenticated(String uid) => _Auth(AuthSession(
    status: AuthSessionStatus.authenticated,
    identity: AuthenticatedIdentity(
        uid: uid, email: '$uid@example.test', isAnonymous: false)));

FamilyActorBindingService _serviceFor(
    _Fixture fixture, FamilyMember member, String uid) {
  return FamilyActorBindingService(_authenticated(uid), fixture.memberships,
      _Reader((familyId, accountUid) async => _remote(member, accountUid)));
}

RemoteFamilyMembership _remote(FamilyMember member, String uid,
        {String? familyId, String? status, String? role}) =>
    RemoteFamilyMembership(
        path: FirestorePaths.member(familyId ?? member.familyId, uid),
        familyId: familyId ?? member.familyId,
        memberId: member.id,
        memberUid: uid,
        role: role ?? member.role.name,
        status: status ?? FamilyMemberStatus.active.name);

Future<RemoteFamilyMembership?> _missing(String _, String __) async => null;

Future<void> _setLocalStatus(
    _Fixture fixture, String memberId, FamilyMemberStatus status) async {
  final db = await fixture.database.database;
  await db.update('family_members', {'status': status.name},
      where: 'family_id = ? AND id = ?', whereArgs: [fixture.familyId, memberId]);
}

Future<void> _setLocalAccountUid(
    _Fixture fixture, String memberId, String accountUid) async {
  final db = await fixture.database.database;
  await db.update('family_members', {'account_uid': accountUid},
      where: 'family_id = ? AND id = ?', whereArgs: [fixture.familyId, memberId]);
}
