# Phase 18 — Architecture: Canonical Family & Device Runtime Context

**Project:** Guardian Eye Pro · **Author:** Manus AI · **Date:** August 13, 2026

---

## 1. Summary

Phase 18 introduces the **canonical family runtime context** — a single source of truth for family, member, device, and permission state — and integrates it into the dashboard UI. It answers the Phase 18 device-context questions (WHO owns a device, WHICH family it belongs to, IS it active, revocation state, child-or-not, and which policy applies) through one resolver joined to the membership repository, without duplicating device state anywhere. No new authorization mechanism is introduced; all permission checks delegate verbatim to the single `FamilyAuthorization` matrix.

## 2. New Artifact

`lib/application/family_context_provider.dart` contains four classes and two Riverpod providers:

| Artifact | Responsibility |
|---|---|
| `FamilyRuntimeContext` | Immutable value object: `familyId`, `actor`, `isVerified`, `permissionsFor`, `allMembers`, `children`, `devices`, and `can(permission)` |
| `FamilyContextResolver` | Resolves the context: fail-closed actor binding → canonical members/children/devices → delegated authorization |
| `familyRuntimeContextProvider` | `FutureProvider.family<FamilyRuntimeContext, String>(familyId)` |
| `DeviceRuntimeContext` | Immutable value object: `state`, `member`, `memberRole`, `isChildDevice`, `isActive` |
| `DeviceContextResolver` | Joins family-scoped device states with member lookup; family-scoped and revocation-safe |
| `deviceRuntimeContextProvider` | `FutureProvider.family<DeviceRuntimeContext?, (familyId, deviceId)>` |

## 3. Family Context Resolution Contract

`FamilyContextResolver.resolve(familyId)` guarantees the following resolution order:

1. **Actor resolution ONLY through `FamilyActorBindingService.resolveForFamily`** (server-sourced UID path, fail-closed). An unbound or child-role account yields `actor: null`, `isVerified: false`.
2. **Members, children, and devices are read from the canonical local repositories** (`FamilyMembershipRepository.membersForFamily`, `ChildDeviceRepository.statesForFamily`) — never from screen-local assumptions. Children are derived as active members with `role == FamilyRole.child`.
3. **Permissions delegate to the single `FamilyAuthorization` matrix.** `FamilyRuntimeContext.can(permission)` returns `false` whenever `actor` is null, unverified, or inactive; otherwise it consults `permissionsFor(actor.role)`.

Empty or whitespace family IDs return a closed unverified context rather than throwing. Repository exceptions during device-state or member reads are caught and degraded to empty/closed views rather than surfacing exceptions to the UI (the actor binding itself may still fail closed upstream).

## 4. Device Context Resolution Contract

`DeviceContextResolver.resolve(familyId, deviceId)` answers the device questions from **one canonical record** plus the membership repository:

- **WHO owns it:** `state.memberId` joined with `membership.memberForFamily(familyId, memberId)` — device identity remains separate from person identity; nothing infers ownership from local primary-parent rows.
- **WHICH family:** the device state is looked up inside the supplied family scope; a device found under a different family scope returns `null` (cross-family rejection).
- **IS active / revocation state:** `_isEnrolled` classifies `unlinked`, `pairingPending`, and `revoked` lifecycles as *closed*; every lifecycle past enrollment — including `offline` and `restricted` — keeps the device enrolled as long as the owning member is active. Revocation of the member closes the device too (`member.isActive`).
- **Child-or-not:** derived from `member?.role == FamilyRole.child`.
- **Which policy applies:** `ChildDeviceState.requiredPolicyVersion` on the canonical state drives `ChildPolicyResolver` staleness decisions (already verified in Phase 17).

An unknown device or a storage/lookup failure returns `null` rather than a fabricated context.

## 5. Provider Graph

```
familyActorBindingServiceProvider   ──┐
familyMembershipRepositoryProvider ──┼── FamilyContextResolver ──▶ familyRuntimeContextProvider (familyId)
childDeviceRepositoryProvider    ──┘         │
                                             └── UI (dashboard_screen.dart)
childDeviceRepositoryProvider    ──┐
familyMembershipRepositoryProvider ─┤── DeviceContextResolver ──▶ deviceRuntimeContextProvider ((familyId, deviceId))
```

The providers reuse the repository providers already exported by `lib/application/guardian_providers.dart`; no overrides are required because the resolver consumes the standard repository instances. Screens that previously composed per-provider reads (actor binding + authorization + member lists) now consume the two canonical providers.

## 6. Dashboard Integration

`lib/presentation/screens/dashboard_screen.dart` (lines ~140–150) was changed as follows:

```dart
// Phase 18: single canonical family runtime context.
final runtime = ref.watch(familyRuntimeContextProvider(familyId));
final FamilyMember? actor = runtime.valueOrNull?.actor;
bool can(FamilyPermission permission) =>
    runtime.valueOrNull?.can(permission) ?? false;
final verifiedActor = runtime.valueOrNull?.isVerified ?? false;
```

The previous per-screen composition (`ref.watch(familyActorBindingProvider)` + local `const FamilyAuthorization()` + `authorization.hasPermission`) was removed, eliminating the duplicated authorization reconstruction. The `actor?.id` handoff to child screens (e.g., `FamilyMembersScreen` `actorMemberId`) is preserved. `flutter analyze` remains at 0 issues and all 80 tests pass after integration.

## 7. Fail-Closed Semantics (unchanged, verified)

- `FamilyActorBindingService` explicitly rejects child-role members (`remoteChildIdentity` / `localChildIdentity` failure) — children can **never** be verified actors.
- Unbound accounts (signed in but no membership for the UID) resolve to an unverified context.
- `DeviceContextResolver` returns `null` for unknown devices and cross-family lookups.
- Offline lifecycle (`ChildDeviceLifecycle.offline`) does **not** close the device — only `unlinked`, `pairingPending`, and `revoked` do.
- Timeline labels, outbox sync states, policy delivery idempotency, and exception-approval override semantics are unchanged from Phase 17 and were verified present.

## 8. Scope Boundaries

| In scope (Phase 18) | Out of scope (explicitly not modified) |
|---|---|
| Canonical family/device context providers | Firebase configuration (byte-identical, gitignored) |
| Dashboard consumption of canonical context | Domain/security/business logic files |
| 7 new tests covering the resolvers | Firestore rules / Cloud Functions (unchanged; emulator tests re-validated) |
| Documentation (this set) | Firebase deployment, Blaze, new resources |

Physical-device and production-Firebase validation are classified **HUMAN ACTION REQUIRED** (see `PHASE_18_HUMAN_ACTION_REQUIRED.md`).
