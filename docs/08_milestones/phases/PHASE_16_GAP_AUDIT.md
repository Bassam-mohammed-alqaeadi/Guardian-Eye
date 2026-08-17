# Phase 16 Gap Audit

| Requirement | Current state | Evidence level | Remaining gap |
|---|---|---|---|
| Baseline forensic audit | Complete in `PHASE_16_BASELINE.md`. | **IMPLEMENTED + VERIFIED LOCALLY** | None for this slice. |
| Parent daily dashboard | Live dashboard links to local daily safety read model. It shows only existing data and a localized not-measured state. | **IMPLEMENTED + VERIFIED LOCALLY** | Physical rendering and real-device data. |
| Child explanation | Child-scoped screen provides rule, usage, readiness, offline, exception, and truthful enforcement wording. | **IMPLEMENTED + VERIFIED LOCALLY** | Wire into a real child-authenticated application session. |
| Exception request | Domain, SQLite persistence, validation, duplicate prevention, child cancellation, parent review, and expiry are implemented. | **IMPLEMENTED + VERIFIED LOCALLY** | Cross-device child→parent sync/read-back on a runtime client. |
| Atomic approval + override | Reuses `PolicyRepository` and `StoredPolicyOverride` in one transaction; override is scoped to the requesting device. | **IMPLEMENTED + VERIFIED LOCALLY** | Remote delivery/read-back across actual child/parent sessions. |
| Denial and expiration | Implemented locally; override resolver uses timestamp expiry without a worker. | **IMPLEMENTED + VERIFIED LOCALLY** | Device clock/lifecycle validation. |
| Local timeline | Implemented as a composed local read model with Outbox state labels. | **IMPLEMENTED + VERIFIED LOCALLY** | Server acknowledgement model if “remote confirmed” is later required. |
| Firestore child/parent authorization | Child own request, parent read/review, and denial boundaries are exercised. | **VERIFIED IN EMULATOR** | Explicit real-backend rules deployment and client validation. |
| Arabic RTL and English LTR | Parent review and child explanation widgets are validated in Arabic and English. | **IMPLEMENTED + VERIFIED LOCALLY** | Device typography/layout review. |
| Android app blocking | Adapter remains truthful: no universal app blocking exists. | **NOT IMPLEMENTED** | Managed-device product decision and OS acknowledgement. |
| Background/Doze/reboot | No worker or receiver is added; timestamp evaluation is correct only when the app evaluates state. | **NOT IMPLEMENTED** | Separate lifecycle slice and physical evidence. |
| Firebase deployment | No Phase 16 deployment performed. | **IMPLEMENTED — VALIDATION BLOCKED** | Owner approval and deployment verification. |
| APK/physical device/FCM | No artifact, device evidence, or new FCM delivery. | **PHYSICAL DEVICE REQUIRED** | Suitable Android host/device and separate validation protocol. |
