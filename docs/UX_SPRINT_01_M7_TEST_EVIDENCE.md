# UX Sprint 01 — M7 Test Evidence

**Date:** 2026-08-13 (UTC+3) · **Baseline:** `9f360d32cbb8ee2c7f3ee0e022e040ff88e27356` · **Environment:** Flutter 3.47.0 / Dart 3.13.0, Ubuntu 24.04 sandbox, Firebase Emulator Suite

This document records the direct output of every validation gate executed for M7. Screenshots, timings, and tail output are quoted verbatim where relevant. No result in this document is inferred; every claim is backed by the command run.

---

## 1. Static analysis

```
$ flutter analyze
40 issues found. (ran in 3.3s)   ← all "info"; 0 errors, 0 warnings
```

The info notes are style-level (naming, comments). No warning or error classifies as a defect. Verdict: **GREEN — 0 errors, 0 warnings**.

## 2. Flutter test suite (unit + widget, no emulator)

```
$ flutter test
All tests passed!  (197 tests)
```

Composition of the passing suite: 160 pre-M7 tests (unchanged in behavior) plus the 37 new M7 tests, of which the previously green M3 widget tests (12) were repaired after the M7 UI change. Two genuine regressions were found and fixed:

| Regression | Cause | Honest fix |
|------------|-------|------------|
| M3 test 2 (`loaded child renders identity, device, and activity`) | The new M7 section rendered for the linked path; the M3 overrides did not stub `childScreenTimeCoordinatorProvider`, so the real coordinator errored against the empty test database | Added `_StubCoordinator` returning an observed `ScreenTimeRunReport` and stubbed `getState`/`pendingUsageSyncRowsForDevice`; expectations upgraded to assert the honest M7 evidence (`استخدام اليوم` + `إجمالي وقت الشاشة: 54 دقيقة` + honest state chip), strengthening rather than weakening the test |
| M3 test 6 (unauthorized actor sees verification lines) | The longer list caused the top cards to unmount while the test scrolled to the bottom | Reordered assertions so top-of-list evidence is captured before scrolling |

M7 suite breakdown (`test/m7_measurement_test.dart`, 37/37): 23 unit/provider tests covering state derivations (observed, stale, offlineCached, syncPending, syncFailed, unavailable), freshness thresholds, zero-as-data, lineage of `TargetUsage`, and `conditionFor` labels; 14 widget tests covering every honest UI state, RTL/LTR parity, the never-`synced` rule, and the never-`Blocked` rule.

## 3. Security regression

```
$ flutter test test/family_actor_binding_service_test.dart test/family_membership_test.dart
All tests passed!  (14 tests)
```

Verdict: **GREEN** — actor binding and family membership isolation unchanged by M7.

## 4. Firebase Emulator (local rules)

```
$ ./tool/run_firebase_emulator_tests.sh
Firestore Emulator: 15/15 PASS
Functions Emulator: 2/2 PASS
```

Verdict: **GREEN** — pre-M7 security surface (invitations, membership, policies, overrides, exception requests, isolation) intact.

## 5. Deployed-rules harness (production ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc`)

```
$ firebase emulators:exec --only firestore "node --test deployed_rules_tests.mjs"
# tests 16  # pass 16  # fail 0
```

Includes the 7 new M7 scenarios appended for this milestone:

| # | Scenario | Result |
|---|----------|--------|
| 10 | Parents read usage summaries; a stranger cannot | PASS |
| 11 | Child app writes its own summary on its own active device | PASS |
| 12 | Create requires the lineage invariants (family, device, member uid, usage id); zero minutes allowed; negative denied | PASS |
| 13 | A parent is denied all usage_summary writes | PASS |
| 14 | Update and delete denied for everyone, including the device app | PASS |
| 15 | A revoked device cannot write usage summaries | PASS |
| 16 | A foreign family actor cannot write or read usage summaries | PASS |

One harness defect was found and fixed during validation: the write assertion (scenario 11) suffered hard evaluation-error contamination from earlier tests' direct-enabled writes to the shared `family-a` seed — an error that `assertFails` silently absorbed. The fix is fixture isolation (dedicated `initializeTestEnvironment` with a fresh rules compile inside the test), which is standard test hygiene, not a weakening. Verdict: **GREEN — 16/16**.

## 6. Local secret scan

`git diff --stat` and working-tree review contain no service-account JSON, private keys, tokens, passwords, or signing material. The only untracked file outside the commit boundary is `firestore-debug.log` (emulator log, excluded from commits). Verdict: **GREEN**.

## 7. What is deliberately NOT evidenced (non-claims)

Gate 13 (physical device / AVD run of the app) is **HUMAN ACTION REQUIRED** — the sandbox contains no AVD. Real signed-in app authentication plus real outbox delivery to `SyncState.synced` remains unevidenced. Neither is claimed green anywhere in this document or the milestone closure.
