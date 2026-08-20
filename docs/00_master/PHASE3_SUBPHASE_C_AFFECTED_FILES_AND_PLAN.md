# Sub-Phase C — Affected Files & Implementation Plan (Notification App-Side Foundation)

**Branch:** `feature/design-system-integration` | **Date:** 21 August 2026 | **Author:** Manus AI
**Principle:** every change reuses an already-approved primitive; nothing is invented. Guardian AI frozen; no FS-010/012/014/016.

## 1. What already exists and will be preserved

| Primitive | Location | Fate |
|---|---|---|
| `DeviceTokenRegistration` + `DeviceTokenRepository` (SQLite persist + outbox enqueue) | `lib/data/fcm_token_repository.dart` | **Preserved unchanged** |
| `FcmTokenService` (permission request + register) | `lib/data/fcm_token_repository.dart` | Extended only: refresh handler, logout revoke |
| Honest gateway stub `GuardedFcmNotificationGateway` | `lib/data/notification_contract.dart` | **Replaced** by `RenderNotificationGateway` (the Render `/api/notify` endpoint is the confirmed sender host) |
| `notification_events` + `notification_tokens` tables (DB v28) | `lib/core/database/guardian_database.dart` | **Preserved** — new code only reads/writes `notification_events` status fields (already schema-complete: `status`, `requested_at`, `acknowledged_at`, `last_error`, `recipient_id`) |
| Outbox architecture (`OutboxSyncExecutor`, `firestore_contracts.dart`) | `lib/data/outbox_sync_executor.dart`, `lib/data/firestore_contracts.dart` | **Preserved** — the new notification request path is NOT an outbox/Firestore write: it is a direct authenticated HTTP call to Render (Architecture Option A). `notification.requested` rows already exist in `notification_events`; they gain honest status transitions |
| Render HTTP client pattern | `lib/application/remote_provisioning_service.dart` | Reused (ID-token injection, Dio, timeouts, remote exceptions) |
| GoRouter with `timeline` (`/timeline/:familyId`) and SOS routes | `lib/presentation/router/app_router.dart` | **Preserved** — two new notification deep-link routes added |
| Startup trigger pattern | `lib/presentation/guardian_app.dart` | Reused (post-frame trigger + auth-state listener) |

## 2. Exact affected files (new + modified)

| File | Action | Purpose |
|---|---|---|
| `lib/data/notification_contract.dart` | **Modify** | Replace the stub with a working `RenderNotificationGateway` posting `POST /api/notify` (kind, familyId, incidentId/sosId) with Bearer Firebase ID token; honest results; maps `notification_events` statuses |
| `lib/data/fcm_token_repository.dart` | **Modify** | Add `revoke()` (local row revoke + remote contract envelope), refresh listener registration, permission-state introspection (`AuthorizationStatus` mapping) |
| `lib/application/remote_notification_service.dart` | **NEW** | App-side notification core: channel init (plugin-only, approved & present in pubspec), `FlutterLocalNotificationsPlugin` init, foreground/background/terminated handlers, local notification rendering from data-only payload (kind + eventId only), safe deep-link routing to `timeline`/SOS destinations with family + event authorization check before navigation, opt-in/opt-out preferences backed by existing DB, honest states `pending/queued/delivered/failed/denied/unavailable` |
| `lib/application/notification_providers.dart` | **NEW** | Riverpod providers: plugin provider, permission provider, service provider, preferences provider, startup wiring |
| `lib/presentation/router/app_router.dart` | **Modify** | Add routes `notification/open` and `notification/incident`/`notification/sos` parameterized by `notificationEventId` |
| `lib/presentation/guardian_app.dart` | **Modify** | Startup wiring: FCM registration on auth state, notification service init (best-effort, honest on failure) |
| `lib/core/localization/app_localizations.dart` | **Modify** | Add AR + EN keys (RTL-safe) for permission states, opt-out screen, delivery states |
| `test/notification_lifecycle_test.dart` | **NEW** | Focused tests: token lifecycle, refresh, revoke, permission states, handler payload validation, idempotency of rendering, route validation |
| `test/render_notification_gateway_test.dart` | **NEW** | Gateway: auth header, payload shape (data-only), honest rejection mapping, timeout behavior |

## 3. Implementation rules (binding)

1. Payload is data-only: `kind`, `familyId`, `sourceId/eventId`, `notificationEventId`. No title/body, no sensitive content. Localization happens in-app from the event kind.
2. Deep-link navigation only after: (a) authenticated session exists, (b) familyId matches the active family, (c) the referenced `notification_events` row exists with matching `family_id` and `kind`. Any failure resolves to the dashboard with an honest toast-free path (the route simply falls back; no false success).
3. Permission denied → honest "Notifications unavailable — enable in device settings" state; never auto-re-request spam.
4. One channel: `guardian_safety` (safety alerts). Plugin `flutter_local_notifications: ^20.0.0` is already in pubspec — approved and present.
5. Logout revocation: on sign-out, local token rows are revoked (never remotely leaked during logout flow); the existing `notification.token.registered` outbox row syncs the token to Firestore when online, where rules already restrict it to the device's family.
6. No new permissions beyond the already-declared `POST_NOTIFICATIONS`.
7. Tests: only fake/plugin-mocked layers; no real FCM.

## 4. Execution order

1. `remote_notification_service.dart` + `notification_providers.dart` (core + wiring)
2. `notification_contract.dart` gateway replacement
3. `fcm_token_repository.dart` refresh/revoke extensions
4. Router deep-link routes
5. `guardian_app.dart` startup wiring
6. Localization keys (AR first, then EN)
7. Focused tests
8. Format + analyze + full regression (432/432 baseline must remain green)
9. Single local checkpoint commit **only if all checks pass** — no push
