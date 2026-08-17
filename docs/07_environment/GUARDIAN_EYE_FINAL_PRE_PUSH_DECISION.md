# Guardian Eye Pro — Final Pre-Push Decision Report

**Date:** 2026-08-14 (UTC+3) · **Baseline:** `d61e2d2` (`master` = `origin/master`, M8 checkpoint) · **Author:** Manus AI · **Type:** decision record (read-only pass; no commit, no push, no M9)

This report closes the final pre-push decision mandate. It fixes the canonical Flutter/Dart toolchain recommendation with evidence, documents the enforcement capability decision across the three realistic paths, records the asset and repository-hygiene findings in the gap register, and ends with a precise decision inventory that awaits owner action. No repository files were changed to reach these decisions — every finding below was reached by inspection and external research only.

---

## 1. Canonical toolchain — one version, fixed — **CORRECTED 2026-08-14: Flutter 3.35.7 / Dart 3.9.2 (CANONICAL)**

> **Correction record (2026-08-14):** Section 1 originally recommended Flutter 3.47.0 / Dart 3.13.0. The owner subsequently directed that **Flutter 3.35.7 / Dart 3.9.2** — matching the owner's Windows 11 machine — be adopted as the canonical toolchain. Full verification was completed on 3.35.7: `flutter analyze` 0 errors / 0 warnings, full suite pass, security regression 14/14, Firestore 15/15, Functions 2/2, deployed-rules harness 23/23, and the native chain was confirmed Flutter-version-independent (`compileSdk` 36 default in both Flutter versions' `FlutterExtension.kt`, Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.1.21, JVM 17, no Dart 3.10+ feature in `lib/`). **`docs/GUARDIAN_EYE_TOOLCHAIN_BASELINE.md` and `docs/GUARDIAN_EYE_REPRODUCIBLE_SETUP.md` now record 3.35.7 / 3.9.2 as CANONICAL. No `flutter upgrade` to 3.47.0 is required or recommended.**

The repository carries two historical evidence baselines: the Phase-17 APK machine used Flutter 3.35.7 (Dart 3.9.2), while the M6–M8 evidence was produced on Flutter 3.47.0 (Dart 3.13.0) with the current `pubspec.lock`. The native chain is **independent of the Flutter version** — this was verified directly: Gradle 9.1.0 (wrapper), AGP 9.0.1 and Kotlin 2.1.21 (`android/settings.gradle.kts`), JVM target 17 (`android/build.gradle.kts`), and SDK levels that come from Flutter's own defaults, which happen to be identical between the two versions (`compileSdk 36`, `minSdk 24`). The codebase uses no Dart 3.10+ feature (verified by searching the entire `lib/` tree), and the `pubspec.yaml` constraint `>=3.0.0 <4.0.0` pins nothing.

Weighting the decision criteria — reproducibility, stability, compatibility, migration cost, freshness — the result is unambiguous:

> **Canonical toolchain: Flutter 3.47.0 / Dart 3.13.0.** Repository impact: **zero files**. The lockfile already reflects Dart 3.13.0, no pubspec change is required, and the native configuration is Flutter-version-independent. The owner's Windows machine action is one `flutter upgrade` to 3.47.0; the single APK build that is already required for fresh-clone Android evidence doubles as the toolchain adoption evidence. Keeping 3.35.7 on the machine remains functionally equivalent for this repository today, but the canonical evidence target — and the recommendation — is 3.47.0.

## 2. Enforcement capability — three paths, one shipped

The code-level truth gate (full-chain trace documented in the audit report) holds without modification: **M8 as shipped is an enforcement foundation / monitoring-only system; actual consumer-app blocking = NOT PROVEN.** The decision analysis across the three realistic future paths:

| Path | Verdict | Basis |
|---|---|---|
| **A. Consumer monitoring mode (M8 as shipped)** | **SHIPPED — no changes** | Honest contract: UsageStats observation, transparent foreground service, durable proof records, honest state labels. Complete and tested (217/217, 23/23 harness) |
| **B. Managed-device edition** (`setPackagesSuspended` / Device Owner) | **DEFERRED — future optional edition** | Platform-restricted: only device/profile owners can call the API [1]; consumer Play apps cannot become owners. Google Family Link operates on Google's own DPC infrastructure. A separate managed-device edition (DPC component, Android Enterprise enrollment, different channel) is architecturally viable — M8's policy engine and outbox are edition-agnostic — but must never be implied or stubbed in the consumer build |
| **C. Accessibility Service path** | **DEFERRED — legitimate but declaration-dependent** | Not prohibited by Play, but requires a Permissions Declaration Form, in-app prominent disclosure, explicit consent with decline option, and privacy/Data-safety sections [2]. Google's own policy document cites family-safety content blocking as its canonical legitimate example [2]; review friction is real and rejection is common when disclosure is insufficient [2] [3] |

The current API 34+ foreground-service gap interacts with these paths only at the monitoring-service layer: whichever service-legitimacy option the owner chooses (dataSync with its Android-15 six-hour cap and Play Console declaration, `specialUse` with its Google approval flow, or migration of the live-monitor workload to the WorkManager polling foundation M8 already has) is a **consumer-mode decision only** and has no bearing on Paths B or C. The full capability analysis lives in `docs/UX_SPRINT_01_M8_ENFORCEMENT_DECISION.md` (new, authored this pass).

## 3. Asset and repository-hygiene findings (registered, not fixed)

The asset audit found that **no code references any bundled asset** — no `Image.asset`, `rootBundle`, fonts, or SVG usage anywhere in `lib/` — and the declared asset directories are empty placeholders, so the current build and all evidence are unaffected. Two registerable facts were recorded in the gap register (no repository files changed to "fix" them): **GA-26** — the launcher source icon `assets/images/guardian_eye_icon.png` is absent while `flutter_launcher_icons` (dev-time tooling) references it; the five tracked mipmap PNGs remain the active icon, and a source icon is only needed if the owner ever regenerates launchers (owner-provided, never manufactured). **GA-27** — `firebase/functions/node_modules` (≈97 MB) exists in a historical baseline commit; the standing rule is to never include `node_modules` in future commits and to perform an owner-approved cleanup pass later (never a history rewrite).

## 4. Decision inventory — what this pass decided and what is handed to the owner

| # | Decided by this pass | Owner action awaiting |
|---|---|---|
| 1 | ~~Canonical toolchain = Flutter 3.47.0~~ **Corrected: 3.35.7 / Dart 3.9.2 = CANONICAL (owner directive; fully verified on 2026-08-14; baseline docs updated)** | APK build on 3.35.7 remains the one outstanding owner action (HUMAN ACTION REQUIRED — no Android SDK in sandbox) |
| 2 | M8 consumer monitoring ships as-is; enforcement truth gate unchanged | — |
| 3 | Managed-device edition deferred; Accessibility path deferred | Strategic decision: pursue B, C, both, or neither (recorded, not started) |
| 4 | Foreground-service API 34+ option remains owner's call (dataSync / specialUse / WorkManager-first) | Choose path; M8 code unchanged |
| 5 | GA-26 icon: defer until regeneration is actually needed | Provide source icon when needed |
| 6 | GA-27 node_modules: defer cleanup | Approve cleanup pass (working-tree only, no history rewrite) |

## 5. Gate confirmations

Nothing in this pass altered source code, tests, Firebase configuration, rules, Functions, or documents that were authored in earlier passes except the gap register (GA-26, GA-27 rows) and the two new documents. The evidence baseline standing at this checkpoint: flutter analyze 0 errors / 0 warnings; Flutter suite 217/217; security regression 14/14; Firestore emulator 15/15; Functions emulator 2/2; deployed-rules harness 23/23; secrets scan clean. `phase17-stable-checkpoint = 274e181` untouched. M9 not started. **No commit was created and no push was performed; this report is the terminal deliverable of the pass.**

## References

[1]: https://learn.microsoft.com/en-us/dotnet/api/android.app.admin.devicepolicymanager.setpackagessuspended "DevicePolicyManager.SetPackagesSuspended — requires device owner, profile owner, or delegate"
[2]: https://support.google.com/googleplay/android-developer/answer/11150561 "Best practices for prominent disclosure and consent — Google Play Help"
[3]: https://support.google.com/googleplay/android-developer/answer/9888170 "Permissions Declaration Form — Google Play Help"

- [1] [DevicePolicyManager.SetPackagesSuspended — .NET for Android API reference](https://learn.microsoft.com/en-us/dotnet/api/android.app.admin.devicepolicymanager.setpackagessuspended)
- [2] [Best practices for prominent disclosure and consent — Google Play Help](https://support.google.com/googleplay/android-developer/answer/11150561)
- [3] [Permissions Declaration Form — Google Play Help](https://support.google.com/googleplay/android-developer/answer/9888170)
