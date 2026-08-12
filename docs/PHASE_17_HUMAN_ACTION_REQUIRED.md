# Phase 17 Human Action Required — Family Membership

## Required local Firebase artifact restoration

The recovered workspace is missing both local-only artifacts that existed before the sandbox reset. A read-only inventory of the canonical working tree, project-file locations, and Phase 13–17 delivery archives found no approved copy. A separately uploaded Google Services file is expressly non-canonical in the forensic report and must not be used without owner confirmation:

| Required artifact | Canonical destination | Why required | Safe action |
|---|---|---|---|
| Generated FlutterFire options | `lib/firebase_options.dart` | Required by `GuardianFirebaseBootstrap` and five existing Flutter test files. | Restore the original generated file from the approved secure Guardian Eye workspace. Do not handwrite it, use an unrelated project, or regenerate it against another project. |
| Android Google Services configuration | `android/app/google-services.json` | Required for Android Firebase build configuration. | Restore the original approved `com.guardianeye.app` configuration from secure project storage. Do not substitute the separately uploaded file without an approved identity comparison. |

After restoring both original artifacts, run the following locally:

```bash
export PATH=/home/ubuntu/flutter/bin:$PATH
cd /home/ubuntu/guardian_eye_flutter
flutter pub get
flutter analyze
flutter test --reporter expanded
GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=1' flutter build apk --debug --no-pub
```

## Authoritative current-member binding

The family-members screen accepts an optional `actorMemberId` and applies the centralized permission matrix to that explicit member. Dashboard navigation currently provides no proven mapping from the authenticated Firebase account to an active local `FamilyMember`. Consequently, Dashboard opens the screen in **read-only mode**; it does not infer ownership merely because a primary-parent record exists locally.

The trusted account-to-member lookup is now implemented and covered by local fail-closed regression tests. Before treating Dashboard actions as runtime-validated, restore the approved artifacts and exercise the lookup from a Flutter client against the Emulator with distinct parent, co-parent, and child identities.

## Device and backend validation

| Validation | Required action | Status today |
|---|---|---|
| Android APK and runtime | Use an Android host with a configured SDK and a physical device or compatible AVD. Exercise offline creation, sync recovery, invitation cancellation/expiry, and role revocation. | **Not performed** |
| iPhone runtime | Use macOS, Xcode, CocoaPods, valid signing, and an iPhone/simulator. | **Not performed** |
| Flutter client ↔ Emulator | Run the restored client with explicit `GUARDIAN_FIREBASE_USE_EMULATORS=true` and a host reachable from the device. | **Not performed** |
| Real Firebase backend | Obtain explicit owner approval for a reviewed deployment and real-backend validation plan. Do not deploy from this state. | **Not authorized; not performed** |

> No completion action in this document authorizes creating a Firebase project, replacing `google-services.json`, generating a new `firebase_options.dart`, changing `com.guardianeye.app`, deploying to `manus-guardian`, or placing Admin credentials in the Flutter client.
