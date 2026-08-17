# UX Sprint 01 v2 — M1 GitHub Checkpoint Report

**Project:** Guardian Eye Pro
**Milestone:** M1 — App Shell + Canonical Navigation
**Author:** Manus AI
**Date:** August 13, 2026

## 1. Push Identity

| Field | Value |
|---|---|
| Repository | `https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git` |
| Branch | `master` (active development baseline) |
| Commit hash | `fb80079` (local) — `fb80079ed8b4120bec79dc769095a3676aa9e1a1` (verified on remote via GitHub API) |
| Commit message | `feat(ux-m1): establish canonical app shell and navigation` |
| Push result | **Success** — `ff432a0..fb80079 master -> master`; remote head confirmed via `gh api repos/.../commits/master` |
| Push method | Standard `git push`; **no force push, no history rewrite** |
| Working tree state | **Clean** — no tracked modifications pending (only `firestore-debug.log`, an emulator debug artifact outside the repository) |

The parent commit was `ff432a0` (the UX Sprint 01 v2 read-only reconciliation report), so the remote history moved forward by exactly one atomic commit.

## 2. Exact Files Included

The commit is a single atomic unit of 14 files changed (809 insertions, 282 deletions):

| Action | File | Role |
|---|---|---|
| Modified | `lib/presentation/guardian_app.dart` | MaterialApp.router shell: canonical theme, locale-driven RTL/LTR, router wiring |
| Modified | `lib/presentation/screens/dashboard_screen.dart` | Product-voice settings entry and grouped canonical navigation; gated actions disabled via runtime context |
| Modified | `lib/core/localization/app_localizations.dart` | AR + EN shell keys (settings, account/session, language, not-found copy) |
| Modified | `test/widget_test.dart` | Fixture path updated to the new settings surface (semantic assertion preserved) |
| Created | `lib/presentation/router/app_router.dart` | Canonical GoRouter: 9 routes, error page, `appRouterProvider` |
| Created | `lib/presentation/screens/settings_screen.dart` | Settings surface: account/session, language toggle, permissions entry |
| Created | `test/m1_shell_test.dart` | 9 M1 widget tests (theme, RTL/LTR, navigation, settings, gating, dead routes) |
| Created | `docs/UX_SPRINT_01_M1_COMPLETION_REPORT.md` | M1 completion report |
| Created | `docs/UX_SPRINT_01_M1_GAP_AUDIT.md` | M1 gap audit with deferrals |
| Created | `docs/UX_SPRINT_01_M1_TEST_EVIDENCE.md` | Direct test evidence for every gate |
| Deleted | `lib/presentation/screens/welcome_screen.dart` | Dead prototype (verified reference-free) |
| Deleted | `lib/presentation/screens/parent_dashboard_screen.dart` | Dead prototype (verified reference-free) |
| Deleted | `lib/presentation/screens/child_profile_screen.dart` | Dead prototype (verified reference-free) |
| Deleted | `lib/presentation/providers/router_provider.dart` | Obsolete router provider |

During review, three generated files that had drifted during `flutter pub get` (`analysis_options.yaml`, `.flutter-plugins-dependencies`, `pubspec.lock`) were reverted to the baseline before commit, keeping the commit strictly within M1 scope.

## 3. Secret Scan

The complete staged diff and all new files were scanned for service-account JSON, private keys (RSA/EC/OpenSSH), client secrets, refresh tokens, passwords, signing keys, and hardcoded API keys. **Result: zero matches.** No secret was present in the commit.

## 4. Boundary Confirmation

The diff was reviewed line-by-line against the change boundary. No line of `FamilyRuntimeContext`, `DeviceRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, the SQLite repositories, the outbox, Firestore rules, Functions, or Firebase configuration (`lib/firebase_options.dart`, `android/app/google-services.json`, `firebase/`, `pubspec.yaml`) was touched. The `phase17-stable-checkpoint` branch remains at its original head (`274e181`) and was not modified.

## 5. Gate Evidence Recap (observed directly this session)

| Gate | Result |
|---|---|
| `flutter analyze` | 0 issues |
| Flutter tests | 89/89 pass |
| M1 widget tests | 9/9 pass |
| Firestore emulator | 15/15 pass |
| Functions emulator | 2/2 pass |

## 6. Closure Statements

- **Phase 17/18 security and runtime architecture: untouched** — confirmed by empty diff on all domain/infrastructure/application trees and Firebase config files.
- **M2 has NOT started** — no first-run, dashboard-redesign, child-home, policy, exception, or timeline work was begun. The workspace is stopped at the M1 checkpoint per the stop-after-M1 boundary.

**M1 GITHUB CHECKPOINT: COMPLETE.** Next step awaits an explicit instruction to begin M2/P1.
