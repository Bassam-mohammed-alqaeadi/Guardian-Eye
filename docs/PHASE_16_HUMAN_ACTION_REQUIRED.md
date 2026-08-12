# Phase 16 Human Action Required

## Child and parent runtime validation

Use two distinct Firebase-authenticated test identities: one parent and one child. The child identity must be bound to an active child device; do not use a parent UID as a child UID. Run the app against the Firebase Emulator first and retain redacted evidence of all steps.

```bash
export PATH=/path/to/flutter/bin:$PATH
cd guardian_eye_flutter
flutter run \
  --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true \
  --dart-define=GUARDIAN_FIREBASE_USE_EMULATORS=true \
  --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=10.0.2.2
```

On the child session, open the child policy experience, confirm the last delivered policy and offline/Usage Access wording, create one request, and cancel a second pending request. On the parent session, review the cached request, approve one and deny one. Confirm that approval yields a device-scoped override, that another child device does not receive the allowance, and that expiry restores the original decision after the timestamp.

## Offline and restart protocol

Disable network after policy delivery. Create or view cached request data, force-stop the application, reopen it, and verify the policy, request status, local usage, queue labels, and expired override decision. Re-enable network and record how the existing Outbox transitions. Do not claim remote confirmation merely because an event enters the queue.

## Build, device, and Usage Access gate

The sandbox stopped at Flutter kernel snapshot before Kotlin compilation. On a host with Android SDK, JDK 17, sufficient memory, and a device/AVD, run:

```bash
export PATH=/path/to/flutter/bin:$PATH
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/android-sdk
cd guardian_eye_flutter
flutter clean
flutter pub get
GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=1' \
  flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Manually deny and then grant Usage Access in Android Settings. Compare a policy-target package’s Android-observable daily usage to the locally stored summary. Capture the adapter result. If it is `unsupported`, record it as unsupported; do not call it blocked.

## Firebase and release boundary

Do not deploy the new exception-request rules to `manus-guardian` unless the owner explicitly approves a real Firebase configuration change. Do not create a Firebase project, replace the local client configuration files, enable Blaze, or deploy Functions for Phase 16. Do not claim FCM delivery. Keep keystores, `key.properties`, `google-services.json`, and `firebase_options.dart` outside the source archive and out of chat.
