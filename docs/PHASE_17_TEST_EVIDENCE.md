# Phase 17 Test Evidence — Family Membership & Multi-Parent Foundation

**Recorded:** 12 August 2026

## Evidence summary

| Area | Command or test | Result | Evidence level |
|---|---|---|---|
| Membership repository | `flutter test test/family_membership_test.dart --reporter expanded` | 4 tests passed: matching-account acceptance/idempotency, expiry/cancellation, owner-only management and device revocation, and permission matrix. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Firestore mutation contract | `flutter test test/firebase_contract_test.dart --reporter expanded` | 7 tests passed, including invitation creation and a single mutation with the invitation update plus account-keyed member write. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Family members UI | `flutter test test/family_members_screen_test.dart --reporter expanded` | 1 Widget test passed: actual member data, device connectivity state, pending invitation display, and the owner invitation form. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Local regression suite | 16 Flutter test files selected to exclude only direct `firebase_options.dart` consumers | 51 tests passed after repairing the independently detected device-scoped override leak. | **VERIFIED LOCALLY** |
| Firestore authorization | `./tool/run_firebase_emulator_tests.sh` | 15 Firestore Rules tests passed, including owner invite, atomic recipient acceptance, wrong-recipient denial, replay denial, expiry denial, cancellation denial, child denial, role-escalation denial, and cross-family denial. | **VERIFIED IN EMULATOR** |
| Functions emulator | Same command | 2 Functions emulator tests passed. | **VERIFIED IN EMULATOR** |
| Static analysis | `flutter analyze` | Blocked by two errors caused only by the absent local `lib/firebase_options.dart`. No unrelated analyzer diagnostics remained. | **IMPLEMENTED — VALIDATION BLOCKED** |
| Full Flutter suite | `flutter test --reporter expanded` | The pre-repair run identified five load failures that directly import the absent Firebase options and one genuine device-scoped-override failure. The latter was fixed and its isolated test now passes. The complete suite has not been rerun because the same five Firebase-option load failures are deterministic. | **IMPLEMENTED — VALIDATION BLOCKED** |
| Debug APK | `flutter build apk --debug --no-pub` with constrained Gradle settings | Blocked immediately: no Android SDK is installed in the recovered sandbox. No APK was created. | **HUMAN ACTION REQUIRED** |
| Trusted actor binding | `flutter test test/family_actor_binding_service_test.dart --reporter expanded` | 10 tests passed for valid parent/co-parent binding and all specified fail-closed conditions. | **IMPLEMENTED + VERIFIED LOCALLY** |
| Closure Emulator rerun | `./tool/run_firebase_emulator_tests.sh` | 15 Rules and 2 Functions tests passed after binding implementation; no deployment occurred. | **VERIFIED IN EMULATOR** |

## Verification scope

The Emulator evidence used only the synthetic `guardian-eye-emulator` project ID configured by the test runner. No rule, index, Function, or client configuration was deployed to `manus-guardian` during Phase 17 recovery or validation.

> Emulator results verify the local rule contract only. They do not constitute real-backend, Android-device, or iPhone-device verification.

## Recovery evidence

The sandbox reset left a partial canonical tree. The Phase 16 delivery archive was staged and copied with a no-overwrite operation, while SHA-256 checks confirmed preservation of the recovered Phase 17 domain, SQLite, authorization, Firestore-contract, Firestore-rules, test, and task-tracking files. The missing membership repository was reconstructed from the preserved Phase 17 architecture, schema, contract, and tests; it is covered by the local test evidence above.

## Conditions that prevent a GREEN Phase 17 gate

The Phase 17 acceptance gate is **not GREEN**. The original local-only Firebase artifacts are absent after the sandbox reset, the Android SDK is absent, no physical device or simulator is attached, and no real Firebase deployment was authorized or performed. The current-account-to-local-member binding is implemented and locally tested, but its Flutter-runtime and Emulator-client validation awaits restoration of the original artifacts.
