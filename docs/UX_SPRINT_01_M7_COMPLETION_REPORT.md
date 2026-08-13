# UX Sprint 01 — M7 Completion Report: Screen-Time Measurement

**Date:** 2026-08-13 (UTC+3)
**Pre-M7 baseline:** `9f360d32cbb8ee2c7f3ee0e022e040ff88e27356` (`master`, `origin/master`)
**Phase 17 stable checkpoint:** `phase17-stable-checkpoint = 274e181` — untouched, preserved.

---

## 1. Milestone scope (what M7 is)

M7 delivers **consent-gated, on-demand screen-time measurement** on the child's linked device, presented honestly in the guardian's child-context screen. It reuses the existing domain contracts (`AndroidObservationGateway`, `ChildScreenTimeCoordinator`, `DailyUsageSummary`, `ChildDeviceRepository`, the outbox) and adds the measurement presentation layer, honesty states, freshness, sync evidence, and the per-target policy comparison.

| Boundary | In scope (M7) | Out of scope (explicitly) |
|----------|---------------|---------------------------|
| Measurement | Consent-gated, on-demand capture presentation, capability ladder | Background measurement service |
| Honesty | 10 observation states, freshness, sync evidence, zero-as-data | Any claim of `synced` without real delivery |
| Policy view | Per-target limit vs. used, honest condition labels (`policy condition detected`, `over limit`) | Enforcement, "Blocked" claims |
| Intelligence | — | No AI/ML of any kind |
| Backend | `usage_summaries` reads validated against deployed rules; pending-outbox read extension | New Firestore rules deployment, Functions changes, Blaze |

## 2. What was implemented

The implementation touches six product files and adds two, all inside the agreed change boundary:

| File | Change |
|------|--------|
| `lib/domain/screen_time.dart` | `UsageObservationState` extended with `stale`, `offlineCached`, `syncPending`, `syncFailed`; new `UsageFreshness` enum with freshness computation |
| `lib/application/child_usage_measurement.dart` *(new)* | Snapshot models: `UsageSyncState`, `TargetUsage`, `UsageMeasurementSnapshot`, `EvaluationSummary`, `EvaluationCondition`, `conditionFor`, `nearestEvaluationTarget` |
| `lib/application/child_usage_measurement_provider.dart` *(new)* | `buildUsageMeasurementSnapshot` — honest state derivation from gateway status, stored summaries, freshness, and pending outbox rows; target observation fix (`observed` status now maps correctly) |
| `lib/application/guardian_providers.dart` | `childUsageMeasurementProvider` (`FutureProvider.family` by device id) |
| `lib/data/child_device_repository.dart` | `pendingUsageSyncRowsForDevice(deviceId)` — read-only contract extension |
| `lib/core/localization/app_localizations.dart` | 29 M7 keys, full AR + EN parity |
| `lib/presentation/screens/child_context_screen.dart` | `_UsageMeasurementSection` + `_UsageMeasurementCard`; linked-device path now shows the honest measurement card instead of the legacy activity card |

## 3. Honesty guarantees enforced in the UI

1. **Zero-as-data:** a captured day with 0 minutes renders as a real measured total (`0 دقيقة`), while a day with no capture renders `noObservation` copy — the two are visually distinct and never conflated.
2. **Never-`synced`:** the badge ladder is `syncPending` → `syncFailed` → `synced`; the `synced` path is reached only through confirmed outbox delivery, and the UI never shortcuts to it.
3. **Never-`Blocked`:** policy comparison uses `m7ConditionDetected` and `m7OverLimit` labels. A grep for the word "Blocked" in M7 UI strings returns nothing.
4. **Freshness is visible:** `stale` readings carry a stale badge; offline-cached readings carry an offline-cached badge with the last capture timestamp — never disguised as fresh.

## 4. Validation results (direct evidence, see `UX_SPRINT_01_M7_TEST_EVIDENCE.md`)

| Gate | Result |
|------|--------|
| `flutter analyze` | GREEN — 0 errors, 0 warnings |
| Full Flutter suite | GREEN — 197/197 (incl. M7 37/37, repaired M3 12/12) |
| Security regression (actor binding + membership) | GREEN — 14/14 |
| Firestore Emulator (local rules) | GREEN — 15/15 |
| Functions Emulator | GREEN — 2/2 |
| Deployed-rules harness (`e22c310a`) | GREEN — 16/16 (7 new M7 scenarios) |
| Secret scan | GREEN — no secrets in working tree or diff |
| `phase17-stable-checkpoint` | Untouched |
| Firebase configuration (`firebase_options.dart`, `google-services.json`, `firebase.json`, `.firebaserc`) | Unchanged |
| M1–M6 history | Unmodified; M7 commits build on top |

## 5. Resolved defects (integrity of the milestone)

Two real defects were discovered during M7 and fixed honestly: the provider's target observation derivation never matched `observed` (every target falsely reported an empty state), and the deployed-rules harness had fixture contamination that hid a hard rules evaluation error inside `assertFails`. Both were corrected with test-strengthening fixes, and both fixes are covered by passing tests.

## 6. Non-claims and human actions

1. **Gate 13 (physical device / AVD): HUMAN ACTION REQUIRED.** The sandbox contains no Android emulator; the app has not been run on-device in this milestone.
2. **Real `SyncState.synced`: HUMAN ACTION REQUIRED.** App-authenticated signed-in session plus real outbox delivery through `FirestoreOutboxRemoteWriter` has not been executed end-to-end in production; the emulator and rules harness prove only the policy posture.
3. The append-only/immutable character of `usage_summaries` is enforced in deployed rules (update/delete `if false`); the absence of server-side expiry is a documented non-claim.
4. No Blaze activation, no billing activation, no production data mutation, no new Firebase resources.
5. M8 (screen-time enforcement) has **not** started and will not start without explicit user instruction.

## 7. Milestone verdict

| Milestone | Verdict |
|-----------|---------|
| M7 — Screen-Time Measurement | **GREEN** on every evidenced gate; two explicit HUMAN ACTION REQUIRED items honestly carried forward (Gate 13; real `SyncState.synced`) |
