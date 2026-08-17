# Guardian Eye Pro — Toolchain Baseline (Frozen Matrix)

One authoritative compatibility matrix for the entire project. All versions below were determined by direct inspection of the repository (Gradle wrapper, `settings.gradle.kts`, `pubspec.yaml`, function engines, Flutter SDK) on 2026-08-14, not chosen arbitrarily. Do not upgrade, downgrade, or experimentally alter any component; every change must be necessary, compatibility-driven, minimal, tested, and documented.

## 1. Frozen Matrix

| Component | Version | Source of truth | Notes |
| --------- | ------- | --------------- | ----- |
| Flutter | 3.35.7 (stable, CANONICAL) | `flutter --version --machine`, 2026-08-14 verified build+test on this version | Owner machine: Windows 11 Flutter 3.35.7 stable (authoritative) |
| Dart | 3.9.2 (bundled with Flutter 3.35.7) | `dart --version`; pubspec.lock SDks: `>=3.9.0 <4.0.0` — 3.9.2 satisfies |
| Android SDK | cmdline-tools / platform-tools (latest pinned by Flutter doctor) | `/opt/android-sdk` layout | No fixed platform-tools version pinned in repo; Flutter resolves via `local.properties`-less setup |
| compileSdk | Flutter default (= 36 default at BOTH Flutter 3.35.7 and 3.47.0 — verified in FlutterExtension.kt) | `android/app/build.gradle.kts` | Not hard-pinned; follows Flutter's default |
| targetSdk | Flutter default (`flutter.targetSdkVersion` = 35) | `android/app/build.gradle.kts` | Same |
| minSdk | Flutter default (`flutter.minSdkVersion` = 21) | `android/app/build.gradle.kts` | Aligns with UsageStats API availability (API 21+) |
| Build tools | Gradle-plugin default (no `buildToolsVersion` declared) | `android/app/build.gradle.kts` | AGP 9.x selects compatible build tools automatically |
| JDK | **21 (canonical)** | `java -version` = openjdk 21.0.11 on build host; Flutter points to Android Studio JBR 21 on the owner's machine | See §3 JDK rule |
| Gradle | 9.1.0 | `android/gradle/wrapper/gradle-wrapper.properties` (`gradle-9.1.0-all.zip`) | Wrapper-driven; identical on every clone |
| AGP | 9.0.1 | `android/settings.gradle.kts` line: `id("com.android.application") version "9.0.1"` | Requires JDK 17+ at build time |
| Kotlin | 2.1.21 | `android/settings.gradle.kts`: `id("org.jetbrains.kotlin.android") version "2.1.21"` | Kotlin Gradle plugin + stdlib aligned |
| Firebase CLI | >= 14.x (current release at 2026-08-14) | `npm i -g firebase-tools` | Emulator suite auth/firestore/functions/UI |
| Node | 20 | `firebase/functions/package.json` engines `{"node": "20"}` | Functions runtime and CLI host |
| npm | Bundled with Node 20 | Same | `firebase/functions/package-lock.json` committed |

## 2. Verification Contract

After any environment change, the following must pass with no modifications to the versions above:

```bash
flutter clean
flutter pub get
flutter analyze        # 0 errors, 0 warnings (info notes allowed)
flutter test           # full suite GREEN (217/217 as of 2026-08-14)
./tool/run_firebase_emulator_tests.sh   # Firestore 15/15, Functions 2/2
flutter build apk --debug               # Android debug APK
```

## 3. JDK Rule (mandate §11)

The owner's host exposes **JDK 23 on PATH** while Flutter is configured to use Android Studio's **JBR 21**. JDK 23 is **not** silently adopted. AGP 9.0.1 supports JDK 21–23 at build time, but the canonical project JDK is **21**, because the entire chain (Flutter-embedded Dart VM, Gradle 9.1.0, AGP 9.0.1, Kotlin 2.1.21) is validated against JDK 21, and the Flutter Android tooling itself resolves JBR 21. The owner keeps JDK 23 installed and on PATH unchanged; the project documents JDK 21 as canonical, and the build selects it through `JAVA_HOME` override in `android/local.properties`-style tooling if a mismatch ever surfaces. No JDK is removed or reinstalled on the owner's machine without explicit justification and approval.

## 4. ADB Rule (mandate §12)

The owner's host exposes two ADB installations (Android Studio bundled + SDK platform-tools standalone). The audit finds both functional; the **canonical ADB for development is the SDK platform-tools installation** (`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`), because it is the version the Android Gradle plugin and Flutter use internally, and it receives standalone updates. The Android Studio bundled copy is left installed (deleting it risks Studio breakage). If `adb devices` shows duplicates or version-mismatch warnings, the reversible fix is to remove the SDK platform-tools directory from PATH and rely on Android Studio's copy, or vice versa — exactly one of the two directories must remain on PATH. Documented, reversible, no blind deletion.

## 5. Gradle / AGP / Kotlin Freeze (mandate §13)

Current state is already the newest stable combination that the repo builds against: Gradle 9.1.0 + AGP 9.0.1 + Kotlin 2.1.21. **No upgrade, downgrade, or experimental change is performed or recommended.** This combination was not changed to "make it build" — it is the state M1–M8 were implemented and validated on. Any future change must satisfy the five conditions of §1 (necessary, compatibility-driven, minimal, tested, documented) and be recorded here with a new date row.

| Date | Change | Reason | Evidence |
| ---- | ------ | ------ | -------- |
| 2026-08-14 | Baseline frozen | Mandate §13 | Matrix above + verification contract green |
