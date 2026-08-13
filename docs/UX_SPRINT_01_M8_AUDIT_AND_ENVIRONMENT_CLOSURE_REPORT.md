# Guardian Eye Pro — M8 Audit + Cross-Milestone Gap Closure + Repository Normalization Closure Report

**Author:** Manus AI | **Date:** 2026-08-14 (UTC+3) | **Scope:** The M8 Enforcement Audit + Cross-Milestone Gap Closure mandate | **Baseline:** `master` HEAD `d61e2d2` (M7 checkpoint) | **Status:** All verifiable gates GREEN; two environment losses declared as HUMAN ACTION REQUIRED; no push performed; awaiting explicit owner approval

## 1. Truth-Gate Audit — The Central Finding (Workstream A)

A post-implementation code-level audit of the M8 enforcement chain reclassified `applyEnforcement()` from "enforcement applied" toward a stricter honest category: **MONITORING-ONLY**. The actual operating-system actions performed by the implementation are (a) foreground-app observation through `UsageStatsManager`, (b) a transparent foreground service that posts a persistent, high-priority family notification visible to the child, and (c) a durable local enforcement record enqueued for remote synchronization through the existing outbox. No consumer-legal API call blocks, kills, suspends, or restricts a third-party app — that authority requires Device/Profile Owner privileges that a Google Play consumer app must never have. The implementation never claimed otherwise in any user-visible label, and the audit confirms the UI vocabulary renders only honest monitoring states (`مراقبة نشطة` / active monitoring, `تم تجاوز الحد` / over limit detected, `القيد مفعّل` / restriction active **only after verified notification posting**).

The honest feature classification is therefore **"M8 Enforcement Foundation"**: a verified, durable, notification-backed enforcement *evidence* chain with `Actual Consumer-App Restriction = NOT PROVEN`. This is registered as **GA-08 — BLOCKED (ENFORCEMENT TRUTH GATE)** in `docs/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md`, and every M8 document carries a Truth-Gate Audit Addendum or blockquote stating it. No claim in this report elevates enforcement beyond monitoring evidence.

## 2. API-34 Foreground Service Failure — A Second Hard Blocker

On Android API 34+, a foreground service declared **without** `foregroundServiceType` fails `startForeground()` with `foreground_type_required_android_14`. The owner's registered device (Samsung SM-S906U, Android 16 / API 36) therefore **cannot start the EnforcementService at all** with the current manifest declaration. The service cannot be validated on the owner's device until one owner-approved path is applied: (P-A) declare `foregroundServiceType="dataSync"` with the matching permission and Play declaration review, (P-B) restrict enforcement reporting to API 33 devices, or (P-C) keep M8 as a measurement/evidence foundation and defer enforcement entirely. The twelve physical scenarios (service startability, lifecycle, outbox delivery, release, process death, force-stop limitation, reboot, Doze, network loss, permission revocation, stale/superseded policy, device revocation, temporary-override expiry) are pre-planned with fixed expected honest outcomes in `docs/UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md` and are marked **HUMAN ACTION REQUIRED** pending this resolution.

## 3. M7 Status Correction

The truth-gate lens applies retroactively to M7: the M7 "measurement" claims were already honest (measurement via UsageStats, never application), so M7 status remains GREEN for measurement. However, the registered gap list was corrected where earlier documents implied enforcement adjacency, and the M7 documentation section of the gap register now explicitly records that M7 never performed, claimed, or attempted any application of restriction.

## 4. Gap Register Consolidation (Single Source of Truth)

`docs/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md` now consolidates every open gap across M1–M8 into one list: GA-01 (real signed-in outbox delivery to `SyncState.synced`), GA-02 (queued→synced transition evidence on real hardware), GA-08 (enforcement truth gate — monitoring-only, BLOCKED), GA-09 (foregroundServiceType for API 34+), GA-10–GA-15 (physical device evidence scenarios, Gate 13), GA-16–GA-22 (Play Store data-safety review, invitation remote sync, override expiry server-side guard parity, background check on API 31+, battery-optimization UX, device-owner impossibility statement, Play restricted-declaration review). Each entry records its gate classification (BLOCKED / HUMAN ACTION REQUIRED / OPEN) and the exact human action required.

## 5. Toolchain and Repository Normalization Audit

| Item | Verified fact (2026-08-14) | Source |
| ---- | -------------------------- | ------ |
| Flutter / Dart | M6–M8 evidence produced on 3.47.0 / 3.13.0; **canonical toolchain subsequently fixed to 3.35.7 / 3.9.2** (owner directive 2026-08-14; full verification completed on 3.35.7; see `GUARDIAN_EYE_TOOLCHAIN_BASELINE.md`) | `flutter --version` (both SDKs); baseline docs |
| compileSdk / targetSdk / minSdk | Per `android/app/build.gradle.kts` (frozen until M9 or later) | build file |
| AGP / Kotlin Gradle Plugin | Per `android/build.gradle.kts` (frozen) | build file |
| Gradle | Wrapper-shipped only; no system Gradle assumed | `gradle/wrapper/` |
| JDK | `flutter doctor` Android toolchain dependency (was present pre-reset; lost with sandbox reset) | doctor |
| ADB | `/opt/android-sdk/platform-tools` (path lost with sandbox reset) | doctor |
| Gradle cache | `android/gradle/` wrapper JAR + `android/app/build.gradle.kts`, `android/settings.gradle.kts` | repo |
| pubspec | All 20+ dependencies pinned by `pubspec.lock`; no new M8 native dependencies | pubspec |
| Assets | `assets/images/`, `assets/translations/` referenced in pubspec but **empty and untracked** — fixed by adding `.gitkeep` so a fresh clone preserves the dirs | filesystem + commit plan |
| Local paths | `android/local.properties` carries `sdk.dir=/home/ubuntu/android-sdk` (a sandbox-local path; regenerated automatically by Flutter tooling, never committed) | local.properties |
| Generated files | `pubspec.lock`, `.flutter-plugins-dependencies` restored to HEAD to avoid generated-file noise in commits | git |
| Log artifacts | `firestore-debug.log` removed (runtime artifact, never committed) | git |
| Tool scripts | `tool/patch_main_activity_m8.py` — temporary development patch script; **proposed for deletion** before commit | filesystem |
| Firebase config | `lib/firebase_options.dart`, `android/app/google-services.json` untouched (identity: project `manus-guardian`, package `com.guardianeye.app`, app `1:165160049292:android:922e6c8a4749c42e4839a`) | config files |

The Android SDK installation (`/home/ubuntu/android-sdk`) was **lost with a sandbox reset** and is not present in this session; consequently `flutter doctor` reports the Android toolchain as NOT AVAILABLE and no APK build could be executed here. This is recorded honestly as an environment loss, NOT a regression claim against the code. The reproducible setup document (`docs/GUARDIAN_EYE_REPRODUCIBLE_SETUP.md`) documents exactly how to re-establish the toolchain on any machine, which is the mandated remedy.

## 6. Post-Normalization Validation (all executed directly, 2026-08-14)

| Gate | Command | Result |
| ---- | ------- | ------ |
| Static analysis | `flutter analyze` | 0 errors, 0 warnings (54 info notes only) |
| Full Flutter suite | `flutter test` | **217/217 PASS** (baseline before M8: 197/197) |
| M8 core tests | `test/m8_enforcement_test.dart` | 19/19 PASS |
| Security regression | actor binding + membership | 14/14 PASS |
| Firestore Emulator | `run_firebase_emulator_tests.sh` | 15/15 PASS |
| Functions Emulator | same script | 2/2 PASS |
| Deployed-rules harness (emulator mode) | `firebase emulators:exec node deployed_rules_tests.mjs` | **23/23 PASS** (16 existing + 7 new `enforcement_status` scenarios) |
| APK build | `flutter build apk --debug` | NOT EXECUTABLE this session (Android SDK lost with sandbox reset; recorded as HUMAN ACTION REQUIRED, Phase-17 closure APK evidence predates this loss) |

## 7. Environment Documents Delivered

Five environment documents were created and one updated: `docs/GUARDIAN_EYE_TOOLCHAIN_BASELINE.md` (every toolchain version and SDK path), `docs/GUARDIAN_EYE_REPRODUCIBLE_SETUP.md` (exact steps to rebuild the environment from a fresh clone), `docs/GUARDIAN_EYE_FIREBASE_ENVIRONMENT.md` (project identity, ruleset versions, emulator usage), `docs/UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md` (the twelve planned scenarios with honest expected outcomes), and `docs/LOCAL_ENVIRONMENT_NETWORK_CHANGES.md` (unchanged reference for the Windows firewall/preparation steps the owner executes manually). `docs/GUARDIAN_EYE_REAL_TEST_ENVIRONMENT_SETUP.md` was updated with the API-34 device-reality note.

## 8. What This Report Does NOT Claim

This report does not claim: enforcement applied on any device, APK build success in this session, service startability on API 34+, Gate 13 physical evidence, real signed-in outbox delivery to `SyncState.synced`, Play Store policy compliance for `dataSync`, or force-stop automatic recovery (documented platform limitation). The only GREEN claims are software-level: analysis, tests, emulators, deployed-rules harness, and the monitoring-chain logic.

## 9. Proposed Commits (awaiting explicit owner approval — nothing pushed)

| # | Message | Contents |
| --- | ------- | -------- |
| 1 | `audit(m8): truth-gate enforcement as monitoring-only, consolidate gaps, and freeze toolchain baseline` | All M8 doc honesty addenda, gap register consolidation, toolchain baseline, reproducible setup, Firebase environment, physical validation plan, real-test-env update, `assets/images/.gitkeep`, `assets/translations/.gitkeep` |
| 2 | `feat(ux-m8): add screen-time enforcement on child device` | Enforcement domain, coordinator, providers, adapter + channel, repository M8 methods, schema v13, Kotlin service/receiver/manifest/strings, child-context UI, localization keys |
| 3 | `test(ux-m8): add enforcement validation and security harness` | 19 M8 tests, probe test, pre-M8 guardrail fixture update, M6 fixture scope fix |
| 4 | `docs(ux-m8): add scope gap evidence and completion report` | M8 design, gap audit, test evidence, completion report, final checkpoint report, deployed-rules harness M8 scenarios, roadmap append-only entry |

`tool/patch_main_activity_m8.py` is proposed for deletion within commit 2's boundary (temporary development artifact). `phase17-stable-checkpoint` = `274e181` remains untouched; no force-push; no history rewrite; no M9.
