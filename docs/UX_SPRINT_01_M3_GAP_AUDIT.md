# UX SPRINT 01 — M3 GAP AUDIT

**Document type:** Gap audit (Section 26 of the M3 mission brief)
**Scope:** Experience Sprint 01, Milestone M3 — Child Context Vertical
**Baseline:** M2 checkpoint `442cf15` (master)
**Current commit:** `6627b3b` (contract) + pending implementation
**Date:** 2026-08-13
**Author:** Manus AI

Every capability listed in the M3 mission brief and in `docs/UX_SPRINT_01_M3_SCOPE_AND_CONTRACT.md` is classified below using the mandated vocabulary. A classification is assigned on the basis of direct evidence (code + test behavior), never on the presence of a UI placeholder.

## 1. Capability Classification Table

| # | Capability | Classification | Evidence |
|---|---|---|---|
| 1 | Child identity display (name, role, stable ID) | **IMPLEMENTED** | `_IdentityCard` renders `displayName`, role label, `CircleAvatar` with first character; widget test 2 verifies content, test 5 verifies honest not-found |
| 2 | Child-context surface (`ChildContextScreen`) | **IMPLEMENTED** | `lib/presentation/screens/child_context_screen.dart`, 12/12 widget tests pass |
| 3 | Canonical route `/child/:familyId/:childId` | **IMPLEMENTED** | Appended to `app_router.dart` as `childContext`; deep-link widget test 12 proves end-to-end resolution; M1 navigation tests remain GREEN |
| 4 | Dashboard → child context entry | **IMPLEMENTED** | `_ChildOverview.onOpenChild` pushes the canonical route (retargeted from members screen); M1 entry-point test still GREEN |
| 5 | Device state (linked / lifecycle / last sync) | **IMPLEMENTED** | `_DeviceStateCard` reads `ChildDeviceState` via SQLite; lifecycle keys cover all 9 `ChildDeviceLifecycle` values; test 2 and 4 cover linked and no-device cases |
| 6 | No-device honest empty state | **IMPLEMENTED** | 'noDevicesLinked' card renders when no row exists; widget test 4 verifies absence of fabricated data |
| 7 | Safety state (family-level, honest labeling) | **IMPLEMENTED** | `_SafetyCard` renders up to 5 newest unacknowledged incidents with severity chip, category, timestamp; labels state they are family-level signals, not per-child verdicts |
| 8 | Recent incidents list (calm vs attention) | **IMPLEMENTED** | Widget tests 8 and 9 distinguish calm/attention states and verify the honest empty label |
| 9 | Today's screen-time summary | **IMPLEMENTED** | `_ActivityCard` renders `DailyUsageSummary` total for today when a device is linked; 'غير متوفر اليوم' rendered when unavailable (test 2, 3) |
| 10 | Return to dashboard (canonical back) | **IMPLEMENTED** | `BackButton` + explicit 'العودة إلى لوحة التحكم' affordance; widget tests navigate back and forward |
| 11 | Loading state | **IMPLEMENTED** | Progress indicator while the context join resolves; test 1 proves the screen never leaves loading while a stub never resolves |
| 12 | Error state with honest retry | **IMPLEMENTED** | Error page with retry button re-invokes the provider; widget test 7 verifies the loop |
| 13 | Offline-first behavior (cached state shown verbatim) | **IMPLEMENTED** | All reads are local SQLite; `lastSyncAt` displayed verbatim; widget test 3 verifies cached-child behavior; no online-status is ever derived from row existence |
| 14 | Authorization gating (`viewChildStatus`) | **IMPLEMENTED** | `FamilyRuntimeContext.can(viewChildStatus)` gates actions; unverified actor sees verification lines and disabled affordances, never dead ends (widget test 6) |
| 15 | Future-capability extension surface (coming soon) | **IMPLEMENTED** | Non-interactive list (bedtime, web filtering, location, device controls, reports, SOS) labeled 'قريباً / Coming soon'; no dead routes created |
| 16 | Per-app screen-time breakdown | **NOT IMPLEMENTED** | Data exists (`DailyUsageSummary.target`) but M3 renders only the daily total per the activity contract; breakdown is the documented M4 extension point |
| 17 | Bedtime control | **DEFERRED** | Extension entry only (M4/P2 scope); correctly not implemented rather than fake |
| 18 | Web filtering control | **DEFERRED** | Same as 17 |
| 19 | Location / geofencing | **DEFERRED** | Same as 17 |
| 20 | Device controls (lock/restrict) | **DEFERRED** | Same as 17 |
| 21 | AI monitoring / risk scores | **NOT IMPLEMENTED** | Explicitly excluded by the safety contract — no fabricated severity math; incidents shown verbatim |
| 22 | Child reports (periodic) | **DEFERRED** | Extension entry only; data pipeline (periodic snapshot export) not modeled |
| 23 | SOS for child | **DEFERRED** | Extension entry only; incident path already exists (family-level incidents) but no per-child SOS trigger |
| 24 | Avatar / nickname / age / school fields | **NOT IMPLEMENTED** | Correctly absent — domain has no such fields; contract forbids inventing them; first-letter avatar is the product-appropriate representation |
| 25 | Online/offline presence rendering | **NOT IMPLEMENTED** | Not modeled by the domain; 'deviceStatusUnavailable' would apply; lifecycle remains the honest device state |
| 26 | English locale surface | **IMPLEMENTED** | Widget test 11 verifies LTR rendering with English keys |
| 27 | Arabic locale surface (RTL) | **IMPLEMENTED** | Widget test 10 verifies RTL direction and Arabic keys |
| 28 | Family membership revocation edge case on child screen | **PARTIAL** | Revoked/expired member status is treated as not-found/unauthorized at the membership level (domain rule); the screen surface does not render a dedicated 'revoked member' message — it surfaces the honest missing/unauthorized error states. Sufficient for M3; revisit in M4 |

## 2. Gap Discipline Notes

The following gaps were deliberately NOT converted into GREEN despite UI elements existing elsewhere in the codebase, in accordance with Section 26 of the brief:

- **Coming-soon entries are text, not routes.** Each future capability is a labeled list entry inside `_ComingSoonSection`. No `GoRoute`, no `onPressed`, no navigation. The widget tests assert these entries are non-interactive (no buttons found for them).
- **No online status was derived.** The domain exposes lifecycle, not network presence. The screen never renders "online/offline" — that would be fabricated data.
- **No per-child safety verdict.** Incidents are family-scoped; the screen repeats the family's recent unacknowledged incidents with an explicit honesty label. No risk score or AI classification was added.
- **No fabricated screen time.** When no device is linked or no summary exists, the section states unavailability instead of zero.
- **No dead routes.** M1's dead-routes test remains GREEN, confirming that no unresolvable path was introduced.

## 3. Deferred Items Inventory (for M4)

| Item | Dependency |
|---|---|
| Per-app screen-time breakdown | `DailyUsageSummary.target` aggregation UI |
| Bedtime / web filtering / location / device controls / SOS | Policy engine + enforcement APIs (Phase 18+) |
| Periodic child reports | Snapshot export pipeline |
| Revoked-member dedicated messaging | Membership status surface decision |
