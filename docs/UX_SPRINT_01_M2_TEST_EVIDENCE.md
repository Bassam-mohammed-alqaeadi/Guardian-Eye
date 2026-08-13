# Experience Sprint 01 v2 — Milestone M2 Test Evidence

**Project:** Guardian Eye Pro
**Milestone:** M2 — Core Parent Experience / Dashboard Foundation
**Baseline commit:** `2a78755` (master) — M1 GREEN checkpoint
**Author:** Manus AI
**Date:** August 13, 2026
**Environment:** Ubuntu 24.04 (amd64) sandbox, Flutter SDK at `/opt/flutter/bin`, package `com.guardianeye.app`, Firebase project `manus-guardian`

Gate honesty rule: every result below was observed directly during this session. Nothing is claimed from memory or expectation.

## 1. Baseline (captured before M2 changes)

| Gate | Baseline result |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | 89/89 pass |
| Firestore emulator | 15/15 pass |
| Functions emulator | 2/2 pass |

## 2. Post-Implementation Gates (observed August 13, 2026)

### 2.1 Static analysis

```
$ flutter analyze
Analyzing guardian_eye...
No issues found! (ran in 3.7s)
```

Result: **0 issues.** (During the diagnostic pass the analyzer reported three `unnecessary_non_null_assertion` warnings at `dashboard_screen.dart` lines 545/554 inside the new `_ChildOverview`; these were resolved by replacing the `!` assertions with a local non-null `lifecycleName` copy, after which the analyzer is clean.)

### 2.2 Full Flutter test suite

```
$ flutter test --reporter compact
...
00:15 +89: /home/ubuntu/guardian_eye/test/m1_shell_test.dart: M1 shell settings has account/session, language and permissions entries
00:15 +89: All tests passed!
```

Result: **89/89 pass** — the original 80 tests plus the 9 M1 shell tests, identical in outcome to the baseline.

### 2.3 Regression diagnosis and repair (M1 test that regressed under M2)

During implementation one M1 shell test regressed: `an unverified actor gets disabled safety actions rather than dead ends` threw `StateError: Bad state: No element` when locating the `إدارة السياسات` OutlinedButton. Full-tree dumps (`rootElement.toStringDeep()`) confirmed the button **was rendered** — `FamilyRuntimeContext` delegation behaved correctly (no ErrorWidget in the tree, no binding exception). The failure was caused by `ListView` **lazy rendering** in widget tests: after M2 added the identity, signal, and child-overview cards above the safety-policies group, the button moved below the visible viewport and was no longer built during the test pump.

The repair preserves the test's exact semantic assertion (unverified actor → disabled, not dead) and adds a scroll step:

```dart
await tester.scrollUntilVisible(
    find.text('إدارة السياسات'), 100);
await tester.pumpAndSettle();
final managePolicies = tester.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, 'إدارة السياسات'));
expect(managePolicies.onPressed, isNull);
```

Temporary debug markers injected during diagnosis (text markers, a deliberate `throw StateError` probe) were removed from `dashboard_screen.dart` before this gate; no marker or probe survives in the working tree. A temporary diagnostic test file (`test/dump_test.dart`) was created during diagnosis and deleted before the gate. Debug print loops injected into `test/m1_shell_test.dart` were also removed.

### 2.4 New-data integration verification

The widget tree was captured directly during the regression diagnosis and verified to contain the full M2 surface: `حديثة` (freshness indicator), `إشارة السلامة` (signal heading), child `إضافة طفل` and `ربط جهاز` entry buttons, and the settings `IconButton` — confirming `_FamilyIdentityCard`, `_SafetySignalCard`, and `_NavGroup` all build against resolved providers with no fabricated data.

### 2.5 Firebase emulator validation (`./tool/run_firebase_emulator_tests.sh`)

Run concluded with clean emulator startup and shutdown:

```
# Firestore rules
# tests 15
# pass 15
# fail 0
# cancelled 0
# skipped 0

# Functions (emulator)
# tests 2
# pass 2
# fail 0
# cancelled 0
# skipped 0
✔  Script exited successfully (code 0)
```

Result: **15/15 Firestore + 2/2 Functions.**

## 3. Existing-Test Integrity

No existing test was removed or weakened. The only change to an existing test is the `scrollUntilVisible` addition described in §2.3, which preserves the assertion verbatim (`onPressed` is `null` for the unverified actor). Temporary diagnostic artifacts were created and deleted within the same session.

## 4. Git State

Working tree contains only the M2 scope: modified `dashboard_screen.dart`, `guardian_providers.dart`, `safety_repositories.dart`, `app_localizations.dart`, `m1_shell_test.dart` (test repair); `analysis_options.yaml` and `.flutter-plugins-dependencies` carry pre-existing modifications from an earlier session unrelated to M2 (noted for honesty). No Firebase configuration, rules, functions, or domain logic changed. The `phase17-stable-checkpoint` branch was not touched.

## 5. Final Gate Verdict

| Gate | Verdict |
|---|---|
| `flutter analyze` | GREEN (0 issues, observed) |
| Flutter test suite | GREEN (89/89, observed) |
| M1 widget tests | GREEN (9/9, observed) |
| Regression diagnosis and repair | GREEN (root cause evidenced, fix semantic-preserving) |
| Existing tests unchanged semantics | GREEN (observed, disclosed) |
| Firestore emulator | GREEN (15/15, observed) |
| Functions emulator | GREEN (2/2, observed) |
| Change boundary respected | GREEN (diff reviewed) |

**M2 GREEN.** Evidence complete. Push to GitHub is withheld pending user gate approval.
