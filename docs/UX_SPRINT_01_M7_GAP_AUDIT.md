# UX Sprint 01 — M7 Gap Audit: Screen-Time Measurement

**Date:** 2026-08-13 (UTC+3)
**Baseline commit:** `9f360d32cbb8ee2c7f3ee0e022e040ff88e27356` (M6 final checkpoint on `master`)
**Auditor:** Manus (autonomous agent), Guardian Eye Pro workspace
**Scope of this audit:** consent-gated, on-demand screen-time usage measurement on the child device — capability ladder, honest states, freshness, sync evidence, per-target breakdown, and policy comparison. This audit is READ-ONLY and does not modify any source code, Firebase configuration, security logic, or tests.

---

## 1. Specification vs. Reality

The M7 scope was defined in `docs/UX_SPRINT_01_M7_SCOPE_AND_CONTRACT.md`. Every contract line was audited against the implemented code (`lib/domain/screen_time.dart`, `lib/application/child_usage_measurement.dart`, `lib/application/child_usage_measurement_provider.dart`, `lib/presentation/screens/child_context_screen.dart`) and the deployed Firestore ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc`.

| # | Contract requirement | Implemented | Evidence |
|---|---------------------|-------------|----------|
| 1 | Measurement is consent-gated: no data flows unless the guardian granted observation access | **Yes** — the measurement pipeline reads only what the `AndroidObservationGateway` exposes, which itself requires the guardian's grant step before `observing`/`observed` states are reachable | `lib/core/platform/android_observation_gateway.dart` + gateway status derivation |
| 2 | On-demand measurement: values are computed when the context screen opens, not in the background | **Yes** — `childUsageMeasurementProvider` is a `FutureProvider.family` keyed by device id; no background service exists for measurement | Provider file, no new background work |
| 3 | Capability ladder: unavailable → permissionRequired → permissionDenied → unsupported → noObservation → observing → observed | **Yes** — `ForegroundApplicationStatus` ladder mapped to `UsageObservationState` via `_emptyObservationStateFor` | Domain + provider |
| 4 | Honesty: states must never claim more than the device can prove | **Yes** — new states `stale`, `offlineCached`, `syncPending`, `syncFailed` added; `SyncState.synced` only surfaces with real outbox delivery confirmation | Domain enums + provider derivation |
| 5 | Freshness: a captured reading older than the freshness threshold is surfaced as `stale`/`offlineCached`, never disguised as fresh | **Yes** — `UsageFreshness` computed from `capturedAt` vs. now with a 2-hour threshold; hasOfflineStored promotes stale to offlineCached | `UsageFreshness` + `nearestEvaluationTarget` |
| 6 | Sync evidence: pending outbox rows for the device are surfaced as `syncPending`/`syncFailed`; never claim `synced` without real delivery | **Yes** — `ChildDeviceRepository.pendingUsageSyncRowsForDevice` feeds `UsageSyncState`; `synced` requires `OutboxSyncExecutor` confirmation (app-side guard; production delivery = HUMAN ACTION REQUIRED) | Repository + provider |
| 7 | Per-target breakdown with zero-as-data rule: 0 minutes observed is a real observation, not "no data" | **Yes** — breakdown rows render for every measured target including zero; absence-of-observation is rendered as `noObservation` copy, never as "0 minutes" | `TargetUsage` + widget tests |
| 8 | Policy comparison: each target shows limit vs. used with an honest condition label; no "Blocked" claims anywhere | **Yes** — `EvaluationCondition` (evaluated/overLimit/conditionDetected) with `conditionFor`/`nearestEvaluationTarget`; UI renders `m7ConditionDetected`/`m7OverLimit` | Domain + screen |
| 9 | No enforcement, no background service, no AI: M7 only measures | **Yes** — the diff contains no enforcement code, no WorkManager additions, no ML dependencies | `git diff --stat` |
| 10 | Localization AR + EN parity | **Yes** — 29 new M7 keys in both maps | `app_localizations.dart` |

## 2. Gaps Identified (and resolved in implementation)

1. **Observation-state derivation bug (fixed during implementation).** The first version of the provider derived target observation states with a broken equality that never matched `observed`; every target reported an empty state even when the gateway proved observation. Fixed so that `status == ForegroundApplicationStatus.observed` maps to `observed`, with all other statuses routed through the honest empty-state mapper. Verified by unit tests (fresh observed + stored summaries → `offlineCached`; stale without stored → `stale`; zero minutes + capture → `observed` with `isMeasured = true`).
2. **Missing repository surface for sync evidence.** `ChildDeviceRepository` had no method to enumerate pending usage outbox rows for a device. Added `pendingUsageSyncRowsForDevice(deviceId)` (contract extension only — the outbox schema and executor are untouched).
3. **Test fixture gap in M3.** The new M7 measurement section rendered for the linked-device path in `child_context_screen.dart`, but the M3 widget tests did not stub `childScreenTimeCoordinatorProvider`, so the real coordinator hit an empty test database and the section rendered the honest unavailable state. Fixed by stubbing the coordinator and the repository's `getState` / `pendingUsageSyncRowsForDevice` in the M3 test overrides, and by reordering assertions so lazy-`ListView` unmounting (caused by the longer screen after M7) does not invalidate expectations. No test was weakened — evidence was preserved and strengthened.
4. **Harness fixture contamination (fixed during validation).** In `firebase/tests/deployed_rules_tests.mjs`, earlier tests' direct-enabled writes to `family-a` (member role updates, policy mutation) corrupted the device/member state the M7 write assertion needed, producing a hard rules evaluation error that `assertFails` happily absorbed. The failing `assertSucceeds` exposed it. Fixed by giving the M7 write assertion its own isolated `initializeTestEnvironment` with a fresh rules compile — proper fixture isolation, not a weakening of the test.
5. **No AVD in sandbox.** Gate 13 (physical device / emulator run of the app itself) remains **HUMAN ACTION REQUIRED** and is declared as such in the completion report.

## 3. Firestore rules posture (deployed ruleset `e22c310a`)

The production ruleset already contains the `usage_summaries` block under `/devices/{deviceId}/usage_summaries/{usageId}`:

| Operation | Allow | Condition |
|-----------|-------|-----------|
| read | parent-family active members (primaryParent/parent/coParent) | `parent(familyId)` |
| create | signed-in device app that owns the device | `activeOwnedDevice` + strict lineage invariants (`familyId`, `deviceId`, `memberUid == request.auth.uid`, `usageId`, `target` string, `totalMilliseconds` int ≥ 0) |
| update, delete | **Denied for everyone** | `if false` — append-only, immutable after write |

Foreign families cannot read or write another family's summaries; a revoked device cannot write; parents cannot write (they only read). The harness validates all seven of these behaviors against the deployed ruleset content.

## 4. Non-claims carried into M7 closure

1. `SyncState.synced` in the real app requires **REAL SIGNED-IN APP AUTH + REAL OUTBOX DELIVERY** via `OutboxSyncExecutor` — not evidenced in this milestone. **HUMAN ACTION REQUIRED.**
2. The rules prohibit updates/deletes (append-only), but no server-side expiry or reconciliation exists for usage summaries — the temporary-override expiry guard is client-side only; the absence of server-side enforcement is a documented non-claim.
3. Gate 13 (physical device / AVD): sandbox has no AVD; the app has never been run on a device in this milestone. **HUMAN ACTION REQUIRED.**
4. Usage observation itself depends on Android permission grant flow; this milestone measures nothing before the guardian's consent step.
5. No Blaze activation, no billing, no production data mutation, no new Firebase resources.
