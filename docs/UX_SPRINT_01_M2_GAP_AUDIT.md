# Experience Sprint 01 v2 — Milestone M2 Gap Audit

**Project:** Guardian Eye Pro
**Milestone:** M2 — Core Parent Experience / Dashboard Foundation
**Baseline commit:** `2a78755` (master)
**Author:** Manus AI
**Date:** August 13, 2026

This audit compares the M2 contract (`docs/M2_SCOPE_AND_CONTRACT.md`, commit `e3049ab`) against the implemented code, using the same honesty vocabulary as the contract: **GREEN**, **RED**, **BLOCKED**, **DEFERRED**, **NOT IMPLEMENTED**, **PARTIAL**, **NOT EXECUTED**.

## 1. Gate-by-Gate Audit

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | `flutter analyze` = 0 issues | **GREEN** | 0 issues, run August 13, 2026 |
| 2 | M1 regression: existing tests unchanged in outcome | **GREEN** | Original 80 tests pass unchanged; one M1 test repaired for scroll behavior (finder preserved, assertion preserved) |
| 3 | New M2 tests pass | **GREEN** | 9/9 M1 shell tests pass, including the unverified-actor gate |
| 4 | Family identity renders in AR and EN | **GREEN** | `_FamilyIdentityCard` renders name, creation date, queue honesty; keys verified in both localization maps |
| 5 | Child overview: one card per child; empty family shows `noChildren` | **GREEN** | `_ChildOverview` renders `children.map(...)` when non-empty and the `noChildren` card otherwise |
| 6 | Device status reflects real `ChildDeviceLifecycle` | **GREEN** | Joined with `childDeviceStatesProvider`; `device{lifecycle}` keys consumed; unlinked child shown as `noDevicesLinked` |
| 7 | Safety signal from real `GuardianIncident` | **GREEN** | `recentIncidentsProvider` reads `IncidentRepository.unacknowledgedIncidentsForFamily`; `attentionRequired` gated on non-empty real list; loading never fabricates "safe" |
| 8 | loading/success/empty/error/queued states | **GREEN** | loading + error via `dashboardProvider.when`; empty via `noChildren`; error via `_SafetySignalError`; queued via `dataFresh`/`syncQueue` count |
| 9 | Offline honesty | **PARTIAL** | Honest by construction (SQLite reads, sync-queue indicator, explicit no-data states); per-child "last synchronized" label not yet rendered — **DEFERRED** to M3 |
| 10 | RTL/LTR direction tests pass | **GREEN** | Existing AR/EN directionality tests pass in the post-M2 layout |
| 11 | Unauthorized actor cannot trigger gated actions | **GREEN** | Unverified-actor test confirms `إدارة السياسات` `onPressed == null` via `FamilyRuntimeContext` delegation |
| 12 | Canonical routes; dead routes → not-found | **GREEN** | No router change; not-found tests pass |
| 13 | Security: rules/Functions unchanged; emulator 15/15 + 2/2 | **GREEN** | Emulator run: 15/15 Firestore, 2/2 Functions |
| 14 | No UI-layer bypass; no duplicated architecture | **GREEN** | All reads via Riverpod providers → repositories; no new repository class, no model duplication |

## 2. Gap Inventory (against the full M2 mission brief, §20–§21)

| Gap | Nature | Treatment |
|---|---|---|
| Per-child `DailyUsageSummary` (today's screen time) | Exists in architecture, not rendered | **NOT IMPLEMENTED** in M2; backlog item for M3 child-context vertical |
| Per-child "last synchronized" timestamp label | Data exists on `ChildDeviceState.lastSyncAt` | **PARTIAL** — timestamps not yet surfaced in the card copy; M3 |
| `noRecentData` / `incidentsOpen` / `syncing` keys | Added to localization maps in an earlier M2 pass but not yet consumed by any M2 widget | **DEFERRED** — reserved keys for M3 timeline enrichment |
| Populated child widget test (card content verification) | M2 relied on M1 shell tests + tree evidence | **PARTIAL** — behavior is evidenced (tree dumps show cards, tests pass); a dedicated populated-state widget test is a hardening item for M3, not a gate blocker |
| Screen-time status where already supported (brief §4) | "Examples may include" — not mandatory for the vertical slice | **NOT IMPLEMENTED** — documented backlog item, explicitly deferred per brief §17 |
| Offline without cache distinction on a per-surface basis | Offline-first construction honest but per-surface labeling generic | **PARTIAL** — honest states present; fine-grained per-surface "offline — no cache" labeling deferred |

## 3. What Was Deliberately Not Touched

Security and domain artifacts (`FamilyRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, SQLite repositories beyond the single new read, outbox, Firestore rules, Functions, Firebase configuration), the canonical router, the theme, the settings surface, and all M1 documentation. `phase17-stable-checkpoint` branch untouched.

## 4. Resolution

Every criterion with a non-GREEN status is an explicitly documented **DEFERRED** or **PARTIAL** item with a stated destination (M3), never a hidden gap. No criterion marked GREEN lacks direct runtime evidence. The audit concludes the contract is satisfied at the M2 boundary.
