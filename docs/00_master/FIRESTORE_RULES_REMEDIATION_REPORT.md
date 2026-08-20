# Firestore Rules Remediation Report

**Project:** Guardian Eye Pro — Flutter Android family-safety platform
**Branch:** `feature/design-system-integration` (checkpoint commit `3e27e4e`)
**File remediated:** `firebase/firestore.rules` (local file only — **not deployed**)
**Date:** 21 August 2026
**Author:** Manus AI
**Scope:** Local-only remediation of the four documented issues (BUG A, BUG B, GAP C, GAP E). Nothing was deployed, published, or touched in production. No new features or notifications were started.

---

## 1. Executive Summary

The local `firestore.rules` file was remediated against the four issues identified in the preceding verification phase. Every fix was verified on a fresh local Firestore emulator with two full test suites — the extended 27-case verification suite and the original 15-case legacy suite (whose stale seeds were fixed in the same pass). All tests pass, the Flutter baseline remains green (**432/432**), and `flutter analyze` reports **0 errors / 0 warnings**.

| Item | Result |
|---|---|
| BUG A — revoked-device incident/SOS writes | **Fixed** (device binding now requires an active member as well) |
| BUG B — locations create evaluation error | **Fixed** (helper rewritten; active device allowed, invalid payloads cleanly denied) |
| GAP C — tasks/rewards/family rules coverage | **Fixed** (new role-scoped clauses for all six collections) |
| GAP E — geofences/web/app/monitoring/modes | **Investigated and fixed** (all active-sync paths now covered by explicit clauses) |
| Verification suite (`firestore.rules.verification.mjs`) | **27/27 PASS** on a fresh emulator |
| Legacy suite (`firestore.rules.test.mjs`) | **15/15 PASS** after stale-seed fixes |
| `flutter analyze` | **0 errors, 0 warnings** |
| Flutter regression | **432/432 PASS** (`All tests passed!`) |
| Rules deployed / production changed | **No** |

## 2. GAP E Investigation — What Needed Rules

Before adding any clause, each GAP E path was traced to the real application code to decide whether it actually syncs remotely. The contracts file (`lib/data/firestore_contracts.dart`) and the per-domain repositories confirm that all fifteen paths below are real remote-sync targets, so explicit rules were added for all of them rather than leaving them to implicit deny.

| Path | App-side writer (evidence) | Write rule added |
|---|---|---|
| `geofences` | `location_repository.dart` outbox (`geofence.created/updated/disabled`) | parent only |
| `favorite_places` | `location_repository.dart` (`favorite.place`) | parent only |
| `location_settings` | `location_repository.dart` (`location.setting`) | parent only |
| `web_hits` | `web_filter_repository.dart` `recordHit` | child **active-owned device** only |
| `web_domains` / `web_category_rules` / `web_settings` | `web_filter_repository.dart` domain/category/setting writes | parent only |
| `app_policies` / `app_allowlists` / `usage_alert_settings` | `application_policy_repository.dart` (config) | parent only |
| `app_block_events` | `application_policy_repository.dart` block history | parent device (**active-owned device**) |
| `monitoring_shots` / `monitoring_evidence` | `monitoring_repository.dart` (child-device evidence) | **active-owned device**; parent read |
| `monitoring_sessions` / `monitoring_requests` / `monitoring_schedules` | `monitoring_repository.dart` | parent only |
| `mode_configs` / `mode_activations` | `mode_config_repository.dart` (`sync_state = queued`) | parent only (activations: device-request branch included) |

Read access on all of these paths is scoped to family members, and every write carries the `familyId` cross-check so no cross-family write can succeed. The `notification_events` and `device_pairings` collections remain permanently write-blocked as before.

## 3. Bug Fixes Applied

**BUG A — incidents/SOS revoked-device bypass.** The `activeMember` branch of `incidents` and `sos` create permitted any active-status member to write events even when their device was revoked. The fix consolidates both branches into a single `deviceBoundEvent` contract that requires the write to come from an **active member** whose **active owned device** carries the payload's `deviceId` (verified against the device doc's own `familyId`). A targeted reproducer confirmed that a revoked member with a still-active device can no longer create incidents or SOS records.

**BUG B — locations create evaluation error.** The old `activeOwnedDevice` helper used a helper (`deviceStatus`) whose final operand returned a string inside a boolean `&&` chain, producing an evaluation error that denied even valid location writes from trusted devices (breaking M9 background-location reporting). The helper was rewritten inline with type-safe guards (`deviceId is string`, `deviceId != ''`), an `exists()`-first device lookup, and the `familyId` cross-check on the device document. Valid active-device writes are now allowed; missing/unknown/empty `deviceId` payloads are cleanly denied without evaluation errors.

**Additional evaluation-safety hardening discovered during remediation.** The `reward_claims` and `task_completions` create clauses combined child and parent branches with an `||` whose sibling branches evaluated fields absent from the sibling's payload, producing `Property undefined` evaluation errors that failed the whole expression. Each branch now guards its own fields (`'decision' in request.resource.data`, `request.resource.data.action is string`), which also aligned the claims rules with the real outbox contract (the child claim request carries `childId`, never `deviceId`, and no `decision`/`decidedBy`).

## 4. Every Allowed and Denied Case (Final Remediated Ruleset)

The full 27-case verification suite on a fresh emulator. Results for the newly added coverage:

| # | Path / Operation | Actor | Result |
|---|---|---|---|
| 1–2 | Unauthenticated read/write: `families`, all subcollections | anonymous | **DENIED** (all) |
| 3–4 | Cross-family reads/writes (A→B and B→A) | primary parent A, child A | **DENIED** (all) |
| 5 | Child reads other members' profiles | child | **DENIED** |
| 6 | Child writes policies/members/devices/invitations | child | **DENIED** |
| 7 | Child reads parent-only collections | child | **DENIED** |
| 8 | Spouse/parent read own family and policies | spouse / parent | **ALLOWED** |
| 9 | Write policies: spouse vs parent | spouse / parent | **DENIED** / **ALLOWED** |
| 10 | Modify family/member records: non-primary vs primary | non-primary / primary | **DENIED** / **ALLOWED** |
| 11 | Revoked member: reads, incidents/SOS/locations with own device | revoked member | **DENIED** (all — device binding now requires active membership) |
| 12 | Untrusted device: locations write with revoked/unknown/empty `deviceId` | child | **DENIED** (cleanly, no evaluation error) |
| 12b | Locations write from active owned device | child | **ALLOWED** (BUG B fixed) |
| 13 | `devices` ownership: child self-registration vs parent owner | child / parent | **DENIED** / **ALLOWED** |
| 14 | **FS-007** `tasks` create; `task_completions` child request with wrong `childId`; child self-review | parent / child (forged) / child | **ALLOWED** (parent) / **DENIED** / **DENIED** |
| 14b | **FS-007** `task_completions` child request for own task; parent review | child / parent | **ALLOWED** / **ALLOWED** |
| 15 | **FS-008** `rewards` catalog create; `reward_ledger` append by child | child | **DENIED** (both) |
| 15b | **FS-008** `rewards` and `reward_ledger` by parent; child claim of own record | parent / child | **ALLOWED** / **ALLOWED** |
| 15c | **FS-008** child claim with another child's `childId`; child self-decision; child decidedBy | child (forged) / child / child | **DENIED** (all) |
| 15d | **FS-008** parent approval decision with correct `decidedBy` | parent | **ALLOWED** |
| 16 | **FS-011** `family_rules` create/update by parent; child and spouse reads | parent / child / spouse | **ALLOWED** / **ALLOWED** (read) / **ALLOWED** (read) |
| 16b | **FS-011** `family_rules` write by child or spouse; parent empty-merge update | child / spouse / parent (empty) | **DENIED** (all) |
| 17 | **GAP E** geofences/favorite places/settings: child write; parent write+read | child / parent | **DENIED** / **ALLOWED** |
| 17b | **GAP E** `web_hits` from child device; parent read; parent write | child (device) / parent | **ALLOWED** / **ALLOWED** / **DENIED** |
| 17c | **GAP E** `monitoring_shots` device write; parent read; parent write | device / parent | **ALLOWED** / **ALLOWED** / **DENIED** |
| 17d | **GAP E** `mode_configs`/`mode_activations` parent; child write | parent / child | **ALLOWED** / **DENIED** |
| 18 | AI paths (`ai_insights`) | parent | **DENIED** — offline-first by design, no gap |
| 19 | Couple Harmony (`couple_decisions`) | spouse | **DENIED** — local SQLite only, no gap |
| 20 | Subscription (`subscription_entitlements`, `billing_records`) | primary parent | **DENIED** — local-only entitlements, no gap |
| 21 | `notification_events` / `device_pairings` | parent | **DENIED** — permanently blocked |
| 22 | Device pairings/ownership boundaries | child / parent | **DENIED** / **ALLOWED** (correct mix) |

## 5. Changed Files (all committed in `3e27e4e`, 9 files, +802 / −66)

| File | Change |
|---|---|
| `firebase/firestore.rules` | Remediated: device-bound incidents/SOS, defensive `activeOwnedDevice`, six GAP C collection clauses, eighteen GAP E clauses |
| `firebase/tests/firestore.rules.verification.mjs` | Contract-aligned and extended to 27 cases covering BUG A/B, GAP C, and GAP E |
| `firebase/tests/firestore.rules.test.mjs` | Stale seeds fixed: device docs gained `familyId` fields; invitation `expiresAt` moved to 2030 (was expiring on the test date) |
| `lib/application/guardian_ai_engine.dart` | Analyzer warning fix (unused variable) from this phase's cleanup |
| `lib/data/family_event_registry_repository.dart` | Analyzer warning fix (unused import) |
| `lib/domain/family_authorization.dart` | Analyzer warning fix (unreachable duplicate switch case) |
| `lib/domain/guardian_ai_models.dart` | Analyzer warning fix (unused import) |
| `docs/00_master/FIRESTORE_RULES_VERIFICATION_REPORT.md` | Previous phase's verification report (committed alongside) |
| `firebase/tests/REMEDIATION_EVIDENCE_LOG.md` | Full working log of the remediation evidence |

Diagnostic reproducers (`repro_bound.mjs`, `repro_gapc.mjs`, `smoke_remediation.mjs`) were created during debugging and deleted after they served their purpose; they are not committed.

## 6. Test and Baseline Results

All Firestore verification runs were executed on a **freshly restarted emulator instance** — a documented quirk of the environment is that the emulator retains its database between runs, which produced non-deterministic results when suites were re-run on a warm instance. The commit-qualifying runs were: verification suite **27/27**, legacy suite **15/15**, `flutter analyze` **0 errors / 0 warnings**, and the full Flutter regression **432/432** (`All tests passed!`).

## 7. Constraints Honored

No rules were deployed, published, or otherwise pushed to the `manus-guardian` production project. Production Firebase configuration was not touched. FS-010 and all remaining subsystems remain unstarted, and notifications remain unimplemented. The commit has **not been pushed** to GitHub, pending your instruction.

## 8. Remaining Unknowns and Recommendations

The only outstanding unknown remains the **live comparison with the deployed ruleset**, which still requires an authenticated Firebase session for `manus-guardian` (`firebase login` or a CI token). Once the deployed ruleset can be fetched, the local remediated file (`3e27e4e`) should be compared against it before any deployment decision. When you approve publishing, the recommended path is a controlled `firebase deploy --only firestore:rules` after the authenticated diff review.
