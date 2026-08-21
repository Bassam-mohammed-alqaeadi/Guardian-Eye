# PHASE 4C CLOSURE REPORT — Local Privacy Controls & Safe Local Purge

**Status: `CLOSED-CODE-VERIFIED`**
**Checkpoint commit: `d06780f` (local only — NOT pushed to GitHub, per user instruction)**
**Branch: `feature/design-system-integration` (never merged to master)**
**Date: 2026-08-21**

---

## 1. Scope Delivered (within the approved PHASE4_DELETION_EXPORT_CONTRACT)

Phase 4C is the **local purge only** phase. It deliberately does **not** implement remote deletion, data export, Firebase Auth deletion, or any future Phase 4 sub-phase. Everything delivered is device-local, offline, and verified only against the local SQLite engine and deterministic unit tests.

| Deliverable | File | Purpose |
|---|---|---|
| Purge engine | `lib/data/privacy_purge_repository.dart` | `LocalPurgeService` — transactional, single-family, fully-honest purge |
| State machine | `lib/application/privacy_purge_providers.dart` | `LocalPurgeNotifier` + `localPurgeNotifierForFamilyProvider` |
| UI | `lib/presentation/screens/privacy_controls_screen.dart` | Honest-state Privacy Controls screen with precondition banner, confirmation dialog, purge action card, remote-data boundary card |
| Entry point | `lib/presentation/screens/settings_screen.dart` + `lib/presentation/router/app_router.dart` | Settings Privacy tile → `/privacy-controls` |
| Localization | `lib/core/localization/app_localizations.dart` | 27 new AR + EN keys (RTL verified at build level) |
| Guard | `lib/core/database/guardian_database.dart` | `verifyBaseSchema()` promoted to production-visible; used as the `blockedMigration` precondition |
| Evidence | `test/privacy_purge_test.dart` | 16 behaviors against the real SQLite engine |

## 2. Engine behavior (CODE-VERIFIED)

The approved contract domains are enforced as constants — `purgedTables` (54), `frozenAiTables` (7), `retainedTables` (8) — with a const-disjointness test proving no table is ever both purged and retained/frozen.

- **Purge scope**: every purged table is deleted inside **one SQLite transaction** keyed by `family_id = ?`; a single failing table rolls back the whole operation and reports an honest `partiallyCompleted` outcome with the exact failed tables.
- **Device-scoped tables** (`app_identity`, `notification_settings`) have no `family_id`: they are wiped wholesale (the local device itself is the purge surface) — reported honestly as `device_scoped`.
- **Outbox is never dropped**: pending rows are marked `abandoned` with `last_error = local_data_deleted` (the outbox has no family column; abandoned rows can never sync because their targets are being deleted).
- **Billing sweep**: `billing_records` older than 90 days are removed; the recent rows are retained per the contract.
- **FK-safe retained-reference skips**: `tasks`, `family_rules`, and `family_rewards` rows that are still referenced by retained append-only logs (`task_completion_log`, `rule_execution_log`, `reward_pending_claims`) are **skipped** — never silently kept and never orphaned. Each skip is reported with `skippedRows` count and `retentionReason = referenced_by_retained_logs`. This surfaced a real design conflict during testing (retained audit logs hold foreign keys into purged configuration tables) and was resolved honestly.
- **Authorization gates**: unverified actor → `blockedPermission`; child role → blocked (children never delete family data); revoked/invited membership → blocked; **actor-family binding** — a member bound to a different family cannot purge that family's data (`actor.familyId` must match the requested `familyId`).
- **Migration precondition**: `verifyBaseSchema()` (nine foundational tables + indexes) must pass before any row is touched; corrupt/legacy DBs short-circuit to `blockedMigration` with zero mutations.

## 3. UI (CODE-VERIFIED, no device validation)

The Privacy Controls screen implements the honest state machine: precondition check → ready confirmation → running → `completed`/`partiallyCompleted`/`blocked*` outcomes, each rendered with its real state and reason. A precondition banner explains when purge is unavailable. No false-success state exists. All copy is covered by the 27 new AR/EN keys.

## 4. Verification evidence

| Check | Result | Status |
|---|---|---|
| Focused purge tests (16 behaviors: purged/retained/frozen domains, outbox abandon, billing sweep, 6 auth gates, transactional rollback, unhealthy schema, idempotency, artifact honesty, const disjointness) | 16/16 green | CODE-VERIFIED |
| Full Flutter regression suite | 478/478 green (baseline 462 + 16 new) | CODE-VERIFIED |
| `flutter analyze` on all 8 changed files | 0 errors, 0 warnings, 1 pre-existing unrelated info lint | CODE-VERIFIED |
| Backend (Render) | Untouched this phase | N/A |
| Firebase/Firestore | Untouched this phase | N/A |
| Real-device / emulator | Not performed (headless engine only) | NOT VALIDATED |
| Production | Not deployed, not modified | N/A |

## 5. Issues found and fixed during testing

1. **Cross-family gate gap**: the gate compared the requested family id but not the actor's family membership. An actor bound to family A could pass the gate while requesting family A's purge — fixed by binding `actor.familyId == familyId` (cross-family purge now blocked, `blockedPermission`).
2. **Retained-audit FK conflict**: `task_completion_log`, `rule_execution_log` reference `tasks`/`family_rules`; purging configuration tables while retaining their audit logs would fail foreign-key constraints. Fixed with honest referenced-row skips (see §2).
3. **Parameter-count bug** (found while fixing #2): a delete with `keptIds.isEmpty` passed a duplicated `familyId` bind argument — fixed with a conditional `whereArgs` list.
4. **`families` row removed from purge list**: deleting the family row itself breaks every FK reference and contradicts the contract (purge removes family data, not the family entity); the family row is retained.
5. **Device-scoped domain mapping**: `app_identity`/`notification_settings` purges previously referenced a nonexistent `family_id` column (runtime failure → `partiallyCompleted`); now wiped wholesale as device-scoped tables.

## 6. Honest verification boundaries

- **CODE-VERIFIED**: everything above runs locally against real SQLite via `flutter test`.
- **DEVICE-VERIFIED / PRODUCTION-VERIFIED**: NOT performed. The UI state machine, purge UX on a real phone, and behavior under concurrent device usage remain unvalidated on hardware.
- **REMOTE BEHAVIOR**: Phase 4C never touches remote data; no push or deployment has occurred, per user instruction.

## 7. Next approved step

Awaiting user direction. Candidate next phases (not started): Phase 4D (local export), Phase 4E (remote deletion per the approved contract), or the next feature phase in the master plan.
