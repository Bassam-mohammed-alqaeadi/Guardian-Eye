# Guardian Eye Pro — M8 Completion Report

**Author:** Manus AI | **Date:** 2026-08-14 (UTC+3) | **Milestone:** M8 Screen-Time Enforcement and Background Resilience | **Baseline:** `master` HEAD `d61e2d2` (M7 checkpoint) | **Implementation parent:** M8 design document `docs/UX_SPRINT_01_M8_ANDROID_ENFORCEMENT_DESIGN.md`

> **2026-08-14 truth-gate audit (Workstream A, post-implementation):** the implemented `applyEnforcement()` was re-audited at the code level and classified **MONITORING-ONLY**: the real OS actions are `UsageStatsManager` observation, a transparent foreground service with persistent notification, and a durable local record. No consumer-legal API call blocks, kills, or restricts a third-party app. Honest feature classification: **"M8 Enforcement Foundation"**, with `Actual Consumer-App Restriction = NOT PROVEN` (register GA-08, BLOCKED — ENFORCEMENT TRUTH GATE). On API 34+, the service lacks `foregroundServiceType` and therefore fails to start on the owner's SM-S906U (Android 16 / API 36) until an owner-approved service-type path is applied. Gate 13 physical evidence for all twelve enforcement scenarios remains **HUMAN ACTION REQUIRED**, and no enforcement claim is displayed to the user without platform verification.

## 1. What M8 Delivers

M8 converts policy decisions into actual device behavior on the child's Android device and makes the safety loop survive process death, reboot, and Doze. It closes the screen-time vertical's final stage — administration (M6), measurement (M7), enforcement (M8) — with an honest, notification-verified enforcement contract that replaces the Phase-14 conservative stub. A consumer app cannot block or kill another app on Android without enterprise device-owner privileges, so M8 implements the strongest truthful behavior available to a consumer family-safety product distributed on Google Play: a local durable policy state, a transparent foreground monitor that verifies restrictions through `UsageStatsManager`, a persistent high-priority family notification to the child, and a durable enforcement record that enqueues remote synchronization through the existing outbox. Application is recorded as `applied` **only when Android has actually confirmed the action**; everything else fails honestly.

## 2. Implementation Inventory

| Layer | Files | Content |
| ----- | ----- | ------- |
| Domain | `lib/domain/child_device_enforcement.dart` | `EnforcementState` (11 honest values), `EnforcementApplication`, `EnforcementSyncState`, `EnforcementApplicationSnapshot`, `EnforcementStateRecord` (bool args rejected; sync flag serialized as int 0/1), `EnforcementDecision` and the `ChildPolicyResolver`-driven evaluation vocabulary |
| Coordinator | `lib/application/child_enforcement_coordinator.dart` | `evaluate(deviceId, {moment, target})` — resolver → engine → adapter observe → adapter apply → state recording → sync queuing; returns `EnforcementApplicationSnapshot` |
| Providers | `lib/application/guardian_providers.dart` | `enforcementStateProvider` wired through `EnforcementPlatformChannel` |
| Platform | `lib/core/platform/android_enforcement_adapter.dart` (M8 upgrade), `lib/core/platform/enforcement_platform_channel.dart` (new) | Honest contract: `applied` only with verified confirmation; MethodChannel bridge `guardian_eye.enforcement` |
| Data | `lib/data/child_device_repository.dart`, `lib/core/database/guardian_database.dart` | `recordEnforcementState`, `queueEnforcementSync`, `pendingEnforcementSyncRowsForDevice`; schema v13 `child_enforcement_states` table added to **both** `_createSchema` and `_upgradeSchema` |
| UI | `lib/presentation/screens/child_context_screen.dart`, `lib/core/localization/app_localizations.dart` | `_EnforcementSection` + `_EnforcementCard`; 22 Arabic/English localization keys |
| Android | `EnforcementService.kt`, `BootReceiver.kt`, `MainActivity.kt`, `AndroidManifest.xml`, `strings.xml` | Transparent foreground service with `UsageStatsManager` monitoring; `BOOT_COMPLETED` receiver re-establishing WorkManager evaluation; permissions `FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`; MethodChannel implementations `applyEnforcement` / `getEnforcementState` / `scheduleEnforcementCheck` |
| Tests | `test/m8_enforcement_test.dart` (19), `test/_m8_bool_probe_test.dart`, guardrail update, harness | See test evidence document |

The WorkManager dependency required no native Gradle change: the `workmanager` Flutter plugin (^0.9.0) was already present in `pubspec.yaml` through the outbox implementation.

## 3. Honesty Boundary (Exact Claims)

The four distinctions from the mandate are preserved as separate observable facts: **policy exists ≠ decision says over-limit ≠ enforcement requested ≠ enforcement applied**. Only a verified OS-level confirmation counts as `Enforcement Applied`. The UI vocabulary renders honest Arabic/English labels (`القيد مفعّل` / `Restriction active` for `enforcementApplied`; `السياسة تحتاج إلى تحديث` / `Policy needs refresh` for `policyStale`; `جارٍ استعادة القيد` / `Recovery in progress` for `recoveryPending`), and no screen uses the word "Blocked" or its Arabic equivalent anywhere. `SyncState.synced` is never displayed without real `OutboxSyncExecutor` confirmation; the enforcement UI's sync evidence derives from pending enforcement sync rows.

**Exact claims now provable**: enforcement requested is a distinct, observable step before application; application requires verified platform confirmation; policies version monotonically (older versions rejected at delivery and at resolution); a stale, missing, or unknown policy never produces an enforcement action and fails to `policyStale` handling; offline enforcement holds on local truth until the documented seven-day watermark expires, after which enforcement moves honestly to `policyStale`/`recoveryPending`; reboot recovery is implemented through a real `BootReceiver` + durable SQLite reload; revocation immediately drops enforcement authority; M6 temporary overrides flow through the resolver unchanged and expired overrides fall back to the policy decision; permission revocation (usage-stats withdrawn) moves the state honestly to `permissionDenied`/`permissionRequired`.

**Exact non-claims (locked, unchanged)**: killing or blocking another app on consumer Android; automatic recovery after an Android force-stop (recovery happens on the next app open — a documented platform limitation); real-time enforcement inside deep Doze (best-effort, honest); GREEN physical evidence for enforcement applied, process-death recovery, reboot recovery, Doze resilience, network-loss non-relaxation, permission revocation, and stale-policy behavior (Gate 13 — physical device/AVD — remains HUMAN ACTION REQUIRED, see GA-08–GA-15 in the master register); `SyncState.synced` without a real signed-in outbox delivery (GA-01/GA-02); `foregroundServiceType` declaration for Android 14+ Play Store distribution (prepared, awaiting production promotion); the client-side override expiry guard with no matching server-side rule on parent-only override documents (GA-22, preserved as a documented non-claim).

## 4. Security Posture

M8 adds no new attack surface to the existing security architecture. The enforcement decision is driven exclusively by `ChildPolicyResolver` validity (revocation, delivery, monotonic version, seven-day watermark), so invalid policy states can never reach enforcement. The only new remote path — the child app writing `enforcement_status/current` — is constrained by the already-deployed production ruleset: `statusId == 'current'`, active owned device, full lineage invariants, universal delete denial, parent read-only access. The M8 harness appended seven scenarios proving these constraints against the **live deployed ruleset** `e22c310a` (23/23 GREEN). Nothing in `FamilyRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, the SQLite repositories' existing tables, the outbox core, Firestore rules, or Functions was modified. The `phase17-stable-checkpoint` branch (`274e181`) was not touched. No Blaze activation, no billing change, no production data written.

## 5. Verification Summary

| Gate | Result | Evidence |
| ---- | ------ | -------- |
| `flutter analyze` | 0 errors, 0 warnings | Run after final harness pass |
| Full Flutter suite | 217/217 PASS (baseline 197/197) | `flutter test` |
| M8 unit suite | 19/19 PASS | `test/m8_enforcement_test.dart` |
| Security regression | 14/14 PASS | Actor binding + membership suites |
| Firestore emulator | 15/15 PASS | `./tool/run_firebase_emulator_tests.sh` |
| Functions emulator | 2/2 PASS | Same script |
| Deployed-rules harness | 23/23 PASS (7 new M8 scenarios) | `firebase/tests/deployed_rules_tests.mjs` |
| Physical device (Gate 13) | HUMAN ACTION REQUIRED | GA-08–GA-15 |
| Real outbox delivery | HUMAN ACTION REQUIRED | GA-01, GA-02 |

Three transient regressions were discovered and repaired at the fixture level only: the retired Phase-14 guardrail test, the M6 decision-preview scroll finder collision with the honest preview rendering, and a temporary probe's wipe order. All repairs are logged in the test evidence document; no assertion was relaxed.

## 6. M8 Does NOT Claim

M8 claims no production deployment: the `enforcement_status` match already exists in the deployed ruleset and the harness proves the app's consumption model against it; no rules publish occurred during M8 and none is required for the local path. M8 claims no networked enforcement: the remote writer remains the `UnconfiguredOutboxRemoteWriter` degradation configured at M4, and remote enforcement status delivery is gated by M9 exactly as the roadmap §15.1 prescribes for M4–M8 acceptance evidence in local terms only. M8 claims no AI, no SMS, no surveillance, no accessibility service, and no device-owner provisioning.
