# Phase 3 — Notification Infrastructure: Deployment Handoff

**Author:** Manus AI
**Branch:** `feature/design-system-integration` (never merged to `master`)
**Date:** August 21, 2026
**Scope:** This document hands off the completed, locally verified Phase 3 notification infrastructure to the human operator. It describes the exact endpoint contract, the deployment action required on Render, the secrets involved, and the verification matrix. **Nothing in this document describes a deployed, production-verified system — the production deployment step is a required human action described in Section 4.**

---

## 1. What Was Built and Where It Lives

Phase 3 delivers a complete notification infrastructure for Guardian Eye Pro on two sides. The Flutter app side (Sub-Phase C) registers the device for push notifications, maintains FCM tokens in SQLite (`app_settings` table `notification_tokens` per family device), verifies the Firebase backend gateway on startup, renders local notifications honestly, and opens deep-link payloads on a dedicated screen that validates event ownership. The server side (Sub-Phase D) hardens the Render backend `POST /api/notify` endpoint so that it satisfies the full security contract: verified Firebase ID tokens, family membership enforcement, same-family event authorization, idempotent exactly-once dispatch, and data-only payloads.

| Side | Commit | Files | Verification |
|------|--------|-------|--------------|
| Sub-Phase C — app foundation | `6667c9f` | 13 files, +1,915 lines | 455/455 Flutter tests green, 0 analyze errors/warnings in changed files |
| Sub-Phase D — server hardening | `34a3cbb` | `guardian_backend/index.js` (+142/−34), `guardian_backend/test/backend.test.mjs` (+201/−34) | 34/34 backend tests green (including 7 new security-contract tests) |
| Firestore rules (Phase 0 remediation) | `8e57cd2` | `firebase/firestore.rules`, emulator suites | 27/27 emulator tests, 20/20 verification suite |

Both commits are **local only** on `feature/design-system-integration` and have **not been pushed** to the remote and have **not been deployed** to any environment.

---

## 2. Server Contract: `POST /api/notify` (Hardened)

The hardened endpoint lives at the Render backend and is invoked by the app whenever a notifyable event (incident or SOS) is created or escalated. The request must carry a **Bearer Firebase ID token**; the caller identity is derived from token verification only and never from the request body.

### Request

| Field | Required | Meaning |
|-------|----------|---------|
| `Authorization: Bearer <Firebase ID token>` | Yes | Caller identity, verified server-side |
| `familyId` | Yes | Family to notify within |
| `kind` | Yes | `incident` or `sos` only |
| `incidentId` | For `kind: incident` | The incident document id inside this family |
| `sosId` | For `kind: sos` | The SOS document id inside this family |

Titles, bodies, and icons are deliberately **not** sent — they are rendered locally by the app from its own records (honest-state UX: the client never displays text that the server invented).

### Response (all 2xx, honest states)

| Field | Meaning |
|-------|---------|
| `sent` | Number of devices that FCM accepted |
| `failed` | Number of devices that FCM rejected |
| `invalidTokensRemoved` | Stale FCM tokens marked `invalid` in the token table |
| `reason` | `accepted` or `no_tokens` (family has no registered parent devices) |
| `eventExisted` | `true` when the request replayed an existing dispatch claim |
| `deliveredAt` | Timestamp of the recorded delivery (null on fresh claim, present on replay) |

### Security behaviors verified by tests

The endpoint enforces a **kind allowlist** (`incident`, `sos`) and returns `400 unknown_kind` for anything else. It returns `400 missing_event_id` when the kind-specific event id is absent. It requires the **family document itself to exist** and the event document to exist **under that same family** in a notifyable state (`detected`, `active`, `open`, `pending`, `acknowledged`, `investigating`); otherwise it returns `404 invalid_event` — a client-supplied event id that does not exist in the same family is **never trusted** into a message, and a bogus family id whose stray subcollection documents happen to match is rejected at the family-existence gate. Membership is enforced as `403 not_a_member` for the new-dispatch path, but **idempotency is resolved first**: a transactional claim on `notification_events/{kind}:{eventId}:{callerUid}` either finds an existing claim (replay → recorded stats returned, no re-fanout) or atomically creates the dispatch slot under re-validated membership. This means a replay cannot be turned into a rejection by a membership change that happened after the original claim, and a duplicate network request cannot produce a double notification fanout. All dispatched FCM messages are **data-only** (`kind`, `familyId`, `notificationEventId`, `incidentId` or `sosId`); high priority applies only to SOS. Stale-token cleanup (marking `invalid`) is preserved. An evidence record moves through `claimed → dispatched` with `sentCount`, `failedCount`, `invalidTokensRemoved`, and `deliveredAt` — full auditability of every dispatch.

### Firestore interaction

The endpoint writes only to `notification_events` documents (server-authenticated via the Render service account), which is consistent with the remediated rules that permanently block **client** writes to `notification_events` (`create/update/delete: if false`). No Firestore rules change is required for this phase; the local remediated ruleset remains in force.

---

## 3. App-Side Foundation (Sub-Phase C)

The Flutter app now carries the complete client half of the infrastructure, all behind test-mode hooks so the local Flutter suite can exercise it without Firebase init. Key surfaces:

1. **`RemoteNotificationGateway`** (`lib/data/notification_contract.dart`) — Dio client to Render with honest result mapping: non-2xx statuses, timeouts, missing backend, and an exhaustive kind check; test-mode bypasses both the Firebase-configuration gate and the identity check, exactly mirroring the provisioning gateway's test-mode contract.
2. **`RemoteNotificationService`** (`lib/application/remote_notification_service.dart`) — FCM channel setup, plugin initialization, foreground/background/terminated handlers, local notification rendering, deep-link routing, per-user preferences, and `NotificationPermissionState` honesty (the app never pretends push is possible when the user declined or the device is unsupported).
3. **Providers** (`lib/application/notification_providers.dart`) — device identity stability (`AppDeviceIdentityService` from the `app_identity` table), token revocation service, and lazy service singletons.
4. **Token lifecycle** (`lib/data/fcm_token_repository.dart`) — refresh handler with injectable stream, revocation written to the local outbox for later sync, and the existing provisioning token registration now reuses the same table.
5. **Database v29** — `notification_settings` and `app_identity` tables added idempotently to both the fresh-schema and upgrade paths; the stable device identity removes the previous Flutter-run-dependent device id instability.
6. **Deep-link flow** — GoRouter `/notification-open` route and `NotificationOpenScreen`, which validates that the referenced notification event exists and belongs to the viewer's family before showing anything (no fake success, honest empty/error states).
7. **Localization** — 212+ new AR/EN keys for the notification experience (permission onboarding, failure, delivery, deep-link states).

---

## 4. Required Human Action: Render Redeployment

**The live Render service is currently serving a stale snapshot.** The live deployment does not expose `/api/notify` (probing returns 404), and the hardened endpoint exists only in the repository source. The code work is complete and verified; the remaining step is purely operational:

1. Push `feature/design-system-integration` to the remote when you approve (currently unpushed by instruction).
2. Retrigger the Render build/deploy for the `guardian_backend` service (`guardian-eye-djg8.onrender.com`), pointing it at the pushed branch (or merge to whatever branch Render tracks) so the hardened `index.js` is built and served.
3. Confirm the deployment finished and re-probe the endpoint (Section 5, matrix row S2).

**Secrets (no action needed, for completeness):** Render already mounts the Firebase Admin service account key at `/etc/secrets/serviceAccountKey.json`, which the bootstrap reads in preference to any local key. The key exists only on Render and in your private Firebase console; it is not in the repository, not in Flutter, and not in any report. No new secrets are required for this phase.

**Do not expect end-to-end push to work until:** (a) the Render redeploy lands, and (b) a real Android device with Google Play Services receives an actual FCM push. Neither has been performed in this session.

---

## 5. Verification Matrix

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| C1 | Flutter regression full suite | **CODE-VERIFIED** | 455/455 tests green (includes 23 new Phase 3 tests) |
| C2 | Flutter analyze on changed files | **CODE-VERIFIED** | 0 errors, 0 warnings |
| C3 | Backend security-contract suite | **CODE-VERIFIED** | 34/34 node tests green (7 new hardening tests) |
| C4 | Data-only payload contract | **CODE-VERIFIED** | Test asserts `notification` block absent; data carries `kind/familyId/notificationEventId` only |
| C5 | Idempotency / replay protection | **CODE-VERIFIED** | Duplicate request returns `eventExisted:true`, single fanout recorded |
| C6 | Cross-family event rejection | **CODE-VERIFIED** | Bogus/cross-family event ids return non-200 before any message construction |
| C7 | Membership-change mid-request protection | **CODE-VERIFIED** | Revocation after claim → replay resolves to claim stats, never re-dispatches |
| S1 | Render endpoint liveness | **BLOCKED-EXTERNAL** | Live `/api/notify` currently returns 404 (stale snapshot); requires human redeploy |
| S2 | Real FCM push on Android device | **BLOCKED-EXTERNAL** | Requires physical Android device + Firebase cloud delivery; not performed in session |
| S3 | Firestore deployed-rules parity | **BLOCKED-EXTERNAL-UNVERIFIED** | Phase 2 parity report; live comparison requires `firebase login` or scoped CI token |
| D1 | Device-level notification UX (permission states, rendering, deep-link) | **BLOCKED-EXTERNAL** | Requires real Android device; headless Flutter tests cover logic only |

---

## 6. Honesty Statements

In accordance with the project's honesty contract: no notification was sent to any real device during this phase; no fake sender, fake delivery receipt, or fake production status was created; the only notification events exercised were in-memory/local ones under test modes. Guardian AI remains a deterministic rule-based system and is untouched. Subscription & Entitlements remains local-only. The Render backend is the intended notification host and Firebase Cloud Messaging (via the Render service account) is the only transport — no Firebase Functions deployment is required or assumed.

**Per-phase statuses:**

| Phase | Status |
|-------|--------|
| Sub-Phase A — architecture correction | ARCHITECTURE-REVIEWED (approved by you) |
| Sub-Phase C — app-side foundation | **CODE-VERIFIED** (455/455 Flutter tests, 0 analyze errors) |
| Sub-Phase D — server contract hardening | **CODE-VERIFIED** (34/34 backend tests, local repository only) |
| Production enablement | **BLOCKED-EXTERNAL** — Render redeploy + Android real-device push are required human actions |

The next milestone after redeployment is a live smoke test against the real endpoint (matrix rows S1/S2) followed by the FS-010 subsystem per the master plan.
