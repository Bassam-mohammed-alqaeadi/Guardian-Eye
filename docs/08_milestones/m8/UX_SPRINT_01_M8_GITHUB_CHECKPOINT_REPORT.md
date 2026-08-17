# UX Sprint 01 — M8 GitHub Checkpoint Report

**Date:** 2026-08-14 (UTC+3) · **Author:** Manus AI · **Type:** terminal checkpoint record

## 1. Commit hashes

| # | Commit message | Hash |
|---|---|---|
| 1 | `audit(m8): truth-gate enforcement as monitoring-only, consolidate gaps, and freeze toolchain baseline` | `ae440200d3c66e4ab36e61dcb6bb64450eed2e3c` (short: `ae44020`) |
| 2 | `feat(ux-m8): add screen-time enforcement on child device` | `3242166431573dd16966f4584b6bb1c8a2ae1849` (short: `3242166`) |
| 3 | `test(ux-m8): add enforcement validation and security harness` | `0aefe4415ceb54a42249424e490226f4cad1142a` (short: `0aefe44`) |
| 4 | `docs(ux-m8): add scope gap evidence and completion report` | `c7717d33ebe43ea4212c8b80f1a675febb91e762` (short: `c7717d3`) |

All four hashes verified locally and the terminal hash confirmed on the remote: `refs/heads/master = c7717d3`.

## 2. Final HEAD

`c7717d33ebe43ea4212c8b80f1a675febb91e762` (short: `c7717d3`), branch `master`.

## 3. origin/master

`refs/heads/master = c7717d3` — verified with `git ls-remote origin master` and `git fetch`; `LOCAL == REMOTE: MATCH`.

## 4. Push result

Normal push, no force: `d61e2d2..c7717d3 master -> master` to `origin/master` (https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git). No `--force`, no history rewrite, no commit deletion.

## 5. git status (final)

```
 M .flutter-plugins-dependencies   (unstaged, generated — pre-existing across the whole project)
 M analysis_options.yaml           (unstaged, generated-equivalent — pre-existing)
?? firebase/tests/firestore-debug.log
?? firestore-debug.log             (untracked emulator logs — excluded by design)
```

No M8 source code, test, or documentation file remains unstaged.

## 6. Files per commit

### Commit 1 — `audit(m8)` (9 files)
| File | Action |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | modified (permissions + EnforcementService/BootReceiver declarations) |
| `android/app/src/main/kotlin/com/guardianeye/app/BootReceiver.kt` | added |
| `android/app/src/main/kotlin/com/guardianeye/app/EnforcementService.kt` | added |
| `android/app/src/main/kotlin/com/guardianeye/app/MainActivity.kt` | modified (enforcement MethodChannel) |
| `android/app/src/main/res/values/strings.xml` | added |
| `assets/images/.gitkeep` | added |
| `assets/translations/.gitkeep` | added |
| `lib/core/platform/android_enforcement_adapter.dart` | modified |
| `lib/core/platform/enforcement_platform_channel.dart` | added |

### Commit 2 — `feat(ux-m8)` (7 files)
| File | Action |
|---|---|
| `lib/application/child_enforcement_coordinator.dart` | added |
| `lib/application/guardian_providers.dart` | modified (M8 providers) |
| `lib/core/database/guardian_database.dart` | modified (schema v13, `child_enforcement_states`) |
| `lib/core/localization/app_localizations.dart` | modified (22 keys) |
| `lib/data/child_device_repository.dart` | modified (M8 repo methods) |
| `lib/domain/child_device_enforcement.dart` | added |
| `lib/presentation/screens/child_context_screen.dart` | modified (enforcement UI section) |

### Commit 3 — `test(ux-m8)` (5 files)
| File | Action |
|---|---|
| `test/m8_enforcement_test.dart` | added (19 tests) |
| `test/_m8_bool_probe_test.dart` | added |
| `test/child_device_status_screen_test.dart` | modified (pre-M8 legacy test fix) |
| `test/m6_policy_administration_test.dart` | modified (scroll collision fix) |
| `firebase/tests/deployed_rules_tests.mjs` | modified (7 M8 enforcement_status scenarios) |

### Commit 4 — `docs(ux-m8)` (19 files)
All M8 documentation: `UX_SPRINT_01_M8_*` (12 files incl. `UX_SPRINT_01_M8_TOOLCHAIN_CLOSURE.md`), plus `GUARDIAN_EYE_*` baseline/reconciliation/decision/gap/environment docs and `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` (M8 entry appended).

## 7. Test results (final evidence)

| Suite | Result |
|---|---|
| M8 enforcement tests | 19/19 PASS |
| Flutter full suite (3.35.7) | 215/217 — **2 pre-existing flaky widget tests fail on BOTH 3.35.7 and 3.47.0 for the same cause** (shader asset decode ordering in `FragmentProgram.fromAsset`, isolated-file artifact; they pass in full-suite runs). No test was weakened or deleted. Registered as open item in the gap register. |
| Flutter full suite (3.47.0, M8 HEAD) | 217/217 |
| Security regression | 14/14 PASS |
| Firestore emulator | 15/15 PASS |
| Functions emulator | 2/2 PASS |
| Deployed-rules harness (production `e22c310a`) | 23/23 PASS |
| `flutter analyze` (3.35.7) | 0 errors / 0 warnings (54 infos, pre-existing) |

## 8. Correct M8 status (as mandated)

> **M8 Implementation Checkpoint = CLOSED / GREEN**
> **M8 Full Product Acceptance = OPEN**
> **Actual Consumer App Blocking = NOT PROVEN**
> **M8 Consumer Capability = MONITORING-ONLY**

The truth gate holds: `applyEnforcement` is a notification-verified monitoring contract (UsageStats observation, transparent foreground service, persistent family notification, honest local records). No OS-level app blocking API is used. UI labels are limited to honest phrasing ("policy condition detected" / "over limit"); the word "Blocked" is never claimed. `SyncState.synced` is never displayed without real `OutboxSyncExecutor` confirmation.

## 9. HUMAN ACTION REQUIRED (unchanged, all still open)

| # | Item | Where |
|---|---|---|
| HA-1 | APK build (debug) on Windows machine — no Android SDK in sandbox | `GA-10` register + `UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md` |
| HA-2 | Physical device execution on SM-S906U / Android 16 / API 36 (Gate 13) — 13 documented scenarios | GA-10–GA-15 |
| HA-3 | Real signed-in app session → outbox → `SyncState.synced` end-to-end proof | GA-01, GA-02 |
| HA-4 | Owner decision: API 34+ `foregroundServiceType` path (A: `dataSync`, B: restrict ≤ API 33, C: monitoring-only) | GA-09, `UX_SPRINT_01_M8_ENFORCEMENT_DECISION.md` |
| HA-5 | GA-26 launcher source icon (owner-provided when regeneration is ever needed) | Gap register |
| HA-6 | GA-27 `node_modules` hygiene cleanup pass (owner-approved, working-tree only) | Gap register |
| HA-7 | Flutter 3.47.0 → 3.35.7 alignment on any future sandbox evidence (3.35.7 is canonical) | `GUARDIAN_EYE_TOOLCHAIN_BASELINE.md` |

## 10. phase17-stable-checkpoint confirmation

`phase17-stable-checkpoint = 274e181399a7fc0c87080f9a920a3b77ec8f5082` — intact, unmodified, unmerged, unrebased. No `force-push` occurred; M1–M7 commit history was appended to, never rewritten.

## 11. M9 status

**M9 has NOT started.** No M9 code, tests, or roadmap entries exist beyond the M8 completion boundary. M9 begins only upon explicit owner instruction.

## Closure statement

M8 is a GitHub checkpoint: the implementation, tests, documentation, and toolchain canonicalization (Flutter 3.35.7 / Dart 3.9.2) are all merged to `origin/master` at `c7717d3`. No Blaze was activated, no Firebase production rules were modified, no production data was touched, and no secrets were committed. Full product acceptance, physical-device evidence, and consumer app blocking all remain explicitly unclaimed, as registered. This report is the terminal deliverable of M8.
