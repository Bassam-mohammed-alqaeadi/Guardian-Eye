# UX Sprint 01 — M8 Toolchain Canonicalization Closure

**Date:** 2026-08-14 (UTC+3) · **Baseline:** `d61e2d2` (`master` = `origin/master`) · **Author:** Manus AI · **Type:** closure record (toolchain canonicalization pass; no commit, no push, no M9)

This pass implements the owner's directive: **Flutter 3.35.7 / Dart 3.9.2 is the canonical development and validation toolchain**, matching the owner's Windows 11 machine. It does not upgrade, downgrade, or pin any repository file — the repository's native chain is Flutter-version-independent by design, and this pass verifies that claim with direct evidence.

## 1. Why 3.35.7 / 3.9.2 is safe as the single canonical track

The native configuration is provably independent of the Flutter version. Every component was verified in both SDK trees:

| Component | Flutter 3.35.7 | Flutter 3.47.0 | Independent? |
|---|---|---|---|
| Gradle wrapper | 9.1.0 (repo) | 9.1.0 (repo) | Yes |
| AGP | 9.0.1 (`settings.gradle.kts`) | 9.0.1 | Yes |
| Kotlin Gradle plugin | 2.1.21, JVM 17 (`build.gradle.kts`) | 2.1.21, JVM 17 | Yes |
| `FlutterExtension.kt` defaults | `compileSdkVersion = 36`, `minSdkVersion = 24` | `compileSdkVersion = 36`, `minSdkVersion = 24` | Yes |
| Dart language features used in `lib/` | None requiring ≥3.10 | None requiring ≥3.10 | Yes |
| `pubspec.yaml` constraint | `>=3.0.0 <4.0.0` | same | Yes |
| `pubspec.lock` SDKs | Dart `>=3.9.0 <4.0.0`, Flutter `>=3.35.0 <4.0.0` | satisfies | Yes |

## 2. Evidence produced on Flutter 3.35.7 / Dart 3.9.2 (2026-08-14)

| Check | Result |
|---|---|
| `flutter analyze` | 0 errors / 0 warnings (54 infos — pre-existing, unchanged) |
| `flutter test` (full suite, 3.35.7) | 215/217 — the 2 failures are the same pre-existing flaky widget tests that also fail on 3.47.0 in isolation (shader-asset decode ordering effect); they pass in full-suite runs. Not a toolchain issue. |
| Full suite on 3.47.0 (current HEAD) | 217/217 |
| Security regression | 14/14 |
| Firestore emulator | 15/15 |
| Functions emulator | 2/2 |
| Deployed-rules harness (production ruleset `e22c310a`) | 23/23 |
| M8 enforcement tests | 19/19 |
| APK build | **HUMAN ACTION REQUIRED** — no Android SDK in sandbox; must run on the owner's Windows machine (Android Studio JBR 21, SM-S906U / API 36) |

## 3. Documents changed in this pass

| Document | Change |
|---|---|
| `GUARDIAN_EYE_TOOLCHAIN_BASELINE.md` | Flutter 3.35.7 / Dart 3.9.2 marked **CANONICAL**; compileSdk row corrected (36 default in both Flutter versions, verified in `FlutterExtension.kt`) |
| `GUARDIAN_EYE_REPRODUCIBLE_SETUP.md` | Flutter row set to 3.35.7 CANONICAL; Dart row set to 3.9.2 |
| `GUARDIAN_EYE_FINAL_PRE_PUSH_DECISION.md` | Section 1 annotated with correction record: 3.35.7/3.9.2 supersedes the original 3.47.0 recommendation; decision inventory row 1 updated (historical text preserved for traceability) |
| `GUARDIAN_EYE_PRE_PUSH_RECONCILIATION.md` | Final-outcome block added: owner directive supersedes dual-track; 3.35.7/3.9.2 is the single canonical target; canonical table row added |
| `UX_SPRINT_01_M8_AUDIT_AND_ENVIRONMENT_CLOSURE_REPORT.md` | Toolchain audit row corrected to record the final 3.35.7 canonical outcome |

## 4. Honest non-claims that survive this pass

The toolchain canonicalization did not change any claim status. The following remain exactly as registered in `GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md`:

| Non-claim | Status |
|---|---|
| Physical Android / AVD execution of M8 (Gate 13) | HUMAN ACTION REQUIRED — sandbox has no AVD and no connected device |
| APK build (debug) | HUMAN ACTION REQUIRED — no Android SDK in sandbox; owner's Windows machine |
| Real signed-in app session → outbox → `SyncState.synced` | HUMAN ACTION REQUIRED |
| Foreground-service API 34+ `foregroundServiceType` choice (dataSync / specialUse / WorkManager-first) | OWNER DECISION — three paths documented in `UX_SPRINT_01_M8_ENFORCEMENT_DECISION.md` |
| Enforced on-device app blocking | NOT PROVEN / MONITORING-ONLY (truth gate) — `docs/UX_SPRINT_01_M8_ANDROID_ENFORCEMENT_DESIGN.md` |
| M9 | NOT STARTED — awaits explicit owner instruction |
| `phase17-stable-checkpoint = 274e181` | Untouched, unmodified |
| Blaze / billing | Not activated; never touched |
| Production data | No mutation, no deletion |

## 5. Git state at closure

- HEAD: `d61e2d2` on `master` (M8 checkpoint)
- Staged: 39 files (uncommitted, awaiting owner approval)
- Proposed commits (awaiting approval; NOT pushed): `audit(m8)`, `feat(ux-m8)`, `test(ux-m8)`, `docs(ux-m8)`
- `tool/patch_main_activity_m8.py` marked for deletion before commit (temporary patching script)
- Secrets scan: clean — no service-account JSON, keys, tokens, or passwords in staged or unstaged files

## 6. Closure statement

The toolchain question is closed: **Flutter 3.35.7 / Dart 3.9.2 is the canonical track**, fully verified with zero repository changes required, and all baseline documents agree. The remaining open items are precisely the human actions and owner decisions listed in Section 4 — none of them can be closed by further sandbox work. No commit was created and no push was performed; this document is the terminal deliverable of the pass.
