# UX Sprint 01 — M6/M7/M8 Closure Sweep (2026-08-16)

**Status (final):** M6, M7 and M8 all closed on the physical device with
real-Firebase evidence. The parent password was provided on 2026-08-17, which
unblocked the full M6 parent-leg and the M7 real-usage acceptance. Quality
gates all GREEN.

**Device:** SM-S906U / RFCT420YY9B / Android 16 / API 36
**Firebase:** `manus-guardian` | **Render:** `guardian-eye-djg8.onrender.com`

---

## 1. Bugs closed this sweep (root causes + fixes)

### 1.1 Stale `syncing` outbox rows never recovered (M9 regression, real bug)

**Root cause:** `OutboxSyncExecutor.executeDue()` only selected rows in
`queued`/`failed`. A `syncing` row left behind by a killed/hung run (process
death, force-stop, network hang, crash) was **never reclaimed**. Witnessed
on the device: `bf7243b7` stuck in `syncing` for 12+ hours, poisoning the
pending count and silently blocking retry.

**Fix** (`lib/data/outbox_sync_executor.dart`):
- 3-minute staleness recovery: any `syncing` row whose
  `next_attempt_at <= now - 3min` is atomically re-queued with
  `last_error = 'stale_syncing_recovered'`. Safe because every remote write
  is idempotent (`idempotencyKey`).
- Bounded commit: `batch.commit()` now has a 20s timeout and
  `waitForPendingWrites()` a 15s timeout — a hung network can no longer
  strand a row in `syncing` forever (`remote_ack_timeout`, retryable).

**Verified:** 6/6 executor tests pass (new regression test added); on-device
both stuck rows were recovered, re-attempted, and reached their honest
terminal state.

### 1.2 `child.enforcement.applied` fell through to an unroutable path (M8)

**Root cause:** `FirestoreEventContract.businessMutation()` had no case for
`child.enforcement.applied`, so it fell to the `default` branch and wrote to
`/families/{familyId}/sync_metadata/{eventId}` — a path **no deployed rule
allows** → guaranteed `permission-denied` (the `blocked` enforcement ops on
the device were this bug's evidence).

**Fix** (`lib/data/firestore_contracts.dart`): routed
`child.enforcement.applied` to `/families/{familyId}/devices/{deviceId}/enforcement_status/current`
with `memberUid`, which the deployed rules explicitly allow for the device's
`memberUid` (`request.auth.uid == device.memberUid`, single-slot `current`).

**Verified:** contract tests 8/8 pass (new regression test added); a fresh
enforcement op on the physical device went `queued → synced`, and the
document was read back from **real Firestore** at the correct path with the
child's `memberUid`, honest `policyStale` state, and `evaluatedAt`.

### 1.3 M8C — `ForegroundServiceDidNotStartInTimeException`

**Root cause:** the M8 monitoring service declared **no
`foregroundServiceType`**, which Android 14+ (API 34+) requires before a
foreground service may start. On Android 16 / API 36 the service could not
start at all — the documented blocker in the M8 final checkpoint report.

**Fix** (`android/app/src/main/AndroidManifest.xml`,
`EnforcementService.kt`): the service's real workload is collecting usage
observations that feed the family policy/outbox sync pipeline → legitimate
`android:foregroundServiceType="dataSync"` plus the
`FOREGROUND_SERVICE_DATA_SYNC` permission (API 35+).

**Verified on device:** `EnforcementService` runs as foreground
(`isForeground=true`, `types=0x00000001` = dataSync) with no crash across
multiple launches and restarts. This is the documented path A of
`docs/UX_SPRINT_01_M8_ENFORCEMENT_DECISION.md` — not a random type.

### 1.4 M7 category policies never matched a real app (two native gaps)

**Root cause 1:** `queryPolicyUsage` filtered UsageStats by `targets.contains(package)` —
category targets (`video`, `social`, …) were compared against package names, so a real
app never matched and every category policy measured a constant zero.

**Root cause 2:** on this Android 16 / Samsung build, `queryAndAggregateUsageStats`
returns a **corrupted map** (every entry keyed as one system app with 0ms), so even a
concrete-package target could not be measured.

**Fix** (`MainActivity.kt`): added `targetPackages()` (category → canonical package
sets, concrete package targets pass through) and switched to raw `queryUsageStats`
rows aggregated manually, keyed by the policy target.

**Verified:** VLC used ~2:46 on the child device; the child context measured
`video = 166,624 ms` and the summary synced to real Firestore (see §3).

### 1.5 Stale incremental kernel poisoning APK builds

**Root cause:** `flutter build` re-packaged a stale `app.dill` kernel
(01:51) that predated all Dart edits — my M6 wiring and executor/contract
fixes were compiled nowhere. Only the Kotlin M8C fix made it into APKs
(Gradle compiles native sources separately).

**Fix:** `flutter clean` + full rebuild. **Verified** by extracting
`kernel_blob.bin` from the built APK and confirming
`stale_syncing_recovered`, `childPolicyDeliveryServiceProvider`, and
`remote_ack_timeout` are present.

---

## 2. M6 — Screen-time administration: closed wiring, parent-leg blocked

**Implemented this sweep (child-device delivery, the known integration gap):**
- `ChildPolicyDeliveryService` wired into runtime:
  `childPolicyDeliveryServiceProvider` in `guardian_providers.dart`.
- Delivery triggered at startup (post-first-frame) in `guardian_app.dart`
  and on every child-context open (`child_context_provider.dart`).
- The source is a no-op when Firebase is unconfigured; it reads only the
  family `/policies` collection that member rules allow a child to read;
  parent-only overrides are never read (GA-22 preserved).

**Verified (parent-leg + child-leg, 2026-08-17):** with the parent password
(`123456`, verified against Firebase Auth) the full vertical ran on the
physical device:

1. Parent signed in as `alibrother402@gmail.com` (M5Parent, owner of family
   `ff70cf2b-…` containing the child device).
2. Parent created policy **VideoPolicy** (video target, 60-min daily limit,
   05:30–22:00) through the app's policy editor → outbox `policy.created`
   (`queued` → `synced`).
3. Verified in **real Firestore**: `families/ff70cf2b-…/policies/86975ce8-…`
   with `enabled=true, dailyLimitMinutes=60, version=1,
   restrictedTargets=[video]`.
4. Restored the child session; the startup delivery pulled the policy into
   the child device (`child_device_policies` row, version 1) and the state
   machine transitioned the device `enrolled → active` with
   `requiredPolicyVersion=1`; `child.policy.delivered` synced to Firestore
   and appears on the child's safety timeline as `timelinePolicyDelivered`.
5. The child context shows "آخر سياسة صالحة · 2026-08-16" and the effective
   policy decision. The child-read side of the delivery path was already
   proven against the deployed ruleset.

## 3. M7 — Usage measurement: code path GREEN, needs a policy target

- Usage access is **granted** on the physical device
  (`GET_USAGE_STATS: allow`).
- **Two real gaps closed this sweep** so category policies actually measure:
  1. `queryPolicyUsage` matched policy targets ('video' etc.) against
     package names, so a real app never matched. Added `targetPackages()`:
     category targets expand to their canonical packages (video → YouTube,
     Samsung Video, VLC, …; social → WhatsApp/Facebook/…; browser →
     Chrome/Samsung Internet/…), and a concrete package target is used as-is.
  2. On this Android 16 / Samsung build `queryAndAggregateUsageStats`
     returns a **corrupted map** (every entry keyed as one system app with
     0ms). Switched to raw `queryUsageStats` rows aggregated manually, and
     summaries are keyed by the policy target so the Dart coordinator's
     `byTarget[target]` lookup resolves.
- **Verified end-to-end with REAL usage:** launched VLC (a video target
  package) on the child device for ~2:46 of foreground time; the system
  aggregate recorded `org.videolan.vlc totalTimeUsed="02:46"`. The child
  context measured **video = 166,624 ms (2 min)** — the displayed value is a
  real device observation, never seeded. A `child.usage.observed` outbox op
  synced and the doc was verified in real Firestore at
  `devices/798b21e3-…/usage_summaries/4eb484d1-…` with `target=video,
  totalMilliseconds=166624, memberUid=<child uid>`.
- Zero-as-data invariant preserved (a measured zero is distinct from
  absence; absence shows "لا توجد بيانات قياس").

## 4. M8 — Device enforcement/monitoring: closed to the maximum legal level

- **Monitoring:** foreground UsageStats observation, lifecycle, permission
  state, honest stale/offline derivation — verified on device.
- **Enforcement surface:** transparent monitoring service + persistent
  family notification + durable local record + remote `enforcement_status`
  sync. No consumer-legal OS-level package suspension is claimed (requires
  device-owner/profile-owner, which this consumer product does not have).
- **Sync:** `child.enforcement.applied` → `enforcement_status/current`
  verified end-to-end in real Firestore (see 1.2).
- **Resilience (physical device):** app restart, force-stop, process death,
  network loss, network restoration, and the stale-`syncing` recovery were
  all exercised live; the FGS survives restarts with the `dataSync` type.

## 5. Cross-milestone regression

- Family management paths (M5) remain GREEN: parent login flow unchanged,
  child redemption/provisioning via Render backend intact (22/22 backend
  authz tests pass), real-backend security validation PASS against live
  Firestore (every unauthorized write/read denied 403: child-member create,
  role escalation, cross-family read, unauthenticated read, revoked-device
  token write, unauthorized incident write).
- Render backend UP (`{"status":"ok","service":"guardian-backend"}`).
- E3 data consistency: the pending count derives from real outbox rows
  (`queued/failed/syncing/blocked`); nothing claims `synced` without a
  confirmed write. The 11 `blocked` rows on the device are honest terminal
  evidence of bug 1.2 and are left intact (no DB manipulation).

## 6. Quality gates (2026-08-16)

| Gate | Result |
|---|---|
| `flutter analyze` | 0 errors, 0 warnings (57 pre-existing info lints in test files only) |
| `flutter test` | **247/247 PASS** |
| Backend tests (`guardian_backend`) | **22/22 PASS** |
| Firestore rules emulator harness | **15/15 PASS** |
| Real-backend security validation | **PASS** (live manus-guardian) |
| `flutter build apk --debug` (mission defines) | **√ Built** |
| Kernel integrity check | All three fixes present in built APK |

## 7. Remaining OPEN items

| Item | Why it remains open |
|---|---|
| M6/M7 device acceptance | **CLOSED** on 2026-08-17 with the parent password: policy created → Firestore → child delivery → effective policy (M6), and real usage measured → summary → Firestore (M7). |
| Trigger D (WorkManager background sync) | Pre-existing owner decision recorded in `docs/UX_SPRINT_01_M9_SYNC_GATE_REPORT.md`; unchanged. |
| OS-level package suspension | Not legally available to consumer Android without device-owner; honestly classified as monitoring + notification surface only. |
| iOS / APNs | BLOCKED — no macOS/iPhone in environment (unchanged). |

## 8. Physical-device evidence summary (SM-S906U, Android 16)

- M8C FGS: running, `types=0x00000001` (dataSync), no
  `ForegroundServiceDidNotStartInTimeException` across repeated launches.
- Outbox recovery: stuck `syncing` rows recovered by the new staleness
  sweep on first sync after the fixed APK install.
- M8 enforcement sync: new op `queued → synced`; document verified in real
  Firestore at `families/{f}/devices/{d}/enforcement_status/current`.
- Usage access: `GET_USAGE_STATS: allow` (M7 prerequisite).
- Network-loss/restore: ops failed retryable during WiFi drops and were
  re-attempted after restoration (exponential backoff, honest `failed`
  states — never a false `synced`).
