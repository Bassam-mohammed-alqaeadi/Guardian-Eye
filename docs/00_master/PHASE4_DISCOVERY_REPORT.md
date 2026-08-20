# Phase 4 — Privacy Controls, Deletion & Data Export: Phase A Discovery Report

**Author:** Manus AI
**Branch:** `feature/design-system-integration`
**Date:** August 21, 2026
**Method:** Strict read-only inspection. No source file was modified, no database was opened, no endpoint was called. All evidence below is traced to file locations in the repository.

---

## 1. SQLite Data Inventory (DB v29)

The database file is `guardian_eye_pro.db` with foreign keys enabled (`PRAGMA foreign_keys = ON`). The current schema version is **29** (`version: 29` in `lib/core/database/guardian_database.dart` L28). The fresh-install path is `_createSchema` (all tables) and the upgrade path is `_upgradeSchema` (incremental migrations `oldVersion < 2 … < 29`). All 70+ tables exist in both paths except the nine foundational tables listed in Section 5, which exist **only in the fresh-install path** — a pre-v2 app cannot upgrade to v29 today. This is an honest finding that Phase C may address with an idempotent base-schema migration guard.

| Data domain | Local table(s) | Domain notes |
|---|---|---|
| Family core | `families`, `family_members`, `family_invitations` | Owner/role/status (`active`, `revoked`, `expired`), `account_uid` binding |
| Devices & tokens | `devices`, `child_device_states`, `child_device_policies`, `notification_tokens` | `revoked_at` soft-revocation on devices; tokens keyed per family device |
| Location | `locations`, `location_points`, `geofences`, `favorite_places`, `location_settings`, `location_alerts` | Points carry `sync_state`; alerts acknowledgeable |
| Safety incidents | `incidents`, `sos_events`, `sos_recipients` | Incident carries `device_id`, `actor_uid` (v14+) |
| Web filtering | `web_hits`, `web_domains`, `web_category_rules`, `web_settings` | All `sync_state queued`; domains/categories family-scoped |
| App control | `app_policies`, `app_allowlist`, `app_block_history`, `usage_alert_settings` | Phase FS-002/FS-003 |
| Monitoring & screen time | `monitoring_shots`, `monitoring_sessions`, `monitoring_requests`, `monitoring_schedules`, `monitoring_evidence_queue`, `child_usage_observations`, `child_usage_summaries`, `child_usage_evaluations`, `child_enforcement_states`, `child_enforcement_evaluations`, `child_exception_requests` | FS-004/FS-005 |
| Modes & family rules | `mode_configs`, `mode_activations`, `family_rules`, `rule_execution_log`, `policy_overrides` | FS-005/FS-011 |
| Tasks & rewards | `tasks`, `task_completion_log`, `family_rewards`, `reward_points_ledger`, `reward_pending_claims` | FS-007/FS-008; ledger is append-only |
| Event registry & signals | `family_events`, `normalized_signals`, `source_event_tracking`, `ai_consent_scopes` | Phase 9 |
| **AI (FROZEN — must not expand)** | `ai_risk_states`, `ai_behavior_profiles`, `ai_insights`, `ai_detections`, `ai_copilot_suggestions`, `ai_policy_proposals` | Deterministic rule-based AI, frozen by your instruction |
| Couple Harmony | `couple_linking`, `couple_routines`, `couple_responsibilities`, `couple_proposals`, `couple_handovers` | FS-013 |
| Subscription & billing | `subscription_entitlements`, `subscription_usage_limits`, `billing_records` | Local-only entitlements; `billing_records` audit-style (no real payment processor) |
| Sync & notifications | `outbox`, `policies`, `notification_events`, `notification_settings`, `notification_tokens`, `app_identity` | Phase 3 additions (v29) |

All tables are family-scoped through `family_id` foreign keys, and most carry a `sync_state` (`queued`/`synced`/`failed`-style) column driving the outbox.

## 2. Firestore Paths and Remote Contracts

`lib/data/firestore_contracts.dart` (`FirestorePaths`) enumerates every remote path the app constructs. The family document `families/{familyId}` is the root; everything else is a subcollection: `members`, `children`, `devices` (+ `notification_tokens`, `enforcement_status/current`, `usage_summaries`), `device_pairings` (client write **permanently false** — pairing flows through the authenticated Render provisioning endpoint), `policies`, `policy_overrides`, `exception_requests`, `incidents`, `sos`, `sos/recipients`, `locations`, `geofences`, `favorite_places`, `location_settings`, `notification_events` (client create/update/delete **permanently false**), `sync_metadata`/`sync_events`, `web_hits`, `web_domains`, `web_category_rules`, `web_settings`, `app_policies`, `app_allowlist`, `app_block_events`, `usage_alert_settings`, `monitoring_shots/sessions/requests/schedules/evidence`, `mode_configs`, `mode_activations`, `family_rules`, `tasks`, `task_completions`, `rewards`, `reward_claims`, `reward_ledger`.

The delete-permission surface in `firebase/firestore.rules` is: **owners** can delete `members`, `invitations`, and most parent-only collections; **parents** can delete policies, overrides, devices, messages, geofences, mode configs, and app-control collections; client delete on `notification_events`, `sync_events`, `device_pairings` is `if false`. There is **no client-side remote delete contract for family deletion, account deletion, or data export** anywhere in the rules or in the app.

The app writes remotely exclusively through the **outbox** (`outbox` SQLite table + `outbox_sync_executor.dart` + `outbox_sync_status.dart`) with 19 known operations: `device.enrolled/revoked/transferred`, `family.created`, `family.invitation.cancelled`, `family.member.accepted/invited/revoked/role.updated`, `child.device.state.updated`, `child.enforcement.applied`, `child.policy.delivered`, `child.usage.observed`, `incident.created/acknowledged`, `geofence.created/disabled/updated`. Delete semantics today are soft (status flips + outbox event), never destructive remote removal by the client.

## 3. Render Backend and Firebase Capabilities

The Render backend (`guardian_backend/index.js`) exposes exactly three endpoints: `/api/provision-child`, `/api/redeem-child`, `/api/notify`. **No deletion, revocation-token, logout, or export endpoint exists.** `firebase/functions/src/index.ts` contains only the two provisioning `onCall` functions and three notification triggers — no deletion/export logic exists there either. The Render service account key (`/etc/secrets/serviceAccountKey.json` on Render) would permit server-side `admin.auth().deleteUser()` and Firestore recursive delete, but no such endpoint has been approved or implemented. Firebase Auth is reachable from Flutter via `FirebaseAuth.instance` (used through providers in `guardian_providers.dart`) — `signOut` and `currentUser.delete()` are client-available, but deleting a Firebase user is a live destructive action that must be gated behind re-authentication and must never be claimed complete without verification.

## 4. Existing Deletion-Adjacent Flows

The only existing destructive-adjacent operations are: `FamilyMembershipRepository.revokeMember` (owner-only via `FamilyPermission.revokeMembers`, soft-revokes the member and the member's devices locally, then enqueues `family.member.revoked` to the outbox — requires `account_uid` to be bound); `cancelInvitation` (same authorization pattern); `GuardianRepositories` device revoke/transfer outbox ops; `location_repository` geofence disable (soft); and `family_event_registry_repository.deleteFamilyEvents(familyId)` — the **only precedent for family-scoped local deletion**, which wipes `normalized_signals` and `family_events` for a family. The settings screen (`settings_screen.dart`) offers account session info, data sync, app preferences, language, and permissions — **no privacy or data-controls section exists**. `ReportExportService` (FS-009) already produces localized PDF/CSV report artefacts from a `FamilyReportSnapshot` — the honest-state pattern and the `share_plus` handoff can be reused for the Phase 4 family data export.

## 5. Data Inventory Table (per your required format)

Remote path column names the closest Firestore contract; "Remote path" = none for domains the app never syncs destructively.

| Data domain | Local table/path | Remote path | Owner | Roles allowed to read | Roles allowed to delete (client) | Exportable | Retention status | Evidence |
|---|---|---|---|---|---|---|---|---|
| Family | `families` | `families/{id}` doc | family owner | members | owner (rules L58: update/delete if owner) | yes (identity only) | local until purged | firestore.rules L55-58 |
| Members | `family_members` | `families/{id}/members/{mid}` | family | members (members-only reads) | owner | yes (name/role) | soft-revoked retained | family_authorization.dart |
| Invitations | `family_invitations` | `families/{id}/invitations/{iid}` | family | members | owner | no (ephemeral) | cancelled-at soft delete | membership repo L295 |
| Devices | `devices`, `child_device_states/policies` | `families/{id}/devices/{did}` | device owner parent | parents | parent (rules L156) | yes (identity) | soft-revoked retained | firestore.rules L152-156 |
| Notification tokens | `notification_tokens` | `families/{id}/devices/{did}/notification_tokens` | device owner | parents | parent | no (opaque) | stale tokens marked invalid | TokenRevocationService |
| Locations | `locations`, `location_points` | `families/{id}/locations/{lid}` | family | parents | parent (L208-211) | yes | retention key `privacyLocationRetention` | firestore.rules L208 |
| Geofences | `geofences` | `families/{id}/geofences/{gid}` | family | members | parent (L340) | yes | until disabled/deleted | rules L340 |
| Favorite places | `favorite_places` | `families/{id}/favorite_places/{pk}` | family | members | parent (L354) | yes | until deleted | rules L354 |
| Incidents | `incidents` | `families/{id}/incidents/{iid}` | family | parents | parent (L185) | yes (identity only) | notifyable states; audit retained | rules L185 |
| SOS | `sos_events`, `sos_recipients` | `families/{id}/sos/{sid}` | family | parents | parent (L196) | yes (identity only) | critical-safety retention | rules L196 |
| Web filtering | `web_hits/domains/category_rules/settings` | `families/{id}/web_*` | family | parents | parent | yes (aggregate) | period-scoped reports | FS-009 |
| App control | `app_policies/allowlist/block_history/usage_alert_settings` | `families/{id}/app_*` | family | parents | parent (L384-397) | yes (aggregate) | policy-versioned | rules L384-397 |
| Monitoring/screen time | `monitoring_*`, `child_usage_*`, `child_enforcement_*`, `child_exception_requests` | `families/{id}/monitoring_*` | family | parents | parent | yes (aggregate) | retention per policy | rules L403-429 |
| Modes & rules | `mode_*`, `family_rules`, `rule_execution_log`, `policy_overrides` | `families/{id}/mode_*`, `family_rules` | family | members (view) / parents (write) | parent | yes | until replaced | rules L432-444 |
| Tasks & rewards | `tasks`, `task_completion_log`, `family_rewards`, `reward_points_ledger`, `reward_pending_claims` | `families/{id}/tasks`, `reward_*` | family | members (own) / parents (all) | parent (task/reward), **ledger append-only** | yes (aggregate) | ledger append-only, never deleted | rules L310 |
| Event registry | `family_events`, `normalized_signals`, `source_event_tracking`, `ai_consent_scopes` | none (local aggregate) | family | parents | owner (precedent `deleteFamilyEvents`) | no | local retention | event_registry repo L140 |
| AI (frozen) | `ai_risk_states`, `ai_behavior_profiles`, `ai_insights`, `ai_detections`, `ai_copilot_suggestions`, `ai_policy_proposals` | none (local aggregate) | family | parents | none during Phase 4 | no | frozen — not expanded | your instruction |
| Couple Harmony | `couple_linking/routines/responsibilities/proposals/handovers` | none (local) | both partners | couple members | either partner | yes (joint) | local retention | FS-013 |
| Subscription & billing | `subscription_entitlements`, `subscription_usage_limits`, `billing_records` | none (local-only) | account holder | self | self | yes (audit only) | local audit | local-only entitlements |
| Outbox & sync | `outbox`, `policies` | outbox → Firestore writes | device | device | device (own queued ops) | no | flushed on sync | outbox_sync_executor |
| Notifications & identity | `notification_events`, `notification_settings`, `notification_tokens`, `app_identity` | `families/{id}/notification_events` (client delete: false) | family | parents | server only | no | until acknowledged/archived | rules L215 |

## 6. Explicit Findings That Shape the Contract (Phase B)

First, **no remote deletion contract exists today** — any Phase 4 remote deletion requires a new, authenticated, owner-only endpoint on the Render backend, which is outside the approved scope unless you approve it in Phase B; the honest default is local-only deletion with a documented "remote deletion requires the future endpoint" limitation. Second, **Firebase Auth deletion is the one remotely-destructive action callable from Flutter** (`currentUser.delete()`), and it must be gated by re-authentication (Firebase `reauthenticateWithCredential`), executed last in the flow, and never claimed complete without verifying the Auth user no longer exists. Third, the **outbox is the honest-state heart**: pending queued operations must be drained or explicitly abandoned (marked `abandoned`) rather than silently dropped; partial failures must surface as `partially_completed`. Fourth, **child and spouse isolation**: only the family owner may delete the family or remove members; children and spouses must be denied at `FamilyRuntimeContext.can()` before any UI action; the spouse's couple data is joint and requires both partners' records to be purged symmetrically. Fifth, **nothing claims success prematurely**: every flow needs the explicit state machine `not_requested → confirmation_required → in_progress → completed / partially_completed / failed / blocked_offline / blocked_backend`. Sixth, the existing `deleteFamilyEvents` precedent and `ReportExportService` pattern give us safe, approved building blocks for local purge and export.

**Stop point:** per your plan, I stop here and wait for your approval of this inventory before writing the Phase B deletion/export contract.
