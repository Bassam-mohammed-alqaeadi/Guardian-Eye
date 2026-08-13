# Guardian Eye Pro — M8 Android Enforcement Design

**Author:** Manus AI | **Date:** 2026-08-14 | **Status:** Design + Truth-Gate Audit Complete | **Authority:** Master Product Blueprint + Canonical Roadmap

> **2026-08-14 truth-gate audit (Workstream A):** a code-level audit of the implemented `applyEnforcement()` classified the enforcement chain as **MONITORING-ONLY**. The real OS actions are `UsageStatsManager` foreground observation, a transparent foreground service with a persistent notification, and a durable local record. No OS API call blocks, kills, or restricts a third-party app (that requires Device/Profile Owner, out of consumer scope). The feature's honest classification is **"M8 Enforcement Foundation"** with `Actual Consumer-App Restriction = NOT PROVEN` (register GA-08). Additionally, on API 34+ a foreground service without `foregroundServiceType` fails to start (`foreground_type_required_android_14`) — the physical validation plan (`UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md`) contains the owner-approved paths to resolve this on the SM-S906U (Android 16 / API 36).

## 1. Selected Enforcement Mechanism

Consumer Android does not allow a third-party app to block or kill another app without enterprise device-owner privileges (Device Policy Manager with profile owner, Knox, or supervised MDM). Guardian Eye is a **consumer family-safety product** distributed on Google Play, so it cannot and must not fake app blocking. The selected mechanism is the strongest truthful behavior available to a consumer app:

1. **Local durable policy state** — every delivered policy is stored in the on-device SQLite repository with monotonic versioning (`deliverPolicy` already ignores older versions and accepts idempotent re-deliveries). The device keeps a `requiredPolicyVersion`, `lastValidPolicyAt`, and `lastDecision` watermark.
2. **Foreground lifecycle monitor** — a transparent **foreground service** (declared permission `FOREGROUND_SERVICE`) that watches the foreground application through `UsageStatsManager` (permission `PACKAGE_USAGE_STATS`, already held by M7). When the effective decision is `restrict`/`bedtime` and the restricted target is in the foreground, the service **verifies and records the enforcement result** on Android: it raises a persistent high-priority family notification to the child, writes the local `EnforcementState`, and enqueues a remote `enforcement_status` record through the existing outbox.
3. **Notification-based restriction evidence** — the child sees an honest, non-deceptive restriction notice. The app never claims "Blocked" because a consumer app cannot technically block another app. `AndroidEnforcementResult.applied` is returned **only when Android has actually confirmed the action** (service running + usage-stats observation + notification posted + durable record written).

This is deliberately not the legacy Phase-14 conservative stub (which returned `unsupported` for every restriction). It is the honest maximum for consumer Android.

## 2. Capability Dependencies

| Dependency | Source | State |
| ---------- | ------ | ----- |
| `PACKAGE_USAGE_STATS` | AndroidManifest (M7) + system settings grant | Held; grant is user action |
| `FOREGROUND_SERVICE` | Manifest addition (M8) | To be added |
| `RECEIVE_BOOT_COMPLETED` | Manifest addition (M8) | To be added |
| `WAKE_LOCK` | Manifest addition (M8) | To be added |
| `POST_NOTIFICATIONS` | AndroidManifest (M7) + runtime grant | Held; runtime grant is user action |
| WorkManager | androidx.work 2.x | Already in project (outbox) |
| `enforcement_status` Firestore match | Deployed ruleset `e22c310a` | Verified present |

## 3. Consumer-Policy Legitimacy

The mechanism uses only documented, Google-allowed APIs. The foreground service shows a **visible, ongoing notification** (transparency requirement for foreground services). There is no overlay trickery, no accessibility abuse, no hidden process, no battery abuse. The service starts only when a live restriction exists and stops when no restriction is active — it is **not a persistent loop**.

## 4. Enforcement Chain (Unchanged Canonical Path)

```text
DigitalPolicy
      ↓
ChildPolicyResolver   (already: revoked / missing / version-stale / age-stale / override / restricted)
      ↓
ScreenTimeEngine      (usage evidence + freshness)
      ↓
EnforcementDecision   (already: allow/warn/restrict/bedtime/temporaryAllow/noEnforcement/policyStale/deviceRevoked)
      ↓
EnforcementAdapter    (M8: real foreground-service monitor — replaces the Phase-14 conservative stub)
      ↓
Android               (verified: service alive, usageStats confirms target, notification posted, record persisted)
      ↓
VerifiedResult        (applied / failed / deferred / notApplicable)
```

The four distinctions from mandate §9 are preserved as separate observable facts: **policy exists ≠ decision says over-limit ≠ enforcement requested ≠ enforcement applied**. Only a verified OS-level confirmation counts as `Enforcement Applied`.

## 5. Enforcement States (UI vocabulary, not raw enums)

| Internal state | Arabic label | English label |
| -------------- | ------------ | ------------- |
| `notRequested` | لا يوجد قيد حالياً | No active restriction |
| `permissionRequired` | يحتاج إلى إذن الاستخدام | Usage access needed |
| `unsupported` | غير مدعوم على هذا الجهاز | Not supported on this device |
| `evaluationReady` | جاهز للتقييم | Evaluation ready |
| `enforcementRequested` | جارٍ تطبيق القيد | Restriction being applied |
| `enforcementApplied` | القيد مفعّل | Restriction active |
| `enforcementFailed` | تعذّر تطبيق القيد | Restriction could not be applied |
| `policyStale` | السياسة تحتاج إلى تحديث | Policy needs refresh |
| `deviceOffline` | الجهاز غير متصل | Device offline |
| `recoveryPending` | جارٍ استعادة القيد | Recovery in progress |
| `permissionDenied` | أُوقف الإذن يدوياً | Permission stopped manually |

## 6. Stale / Versioning / Revocation Behavior

A decision can only become `restrict`/`bedtime` when `ChildPolicyResolver` returns `isValid: true`. The resolver already fails validity for: missing delivery, `highestVersion < requiredPolicyVersion` (old-version replay rejected at delivery time AND at resolution time), and policy age beyond the 7-day watermark. An unknown or invalid policy **never** produces an enforcement action; the adapter returns `deferred` (policyStale) or `notApplicable` (deviceRevoked) and the UI moves to `policyStale`/`recoveryPending`. Older versions cannot replace newer ones — `deliverPolicy` enforces monotonicity and throws on equal-version payload conflict.

On revocation, `device.lifecycle == revoked` drives `deviceRevoked`, the local enforcement state is cleared, and no new `deliverPolicy` is accepted for that device lineage.

## 7. Offline Behavior

All enforcement-relevant state (delivered policies, required version, last valid policy time, active enforcement state, pending enforcement rows) lives in **SQLite on the device**. Internet loss does not relax an already-valid local restriction: the foreground monitor keeps running on local truth. When the policy watermark expires (age > max age), enforcement moves to `policyStale` with an honest `recoveryPending` notice — this is the documented safety release, never a silent relaxation into an unknown policy.

## 8. Resilience

| Failure | Behavior | Claim |
| ------- | -------- | ----- |
| Process death | All state durable in SQLite; WorkManager redelivers pending one-off/enqueue work; boot receiver re-establishes on reboot | Provable in tests WITHOUT a device (WorkManager behavior via injected scheduler tests) |
| Reboot | `BOOT_COMPLETED` receiver enqueues recovery work → policy reload from SQLite → enforcement re-established | Requires physical evidence for GREEN |
| Force-stop | Android suspends broadcasts/scheduling until the user reopens the app; state enters `recoveryPending`; restoration happens on next app open | Platform limitation — documented non-claim |
| Doze | Foreground service + notification exempt from battery optimizations while a restriction is active; WorkManager periodic re-evaluation is best-effort in deep Doze | Best-effort, documented honestly |
| Network loss | Local enforcement continues; outbox queues `enforcement_status` rows for later sync | Provable in tests |
| Permission revocation (usage stats withdrawn) | State moves to `permissionDenied`/`permissionRequired` honestly | UI path in M7 vocabulary reused |

Background design follows mandate §16: minimum legitimate mechanism. No persistent loops, no aggressive polling (periodic WorkManager minimum 15 minutes), no hidden service, no battery abuse.

## 9. Security Model

The deployed ruleset `e22c310a` already contains the `match /devices/{deviceId}/enforcement_status/{statusId}` path. M8 adds a deployed-rules harness scenario proving: the child's own device writes only its own active-owned device rows with lineage invariants; a foreign family's device cannot write; a parent reads enforcement status; a revoked device's writes are denied. Existing M1–M7 security tests are untouched.

## 10. Exact Claims

**Can claim:** enforcement requested is a distinct, observable step before application; application requires verified OS confirmation; policies version monotonically; stale/unknown policies never enforce; offline enforcement holds until the documented watermark; reboot recovery is implemented via a real receiver + durable reload; revocation immediately drops authority; overrides (M6) flow through the resolver unchanged.

**Cannot claim (non-claims):** killing/blocking another app on consumer Android; recovery after Android force-stop without user re-opening the app; real-time enforcement inside deep Doze; GREEN physical evidence (enforcement/release/process-death/reboot/Doze/network-loss) without a physical device or AVD executing the flow; `SyncState.synced` without a real signed-in outbox delivery.
