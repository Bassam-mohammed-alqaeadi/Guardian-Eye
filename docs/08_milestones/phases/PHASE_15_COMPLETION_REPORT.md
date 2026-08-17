# Phase 15 Completion Report — Measured Screen Time Foundation

**Date:** 12 August 2026  
**Selected slice:** Consent-gated Android Usage Access observation, deterministic daily screen-time accounting, and a truthful enforcement boundary.

> **Final classification:** Phase 15 completes the measurable, local-first foundation for screen-time limits. It does not prove a physical Android observation, successful APK/Kotlin build, continuous background monitoring, reboot/Doze behavior, or universal application blocking.

## Delivered behavior

| Layer | Delivered work | Evidence classification |
|---|---|---|
| Product baseline | Public capability baseline categorizes parity, advantage, differentiator, and future work without copying competitor UI/code. | **IMPLEMENTED + DOCUMENTED** |
| Android policy choice | Usage Access measurement is selected; Accessibility, overlays, normal-app universal blocking, and DPC provisioning are not used for Phase 15. | **IMPLEMENTED + DOCUMENTED** |
| Least privilege | The current manifest/screen exposes only Usage Access and notifications; location, microphone, overlay, and boot permissions were removed from this phase’s declared permission path. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Policy | Optional daily minutes are validated, persisted in SQLite/Outbox, serialized by Firestore contract, delivered to child snapshots, and editable in the parent policy UI. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Observation | Android bridge queries daily aggregate usage for policy-target packages only and emits explicit permission/no-data/unsupported states. | **IMPLEMENTED — VALIDATION BLOCKED** |
| Accounting | Daily cumulative package summaries are persisted by device/day/target and cannot move backward on a lower later sample. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Decision | At the exact limit, the pure engine yields `enforcementRequested`; a temporary allow wins; adapter returns `unsupported`, not applied, for ordinary Android app blocking. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Parent UX | Parent sees policy limit, local usage summary, and on-demand measurement action with non-enforcement language. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Firestore authorization | Usage summary write rules restrict writer to active child device identity; parent/revoked/cross-family paths are denied. | **VERIFIED IN EMULATOR** |

## Validation record

| Command | Result | What it proves | What it does not prove |
|---|---|---|---|
| `flutter analyze` | Passed with no issues. | Dart static consistency. | Kotlin compilation or native behavior. |
| `flutter test --reporter expanded` | **45 tests passed.** | Policy limits, SQLite/Outbox accounting, UI boundaries, contracts, and prior architecture. | Physical Usage Access or enforced app restriction. |
| `./tool/run_firebase_emulator_tests.sh` | **11 Firestore Rules + 2 Functions tests passed.** | Child usage-summary authorization in Emulator, including denials. | Deployment to real Firebase or device telemetry. |
| `flutter build apk --debug --no-pub` with conservative Gradle flags | Stopped at `:app:compileFlutterBuildDebug` / `kernel_snapshot_program`. | The environment attempted a debug build. | Kotlin compilation, APK artifact, install, or device validation. |

## Explicit non-claims

No capability is marked protected because a policy exists or a limit is exceeded. The Android adapter’s `unsupported` result is the only truthful Phase 15 outcome for a restriction request on an unmanaged normal Android device. No Accessibility service, overlay interception, Device Owner/DPC provisioning, background service, reboot receiver, or automatic exception request was added.

No Phase 15 Firebase rule/configuration was deployed to `manus-guardian`, preserving the stated boundary against changing real Firebase configuration. No Firebase Admin credential is in Flutter. The local Firestore rules change is Emulator-verified only.

## Next evidence gate

Follow [`PHASE_15_HUMAN_ACTION_REQUIRED.md`](PHASE_15_HUMAN_ACTION_REQUIRED.md) on a physical Android device or AVD. The first test must demonstrate permission denied, then explicitly granted Usage Access, a policy-target app’s measured daily total, local persisted recovery after force-stop, offline behavior, and the truthful unsupported adapter status for a crossed limit. A future enforcement phase may consider Device Owner/DPC only after product, consent, Play-policy, and managed-device provisioning decisions.
