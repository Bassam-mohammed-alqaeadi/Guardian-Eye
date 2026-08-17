# Firebase Local Files Required

## Purpose

Guardian Eye Pro uses two client configuration artifacts that are intentionally **local-only**. They connect the approved Flutter application identity to the existing Firebase project, but they are not source-controlled or included in safety-oriented downloadable archives.

> These artifacts are client configuration files, not Firebase Admin credentials. They must never be replaced by invented values, copied from a different project, or committed to source control.

| Required artifact | Required local path | Current forensic result | Why it is local-only |
|---|---|---|---|
| `google-services.json` | `android/app/google-services.json` | Present in the canonical working workspace. | It is Firebase project/app configuration and is explicitly ignored by `.gitignore`. |
| `firebase_options.dart` | `lib/firebase_options.dart` | Present in the canonical working workspace. | It is the FlutterFire-generated platform options file and is explicitly ignored by `.gitignore`. |

## Reconstructing a downloaded project safely

The Phase 13 ZIP intentionally excludes both files. A person receiving that ZIP must place **only the already-approved, matching local artifacts** into these exact paths:

```text
google-services.json  → android/app/google-services.json
firebase_options.dart → lib/firebase_options.dart
```

The files must originate from the same approved Firebase project and Android identity already used by Guardian Eye Pro. Do not use an artifact from another project, do not edit either file manually, and do not add them to Git.

## If the secure local copies are unavailable

The current canonical workspace already contains both files, so no regeneration or recovery is needed there. For a new developer workstation or a clean exported copy, the authorized project owner must obtain the correct artifacts through the existing Firebase project workflow and verify the project/app identity before placing them locally. Do not create another Firebase project and do not change `com.guardianeye.app`.

## Reproducibility boundary

The downloaded archive remains reproducible for source, architecture, Firestore rules, indexes, and Emulator-first development. A local Firebase client configuration step is intentionally required before Android/iOS Firebase initialization or real-backend validation can run. Normal development remains Emulator-first and does not require production data in the Firebase Console.
