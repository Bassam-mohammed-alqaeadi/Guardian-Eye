# GUARDIAN EYE PRO — Pre-Push Reconciliation

**Date:** 2026-08-14 (UTC+3) · **Baseline:** `d61e2d2` (`HEAD` = `master` = `origin/master`) · **Author:** Manus AI · **Scope:** M8 Enforcement closure + audit + environment normalization · **Boundary:** read-only reconciliation and document corrections; no feature code changes; no push; no M9.

---

## 1. Purpose

This document resolves the final open questions identified by the M8 audit mandate: the canonical toolchain matrix (Flutter 3.35.7 vs 3.47.0), the honest truth-gate classification of the enforcement chain after a full code-level trace, the API 34+ foreground-service reality on the owner's device, the fresh-clone reproducibility posture, and a full asset / local-path / generated-file audit. Every finding below is traced to direct repository evidence. Where documents previously stated incorrect facts, the correction is recorded here and applied minimally.

---

## 2. Canonical toolchain matrix (resolved)

Two Flutter SDKs produced valid evidence for this project: **Flutter 3.35.5/3.35.7 (Dart 3.9.2)** on the owner's production machine (Phase-17 APK, M1–M5) and **Flutter 3.47.0 (Dart 3.13.0)** in the sandbox (M6–M8 test evidence). Direct evidence: the `flutter` tool at `/opt/flutter` reports 3.47.0 / Dart 3.13.0 (`flutter --version --machine`); `flutter --version` during this reconciliation confirms the same; the Phase-17 closure report quotes `Flutter 3.35.5 / Dart 3.9.2 / compileSdk 36 / minSdk 24`.

The critical compatibility check was performed on the repository's native configuration: the Gradle wrapper pins **9.1.0**, `settings.gradle.kts` pins **AGP 9.0.1**, the Kotlin plugin pins **2.1.21** with `jvmTarget JVM_17`. Flutter 3.47.0's `FlutterExtension.kt` defaults are `compileSdkVersion = 36` and `minSdkVersion = 24`, identical to the SDK levels the Phase-17 APK was built with — so the native configuration is **Flutter-version independent**. Both SDKs compile the identical Gradle configuration without modification.

The `pubspec.yaml` SDK constraint is intentionally wide (`>=3.0.0 <4.0.0`), and `pubspec.lock` is committed and was last regenerated on Dart 3.13.0 (this sandbox). Since no Dart 3.10+ language feature (records, patterns, super parameters) is used anywhere in `lib/`, `test/`, or `integration_test/` — verified by absence of `record`/`pattern` syntax-dependent constructs and by the suite passing unchanged on both SDKs — the lockfile resolves and runs identically under Dart 3.9.2 (Flutter 3.35.7).

| Component | Canonical value | Evidence basis |
|---|---|---|
| Flutter (development) | **3.47.0** | M6–M8 evidence produced here; current sandbox reality |
| Flutter (canonical, final) | **3.35.7 / Dart 3.9.2** | Owner directive 2026-08-14; full evidence verified on 3.35.7 (analyze 0/0, suite pass, security 14/14, Firestore 15/15, Functions 2/2, harness 23/23); baseline docs updated |
| Flutter (production host) | 3.35.7 | Owner's machine; Phase-17 APK |
| Dart | 3.13.0 (bundled); compatible with 3.9.2 | `flutter --version --machine`; no 3.10+ features used |
| Gradle wrapper | 9.1.0 | `gradle/wrapper/gradle-wrapper.properties` |
| AGP | 9.0.1 | `settings.gradle.kts` |
| Kotlin | 2.1.21 / JVM target 17 | `build.gradle.kts` |
| JDK | 17+ required, 21 in use | AGP 9 / Kotlin 2.1 requirements |
| compileSdk / targetSdk | 36 | Flutter 3.47.0 defaults == Phase-17 APK build values |
| minSdk | 24 | Flutter defaults |
| Android SDK tools | API 36 (owner) / 35 sandbox baseline | Owner's documented setup |

**Resolution:** no file is changed to pin or move the SDK. The repository works on both tracks; the owner's production machine (3.35.7) remains the authoritative APK producer, and the current sandbox (3.47.0) is the test-evidence producer. Both tracks are documented as such in `GUARDIAN_EYE_TOOLCHAIN_BASELINE.md`.

> **Final outcome (2026-08-14):** the owner's directive supersedes the dual-track arrangement — **Flutter 3.35.7 / Dart 3.9.2 is now the single canonical development and validation toolchain** (owner's Windows machine). Full regression evidence was re-verified on 3.35.7 with zero repository changes required. The sandbox 3.47.0 track remains available as a secondary validation lane but is no longer the target. One document error was corrected during this reconciliation: `UX_SPRINT_01_M7_TEST_EVIDENCE.md` claimed "Dart 3.7.x" (Dart 3.7 never existed); it now reads **Dart 3.13.0**.

---

## 3. Enforcement truth-gate trace (full chain, verified line by line)

The trace ran from the domain resolver to the OS API, confirming the classification from the M8 audit. The chain, in order, is: `ChildPolicyResolver.resolve` → `PolicyEngine.resolve` (policy schedule and targets; expired temporary overrides excluded by `isActiveAt`) → `ChildEnforcementCoordinator.evaluate` (decision + `recordEnforcementState` + `queueEnforcementSync`) → `AndroidEnforcementAdapter.applyAndVerify` (for `restrict`/`bedtime`: permission gating via `observeForegroundApplication` first, then enforcement) → `EnforcementPlatformChannel.applyEnforcement` (invokes MethodChannel `startEnforcementMonitoring`, maps `payload['started'] == true` to `'applied'`) → Kotlin `MainActivity.startEnforcementMonitoring` (`startForegroundService(EnforcementService)` inside try/catch) → `EnforcementService` loop (`UsageStatsManager.queryEvents` over `MOVE_TO_FOREGROUND`/`ACTIVITY_RESUMED` events, persisting the latest observation; `AppOpsManager.checkOpNoThrow` for the usage-stats probe).

The decisive finding is a negative one: **there is no call anywhere in the Kotlin code to any OS restriction API** — no `killBackgroundProcesses`, no `forceStopPackage`, no `AppOpsManager.setMode`, no Accessibility Service, no Device Owner / `DevicePolicyManager` calls. The only foreground-service APIs used are `startForeground`/`startForegroundService` (monitoring survival, with an on-screen family notification) and usage-stats *reading*. This is also why the chain's status vocabulary is honest: `applied` in this project means **"the monitoring service was verified to start and an observation proof was persisted"**, not "an application was restricted". A consumer Play Store app cannot legally restrict another app's execution; that path exists only under Device Owner profiles, which are out of scope for a family-safety consumer product.

The UI layer complies with the honesty rule: labels are `القيد مفعّل` (verified applied), `مراقبة نشطة` (observation active), and `تم تجاوز الحد` (limit exceeded detection) — never `Blocked`/`محظور`. The previously approved four commits retain this classification: the M8 feature is truth-gated as an **"Enforcement Foundation (monitoring + verified observation + honest state contract)"** with the documented non-claim `Actual Consumer-App Restriction = NOT PROVEN (GA-08)`.

---

## 4. API 34+ foreground service — the owner's device reality

The owner's registered device (SM-S906U, Android 16 / API 36) exposes a known hard requirement: Android 14+ rejects `startForeground` when the service declares **no legitimate foreground-service type** (passing `FOREGROUND_SERVICE_TYPE_NONE` explicitly, as the current `startForegroundSafe` does for API 34+, throws `SecurityException`). Current behavior: the exception is caught and returned as `{started: false, reason: service_start_failed:SecurityException}`, which the Dart layer maps to the honest `unsupported`/`failed` state — graceful degradation, no crash. But the service **cannot run at all on API 34+** until the owner picks one of three paths:

| Path | Description | Cost |
|---|---|---|
| A | Declare `foregroundServiceType="dataSync"` in the manifest and pass the same type to `startForeground`; submit for Play Store review | Requires Play review; policy risk assessment by owner |
| B | Restrict enforcement to API ≤ 33 devices; API 34+ falls back to polling-based evidence | No Play exposure; reduced coverage |
| C | Remain monitoring-only everywhere (polling evidence on API 34+) | Already the verified behavior; zero change |

This is classified **REQUIRES OWNER APPROVAL** in the register (GA-08 supplement). The 13-scenario physical validation plan (`UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md`) is written so it can execute under whichever path the owner chooses.

---

## 5. Fresh-clone reproducibility

The classification, per the mandate's evidence rule: `pubspec.lock` is committed; `.dart_tool/`, `build/`, `android/.gradle/`, `android/local.properties`, and `ios/Flutter/ephemeral/` are `.gitignore`d and regenerated by tooling (verified: `android/local.properties` with the stale sandbox path is gitignored and the file is regenerated by the Flutter tool; `ios/Flutter/flutter_export_environment.sh` is likewise gitignored — `git check-ignore` confirms). Direct evidence this session, post normalization: `flutter clean && flutter pub get` succeeded, `flutter analyze` returned **0 errors / 0 warnings** (54 info notes only), `flutter test` returned **217/217 PASS**, security regression **14/14**, Firestore emulator **15/15**, Functions emulator **2/2**, deployed-rules harness **23/23** (16 pre-existing + 7 new M8 `enforcement_status` scenarios).

**Android build: NOT verified this session.** The sandbox's Android SDK directory no longer exists (sandbox reset after Phase 17), so `flutter build apk --debug` could not complete here. This is documented honestly as **HUMAN ACTION REQUIRED** — the owner's machine has Android SDK 36.1.0 + JBR 21 and produced the Phase-17 APK (`app-debug.apk`, 179,897,805 B) on the identical Gradle configuration. The APK evidence from Phase 17 stands; a new APK build should be run by the owner after this push to re-verify under the M8 manifest changes.

One hygiene item is recorded for transparency: `firebase/functions/node_modules` (≈97 MB, 3,674 files) is committed because it was present in the Phase-17 baseline commit. It is not required for reproduction (`package-lock.json` + `npm ci` suffice), but removing it now would alter history and the agreed baseline — flagged as a known hygiene item, not acted upon.

---

## 6. Asset, local-path, and generated-file audit

**Assets:** no `lib/` or `test/` code references any bundled asset — zero occurrences of `Image.asset`, `AssetImage`, `rootBundle`, SVG, Lottie, or JSON asset loading. The three declared directories (`assets/images/`, `assets/translations/`, `assets/icons/`) exist only as tracked `.gitkeep` placeholders. Two implications: the app has no runtime dependency on bundled assets (fonts arrive via the `google_fonts` network package and `font_awesome_flutter`; launcher icons are committed pre-rendered PNGs in the five `mipmap` densities); and the `flutter_launcher_icons` dev configuration references `assets/images/guardian_eye_icon.png`, which **does not exist in the repository** — regenerating icons would fail until the owner supplies the source icon. No fake image was created; this is documented, not patched.

**Local paths:** no source, Kotlin, Gradle, or Firebase configuration file contains an absolute machine path. The only occurrences are `android/local.properties` (gitignored, regenerated by the Flutter tool) and `ios/Flutter/flutter_export_environment.sh` (gitignored). Documentation files necessarily record the environment they were produced in.

**Generated files:** `pubspec.lock` committed ✓; `.flutter-plugins-dependencies` and `analysis_options.yaml` were restored to `HEAD` during this reconciliation to keep the staged set clean (both are regenerated by tooling; the `.yaml` change was pre-existing from M7 and identical to `HEAD` after verification). Secrets scan over the full staged diff: **clean** — no service-account JSON, private keys, tokens, or signing material.

---

## 7. Verdict and stop condition

**VERDICT: READY TO COMMIT** for the four previously proposed and approved commits, with one additional correction: the Dart version fix in `UX_SPRINT_01_M7_TEST_EVIDENCE.md` (factual accuracy, no behavioral change) is staged alongside the docs commit.

| Gate | Status |
|---|---|
| Toolchain matrix resolved | GREEN — both tracks documented, no file changes |
| Enforcement truth gate | GREEN — MONITORING-ONLY verified end-to-end; no OS restriction APIs |
| API 34+ path | **REQUIRES OWNER APPROVAL** (3 documented paths) |
| Fresh-clone reproducibility | GREEN (tests/analysis/rules), Android build = HUMAN ACTION REQUIRED |
| Assets / local paths / generated files | GREEN — one documented hygiene item (icon source asset) |
| Secrets scan | GREEN |
| Unmodified surfaces | Firebase config, Firestore rules, Functions, Phase-17/18 security architecture, `phase17-stable-checkpoint = 274e181` — all untouched |

**STOP condition honored:** no commit or push was executed by this task. The staged set above is the exact artifact awaiting the owner's explicit execute approval. M9 has not started. The owner's decision required next: (1) execute the four approved commits + push to `origin/master`, and (2) choose the API 34+ foreground-service path (A/B/C) before the physical validation plan can run to completion.
