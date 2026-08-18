# Guardian Eye Pro — Deep Coherence Audit Report (CL-007)

**Date:** 2026-08-18 · **Branch:** `feature/design-system-integration` · **Scope:** every declared phase (Phase 0/1, M1–M9, FS-002, FS-001) compared against `MASTER_DEVELOPMENT_PLAN.md` and `MASTER_SCREEN_INDEX.md` · **Status:** complete, uncommitted · **Tests:** 274/274 green · **Analyze:** 0 errors

## 1. What was audited

The audit walked four comparison layers for every declared phase: the router versus the canonical routes in the master screen index; every screen file versus its declared screen ID and specification; every repository outbox call site versus its Firestore contract case; and every localization key referenced on screen versus the Arabic and English maps. Each layer was cross-checked for drift, orphans, dead ends, and integration gaps.

## 2. Problems found and fixed

| # | Finding | Severity | Fix applied |
|---|---------|----------|-------------|
| 1 | **Family Map broke navigation** — member tiles pushed `/location/:familyId/members/:id` and the history tile pushed `/location/:familyId/history`; neither route exists, so a real user would land on the 404 page. | Critical (user-facing break) | Tiles now push the canonical member-details route `/location/:familyId/:memberId` and per-member history `/location/:familyId/:memberId/history`. |
| 2 | **Location History ignored the selected member** — `LocationHistoryScreen` (LO-003) discarded its `memberId` parameter and fell back to a runtime-derived first member, so history could show the wrong child's route. | Critical (data correctness) | The screen is now scoped strictly to the member passed from the family map; its route comment updated to match the canonical path-parameter style. |
| 3 | **Four FS-001 routes deviated from the master plan** — create was `/geofences/create` (plan: `/new`), edit was `/geofences/:id` (plan: `/:geofenceId/edit`), onboarding was `/location/:familyId/permissions` (plan: `/onboard/location`), and child sharing was `/location/sharing/self` (plan: `/child/:familyId/:childId/location-sharing`). | Medium (doc/code drift) | All four realigned to the canonical plan routes; every push call site updated accordingly. The child sharing screen now receives real family/child identifiers from the route instead of resolving an empty-string family id. |
| 4 | **Missing bilingual localization keys** — `acknowledge` and `saveChanges` were used on screen but absent from both language maps, so the app would display raw key literals; additionally ~85 FS-001 keys had been lost during a local file revert. | Medium (RTL/UX integrity) | All ~90 keys were reconstructed with professional Arabic and English values and verified present in both maps. |
| 5 | **LO-014 Geofence Templates not implemented** — the plan declared inline presets (school hours, home range, prayer place) on the create form, but only a placeholder hint existed. | Medium (declared-vs-delivered gap) | Three `GeofenceTemplate` presets now pre-fill name, radius, alert profile, and anchor on the create form, with localized names. |
| 6 | **Two implemented screens were unrouted orphans** — `SafetyActionsScreen` (SOS send + manual outbox sync) and `ChildPolicyExperienceScreen` (child device context) existed but could never be reached. | Medium (dead code) | Registered at `/safety/actions/:familyId` and `/child/:familyId/:childId/device`, with honest entry points wired from the safety policies screen and the child context screen. |
| 7 | **No path from the dashboard into the new subsystems** — Web Filtering (FS-002) and Location (FS-001) had no entry point from any baseline screen, contradicting the Phase 2.5 dashboard-card contract. | Medium (integration gap) | The dashboard now exposes gated Web Protection and Family Map navigation groups (plus favorite places and alerts shortcuts), all authorized through `FamilyRuntimeContext.can()`. |
| 8 | **Stale documentation statuses** — `MASTER_SCREEN_INDEX.md` still marked all WF-002…WF-010 and LO-001…LO-015 rows as PLANNED. | Low (doc drift) | All implemented rows updated to COMPLETED; `CHANGE_LOG.md` extended with entry CL-007. |
| 9 | **Screen-ID comment drift** in `location_screens.dart` (LO-008…LO-013 comments were offset). | Low (maintainability) | Comments renumbered to the canonical plan order. |

## 3. Verification of declared phases

| Declared phase | Screens vs plan | Routes vs docs | Contract completeness | Result |
|----------------|-----------------|----------------|----------------------|--------|
| Phase 0/1 (design system, M1–M9) | 14/14 baseline screens routed | 14/14 match BX-001…BX-014 | intact | Coherent |
| FS-002 (Web Filtering) | 10/10 screens + 10 routes | exact match incl. WF-010 device route | 6 contract cases, outbox + real pull bridge | Coherent |
| FS-001 (Location & Geofencing) | 15/15 screens | 15/15 canonical after realignment | 5 contract cases, outbox + real pull bridge, rules spec | Coherent (was broken in 3 places — now fixed) |
| Cross-subsystem wiring | dashboard ↔ web + location; child context ↔ device experience; safety policies ↔ SOS | new routes registered | no new mock paths | Coherent (was a gap — now closed) |

Firestore contracts remain complete: 22 switch cases cover all 11 FS-002/FS-001 outbox operations plus the incident acknowledgment case fixed in CL-005; unknown operations fall to the documented safe `syncMetadata` path. No existing Firebase rules, schema, or Render backend was modified; only new collections were added per phase.

## 4. Test discipline

The widget test for the safety-policies screen was made scroll-aware after the new SOS entry card grew the list beyond the test viewport. Six new regression tests (`test/coherence_audit_test.dart`, CL-007) now lock in canonical route coverage across all subsystems, the LO-014 template preset contract, bilingual key presence for the audit-added keys, and the child self-scope identity guard.

**Final verification: 274/274 tests green (268 prior + 6 new), `flutter analyze` 0 errors, 0 warnings from new code.**

## 5. Pending by your rule

Nothing has been committed. The working tree holds 19 files (Phase 17 closure bundle, Phase 0/1, master docs, FS-002, CL-005, and the full FS-001 + CL-007 coherence sweep). The codebase is now coherent as one application: every declared screen is reachable, every declared route matches the plan, every mutation reaches its real Firestore path, and every visible string is translated in both languages.

Awaiting your explicit confirmation ("yes, commit") before pushing to `feature/design-system-integration`.
