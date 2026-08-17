# Guardian Eye Pro — M8 Final Checkpoint Report

**Author:** Manus AI | **Date:** 2026-08-14 (UTC+3) | **Milestone:** M8 | **Status:** Implementation GREEN — final GitHub checkpoint **awaiting explicit owner approval** (not yet pushed, per standing requirement)

## 1. Checkpoint Position

The M8 implementation is complete and verified against every evidence gate executable from the sandbox. The working tree is ready for the four atomic commits proposed to the owner; per the standing requirement, no commit has been executed and no push has occurred without explicit owner approval. The checkpoint sits directly on top of the M7 checkpoint (`master` HEAD `d61e2d2dff7f43f0e4221ade03a3d6c54c214970`), with the `phase17-stable-checkpoint` branch (`274e181`) untouched throughout.

## 2. Final Evidence at Checkpoint

| Gate | Result | Verified |
| ---- | ------ | -------- |
| `flutter analyze` | 0 errors, 0 warnings (54 info notes) | 2026-08-14, post-harness |
| Full Flutter suite | 217/217 PASS | `flutter test` |
| M8 enforcement unit suite | 19/19 PASS | `test/m8_enforcement_test.dart` |
| Security regression (binding + membership) | 14/14 PASS | `flutter test test/family_actor_binding_service_test.dart test/family_membership_test.dart` |
| Firestore emulator harness | 15/15 PASS | `./tool/run_firebase_emulator_tests.sh`, exit 0 |
| Functions emulator harness | 2/2 PASS | Same script |
| Deployed-rules harness (live ruleset `e22c310a`) | 23/23 PASS | 7 new M8 `enforcement_status` scenarios appended |
| Physical device / AVD | HUMAN ACTION REQUIRED (Gate 13) | GA-08–GA-15, sandbox has no device or AVD |
| Real signed-in outbox delivery | HUMAN ACTION REQUIRED | GA-01, GA-02 |

## 3. Proposed Commits (Awaiting Approval)

1. `feat(ux-m8): add screen-time enforcement on child device` — domain, coordinator, adapter, channel, repository, schema v13, providers, UI, localization, Kotlin service/receiver/manifest, M8 design doc.
2. `test(ux-m8): add enforcement validation and security harness` — 19 M8 unit tests, probe, guardrail update, M6 fixture repair, 7 deployed-rules scenarios.
3. `docs(ux-m8): add scope gap evidence and completion report` — gap audit, test evidence, completion report, plus the pre-existing M8 design document and the master gap register/environment documents.
4. `docs(roadmap): record M8 screen-time enforcement completion` — append-only canonical roadmap entry plus change-log row.

The helper script `tool/patch_main_activity_m8.py` (used only during development) is proposed for deletion before the commit rather than inclusion in the tree.

## 4. Known Non-Claims Preserved at Checkpoint

The checkpoint deliberately preserves the honesty boundary: no "Blocked" claims anywhere in the UI; `SyncState.synced` displayed only after real outbox delivery confirmation; physical-device evidence for enforcement applied, process-death, force-stop, reboot, Doze, network-loss, permission revocation, and stale-policy behavior all declared HUMAN ACTION REQUIRED; `foregroundServiceType` (Android 14+) declared prepared-for-production-promotion; the client-side-only override expiry guard documented with its matching server-side absence as a prepared non-claim (GA-22); no Blaze activation; no production data mutation; no Firebase configuration changes; no start of M9.

## 5. Next Milestone State

M9 (Production Sync Gate) has NOT started and will not start without explicit owner instruction. All remaining work items are registered in `docs/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md` (GA-01–GA-25), and the physical-device program (GA-08–GA-15) is the single largest outstanding human action in the roadmap.


## Truth-Gate Audit Addendum (2026-08-14, Workstream A)

A post-implementation code-level audit reclassified `applyEnforcement()` as **MONITORING-ONLY**. The actual OS actions performed are `UsageStatsManager` foreground observation, a transparent foreground service with a persistent family notification, and a durable local record; no consumer-legal API call blocks, kills, or restricts a third-party app. The feature is honestly classified as the **"M8 Enforcement Foundation"** with `Actual Consumer-App Restriction = NOT PROVEN` (register GA-08, BLOCKED — ENFORCEMENT TRUTH GATE). On API 34+ the service lacks `foregroundServiceType` and therefore **cannot start** on the owner's SM-S906U (Android 16 / API 36) until an owner-approved service-type path is applied (`docs/UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md`). Gate 13 physical evidence for all twelve enforcement scenarios remains **HUMAN ACTION REQUIRED**; nothing in this document elevates any enforcement claim beyond monitoring evidence.

## M8C Closure Addendum (2026-08-16, physical-device evidence)

The two HUMAN-ACTION gaps recorded above were closed on the physical device
(SM-S906U / Android 16 / API 36):

1. **`foregroundServiceType` applied (path A of the enforcement decision doc):**
   `android:foregroundServiceType="dataSync"` + `FOREGROUND_SERVICE_DATA_SYNC`
   permission added; the service's real workload (usage observation feeding the
   family policy/outbox sync pipeline) maps to the legitimate `dataSync` type.
   Verified running: `isForeground=true`, `types=0x00000001`, no
   `ForegroundServiceDidNotStartInTimeException` across repeated launches.
2. **Enforcement sync closed:** `child.enforcement.applied` was routed through
   the contract `default` case to `/sync_metadata/{eventId}` (no rule allows
   it) → `permission-denied`. Fixed to write
   `devices/{deviceId}/enforcement_status/current` with `memberUid`; a fresh
   op synced and the document was verified in real Firestore.
3. **Outbox executor resilience:** stale `syncing` rows (killed/hung runs) are
   now recovered after a 3-minute watermark, and remote commits are bounded
   (20s commit + 15s ack timeouts).

Full sweep record: `docs/UX_SPRINT_01_M6_M8_CLOSURE_SWEEP.md`. The remaining
M6/M7 device-acceptance legs are blocked only on the parent account password
(owner action); everything else in this report stands as verified.
