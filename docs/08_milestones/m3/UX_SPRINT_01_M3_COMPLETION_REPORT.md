# UX SPRINT 01 — M3 COMPLETION REPORT

**Document type:** Milestone completion report (final of the four M3 documents)
**Scope:** Experience Sprint 01, Milestone M3 — Child Context Vertical
**Date:** 2026-08-13
**Author:** Manus AI

## 1. Git Record

| Item | Value |
|---|---|
| Baseline commit | `442cf15` — `feat(ux-m2): enrich parent dashboard with family identity, child overview, and safety signal` (pushed, origin/master) |
| Contract commit | `6627b3b` — `docs(ux-m3): define child context contract for parent experience vertical` (pre-implementation, committed before code) |
| Implementation commit | Pending user approval (proposed below) |
| Working tree before implementation commit | Clean of M3 deliverables except the staged deliverables; M2 history unamended; `phase17-stable-checkpoint` untouched |
| Branch | `master` (no force-push, no history rewrite) |

## 2. Files Changed

| File | Role |
|---|---|
| `lib/application/child_context_provider.dart` (new, 118 lines) | Data layer: `ChildContextKey` (familyId + memberId record), `childContextProvider` (FutureProvider.family), `ChildContextSnapshot` |
| `lib/presentation/screens/child_context_screen.dart` (new, 419 lines) | UI: `ChildContextScreen` + `_IdentityCard`, `_DeviceStateCard`, `_SafetyCard`, `_ActivityCard`, `_ComingSoonSection`, `_ErrorCard` |
| `lib/core/localization/app_localizations.dart` | ~30 new keys in Arabic and English (identity, lifecycle, safety, activity, coming-soon, error) |
| `lib/presentation/router/app_router.dart` | New canonical route `/child/:familyId/:childId` (name: `childContext`) |
| `lib/presentation/screens/dashboard_screen.dart` | `_ChildOverview.onOpenChild` retargeted to push the canonical child-context route |
| `test/m3_child_context_unit_test.dart` (new) | 8 unit tests for the data layer |
| `test/m3_child_context_test.dart` (new) | 12 widget tests for screen behavior and navigation |
| `docs/UX_SPRINT_01_M3_SCOPE_AND_CONTRACT.md` | Contract (committed first, `6627b3b`) |
| `docs/UX_SPRINT_01_M3_GAP_AUDIT.md` | Gap classification (this milestone) |
| `docs/UX_SPRINT_01_M3_TEST_EVIDENCE.md` | Test evidence (this milestone) |

## 3. Architecture

M3 adds no duplicate architecture. It reuses, in strict read-only fashion, the infrastructure discovered in Phase B:

- **Child identity** — a `FamilyMember` with `role == FamilyRole.child`; no separate child entity exists and none was invented.
- **Device state** — `ChildDeviceRepository.statesForFamily` and `usageForDeviceDay` (SQLite, offline-first, M1/M2 infrastructure).
- **Safety** — `recentIncidentsProvider` / `IncidentRepository.unacknowledgedIncidentsForFamily` (M2), family-scoped, displayed with honesty labels.
- **Authorization** — `FamilyRuntimeContext.can(FamilyPermission.viewChildStatus)`; no new permission was created, no domain logic was modified.
- **Navigation** — go_router canonical routes in `app_router.dart`; `childContext` appended without touching M1/M2 routes.

## 4. Data Flow

```text
/dashboard (M2) ── onOpenChild(child) ──> context.push('/child/{familyId}/{childId}')
   │
   childContextProvider(ChildContextKey(familyId, memberId))
   ├── FamilyRuntimeContext.childrenForFamily(familyId) → child member (or missing)
   ├── ChildDeviceRepository.statesForFamily(familyId) → device state by memberId
   ├── ChildDeviceRepository.usageForDeviceDay(deviceId, today) → screen-time total
   └── recentIncidentsProvider(familyId) → up to 5 newest unacknowledged incidents
   └── ChildContextSnapshot → ChildContextScreen (identity / device / safety / activity / coming-soon)
```

All reads are local (SQLite). Every absent datum surfaces an honest empty state; nothing is fabricated.

## 5. Navigation

`/child/:familyId/:childId` is the only new route. It deep-links (widget test 12), resolves through the standard go_router shell, and falls back to the screen's honest error page when the child is missing. No dead routes were created for the coming-soon capabilities, so the M1 dead-routes test remains GREEN.

## 6. Security

Domain, authorization, and security logic are untouched. The actor-binding and membership regression suites remain GREEN (14/14). Every executable action on the screen is gated through `FamilyRuntimeContext.can(viewChildStatus)`; an unverified actor sees verification lines and disabled affordances, never dead ends.

## 7. Offline Behavior

The provider joins only local SQLite reads; the cached `lastSyncAt` timestamp is displayed verbatim. When a device is unlinked or uncached, the screen states unavailability explicitly. Tests 1, 3, and 4 prove loading persistence, cached verbatim display, and honest empty states respectively.

## 8. Localization

All new copy ships in both language maps (Arabic first, consistent with M1/M2). `languageCode`-aware widget tests (10 and 11) verify both RTL and LTR surfaces end to end.

## 9. Accessibility

Material 3 `Card`/`ListTile` structure with Cairo typography; semantic labels come from localization keys; no custom gestures were introduced; coming-soon entries are explicitly non-interactive to prevent false affordances.

## 10. Tests — Exact Results

| Suite | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Full regression | `flutter test` | **109/109 PASS** |
| M3 unit tests | `test/m3_child_context_unit_test.dart` | **8/8 PASS** |
| M3 widget tests | `test/m3_child_context_test.dart` | **12/12 PASS** |
| Security regression | actor binding + membership | **14/14 PASS** |
| Firestore emulator | `./tool/run_firebase_emulator_tests.sh` | **15/15 PASS** |
| Functions emulator | same | **2/2 PASS** |

## 11. Non-Claims

- Per-app screen-time breakdowns, bedtime, web filtering, location, device controls, SOS, and periodic reports are **not implemented** in M3 (documented extension points).
- No online/offline presence, risk scores, avatars, nicknames, or fabricated severity math were added.
- M3 does not modify Firebase configuration, Firestore rules, Functions, or Phase 17/18 runtime architecture.

## 12. Next Milestone

M3 = GREEN pending final checkpoint push. No M4/P1 work has started; M3 stops at this checkpoint awaiting explicit user approval.
