# UX SPRINT 01 — M3 TEST EVIDENCE

**Document type:** Test evidence (Section 28 requirement of the M3 mission brief)
**Scope:** Experience Sprint 01, Milestone M3 — Child Context Vertical
**Date:** 2026-08-13 (evidence collected between 13:20 and 13:35 UTC)
**Author:** Manus AI

All results below were produced directly in the sandbox environment. No value is inferred; each row corresponds to an executed command whose output was captured.

## 1. Static Analysis

| Check | Command | Result |
|---|---|---|
| Full-project analyzer | `flutter analyze` | **No issues found** (0 errors, 0 warnings, 0 infos across lib/ and test/) |

## 2. Unit Tests — Child Context Data Layer

File: `test/m3_child_context_unit_test.dart` — **8/8 PASS**

| # | Scenario | Verdict |
|---|---|---|
| 1 | State mapping: active lifecycle → correct `ChildDeviceState` shape | PASS |
| 2 | State mapping: unlinked → no-device snapshot | PASS |
| 3 | Snapshot composition: identity + device + usage join correctly | PASS |
| 4 | Safety: unacknowledged family incidents map into recent incidents | PASS |
| 5 | Safety: calm vs attention classification from incident list | PASS |
| 6 | Offline: cached `lastSyncAt` preserved verbatim | PASS |
| 7 | Offline: missing device → honest empty (no fabricated zero) | PASS |
| 8 | Authorization: null actor → no-action snapshot | PASS |

All eight tests run against the real SQLite schema (`openTestDatabase` in `setUpAll`) with deterministic stub repositories, so the provider chain is identical to production.

## 3. Widget Tests — Child Context Screen and Navigation

File: `test/m3_child_context_test.dart` — **12/12 PASS**

| # | Scenario (per the M3 brief) | Verdict |
|---|---|---|
| 1 | Loading state shows progress until data arrives | PASS |
| 2 | Loaded child renders identity, device, and activity | PASS |
| 3 | Offline cached child shows sync time verbatim | PASS |
| 4 | Offline uncached child shows honest empty state | PASS |
| 5 | Child not found surfaces the honest missing-child error | PASS |
| 6 | Unauthorized actor sees verification lines, no dead ends | PASS |
| 7 | Error state offers an honest retry | PASS |
| 8 | Safety state distinguishes calm from attention | PASS |
| 9 | Recent incidents empty state is honest | PASS |
| 10 | Arabic locale drives a right-to-left surface | PASS |
| 11 | English locale drives a left-to-right surface | PASS |
| 12 | Navigation to child context is canonical and deep-linkable | PASS |

Notable test mechanics (preserving test honesty):

- Test 1 uses `Completer`-based never-resolving repository stubs (no scheduled timers), proving the loading state persists until data arrives.
- Tests 1, 7, and 12 mount the real `GuardianApp` inside a `ProviderScope` so the go_router shell, localization delegates, and theme are exercised end to end.
- Test 6 asserts the lock icon (`Icons.lock_outline`) appears for an unverified actor and that no dead-end button exists.
- M1 and M2 suites remain GREEN after the navigation retarget (`m1_shell_test.dart` 9/9), confirming Gate F.

## 4. Full Regression Suite

| Suite | Result |
|---|---|
| `flutter test` (all files) | **109/109 PASS** (80 inherited + 9 M1 + 8 M3 unit + 12 M3 widget) |
| `test/family_actor_binding_service_test.dart` + `test/family_membership_test.dart` | **14/14 PASS** (security regression untouched) |

## 5. Firebase Emulator Tests

| Suite | Result |
|---|---|
| Firestore rules (`npm test` on Firestore rules suite) | **15/15 PASS, 0 fail** |
| Functions (`requestIncidentNotification`, `requestSosNotification`) | **2/2 PASS, 0 fail** |

Command: `./tool/run_firebase_emulator_tests.sh` — exit code 0, no emulator restart needed between runs.

## 6. Gate Summary

| Gate (per brief) | Verdict |
|---|---|
| A — M2 baseline GREEN | GREEN (verified before M3 started: 89/89, 0 analyzer issues) |
| D — Unit tests pass | GREEN (8/8) |
| E — Widget tests pass | GREEN (12/12) |
| F — M1/M2 navigation GREEN | GREEN (109/109) |
| G — No false-positive data | GREEN (tests 1, 4, 5, 9) |
| H — RTL/LTR + localization | GREEN (tests 10, 11) |
| I — Full validation | GREEN (analyze 0, suite 109/109, security 14/14, emulator 17/17) |
