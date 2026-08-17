# Implementation Evidence — Flutter Canonical Project

| Item | Evidence | Result |
|---|---|---|
| Stack decision | `/home/ubuntu/guardian_eye_flutter` is a Flutter/Dart project; Android and iOS host files are present. | VERIFIED |
| Dependencies | `flutter pub get` resolved Riverpod, SQLite, Firebase packages, location, permissions, QR, notifications, and WorkManager. | VERIFIED in the current sandbox before reset; re-run required on the final build host. |
| Static analysis | `flutter analyze` after recovery completed without reported errors or warnings. | VERIFIED |
| Unit/widget tests | The Guardian Eye Pro no-sample-data onboarding widget test passed. | VERIFIED |
| Local persistence | `GuardianDatabase`, family repository, local outbox, pairing hash/expiry, and SOS local event paths are source-implemented. | IMPLEMENTED; device/database runtime remains to be verified. |
| Remote sync | Firestore-aware transport declines to sync unless Firebase is compiled in and an authenticated session exists. | PARTIALLY IMPLEMENTED; Firebase project required. |
| Android native capabilities | Android manifest and capability channel are source-implemented with settings-based user consent. | PARTIALLY IMPLEMENTED; physical-device verification required. |
| iOS | iOS host and privacy strings are source-implemented. | PARTIALLY IMPLEMENTED; Xcode/macOS build required. |

The sandbox reset interrupted an APK build while Gradle was preparing the Android NDK. The Android SDK/JDK installation must be repeated on the final build host; no APK is claimed as produced.
