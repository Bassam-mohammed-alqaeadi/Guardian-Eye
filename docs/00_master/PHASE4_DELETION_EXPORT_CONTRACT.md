# Phase 4 — Deletion and Export Contract (Phase B)

**Author:** Manus AI
**Branch:** `feature/design-system-integration`
**Date:** August 21, 2026
**Status:** Draft contract — **not yet approved; no code has been written.**
**Companion document:** `PHASE4_DISCOVERY_REPORT.md` (Phase A evidence).

---

## 1. Data Classification Matrix

Every data domain was classified from the Phase A inventory. Classification codes: **L** = local-only, **RS** = remote-synced (mirrored to Firestore via the outbox), **LA** = local aggregate derived from other data, **AA** = audit/append-only, **SC** = security credential/token, **TA** = temporary/cache/export artifact, **FA** = frozen AI (must not be expanded). Retention values marked **UNKNOWN** require a product decision; nothing was invented.

| Domain | Local table(s) | Class | Owner | Readers | Deletion requester | Child/spouse see it? | Exportable | Retention | Deletion behavior | Remote behavior | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Family core | `families` | RS | owner | members | owner (owner-only) | child sees name only (via membership), spouse reads family doc | yes (identity) | UNKNOWN → propose: until family deleted | local: row archived (not destroyed until verified); remote: **unavailable** | discovery §2 |
| Members | `family_members` | RS | family | members (own row fully, others name/role) | owner only | yes (limited) | yes (own) | until revoked | **soft revoke** (status flip + outbox); hard delete **requires separate approved contract** | membership repo `revokeMember` |
| Invitations | `family_invitations` | RS | family | members | owner | yes (invitee) | no | expires-at natural death | cancel (soft, outbox `family.invitation.cancelled`) | existing contract |
| Devices | `devices`, `child_device_states/policies` | RS | parent of device | parents | parent (role `manageDevices`) | child never; spouse no | yes (identity) | until revoked | revoke = access + token cutoff; family history untouched | rules L152-156 parent-delete; client contract exists for device doc |
| Notification tokens | `notification_tokens` (+ remote subcollection) | RS+SC | device owner | parents | parent; self on own device | no | no (opaque) | stale→invalid | mark `invalid`, revoke via Render `notify` stale-cleanup; auth `revokeTokens` later | TokenRevocationService |
| Locations | `locations`, `location_points` (+ `families/{id}/locations`) | RS | family | parents | parent (location rules) | child device contributes but does not read others | yes (own history) | UNKNOWN → propose: per retention key `privacyLocationRetention` | wipe points locally + enqueue outbox op | parent-delete rules L208-211 |
| Geofences | `geofences` (+ remote) | RS | family | members | parent | yes | yes | until deleted | soft disable exists; hard delete via parent contract | rules L340 |
| Favorite places | `favorite_places` (+ remote) | RS | family | members | parent | yes | yes | until deleted | parent-delete contract | rules L354 |
| Incidents | `incidents` (+ remote) | RS+AA | family | parents | parent | child never | yes (identity only) | UNKNOWN → propose: safety retention | local delete allowed only for non-notifyable records; audit states retained | rules L185 |
| SOS | `sos_events`, `sos_recipients` (+ remote) | RS+AA | family | parents | parent | child never | yes (identity only) | UNKNOWN → propose: critical-safety retention | same as incidents | rules L196 |
| Web filtering | `web_hits/domains/category_rules/settings` (+ remote) | RS | family | parents | parent | child never | yes (aggregate) | period-scoped | local wipe + outbox | parent-delete rules L364-378 |
| App control | `app_policies/allowlist/block_history/usage_alert_settings` (+ remote) | RS | family | parents | parent | child never | yes (aggregate) | policy-versioned | local wipe + outbox | rules L384-397 |
| Monitoring/screen time | `monitoring_*`, `child_usage_*`, `child_enforcement_*`, `child_exception_requests` (+ remote) | RS | family | parents | parent | child only own status | yes (aggregate) | UNKNOWN → propose: per-monitoring-policy retention | local wipe + outbox | rules L403-429 |
| Modes & family rules | `mode_*`, `family_rules`, `rule_execution_log`, `policy_overrides` (+ remote) | RS | family | members view / parents write | parent | child sees active modes | yes | until replaced | parent-delete contract | rules L432-444 |
| Tasks & rewards | `tasks`, `task_completion_log`, `family_rewards`, `reward_points_ledger`, `reward_pending_claims` (+ remote) | RS+AA (ledger) | family | members own / parents all | parent | child own tasks | yes (aggregate) | ledger **append-only forever** | local delete of task/reward only; ledger rows retained | rules L222-322 |
| Event registry | `family_events`, `normalized_signals`, `source_event_tracking`, `ai_consent_scopes` | **LA** | family | parents | owner (precedent exists) | child never | no | local retention | **existing precedent** `deleteFamilyEvents` | event_registry repo L140 |
| AI | `ai_risk_states`, `ai_behavior_profiles`, `ai_insights`, `ai_detections`, `ai_copilot_suggestions`, `ai_policy_proposals` | **FA** | family | parents | **none in Phase 4** | child never | no | frozen | **no new retention/deletion behavior added** — only documented | your instruction |
| Couple Harmony | `couple_linking/routines/responsibilities/proposals/handovers` | L | both partners | couple members | either partner (own data); joint rows symmetrically | spouse yes | yes (joint) | local retention | local wipe both sides | FS-013 |
| Subscription & billing | `subscription_entitlements`, `subscription_usage_limits`, `billing_records` | L+AA | account holder | self | self | no | yes (audit only) | local audit | keep audit rows; entitlements purged | local-only entitlements |
| Outbox & sync | `outbox`, `policies` | RS | device | device | device | no | no | flushed on sync | **drained or explicitly abandoned** — never silently dropped | outbox_sync_executor |
| Notifications | `notification_events` (client-delete: false), `notification_settings` | RS+LA | family | parents | server only | child never | no | until acknowledged/archived | client cannot delete remote; local events cleared on purge | rules L215 |
| App identity | `app_identity` | **SC** | device | device | self | no | no | reinstall | wiped on local purge | Phase 3 |

## 2. Operations Contract

The requester boundary uses the app's authorization system exclusively: `FamilyRuntimeContext.can(FamilyPermission.x)` plus the owner check `actorMemberId == ownerMemberId` (already encapsulated in `FamilyMembershipRepository._requireOwner`). Firebase Auth identity is `FirebaseAuth.instance.currentUser.uid`. "Re-authentication" means Firebase `reauthenticateWithCredential` against the user's own credential before the destructive call.

### A. Delete local data from the current device ("Local purge")

| Field | Definition |
|---|---|
| Requester | Any signed-in user on their own device (self-operation); confirmed in a dedicated dialog |
| Re-authentication | **Required** for account-linked devices (credential recheck); not required for unbound offline accounts beyond the confirmation dialog |
| Data affected | Every table in the inventory except `billing_records` audit rows (retained 90 days UNKNOWN-proposed) and AI tables (`ai_*` — frozen, untouched unless you approve a delete decision); caches, app dir export artifacts, generated PDF/CSV reports, downloaded thumbnails |
| Local behavior | Immediate, transactional batch within a single SQLite transaction; outbox rows **abandoned** explicitly (`state: 'abandoned'`, `last_error: 'local_data_deleted'`) — never deleted silently |
| Remote behavior | **Unavailable** — no remote deletion contract exists; purge is local only by definition |
| Offline behavior | `completed` (local purge has no remote dependency) |
| Partial failure | `partially_completed` with per-table result map; retry offered per table |
| Irreversible boundary | All local tables except retained audit + frozen AI; **remote data is NOT deleted** — the family survives on Firestore |
| Success evidence | `SELECT COUNT(*) = 0` per purged table; outbox `abandoned` confirmation; audit row written to `billing_records`-style local audit table with timestamp and actor, no payload |
| Export format | n/a |

### B. Delete my account

| Field | Definition |
|---|---|
| Requester | The user's own Firebase Auth UID — verified `currentUser.uid == requesterUid` |
| Re-authentication | **Required** — `reauthenticateWithCredential` immediately before destruction; failure → `failed` |
| Data affected | Local: everything in operation A plus `app_identity`; Remote: **only the Firebase Auth user record** (via `currentUser.delete()`) |
| Local behavior | A — purge first, then Auth deletion **last** |
| Remote behavior | Auth deletion via Firebase Auth client SDK (existent contract). Family/member Firestore data: **BLOCKED-BACKEND** — no endpoint deletes the family documents |
| Offline behavior | `blocked_offline` ("Cannot verify account credentials while offline") |
| Partial failure | Auth delete failure → `partially_completed`: local purge done, account still exists; user shown honest split state with retry for the auth step only |
| Irreversible boundary | The Auth record deletion. Local purge alone is marked "local data removed" only |
| Success evidence | `FirebaseAuth.instance.currentUser == null` after deletion + local counts zero |
| Export format | n/a |

### C. Delete this family

| Field | Definition |
|---|---|
| Requester | **Owner only**: `FamilyRuntimeContext.can(FamilyPermission.manageMembers)` **and** `actorMemberId == ownerMemberId`. Child/spouse/co-parent → denied at the context layer before any UI path |
| Re-authentication | **Required** (owner credential recheck) + typed confirmation string |
| Data affected | Local: all family-scoped tables for this family + outbox rows belonging to this family (abandoned explicitly) + `notification_tokens` entries; Remote: **unavailable** — Firestore family documents are NOT deleted by the client |
| Local behavior | Immediate, transactional, same device only |
| Remote behavior | **BLOCKED-BACKEND** until an authenticated owner-only Render contract exists (recommended future endpoint) |
| Offline behavior | `completed` for local scope (no remote dependency); banner states remote family data still exists in the cloud |
| Partial failure | `partially_completed` with per-table map; retry per table |
| Irreversible boundary | Local family data only. Remote data survives |
| Success evidence | Per-table zero-count + outbox abandoned confirmation + owner audit record |
| Export format | n/a |

### D. Remove a family member

| Field | Definition |
|---|---|
| Requester | Owner (`FamilyPermission.revokeMembers` + owner check) — matches existing `revokeMember` contract exactly |
| Re-authentication | Not required (matches existing flow) |
| Data affected | Soft revoke only: member status → `revoked`, member devices → `revoked_at`, outbox op `family.member.revoked` |
| Local behavior | Immediate, transactional (existing) |
| Remote behavior | Existing outbox contract; remote document not hard-deleted |
| Offline behavior | Queued (existing outbox semantics) |
| Partial failure | `partially_completed` |
| Irreversible boundary | None — soft revoke is reversible by the owner |
| Hard delete | **Out of Phase 4** unless a separate approved contract is added — requires the future Render endpoint |
| Success evidence | Existing `revokeMember` transaction + outbox enqueue |

### E. Revoke/remove a child device

| Field | Definition |
|---|---|
| Requester | Parent with `FamilyPermission.manageDevices` |
| Re-authentication | Not required (policy-level action) |
| Data affected | `devices.revoked_at`, `child_device_states` cutoff, `notification_tokens` → invalid + enqueue, outbox op `device.revoked` (existing) |
| Local behavior | Immediate; tokens revoked on next `notify` dispatch (stale-cleanup path); child device loses policy delivery |
| Remote behavior | Existing outbox contract; remote device doc updated by parent rules (L152-156) |
| Offline behavior | Queued for device doc; token invalidation local-immediate |
| Partial failure | `partially_completed` |
| Irreversible boundary | None — device history (usage, enforcement evaluations) is retained; revocation is reversible |
| Success evidence | Existing device-revoke transaction + token invalidation counts |

### F. Export my authorized family data

| Field | Definition |
|---|---|
| Requester | Parent or owner (`can(viewFamily)` + family membership) — never a child |
| Re-authentication | Not required for local export (data is already on-device) |
| Data affected | Export bundle (JSON) + optional PDF/CSV report (reuses `ReportExportService` patterns): family identity (name, my role), my members view, my devices view, location settings (not raw history unless the requester is the data subject's parent), geofences, incidents/SOS identities, web + app aggregate stats for the selected period, tasks/rewards aggregates, modes, couple (self), subscription (self) |
| Excluded by construction | Another family's data (exporter is bound to a single `familyId` from the local membership row), raw FCM tokens, `app_identity` values, service-account material (none exists on device), outbox payloads, AI frozen tables |
| Local behavior | File written to app documents dir; **no network call required** — works fully offline (`blocked_offline` never applies; permission-denied applies only if file-system write permission fails) |
| Remote behavior | **Blocked-external**: `share_plus` handoff to the OS share sheet |
| Partial failure | `failed` with per-section flags; retry regenerates |
| Irreversible boundary | None |
| Success evidence | File exists, non-empty, valid JSON parse; section manifest lists exactly what was included |
| Export format | **JSON** primary (structured, localized labels, schema-versioned), **PDF/CSV** optional via existing `ReportExportService` |
| Export states | `not_requested → permission_check → preparing → ready_to_share → shared_or_saved`; failures `blocked_permission, failed, cancelled, expired` |

### G. Delete location history

| Field | Definition |
|---|---|
| Requester | Parent (`can(viewChildStatus)` + location authorization) |
| Data affected | `location_points` rows for the selected family/period; remote `locations` docs via outbox envelope |
| Behavior | Local wipe within a date range + remote delete request queued; **unverifiable remotely today → local state honest, remote marked `blocked_backend` pending future contract** |
| Evidence | Per-family per-period zero-count locally |

### H. Delete event-registry data

Uses the **existing precedent** `family_event_registry_repository.deleteFamilyEvents(familyId)` (wipes `family_events` + `normalized_signals` for the family). No new contract needed; it becomes one privacy-screen action behind `FamilyPermission.viewAiInsights`-style parent gate.

### I. Revoke notification tokens and app identity

| Field | Definition |
|---|---|
| Requester | Self (own device) |
| Data affected | `notification_tokens` → `revoked_at`; `app_identity` wiped; Render notification channel disabled via `notification_settings` key |
| Remote behavior | FCM token invalidation on next dispatch (existing stale-cleanup in `/api/notify`); auth `revokeTokens(uid)` via Admin only from a future endpoint |
| Evidence | Token row counts zero + identity key absent |

### J. Outbox handling during deletion/export

All queued rows belonging to a purged family are moved to `state = 'abandoned'` with `last_error = 'local_data_deleted'` inside the same transaction as the purge. Rows already `in_flight` during a purge abort and are marked `failed` then `abandoned`. Rows **not** belonging to the purged family are untouched. Export never reads or writes the outbox.

### K. Partial remote failure

Every operation that touches remote state reports per-step outcomes. The UI renders `partially_completed` with the exact subset verified, offers retry for the failed subset only, and never rolls the honest state back to "success." No new remote call is synthesized to hide the failure.

### L. Legacy migration before deletion/export (migration compatibility gate)

**Finding (from discovery):** the upgrade path (`_upgradeSchema`, lines 331–700) creates 61 tables via migrations but **never creates** the nine foundational tables `families, family_members, devices, locations, messages, pairing_sessions, incidents, outbox, policies`. A live app on schema < v2 upgrading today would crash on any write to those tables. The schema history is fully provable from `guardian_database.dart` (fresh schemas at lines 45–78; migrations at 331–700; the nine tables appear only in the fresh path).

**Proposed idempotent gate (Phase C implementation, separate from deletion):** before any privacy operation runs, `_ensureBaseSchema()` executes `CREATE TABLE IF NOT EXISTS` for exactly the missing nine tables and their indexes, then a `_verifyBaseSchema()` sanity check. No data is altered. If either table already exists, no-op. Failure mode: privacy screen shows `blocked_migration` ("Database could not be prepared — contact support") and refuses to proceed.

**Upgrade tests:** construct an in-memory SQLite database at representative versions (v1 fresh, v12 pre-membership-accounts, v28 pre-notifications) by replaying the real `_createSchema`/`_upgradeSchema` logic, then run `openDatabase(... version: 29)` and assert all nine tables + indexes exist and existing rows are untouched.

**Rollback:** migration gate never deletes or alters data, so no rollback is needed beyond leaving the DB untouched on error (the transaction-free idempotent DDL either succeeds or throws without side effects).

**Separation rule:** destructive deletion and migration never share code paths, transactions, or tests.

## 3. Local-vs-Remote Boundary (explicit)

| Layer | Deletable in Phase 4 | Blocked until |
|---|---|---|
| SQLite (all family tables) | **Yes** (local purge, with retained audit + frozen AI) | — |
| SQLite metadata (outbox, tokens, identity) | **Yes** (abandon/void) | — |
| File artifacts (exports, caches, reports) | **Yes** | — |
| Firebase Auth user record | **Yes** (owner only, re-auth, last step) | — |
| Firestore family documents & subcollections | **No** | Authenticated owner-only Render endpoint (future) |
| Firestore notification_events | **No** (client delete permanently false by rules) | — |
| Render FCM delivery | Existing stale-cleanup only | — |

## 4. State Machines (as required)

Deletion: `not_requested → confirmation_required → reauthentication_required → in_progress → completed` with non-success exits `partially_completed, failed, blocked_offline, blocked_permission, blocked_backend, blocked_migration, cancelled, unknown`. Export: `not_requested → permission_check → preparing → ready_to_share → shared_or_saved` with failures `blocked_offline, blocked_permission, failed, cancelled, expired, unknown`. The UI reads state only from verified evidence (zero counts, null current user, file existence + parse) — never from a hopeful return value.

## 5. Screens and UX Contract (to implement in Phase C)

One new **Privacy & Data Controls** screen (settings entry point) containing: Local Data Purge, Delete Account, Delete Family (owner-only, hidden otherwise), Remove Member entry (existing member management reuses), Revoke Device entry (existing), Delete Location History, Export Data, Notification Token & Device Privacy, and Privacy Policy & Retention info (existing `privacy*` l10n keys reused). Every screen: Cairo typography, Guardian primitives (rounded-16 cards, navy `#0F2A5B`/teal `#00B8A9`), AR RTL + EN LTR via `t()` keys, and loading/empty/error/offline/permission-denied/partial-success/honest-blocked-backend states. No sensitive payload in logs.

## 6. Test Plan (Phase D)

Owner-only family deletion; non-owner denial; child and spouse denial via `FamilyRuntimeContext`; cross-family denial (purge targets only the actor's family); soft revoke vs hard delete (hard delete absent = asserted not implemented); device revoke + token cleanup counts; complete local purge across **all current tables** (zero-count assertions per table incl. metadata); outbox abandon counts vs dropped counts; export contains exactly the authorized family's data (seed two families, assert cross-family absence); export excludes tokens/identity/outbox/AI tables; re-auth failure path; offline and partial-failure state assertions; repeated purge idempotency (second run → `completed` with no-op semantics); migration gate from v1/v12/v28 in-memory SQLite → v29 with pre-existing rows intact; AR/EN localization and RTL layout widget tests.

## 7. Unknowns and Required Product Decisions

1. **Retention periods** for locations, incidents, SOS, and monitoring data are UNKNOWN — propose: locations per `privacyLocationRetention` key; incidents/SOS retained until owner explicitly deletes (safety records); monitoring per policy. Please confirm or correct.
2. **AI data deletion decision**: frozen tables stay untouched in Phase 4. If you ever want them purgeable, that requires a separate approved decision (outside this phase).
3. **Remote family deletion/export endpoint** on Render: formally BLOCKED-BACKEND in this phase. When you approve, it is a later phase with its own security contract (owner-only, re-auth token, no client-supplied family id trust).
4. **`billing_records` audit retention**: proposed 90 days, UNKNOWN until you decide.
5. **Legacy migration gate**: approved as a separate safe sub-task inside Phase C, not mixed with deletion.

## 8. Non-Goals (explicit)

No new destructive backend endpoint; no Firestore rules change; no AI retention/deletion behavior; no FS-010/FS-012/FS-014/FS-016; no billing integration; no redesign of existing screens; no production data touch; no deployment; no push.

---

**Stop point:** per your instruction, I stop here without writing code, without modifying files, and without creating a commit. Awaiting your approval of this contract (including the UNKNOWN product decisions) before Phase C.
