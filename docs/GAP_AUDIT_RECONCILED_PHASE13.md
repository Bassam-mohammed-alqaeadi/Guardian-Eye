# Reconciled Gap Audit — Phase 13

## Reconciliation statement

Phase 13 selected one dependency-ready vertical slice rather than expanding the product surface: **family safety policy management**. The selection is complete across local storage, domain evaluation, Outbox contract, Firestore authorization, and parent configuration UI. The audit does not convert configuration into a claim of child-device enforcement.

| Product capability | Previous position | Phase 13 reconciliation | Evidence level | Remaining gap |
|---|---|---|---|---|
| Scheduled safety policies | Policy engine and SQLite storage existed, but mutability and user management were incomplete. | Create, edit, version, toggle, list, and explain policies using real SQLite data. | **IMPLEMENTED + VERIFIED LOCALLY** | Physical UI interaction test. |
| Policy synchronization | Generic Outbox existed but policy mutations did not include complete remote data. | Policy creation/update/override mutations now carry the required data and list state derives from Outbox. | **IMPLEMENTED + VERIFIED LOCALLY** | Flutter-client sync/read-back on Emulator and real backend. |
| Policy authorization | Parent-only Firestore policy rule existed but lacked focused verification and override rule parity. | Parent-only policies and policy overrides tested in Emulator; reviewed rules/indexes deployed to `manus-guardian`. | **VERIFIED IN EMULATOR**; deployment **VERIFIED ON REAL BACKEND** | Real client allow/deny operations with redacted evidence. |
| Temporary exceptions | Ephemeral domain type existed. | Persistent override with creator, expiry, sync state, Outbox mutation, and parent UI entry point. | **IMPLEMENTED + VERIFIED LOCALLY** | Device-time and process-restart validation. |
| Arabic and English experience | Core localization existed. | Policy titles, form labels, statuses, states, warnings, and error/retry text added in Arabic and English. | **IMPLEMENTED + VERIFIED LOCALLY** | RTL visual validation on Android/iPhone. |
| Android app blocking / Usage Stats | Not implemented. | Deliberately excluded to prevent false enforcement claims. | **NOT IMPLEMENTED** | Separate consent-oriented Android enforcement slice. |
| Background policy application | Not implemented. | Deliberately excluded. | **NOT IMPLEMENTED** | Android lifecycle, Doze, reboot, and background service design. |
| Firebase Functions deployment | Source and Emulator tests existed. | Remains blocked on billing plan; not retried or bypassed. | **IMPLEMENTED — VALIDATION BLOCKED** | Owner-approved Blaze enablement. |
| Physical Android and iOS | No validated artifact/device. | No false completion added. | **HUMAN ACTION REQUIRED** | Build host, device/AVD, and macOS/Xcode. |

## Acceptance criteria reconciliation

| Criterion | Status | Evidence |
|---|---|---|
| Parent can persist a scoped policy offline. | Met. | SQLite repository tests and Outbox transaction coverage. |
| Policy update increments a version and creates a durable mutation. | Met. | `local_repository_test.dart`. |
| Parent can enable/disable an existing policy. | Met. | Repository test plus UI switch wiring. |
| Parent can create a temporary allowance. | Met locally. | Repository override test and UI action wiring. |
| Child cannot write policy and unrelated parent cannot write across families. | Met in Emulator. | Firestore rules test suite. |
| The selected rules/indexes are available on the project reference backend. | Met. | Successful Firestore-only deployment to `manus-guardian`. |
| A child device is blocked at schedule time. | Not in scope. | No enforcement adapter exists or is claimed. |
| A real Flutter client syncs policy changes on a device. | Not yet met. | APK/AVD/device blocker remains. |

## Next priority recommendation

The next vertical slice should not begin with app blocking. First validate this policy-management data flow from Flutter on an Android device or AVD against the Firebase Emulator, including offline edit, restart, reconnect, Outbox delivery, and Firestore read-back. That establishes runtime evidence before adding a privileged Android capability. After it, the appropriate next product slice is a consent-first Android policy enforcement adapter with explicit capability discovery and no hidden monitoring.
