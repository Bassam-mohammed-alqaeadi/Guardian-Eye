# UX Sprint 01 — M7 Screen-Time Measurement: Scope and Contract

**Author:** Manus AI
**Date:** 2026-08-13
**Baseline:** M6 checkpoint `9f360d32cbb8ee2c7f3ee0e022e040ff88e27356` on `master` (verified)

---

## 1. Objective

M7 converts Screen-Time from policy administration into **actual measured device usage**. A parent must be able to understand how much screen time the child actually used today, when it occurred, how it compares with the active M6 policy, and — most importantly — whether any of that information is a real observation, an empty state, a permission denial, an unsupported device, stale data, or offline-cached data. The system must never fabricate measurement.

## 2. Baseline Verification

The repository baseline was verified before any M7 work began: `HEAD` matches `origin/master` at `9f360d3` (the M6 GitHub checkpoint), M1–M6 history is intact, and `phase17-stable-checkpoint = 274e181` remains untouched. The M6 completion report, gap audit, and test evidence were read; M6 is closed on the real backend with the deployed ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc`.

## 3. In Scope

M7 includes the following, all layered on the existing domain rather than parallel implementations:

| Area | Detail |
|---|---|
| Usage observation | Android `UsageStatsManager` read path through the existing `android_observation_gateway` and `ChildScreenTimeCoordinator` (on-demand, not background) |
| Usage Access permission | Transparent capability-ladder UX: not requested / requires settings / granted / denied / unsupported / unavailable; the existing `CapabilityGateway` handles the native settings intent |
| Daily aggregation | `DailyUsageSummary` with cumulative, replay-safe upsert semantics (device + local day + target, never additive duplication) |
| Local day boundary | Local timezone day start, tested for midnight rollover and same-day re-observation |
| Policy comparison | The existing `ScreenTimeEngine.evaluate` produces evaluation labels (within / near / over limit, no active policy, unable to evaluate) with **no enforcement claims** |
| Child Context integration | The M3 child context entry point gains today's usage, freshness, breakdown, comparison, permission state, and offline state |
| Offline-first | Summaries persist locally and display offline verbatim with freshness context; nothing is fabricated |
| Synchronization | Usage observations sync through the existing outbox (`child.usage.observed`) with preserved idempotency and `SyncState` semantics |
| Honest states | `permissionRequired`, `permissionDenied`, `unsupported`, `noObservation`, `observing`, `observed`, `stale`, `offlineCached`, `syncPending`, `syncFailed` |
| Localization | Arabic (RTL) and English (LTR) for all usage, permission, freshness, comparison, error, and sync UI text |
| Security | Family-scoped reads by device membership; child self-scope only; spouse follows M5 Option A; unbound and cross-family actors fail closed; no forged `familyId`/`childId`/`deviceId` accepted |
| Tests | Unit, widget (14 scenarios), integration, emulator security rules, and deployed-rules harness additions |

## 4. Out of Scope (M7 != M8)

M7 measures; M8 enforces. Explicitly excluded: app blocking, system-level restriction, enforcement services, accessibility-based blocking, overlay enforcement, Device Owner, background continuous collection, reboot/Doze receivers, enforcement watchdogs, AI monitoring or classification, web filtering, location/geofencing, chat, audio, mirroring, subscriptions, and payments. M7 introduces no persistent monitoring service, reboot receiver, Doze optimization, or watchdog.

## 5. Critical Non-Claims

1. **No "Blocked" claim.** Usage exceeding a configured limit is reported only as a *policy condition detected* (e.g., "over the policy limit"), never as the device being blocked or restricted. M6 configures the policy; M7 observes the condition; only M8 may enforce.
2. **Zero is not "no data".** Zero minutes observed and no observation available are distinct UI states at all times.
3. **Permission denied is not zero usage.** A denied Usage Access permission renders `permissionDenied` with no numeric usage claim.
4. **Synced only after real confirmation.** `SyncState.synced` is never displayed without `OutboxSyncExecutor` confirmation; `syncPending`/`syncFailed` reflect the real outbox state.
5. **No AI** of any kind; no content classification or risk scoring.

## 6. Domain Reuse Contract

No parallel implementations are created. The following existing contracts are reused unchanged:

| Contract | Role in M7 |
|---|---|
| `lib/domain/screen_time.dart` | `UsageObservationState` (extended with `stale`/`offlineCached`/`syncPending`/`syncFailed`), `DailyUsageSummary`, `ScreenTimeEvaluation`, `ScreenTimeEngine.evaluate` |
| `lib/application/child_screen_time_coordinator.dart` | `evaluateNow(deviceId)` — on-demand observation, evaluation, and local recording |
| `lib/core/platform/android_observation_gateway.dart` | `observeUsageStats` method channel read path |
| `lib/core/platform/capability_gateway.dart` | `usageStats` capability detection and `request()` → native Usage Access settings |
| `lib/data/child_device_repository.dart` | Cumulative upsert, `usageForTarget`, `usageForDeviceDay`, `recordScreenTimeEvaluation` |
| `lib/application/guardian_providers.dart` | `childUsageForTodayProvider`, `childScreenTimeCoordinatorProvider` |
| `lib/application/child_context_provider.dart` | Existing `childContextProvider` extended with the M7 measurement snapshot |
| `lib/data/outbox_sync_executor.dart` | Existing `child.usage.observed` mutation → `deviceUsageSummary` path with idempotency key |

## 7. Data Minimization

Only the minimum fields for screen-time calculation are collected: package/application, foreground duration, observation window, observation day, and device identifier. No screenshots, microphone, location, message content, browser history, or AI classification is added.

## 8. Backend Classification

| Path | Class | Evidence basis |
|---|---|---|
| Usage summary creation by an active enrolled child device | **A — Real Firebase** | The deployed ruleset `e22c310a` contains the `usage_summaries` block with `activeOwnedDevice` guards; outbox executor maps `child.usage.observed` to this path |
| Rules matrix and denial paths | **B — Emulator** | Isolated security isolation tests on the deployed ruleset |
| Destructive authorization permutations, cross-family denial | **B — Emulator** | Never exercised against production |
| Usage Access permission grant/denial, real usage capture, force-stop persistence, offline display parity | **C — Human Action Required** | Requires a physical child device or representative AVD; the sandbox has none |

## 9. Acceptance Gates

| Gate | Requirement | Status source |
|---|---|---|
| 1 | `flutter analyze = 0` issues | Phase E |
| 2 | M1–M6 tests remain GREEN | Phase E |
| 3–6 | Measurement, permission, aggregation, daily-summary correctness | Phase D unit/widget tests |
| 7 | `ScreenTimeEngine` semantics used for comparison | Phase D |
| 8 | Offline honesty | Phase D |
| 9 | Sync claimed only after real confirmation | Phase D/E |
| 10 | Security boundaries | Phase E + harness |
| 11 | Supported operations proven against real backend | Phase E |
| 12 | Emulator rules/security tests pass | Phase E |
| 13 | Physical device / AVD measurement evidence | **HUMAN ACTION REQUIRED** — M7 cannot be declared fully GREEN |
| 14 | Arabic RTL + English LTR | Phase D widget tests |
| 15 | Accessibility of critical data | Phase D |
| 16 | No M8 enforcement features | Audit at Phase G |

## 10. Deliverables

`feat`/`test`/`docs` commits matching actual work; `docs/UX_SPRINT_01_M7_SCOPE_AND_CONTRACT.md`, `docs/UX_SPRINT_01_M7_GAP_AUDIT.md`, `docs/UX_SPRINT_01_M7_TEST_EVIDENCE.md`, `docs/UX_SPRINT_01_M7_COMPLETION_REPORT.md`, a final checkpoint report, and an append-only roadmap entry. **No push without explicit user approval; M8 does not start.**
