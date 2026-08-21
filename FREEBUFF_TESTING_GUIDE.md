# Guardian Eye Pro — Freebuff Testing & Handoff Guide

## 1. Repository Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git
   cd Guardian-Eye
   git checkout feature/design-system-integration
   ```
2. Verify the baseline:
   ```bash
   git rev-parse HEAD
   # Should match 8b9dbf3 (or latest publication commit)
   ```

## 2. Environment Configuration
1. **Firebase:**
   - Place your real `google-services.json` in `android/app/`.
   - Place your real `GoogleService-Info.plist` in `ios/Runner/`.
   - Re-generate `lib/firebase_options.dart` using `flutterfire configure`.
2. **Backend:**
   - `cd guardian_backend`
   - Copy `.env.example` to `.env` and fill in secrets.
   - Place your service account key at `firebase-key.json`.
   - Run `npm install`.

## 3. Verification Sequence
### 3.1 Static Analysis & Unit Tests
```bash
flutter pub get
flutter analyze
flutter test
```
Ensure all 659 tests pass.

### 3.2 Backend Verification
```bash
cd guardian_backend
npm test
# Verify health and auth endpoints
```

### 3.3 Integration & Route Testing
- Launch the app in an emulator or real device.
- Follow the **Startup Flow** (FS-016): Splash → Role Gate → Dashboard.
- Verify **SOS Dispatch** (FS-006) enqueues to outbox and triggers Render notification.
- Verify **One-Way Audio** (FS-008) transport via Render relay.
- Verify **Family Rules** (FS-011) enforcement and local SQLite state.

## 4. Failure Reporting
If a test fails or a route crashes:
1. Capture the logs (`flutter logs`).
2. Identify the affected `FS-XXX` phase.
3. Check `docs/00_master/` for the corresponding specification and audit report.
4. Report the failure without hiding the underlying issue.
