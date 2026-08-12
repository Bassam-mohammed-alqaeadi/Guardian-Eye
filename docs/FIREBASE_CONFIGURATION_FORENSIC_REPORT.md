# Firebase Configuration Forensic Report

**Date:** 12 August 2026  
**Scope:** Read-only inspection of `/home/ubuntu/guardian_eye_flutter` and the Phase 13 downloadable archive. No Firebase configuration file, project identity, rule, dependency, or application architecture was changed during the inspection.

> **Conclusion:** The two questioned Firebase configuration files were neither deleted nor absent from the current working project. They are present locally and were intentionally excluded from the downloadable Phase 13 ZIP as a safety measure. No replacement configuration should be generated.

## 1. File existence and exact paths

| Artifact | Current canonical workspace | Exact path | Phase 13 archive | Classification |
|---|---|---|---|---|
| Android Google Services config | Present | `android/app/google-services.json` | Absent | Present locally; intentionally excluded from export. |
| FlutterFire platform options | Present | `lib/firebase_options.dart` | Absent | Present locally; intentionally excluded from export. |
| Firebase CLI project mapping | Present | `.firebaserc` | Present | Included in export. |
| Firebase deploy manifest | Present | `firebase.json` | Present | Included in export. |
| Local Firebase CLI cache directory | Absent | `.firebase/` | Not applicable | No local CLI cache was found. |

The recursive workspace scan also found a separately supplied upload named `google-services.json` and package-library source files with similar names. They are not used as evidence for the canonical project configuration.

## 2. Git and export status

| Question | Finding | Evidence level |
|---|---|---|
| Is the current workspace a Git worktree? | No `.git` metadata exists in the canonical workspace, so a live tracked/ignored Git status cannot be determined there. | **VERIFIED LOCALLY** |
| Are the Firebase artifacts intended to be ignored by Git? | Yes. `.gitignore` explicitly lists `android/app/google-services.json` and `lib/firebase_options.dart`. | **VERIFIED LOCALLY** |
| Is there an independent export manifest in this workspace? | No `export.json` or `.project-config.json` was found. | **VERIFIED LOCALLY** |
| Were the two artifacts excluded from the downloaded Phase 13 project? | Yes. The archive contains `.firebaserc` and `firebase.json`, but does not contain either local Firebase artifact. | **VERIFIED LOCALLY** |

This establishes **B: present in the working filesystem but excluded from the downloadable/export artifact**. The `.gitignore` entries additionally establish the intended local-only Git policy, but the missing `.git` directory prevents a forensic claim about a particular Git commit or index state.

## 3. Firebase project and Android identity

| Verification | Result | Evidence |
|---|---|---|
| Firebase CLI mapping references `manus-guardian` | Confirmed. | Boolean inspection of `.firebaserc`; no contents printed. |
| FlutterFire options reference `manus-guardian` | Confirmed. | Boolean inspection of `lib/firebase_options.dart`; no contents printed. |
| Android Google Services config references `manus-guardian` | Confirmed. | Boolean inspection of `android/app/google-services.json`; no contents printed. |
| Android application ID is `com.guardianeye.app` | Confirmed in `android/app/build.gradle.kts`. | Static source inspection. |
| Android Manifest directly declares that package string | Not applicable in this project layout; the Gradle application ID is the authoritative Android application identity inspected here. | Static source inspection. |

No credential, API key, OAuth client value, application identifier beyond the required public package name, or Firebase configuration content was printed during this audit.

## 4. Actual build and FlutterFire configuration

The Android Gradle source references the Google Services plugin. Therefore an Android build configured for Firebase expects `android/app/google-services.json` to exist locally. Flutter bootstrap imports the generated options and initializes Firebase using `DefaultFirebaseOptions.currentPlatform`. This confirms that FlutterFire is wired through the generated options rather than a handwritten or fallback configuration mechanism.

| Component | Status | Evidence level |
|---|---|---|
| Google Services plugin reference | Present. | **VERIFIED LOCALLY** |
| Android local config path | Present and matched to the approved project identity. | **VERIFIED LOCALLY** |
| FlutterFire options import | Present. | **VERIFIED LOCALLY** |
| `DefaultFirebaseOptions.currentPlatform` initialization | Present in `guardian_firebase_bootstrap.dart`. | **VERIFIED LOCALLY** |
| Firebase Admin credentials in Flutter | Not introduced or inspected as present. | **NO CHANGE MADE** |

## 5. Environment strategy verification

The Phase 12 environment strategy remains intact and was not changed.

| Requested environment | Actual source behavior | Backend target | Safety condition |
|---|---|---|---|
| `DEVELOPMENT` | Enabled only when an explicit Emulator host is supplied. | Firebase Emulator. | Empty host disables Firebase. |
| `TEST` | Enabled only when an explicit Emulator host is supplied. | Firebase Emulator. | Empty host disables Firebase. |
| `REAL_BACKEND_VALIDATION` | Enabled only with an explicit real-backend approval define. | `manus-guardian`. | Missing approval disables Firebase. |
| `PRODUCTION` | Enabled only with an explicit production approval define. | `manus-guardian`. | Missing approval disables Firebase. |

When development or test uses the Emulator, bootstrap calls the Firebase Auth and Firestore Emulator endpoints after initializing the FlutterFire app. With no explicit environment defines, Firebase remains disabled; the application does not silently write to the real backend.

## 6. Why the Firebase Console can contain little or no data

Normal Guardian Eye Pro development uses the Firebase Emulator in `DEVELOPMENT` and `TEST`. Emulator Auth, Firestore, and Functions data are local to the Emulator session and therefore do not appear in the Firebase Console.

The documented real-backend validation used disposable authentication sessions, a family-plus-primary-parent bootstrap/read-back record, and denied authorization-boundary attempts. These are validation artifacts, not normal family usage. Cloud Functions are not deployed because the project requires owner-approved Blaze billing for that deployment path. The current application also remains disabled without explicit environment and approval defines.

> Accordingly, a sparse Firebase Console is expected and is not evidence that the local Firebase client configuration was absent or that normal application use has been writing to the real backend.

## 7. Root cause and required action

| Question | Determination |
|---|---|
| Were the files deleted? | No. Both are currently present in the canonical working filesystem. |
| Were the files never generated? | No. Both generated/configured artifacts are present and identity checks match the approved project. |
| Why did the download not contain them? | The Phase 13 archive intentionally excluded both local-only paths while retaining safe Firebase metadata such as `.firebaserc` and `firebase.json`. |
| Is Firebase configuration regeneration required? | No. Do not generate, invent, replace, or modify any Firebase configuration file. |
| Is human action required now? | Not for the current canonical workspace. A recipient of the ZIP needs the existing approved local artifacts placed in the documented paths before Firebase client initialization can run. |

The safe restoration instructions are maintained in [`FIREBASE_LOCAL_FILES_REQUIRED.md`](FIREBASE_LOCAL_FILES_REQUIRED.md). They deliberately do not include secret content or instructions to create a new Firebase project.

## 8. Constraints preserved

This inspection did **not** create another Firebase project, change `com.guardianeye.app`, generate or modify either configuration artifact, weaken Firestore rules, add Firebase Admin credentials to Flutter, alter the Flutter/Riverpod/SQLite/Outbox/Firebase architecture, or switch frameworks.
