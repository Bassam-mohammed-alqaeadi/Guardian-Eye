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
