# Sync Conflict Policy — Guardian Eye Pro

## General rule

SQLite is authoritative for pending offline operations; Firestore is the shared family source of truth after an authenticated server-accepted write. No remote write silently overwrites a conflicting protected record. Each sync mutation carries the immutable outbox event ID, idempotency key, creation time, operation, and entity ID.

| Entity | Version/timestamp strategy | Conflict strategy | Deletion semantics |
|---|---|---|---|
| Family ownership | Immutable owner UID | Reject any owner change from mobile client; backend-only migration | Archive only; retain audit record. |
| Members / child profiles | `updatedAt` plus role | Parent edits require current role; backend rejects self-escalation and cross-family writes | Soft archive/status change. |
| Device | Enrollment/revocation transition | Revocation wins permanently; an active write after revocation becomes permanent failure | `status: revoked`, never hard-delete audit. |
| Pairing | State machine and expiry | First valid enrollment wins; reused/expired/revoked request rejected | Retain terminal state until retention policy cleanup. |
| Policies | Monotonic version + `updatedAt` | Reject stale update; client refreshes and creates an explicit new edit instead of overwrite | Disabled/archived, not destructive deletion. |
| Incidents / SOS | Append-only event ID | Duplicate event ID maps to the same remote document; acknowledgement transition is monotonic | Resolved/retained according to privacy policy. |
| Notification token | Device + token keyed record | Latest token for an active device replaces prior active token; revoked device token is invalidated | Revoke token state; backend deletes only after policy retention. |

Retryable transport failures retain the local outbox row with deterministic exponential backoff. Permanent authorization, malformed payload, invalid ownership, and revoked-device failures move the event to `blocked`; they do not retry indefinitely. Process restart is safe because pending state and next retry time are persisted in SQLite. Physical Doze/force-stop behavior still requires Android device validation.
