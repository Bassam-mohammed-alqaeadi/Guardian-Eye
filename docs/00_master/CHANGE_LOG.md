# CHANGE LOG — Impact-Analysis Register

**Authoritative register of every meaningful change.** One entry per change; newest first. The impact-analysis template below is mandatory before implementation for every meaningful code or product change.

## Template (fill per change)

```text
CHANGE-ID:            · <unique id>
REQUEST:              · <what was asked / why>
CURRENT PHASE:        · <phase at time of change>
AFFECTED FEATURE:     · <subsystem(s)>
AFFECTED SCREENS:     · <screen IDs>
AFFECTED FILES:       · <code + doc files>
AFFECTED DATA:        · <models/providers touched>
AFFECTED BACKEND:     · <contract changes — usually: NONE>
AFFECTED EVENTS:      · <GuardianEvent types read/emitted>
AFFECTED SECURITY:    · <authorization/privacy surface>
AFFECTED CURRENT PHASE:      · <does it alter in-flight work?>
AFFECTED PREVIOUS FOUNDATION: · <does it touch M1–M9 / Phase 17 / 18?>
AFFECTED FUTURE PHASES:      · <which later phases consume this?>
MIGRATION REQUIRED:   · <data/migration steps>
TESTS REQUIRED:       · <new/updated tests>
DOCS REQUIRED:        · <docs touched>
ROLLBACK:             · <how to undo>
STATUS:               · proposed / approved / merged
```

## Entries

### CL-001 — Master development constitution established
- **REQUEST:** User directive (pasted_content_6.txt): replace all prior phase planning with a single current-to-future execution blueprint covering all ~150 screens, 16 subsystems, and the Guardian AI system, executable by any AI model.
- **CURRENT PHASE:** UX Transformation — Screen System Buildout (baseline 5a2bf25).
- **AFFECTED FEATURE:** All (documentation scope).
- **AFFECTED SCREENS:** All ~150 (registry created; no UI changed).
- **AFFECTED FILES:** docs/00_master/ (6 new files) + docs/00_master/INDEX.md update.
- **AFFECTED DATA:** none.
- **AFFECTED BACKEND:** NONE.
- **AFFECTED EVENTS:** none.
- **AFFECTED SECURITY:** none (documents governance; enforces Phase 17 law).
- **AFFECTED CURRENT PHASE:** defines it (FS-002 next).
- **AFFECTED PREVIOUS FOUNDATION:** references only; declares M1–M9 / Phase 17 / 18 immutable.
- **AFFECTED FUTURE PHASES:** all (orders them).
- **MIGRATION REQUIRED:** none.
- **TESTS REQUIRED:** none (docs only).
- **DOCS REQUIRED:** this file; INDEX.md.
- **ROLLBACK:** delete the six new files; revert INDEX.md.
- **STATUS:** merged (docs committed to feature/design-system-integration).

### CL-002 — Gap-closure expansion of all subsystems (documentation revision)

```text
CHANGE-ID:            · CL-002
REQUEST:              · User directive: complete the services/screens of every subsystem, close all functional gaps of the FS-002 type (4→10), and update the master documents — every addition must serve a real purpose.
CURRENT PHASE:        · Phase 2 — FS-002 Web Filtering (in-flight specs updated in place)
AFFECTED FEATURE:     · All 16 subsystems + Guardian AI + Commercial
AFFECTED SCREENS:     · +31 FS gap screens (WF-005…010, AC-005…008, SC-007…009, MD-009/010, SO-007/008, AS-008/009, AU-013/014, RP-006/007, CH-003/004, RL-006/007, CM-004/005, CO-005…007, PD-006/007, DL-010/011, ST-004/005, LO-013…015), +3 AI (AI-011…013), +1 commercial (CMR-005)
AFFECTED FILES:       · docs/00_master/*.md (plan, matrix, index, navigation map, change log)
AFFECTED DATA:        · NONE — screens consume existing providers
AFFECTED BACKEND:     · NONE
AFFECTED EVENTS:      · Future consumers documented only; no new event types defined yet
AFFECTED SECURITY:    · All new screens authorize via FamilyRuntimeContext.can(); child-vertical screens are self-scope fail-closed
AFFECTED CURRENT PHASE:      · FS-002 scope now WF-001…WF-010 (10 screens, test floor ≥267)
AFFECTED PREVIOUS FOUNDATION: · NONE
AFFECTED FUTURE PHASES:      · All; additions are the intended complete-system targets
MIGRATION REQUIRED:   · NONE (documentation only)
TESTS REQUIRED:       · New tests per screen when implemented; no test impact from this doc change
DOCS REQUIRED:        · MASTER_DEVELOPMENT_PLAN.md, MASTER_FEATURE_MATRIX.md, MASTER_SCREEN_INDEX.md, MASTER_NAVIGATION_MAP.md, CHANGE_LOG.md
ROLLBACK:             · Documentation only — no code to revert
STATUS:               · approved (user directive)
```

### CL-003 — FS-002 Web Filtering implemented (WF-001…WF-010)
- **REQUEST:** User directive: implement the complete FS-002 Web Filtering subsystem (10 screens) with verified integration, icons/assets within the design system.
- **CURRENT PHASE:** FS-002 implementation (declared in CL-002).
- **AFFECTED FEATURE:** FS-002 Web Filtering.
- **AFFECTED SCREENS:** WF-001…WF-010 (routes `/safety/web/:fid[/categories|/blocklist|/settings|/history|/history/:hid|/history/:hid/allow|/allowlist|/child/:cid|/blocked/:hid]`).
- **AFFECTED FILES:** `lib/data/web_filter_repository.dart` (new), `lib/domain/web_filtering/` (new: categories + data model), `lib/presentation/screens/web_filter_screens.dart` (new), `web_filter_management_screens.dart` (new), `web_filter_child_screens.dart` (new), `lib/core/database/guardian_database.dart` (migration v15), `lib/application/guardian_providers.dart` (4 new providers), `lib/presentation/router/app_router.dart` (10 routes), `lib/core/localization/app_localizations.dart` (~96 AR/EN keys), `docs/06_ux/02_screens/INDEX.md` (WF table).
- **AFFECTED DATA:** SQLite tables `web_filter_hits`, `web_filter_domains`, `web_filter_category_rules`, `web_filter_settings`; 4 new Riverpod providers (`webHitsProvider`, `webDomainsProvider`, `webSettingsProvider`, `webFilterRepositoryProvider`).
- **AFFECTED BACKEND:** NONE — local-first via the existing outbox/sync semantics; no Firestore schema or rules changed.
- **AFFECTED EVENTS:** none new.
- **AFFECTED SECURITY:** all screens gated by `FamilyRuntimeContext.can(viewPolicies/managePolicies)`; unauthorized surfaces show honest `GuardianStateView`; child-facing blocked page (WF-010) is fail-closed self-scope.
- **AFFECTED CURRENT PHASE:** FS-002 implemented per CL-002 test floor.
- **AFFECTED PREVIOUS FOUNDATION:** NONE (M1–M9/Phase 17-18 untouched).
- **AFFECTED FUTURE PHASES:** FS-003+ (web hits feed L3 behavior analytics); AI copilot consumes `webHitsProvider`.
- **MIGRATION REQUIRED:** SQLite migration v15 (auto on next DB open; no data loss).
- **TESTS REQUIRED:** baseline unchanged — 247/247 green; `flutter analyze` 0 errors / 0 warnings (info-only lints 166 → 118).
- **DOCS REQUIRED:** INDEX.md WF table added (this entry).
- **ROLLBACK:** `git revert` of this commit; DB migration is additive-only (safe to keep).
- **STATUS:** approved (user directive)

### CL-004 — FS-002 Web Filtering: real Firebase/Firestore backend integration

```text
CHANGE-ID:            · CL-004
REQUEST:              · User directive: complete ALL backend work for FS-002 — real Frontend + Backend +
                        Firebase integration. No Mock, no partial. Close the phase completely.
CURRENT PHASE:        · FS-002 closure (after CL-003 frontend)
AFFECTED FEATURE:     · FS-002 Web Filtering
AFFECTED SCREENS:     · WF-001 (dashboard pull-to-refresh now performs a real remote pull)
AFFECTED FILES:       · lib/data/firestore_contracts.dart (web.hit / web.domain / web.domain.removal /
                        web.category / web.setting / web.hit.overridden switch cases + FirestorePaths for
                        web_hits, web_domains, web_category_rules, web_settings, web_policy)
                      · lib/data/web_filter_repository.dart (outbox payloads now match contract keys;
                        setSetting/removeDomain/setDomainEnabled enqueue outbox; sync-aware markOverridden;
                        public database getter)
                      · lib/data/web_filter_remote_service.dart (NEW — WebPolicyRemoteReader,
                        FirestoreWebPolicyRemoteReader, RemoteWebPolicy/Hit/Domain/CategoryRule,
                        WebPolicySyncApplier, WebFilterPullService/WebPullResult)
                      · lib/application/guardian_providers.dart (webPolicyRemoteReaderProvider,
                        webPolicySyncApplierProvider, webFilterPullProvider, no-op fallback when Firebase
                        is unconfigured)
                      · lib/presentation/screens/web_filter_screens.dart (dashboard refresh calls the
                        real pull provider before invalidating local providers)
                      · test/web_filter_backend_test.dart (NEW — 10 tests: contract paths/idempotency,
                        payload validation, applier merge/removal, honest pull failure)
                      · docs/00_master/FIRESTORE_RULES_WEB_FILTER.md (NEW — deployable security rules spec)
AFFECTED DATA:        · Same SQLite tables (migration v15); remote pull writes only verified server facts
AFFECTED BACKEND:     · NEW Firestore documents only — families/{familyId}/web_policy summary doc plus
                        web_hits / web_domains / web_category_rules / web_settings collections. Zero
                        changes to existing Firebase rules/schema/Render backend.
AFFECTED EVENTS:      · 6 new business operations (web.hit, web.domain, web.domain.removal, web.category,
                        web.setting, web.hit.overridden) via the existing contract engine
AFFECTED SECURITY:    · Security rules spec requires auth + family-member authorization for all web
                        collections; removals are idempotent deletion markers, not history rewrites
AFFECTED CURRENT PHASE:      · Closes FS-002 completely (frontend + backend + Firebase)
AFFECTED PREVIOUS FOUNDATION: · NONE (M1–M9 / Phase 17-18 untouched)
AFFECTED FUTURE PHASES:      · All subsystems follow the same pull/push pattern (child policy delivery,
                        FS-003+ remotes); the outbox/sync semantics become the standard
MIGRATION REQUIRED:   · None (additive collections only); deploy FIRESTORE_RULES_WEB_FILTER.md rules
                        manually to the project
TESTS REQUIRED:       · +10 (web_filter_backend_test.dart); total suite 247 → 257, all green;
                        flutter analyze 0 errors / 0 warnings on new code
DOCS REQUIRED:        · CHANGE_LOG.md (this entry), FIRESTORE_RULES_WEB_FILTER.md
ROLLBACK:             · git revert of this commit; web collections can be dropped from Firestore
STATUS:               · ready (awaiting user confirmation to commit)
```

### CL-005 — Backend integration audit: incident.acknowledged sync fix

```text
CHANGE-ID:            · CL-005
REQUEST:              · User directive: re-verify ALL previous phases for real Frontend + Backend +
                        Firebase + Render integration; fix any genuine gaps found.
CURRENT PHASE:        · Post FS-002 closure (FS-003 not started)
AFFECTED FEATURE:     · Safety incidents (M6/M7-adjacent) — one missed sync case
AFFECTED SCREENS:     · none (backend-only; dashboard incident state already local-correct)
AFFECTED FILES:       · lib/data/firestore_contracts.dart (new incident.acknowledged case →
                        families/{fid}/incidents/{iid} merge)
                      · test/web_filter_backend_test.dart (new contract test)
AFFECTED DATA:        · Firestore incidents/{incidentId} now receives the acknowledged status
AFFECTED BACKEND:     · contract switch only; existing deployed rules already allow member-
                        authorized incident writes (same path as incident.created)
AFFECTED EVENTS:      · incident.acknowledged (previously fell to syncMetadata — unauthorized,
                        permanently permission-denied, like the closed M8 bug)
AFFECTED SECURITY:    · none new (same incident path/authorization as incident.created)
AFFECTED CURRENT PHASE:      · closes a residual sync gap; no in-flight work altered
AFFECTED PREVIOUS FOUNDATION: · NONE (M1–M9/Phase 17-18 untouched)
AFFECTED FUTURE PHASES:      · FS-011 rules / reporting consume acknowledged incidents
MIGRATION REQUIRED:   · none
TESTS REQUIRED:       · +1 contract test; suite 257 → 258, all green; 0 errors/0 warnings
DOCS REQUIRED:        · this entry
ROLLBACK:             · git revert of this commit
STATUS:               · ready (awaiting user confirmation to commit)
```

### CL-006 — FS-001 Location & Geofencing: complete real Firebase/Firestore integration
- **REQUEST:** User directive: "FS-001 — Location & Geofencing, fix this phase as planned" — full subsystem to the same Frontend + Backend + Firebase real-integration standard (no Mock, no partial).
- **CURRENT PHASE:** FS-001 Location & Geofencing (prior code state: UX docs only, no implementation).
- **AFFECTED FEATURE:** FS-001 Location & Geofencing.
- **AFFECTED SCREENS:** LO-001 … LO-015 (family map, member details, history, geofence list/create/edit, settings, alerts, privacy, permission onboarding, sharing status, favorite places, child self-scope sharing).
- **AFFECTED FILES:** lib/core/database/guardian_database.dart (v16), lib/data/location_repository.dart (NEW), lib/data/location_remote_service.dart (NEW), lib/data/firestore_contracts.dart (5 cases), lib/application/guardian_providers.dart, lib/presentation/screens/location_screens.dart (NEW), lib/presentation/screens/location_child_screens.dart (NEW), lib/presentation/widgets/guardian_map_widget.dart (NEW), lib/presentation/router/app_router.dart (13 routes), lib/core/localization/app_localizations.dart (~85 keys AR+EN), test/location_backend_test.dart (NEW), docs/00_master/FIRESTORE_RULES_LOCATION.md (NEW), docs/00_master/CHANGE_LOG.md (this entry).
- **AFFECTED DATA:** new SQLite tables location_points, geofences, location_alerts, favorite_places, location_settings (migration v16).
- **AFFECTED BACKEND:** NEW Firestore contract cases location.updated, geofence.created/updated/disabled, favorite.place, location.setting (paths families/{id}/locations|geofences|favorite_places|location_settings); real pull bridge (verified /locations server read → WebPolicySyncApplier-style merge with removal handling); honest failure reporting.
- **AFFECTED EVENTS:** location.updated (device-written), geofence.* (parent-written), favorite.place, location.setting — all outbox-enqueued with idempotency keys.
- **AFFECTED SECURITY:** new collections authorized per FIRESTORE_RULES_LOCATION.md; locations device-written/parent-read, geofences parent-written; hard delete blocked server-side; soft-disable semantics.
- **AFFECTED CURRENT PHASE:** closes FS-001.
- **AFFECTED PREVIOUS FOUNDATION:** NONE (M1–M9 untouched; reuses membership/pull infrastructure).
- **AFFECTED FUTURE PHASES:** FS-011 (rules/alerts reporting consumes location_alerts); Guardian AI location layer consumes verified positions.
- **MIGRATION REQUIRED:** SQLite migration v16 (automatic).
- **TESTS REQUIRED:** +10 backend tests (contract paths, payload validation, applier merge/removal, pull failure); suite 258 → 268, all green; 0 errors/0 warnings on new code.
- **DOCS REQUIRED:** FIRESTORE_RULES_LOCATION.md (deployable), this entry.
- **ROLLBACK:** git revert of this commit (+ migration v16 undo).
- **STATUS:** ready (awaiting user confirmation to commit)


## CL-007 — Coherence audit: full-phase consistency sweep
Date: 2026-08-18 | Branch: feature/design-system-integration | Tests: 274/274 green

Deep coherence audit of every declared phase (Phase 0/1, M1-M9, FS-002, FS-001) against MASTER_DEVELOPMENT_PLAN.md and MASTER_SCREEN_INDEX.md. Findings and fixes:

1. **Broken navigation in Family Map (LO-001)**: member tiles pushed `/location/:familyId/members/:id` and the history tile pushed `/location/:familyId/history` — both routes do not exist (404 page). Fixed to the canonical member-details and per-member history routes.
2. **Location History ignored the selected member (LO-003)**: the screen discarded `memberId` and fell back to a runtime-derived scope. Now scoped strictly to the member passed from the map.
3. **Four FS-001 routes deviated from the canonical master plan** and were realigned: create `/geofences/new`, edit `/geofences/:geofenceId/edit`, permission onboarding `/onboard/location`, child sharing `/child/:familyId/:childId/location-sharing` (with real family/child identifiers bound instead of an empty-string fallback).
4. **Missing bilingual localization keys** (`acknowledge`, `saveChanges`, plus ~90 FS-001 keys lost during a local revert) were reconstructed with professional AR+EN values.
5. **LO-014 Geofence Templates implemented**: three ready-made presets (school hours, home range, prayer place) pre-fill name, radius, alert profile and anchor on the create form.
6. **Two orphan screens got routes**: SafetyActionsScreen at `/safety/actions/:familyId` and ChildPolicyExperienceScreen at `/child/:familyId/:childId/device`.
7. **Missing cross-subsystem wiring**: the dashboard now exposes Web Protection and Family Map entry cards (gated by `FamilyRuntimeContext.can()`), the child context screen exposes the device experience, and the safety policies screen exposes the SOS utility. No more dead-end subsystems.
8. **Test discipline**: the policy-manager widget test was made scroll-aware (new SOS card grew the list); six new CL-007 regression tests lock in canonical route coverage, template presets, bilingual key presence and the child self-scope contract.

MASTER_SCREEN_INDEX statuses updated to COMPLETED for WF-002..WF-010 and LO-001..LO-015. Zero changes to existing Firebase rules, schema, or the Render backend.
