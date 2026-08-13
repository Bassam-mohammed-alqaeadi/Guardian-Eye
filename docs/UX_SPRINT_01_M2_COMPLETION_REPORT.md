# Experience Sprint 01 v2 — Milestone M2 Completion Report

**Project:** Guardian Eye Pro
**Milestone:** M2 — Core Parent Experience / Dashboard Foundation
**Baseline commit:** `2a78755` (master) — M1 GREEN checkpoint (M1 commits `fb80079`, `2a78755`; M2 contract `e3049ab`)
**Author:** Manus AI
**Date:** August 13, 2026
**Status:** M2 GREEN (gates evidenced directly; see `UX_SPRINT_01_M2_TEST_EVIDENCE.md`)

---

## 1. Executive Summary

M2 turned the M1 family-home shell into the first production-grade **Parent Experience vertical slice**. The dashboard body now presents three honest, real-data sections on top of the M1 chrome: **family identity** (name, creation date, today's counts and sync-queue honesty), a **safety signal** computed from real unacknowledged incidents in the local SQLite incident store, and a **child overview** that joins every family child with its real `ChildDeviceState.lifecycle` — an unlinked child is shown explicitly as having no device attached, never silently omitted. Navigation into child and safety contexts flows exclusively through the M1 canonical router, and every gated action remains delegated to `FamilyRuntimeContext.can()` with no local role check introduced.

One genuinely new data contract was added — a recent-incidents read on the existing `IncidentRepository` — because the repository previously only recorded and acknowledged incidents and exposed no read surface for the safety signal. This is an extension of an existing repository, not a replacement, and it required no rule, domain, or authorization change.

## 2. What Was Built

### 2.1 Recent-incidents read (`lib/data/safety_repositories.dart`) — EXTENDED

`IncidentRepository` gained `recentIncidentsForFamily(String familyId)`, which queries the same local incidents table filtered by the loaded family id. No schema, rule, or business-logic change; no new repository was created, and no existing method was modified in a way that affects consumers.

### 2.2 Recent-incidents provider (`lib/application/guardian_providers.dart`) — EXTENDED

`recentIncidentsProvider` — a `FutureProvider.family<List<GuardianIncident>, String>(familyId)` — wires the dashboard's safety signal through the standard `UI → provider → repository → SQLite` path. It sits next to the existing `childDeviceStatesProvider`, `childUsageForTodayProvider`, and `familyDailySafetyProvider` family providers and consumes only `incidentRepositoryProvider`.

### 2.3 Localization (`lib/core/localization/app_localizations.dart`) — EXTENDED

Both AR and EN maps gained the M2 user-visible keys: `familyIdentity`, `childOverview`, `safetySignal`, `createdFamily`, `incidentsToday`, `syncQueue`, `offlineFirst`, `actorVerificationRequired`, `safeToday`, `attentionRequired`, `noDevicesLinked`, `dataFresh`, `noChildren` plus nine lifecycle badge keys (`deviceUnlinked` … `deviceRecovering`) already present in the localization system and now actively consumed by the child overview. Every new string was added to both languages; no existing key was removed or altered.

### 2.4 Enriched dashboard (`lib/presentation/screens/dashboard_screen.dart`) — MODIFIED

The `_Dashboard` body now watches `childDeviceStatesProvider(familyId)` and `recentIncidentsProvider(familyId)` and renders four new private widgets, all plain `StatelessWidget`s receiving their data through constructor parameters (no widget calls `GuardianDatabase` or `FirebaseFirestore` directly; business logic remains in repositories):

| Widget | Responsibility | States handled |
|---|---|---|
| `_FamilyIdentityCard` | Family name, creation date, honest sync-queue indicator (`dataFresh` when `queuedOperations == 0`) | success |
| `_SafetySignalCard` | Real unacknowledged incidents → `safeToday` / `attentionRequired` with icon and localized count; trailing canonical entry into `/timeline/:familyId` gated by `viewSafetyTimeline` | success, attention, loading (signal withheld until data exists) |
| `_SafetySignalError` | Signal load failure with a retry that invalidates the read providers | error |
| `_ChildOverview` | One card per child joined with its real `ChildDeviceState.lifecycle`; empty family shows `noChildren`; unlinked child shown as `noDevicesLinked` | success, empty, device-unknown |

The M1 metric row, `_NavGroup` navigation groups, verification banner, and the family-setup empty state are unchanged in behavior; the legacy inline children section that duplicated `_ChildOverview` semantics was removed in favor of the joined child/device cards (this is the one deletion in the file — a duplicate, not a new capability).

## 3. Data Flow

```
UI (dashboard widgets)
 → ref.watch(childDeviceStatesProvider / recentIncidentsProvider / dashboardProvider)
 → incidentRepositoryProvider / childDeviceRepositoryProvider / familyRepositoryProvider
 → GuardianDatabase (SQLite) — incidents table, child device states, families/members
```

`dashboardProvider` continues to drive loading/success/error at the screen level. The safety signal is intentionally withheld until at least one of its two data sources resolves (`valueOrNull != null`) — a loading signal would fabricate a "safe today" state from absence, which violates the honest-data rule. When either source resolves with data, the signal reflects reality; when both are in error, `_SafetySignalError` offers a localized retry.

## 4. Offline Behavior

The dashboard is offline-first by construction because every source reads SQLite. The sync-queue indicator renders `dataFresh` (`حديثة`) when `queuedOperations == 0` and the honest queued count otherwise; sync availability keeps the M1 settings-flow semantics (unconfigured writer → sync unavailable messaging). A child without a local device state shows the `noDevicesLinked` honest state — never a fabricated summary. **Known limitation (documented, not pretended solved):** per-child `lastSyncAt` timestamps exist on `ChildDeviceState` but the dashboard card does not yet display a "last synchronized" label; that belongs to M3's timeline enrichment, not M2.

## 5. Localization and Accessibility

Arabic RTL and English LTR are verified by the existing M1 shell tests (directionality delegated to `Directionality` at the shell level; no manual left/right positioning). Actionable elements carry semantic labels; lifecycle badges combine icon + localized text so no critical information is conveyed by color alone; the safety signal combines status label + icon + description.

## 6. Boundary Compliance

No change touched `FamilyRuntimeContext`, `DeviceRuntimeContext`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, SQLite repositories beyond the single new read method, outbox, Firestore rules, Functions, or Firebase configuration. The router, theme, and settings surface were not modified. Temporary debug markers injected during diagnosis were fully removed before the gate.

## 7. Tests Executed (exact results)

| Gate | Result |
|---|---|
| `flutter analyze` | **0 issues** |
| `flutter test` | **89/89 pass** (original 80 unchanged in outcome + 9 M1 shell tests; one M1 test was repaired — not weakened — to scroll to a button that moved below the fold after the new cards, see test evidence) |
| Firestore emulator | **15/15 pass** |
| Functions emulator | **2/2 pass** |
| M1 regression | **GREEN** — identical outcomes, no weakened assertions |

## 8. Known Limitations and Deferred Work

- `DailyUsageSummary` per-child screen-time badges are **NOT IMPLEMENTED** in M2 — the provider exists but the dashboard does not render it yet; it belongs to the child-context vertical (M3).
- Per-child "last synchronized" label — **DEFERRED** to M3.
- First-run onboarding redesign — **DEFERRED** (explicitly out of M2 scope per the contract).
- Real-time cloud streaming of child state — **DEFERRED**.

## 9. Final Status

**M2 STATUS: GREEN.** All fourteen acceptance criteria of `docs/M2_SCOPE_AND_CONTRACT.md` hold with direct runtime evidence recorded in `UX_SPRINT_01_M2_TEST_EVIDENCE.md`. Next milestone: M3 (child-context vertical + screen-time visibility), upon explicit user instruction only.
