# PHASE 17 — FIREBASE CONFIGURATION CHANGE INVENTORY

**Date:** August 13, 2026 · **Author:** Manus AI · **Scope:** strictly local client configuration; no production resources touched.

## What was created or changed (local files only)

| # | File / Location | Nature of change | When | How |
|---|---|---|---|---|
| 1 | `lib/firebase_options.dart` | **Created (regenerated)** — FlutterFire CLI 1.4.1 generated options targeting existing project `manus-guardian`, Android app `1:165160049292:android:922e6c8a4749c42e4839a9`, package `com.guardianeye.app` | Phase 17 recovery | `flutterfire configure` under the authenticated owner session |
| 2 | `android/app/google-services.json` | **Created (regenerated)** — matching Android client config: project number 165160049292, package `com.guardianeye.app` | Phase 17 recovery | `flutterfire configure` (writes google-services.json automatically) |
| 3 | `android/build.gradle.kts` | **Edited** — removed `afterEvaluate` compileOptions override; added configuration-time Java 17 publishing and KotlinCompile JVM-target mirroring (Gradle remediation; build infra only) | Gradle remediation | Manual minimal edit |
| 4 | `android/settings.gradle.kts` | **Edited** — Kotlin plugin 2.3.20 → 2.1.21 (AGP 9.0.1 compatibility) | Gradle remediation | Manual minimal edit |
| 5 | `android/app/build.gradle.kts` | **Edited** — AGP 9 new-DSL `ApplicationExtension`, explicit Kotlin plugin application, `jvmTarget.set()` syntax | Gradle remediation | Manual minimal edit |
| 6 | `android/gradle.properties` | **Edited** — JVM args tuned to 1024m (sandbox memory), plus pre-existing flags | Gradle remediation | Manual minimal edit |

## What was explicitly NOT changed

No Firebase **production** resource was created, modified, or deployed: no Firestore rules deployed, no indexes created, no Functions deployed, no Remote Config changed, no Authentication settings changed, no Storage rules deployed, no Blaze plan activation, no new project, no new app registration, no deleted resources. The project `manus-guardian` and its existing Android application are untouched; the regenerated client files point at the pre-existing identities.

## Credential hygiene

The two generated client files contain only public client identifiers (project ID, app ID, API key for client use, OAuth client ID) — no private keys, service-account JSON, refresh tokens, or Admin SDK material. Both files are listed in `.gitignore` and are excluded from the repository checkpoint. A full secret scan of the repository confirmed no Admin credentials, private signing keys, `.env` secrets, or unrelated tokens anywhere in the tree.

## Verification

SHA-256 baselines were recorded for both client config files and re-verified after the APK build: identity fields matched exactly (project `manus-guardian`, project number `165160049292`, App ID `1:165160049292:android:922e6c8a4749c42e4839a9`, package `com.guardianeye.app`). The post-build APK manifest carries applicationId `com.guardianeye.app`.
