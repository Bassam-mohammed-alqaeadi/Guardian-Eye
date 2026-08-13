# UX Sprint 01 — M8 Enforcement Capability Decision

**Date:** 2026-08-14 (UTC+3) · **Baseline:** `d61e2d2` (`master` = `origin/master`) · **Author:** Manus AI · **Type:** product/architecture decision document · **Status:** DECIDED — no code or manifest changes; awaiting owner execution actions

This document is the mandated product/architecture decision analysis for the M8 enforcement capability. It fixes the current classification on direct code-level evidence, analyzes the three realistic future capability paths, and records what is decided, what is deferred, and why. Nothing in this document modifies source code, tests, or the repository tree.

---

## 1. The current classification is fixed and must not be weakened

The code-level audit traced the entire chain — `ChildPolicyResolver.resolve` → `PolicyEngine.resolve` → `ChildEnforcementCoordinator.evaluate` → `AndroidEnforcementAdapter.applyAndVerify` → `EnforcementPlatformChannel` → Kotlin `MainActivity.startEnforcementMonitoring` → `EnforcementService` (UsageStatsManager read loop) — and verified a negative fact with certainty: **there is no call anywhere in the Kotlin code to any OS-level restriction API.** No `DevicePolicyManager`, no `setPackagesSuspended`, no `killBackgroundProcesses`, no `forceStopPackage`, no `AppOpsManager.setMode`, no AccessibilityService implementation. The service reads foreground events and persists observation proofs; it never stops, suspends, or kills another application.

The classification therefore remains, permanently for the current consumer build:

> **M8 = ENFORCEMENT FOUNDATION / MONITORING-ONLY. Actual consumer-app blocking = NOT PROVEN.**

Every UI label already honors this: the app says "القيد مفعّل" (restriction verified as applied — meaning the monitoring contract was verified), "مراقبة نشطة" (observation active), and "تم تجاوز الحد" (limit exceeded detection) — never "Blocked"/"محظور". The UI honesty rule (no enforcement claims without platform verification) stands and this decision reinforces it.

---

## 2. Path A — Consumer mode (the current and shipping mode)

Consumer mode is the product that ships on Google Play today: monitoring of foreground application usage via UsageStatsManager, policy awareness with honest enforcement states, transparent child-facing notification (the family notification that persists while monitoring is active), and zero false "blocked" claims. This mode is complete, tested (217/217 Flutter, 23/23 deployed-rules harness), and honestly scoped. **Decision: SHIP as-is. No changes.**

## 3. Path B — Managed-device future mode (Device Owner / Profile Owner)

`DevicePolicyManager.setPackagesSuspended` — the API that actually suspends packages — is restricted by the platform itself: it can only be called by a **device owner, profile owner, or their delegate** [1]. A consumer app distributed on Google Play cannot become a device or profile owner on an arbitrary family device; ownership requires device-provisioning flows (Device Policy Controller enrollment, Android Enterprise, zero-touch enrollment) that are a completely different distribution channel. Google's own Family Link operates on this managed-device architecture through Google's system-level supervised infrastructure, which third-party consumer apps cannot replicate through the Play Store.

This makes the decision straightforward: the managed-device path is a **separate optional edition**, not a feature flag in the consumer app. The analysis concludes that a future "Guardian Eye Pro — Managed Device Edition" is architecturally viable (the M8 monitoring foundation, policy engine, and outbox sync are edition-agnostic and would be reused), but it requires a DPC component, an Android Enterprise / partner enrollment flow, and a separate release channel. It must never be advertised, implied, or stubbed in the consumer Google Play build. **Decision: DEFERRED — record as a future optional edition in the roadmap (not implemented now, not consumer Play content).**

## 4. Path C — Accessibility path

The Accessibility Service API is **not automatically prohibited** by Google Play. The policy framework requires, for any app that uses it: a declaration in the Play Console Permissions Declaration Form, an in-app **prominent disclosure presented before the flow that uses the API**, explicit consent with a decline option and graceful degradation, and a complete privacy policy plus Data safety section [2]. Notably, Google's own policy document uses the family-safety scenario as its primary example of a legitimate use case:

> "An example of this could be an app that collects browser history to detect and block a child from sensitive content using Accessibility Service APIs." [2]

So the Accessibility path is **legitimate in principle but high-friction in practice**: the declaration form is reviewed by Google, disclosure/consent flows must be designed, and rejection is common when disclosure is insufficient [2] [3]. If ever pursued, it would require (1) a dedicated consent flow in the app, (2) a Play Console declaration with a demonstration video, and (3) an explicit decision about whether per-app "blocking-style" UX is acceptable for this product's honesty policy. **Decision: DEFERRED — documented as a viable but declaration-dependent future path; no implementation.**

## 5. Decision summary table

| Path | Status | Verdict | Condition to activate |
|---|---|---|---|
| A. Consumer monitoring (M8 as shipped) | **ACTIVE** | Ship as-is | — |
| B. Managed-device edition (setPackagesSuspended / Device Owner) | **DEFERRED** | Future optional edition, never in consumer Play mode | Owner decides to pursue DPC/Android Enterprise channel |
| C. Accessibility Service | **DEFERRED** | Viable under Play disclosure/consent framework; not prohibited | Owner accepts Play declaration + in-app disclosure/consent design work |

The current API 34+ foreground-service blocker (Path decision in the companion pre-push report) interacts with this table: whichever foreground-service legitimacy path the owner chooses applies **only to the monitoring service of the consumer mode**; it has no bearing on Paths B and C, which are structurally separate.

---

## References

[1]: https://developer.android.com/reference/android/app/admin/DevicePolicyManager#setPackagesSuspended(android.os.UserHandle,%20java.lang.String%5B%5D,%20boolean) "DevicePolicyManager.setPackagesSuspended — Android Developers"
[2]: https://support.google.com/googleplay/android-developer/answer/11150561 "Best practices for prominent disclosure and consent — Google Play Help"
[3]: https://support.google.com/googleplay/android-developer/answer/9888170 "Permissions Declaration Form — Google Play Help"

- [1] [DevicePolicyManager.setPackagesSuspended — Android Developers](https://developer.android.com/reference/android/app/admin/DevicePolicyManager#setPackagesSuspended(android.os.UserHandle,%20java.lang.String%5B%5D,%20boolean))
- [2] [Best practices for prominent disclosure and consent — Google Play Help](https://support.google.com/googleplay/android-developer/answer/11150561)
- [3] [Permissions Declaration Form — Google Play Help](https://support.google.com/googleplay/android-developer/answer/9888170)
