# Guardian Eye Pro — M8 Physical Validation Plan

Pre-planned physical-device validation for the M8 enforcement chain. This plan is written **before** execution so that every scenario has a fixed, repeatable sequence, an expected honest outcome, and an evidence requirement. It was authored on 2026-08-14 after the code-level truth-gate audit classified `applyEnforcement()` as **monitoring-only** with `Actual Consumer-App Restriction = NOT PROVEN` (register GA-08, BLOCKED — ENFORCEMENT TRUTH GATE).

## 0. Pre-Condition Blocker (must be resolved first)

The M8 `EnforcementService` declares no `foregroundServiceType`, which means Android API 34+ throws on `startForeground` and the service **cannot start**. The owner's registered device (SM-S906U, Android 16 / API 36) is therefore **blocked for every scenario below** until one of these owner-approved paths is taken:

| Path | What changes | Considerations |
| ---- | ------------ | -------------- |
| P-A | Declare `foregroundServiceType="dataSync"` + declare the corresponding permission, verify against Play Store data-safety and restricted-declaration policies | `dataSync` requires an eligible user-facing sync use case and Play declaration; the family-sync notification content supports it, but policy compliance is the owner's decision |
| P-B | Restrict enforcement support to API 33 devices until P-A is approved | Honest limitation; the app already reports honest states |
| P-C | Defer enforcement entirely and keep M8 as a measured, reported, durable-evidence foundation | Feature name stays "M8 Enforcement Foundation" |

Scenarios 1–12 execute only after this blocker is resolved. Execute scenarios 0 before all others.

## 1. Scenario 0 — Service Startability (API 34+)

With the chosen path applied, install the debug APK, launch the child profile, and confirm the foreground service starts with its minimal persistent notification. **Expected honest outcome:** the app never claims "Blocking"; the enforcement UI shows the monitoring state in Arabic with the honest label. **Evidence:** `adb logcat | grep EnforcementService`, screenshot of the persistent notification, screenshot of the child-context enforcement card.

## 2. Scenario 1 — Enforcement State Lifecycle

Parent creates a video policy (daily limit, e.g., 30 minutes) for the child device; the child app consumes it and the enforcement card transitions from `Evaluation ready` to `Monitoring` and back, in Arabic. **Evidence:** logcat sequence + UI screenshots matching the state vocabulary (`مراقبة نشطة` / active monitoring, `تم تجاوز الحد` / over limit detected).

## 3. Scenario 2 — Result Registration and Outbox Delivery

While over the limit, the child app records `EnforcementApplication` rows and enqueues them; after connectivity returns, rows transition `queued → synced` (register GA-02) and the parent app displays the honest record. **Evidence:** `adb logcat | grep Outbox`, SQLite inspection, parent-app sync-state label.

## 4. Scenario 3 — Enforcement Release

Parent revokes the restrictive policy or relaxes the limit; the child app re-evaluates at the next 15-minute window and the state returns to evaluation-ready/monitoring. **Evidence:** parent policy change + child state transition log.

## 5. Scenario 4 — Process Death Recovery

Kill the child app process mid-enforcement (`adb shell am force-stop com.guardianeye.app` does NOT count here; use system-app force kill or battery-optimization kill). **Expected honest outcome:** no crash claims; on next launch the app reloads durable policy state and re-computes. **Evidence:** ADB log of the recovery sequence.

## 6. Scenario 5 — Force-Stop Platform Limitation

Force-stop from system settings and document the real behavior: WorkManager and broadcast receivers are cancelled by the platform; the service resumes only when the app is launched again or via scheduled check. **Evidence:** log showing the honest `suspended`/unavailable state, plus the documented limitation section in the M8 docs.

## 7. Scenario 6 — Reboot Recovery

Reboot with active enforcement; `BootReceiver` reschedules the WorkManager check and the app reloads policy on launch. **Evidence:** ADB boot log showing re-establishment within one evaluation window.

## 8. Scenario 7 — Doze / Power Management

With battery optimization unrestricted, verify WorkManager scheduling and the foreground service survive Doze; with optimization restricted, document the honest degradation. **Evidence:** standby-bucket observation (`adb shell dumpsys deviceidle`), battery log.

## 9. Scenario 8 — Network Loss

Cut network during active enforcement; the app keeps evaluating locally (UsageStats is local) and enqueues results; on restore, sync completes. **Evidence:** log sequence across the offline window.

## 10. Scenario 9 — Permission Revocation

Revoke `PACKAGE_USAGE_STATS` on the device; the app transitions to the honest unverified state instead of claiming measurement. **Evidence:** revocation + state transition log.

## 11. Scenario 10 — Stale / Revoked / Superseded Policy

Parent edits the policy (supersede, version bump) while the child is offline; the child detects `policy_version_stale` honestly and keeps the last-known-good policy until a fresh one arrives. **Evidence:** version-sequence log.

## 12. Scenario 11 — Device Revocation by Parent

Parent unlinks the child device; the child's next policy fetch fails honestly and enforcement evaluation stops with an honest state. **Evidence:** unlink + child state log.

## 13. Scenario 12 — Temporary Override Expiry

Parent grants a temporary override (e.g., +30 minutes); the child honors it while active and automatically falls back to the policy decision after expiry. **Evidence:** override grant → active state → expiry → fallback log.

## 14. Evidence Format

Every executed scenario records: device model + Android version, APK build hash, scenario number, step-by-step commands used, raw logcat excerpts, UI screenshots, pass/fail verdict, and the honest-state label actually displayed. No verdict is marked PASS on emulator-only or harness-only evidence; physical evidence is mandatory for these scenarios.

## 15. Rollback

All scenarios run on the debug APK with a test family. Uninstalling the app removes the child-device rows; the parent can unlink the device and delete the test family. No production-family data is required.
