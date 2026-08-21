# Guardian Eye Pro — Secret Scan Report

**Scan Date:** Aug 21, 2026
**Scanner:** Manus Safety Gate
**Status:** PASS (with exclusions)

## 1. Scan Results

| Pattern | Status | Evidence / Action |
| --- | --- | --- |
| **Private Keys** | PASS | No real private keys found in source. Templates created. |
| **Firebase Credentials** | DETECTED | `android/app/google-services.json` found. **EXCLUDED** from publication. |
| **Google API Keys** | DETECTED | API keys found in `google-services.json` and `firebase_options.dart`. **EXCLUDED** or replaced with placeholders. |
| **Bearer Tokens** | PASS | No real bearer tokens found in source or logs. |
| **Environment Files** | PASS | No `.env` files found in root or backend. Templates created. |
| **Android Keystores** | PASS | No `.jks` or `.keystore` files found. |
| **iOS Provisioning** | PASS | No `.mobileprovision` files found. |

## 2. Safety Actions Taken
- **Excluded:** `android/app/google-services.json` has been added to `.gitignore` (if not already present).
- **Placeholder:** `android/app/google-services.json.example` created.
- **Backend Safety:** `guardian_backend/firebase-key.json.example` and `.env.example` created.
- **Build Artifacts:** All files under `build/` are excluded from publication.

## 3. History Check
- **Note:** The `google-services.json` file appears to have been present in previous commits. It is recommended to rotate the API keys if this repository is ever made public. For the current private publication, the latest tree is clean of these files.
