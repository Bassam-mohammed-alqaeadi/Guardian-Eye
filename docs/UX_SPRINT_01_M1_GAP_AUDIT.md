# Experience Sprint 01 v2 — Milestone M1 Gap Audit

**Project:** Guardian Eye Pro
**Milestone:** M1 — App Shell + Canonical Navigation
**Baseline commit:** `ff432a0` (master)
**Author:** Manus AI
**Date:** August 13, 2026
**Related:** `UX_SPRINT_01_M1_COMPLETION_REPORT.md`, `UX_SPRINT_01_M1_TEST_EVIDENCE.md`, `UX_SPRINT_01_V2_RECONCILIATION.md`

This audit compares the M1 specification against the delivered work. Its purpose is to state precisely what was met, what was met with a deferral noted, and what remains for later milestones — so that M1 can be declared GREEN without hiding unresolved items, and so that M2/P1 planning begins from a truthful inventory.

## 1. Specification Coverage

| Spec item | Requirement | Verdict | Notes |
|---|---|---|---|
| 1. App theme | Replace inline `ThemeData` with `AppTheme.lightTheme`/`darkTheme`, preserve Cairo + Material3, no second theme system | **Met** | `guardian_app.dart` now consumes the canonical theme; `app_theme.dart` and `app_colors.dart` untouched |
| 2. Canonical navigation | One navigation system; GoRouter repaired, not duplicated; no obsolete screens reachable | **Met** | `app_router.dart` is the single routing truth; 9 routes, all live screens; dead prototypes retire to a localized not-found page |
| 3. Navigation IA | Product voice (Home/Family/Safety/Timeline/Settings), no technical module names in primary nav; authorization via `FamilyRuntimeContext` → `FamilyAuthorization`, no local role checks | **Met** | Dashboard buttons relabeled in product voice; gated buttons disabled rather than hidden; authorization unchanged |
| 4. Settings/session | Move session/language controls out of the family-home app bar into a real settings surface; no Firebase terminology in primary nav | **Met** | New `SettingsScreen` (`/settings`); account/session entry pushes `FirebaseSessionScreen`; session label is «الحساب والجلسة» |
| 5. RTL/LTR shell | Coherent Arabic RTL / English LTR: navigation order, directional icons, back affordance, alignment | **Met** | Directionality derived from locale at the shell; back affordance is the platform `AppBar` back arrow, which Directionality flips automatically; no manual left/right positioning used |
| 6. Dead-path retirement | Verify references before deleting welcome/parent-dashboard/child-profile screens and obsolete routerProvider | **Met** | Project-wide grep confirmed zero live references before deletion |
| 7. Shneiderman rules (M1 checks) | Consistency, universal usability, informative feedback, dialog closure, error prevention, easy reversal, user control, low memory load | **Met with one noted nuance** | Settings language toggle shows a «حُفظت الإعدادات» SnackBar (informative feedback, dialog closure); the back action reverses settings push (easy reversal); the not-found page always offers a safe home return (user control, error prevention). **Nuance:** the settings screen currently has no sheet/dialog operations beyond navigation, so sheet/dialog closure within settings is not yet exercised — no dialog exists to close |
| 8. Accessibility | Dynamic text scaling, semantic labels, contrast, touch targets, reduced motion, AR/EN semantics, semantic labels on icon-only controls | **Met with one deferral** | The settings icon carries both `tooltip` and `semanticLabel`; semantic labels verified present in AR/EN. **Deferral:** a real-device pass for dynamic text scaling and reduced-motion compatibility was not run; emulator widget tests cannot fully exercise dynamic scaling |
| 9. Tests | Baseline captured; post-implementation analyze/test/emulator; focused widget tests for shell, RTL, LTR, navigation, settings, unauthorized nav, dead routes; no weakening of existing tests | **Met** | Baseline 80/80 preserved; 9 new M1 widget tests all passing; emulator 15/15 + 2/2 |
| 10. Visual quality | Calm, warm, premium, minimal, family-centered, trustworthy; avoid admin-dashboard look | **Met at M1 scope** | The shell now reads as a product shell. Full visual-polish verification (screenshots, motion, illustration) belongs to P3 and is not part of M1 |
| 11. Change boundary | No changes to runtime context, actor binding, authorization, policy engine, SQLite, outbox, rules, functions, Firebase config | **Met** | Verified by file-level diff; only shell/routing/settings/localization/test files touched |

## 2. One Test Change Disclosed

The pre-existing widget test `Firebase account entry states that sync is unavailable when unconfigured` was updated because M1 deliberately removed the Firebase icon from the family-home app bar that its finder referenced. The test's semantic assertion was preserved — it still opens the settings surface, enters the account/session entry, and asserts the same `FirebaseSessionScreen` unconfigured state. This is a fixture-path update forced by the spec (settings controls moved out of the app bar), not a weakening: the same product behavior is asserted through the new navigation path.

## 3. Known Gaps and Deferrals

**Gap A — Settings surface depth (deferred to P1).** The settings surface currently hosts account/session, language, and a permissions entry. The reconciliation planned `appPreferences` (including theme mode choice) as part of the same surface; the theme mode today follows the system setting. The key and entry point for app preferences were added to localization, but the preference UI is not yet built. Deferring to P1 avoids inflating M1 beyond the shell's foundation.

**Gap B — First-run journey (deferred, M2 scope).** The shell assumes a user lands on the family home; first-run onboarding, family setup, and child-home journeys are explicitly out of M1's stop-after boundary.

**Gap C — Motion, iconography, illustration verification (deferred to P3).** Widget tests confirm widget-level behavior but not the visual feel of the shell on real hardware. Screenshot-based verification against the design system is planned for P3.

**Gap D — Multi-role navigation smoke (partially validated).** The shell was verified for parent and unverified-actor states (disabled safety actions). Co-parent and child actor states were not independently widget-tested in M1; they are exercised indirectly through the preserved domain test suite, and explicit multi-role shell tests can be added in P1.

**Non-claim:** M1 does not claim any redesign of dashboard metrics, policy screens, exception flow, or timeline. Those surfaces were reached through the canonical router but not redesigned.

## 4. Remaining Blockers for M2/P1

No blocker prevents M2 from starting. The deferrals above are scheduled work, not defects. The only pre-condition is the user's gate approval for the M1 commit (push is withheld pending approval, per project rules).

## 5. Final State

**M1 GREEN.** All eleven specification sections are met or explicitly deferred with rationale. No unresolved defects. No boundary violations. Evidence in `UX_SPRINT_01_M1_TEST_EVIDENCE.md`.
