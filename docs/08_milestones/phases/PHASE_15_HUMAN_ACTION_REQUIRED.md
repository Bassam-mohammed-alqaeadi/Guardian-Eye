# Phase 15 Human Action Required

## Current gate

The Flutter, SQLite, and Firebase Emulator paths are validated. An APK build stopped at Flutter kernel snapshot in this sandbox before Kotlin compilation or installation, so all Usage Access, Android bridge, lifecycle, and enforcement results remain unverified on hardware.

> Do not describe a device as protected, restricted, or app-blocked until the corresponding physical-device test produces evidence.

## Android host and APK build

On a host with Android SDK, JDK 17, and sufficient memory, run:

```bash
export PATH=/path/to/flutter/bin:$PATH
export JAVA_HOME=/path/to/jdk-17
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT="$ANDROID_HOME"
cd guardian_eye_flutter
flutter doctor -v
flutter clean
flutter pub get
GRADLE_OPTS='-Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=1' \
  flutter build apk --debug
```

Record the Flutter version, Android API/device model, APK SHA-256, and full build outcome. The current sandbox build failure must not be overwritten by a claim that Kotlin source compiled.

## Physical Android device and USB debugging

Enable Developer options and USB debugging manually on the child test device. Then run:

```bash
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb logcat -c
adb logcat | grep -E 'Guardian|UsageStats|flutter'
```

Enroll only a dedicated test child device. Confirm the child Firebase UID is distinct from the parent UID, replayed pairing fails, revoked device behavior remains revoked, and the parent cannot submit child usage as its own identity.

## Usage Access consent and observation

On the child device, open Guardian Eye’s **Permissions** screen, select Usage statistics, and manually enable Guardian Eye from the Android Settings page. Deny first, run **Measure usage and evaluate policy**, and capture the `blockedByPermission`/permission-required state. Then grant access, use a policy-target Android package, return to Guardian Eye, and run the same on-demand measurement.

Verify that the local daily summary matches Android-observable data for that package. The evidence must include the package target, time window, local summary, rule limit, domain decision, and Android adapter result. If the adapter reports unsupported, retain that result—do not relabel it applied.

## Offline, restart, and lifecycle protocol

With a valid delivered policy, disable network, take a measurement, force-stop Guardian Eye, reopen it, and verify the stored policy version and usage summary are preserved. Re-enable network and verify queued events behave according to the existing Outbox state. Reboot and Doze are not implemented lifecycle triggers; record them as unverified unless a future dedicated background implementation and evidence exist.

## Firebase setup and real backend boundary

For Emulator validation, use the project’s explicit environment defines and an Android Emulator host address where applicable:

```bash
flutter run \
  --dart-define=GUARDIAN_FIREBASE_CONFIGURED=true \
  --dart-define=GUARDIAN_FIREBASE_USE_EMULATORS=true \
  --dart-define=GUARDIAN_FIREBASE_EMULATOR_HOST=10.0.2.2
```

Do not create another Firebase project. Do not substitute `google-services.json` or `firebase_options.dart`, and do not deploy the new local usage-summary rule to `manus-guardian` without an explicit owner decision to change real Firebase configuration. Cloud Functions deployment remains a separate Blaze-plan owner decision.

## Play review and release signing

Before a Play release, have the owner conduct a policy/legal review of disclosed data processing, Usage Access purpose, privacy policy, Data safety form, and any future Accessibility or device-owner proposal. Accessibility is not part of Phase 15.

Create an upload key only in the owner’s protected keystore process, outside source control, for example:

```bash
keytool -genkeypair -v -keystore guardian-eye-upload.jks \
  -alias guardian-eye-upload -keyalg RSA -keysize 2048 -validity 10000
```

Keep the keystore and `key.properties` outside the repository and export archive. Do not send their values in chat or place them in Flutter source.
