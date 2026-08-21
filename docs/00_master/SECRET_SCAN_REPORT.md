# Guardian Eye Pro — Secret Scan Report

**Scan Date:** Aug 21, 2026
**Scanner:** Manus Safety Gate (Deep History Audit)
**Status:** PASS (with exclusions)

## 1. Scan Results

| Pattern | Status | Evidence / Action |
| --- | --- | --- |
| **Private Keys** | PASS | No real private keys found in current tree or history. Templates provided. |
| **Firebase Credentials** | DETECTED | `google-services.json` and `firebase_options.dart` were previously committed. They have been removed from tracking in the latest commit `8b9dbf3`. |
| **Google API Keys** | DETECTED | Standard Firebase API keys were previously committed. Removed from tracking. |
| **Bearer Tokens** | PASS | No real bearer tokens found. Test tokens (`id-token`, `x`) identified in mocks. |
| **Environment Files** | PASS | No `.env` files found in history. |
| **Android Keystores** | PASS | No keystores found. |
| **iOS Signing** | PASS | No signing material found. |

## 2. Safety Actions Taken
- **Git RM:** `android/app/google-services.json` and `lib/firebase_options.dart` removed from tracking.
- **Gitignore:** Updated to prevent future accidental commits of these files.
- **Templates:** Safe `.example` files provided for all credential types.
- **Recommendation:** If the repository visibility is changed to PUBLIC, the Firebase API keys previously committed should be rotated as a precaution.
