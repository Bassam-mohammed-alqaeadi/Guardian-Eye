# Guardian Eye Pro — Real Testing Environment Setup Guide

Administrative workstream (Workstream C). This document records how to prepare a real Windows development machine so that the project's tests, emulators, and device validation run without avoidable local networking problems. It deliberately separates what has already been verified in the Manus sandbox from what the owner must do on their own machine.

## 1. What Is Already Verified (Manus Sandbox)

The following were proven working on 2026-08-14 and are reproduced identically on a correctly configured machine.

| Layer | State | Evidence |
| ----- | ----- | -------- |
| Flutter SDK (3.x stable) + Dart | GREEN | `flutter analyze` 0 errors / 0 warnings |
| Android SDK + Gradle | GREEN | `flutter build apk --debug` succeeded (Phase 17) |
| Firebase CLI auth (`manus-guardian`) | GREEN | `firebase projects:list` access confirmed |
| Firestore Emulator | GREEN | 15/15 rules tests |
| Cloud Functions Emulator | GREEN | 2/2 tests |
| Rules harness vs deployed snapshot | GREEN | 16/16 (includes M7/M8 paths) |
| Local test database (SQLite in-memory) | GREEN | 217/217 Flutter tests incl. M8 |
| Rules harness vs deployed snapshot | GREEN | 23/23 (includes M8 `enforcement_status` scenarios) |
| GitHub repo (master branch) | GREEN | M1–M7 checkpoints pushed; `phase17-stable-checkpoint` frozen at `274e181` |

## 2. Development Setup (Owner's Windows Machine)

| Item | Requirement | Owner Action |
| ---- | ----------- | ------------ |
| Git | Git for Windows 2.40+ | Install; set identity (`git config user.name/email`) |
| GitHub access | HTTPS OAuth via `git clone` or GitHub CLI `gh auth login` | Browser login by owner (never paste tokens in chat) |
| VS Code | 1.90+ | Install; add Flutter/Dart extensions |
| Flutter SDK | Same major version as sandbox (check `flutter --version`) | Install via flutter.dev; verify `flutter doctor` |
| Android SDK | platform-tools + build-tools; compileSdk 35 (per app) | Android Studio or cmdline-tools; accept licenses |
| JDK | JDK 17 (matches project Gradle) | Install; set `JAVA_HOME` |
| Firebase CLI | `npm i -g firebase-tools`; `firebase login` | Browser login by owner |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` | Optional; only regenerate config files if owner authorizes |
| AVD | API 33+ system image (Google Play or AOSP) | Via Android Studio Device Manager |

## 3. Backend Setup

The project uses one Firebase project, `manus-guardian` (project number `165160049292`), with Android app `1:165160049292:android:922e6c8a4749c42e4839a9` (package `com.guardianeye.app`). Existing `firebase_options.dart` and `google-services.json` in the repo must NOT be regenerated without owner approval. The deployed ruleset as of this writing is `e22c310a-c24e-4101-abb7-9df31c57e5cc` (verified via saved snapshot); the owner can verify the live id with `firebase firestore:rules:list --project manus-guardian`.

Local emulation requires no account: `./tool/run_firebase_emulator_tests.sh` runs Firestore + Functions emulators with the repo's rules and functions sources. Production boundaries: never run emulator tests against the live project, never publish rules or functions without owner approval, and Blaze must remain inactive until the owner explicitly activates it (currently BLOCKED — BILLING, register GA-21).

## 4. Device Setup (Physical Android)

| Step | Command / Path | Purpose |
| ---- | -------------- | ------- |
| USB debugging | Settings → Developer options → USB debugging | ADB pairing |
| ADB connection | `adb devices` | Verify authorized device |
| Install debug build | `flutter install` or `adb push build/app/outputs/flutter-apk/app-debug.apk` | On-device app |
| Grant usage access | `adb shell pm grant com.guardianeye.app android.permission.PACKAGE_USAGE_STATS` | UsageStats measurement |

**M8 critical device note (2026-08-14 truth-gate audit):** the M8 `EnforcementService` intentionally declares no `foregroundServiceType`, which means `startForeground` **throws on API 34+ and the service fails to start** (the failure is recorded honestly as `foreground_type_required_android_14`). The owner's registered device, SM-S906U, runs Android 16 (API 36), so **no M8 enforcement scenario can currently execute on it** until a legitimate service type (e.g., `dataSync`) is declared and Play-policy implications are reviewed. This is register GA-08 (BLOCKED — ENFORCEMENT TRUTH GATE); the physical validation plan for the twelve enforcement scenarios is in `docs/UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md`. The honest feature classification is **"M8 Enforcement Foundation"** with `Actual Consumer-App Restriction = NOT PROVEN` (§27 of the mandate).
| Grant notifications | System dialog at runtime (POST_NOTIFICATIONS declared) | Enforcement alerts |
| Battery optimization | Settings → Apps → Guardian Eye → Battery → Unrestricted (optional, for Doze observation) | Doze behavior study |
| Boot receiver | Declared in manifest by M8; first boot after install confirms | Reboot recovery |

Overlay (SYSTEM_ALERT_WINDOW) and Accessibility are NOT required by the M8 design; they are mentioned only if a future mechanism legitimately needs them (§22 of the mandate keeps the door closed to aggressive mechanisms).

## 5. Network Preparation (Windows)

Scoped scoped-scoped rules only (never global firewall/AV disable — non-negotiable §23). See `docs/LOCAL_ENVIRONMENT_NETWORK_CHANGES.md` for the change log, previous state, rollback instructions, and verification.

## 6. Account Preparation (Firebase)

Owner completes interactive authentication (browser takeover pattern). Exact steps are provided in the register under GA-01/GA-26: create nothing in production until a controlled test scope is approved; test identities are created through the app's own invite flow whenever possible so the production database only contains family data the owner knowingly created.

## 7. Secrets Policy

No credentials are stored in the repository, in committed `.env` files, in documentation, in test logs, or in screenshots. The sandbox and the owner's machine both use local credential stores (Firebase CLI token file `~/.config/configstore/firebase-tools.json`, Git HTTPS credential manager). A secrets scan is run before every commit.
