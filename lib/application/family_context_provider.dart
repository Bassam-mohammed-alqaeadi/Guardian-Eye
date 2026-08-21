/// Canonical family runtime context for Guardian Eye Pro — Phase 18.
///
/// One single runtime source of truth that the UI consumes instead of
/// reconstructing family/member/device state independently per screen.
///
/// Graph (as mandated by the Phase 18 architecture):
///
///   Authenticated User → Trusted Actor → Family Context
///     ├── Family
///     ├── Member  (the actor)
///     ├── Role
///     ├── Permissions (centralized FamilyAuthorization matrix — not duplicated)
///     ├── Devices
///     └── Children
///
/// Person identity and device identity remain separate. Nothing in this
/// module infers "this device is the owner" from a local primary-parent row:
/// authority always flows from [FamilyActorBindingService], which is fail-closed.
///
/// No new authorization mechanism is introduced. Permissions are delegated to
/// [FamilyAuthorization], which remains the single permission source.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/child_device_repository.dart';
import '../data/family_actor_binding_service.dart';
import '../data/family_membership_repository.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/family_authorization.dart';
import '../domain/guardian_models.dart';
import 'guardian_providers.dart';

/// One coherent family runtime view resolved for an explicit family.
class FamilyRuntimeContext {
  const FamilyRuntimeContext({
    required this.familyId,
    required this.family,
    required this.actor,
    required this.isVerified,
    required this.permissionsFor,
    required this.allMembers,
    required this.children,
    required this.devices,
  });

  /// The family this context belongs to.
  final String familyId;

  /// The family record (may be a local canonical reference).
  final GuardianFamily? family;

  /// The verified actor member, or `null` when binding failed closed.
  final FamilyMember? actor;

  /// `true` only when the Trusted Actor Binding verified the authenticated
  /// account to an active local member. Never `true` when `actor` is `null`.
  final bool isVerified;

  /// Permission resolution function. Delegated verbatim to the single
  /// [FamilyAuthorization] matrix (role-based) — never a second mechanism.
  final Set<FamilyPermission> Function(FamilyRole role) permissionsFor;

  /// All members of the family (adults and children).
  final List<FamilyMember> allMembers;

  /// Child members of the family (child isolation view).
  final List<FamilyMember> children;

  /// Device runtime states for the family, keyed by device id.
  final List<ChildDeviceState> devices;

  /// FS-016 — public fail-closed unverified context. Used by the role gate
  /// when binding resolution fails so the gate never decides from a default.
  factory FamilyRuntimeContext.unverified() => FamilyRuntimeContext(
        familyId: '',
        family: null,
        actor: null,
        isVerified: false,
        permissionsFor: const FamilyAuthorization().permissionsFor,
        allMembers: const [],
        children: const [],
        devices: const [],
      );

  /// Permission check for the verified actor, or `false` when unverified.
  bool can(FamilyPermission permission) {
    final a = actor;
    if (a == null || !isVerified) return false;
    return a.isActive && permissionsFor(a.role).contains(permission);
  }
}

/// Resolves the canonical [FamilyRuntimeContext] for a family.
///
/// Resolution order guarantees:
/// 1. The actor is resolved ONLY through [FamilyActorBindingService]
///    (server-sourced UID path, fail-closed).
/// 2. Members, children, and devices are read from the canonical local
///    repositories ([FamilyMembershipRepository], [ChildDeviceRepository]) —
///    never from screen-local assumptions.
/// 3. Permissions are delegated to the single [FamilyAuthorization] matrix.
class FamilyContextResolver {
  const FamilyContextResolver({
    required FamilyActorBindingService actorBinding,
    required FamilyMembershipRepository membership,
    required ChildDeviceRepository deviceRepository,
    FamilyAuthorization? authorization,
  })  : _actorBinding = actorBinding,
        _membership = membership,
        _deviceRepository = deviceRepository,
        _authorization = authorization ?? const FamilyAuthorization();

  final FamilyActorBindingService _actorBinding;
  final FamilyMembershipRepository _membership;
  final ChildDeviceRepository _deviceRepository;
  final FamilyAuthorization _authorization;

  Future<List<ChildDeviceState>> _safeDeviceStates(String familyId) async {
    try {
      return await _deviceRepository.statesForFamily(familyId);
    } catch (_) {
      return const <ChildDeviceState>[];
    }
  }

  /// Resolve the full canonical context. Never throws on binding failures —
  /// an unverified context is returned instead (fail-closed, not fail-open).
  Future<FamilyRuntimeContext> resolve(String familyId) async {
    final normalizedFamilyId = familyId.trim();
    if (normalizedFamilyId.isEmpty) {
      return _unverified();
    }

    // Canonical actor resolution (fail-closed).
    final bindingResult =
        await _actorBinding.resolveForFamily(normalizedFamilyId);
    final actor =
        bindingResult.isVerified ? bindingResult.binding?.member : null;

    // Canonical members (all), canonical children (role-filtered),
    // canonical device runtime states.
    final allMembers = await _membership.membersForFamily(normalizedFamilyId);
    final children = allMembers
        .where((m) => m.isActive && m.role == FamilyRole.child)
        .toList(growable: false);

    final List<ChildDeviceState> devices =
        await _safeDeviceStates(normalizedFamilyId);

    final verified = bindingResult.isVerified && actor != null;
    return FamilyRuntimeContext(
      familyId: normalizedFamilyId,
      family: null,
      actor: actor,
      isVerified: verified,
      permissionsFor: _authorization.permissionsFor,
      allMembers: allMembers,
      children: children,
      devices: devices,
    );
  }

  FamilyRuntimeContext _unverified() {
    return FamilyRuntimeContext(
      familyId: '',
      family: null,
      actor: null,
      isVerified: false,
      permissionsFor: _authorization.permissionsFor,
      allMembers: const [],
      children: const [],
      devices: const [],
    );
  }
}

/// Canonical Riverpod exposure. Screen code consumes [familyRuntimeContextProvider]
/// instead of composing per-screen repository reads.
final familyRuntimeContextProvider =
    FutureProvider.family<FamilyRuntimeContext, String>((ref, String familyId) {
  final binding = ref.watch(familyActorBindingServiceProvider);
  final membership = ref.watch(familyMembershipRepositoryProvider);
  final devices = ref.watch(childDeviceRepositoryProvider);
  return FamilyContextResolver(
          actorBinding: binding,
          membership: membership,
          deviceRepository: devices)
      .resolve(familyId);
});

/// Canonical device context answering the Phase 18 device questions
/// (WHO owns it, WHICH family, IS active, revocation state, child-or-not,
/// which policy applies) from the single device record and the membership
/// repository — device state is never duplicated elsewhere.
class DeviceRuntimeContext {
  const DeviceRuntimeContext({
    required this.state,
    required this.member,
    required this.memberRole,
    required this.isChildDevice,
    required this.isActive,
  });

  /// The single canonical device runtime state.
  final ChildDeviceState state;

  /// The member that owns this device (device identity != person identity).
  final FamilyMember? member;

  /// The owning member's role (parent / child / spouse / co-parent).
  final FamilyRole? memberRole;

  /// `true` when the owning member is a child — drives policy resolution.
  final bool isChildDevice;

  /// `true` when the device is enrolled and the owning member is active
  /// (revocation of either closes the device).
  final bool isActive;
}

/// Resolves [DeviceRuntimeContext] for a device inside a family.
class DeviceContextResolver {
  const DeviceContextResolver({
    required ChildDeviceRepository deviceRepository,
    required FamilyMembershipRepository membership,
  })  : _deviceRepository = deviceRepository,
        _membership = membership;

  final ChildDeviceRepository _deviceRepository;
  final FamilyMembershipRepository _membership;

  Future<DeviceRuntimeContext?> resolve({
    required String familyId,
    required String deviceId,
  }) async {
    final ChildDeviceState? state;
    try {
      final all = await _deviceRepository.statesForFamily(familyId);
      state = all.where((s) => s.deviceId == deviceId).firstOrNull;
    } catch (_) {
      return null;
    }
    if (state == null || state.familyId != familyId) return null;

    final FamilyMember? member;
    try {
      member = await _membership.memberForFamily(
          familyId: state.familyId, memberId: state.memberId);
    } catch (_) {
      return null;
    }

    return DeviceRuntimeContext(
      state: state,
      member: member,
      memberRole: member?.role,
      isChildDevice: member?.role == FamilyRole.child,
      isActive: _isEnrolled(state) && member != null && member.isActive,
    );
  }

  /// Revocation (and never-linked) states close the device; every state
  /// past enrollment (including offline and restricted) keeps it enrolled
  /// as long as the owning member is active.
  bool _isEnrolled(ChildDeviceState state) =>
      state.lifecycle != ChildDeviceLifecycle.unlinked &&
      state.lifecycle != ChildDeviceLifecycle.pairingPending &&
      state.lifecycle != ChildDeviceLifecycle.revoked;
}

/// Canonical Riverpod exposure for device context.
final deviceRuntimeContextProvider = FutureProvider.family<
    DeviceRuntimeContext?,
    ({
      String familyId,
      String deviceId
    })>((ref, ({String familyId, String deviceId}) scope) {
  final devices = ref.watch(childDeviceRepositoryProvider);
  final membership = ref.watch(familyMembershipRepositoryProvider);
  return DeviceContextResolver(
          deviceRepository: devices, membership: membership)
      .resolve(familyId: scope.familyId, deviceId: scope.deviceId);
});
