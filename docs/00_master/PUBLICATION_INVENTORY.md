# Guardian Eye Pro — Publication Inventory

## 1. Published Files (Safe for Private Repository)
- **Flutter/Dart Source:** All files under `lib/` (domain, data, presentation, application, core).
- **Android Source:** `android/` directory (excluding `google-services.json` and signing keys).
- **iOS Source:** `ios/` directory (excluding `GoogleService-Info.plist` and signing certificates).
- **Backend Source:** `guardian_backend/` (excluding `node_modules`, `.env`, and service account keys).
- **Database:** `lib/core/database/guardian_database.dart` (schema v32 and migrations).
- **Firebase Templates:** `firebase/firestore.rules`, `firebase/firestore.indexes.json`.
- **Render Configuration:** `render.yaml` (if present) or environment variable documentation.
- **Tests:** All files under `test/` (unit, widget, integration).
- **Localization:** `lib/core/localization/app_localizations.dart` (AR/EN).
- **Assets:** `assets/` directory (icons, images).
- **Documentation:** All files under `docs/` (master plan, audit reports, specifications).
- **CI/CD:** `.github/workflows/` (if present).
- **Tooling:** `tool/` scripts.
- **Configuration:** `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`.

## 2. Excluded Files & Safety Gate
| Path | Reason | Replacement / Template | User Action |
| --- | --- | --- | --- |
| `android/app/google-services.json` | Firebase Credential | `android/app/google-services.json.example` | Provide real file |
| `ios/Runner/GoogleService-Info.plist` | Firebase Credential | `ios/Runner/GoogleService-Info.plist.example` | Provide real file |
| `guardian_backend/.env` | Backend Secrets | `guardian_backend/.env.example` | Provide real secrets |
| `guardian_backend/firebase-key.json` | Service Account | `guardian_backend/firebase-key.json.example` | Provide real key |
| `guardian_backend/node_modules/` | Dependency Cache | `npm install` | Run install |
| `build/` | Build Artifacts | `flutter build` | Run build |
| `.dart_tool/` | Dart Tooling | `flutter pub get` | Run pub get |
| `*.jks`, `*.keystore` | Signing Keys | N/A | Provide real keys |
| `*.mobileprovision` | iOS Provisioning | N/A | Provide real profile |

## 3. Safe Templates Created
- `android/app/google-services.json.example`
- `guardian_backend/.env.example`
- `guardian_backend/firebase-key.json.example`
- `FREEBUFF_TESTING_GUIDE.md`
