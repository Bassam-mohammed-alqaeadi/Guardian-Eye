# PHASE 17 — CONTROLLED GRADLE REMEDIATION REPORT

**Project:** Guardian Eye Pro (Flutter)
**Date:** August 13, 2026
**Author:** Manus AI
**Scope:** Android Gradle build remediation only (authorized controlled change). No Firebase resources were touched, nothing was deployed, no Phase 18 started, and nothing was pushed to GitHub.

---

## 1. Root Cause

The APK build failure `:cloud_firestore → sourceCompatibility has been finalized` was **self-inflicted by a previous temporary Gradle workaround** in `android/build.gradle.kts`. During earlier Phase 17 troubleshooting of the `workmanager_android` JVM-target conflict, an `afterEvaluate` block was added that overrode `compileOptions` on every Android library subproject **after** the subproject scripts had already finalized their `compileOptions`. Under AGP 9.0.1, the FlutterFire plugins (`cloud_firestore`, `firebase_core`, etc.) read `project.ext.javaVersion` from their own `local-config.gradle` and finalize their compile options during script evaluation — before any `afterEvaluate` can write to them. The result was the "has been finalized" script exception on plugin configuration.

The second, deeper conflict is structural: under AGP 9, plugins such as `workmanager_android` no longer apply `kotlin-android` themselves (they assume AGP 9's built-in Kotlin support), which means:

| Plugin family | Its own Java target | Kotlin jvmTarget without intervention |
|---|---|---|
| FlutterFire (`firebase_*`) | 17 (via `local-config.gradle`) | unset → compiler default → **17**, consistent |
| `workmanager_android` | 1.8 (hardcoded in its `build.gradle`) | unset → compiler default → **21** (Kotlin 2.x), **inconsistent** |

The Kotlin Gradle plugin aborts compilation with `Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks` whenever the two disagree. The correct remediation is to mirror each plugin's own finalized Java target into its KotlinCompile tasks at task-configuration time — reading a finalized value is allowed; only writing to a finalized extension is forbidden.

## 2. Files Changed

Only two files were modified, both inside `android/` build configuration. No file outside this scope was touched.

| File | Change | Justification |
|---|---|---|
| `android/build.gradle.kts` | Removed the `afterEvaluate { compileOptions {...} }` override entirely. Replaced it with: (a) publishing `rootProject.ext["javaVersion"] = JavaVersion.VERSION_17` before plugin evaluation (this is exactly what FlutterFire `local-config.gradle` reads), and (b) a `tasks.withType<KotlinCompile>().configureEach { ... }` block that lazily reads each library plugin's own finalized `compileOptions.targetCompatibility` and mirrors it into `compilerOptions.jvmTarget` | Removes the forbidden after-Evaluate write; resolves the `workmanager_android` Java 1.8 / Kotlin mismatch with a read-only, configuration-time mirror |
| `android/gradle.properties` | `org.gradle.jvmargs` 1536m → 1024m | The 4 GB sandbox was OOM-killing the Gradle daemon during full debug compilation (`Gradle build daemon disappeared unexpectedly`). 1024 m runs reliably within available memory. |

The following files were inspected and left **untouched**: `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`.

## 3. Exact Nature of the Gradle Fix

The final `subprojects` block in `android/build.gradle.kts` is:

```kotlin
subprojects {
    project.evaluationDependsOn(":app")
    rootProject.ext["javaVersion"] = JavaVersion.VERSION_17
    plugins.withId("com.android.library") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaTarget = project.extensions
            .findByType<com.android.build.api.dsl.LibraryExtension>()
            ?.compileOptions?.targetCompatibility
            ?: JavaVersion.VERSION_17
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget.toString())
        )
    }
}
```

Design guarantees: no `afterEvaluate`, no `resolutionStrategy`, no version upgrades, no per-plugin name branching (the JVM target is read dynamically from each plugin's own finalized extension, so future plugins inherit the correct value automatically), and only read operations on finalized extensions.

## 4. Validation Evidence

### flutter analyze

> Analyzing guardian_eye... No issues found! (ran in 4.2s)

**Result: GREEN — 0 issues.**

### Flutter targeted tests

| Suite | Result |
|---|---|
| `test/family_actor_binding_service_test.dart` | 10/10 PASS — All tests passed! |
| `test/family_membership_test.dart` | 4/4 PASS — All tests passed! |

**Result: GREEN.** The earlier full-suite result of 73/73 PASS was confirmed in the read-only validation stage and remains valid; the remediation touched only Gradle configuration, not Dart code.

### Firebase Emulator validation (`./tool/run_firebase_emulator_tests.sh`)

| Emulator | Result |
|---|---|
| Firestore | 15 tests, 15 pass, 0 fail |
| Functions | 2 tests, 2 pass, 0 fail |
| Script exit code | 0 |

**Result: GREEN.**

### Android environment

`flutter doctor -v` reports `[✓] Flutter (Channel stable, 3.35.5)` and `[✓] Android toolchain (Android SDK version 36.0.0)`. `flutter analyze` reports no issues. These were confirmed in the preceding read-only validation stage.

## 5. APK Build Result — GREEN

Exactly one build attempt was made after the fix: `flutter build apk --debug --no-tree-shake-icons`.

| Attribute | Value |
|---|---|
| Outcome | BUILD_SUCCESS (single attempt) |
| APK path | `build/app/outputs/flutter-apk/app-debug.apk` |
| APK size | 179,897,805 bytes (≈ 172 MB, debug build) |
| Build duration | 1m 30.0s wall clock |
| Flutter version | 3.35.5 (stable) |
| Dart version | 3.9.2 |
| Gradle version | 9.1.0 |
| AGP version | 9.0.1 |
| Kotlin version | 2.1.21 |
| compileSdk | 36 (Flutter platform default) |
| targetSdk | 36 (defaults to compileSdk in merged manifest) |
| minSdk | 24 (aapt dump badging) |
| package / applicationId | `com.guardianeye.app` |
| versionCode / versionName | 1 / 1.0.0 |

### Firebase identity verification (post-build, read-only)

| Identity field | Expected | Observed | Match |
|---|---|---|---|
| Firebase project | `manus-guardian` | `manus-guardian` | ✅ |
| Project number | 165160049292 | 165160049292 | ✅ |
| Android App ID | `1:165160049292:android:922e6c8a4749c42e4839a9` | `1:165160049292:android:922e6c8a4749c42e4839a9` | ✅ |
| Android package | `com.guardianeye.app` | `com.guardianeye.app` | ✅ |

Both `lib/firebase_options.dart` and `android/app/google-services.json` remain byte-identical to their restored Phase 17 versions (SHA-256 verified unchanged from the Phase 17 recovery baseline).

## 6. Workspace Integrity Result — GREEN (scoped changes only)

SHA-256 comparison against the pre-remediation baseline:

| File | Status in this remediation |
|---|---|
| `android/build.gradle.kts` | Changed (intended — the fix) |
| `android/gradle.properties` | Changed (intended — JVM args) |
| `android/app/build.gradle.kts` | **Unchanged** |
| `android/settings.gradle.kts` | **Unchanged** |
| `android/gradle/wrapper/gradle-wrapper.properties` | **Unchanged** |
| `lib/firebase_options.dart` | **Unchanged** |
| `android/app/google-services.json` | **Unchanged** |
| `pubspec.yaml` / `pubspec.lock` | **Unchanged** |
| `firebase.json` / Firestore Rules / Functions | **Unchanged** |

Note on scope: three files (`lib/core/localization/app_localizations.dart`, `lib/presentation/screens/family_safety_experience_screens.dart`, `test/local_repository_test.dart`) differ from the *Phase 16* baseline; these are the **previously completed and validated Phase 17 fixes** (missing localization keys, lazy-build list fix, and the stale test fixture date) and are unchanged relative to the Phase 17 recovery baseline recorded at the start of this phase. No business logic, security layer, localization key content, or test assertion was modified by the Gradle remediation.

## 7. Remaining Blockers

None. All mandatory gates of this remediation are evidenced as passing. The only operational observation is that the sandbox's 4 GB memory requires `org.gradle.jvmargs` to stay at or below 1024 m for a full debug build; a release build or CI environment with more memory can restore a larger heap.

## 8. Recommendation for Final Phase 17 Gate

With every evidence gate satisfied — Firebase identity GREEN, flutter analyze GREEN, actor binding 10/10 GREEN, membership 4/4 GREEN, Firestore emulator 15/15 GREEN, Functions emulator 2/2 GREEN, Android SDK GREEN, APK build GREEN (172 MB debug APK produced and verified), and workspace integrity GREEN — **Phase 17 is recommended for final closure**. The APK build gate, previously the sole failing gate, is now evidenced as passing. No further experiments, dependency upgrades, or configuration changes are recommended before closure. Phase 18 should not begin until explicitly authorized.
