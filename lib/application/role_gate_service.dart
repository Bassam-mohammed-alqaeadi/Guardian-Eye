/// FS-016 — Role gate decision service.
///
/// Design laws:
/// 1. Role decisions are derived from the canonical [FamilyRuntimeContext]
///    and the single [FamilyAuthorization] matrix — no role logic is
///    duplicated in the router or widgets.
/// 2. Eligibility is computed from the verified actor only. An ineligible
///    actor (child, unverified, revoked) is never offered a role selection.
/// 3. The gate never silently defaults: when no role has been persisted, or
///    the persisted role no longer matches the verified actor, the gate
///    must be shown again (or the honest unverified state rendered).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/guardian_models.dart';
import 'family_context_provider.dart';
import 'guardian_providers.dart';
import 'startup_state_service.dart';

/// The decision the role gate exposes to the UI for one resolved context.
enum RoleGateDecision {
  /// Verified parent-type actor with no (or stale) persisted role — gate
  /// must show. The actor explicitly selects a role; nothing is defaulted.
  showGate,

  /// Verified actor whose persisted role still matches this actor — land
  /// directly on the role landing.
  landWithRole,

  /// Verified child — land directly on the child surface (no gate).
  landAsChild,

  /// Verified spouse/couple — land directly on the harmony surface.
  landAsSpouse,

  /// Actor exists but the Trusted Actor Binding did not verify this
  /// account to an active member — honest unverified state.
  unverified,

  /// No authenticated account at all.
  signedOut,
}

/// FS-016 — canonical role eligibility. Parent-type roles may select and be
/// persisted; child and spouse have fixed canonical landings and are never
/// offered a choice. Child isolation is enforced by the role itself — a
/// child member is never considered gate-eligible.
bool isGateEligibleRole(FamilyRole role) =>
    role == FamilyRole.primaryParent ||
    role == FamilyRole.parent ||
    role == FamilyRole.coParent;

/// The gate decision for a resolved runtime context, given the currently
/// persisted role and actor id. Pure function — trivially testable.
RoleGateDecision decideRoleGate({
  required FamilyRuntimeContext context,
  required bool isAuthenticated,
  required String? persistedRole,
  required String? persistedActorId,
}) {
  if (!isAuthenticated) return RoleGateDecision.signedOut;

  final actor = context.actor;
  if (!context.isVerified || actor == null) return RoleGateDecision.unverified;

  final role = actor.role;
  if (role == FamilyRole.child) return RoleGateDecision.landAsChild;
  if (role == FamilyRole.spouse) return RoleGateDecision.landAsSpouse;
  if (!isGateEligibleRole(role)) return RoleGateDecision.unverified;

  // Parent-type actor: land directly only when a role was already persisted
  // against THIS actor. When the account unlinks from the family the actor
  // id changes, the persisted pair no longer matches, and the gate
  // honestly re-shows.
  if (persistedRole != null && persistedActorId == actor.id) {
    return RoleGateDecision.landWithRole;
  }
  return RoleGateDecision.showGate;
}

/// Resolves the gate decision for the session family: canonical runtime
/// context + persisted onboarding state. The family id is read best-effort
/// from the dashboard (the same honest source the shell uses); until a
/// family resolves the decision is `signedOut` so the UI shows the
/// unauthenticated/unlinked surface.
final roleGateDecisionProvider = FutureProvider<RoleGateDecision>((ref) async {
  final persistence = ref.watch(onboardingPersistenceProvider);
  final dashboard = ref.watch(dashboardProvider);
  final auth = ref.watch(firebaseAuthSessionProvider);

  final session = auth.valueOrNull;
  if (session == null || !session.isAuthenticated) {
    return RoleGateDecision.signedOut;
  }

  final familyId = dashboard.valueOrNull?.family?.id;
  if (familyId == null || familyId.isEmpty) {
    // Authenticated but no family — the gate is not meaningful; the UI
    // routes to the unlinked entry (PD-001 territory, FS-016 only reports).
    return RoleGateDecision.signedOut;
  }

  final context = await ref
      .read(familyRuntimeContextProvider(familyId).future)
      .catchError(
          (Object _, StackTrace __) => FamilyRuntimeContext.unverified());
  final persistedRole = await persistence.selectedRole();
  final persistedActor = await persistence.selectedRoleActorId();

  return decideRoleGate(
    context: context,
    isAuthenticated: session.isAuthenticated,
    persistedRole: persistedRole,
    persistedActorId: persistedActor,
  );
});

/// Cached persisted role/actor so the gate can re-render without re-reading
/// SQLite on every frame. Updated by [persistRoleForActor] after a real
/// write to `app_identity`.
final persistedGateRoleProvider = StateProvider<String?>((ref) => null);
final persistedGateActorProvider = StateProvider<String?>((ref) => null);

/// Persists the gate decision for the verified actor and refreshes the
/// cached providers so the decision stream re-emits on change.
Future<void> persistRoleForActor(
    {required String roleKey,
    required String actorMemberId,
    required WidgetRef ref}) async {
  final persistence = ref.read(onboardingPersistenceProvider);
  await persistence.persistSelectedRole(roleKey, actorMemberId);
  ref.read(persistedGateRoleProvider.notifier).state = roleKey;
  ref.read(persistedGateActorProvider.notifier).state = actorMemberId;
}
