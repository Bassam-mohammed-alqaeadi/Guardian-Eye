# Guardian Eye Pro — UX Sprint 01 M8 Gap Audit

**Author:** Manus AI | **Date:** 2026-08-14 (UTC+3) | **Milestone:** M8 Screen-Time Enforcement and Background Resilience | **Baseline:** `master` HEAD `d61e2d2dff7f43f0e4221ade03a3d6c54c214970` (M7 final checkpoint)

## 1. Purpose and Authority

This audit is the opening document of the M8 execution program, performed before any implementation. It reconciles the M8 scope as defined in `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` §14 (the M8 milestone specification) against the Phase 17/18 baseline, the M1–M7 evidence documents, the master gap register (`docs/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md`), and the mandate's honesty contract. The document records what M8 is permitted to claim, what it must not claim, and every gap it closes or inherits.

## 2. Baseline State at the Start of M8

The M7 checkpoint left the product with a complete screen-time administration surface (M6) and a consent-gated, on-demand usage measurement path (M7), but with no device-side enforcement. The enforced claim in the UI was limited to `policy condition detected` and `over limit` labels. The Phase-14 conservative stub in `AndroidEnforcementPlatform` returned `unsupported` with reason `android_app_blocking_not_implemented` for every restriction attempt, and a pre-M8 guardrail test (`test/child_device_status_screen_test.dart`) pinned that behavior as the accepted non-claim. All M1–M7 suites were GREEN at 197/197, and the deployed production ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc` already contained the `devices/{deviceId}/enforcement_status/{statusId}` match block, although nothing in the app yet wrote to it.

## 3. M8 Scope as Defined by the Roadmap

The canonical roadmap §14 defines M8 as the milestone that converts policy decisions into actual device behavior and makes the entire safety loop survive process death, reboot, and Doze. Included are app-blocking or restriction enforcement through a legitimate Android path (documented and Play-policy-compliant, with a stated bypass-handling policy), bedtime-window enforcement derived from `DigitalPolicy` schedules, a watchdog that re-evaluates on process restart using durable state, reboot and Doze behavior with explicit evidenced claims, and transparent on-device indication when enforcement is active. Excluded are system-wide surveillance claims, accessibility-service abuse, Device Owner provisioning, SMS fallback (M13), and AI-driven enforcement (M10+). Backend requirements are explicitly "none new" because enforcement is device-local by design, consistent with the offline-first architecture.

## 4. Gap Inventory Discovered Before Implementation

The pre-implementation audit identified the following gaps, classified against the roadmap acceptance gates and the mandate's honesty contract.

| ID | Gap | Classification | M8 Treatment |
| -- | --- | -------------- | ------------ |
| M8G-01 | No enforcement mechanism exists; the adapter returns `unsupported` for every restriction | TECHNICAL GAP — M8 scope | Closed: honest notification-verified enforcement contract replaces the Phase-14 stub |
| M8G-02 | No domain vocabulary for enforcement states | TECHNICAL GAP — M8 scope | Closed: `EnforcementState` (11 values), `EnforcementApplication`, `EnforcementSyncState`, snapshot models |
| M8G-03 | Policy freshness evaluated only at decision time with no durable enforcement state table | TECHNICAL GAP — M8 scope | Closed: SQLite schema v13 `child_enforcement_states` table (fresh and upgrade paths) |
| M8G-04 | No background re-evaluation; restriction silently dies on process death | TECHNICAL GAP — M8 scope | Closed: transparent foreground service + WorkManager re-evaluation + boot receiver |
| M8G-05 | No on-device UI for enforcement state | UX GAP — M8 scope | Closed: `_EnforcementSection` + `_EnforcementCard` on the child context screen with honest labels |
| M8G-06 | Deployed ruleset `enforcement_status` match exists but has no harness proof | HARNESS GAP — M8 scope | Closed: 7 new deployed-rules scenarios appended and GREEN against the live ruleset |
| M8G-07 | Pre-M8 guardrail test pins the Phase-14 stub behavior | TEST REGRESSION RISK | Closed: guardrail test updated to the new honest contract (fixture update, behavior strengthened) |
| M8G-08 | Physical-device evidence (enforcement applied, process death, reboot, Doze, network loss, permission revocation, stale policy) | PHYSICAL DEVICE — Gate 13 | Not closable from the sandbox. Registered as GA-08–GA-15, all READY — PHYSICAL DEVICE REQUIRED |
| M8G-09 | Real signed-in outbox delivery to `SyncState.synced` | HUMAN ACTION REQUIRED | Not closable from the sandbox. GA-01/GA-02 remain HUMAN ACTION REQUIRED |
| M8G-10 | `foregroundServiceType` declaration for Android 14+ (Play Store distribution) | PRODUCTION PROMOTION | Registered GA-26-equivalent note: required before Play Store release; outside M8 code gates |
| M8G-11 | M7 `ScreenTimeSection` label style must remain non-enforcement ("policy condition detected") | HONESTY CONTRACT | Preserved by design; M8 UI uses `enforcementApplied` vocabulary only for the enforcement section |

## 5. Honest Claims and Non-Claims

The audit locks the honesty boundary before implementation. **Claimable after implementation**: enforcement requested is a distinct observable step before application; application requires verified platform confirmation and never a synthetic success; policies version monotonically and an older version can never replace a newer one; a stale, missing, or unknown policy can never produce an enforcement action (it fails to `policyStale`); offline enforcement holds on local truth until the documented watermark expires; reboot recovery is implemented through a real broadcast receiver with durable reload; revocation immediately drops enforcement authority; M6 temporary overrides flow through the resolver unchanged and expired overrides fall back to the policy decision.

**Non-claims locked in this audit**: a consumer app cannot block or kill another app on Android without enterprise device-owner privileges, so no "Blocked" claim may appear anywhere; recovery after an Android force-stop is not automatic on modern Android and is documented as a platform limitation; deep-Doze real-time enforcement is best-effort; the GREEN physical-evidence gates (GA-08–GA-15) cannot be satisfied without a physical device or AVD; `SyncState.synced` cannot be claimed without a real signed-in outbox delivery; and the override expiry guard lives on the client device, while the absence of a matching server-side rule on parent-only override documents remains a documented, prepared non-claim (GA-22).

## 6. Security Boundary

M8 adds no new attack surface to membership, binding, authorization, or rules. The enforcement chain reuses the existing `ChildPolicyResolver` validity contract (revocation, delivery, monotonic version, seven-day freshness watermark) so that no decision can reach enforcement unless the policy is locally valid. The only new remote path is the child-app write to its own `enforcement_status/current` document, which the deployed ruleset already constrains to `statusId == 'current'` on an active owned device with full lineage invariants and a universal delete denial. The M8 harness appends proof of these constraints against the live ruleset. Nothing in `FamilyRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, the SQLite repositories, the outbox, Firestore rules, or Functions is modified by the M8 feature set; the only repository additions are enforcement-state recording and sync queuing, which append to the existing tables.

## 7. Change Boundary

The M8 program modifies the files listed in the completion report and test evidence documents. It does not modify Firebase configuration (`firebase_options.dart`, `google-services.json`, `firebase.json`, `.firebaserc`), does not modify any Phase 17/18 security or business logic beyond the Phase-14 stub replacement, does not touch the `phase17-stable-checkpoint` branch, activates no Blaze billing, and writes no production data. The audit concludes with the milestone ready to proceed to implementation under the locked claim/non-claim boundary above.


## Truth-Gate Audit Addendum (2026-08-14, Workstream A)

A post-implementation code-level audit reclassified `applyEnforcement()` as **MONITORING-ONLY**. The actual OS actions performed are `UsageStatsManager` foreground observation, a transparent foreground service with a persistent family notification, and a durable local record; no consumer-legal API call blocks, kills, or restricts a third-party app. The feature is honestly classified as the **"M8 Enforcement Foundation"** with `Actual Consumer-App Restriction = NOT PROVEN` (register GA-08, BLOCKED — ENFORCEMENT TRUTH GATE). On API 34+ the service lacks `foregroundServiceType` and therefore **cannot start** on the owner's SM-S906U (Android 16 / API 36) until an owner-approved service-type path is applied (`docs/UX_SPRINT_01_M8_PHYSICAL_VALIDATION_PLAN.md`). Gate 13 physical evidence for all twelve enforcement scenarios remains **HUMAN ACTION REQUIRED**; nothing in this document elevates any enforcement claim beyond monitoring evidence.
