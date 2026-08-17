# M2 — Core Parent Experience / Dashboard Foundation: Scope and Contract

**Project:** Guardian Eye Pro
**Baseline:** `2a78755` (master) — M1 GREEN checkpoint (M1 commit `fb80079`)
**Author:** Manus AI
**Date:** August 13, 2026

This contract defines the exact M2 implementation surface against the audited Phase 17/18 architecture. It is internally consistent with the repository as of the baseline: every entity, repository, provider, and route referenced below exists today and will be reused, not duplicated.

## 1. Product Scope

M2 turns the family home into the first production-grade **Parent Experience vertical slice**. It connects the existing offline-first architecture (SQLite families/members/incidents/outbox) and the trusted-actor runtime context into one coherent surface: a parent opens the app and sees an honest snapshot of the family, each linked child, and the family's current safety signal — then navigates deterministically into any child's safety context through the M1 canonical router.

M2 does **not** redesign the dashboard chrome established by M1 (single settings entry, grouped `_NavGroup` navigation, product-voice labels). It enriches the family-home body with contextual family, child, and safety data, and defines how the family identity is carried to detail screens.

Explicitly **deferred** (documented backlog, not implemented): first-run onboarding redesign (M2 scope covers an already-bootstrapped family only; first-run was the M2 predecessor's separate stop line and belongs to its own milestone), AI risk scoring, real-time cloud streaming of child state, screen mirroring, geofencing, payments, chat, web filtering, full SOS infrastructure.

## 2. User Journey

The complete flow M2 must support, end to end, on the canonical router:

`App Shell (/)` → `Authentication / user context (session exists on device)` → `Family Context (first non-archived family; no-family state when absent)` → `Parent Dashboard (body: family identity, child cards, safety signal)` → `Child Context (/family/:familyId detail)` → `Child Safety / Status (/safety/device-status/:familyId, /safety/daily/:familyId)` → `Alerts summary (/timeline/:familyId)` — with `FamilyRuntimeContext` gating every gated action and the localized not-found page catching every dead path.

## 3. Screens in M2

| Screen | Route | M2 role |
|---|---|---|
| `DashboardScreen` | `/` | **Enriched.** Body gains three data sections: family identity, child overview cards, safety signal; retains M1 `_NavGroup` actions |
| `FamilyMembersScreen` | `/family/:familyId` | **Consumed, not modified** — canonical child/family detail destination |
| `ChildDeviceStatusScreen` | `/safety/device-status/:familyId` | **Consumed, not modified** — per-child device/safety context |
| `FamilyDailySafetyScreen` | `/safety/daily/:familyId` | **Consumed, not modified** |
| `FamilySafetyTimelineScreen` | `/timeline/:familyId` | **Consumed, not modified** — alerts summary destination |
| `SettingsScreen` | `/settings` | Unchanged |

No new screen files are created. M2 is a data-integration and state-handling milestone on the M1 shell.

## 4. State Contract (per section)

The dashboard body renders five observable states, each with localized copy and no fake data:

| State | Trigger | UI behavior |
|---|---|---|
| **loading** | `dashboardProvider` AsyncValue.loading | Skeleton/shimmer-free progress indicator within the body |
| **no family** | `family` is `null` (no family exists) | Explicit «لا توجد عائلة» / empty-family state with the existing `createFamily` entry — identical to M1's empty setup semantics |
| **success** | `family` non-null | Family identity row, one child card per `children` element, safety signal |
| **error** | `dashboardProvider` AsyncValue.error | Localized error message with a retry affordance that re-reads the provider |
| **offline / stale** | `queuedOperations > 0` | Sync-queue indicator showing the honest queued count (existing key `syncQueue`); sync availability distinguished via `outboxRemoteWriterProvider` readiness |

Child-card states: populated (name + device lifecycle), no children (key `noChildren`), device unknown (child with no linked device — shown explicitly as «لا يوجد جهاز مربوط»-style honest state, never omitted), device offline/restricted/suspended shown via lifecycle badge with localized text derived from `ChildDeviceLifecycle`.

Unauthorized state: an unverified actor sees the gated sections' actions disabled via `can(FamilyPermission.*)` — exactly as M1; M2 adds no new authorization mechanism.

## 5. Data Contracts

Only existing domain entities are used. No new models are created:

- `GuardianDashboard` (family, children, incidentsToday, queuedOperations) via `dashboardProvider` → `FamilyRepository.loadDashboard` (first non-archived family, child members, today's incident count, outbox queued count — all SQLite/offline-first).
- `FamilyRuntimeContext` via `familyRuntimeContextProvider` (actor, isVerified, allMembers, children, devices `List<ChildDeviceState>`, `can()`).
- `ChildDeviceState` / `ChildDeviceLifecycle` via `childDeviceStatesProvider` (keyed by familyId) — the per-child device status source of truth.
- `DailyUsageSummary` via `childUsageForTodayProvider` (keyed by deviceId) for today's screen-time status where available; absence is shown honestly («غير متوفر اليوم»).
- `GuardianIncident` via a new read on `incidentRepositoryProvider` — recent acknowledged/unacknowledged incidents today, used only for the safety signal (count already exists on the dashboard; M2 adds the per-child incident indicator from the same repository).
- `ChildDailySafetySnapshot` via `familyDailySafetyProvider` — referenced by `/safety/daily/:familyId`, not duplicated.

## 6. Repository and Provider Contracts

M2 consumes: `dashboardProvider`, `familyRuntimeContextProvider`, `familyRepositoryProvider`, `childDeviceRepositoryProvider`, `childDeviceStatesProvider`, `childUsageForTodayProvider`, `incidentRepositoryProvider`, `outboxRemoteWriterProvider`, `capabilityGatewayProvider`, `familyActorBindingProvider`. UI code reads providers only through Riverpod; no widget calls `GuardianDatabase` or `FirebaseFirestore` directly. Business logic stays in repositories/use cases. No new state-management framework, no global mutable state, no parallel implementations of existing services.

One genuinely new contract is added because it does not exist today: **recent incidents query**. `IncidentRepository` currently only records and acknowledges; it exposes no read stream. M2 adds a read method on the existing `IncidentRepository` (SQLite, same table) so the safety signal can reference real incidents. This is an extension, not a replacement; no rule or domain logic changes.

## 7. Navigation Contracts

All transitions use the M1 canonical router via `context.push`: family members `/family/:familyId`, child device status `/safety/device-status/:familyId`, daily safety `/safety/daily/:familyId`, timeline `/timeline/:familyId`, settings `/settings`. Deep links to unknown paths still resolve to the localized not-found page. The router itself remains unchanged; only its consumers gain richer entry points.

## 8. Localization Contracts

Every new user-visible string is added to the existing `AppLocalizations` AR/EN maps and accessed via `l10n.t('key')`. No hard-coded production text. New keys introduced by M2: `childOverview`, `familyIdentity`, `safetySignal`, `noDevicesLinked`, `deviceOnline`/`deviceOffline`/`deviceRestricted`/`deviceSuspended`/`deviceRecovering`, `incidentsOpen`, `safeToday`, `attentionRequired`, `noRecentData`, `retry`, `syncing`, `todayScreenTime`, `screenTimeUnavailable`, `childDetails`.

## 9. Offline Behavior

The dashboard is offline-first by construction: `loadDashboard` reads SQLite. States are reported honestly:

- **Online + fresh:** `syncQueue == 0` and writer ready — current data, «حديثة».
- **Offline with cache:** previously synchronized SQLite data shown with a «آخر مزامنة» label where `lastSyncAt` timestamps exist on `ChildDeviceState`; stale data is never presented as current.
- **Offline without cache:** for a child with no local device state, the card shows the honest «لا توجد بيانات» state, not a fabricated summary.
- **Sync pending:** `queuedOperations > 0` shows the sync-queue indicator; if the writer is unconfigured, sync is reported as unavailable (same semantics M1 established in the settings flow).

## 10. Security Boundaries

A parent can read only their own family's data, resolved through the existing first-family semantics (single local family database — the Phase 17/18 single-device multi-role model). The trusted actor binding remains the sole authorization source: `FamilyRuntimeContext.can()` gates every gated action. `IncidentRepository` reads are filtered by the loaded family's id. No Firestore rule changes, no authorization bypass, no cross-family exposure. If any future feature requires a rules change, the project's stop-document-minimum-change rule applies.

## 11. Design System, RTL/LTR, Accessibility

All new UI uses `AppTheme` (Cairo/Material3), existing card/button/tile components, and `AppColors` tokens. Directionality is delegated to `Directionality` (no manual left/right positioning); RTL/LTR verified by widget test. Accessibility: semantic labels on every actionable element, touch targets ≥ 48dp, hierarchy via the existing text theme, no critical information by color alone (lifecycle badges combine icon + localized text; safety signal combines a status label + icon + description).

## 12. Acceptance Criteria (GREEN/RED)

| # | Criterion | GREEN when |
|---|---|---|
| 1 | `flutter analyze` | 0 issues |
| 2 | M1 regression | 89/89 existing tests pass unchanged in outcome |
| 3 | New M2 tests | all pass |
| 4 | Family identity | Non-null family renders family identity row in Arabic and English |
| 5 | Child overview | One card per child; no-child family renders `noChildren` |
| 6 | Device status | Cards reflect real `ChildDeviceState.lifecycle`; unknown device shown honestly |
| 7 | Safety signal | Computed from real `GuardianIncident` severity presence or incidents count — never fabricated |
| 8 | States | loading/success/empty/error/queued each independently verified by widget test |
| 9 | Offline honesty | Stale/unavailable states labeled distinctly; no fake cache |
| 10 | RTL/LTR | Direction tests pass for Arabic and English |
| 11 | Unauthorized | Unverified actor cannot trigger gated actions (M1 behavior preserved) |
| 12 | Router | Detail navigation uses canonical routes; dead routes still land on not-found |
| 13 | Security | Firestore rules and Functions unchanged; emulator 15/15 + 2/2 |
| 14 | Boundaries | No UI-layer Firebase/SQLite bypass; no duplicated models/providers |

## 13. Final Status Vocabulary

All evidence will use explicit statuses: **GREEN**, **RED**, **BLOCKED**, **DEFERRED**, **NOT IMPLEMENTED**, **PARTIAL**, **NOT EXECUTED** (with reason). M2 is declared GREEN only when every applicable criterion above holds with direct runtime evidence.
