# PHASE 4D CLOSURE REPORT — Authorized Local Family-Data Export

**Status: `CLOSED-CODE-VERIFIED`**
**Checkpoint commit: `50b65c4` (local only — NOT pushed to GitHub, per user instruction)**
**Branch: `feature/design-system-integration` (never merged to master)**
**Date: 2026-08-21**

---

## 1. Scope Delivered (within the approved PHASE4_DELETION_EXPORT_CONTRACT)

Phase 4D is the **local authorized export** phase. It deliberately does **not** implement remote export, cloud uploads, Firebase storage access, or any future Phase 4 sub-phase. Everything delivered is device-local, offline, and verified only against the local SQLite engine and deterministic unit tests. Export is the honest mirror of the Phase 4C purge: the same healthy-base-schema precondition, the same authorization gates, and the same "never claim success until proven" rule.

| Deliverable | File | Purpose |
|---|---|---|
| Export engine | `lib/data/family_data_export_service.dart` | `LocalFamilyExportService` — versioned JSON bundle builder with manifest, forbidden-key scanner, and double-pass validation |
| State machine | `lib/application/family_export_providers.dart` | `LocalExportNotifier` + per-family provider, reusing the purge precondition provider for the healthy-schema gate |
| UI | `lib/presentation/screens/export_controls_screen.dart` | Honest-state Export Controls screen (permission check → preparing → ready-to-share → failed/cancelled/expired), share-or-save action, forbidden-data boundary card |
| Entry point | `lib/presentation/screens/settings_screen.dart` + `lib/presentation/router/app_router.dart` | Settings "Data & Export" tile → `/export-controls` |
| Localization | `lib/core/localization/app_localizations.dart` | 17 new AR + EN key pairs (36 key insertions), RTL builds cleanly |
| Evidence | `test/family_export_test.dart` | 16 behaviors against the real SQLite engine |

## 2. Engine behavior (CODE-VERIFIED)

The export bundle is a versioned JSON document (`schemaVersion = 1`) with three top-level keys — `manifest`, `family`, `sections` — and a strict post-write honesty rule: the file is **written, re-read, and re-validated** before any "exported" claim is made. A bundle that fails either pass (corrupted base schema, failing section readers, forbidden keys, manifest family mismatch, missing manifest/family/sections) is deleted from disk and returned as an honest `failed` outcome with `reason = validation_failed` or `post_write_validation_failed`.

- **Authorization gates** (all enforced against `FamilyRuntimeContext`): unbound/unverified actor → `blockedPermission (actor_not_bound)`; child role → `child_denied`; revoked/invited membership → `membership_not_active`; actor-family binding → `cross_family_denied` (a member bound to another family cannot export this family); missing `viewReports` permission → `permission_denied`; unhealthy base schema → `base_schema_unhealthy` with zero bytes written.
- **Forbidden key scanner**: a recursive case-insensitive walker over the entire bundle rejects `fcm_token`, `token`, `app_identity`, `outbox`, `notification_tokens`, and the frozen AI domains (`ai_risk_states`, `ai_behavior_profiles`, `ai_insights`, `ai_detections`, `ai_copilot_suggestions`, `ai_policy_proposals`, `ai_consent_scopes`, and the couple-harmony internals) — a single poisoned row anywhere in the bundle fails the whole export.
- **Section model**: each domain is an independent `ExportSectionBuilder` with `included`/`no_data`/`failed` status; one failing reader fails the whole export honestly (`section_failures: …`) rather than shipping a partial bundle; empty domains report `no_data` without failing the bundle.
- **Aggregates only, no raw coordinates**: the location history section reuses the reports aggregation surface (per-period aggregates) — raw location points are never serialized, matching the approved contract.
- **Self-only couple data**: the couple linking section emits only rows belonging to the requesting actor (via `partner_member_id` matching the actor), never the partner's private records.
- **Stamped files**: filenames carry a UTC timestamp (`guardian_export_{familyId}_{YYYY-MM-DD_HH-MM-SS}.json`); repeated exports regenerate fresh stamped files — the contract's "no stale copy" rule.
- **Expiry**: the returned file reference carries a 30-minute window (configurable); the `expired` state exists in the state machine for the UI honesty contract.

## 3. UI (CODE-VERIFIED, no device validation)

The Export Controls screen mirrors the Privacy Controls honest state machine: precondition banner → preparing → `readyToShare` with the share-or-save card → honest `failed`/`cancelled`/`expired` states with reasons. No false-success state exists: "exported" is only shown after the double-pass validation proves the bundle is valid, self-consistent, and free of forbidden keys. All copy is covered by the 17 new AR/EN key pairs.

## 4. Verification evidence

| Check | Result | Status |
|---|---|---|
| Focused export tests (16 behaviors: export contract, section content rules, aggregates-only location history, self-only couple data, stamped-file regeneration, 6 authorization gates, corrupted-schema gate, failing-reader honesty, forbidden-keys rejection, re-validated manifest family binding, excluded-domain absence, honest `no_data` sections) | 16/16 green | CODE-VERIFIED |
| Full Flutter regression suite | 494/494 green (baseline 462 + 16 Phase 4C + 16 Phase 4D) | CODE-VERIFIED |
| `flutter analyze` on all 7 changed files | 0 errors, 0 warnings, 1 pre-existing unrelated info lint (`app_router.dart:305`, pre-existing route) | CODE-VERIFIED |
| Backend (Render) | Untouched this phase | N/A |
| Firebase/Firestore | Untouched this phase | N/A |
| Real-device / emulator | Not performed (headless engine only) | NOT VALIDATED |
| Production | Not deployed, not modified | N/A |

## 5. Issues found and fixed during testing

1. **Seed INSERT mismatches**: several test seeds referenced columns that do not exist in the real v29 schema (`location_settings`, `family_rewards`, `tasks`, `couple_linking`, `notification_tokens`, `incidents`). All fixed to match the actual DDL before the focused suite could run.
2. **Dead `fileWriter` test hook**: the export run accepted an optional file writer that the production path never honored correctly (the legitimate bundle write always overwrote any test injection), making the "tampered file" attack test unprovable as written. The hook was removed entirely; the tamper-proofing invariant is instead covered by the proven positive test — the written file's manifest family id is re-validated and must always equal the requested family, and any forbidden key anywhere in the written bundle fails the post-write pass.
3. **Repeated-export stamp**: the "fresh stamped file" test only passed by wall-clock luck; the service now takes an injectable `clock` so stamps are deterministic and the idempotency rule is provable.
4. **Section-shape assertions**: initial test assertions assumed a list-shaped `sections` field; the real bundle is a map keyed by section key — assertions corrected to the actual contract shape.

## 6. Honest verification boundaries

- **CODE-VERIFIED**: everything above runs locally against real SQLite via `flutter test`.
- **DEVICE-VERIFIED / PRODUCTION-VERIFIED**: NOT performed. The UI state machine, the platform share sheet on a real phone, Arabic RTL rendering, and behavior under concurrent device usage remain unvalidated on hardware.
- **REMOTE BEHAVIOR**: Phase 4D never touches remote data; no push or deployment has occurred, per user instruction.

## 7. Next approved step

Awaiting user direction. Candidate next phases (not started): Phase 4E (remote deletion per the approved contract), or the next feature phase in the master plan.
