# UX Sprint 01 — M6 Completion Report: Screen-Time Administration

**Date:** 2026-08-13
**Author:** Manus AI
**Milestone:** M6 — parent screen-time policy administration on the real backend contracts

## 1. Scope delivered

M6 delivers the complete parent administration experience for screen-time policies over the existing domain contracts, without modifying the domain, the rules, or the Functions. The work consists of four production files and two test/documentation surfaces.

| Component | File | Role |
|-----------|------|------|
| Screen | `lib/presentation/screens/screen_time_policies_screen.dart` (~1250 lines) | Policy list, effective-decision card, editor bottom sheet, override dialog, exception review |
| Child context integration | `lib/presentation/screens/child_context_screen.dart` | `_ComingSoonSection` replaced by live `_ScreenTimeSection` with manage gating |
| Providers | `lib/application/guardian_providers.dart` | `childPoliciesProvider`, `childOverridesProvider` |
| Router | `lib/presentation/router/app_router.dart` | `/child/:familyId/:childId/policies` |
| Localization | `lib/core/localization/app_localizations.dart` | ~45 keys appended to both Arabic and English maps |
| Tests | `test/m6_policy_administration_test.dart` | 20 tests (18 widget + 2 engine unit) |
| Security evidence | `firebase/tests/deployed_rules_tests.mjs` | 5 tests against the deployed ruleset |

## 2. Behavior delivered

The policy list shows each policy with its schedule, target apps, enabled state, inline enable/disable action, edit action, and honest sync state. Creating or editing a policy runs through a drag-to-resize bottom sheet that validates the name, schedule, and targets before saving through `PolicyRepository`, then displays the resulting `SyncState`. The effective-decision card recomputes `PolicyEngine.resolve` live, showing whether a representative window would be restricted, allowed by override, or unrestricted, with the reason cited. Temporary overrides are granted through a dialog that requires both a target and a bounded duration from fixed chips; indefinite overrides are not possible in the UI. Pending child exception requests surface with an inline approve/deny review that executes the repository's atomic pipeline (expire-if-due, parent check, active-device guard, in-transaction override creation) and invalidates the cached lists. Authorization is enforced per control: the manage bar and all write actions require `managePolicies` (owner/parent/coParent), exception review requires `reviewExceptionRequests`, and the spouse role (Option A) and actors outside the family see honest read-only or unavailable surfaces with no dead ends.

## 3. Evidence gates

All gates passed with direct execution evidence on 2026-08-13: `flutter analyze` 0 errors/0 warnings; full suite 160/160; security regression 17/17; Firestore Emulator 15/15; Functions Emulator 2/2; deployed-rules harness 9/9 (including the 5 new M6 cases). The local and deployed rulesets were verified byte-identical (`e22c310a`) at the start of M6.

## 4. Honest non-claims

1. **No enforcement.** The UI communicates policies as "the configuration the child device should follow." Nothing in M6 measures usage or blocks anything on the child device (M7/M8 territory).
2. **SyncState.synced is not claimed.** Widget tests and UI behavior cover `localOnly`/`queued`; achieving `synced` requires a real signed-in app session and real outbox delivery — **HUMAN ACTION REQUIRED**.
3. **Override expiry guard is client-side.** The deployed ruleset scopes overrides to `parent(familyId)` but does not validate a mandatory `expiresAt`; the invariant is enforced in the repository and the editor, and the harness documents this fact instead of overstating it.
4. **Device linking remains HUMAN ACTION REQUIRED** for any real policy delivery on a physical child device.

## 5. Remaining work (explicitly not started)

M7 (usage measurement and screen-time runs), M8 (device-side enforcement), and real signed-in delivery verification are not started and will not start without explicit user instruction.
