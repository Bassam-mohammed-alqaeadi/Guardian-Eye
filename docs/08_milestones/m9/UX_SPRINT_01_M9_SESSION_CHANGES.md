# M9 Session — Last Changes & Real-Device Evidence

Date: 2026-08-14
Device: Samsung SM-S906U (`RFCT420YY9B`) · Android 16 / API 36
App: `com.guardianeye.app` (debug APK, Flutter 3.35.7)
Firebase: `manus-guardian` (Spark plan, no Blaze)

---

## 1. Code changes made this session

### 1.1 `lib/application/guardian_providers.dart` — stale sync-count honesty fix

Root cause found on the real device: the Settings sync card showed **"متزامن" (Synced)** while 1 outbox operation was still `queued`. `pendingOutboxCountProvider` was a plain cached `FutureProvider` that computed `0` when the Settings screen first opened (before any mutation existed) and was never invalidated — an M9 honesty violation.

- `pendingOutboxCountProvider` → `FutureProvider.autoDispose<int>` so the count is re-derived from the real SQLite outbox every time the surface opens.
- `familyPendingSyncProvider` → `FutureProvider.autoDispose.family` for the same reason on the family screen.

```diff
-final pendingOutboxCountProvider = FutureProvider<int>(
+final pendingOutboxCountProvider = FutureProvider.autoDispose<int>(
     (ref) => ref.watch(outboxSyncStatusProvider).pendingCount());
-final familyPendingSyncProvider = FutureProvider.family<bool, String>(
+final familyPendingSyncProvider = FutureProvider.autoDispose.family<bool, String>(
     (ref, String familyId) =>
         ref.watch(outboxSyncStatusProvider).hasPendingForFamily(familyId));
```

### 1.2 `lib/presentation/screens/settings_screen.dart` — live invalidation on run completion

The sync card now re-reads the real outbox whenever a coordinator run finishes while the card is visible (startup/connectivity triggers), so it can never show a stale count.

```diff
   Widget build(BuildContext context) {
     final l10n = AppLocalizations.of(context);
     final syncState = ref.watch(syncCoordinatorProvider);
+    ref.listen(syncCoordinatorProvider, (previous, next) {
+      if ((previous?.isSyncing ?? false) && !next.isSyncing) {
+        ref.invalidate(pendingOutboxCountProvider);
+      }
+    });
```

### 1.3 Verification

- `flutter analyze` → GREEN
- `flutter test` → 230/230 GREEN
- APK rebuilt + reinstalled with the real-backend defines
  (`GUARDIAN_ENV=real_backend_validation`, `GUARDIAN_REAL_BACKEND_VALIDATION=true`, `GUARDIAN_FIREBASE_CONFIGURED=true`); data preserved across install.

---

## 2. Real-device M9 gate evidence (this session)

### 2.1 Real Firebase Auth — PROVEN

- Auth session restored on the device: UID `3P5YoV4iKDasxorHi95AQhfAm9e2`.

### 2.2 Real family created through the app UI — PROVEN

- Family `3e7a934a-ddb9-419e-8e45-dd542cdd3344` ("M9Parent") created via the real UI form.

### 2.3 Outbox + sync chain (family) — PROVEN

| Field | Value |
|---|---|
| Outbox op 1 | `deb1c4f4-bdee-4a42-8026-e8cee7db7d2b` (`family.created`) |
| Observed | `queued` (attempt 0) → `synced` (attempt 0, no error) |
| Trigger | startup (Trigger A) after reinstall |

### 2.4 Real Firestore documents (trusted REST read) — PROVEN

- `families/3e7a934a-ddb9-419e-8e45-dd542cdd3344` — `idempotencyKey = deb1c4f4-…` (= outbox op ID), ownerUid = `3P5YoV4iKDasxorHi95AQhfAm9e2`
- `families/3e7a934a-ddb9-419e-8e45-dd542cdd3344/members/3P5YoV4iKDasxorHi95AQhfAm9e2` — `idempotencyKey = deb1c4f4-…`, role `primaryParent`, memberId present

The `idempotencyKey` equal to the exact outbox operation ID is definitive proof the documents originated from the app's outbox flow (no manual Firestore creation).

### 2.5 Actor verification / Family Management unlock — PROVEN

- After delivery + app restart, the read-only warning disappeared; full management navigation (Family Members, Add child, Pair device, Safety policies, Child device status, Daily safety) became enabled.
- Local binding persisted: member `account_uid = 3P5YoV4iKDasxorHi95AQhfAm9e2`.

### 2.6 One M5 remote mutation (invitation) — PROVEN

- Invite created through the UI: target `m9invite.test@example.com`, proposed role `coParent`.
- Outbox op 2 `9e6128dd-f907-445e-bb9c-58c58c511d33` (`family.member.invited`) → observed `queued` → `synced` (attempt 0, no error).
- Real Firestore doc: `families/3e7a934a-…/invitations/bef1837b-ef34-403d-a71c-45f77a68f757` — `idempotencyKey = 9e6128dd-…` (= op 2 ID), status `pending`, `syncStatus: client_submitted`, inviterMemberId `063a1685-…`, server createTime `2026-08-14T18:35:24Z` (the startup sync after restart).

### 2.7 Startup retry (Trigger A) — PROVEN

- Force-stopped the app with a queued invite op; on relaunch the startup trigger synced it without manual intervention (`queued → synced`, first attempt).

### 2.8 E3 truthfulness — VERIFIED (fixed state)

- Dashboard "عمليات بانتظار المزامنة" reflects the real outbox (0 when empty; family card shows "حديثة").
- The stale "متزامن" bug from 2.x was reproduced, root-caused (cached `FutureProvider`), and fixed in 1.1/1.2.

---

## 3. Additional real-device bug found & fixed (this session)

Inviting a member crashed the app UI with a framework assertion (`_dependents.isEmpty`) — reproduced twice on-device and in a widget test.

**Root cause:** `_showInviteSheet` (family members) and `_addChild` (dashboard) created a `TextEditingController`, then called `controller.dispose()` immediately after `showModalBottomSheet` returned — while the sheet's **exit animation was still using the controller** (`A TextEditingController was used after being disposed`), which cascaded into the framework assertion.

**Fix:** refactored both bottom sheets into lifecycle-safe `ConsumerStatefulWidget`s (`_InviteSheet`, `_AddChildSheet`) that own their controller and dispose it in `dispose()` (after the route fully unmounts). Added regression test `test/family_invite_sheet_lifecycle_test.dart`.

Files changed (in addition to 1.1/1.2):
- `lib/presentation/screens/family_members_screen.dart`
- `lib/presentation/screens/dashboard_screen.dart`
- `test/family_invite_sheet_lifecycle_test.dart`

Verification: `flutter analyze` 0 errors/warnings; `flutter test` 231/231 GREEN; APK rebuilt with real-backend defines.

## 4. Gate 1 — Offline → Online → Sync: PROVEN

1. Device set offline (`Active default network: none`).
2. Offline-created mutations persisted in the outbox: `d3bf72cf-1c7c-41ca-92a0-6e8312f0aa3d` (`family.member.invited`, target `m9gate1.test@example.com`, created 2026-08-14T19:06:41Z, state=queued attempt=0) and `fd902107…` (`member.created`).
3. E3 during queued state: dashboard showed `عمليات بانتظار المزامنة: 1`; family card showed `عمليات بانتظار المزامنة` — **not** `متزامن`/`حديثة` (verified in UI dump; no fake/seed).
4. Network restored → sync ran → outbox `d3bf72cf` → **synced** (attempt 0).
5. Real Firestore doc (trusted REST read): `families/3e7a934a-ddb9-419e-8e45-dd542cdd3344/invitations/04c317c6-20d0-431b-8294-1ea544322784` with **`idempotencyKey = d3bf72cf-…`** (= outbox op ID), targetEmail `m9gate1.test@example.com`, status pending, updatedByUid = authenticated actor, server `createTime 2026-08-14T19:48:57Z`.

Notes:
- `fd902107` (`member.created`, a child created accidentally during blind taps) was rejected by Firestore rules → state **blocked**, attempt=1, `last_error=permission-denied` — an honest, durable rejection per outbox semantics (not weakened). Because it remains non-synced, the family still honestly reports pending — correct E3 behavior, not a false negative.
- The device lost real internet at times during the session (cellular DNS broken, WiFi reconnects); the offline/online legs required manual WiFi restoration (HUMAN ACTION).

## 5. In progress / not yet complete

- **Gate 2 second half (E3 returns to synced after ALL delivery)**: the gate mutation (invitation) returned to synced; the family-level label stays `pending` only because the rules-blocked child op remains — resolving that requires a Firestore rules decision (owner-approved, out of M9 scope).
- The documented M8 `ForegroundServiceDidNotStartInTimeException` recurs ~30s after some launches (BootReceiver → EnforcementService). Untouched (out of M9 scope).

---

## 4. Known environment notes

- The documented M8 issue recurs on this device: `ForegroundServiceDidNotStartInTimeException` (BootReceiver → `EnforcementService` without `startForeground`) crashes the app ~30s after some launches. Out of M9 scope (§18); no WorkManager/foreground-service changes were made.
- Firestore REST trusted reads used the Firebase CLI's stored OAuth access token (in memory only; never written to the repo).
- Session helper scripts (`dev_ui_helper.py`, `dev_m9_driver.py`) and debug artifacts (`*.png`, `sem*.txt`, `db*.db`, `wd*.txt`) exist at repo root — **untracked and to be excluded from any commit**.
