# Phase 17 Test Evidence — Family Membership & Multi-Parent Foundation

**Recorded:** 12 August 2026 · **Final reconfirmation:** 13 August 2026 (Phase 17 closure)
**Status: ALL BLOCKED ENTRIES RESOLVED — see § Final closure reconfirmation.**

## Evidence summary

| Area | Command or test | Result | Evidence level |
|---|---|---|---|
| Membership repository | `flutter test test/family_membership_test.dart --reporter expanded` | 4 tests passed: matching-account acceptance/idempotency, expiry/cancellation, owner-only management and device revocation, and permission matrix. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Firestore mutation contract | `flutter test test/firebase_contract_test.dart --reporter expanded` | 7 tests passed, including invitation creation and a single mutation with the invitation update plus account-keyed member write. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Family members UI | `flutter test test/family_members_screen_test.dart --reporter expanded` | 1 Widget test passed: actual member data, device connectivity state, pending invitation display, and the owner invitation form. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Local regression suite | 16 Flutter test files selected to exclude only direct `firebase_options.dart` consumers | 51 tests passed after repairing the independently detected device-scoped override leak. | **VERIFIED LOCALLY** |
| Firestore authorization | `./tool/run_firebase_emulator_tests.sh` | 15 Firestore Rules tests passed, including owner invite, atomic recipient acceptance, wrong-recipient denial, replay denial, expiry denial, cancellation denial, child denial, role-escalation denial, and cross-family denial. | **VERIFIED IN EMULATOR** |
| Functions emulator | Same command | 2 Functions emulator tests passed. | **VERIFIED IN EMULATOR** |
| Static analysis | `flutter analyze` | Previously blocked by the absent `lib/firebase_options.dart`; now **PASS — 0 issues** after Firebase client configuration recovery. | **VERIFIED** |
| Full Flutter suite | `flutter test --reporter expanded` | Previously blocked by Firebase-option load failures; after localization key restoration and fixture corrections: **PASS — 73/73**. | **VERIFIED** |
| Debug APK | `flutter build apk --debug` after Android SDK installation and controlled Gradle remediation | **BUILD_SUCCESS** — `build/app/outputs/flutter-apk/app-debug.apk` (≈172 MB, 1m 30s, single attempt). | **VERIFIED (debug artifact only)** |
| Trusted actor binding | `flutter test test/family_actor_binding_service_test.dart --reporter expanded` | 10 tests passed for valid parent/co-parent binding and all specified fail-closed conditions. | **IMPLEMENTED + VERIFIED LOCALLY** |

## Final closure reconfirmation (13 August 2026)

Immediately before the Phase 17 checkpoint commit, the complete validation suite was re-run without any source modification:

> `flutter analyze` — No issues found! (0 issues)
> `flutter test --reporter expanded` — 73 tests, all passed
> `./tool/run_firebase_emulator_tests.sh` — Firestore 15/15 PASS, Functions 2/2 PASS, script exit 0

## Verification scope

The Emulator evidence used only the synthetic `guardian-eye-emulator` project ID configured by the test runner. No rule, index, Function, or client configuration was deployed to `manus-guardian` during Phase 17 recovery or validation.

> Emulator results verify the local rule contract only. They do not constitute real-backend, Android-device, or iPhone-device verification. Physical-device, FCM, app-blocking, and iOS validations remain NOT YET PERFORMED; the debug APK is not a release-ready artifact.

## Recovery evidence

The sandbox reset left a partial canonical tree. The Phase 16 delivery archive was staged and copied with a no-overwrite operation, while SHA-256 checks confirmed preservation of the recovered Phase 17 domain, SQLite, authorization, Firestore-contract, Firestore-rules, test, and task-tracking files. The missing membership repository was reconstructed from the preserved Phase 17 architecture, schema, contract, and tests; it is covered by the local test evidence above. The missing Firebase client configuration was regenerated officially via FlutterFire CLI against the existing `manus-guardian` project, the Android SDK was installed, and the APK build gate was closed by the controlled Gradle remediation documented in `docs/phases/PHASE_17_CONTROLLED_GRADLE_REMEDIATION_REPORT.md`.
