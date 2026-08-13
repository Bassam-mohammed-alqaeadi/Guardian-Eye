# Phase 17 Stable Checkpoint

**Document purpose:** This checkpoint permanently records the restored, verified Phase 17 baseline of the Guardian Eye Pro project following a sandbox reset that destroyed all unpushed working state. It also states precisely what this checkpoint does and does not contain.

**Author:** Manus AI
**Recovery timestamp:** 2026-08-13T10:40Z (UTC)
**Git branch:** `phase17-stable-checkpoint` (GitHub: `Bassam-mohammed-alqaeedi/Guardian-Eye`)
**Checkpoint commit hash:** `2608d2afec9698b0ba1969f7ad39a511d340d888`
**Baseline commit hash:** `558e2be` (root of the checkpoint branch, restored from the verified Phase 17 closure backup)

---

## 1. What Happened

A sandbox reset destroyed the in-progress UX Sprint 01 ("Golden Journey") implementation, which had never been pushed to GitHub. By explicit user decision, Sprint 01 was **not** recreated in this session. The project workspace was instead rebuilt from the verified `Guardian_Eye_Pro_Phase17_Closure_Trusted_Actor_Binding.zip` backup, re-validated end to end, and pushed as a frozen, stable checkpoint branch so this loss cannot recur.

## 2. Firebase Identity (Verified Without Modification)

The Firebase platform configuration was restored and verified to match the mandated identity exactly. No Firebase resource was created, modified, or deployed.

| Field | Verified value |
| --- | --- |
| `projectId` | `manus-guardian` |
| Project number | `165160049292` |
| `package_name` / applicationId | `com.guardianeye.app` |
| Android `mobilesdk_app_id` | `1:165160049292:android:922e6c8a4749c42e4839a9` |
| `lib/firebase_options.dart` | Exists, tracked, matches the values above |
| `android/app/google-services.json` | Exists, tracked, matches the values above |

## 3. Test Evidence

All validation was executed directly on the recovered workspace. Every gate below passed with direct evidence.

| Gate | Command | Result |
| --- | --- | --- |
| Static analysis | `flutter analyze` | **No issues found** (0 issues) |
| Flutter widget and unit suite | `flutter test` | **73/73 All tests passed** |
| Firestore emulator (security rules) | `./tool/run_firebase_emulator_tests.sh` | **15/15 passed, 0 failed** |
| Cloud Functions emulator | Same run, `test:emulator` | **2/2 passed, 0 failed** |

Two categories of pre-existing defects in the restored baseline zip were repaired as part of checkpoint validation, and both repairs are content-level fixes only (no architecture, security, or business logic change):

1. **Localization gaps.** The restored `family_safety_experience_screens.dart` referenced localization keys absent from `app_localizations.dart`, which would render as raw key strings at runtime (`requestPending`, `requestApproved`, `requestDenied`, `requestExpired`, `requestCancelled`, `approveRequest`, `denyRequest`, `requestDecisionSaved`, `temporaryExceptionUntil`, `approvalNotice`, `childPolicyExplanation`). Both Arabic and English entries were added with truthful, non-blocking wording, and the approval honesty notice ("Approval creates a temporary policy allowance...") was wired into the pending request card. After the repair, `exception_request_screen_test.dart` passes 4/4.
2. **Time-sensitive test fixture.** `local_repository_test.dart` used a hard-coded expiry `DateTime(2026, 8, 12, 22)` that is no longer in the future, causing `PolicyRepository.createOverride` validation to reject the override. The fixture was changed to `DateTime.now().toUtc().add(10 minutes)` — a fixture data fix only.

## 4. Android Build Evidence

The Android debug APK evidence from the completed Phase 17 closure (APK path `build/app/outputs/flutter-apk/app-debug.apk`, package `com.guardianeye.app`) is preserved in the Phase 17 closure zip referenced by this document. The APK was not rebuilt in this session because the instruction targeted minimum validation only; the Flutter and Android toolchain remain available to rebuild it on demand.

## 5. Secrets Review

The full diff of the checkpoint was reviewed before pushing. The only API credential present anywhere in the committed tree is the Firebase browser `apiKey` inside `lib/firebase_options.dart` (`AIzaSy...`), which is the non-secret public browser key mandated to be tracked in git by project policy. No private keys, service accounts, passwords, or OAuth tokens are present in any committed file. Build artifacts (`firebase/functions/lib/index.js`, `node_modules/`, debug logs) were explicitly excluded from the commit.

## 6. Git State

| Item | Value |
| --- | --- |
| Checkpoint branch | `phase17-stable-checkpoint` on origin |
| Checkpoint commit | `2608d2afec9698b0ba1969f7ad39a511d340d888` |
| Branch root | `558e2be` (Phase 17 baseline restored, first commit) |
| Origin `master` | **Untouched** — retains its own history through Phase 18 (`e1d0d2c` at tip); no force push, no history rewrite, no deletion |
| Working tree | Clean (remaining untracked files are build artifacts: `node_modules/`, compiled `index.js`) |

## 7. Known Non-Claims

This checkpoint deliberately does not claim the following:

1. **Sprint 01 is NOT included.** All UX Sprint 01 work (first-run family naming, settings, child home experience, policy preview confirmation, exception request dialog, Golden Journey widget tests) was destroyed by the reset and was explicitly not recreated. The saved mission brief and audit documents remain as the specification for a future Experience Sprint.
2. **The checkpoint branch is intentionally separate from `master`.** The remote `master` branch had already advanced beyond Phase 17 (into Phase 18 territory) by the time the restore was attempted, so the restored snapshot shares no common ancestor with it. Pushing to `master` without force-pushing was impossible, and force-pushing was prohibited; therefore a dedicated checkpoint branch was created and the remote `master` history was left completely intact.
3. **No Firebase deployment, Blaze activation, or resource creation occurred.** All emulator runs used the isolated synthetic project `guardian-eye-emulator`.
4. **No Phase 18/19 work was started.**

## 8. Recovery Procedure for Future Resets

To reproduce this checkpoint from the `Phase17_Closure_Trusted_Actor_Binding.zip` backup: extract into `/home/ubuntu/guardian_eye`, `flutter pub get`, restore `lib/firebase_options.dart` and `android/app/google-services.json` from the verified upload copies, run `flutter analyze`, `flutter test`, and `./tool/run_firebase_emulator_tests.sh`, verify Firebase identity fields, then commit and push to a new checkpoint branch (never force-push to `master`).
