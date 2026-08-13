# Experience Sprint 01 v2 — Milestone M1 Test Evidence

**Project:** Guardian Eye Pro
**Milestone:** M1 — App Shell + Canonical Navigation
**Baseline commit:** `ff432a0` (master)
**Author:** Manus AI
**Date:** August 13, 2026
**Environment:** Ubuntu 24.04 (amd64) sandbox, Flutter SDK at `/opt/flutter/bin`, package `com.guardianeye.app`, Firebase project `manus-guardian`

Gate honesty rule: every result below was observed directly during this session. Nothing is claimed from memory or expectation.

## 1. Baseline (captured before M1 changes)

| Gate | Baseline result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 80/80 pass |
| Firestore emulator | 15/15 pass |
| Functions emulator | 2/2 pass |

## 2. Post-Implementation Gates (observed August 13, 2026)

### 2.1 Static analysis

```
$ flutter analyze
Analyzing guardian_eye...
No issues found! (ran in ...)
```

Result: **0 issues.**

### 2.2 Full Flutter test suite

```
$ flutter test
00:15 +89: /home/ubuntu/guardian_eye/test/m1_shell_test.dart: M1 shell settings has account/session, language and permissions entries
00:15 +89: All tests passed!
```

Result: **89/89 pass** — the original 80 tests plus 9 new M1 tests in `test/m1_shell_test.dart`.

### 2.3 New M1 widget tests (`test/m1_shell_test.dart`) — all passing

| # | Test | Verified |
|---|---|---|
| 1 | renders the family home with the canonical Cairo theme | Cairo font family present in active theme |
| 2 | Arabic locale drives a right-to-left shell | `TextDirection.rtl` |
| 3 | English locale drives a left-to-right shell | `TextDirection.ltr` |
| 4 | navigation entry points live on the family home and all use the canonical router | grouped nav buttons, `context.push` routes |
| 5 | settings language toggle updates the shell locale and feedback appears | Arabic → English segment, «حُفظت الإعدادات» confirmation |
| 6 | an unverified actor gets disabled safety actions rather than dead ends | «إدارة السياسات» `onPressed` is `null` via `FamilyRuntimeContext` delegation |
| 7 | dead routes land on the not-found page instead of prototype screens | `/child-profile` → «الصفحة غير موجودة» + «العودة إلى الشاشة الرئيسة» |
| 8 | unknown deep links also land on the not-found page | `/welcome` → not-found page |
| 9 | settings has account/session, language and permissions entries | «الحساب والجلسة», segmented language control, permissions entry |

### 2.4 Firebase emulator validation (`./tool/run_firebase_emulator_tests.sh`)

Run concluded at approximately 11:08 (GMT+3), August 13, 2026, with clean emulator startup and shutdown:

```
# Firestore rules
# pass 15
# fail 0
# cancelled 0
# skipped 0

# Functions (emulator)
# pass 2
# fail 0
# cancelled 0
# skipped 0
✔  Script exited successfully (code 0)
```

Result: **15/15 Firestore + 2/2 Functions.**

## 3. Existing-Test Integrity

No existing test was removed or weakened. One pre-existing widget test (`Firebase account entry states that sync is unavailable when unconfigured` in `test/widget_test.dart`) had its navigation fixture updated: the M1 spec required removing the Firebase icon from the family-home app bar (settings controls move into the settings surface), so the test now opens settings → account/session entry and asserts the identical semantic condition — the `FirebaseSessionScreen` reports sync unavailable when Firebase is unconfigured. The assertion and its meaning are unchanged; only the path changed, which is precisely the behavior M1 implemented.

## 4. Git State

Working tree contains only the M1 scope: modified `guardian_app.dart`, `dashboard_screen.dart`, `app_localizations.dart`, `widget_test.dart`; new `router/app_router.dart`, `screens/settings_screen.dart`, `test/m1_shell_test.dart`, three docs; deleted `welcome_screen.dart`, `parent_dashboard_screen.dart`, `child_profile_screen.dart`, `providers/router_provider.dart`. No Firebase configuration, rules, functions, or domain logic changed. The `phase17-stable-checkpoint` branch was not touched.

## 5. Final Gate Verdict

| Gate | Verdict |
|---|---|
| `flutter analyze` | GREEN (0 issues, observed) |
| Flutter test suite | GREEN (89/89, observed) |
| M1 widget tests | GREEN (9/9, observed) |
| Existing tests unchanged semantics | GREEN (observed, disclosed) |
| Firestore emulator | GREEN (15/15, observed) |
| Functions emulator | GREEN (2/2, observed) |
| Change boundary respected | GREEN (diff reviewed) |

**M1 GREEN.** Evidence complete. Push to GitHub is withheld pending user gate approval.
