# Phase 3 — Architecture Correction Report (Phase A)

**Project:** Guardian Eye Pro — Flutter Android family-safety platform
**Branch:** `feature/design-system-integration`
**Phase:** 3, Phase A — Architecture correction (read-only; no production change, no deployment)
**Date:** 21 August 2026
**Author:** Manus AI
**Driving instruction:** the revised Phase 3 instruction states that **Render is the intended backend host** for notifications and that Firebase Blaze/Functions must not be assumed. Render `onDocumentCreated` triggers are not available by themselves, so an event-ingestion mechanism must be identified before any implementation.

---

## 1. Classification of the Existing Firebase Functions Implementation

The file `firebase/functions/src/index.ts` (197 lines) contains two unrelated systems — child device provisioning and the notification pipeline. Only the notification pipeline is relevant to Phase 3.

| Component | Lines | Classification | Portability to Render |
|---|---|---|---|
| `createNotificationRequest` | 146–156 | **Reusable domain logic** — idempotent creation of the notification event document (`kind` + `sourceId` → `eventId`, status `pendingBackend`). Pure Firestore admin logic | **Portable as-is** (firebase-admin/firestore works on any Node host) |
| `fanoutNotification` body | 167–196 | **Mostly reusable domain logic** — transactional exactly-once claim (`pendingBackend`→`processing`), active-token fanout via `collectionGroup('notification_tokens')` filtered by `familyId`, data-only payload construction (`kind, familyId, sourceId, notificationEventId`), invalid-token revocation (`messaging/registration-token-not-registered`, `messaging/invalid-registration-token`), terminal states (`backendAccepted`, `backendFailed`, `noActiveToken`, `fcmNotExercisedInEmulator`) | **Portable with adaptation** — the claim transaction, token selection, messaging call, and cleanup are all admin-SDK operations; only the trigger attachment is Functions-specific |
| `requestIncidentNotification`, `requestSosNotification`, `fanoutNotification` (trigger attachment) | 158–166 | **Firebase-Functions-specific trigger/wrapper** — `onDocumentCreated` Firestore triggers bound to `families/{familyId}/incidents/{incidentId}`, `.../sos/{sosId}`, `.../notification_events/{eventId}` | **NOT portable** — this is the exact mechanism unavailable on Render; must be replaced by an event-ingestion mechanism |
| `initializeApp`, `getFirestore`, `getMessaging` | 1–9 | **Configuration/deployment code** | **Portable** — the Render `guardian_backend` already bootstraps exactly this from `/etc/secrets/serviceAccountKey.json` |
| `createChildDeviceProvisioning`, `redeemChildDeviceProvisioning`, `requireParent`, `requiredString`, `hashPairingCode` | 11–144 | Unrelated (FS-015 provisioning) — already ported to Render | N/A for Phase 3 |

**Conclusion of step 1:** roughly 90% of the notification domain logic (event creation, claim, fanout, payload construction, token revocation, failure states) is plain firebase-admin code and moves to Render unchanged. The only thing that must be replaced is the **trigger mechanism** (`onDocumentCreated`), which is precisely the event-ingestion question of step 3.

## 2. Render Capability Confirmation (verified in-session, read-only)

The repository ships `guardian_backend/` — a Node/Express service that **already runs on Render** and already uses firebase-admin with a Render secret-mounted service-account key:

| Evidence | Finding |
|---|---|
| `guardian_backend/package.json` | Express 5 + firebase-admin 14 + cors + dotenv; `node index.js` on `$PORT` — standard Render web-service layout |
| `index.js` L26–28, L456–480 | Admin SDK initialized from `/etc/secrets/serviceAccountKey.json` (Render secret), falling back to a local key for development; `auth.verifyIdToken()` middleware already implements server-side ID-token verification |
| Live health probe | `GET https://guardian-eye-djg8.onrender.com/` → `{"status":"ok","service":"guardian-backend"}` — **the service is live in production** |
| Live endpoint probes | `/api/provision-child`, `/api/redeem-child`, `/api/notify` → **404** — the production deployment is currently running an **older codebase without** `/api/notify` (the endpoint exists only in the repository source). Provisioning endpoints similarly 404 in production |
| Local test suite | `npm test` → **27/27 pass**, including 7 `/api/notify` tests (unauthenticated rejection, non-member rejection, no-tokens, delivery to parent device tokens, stale-token invalidation) |
| Service-account key | Key lives only at `/etc/secrets/serviceAccountKey.json` on Render / local dev copy; **nothing in Git, logs, or reports** |

**Conclusion of step 2:** Render can safely host the notification sender. It already has the runtime, the admin SDK, the verified-ID-token auth middleware, and — critically — **an already-written, already-tested `POST /api/notify` endpoint in the repository source**. Note honestly: the production Render deployment (live right now) is running an older snapshot that does not expose `/api/notify`; making it live is a deployment/infrastructure step, not a code step.

## 3. The Required Event-Ingestion Mechanism

`onDocumentCreated` triggers are a Firebase-Functions primitive; Render receives only HTTP traffic (and scheduled cron jobs, which would be polling, not triggers). Render therefore cannot learn about new incidents/SOS automatically from Firestore. The event-ingestion mechanism must come from one of four candidates.

## 4. Option Comparison

| # | Option | Description | Fit with existing codebase | Honest assessment |
|---|---|---|---|---|
| **A** | **Authenticated app → Render notification request endpoint** | The app calls `POST /api/notify` (Render, Bearer Firebase ID token) when it creates an incident/SOS; Render verifies the token, verifies family membership, collects active parent tokens, sends data-only (or minimal) payloads, revokes invalid tokens | **Exact match.** The endpoint is already implemented (`index.js` L346–437), has 7 passing server tests, uses the same auth + membership pattern as `/api/provision-child`, and the app already has a Render HTTP client (`RemoteProvisioningService` pattern with ID-token injection). The client contract for the missing pieces (incident/SOS write path) is local-only today, so there is no client side to break | **Recommended.** This requires no new event source, no polling, no new infrastructure, no trigger replacement — the app *is* the event source, the same pattern Firestore triggers replaced. Synchronous, auditable, testable end-to-end |
| **B** | Render worker polling `notification_events` / outbox collection | A cron/scheduled task on Render polls Firestore for `status == pendingBackend` rows and fans them out | Polling exists nowhere in the codebase; adding a scheduler means new Render cron infrastructure, new loop code, and reconciling against the already-complete `/api/notify` endpoint. Also re-creates the exactly-once claim logic that the app-side trigger already guarantees | **Rejected as unnecessary** — strictly more machinery than A for identical security properties |
| **C** | Existing Render outbox/provisioning pipeline | Reuse the provisioning pipeline (`provisioningSessions`) or any existing outbox | **No such pipeline exists for notifications.** The provisioning pipeline is for device pairing sessions and has no notification semantics; `guardian_backend/` contains zero outbox/sync/poll code (grep-verified). Client-side `firestore_contracts.dart` defines a token-sync outbox contract, but the outbox registry is unwired and the rules permanently block client writes to `notification_events` | **Not available** — would be invention, which the instruction prohibits |
| **D** | Another already-approved event bridge | Some previously approved webhook/bridge/queue | No webhook, queue, or bridge is documented or coded anywhere in the repository or docs (grep-verified against `docs/`) | **Not available** — nothing approved exists |

## 5. Recommendation

**Option A — authenticated app → Render `/api/notify` — is the safest option, and it is the only option grounded in already-written, already-tested repository code.**

The correction to the previous discovery report is that the earlier "sender must live in Firebase Functions" conclusion was written before Render's `guardian_backend` (with its `/api/notify` endpoint and 27 passing tests) was fully assessed against the revised deployment strategy. Under the confirmed Render-first strategy, the architecture is:

1. **Event ingestion = the app itself.** When a parent creates an incident or SOS (a currently local-only SQLite write), the same screen/flow posts `POST /api/notify` to Render with the Bearer Firebase ID token. No trigger, no poller, no bridge.
2. **Server authority (Phase B contract alignment).** Render already satisfies items 1–2 of the required contract (`verifyIdToken` + member existence/role check in `requireAuth` and the member-active check in `/api/notify`); items 3–6 (event existence/authorization, never trusting client IDs, idempotency, replay/duplicate/cross-family prevention) and 8 (token revocation, already tested) remain to be hardened in a follow-up Phase D hardening pass — see Section 6.
3. **Payload honesty.** The existing endpoint mixes a display `notification` block with a `data` block. Phase D must enforce the instruction's item 7: data-message-only payloads carrying only `kind, familyId, sourceId/eventId, notificationEventId`, with all detail retrieved in-app after authentication.
4. **Rules are untouched.** Firestore rules currently block client writes to `notification_events`; under Option A the app no longer writes them at all — it asks Render to send, and Render can continue writing audit evidence as today. **No rule change is required.**

### What remains BLOCKED-EXTERNAL vs local

| Item | Status |
|---|---|
| Full server-side render of the chosen architecture (production `/api/notify` live) | **BLOCKED-EXTERNAL** — requires redeploying `guardian_backend` on Render with the service-account secret and notifying the changed codebase; deployment on Render is a human/infrastructure action |
| Live authenticated Firebase session for `manus-guardian` (to deploy if Functions were ever needed) | BLOCKED-EXTERNAL (carried over from Phase 2) |
| Android real-device push test (foreground/background/terminated/deep-link) | Requires the production Render endpoint to be live first |
| Classification of existing Functions code; Render capability confirmation; option comparison; local server test runs (27/27) | **VERIFIED LOCALLY** in this session |

## 6. Gap Analysis of the Existing `/api/notify` Against the Phase B Contract

The existing endpoint is a strong foundation but does not yet satisfy every Phase B requirement, which defines the Phase D hardening scope:

| Contract item | Current state | Phase D action |
|---|---|---|
| 1. ID-token verification | Done (`verifyIdToken` in `requireAuth`) | None |
| 2. Family membership | Done (member doc exists + `status: active`) | None |
| 3. Event exists and is authorized | **Missing** — any member can request any `kind` without an incident/SOS existing | Server must resolve `incidentId`/`sosId` against `families/{familyId}/incidents/{id}` / `sos/{id}`, re-check the caller's visibility/role before sending |
| 4. Never trust client IDs | **Partial** — `familyId` is used only for Firestore lookup; but `kind`, `incidentId` are client-supplied | Validate kinds against a server enum; reject unknown kinds; ignore client-supplied recipient lists |
| 5. Idempotency | **Missing** — no per-event record; repeated calls re-send | Write an event document (`notification_events/{kind}_{sourceId}`) first with idempotent creation, then fan out only if the claim transaction flips status — mirrors the portable Functions logic from Section 1 |
| 6. Replay / duplicate fanout / cross-family / unauthorized recipient selection | Partially mitigated by the transactional claim (if 5 is added); recipients are currently derived from `devices` (parent roles only) — no recipient selection parameter exists, which is correct | Complete via 5; keep recipient derivation server-side only |
| 7. Data-message-only payloads | **Not compliant** — currently sends `notification.title/body` | Strip the `notification` block; send `data` only (`kind, familyId, sourceId, notificationEventId`); the app renders the localized notification from the event id |
| 8. Revoke invalid tokens | Done and tested (`status: invalid`) | None (consider `revoked` naming alignment with the Functions convention) |
| 9. Secrets only in Render secret storage | Done | None |
| 10. Timeout / retry / backoff / dead-letter / failure states | **Missing** — single synchronous `sendEachForMulticast`; no retry, no dead-letter state on the event document | Add `backendAccepted`/`backendFailed`/`pendingBackend` event states and a bounded retry with backoff; log failure kinds |

## 7. Summary

Under the confirmed Render-first strategy, the correct and safest architecture is **Option A**: the app posts to the already-implemented, already-tested Render endpoint `POST /api/notify`, authenticated by Firebase ID token, with Render performing all authorization, fanout, token revocation, and audit recording. Firebase Functions are no longer the sender host and need not be deployed; the Functions source remains as a classification reference only. The production Render deployment must be refreshed to the current repository snapshot (it currently returns 404 for `/api/notify`), which is an external deployment action. Phase C (app-side foundation: token lifecycle, channel, handlers, rendering, routing, preferences, honest states, tests, localization) can proceed immediately and is independent of the deployment; full end-to-end delivery may be claimed only after the Render deployment is refreshed and a real Android test completes.

**Requesting approval:** Phase C app-side implementation per the revised instruction, with Phase D hardening of `/api/notify` (Section 6) to be performed if the Render source remains in this repository and credentials/deployment become available; otherwise Phase D is marked BLOCKED-EXTERNAL with an exact human-action contract.

---

*All findings are from read-only inspection of `firebase/functions/src/index.ts`, `guardian_backend/` (index, tests, package), live probes against `guardian-eye-djg8.onrender.com`, `lib/`, and `docs/`. No production configuration was modified; no credentials were printed; no code was committed. Local dependency install (`npm install` in `guardian_backend/`) was performed solely to execute the existing 27-test suite and does not change the codebase.*
