# Guardian Eye Pro — High-Risk System Verification Evidence

## 1. Background Sync (WorkManager)
- **Status:** CODE-VERIFIED
- **Implementation:** `callbackDispatcher` in `main.dart`.
- **Worker:** `SyncCoordinatorCore` → `OutboxSyncExecutor`.
- **Frequency:** 15 minutes.
- **Constraints:** Network connected, Battery not low.
- **Risk:** Background execution on Android 13+ requires `POST_NOTIFICATIONS` and battery optimization whitelisting, which are not currently handled in the native bridge.

## 2. Notification Dispatch (Render + FCM)
- **Status:** CODE-VERIFIED / BACKEND-READY
- **Path:** `SosRepository` → `Outbox` → `OutboxSyncExecutor` → `NotificationGateway` → `Render /api/notify`.
- **Auth:** Firebase ID Token (Bearer) required.
- **Dispatch:** Render backend validates family membership before FCM multicast.
- **Risk:** `NotificationGateway` uses a placeholder Render URL. Deployment is required for live testing.

## 3. Audio Relay (FS-008)
- **Status:** CODE-VERIFIED / BACKEND-READY
- **Frontend:** `AudioMonitorService` (parent) / `AudioCaptureService` (child).
- **Backend:** `/api/audio/upload` and `/api/audio/stream`.
- **Protocol:** HTTP-based chunked upload/download (relay).
- **Risk:** Real-time latency and OOM on large audio sessions. `AudioCaptureService` has a 10-minute timeout but no chunked disk-buffering.

## 4. Trusted Actor Binding (FS-016)
- **Status:** CODE-VERIFIED
- **Mechanism:** `startup_state_service.dart` resolves `authenticatedWithFamily` state.
- **UI:** `RoleGateScreen` enforces selection and persists via `OnboardingPersistenceService`.
- **Risk:** If Firestore membership is revoked, the local `selectedRole` persists until the next `dashboardProvider` refresh, creating a potential brief unauthorized access window.
