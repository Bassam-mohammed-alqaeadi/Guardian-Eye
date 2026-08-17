# UX Sprint 01 — M9 Real Firebase Sync Gate Report

**Status:** PARTIAL — Triggers A/B/C + E3 implemented and verified; Trigger D
(WorkManager background sync) deferred by owner decision; real-device proof
HUMAN ACTION REQUIRED.

**Baseline:** `b6e2b94c23701964f1cf7012f16de917ee5541b5` (confirmed `origin/master`).

## 1. Root cause closed

Real-device validation proved the outbox pipeline worked but was never
triggered at runtime: `OutboxSyncExecutor.executeDue()` was only reachable
from the unrouted `SafetyActionsScreen`, and `workmanager` was a dependency
with no Dart registration.

M9 adds the canonical **runtime sync coordinator** around the existing
durable outbox. No second sync engine, no second Firestore writer, no
redesign of the outbox or database.

## 2. What was implemented

| Piece | File |
|---|---|
| `SyncCoordinatorCore` — single-flight execution (concurrent triggers share one run) | `lib/application/sync_coordinator.dart` |
| `SyncCoordinator` — `StateNotifier<SyncRunState>` exposing honest `isSyncing` / `lastReport` / `lastError` | `lib/application/sync_coordinator.dart` |
| Trigger A — app startup (post-first-frame) + auth-aware retry after sign-in | `lib/presentation/guardian_app.dart` |
| Trigger B — offline → online connectivity restoration (transition-only stream) | `lib/core/platform/network_connectivity_service.dart` |
| Trigger C — canonical manual "sync now" in Settings with queued/syncing/synced/failed | `lib/presentation/screens/settings_screen.dart` |
| E3 — family-level pending sync derived from the REAL outbox (incl. `family.created`) | `lib/data/outbox_sync_status.dart`, `lib/presentation/screens/family_members_screen.dart` |
| Providers wired | `lib/application/guardian_providers.dart` |

Honesty contract preserved: `SyncState.synced` is written only by
`OutboxSyncExecutor` after the remote writer confirms delivery. The
coordinator never infers, optimistically sets, or claims `synced`; it only
exposes the executor's real report. Logged-out runs are clean no-ops
(`authenticated_identity_required`) and stale identities can never write
(the executor reads the current session on every run).

## 3. Verification evidence

- `flutter analyze` — 0 errors, 0 warnings (54 pre-existing info lints in
  older test files unchanged).
- `flutter test` — **230/230 passed** (217 baseline + 13 new M9 tests:
  coordinator single-flight/state/failure-containment, connectivity
  transition mapping, E3 family-pending status).
- `flutter build apk --debug` — **√ Built `app-debug.apk`**.
- Trigger matrix tests: concurrent startup + manual triggers collapse to one
  execution; offline→online duplicate reports suppressed; family overview no
  longer shows "متزامن" while `family.created` is queued.

## 4. BLOCKED — Trigger D (WorkManager background sync), owner decision

M9 §6 mandates wiring the existing `workmanager` dependency to a background
sync opportunity. Importing `package:workmanager` (which imports
`workmanager_apple` unconditionally) exposes a **pre-existing incompatibility
in the committed `pubspec.lock`**:

```
workmanager_platform_interface 0.9.4 added the named parameter
'foregroundServiceConfig' to registerOneOffTask / registerPeriodicTask;
workmanager_apple 0.9.4 (resolved by the lock) does not implement it:

/C:/.../workmanager_apple-0.9.4/lib/workmanager_apple.dart:31:16:
Error: The method 'WorkmanagerApple.registerOneOffTask' has fewer named
arguments than those of overridden method
'WorkmanagerPlatform.registerOneOffTask'.
```

Verified: baseline `b6e2b94` builds the APK; the conflict only surfaces when
app code imports `workmanager`. Per M9 §19 toolchain freeze, the fix
requires an owner-approved dependency-resolution change (proposed minimal
pin: `workmanager_platform_interface 0.9.3` + `workmanager_android 0.9.2`,
keeping `workmanager 0.9.0+3`). **Owner chose to defer Trigger D**, so M9 is
PARTIAL on this gate. The coordinator is designed so the future worker
invokes the same `SyncCoordinatorCore` over the same executor.

## 5. Remaining gaps (honest)

- **Real-device + real-Firebase sync run** (family created → outbox →
  coordinator → executor → Firestore → `SyncState.synced`) — HUMAN ACTION
  REQUIRED on device `RFCT420YY9B`.
- **Trigger D** — deferred by owner (see §4).
- M5/M6/M7 device validation after a successful real sync — not attempted
  (primary gate not yet proven on-device).
- No production rules changed; no Blaze activation; no unrelated files
  committed.
