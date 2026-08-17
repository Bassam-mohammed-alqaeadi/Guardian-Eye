# Phase 14 Architecture — Child Device Enforcement Foundation

## Objective and boundary

Phase 14 establishes a **truthful enforcement foundation**, not a claim that Android application blocking is already live. The implementation separates policy configuration, delivery, local persistence, deterministic resolution, domain decision, platform capability, and applied operating-system action.

```text
Parent policy → Firestore family policy read → child delivery boundary
      → SQLite child policy store → pure PolicyResolver → EnforcementEngine
      → Android enforcement adapter → truthful applied-status telemetry
```

The existing Outbox remains the authoritative path for parent-originated changes. Child-device health and evaluation telemetry are independent from policy authority and must never be interpreted as proof that a restriction was applied by Android.

## Components

| Layer | Responsibility | Authority boundary |
|---|---|---|
| `ChildDeviceStateMachine` | Validates and records lifecycle transitions. | Cannot change family ownership or pairing identity. |
| `ChildPolicyDeliveryRepository` | Stores signed-in child-visible policy snapshots transactionally, preserves the newest version, and retains last valid data offline. | Does not infer a remote acknowledgement. |
| `ChildPolicyResolver` | Purely determines current policy validity and restriction intent. | Has no platform APIs or side effects. |
| `EnforcementEngine` | Converts a resolved policy and child state into a deterministic domain decision. | Has no Android API access. |
| `AndroidObservationGateway` | Reads only disclosed, user-consented Android Usage Stats data when available. | Does not use hidden APIs, Accessibility, or silent permission changes. |
| `AndroidEnforcementAdapter` | Reports exactly what the current Android capability can or cannot apply. | Never reports an OS restriction without evidence. |
| `ChildDeviceStatusScreen` | Shows parent-visible state, policy version, readiness, offline/revocation state, and evaluation status. | Never represents configuration as enforcement. |

## Delivery strategy

Family members may read family policies under the existing rules, including a properly authenticated child identity. The current rules intentionally do **not** expose `policy_overrides` to child identities. Phase 14 therefore supports locally delivered temporary overrides in the resolver but does not claim remote child delivery of an override until a server-mediated, child-targeted contract exists and is verified.

Every delivery record is family and device scoped. A lower policy version cannot replace a newer locally stored policy; an equal version is idempotent; a higher version replaces the prior snapshot. Offline evaluation uses the last valid snapshot until it becomes stale under the configured policy-age boundary.

## Lifecycle and recovery

The foundational storage is SQLite-backed. Process death and reboot recovery mean that the next explicit application/service entry point loads state and re-evaluates the last valid local policy; they do **not** mean that Phase 14 introduces an always-running or reboot-surviving Android enforcement service. A future Android worker/service requires a separate consent, lifecycle, battery, and physical-device validation slice.

## Non-goals

Phase 14 does not implement Usage Stats production proof, Accessibility activation, overlay blocking, Device Owner, hidden APIs, screen capture, background polling, boot receivers, actual application blocking, or on-device AI inference.
