# Guardian Eye Pro — Reproducible Setup (Fresh-Clone Procedure)

Single documented procedure so that any fresh clone builds and validates without hidden local state from a previous environment. All steps below were verified on 2026-08-14 in a clean sandbox; the owner's machine follows the same path with the platform substitutions noted.

## 1. Prerequisites

| # | Prerequisite | Exact requirement |
| - | ------------ | ----------------- |
| 1 | OS | Windows 10/11 x64 (owner) or Ubuntu 24.04+ (CI/sandbox) |
| 2 | Git | 2.40+ |
| 3 | Flutter | 3.35.7 stable (CANONICAL — verified 2026-08-14; matches owner machine) |
| 4 | Dart | 3.9.2 (bundled with Flutter 3.35.7) |
| 5 | Android SDK | cmdline-tools latest + platform-tools + build-tools; licenses accepted |
| 6 | JDK | 21 (canonical; see toolchain baseline §3) |
| 7 | Firebase CLI | `npm i -g firebase-tools` (Node 20 host) |
| 8 | Node / npm | Node 20, npm bundled |
| 9 | Android Studio | Latest (provides JBR 21 and device tooling; optional for CLI-only builds) |
| 10 | VS Code | 1.90+ with Flutter + Dart extensions (owner's editor of choice) |
| 11 | Physical device (optional but required for full acceptance) | Android 5.0+ with USB debugging; owner's SM-S906U (Android 16 / API 36) is the registered validation device |

## 2. Clone and Flutter Setup

```bash
git clone https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git
cd Guardian-Eye
flutter doctor                     # confirm Android toolchain GREEN
flutter pub get                    # dependency resolution (clean, no cache assumption)
flutter analyze                    # 0 errors, 0 warnings
flutter test                       # full suite
```

`flutter pub get` resolves `pubspec.yaml` deterministically using the committed `pubspec.lock`; the Gradle wrapper (`gradle-9.1.0`) pulls its own distribution on first Android build, so no hidden Gradle installation is required.

## 3. Firebase Configuration (Manual Account Authentication)

The repository commits `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json`, and `.firebaserc` — they identify project `manus-guardian` (Android app `1:165160049292:android:922e6c8a4749c42e4839a9`, package `com.guardianeye.app`). They are **read-only identities**: they never change during development and must not be regenerated without owner approval.

Interactive authentication is a human action performed by the owner in the browser (never paste tokens or keys anywhere):

```bash
firebase login                     # browser OAuth by the owner
firebase use guardian              # selects manus-guardian (.firebaserc alias)
firebase projects:list             # confirms access to manus-guardian
```

## 4. Emulator Validation

```bash
./tool/run_firebase_emulator_tests.sh   # Firestore 15/15 + Functions 2/2
```

Emulator ports: auth `9099`, firestore `8080`, functions `5001`, UI `4000` (see network-changes doc for scoped firewall notes). Never run emulator tests against the live project.

## 5. Android Build and Device

```bash
flutter build apk --debug          # debug APK
flutter devices                    # discovers USB devices / AVDs
flutter run                        # or install the APK manually
```

On the owner's Windows machine, add `%LOCALAPPDATA%\Android\Sdk\platform-tools` to PATH (canonical ADB, toolchain baseline §4). For the owner's SM-S906U: enable Developer options → USB debugging, authorize the host once, then `flutter devices` lists it.

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| `flutter pub get` fails | No internet / proxy | Set HTTPS proxy in Dart config; verify `flutter doctor` network |
| Gradle download fails | Gradle distribution cache missing + no network | Wrapper re-downloads `gradle-9.1.0-all.zip`; ensure outbound 443 to services.gradle.org |
| `ADB server version mismatch` | Two ADB installations (dual-install) | Use canonical platform-tools ADB (baseline §4); kill stray servers |
| JDK error at Android build | JDK 23 picked up | Ensure canonical JDK 21 via `JAVA_HOME` (baseline §3) |
| Emulator suite fails on Windows | Firewall blocking loopback/5037 | Scoped rules in `LOCAL_ENVIRONMENT_NETWORK_CHANGES.md` |
| UsageStats returns empty | Permission not granted on device | Grant via system settings / `adb shell pm grant ... PACKAGE_USAGE_STATS` |

## 7. Verification Checklist (Definition of Done — mandate §25)

A fresh clone is complete when, on the target machine, the following all succeed without hidden files from a previous environment: (1) `flutter pub get` resolves; (2) all referenced asset directories exist (`assets/images/`, `assets/translations/`, `assets/icons/`, populated via `.gitkeep`); (3) `flutter build apk --debug` compiles Android; (4) `flutter analyze` and `flutter test` pass; (5) `flutter devices` discovers the intended Android device; (6) `flutter run` starts the app; (7) Firebase connectivity follows the documented manual login (no stored tokens committed). Items 5–7 require the owner's physical device and interactive sign-in and are therefore recorded as **HUMAN ACTION REQUIRED** in the master register (GA-01, GA-04, GA-05, GA-06).

## 8. Repository Hygiene Notes

The following are intentionally committed and must remain committed: `pubspec.lock`, `.flutter-plugins-dependencies`, Gradle wrapper, `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json`, `.firebaserc`, mipmap launcher icons, and `firebase/functions/node_modules` (historical; removal is a separate owner decision — see register). The following are intentionally ignored: `.dart_tool/`, `build/`, `.gradle/`, `android/local.properties`. The `assets/images/` and `assets/translations/` directories are currently empty placeholder directories preserved by `.gitkeep`-style tracking; the app loads no bundled image/translation assets at runtime (localization is code-defined), so a fresh clone builds cleanly. If a future milestone ships bundled assets, they must satisfy the asset rule: exist + tracked + referenced + included in build + available after fresh clone.
