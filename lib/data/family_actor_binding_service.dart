import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/guardian_models.dart';
import 'family_membership_repository.dart';
import 'firebase_auth_context.dart';
import 'firestore_contracts.dart';

enum FamilyActorBindingFailure {
  invalidFamilyId,
  firebaseUnconfigured,
  unauthenticated,
  anonymousIdentity,
  invalidAuthenticatedUid,
  remoteReadFailed,
  remoteMembershipMissing,
  remotePathMismatch,
  remoteFamilyMismatch,
  remoteIdentityMismatch,
  remoteMembershipInactive,
  remoteRoleInvalid,
  remoteChildIdentity,
  localMemberMissing,
  localMemberInactive,
  localIdentityMismatch,
  localRoleMismatch,
  localChildIdentity,
  remoteLocalMemberMismatch,
  localBindingRejected,
}

class RemoteFamilyMembership {
  const RemoteFamilyMembership({
    required this.path,
    this.familyId,
    this.memberId,
    this.memberUid,
    this.role,
    this.status,
  });

  final String path;
  final String? familyId;
  final String? memberId;
  final String? memberUid;
  final String? role;
  final String? status;
}

abstract class FamilyMembershipRemoteReader {
  Future<RemoteFamilyMembership?> readMembership({
    required String familyId,
    required String accountUid,
  });
}

class FirestoreFamilyMembershipRemoteReader
    implements FamilyMembershipRemoteReader {
  const FirestoreFamilyMembershipRemoteReader(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<RemoteFamilyMembership?> readMembership({
    required String familyId,
    required String accountUid,
  }) async {
    final path = FirestorePaths.member(familyId, accountUid);
    final snapshot = await _firestore
        .doc(path)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    return RemoteFamilyMembership(
      path: snapshot.reference.path,
      familyId: data?['familyId'] as String?,
      memberId: data?['memberId'] as String?,
      memberUid: data?['memberUid'] as String?,
      role: data?['role'] as String?,
      status: data?['status'] as String?,
    );
  }
}

class FamilyActorBinding {
  const FamilyActorBinding({
    required this.familyId,
    required this.identity,
    required this.member,
    required this.remotePath,
  });

  final String familyId;
  final AuthenticatedIdentity identity;
  final FamilyMember member;
  final String remotePath;
}

class FamilyActorBindingResult {
  const FamilyActorBindingResult._({this.binding, this.failure});

  const FamilyActorBindingResult.verified(FamilyActorBinding binding)
      : this._(binding: binding);

  const FamilyActorBindingResult.unverified(FamilyActorBindingFailure failure)
      : this._(failure: failure);

  final FamilyActorBinding? binding;
  final FamilyActorBindingFailure? failure;
  bool get isVerified => binding != null && failure == null;
}

/// Resolves a UI actor only when both the active Firebase identity and the
/// server-sourced, UID-keyed Firestore member document agree with SQLite.
/// Every absence, malformed field, authorization failure, or mismatch returns
/// an unverified result; callers must expose no privileged action in that case.
class FamilyActorBindingService {
  const FamilyActorBindingService(
      this._auth, this._memberships, this._remoteReader);

  final AuthContext _auth;
  final FamilyMembershipRepository _memberships;
  final FamilyMembershipRemoteReader _remoteReader;

  Future<FamilyActorBindingResult> resolveForFamily(String familyId) async {
    final normalizedFamilyId = familyId.trim();
    if (normalizedFamilyId.isEmpty) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.invalidFamilyId);
    }
    final session = _auth.currentSession;
    if (session.status == AuthSessionStatus.unconfigured) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.firebaseUnconfigured);
    }
    if (!session.isAuthenticated || session.identity == null) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.unauthenticated);
    }
    final identity = session.identity!;
    final uid = identity.uid.trim();
    if (identity.isAnonymous) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.anonymousIdentity);
    }
    if (uid.isEmpty) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.invalidAuthenticatedUid);
    }

    final expectedPath = FirestorePaths.member(normalizedFamilyId, uid);
    RemoteFamilyMembership? remote;
    try {
      remote = await _remoteReader.readMembership(
          familyId: normalizedFamilyId, accountUid: uid);
    } catch (_) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteReadFailed);
    }
    if (remote == null) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteMembershipMissing);
    }
    if (remote.path != expectedPath) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remotePathMismatch);
    }
    if (remote.familyId != normalizedFamilyId) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteFamilyMismatch);
    }
    if (remote.memberUid != uid) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteIdentityMismatch);
    }
    if (remote.status != FamilyMemberStatus.active.name) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteMembershipInactive);
    }
    final remoteRole = _roleOrNull(remote.role);
    if (remoteRole == null) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteRoleInvalid);
    }
    if (remoteRole == FamilyRole.child) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteChildIdentity);
    }
    final remoteMemberId = remote.memberId;
    if (remoteMemberId == null || remoteMemberId.isEmpty) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.remoteLocalMemberMismatch);
    }
    final local = await _memberships.memberForFamily(
        familyId: normalizedFamilyId, memberId: remoteMemberId);
    if (local == null) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localMemberMissing);
    }
    if (!local.isActive) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localMemberInactive);
    }
    if (local.accountUid != null && local.accountUid != uid) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localIdentityMismatch);
    }
    if (local.role != remoteRole) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localRoleMismatch);
    }
    if (local.role == FamilyRole.child) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localChildIdentity);
    }
    try {
      final bound = await _memberships.bindVerifiedAccount(
          familyId: normalizedFamilyId,
          memberId: local.id,
          accountUid: uid,
          expectedRole: remoteRole);
      return FamilyActorBindingResult.verified(FamilyActorBinding(
          familyId: normalizedFamilyId,
          identity: identity,
          member: bound,
          remotePath: expectedPath));
    } catch (_) {
      return const FamilyActorBindingResult.unverified(
          FamilyActorBindingFailure.localBindingRejected);
    }
  }

  FamilyRole? _roleOrNull(String? value) {
    if (value == null) return null;
    for (final role in FamilyRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
