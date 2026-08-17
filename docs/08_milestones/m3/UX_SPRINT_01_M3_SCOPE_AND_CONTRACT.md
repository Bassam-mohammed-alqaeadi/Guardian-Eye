# Experience Sprint 01 v2 — Milestone M3 Scope and Contract

**Project:** Guardian Eye Pro
**Milestone:** M3 — Child Context Vertical
**Baseline commit:** `442cf153e668033bb1b3f86a1c51e78231566f44` (master) — M2 GREEN checkpoint
**Author:** Manus AI
**Date:** August 13, 2026

This contract is derived from the repository's **actual** capabilities discovered in Phase B discovery. Every requirement below maps to an existing domain model, repository read, or provider. Nothing is invented for UI completeness.

## 1. Product Goal

The Child Context is the canonical parent-facing surface for a single child. From it, every future Guardian Eye Pro capability (screen time, bedtime, web filtering, location, AI monitoring, reports, device controls, alerts, geofencing, SOS) must eventually attach — never as a standalone navigation structure. M3 does not implement those capabilities; it establishes the **context** (who, what device, is it safe, what happened, what can I do) and the **extension surface** (a documented, non-dead list of future capability entry points clearly labeled as not yet available).

## 2. User Journey

```text
Dashboard (M2) → Child Overview card → "تفاصيل الطفل / Child Details"
→ /child/:familyId/:childId → Child Context Screen
```

The screen answers five questions in this hierarchy: who is this child; which device belongs to this child; is the child/device currently safe; what happened recently; what can the parent do next.

## 3. Child Identity Contract

The child **is** a `FamilyMember` whose `role == FamilyRole.child`. There is no separate child entity in this codebase — that is the authoritative model, reused directly. Authoritative fields displayed: `FamilyMember.id` (stable identifier, used as route parameter), `displayName`, `role` (rendered via `FamilyRole` semantics), `familyId`, member `status` (`FamilyMemberStatus` — a revoked/expired member is treated as not found/unauthorized, never shown as a normal child). No avatar field exists in the domain; the product-appropriate representation is the existing M2 pattern: `CircleAvatar` with the first character of `displayName`. **Do not invent avatar, nickname, age, or school fields.**

## 4. Device Contract

A child's device state is the `ChildDeviceState` (domain: `child_device_enforcement.dart`) whose `memberId` matches the child's `FamilyMember.id`, read via `ChildDeviceRepository.statesForFamily(familyId)` (SQLite, offline-first). Displayable honestly:

| Aspect | Source | Rendered as |
|---|---|---|
| Linked / unlinked | `ChildDeviceLifecycle.unlinked` or absence of any row for this member | 'noDevicesLinked' (existing key) |
| Lifecycle | `ChildDeviceState.lifecycle` (9 values) | 'device{lifecycle}' keys (existing M2 set) |
| Last synchronization | `ChildDeviceState.lastSyncAt` | 'lastSync' label + formatted timestamp (M3) |
| Synchronization freshness | presence/absence of `lastSyncAt`, queue count on dashboard | 'dataFresh' / 'syncUnavailable' (existing keys) |
| Device platform, online/offline presence, network presence | **NOT AVAILABLE** — not modeled | never rendered; 'deviceStatusUnavailable' if lifecycle unknown |

No "online" status is derived from the existence of a row. Lifecycle is the honest device state.

## 5. Safety Contract

`GuardianIncident` is family-scoped (`familyId`, `category`, `severity`, `confidence`, `status`, `observedAt`, `modelVersion` — no child identifier). Therefore the child context shows the family's recent unacknowledged incidents (reuse `recentIncidentsProvider` / `IncidentRepository.unacknowledgedIncidentsForFamily` from M2) with an honest label: these are family-level signals that concern this child's environment, **not** per-child verdicts. Rendered per incident: severity chip (`IncidentSeverity`), `SafetyCategory`, timestamp, acknowledged state (list content = unacknowledged by definition). The family-level safety signal card (M2) remains on the dashboard; the child context repeats the recent list in a concise form (up to 5, newest first). **No risk scores, no AI classifications, no fabricated severity math** — the incident's own `severity` field is displayed verbatim.

## 6. Activity Contract

Real activity data **exists**: `DailyUsageSummary` via `ChildDeviceRepository.usageForDeviceDay(deviceId, day: today)` (SQLite). M3 renders the minimal honest summary when a device is linked and summaries exist: total screen time for today (minutes), otherwise 'screenTimeUnavailable' ('غير متوفر اليوم' already exists). Per-app breakdowns exist in the same table (`target` field) — M3 shows only the total; breakdowns are the extension point. If the child has no linked device, the section is labeled unavailable, not zero-fabricated.

## 7. Action Contract

Executable in M3: view child identity; view device state; view safety state; view recent incidents; view today's screen-time total; return to dashboard (canonical back behavior). Extension points displayed as a clearly-separated, non-interactive list labeled 'قريباً / Coming soon': bedtime, web filtering, location, device controls, reports, SOS. **No dead routes are created for these** — they are text entries only. Permissions gate every real action through `FamilyRuntimeContext.can(FamilyPermission.viewChildStatus)` and the existing role/verification model; no new permission is invented.

## 8. Navigation Contract

New canonical route appended to `app_router.dart`:

```text
GET /child/:familyId/:childId   (name: childContext) → ChildContextScreen
```

| Scenario | Behavior |
|---|---|
| Valid child, authorized parent | Full child context |
| Unknown `childId` (no such member) | Not-found page (`/child/f-1/does-not-exist` test) |
| Child not in this family (`familyId` mismatch) | Not-found page |
| Member status ≠ active (revoked/expired) | Treated as not found |
| Unauthorized actor (unverified or lacks `viewChildStatus`) | Content hidden behind the existing disabled-action semantics; the screen itself still resolves with an honest "verification required" line from localization (actorVerificationRequired key) |
| Deleted/unlinked child | Member absence → not found; unlinked device → honest 'noDevicesLinked' inside a found-child screen |
| Offline child-device lifecycle | Rendered as the honest `ChildDeviceLifecycle.offline` label |

Back navigation uses the router stack (no custom pop stack); cold start via deep link to `/child/:f/:c` resolves through the same route and providers.

## 9. Offline Contract

All M3 reads are SQLite (`ChildDeviceRepository`, `IncidentRepository`, `FamilyMembershipRepository` via `familyRuntimeContextProvider`'s local reads). Honest states:

| Condition | Rendered |
|---|---|
| Data resolved | Actual values; `dataFresh` when no queued operations |
| Offline + cache exists | Same as resolved — local is canonical; sync-queue indicator present |
| No cache / empty local data | Explicit empty states (`noDevicesLinked`, `noRecentIncidents`, `screenTimeUnavailable`) |
| Genuine load failure | Error card with retry (M2 `_Failure` pattern) |
| Sync pending | `syncQueue` indicator from `GuardianDashboard.queuedOperations` |

No data is displayed as current when it is not.

## 10. Localization Contract

All strings via `AppLocalizations.of(context).t(key)`, Arabic + English maps in `app_localizations.dart`. M3 keys: `childContext`, `lastSyncAt`, `lastSyncNever`, `noRecentIncidents`, `activitySummary`, `comingSoon`, `verificationRequiredLine`, `memberNotActive` (+ plural-safe phrasing; existing M2 keys reused: `childDetails`, `todayScreenTime`, `screenTimeUnavailable`, `noDevicesLinked`, `device{lifecycle}`, `incidentsToday`, `dataFresh`, `syncQueue`, `actorVerificationRequired`). Dates via `DateFormat.yMMMd`/`jm` with `isRtl` locale direction.

## 11. Security Contract

The UI is never an authorization boundary. Authorization outcomes come exclusively from `FamilyRuntimeContext` (actor identity via `FamilyActorBindingService`, verification, role → `FamilyPermission.viewChildStatus`, family membership via `FamilyMembershipRepository` local reads). A parent can only reach children of their authorized family because every provider is family-scoped and SQLite rows are queried by `family_id`. Firestore rules, `FamilyAuthorization`, `PolicyEngine`, and all Phase 17 security artifacts are **not modified**. Backend remains authoritative; M3 adds no new authorization logic, it only consults the existing runtime context.

## 12. Architecture

```text
ChildContextScreen (presentation)
  ↓ ref.watch(childContextProvider(familyId, childId))
      FutureProvider.family joining:
  FamilyRuntimeContext        ← familyMembershipRepository, actor binding (local)
  ChildDeviceState (by memberId) ← childDeviceRepository.statesForFamily (SQLite)
  List<GuardianIncident>      ← incidentRepository.unacknowledgedIncidentsForFamily (SQLite)
  List<DailyUsageSummary>     ← childDeviceRepository.usageForDeviceDay (SQLite)
```

No Firestore reads from widgets. No new repository classes; joins happen in a provider composition. `childContextProvider` is unit-tested (state mapping, safety mapping, offline mapping, authorization outcomes). Existing providers are reused wherever possible: `childDeviceStatesProvider`, `recentIncidentsProvider`, `childUsageForTodayProvider` — `childContextProvider` aggregates them deterministically per child.

## 13. State Model (explicit, never collapsed into one spinner)

Loading → skeleton spinner; Loaded; Empty (found child, no device, no incidents, no usage — explicit "nothing recorded yet" labels); Error → retry card; Unauthorized/unverified → verification line + disabled actions; Not found → canonical not-found page; Offline cached → resolved (local canonical) with queue indicator.

## 14. Acceptance Criteria

1. `flutter analyze` = 0 issues.
2. All existing tests pass unchanged in semantics (89/89 baseline; M2 tests GREEN).
3. New M3 widget tests GREEN: loading, loaded child, loaded child with device+incidents, offline cached (deterministic local data), no device, no recent incidents, not found (unknown id + family mismatch), unauthorized/unverified actor, error+retry, safety severity displayed verbatim, Arabic RTL, English LTR, navigation from dashboard child button to `/child/:f/:c`, deep link resolves, invalid deep link → not-found.
4. New M3 unit tests GREEN: state mapping, safety mapping, offline mapping, authorization outcomes.
5. Firestore emulator 15/15 + Functions 2/2.
6. Security tests (actor binding, membership) GREEN.
7. No fabricated production data anywhere.
8. RTL/LTR both GREEN.
9. Documentation: contract (this file), gap audit, test evidence, completion report.
10. Git: M3 commits appended to master; no amend, no force-push; `phase17-stable-checkpoint` untouched; no push without explicit user approval.

## 15. Explicitly Deferred (classified in the gap audit)

Full screen-time engine (breakdown views), bedtime engine, web filtering, location tracking, geofencing, screen mirroring, one-way audio, full SOS workflow, subscription/payment, AI-model implementation, reporting engine, chat system, per-child incidents (requires a domain extension — BLOCKED until domain is extended, deferred).
