# Guardian Eye Pro — Freebuff Testing & Handoff Guide

## 1. Repository Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git
   cd Guardian-Eye
   git fetch --all --tags
   ```
2. Check out the verified branch:
   ```bash
   git checkout feature/design-system-integration
   ```
3. Verify the current full SHA:
   ```bash
   git rev-parse HEAD
   # Should match the publication-correction SHA reported in the manifest.
   ```

## 2. Environment Configuration
1. **Firebase (Mandatory):**
   - Place your real `google-services.json` in `android/app/`.
   - Place your real `GoogleService-Info.plist` in `ios/Runner/`.
   - Re-generate `lib/firebase_options.dart` using `flutterfire configure`.
   - **Warning:** Do not commit these files.
2. **Backend (Render):**
   - `cd guardian_backend`
   - Copy `.env.example` to `.env` and fill in secrets.
   - Place your service account key at `firebase-key.json`.
   - Run `npm install`.

## 3. Verification Sequence
### 3.1 Static Analysis & Regression Tests
```bash
flutter pub get
flutter analyze
flutter test
```
**Acceptance Criteria:** 659/659 tests passing, 0 analyze errors.

### 3.2 Subsystem Integration
For each phase FS-001 through FS-016:
1. Verify the corresponding routes in `lib/presentation/router/app_router.dart`.
2. Check the implementation logic in `lib/data/` and `lib/application/`.
3. Verify localization keys in `lib/core/localization/app_localizations.dart`.

### 3.3 Integration Gates
- **Firebase:** Requires real project setup. Mark as `BLOCKED-FIREBASE` if not configured.
- **Render:** Requires backend deployment. Mark as `BLOCKED-RENDER` if not deployed.
- **Real Device:** Headless tests do not prove Android-specific behavior. Mark as `REAL-DEVICE-NOT-VALIDATED`.

## 4. Handoff Evidence
Record the following for your report:
- Exact branch and full commit SHA.
- Date and time (UTC) of verification.
- Output of `flutter analyze` and `flutter test`.
- Any integration blockers found.
