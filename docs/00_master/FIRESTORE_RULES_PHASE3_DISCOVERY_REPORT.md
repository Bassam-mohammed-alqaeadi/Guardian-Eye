# Phase 3 (Phase A) Discovery Report — Notification Infrastructure

**Project:** Guardian Eye Pro — Flutter Android family-safety platform
**Branch:** `feature/design-system-integration`
**Phase:** 3, Phase A — Read-only discovery (implementation deferred pending approval)
**Date:** 21 August 2026
**Author:** Manus AI
**Constraints honored:** read-only inspection only; no code changes; no feature start; no deployment; no real family data, child data, or production tokens used or printed; no secrets exposed.

---

## 1. Current Notification Architecture

The platform already contains a substantial, well-designed notification skeleton split across three layers: a local token lifecycle in the app, a client-side honest gateway, and a server-side sender inside Firebase Functions.

### 1.1 App layer (`lib/`)

| Component | File | Current state |
|---|---|---|
| Token model & persistence | `lib/data/fcm_token_repository.dart` | **Implemented.** `DeviceTokenRegistration` (id, familyId, deviceId, userUid, token, platform); SQLite table `notification_tokens` (incl. `revoked_at`) with unique index on `(device_id, token)`; outbox enqueue with `notification.token.registered` operation and idempotency key |
| Token service | `lib/data/fcm_token_repository.dart` (`FcmTokenService`) | **Partial.** `register()` requests permission (alert/badge/sound) and persists the token on success; exposes `tokenRefreshes` stream, but **no refresh/revoke handler is wired** |
| Dispatch gateway | `lib/data/notification_contract.dart` | **Implemented but unconnected.** `GuardedFcmNotificationGateway` returns honest `accepted:false` with reason `server_side_notification_producer_required`; exists as a type but **no provider wires it anywhere** |
| Foreground/background/terminated handlers | `lib/main.dart`, app-wide | **Absent.** No `onMessage`, `onBackgroundMessage`, `onMessageOpenedApp`, or `getInitialMessage` — incoming FCM data messages are silently ignored |
| Android channels / local notifications | `android/`, `lib/` | **Absent.** `AndroidManifest.xml` declares `POST_NOTIFICATIONS` only; no default channel metadata, no channel creation, no icon; `flutter_local_notifications` plugin is registered by the generated plugin list but **never initialized or used** |
| Deep links / routing | `lib/presentation/router/app_router.dart` | **Absent.** No notification route; nothing resolves `notificationEventId` into a destination screen |
| Preferences / opt-out | `lib/` | **Absent.** No notification settings screen, no opt-in/opt-out model |
| Event model (local) | `lib/core/database/guardian_database.dart` | **Present.** `notification_events` table (`id, family_id, incident_id, sos_id, kind, status, requested_at, acknowledged_at, last_error`, plus `recipient_id` migration) — but **no app code writes or reads it** |
| Remote token sync contract | `lib/data/firestore_contracts.dart` L308–325 | **Contract exists, registry not wired.** `'notification.token.registered'` maps to `families/{familyId}/devices/{deviceId}/notification_tokens/{idempotencyKey}` with payload validation — however, the outbox event registry does not expose `notification.token.*` operations, so the sync is contract-defined but **never dispatched** |
| Provider | `lib/application/guardian_providers.dart` L239 | `DeviceTokenRepository` provided; `FcmTokenService` is **not** provided or started at app launch |

### 1.2 Server layer (`firebase/functions/src/index.ts`, 197 lines)

The Functions codebase contains the **only legitimate sender** in the entire repository, and it is a complete, production-quality implementation:

| Element | Detail |
|---|---|
| Trigger | `requestIncidentNotification` / `requestSosNotification` on `onDocumentCreated` for `families/{familyId}/incidents/{incidentId}` and `sos/{sosId}` |
| Request object | `createNotificationRequest` writes `families/{familyId}/notification_events/${kind}_${sourceId}` with `{familyId, eventId, kind, sourceId, status: pendingBackend}` — idempotent (`already-exists` caught) |
| Fanout | `fanoutNotification` on notification_event creation: transactional claim (`pendingBackend`→`processing`) for **exactly-once processing**; token selection via `collectionGroup('notification_tokens')` filtered by `familyId` + `status == active` |
| Payload | **Data-message only** (`kind, familyId, sourceId, notificationEventId`) — no title/body, no sensitive content; requires the app to render a local notification from the event id |
| Invalid-token cleanup | Per-token failures with `messaging/registration-token-not-registered` or `messaging/invalid-registration-token` set the token doc to `status: revoked` |
| Terminal states | `backendAccepted`, `backendFailed`, `noActiveToken`, `fcmNotExercisedInEmulator`; failure counts recorded |
| Render backend | **Zero notification references** — correct; the sender must not live on Render |

### 1.3 Rules layer

`notification_events` (L215): family members may read; **create/update/delete is `false`** — clients can never write events; only the Functions admin SDK can. `device_pairings` is permanently blocked. This matches the trusted-backend-only pattern exactly.

## 2. Actual Gaps

Stored FCM tokens are **not** proof of delivery; the honest inventory is:

1. **No sender in production.** Firebase Functions is documented as never deployed: the project is not on the Blaze plan, so Cloud Build/Artifact Registry building is blocked and `functions:list` contains no Guardian function (`docs/03_security/REAL_FIREBASE_VALIDATION.md`, `docs/04_backend/FIREBASE_REAL_ENVIRONMENT_SETUP.md`, `docs/07_environment/HUMAN_ACTION_REQUIRED.md`). The incident/sos trigger therefore **never fires against live production Firestore** today.
2. **App cannot display or act on pushes.** No message handlers, no channel, no local notification rendering — even if a sender existed, the user would see nothing.
3. **Token refresh/revocation app-side missing.** The server revokes tokens on send failure, but the app never re-registers after rotation and never revokes on logout.
4. **Outbox registry not wired** — token remote sync is contract-defined but unregistered, so tokens never reach Firestore (and `notification_tokens` subcollection writes are correctly blocked client-side by rules anyway).
5. **No preferences, opt-out, or deep-link routing.**
6. **No client-visible notification state UX** — the gateway is unconnected and untested beyond one token-repo test (`test/fcm_token_repository_test.dart`, 1 test).
7. Test coverage for gateway idempotency, lifecycle, opt-out, and failure paths does not exist.

## 3. Where a Legitimate Sender Can Live

The only acceptable location is `firebase/functions` (trusted backend with `firebase-admin/messaging`), where a complete implementation already exists. Render must **not** be given a notification endpoint, and no in-app or fake sender may be invented. Because the Functions sender cannot be deployed from this environment (no Blaze plan, no authenticated Firebase session — Phase 2 established the session is unavailable), the server portion is:

> **BLOCKED-EXTERNAL** — the sender exists as code but cannot be activated or validated against production from this sandbox.

## 4. Short Plan (stopped before implementation, pending your approval)

**Phase B (safe local implementation, app-only):**
1. Wire `FcmTokenService` into a startup provider: register, refresh handler (re-upsert), logout revoke (clear token docs locally + remote via the existing contract).
2. Create the typed notification event contract (`familyId, eventId, recipient, eventType, idempotencyKey`) backed by the existing `notification_events` table, with honest local states: `pending, queued, delivered, failed, denied, unavailable`.
3. Implement Android channel creation (one default channel) and `flutter_local_notifications` initialization; add foreground/background/terminated handlers plus `getInitialMessage` handling with a safe deep-link route (incident/SOS summary → respective timeline screen).
4. Privacy: payloads carry only `kind + eventId`; all detail retrieval happens in-app after authentication — already guaranteed by the server's data-only payload.
5. Preferences model + permission-denied honest UX (no false promises).
6. Tests: event creation, recipient scoping, idempotency, token lifecycle, opt-out, failure handling, route validation.

**Phase C (external sender decision, formalized):** activation requires (a) Blaze billing on `manus-guardian`, (b) an authenticated Firebase session (`firebase login` or CI token — the Phase 2 block), (c) `firebase deploy --only functions:guardian --project manus-guardian`, then (d) an Android device test matrix: foreground/background/terminated arrival, permission denied, token rotation, offline queue, deep-link navigation.

**Phase D/E:** verification and a single local checkpoint commit only if all local checks pass; no push, no deploy.

---

*All findings are from read-only inspection of `lib/`, `android/`, `firebase/functions/`, `firebase/firestore.rules`, and `docs/`. No file was modified.*
