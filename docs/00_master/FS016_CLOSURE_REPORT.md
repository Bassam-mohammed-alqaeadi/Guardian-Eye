# FS-016 — Startup & State Machine: Closure Report

**Author:** Manus AI
**Branch:** `feature/design-system-integration`
**Date:** August 21, 2026
**Commits:** `edffe43` (implementation), `1b03c34` (wiring, l10n, discovery artifacts)
**Preceding checkpoint:** `18ec4fa` (HEAD before this batch)
**Verification status:** **CLOSED-CODE-VERIFIED** (Flutter tests + static analysis). This status is not SERVER-VERIFIED, EMULATOR-VERIFIED, DEVICE-VERIFIED, or PRODUCTION-VERIFIED — no real device, emulator, or deployment was involved, and nothing was pushed to origin or deployed.

---

## 1. Scope delivered

FS-016 is defined in the master plan as the app's cold-start experience and subscription-aware feature gating. The discovery report (PHASE7-DISCOVERY-CONFIRMED) identified that the codebase had no splash screen, no role gate, no `/whats-new`, no offline startup card, and no onboarding-completion persistence. This batch closes all five gaps with pure additive changes on top of the FS-010 baseline (646/646 Flutter tests green), with the FS-010 regression suite remaining untouched.

| Plan item | Delivery | Route | Evidence |
| --- | --- | --- | --- |
| ST-001 splash | First-run splash shown **exactly once per install**, pushed after the first frame so it never delays first paint; persistence failure skips it fail-soft | `/splash` (`startupSplash`) | `guardian_app.dart` entry trigger; `onb_onboarding_seen` key in `startup_state_service.dart`; `test(fs016_startup_test.dart)` "the seen key" test |
| ST-001 role gate | Honest `RoleGateScreen` with four mutually exclusive honest states — signed out, unverified binding (fail-closed), parent-type gate, direct landings — driving every decision through `FamilyRuntimeContext`; the role logic is never re-implemented locally | `/role` (`roleGate`) | `role_gate_service.dart` (`decideRoleGate` pure function + 10 matrix tests); `startup_screens.dart` |
| ST-002 feature lock | Reuse layer established: `RoleGateScreen` and the startup surfaces compose the existing entitlements/subscription providers and `GuardianOfflineBanner`; ST-002's inline lock card will be built on the same primitives in a future dedicated batch (this batch does not build a paywall UI) | — | `whats_new_widgets.dart`, `startup_widgets.dart` primitive reuse |
| ST-003 offline startup | Offline freshness card (last successful sync stamp + manual sync CTA) is embedded in the role gate and the whats-new screen and is reusable by any cold-start surface; `GuardianOfflineBanner` remains untouched | — | `startup_widgets.dart` offline card; existing `GuardianOfflineBanner` preserved |
| ST-004 role landings | Canonical `ChildLandingWrapper` over the existing child vertical; child and spouse members bypass the gate entirely (honest direct landings) | `/child/:familyId/:childId/landing` (`childLanding`); spouse lands on harmony (gate decision documented) | `startup_screens.dart` wrapper; `decideRoleGate` child/spouse tests; legacy `/child/:familyId/:childId` detail route untouched |
| ST-005 what's new | `WhatsNewScreen` with per-version cards and per-version dismissal persistence over `app_identity`, reachable from settings; dismissed versions persist across launches | `/whats-new` (`whatsNew`) | `whats_new_screen.dart`, `whats_new_widgets.dart`; persistence tests ("dismissedVersions accumulates", "whatsNewDismissedFor", "dismissal per version") |

## 2. Implementation facts

The startup state machine (`startup_state_service.dart`, 220 lines) exposes `OnboardingPersistenceService` over the existing `app_identity` table (no migration — reuse of the established key-value store), `AppStartupSnapshot` with an honest `gateReady` predicate (only a verified, membership-configured actor may pass), and the four new persistence keys `onb_seen`, `onb_selected_role`, `onb_selected_actor`, `onb_whats_new_dismissed_for`, `onb_whats_new_dismissed_versions`. The role-gate decision service (`role_gate_service.dart`, 135 lines) is a pure function plus a persistence provider; it imports `FamilyAuthorization` and `FamilyRuntimeContext` directly, so the gate inherits any future permission-matrix change without touching the gate. `FamilyRuntimeContext.unverified()` was added to `family_context_provider.dart` as a public fail-closed constructor — the gate's one structural dependency on the domain layer.

The l10n remediation migrated all 24 raw strings in `FirebaseSessionScreen` (the only screen with AR-hardcoded copy) to `l10n.t()` keys, added approximately 83 AR/EN key-value pairs, and the diff shows **zero deletions** in `app_localizations.dart` — no existing key was altered. `settings_screen.dart` gained a single additive whats-new tile after the chat entry.

## 3. Verification evidence

| Check | Result |
| --- | --- |
| New FS-016 focused suite (`test/fs016_startup_test.dart`) | **136/136 green** — pure decision matrix, real `GuardianDatabase.forTesting` app_identity persistence, l10n completeness (every used key exists in both AR and EN), honest snapshot gates |
| Full Flutter regression (`ls test/*.dart` minus headless_validation/test_database) | **646/646 green** (baseline grew from 510 to 646 with interim phase files; no pre-existing test was modified) |
| `flutter analyze` | 0 errors, 0 warnings (461 pre-existing infos unrelated to this batch) |
| `dart format` | Applied to all 13 changed/new lib+test files |
| Pre-commit audit | No secrets, no unrelated files, no deletions of existing behavior, docs-only `PHASE4_DELETION_EXPORT_CONTRACT.md` and `PHASE7_DISCOVERY_REPORT.md` added alongside |

## 4. Honest-state and privacy properties

The gate is fail-closed in every unresolved state: an unverified binding, a revoked or invited member, and an unlinked account all produce honest non-gate states rather than silently defaulting to a role. The first-run splash cannot break the shell — persistence errors skip it, and the role gate remains the standing guard on every path. All FS-016 data lives in `app_identity` (local-only, key-value), so the Phase 4 local privacy contract is unaffected: nothing new enters `retainedTables` or `purgedTables`, and no family data is written by this batch.

## 5. Known limitations and next steps

ST-002's inline feature-lock card itself is a **gap-closure decision left for a dedicated batch** — the plan's ST-002 "upgrade gate" UI was not built, only the reuse contract (entitlements providers, offline banner) confirmed and wired into the surfaces that need it. The `childLanding` route covers the child vertical; the spouse landing currently resolves to the harmony dashboard through the gate decision but the harmony route composition is inherited from the existing `CoupleRoleScreen` and should be re-verified at first device validation. Real-device validation (DEVICE-VERIFIED) of the splash timing and role-gate transitions remains outstanding. Per the phase contract, **FS-014 is not touched by this batch** — its first-run screens will mount on the gate and landings built here.

**Final status: CLOSED-CODE-VERIFIED.** Nothing pushed to origin; awaiting user approval.
