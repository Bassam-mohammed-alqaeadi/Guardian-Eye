# Phase 15 Gap Audit

| Capability | Current implementation | Evidence level | Remaining requirement |
|---|---|---|---|
| Child pairing and identity separation | Existing pairing/lifecycle path retained; tests cover one-time enrollment and replay protection. | **IMPLEMENTED + VERIFIED LOCALLY**; existing **VERIFIED IN EMULATOR** provisioning evidence. | Physical child enrollment and revocation evidence. |
| Daily-limit policy | `DigitalPolicy` carries optional validated `dailyLimitMinutes`; SQLite, Outbox, Firestore contract, delivery, and policy editor preserve it. | **IMPLEMENTED + VERIFIED LOCALLY** | Child-to-Emulator and real-device policy delivery. |
| Usage observation | Kotlin bridge queries `UsageStatsManager` only for policy targets after Usage Access; Flutter maps permission/no-data/unsupported states. | **IMPLEMENTED — VALIDATION BLOCKED** | APK/Kotlin compilation and physical Android permission/device evidence. |
| Screen-time accounting | Cumulative daily summaries are monotonic per device/day/target, persisted locally, and evaluated through a pure engine. | **IMPLEMENTED + VERIFIED LOCALLY** | Compare against a physical device’s observable Android data. |
| Enforcement truthfulness | Exceeded limit produces domain `restrict` / `enforcementRequested`; adapter returns `unsupported` for unmanaged normal Android app blocking. | **IMPLEMENTED + VERIFIED LOCALLY** | A future managed-device mechanism with OS acknowledgement, if approved. |
| Usage telemetry authorization | Active child device can create scoped usage summary; parent, revoked device, and cross-family writes are denied. | **VERIFIED IN EMULATOR** | Explicit owner-approved real Firebase rules deployment and real-client validation. |
| Parent experience | Parent can configure an optional daily limit, review today’s local summaries, and request on-demand measurement. | **IMPLEMENTED + VERIFIED LOCALLY** | Physical rendering and real Usage Access behavior. |
| Child transparent experience / exception request | Parent explanation is truthful; no child-authenticated exception request UI is fabricated. | **NOT IMPLEMENTED** | Separate child-mode identity and reviewed request-delivery slice. |
| General Android app blocking | Not implemented. | **NOT IMPLEMENTED** | A separate Device Owner/DPC product decision, consent/provisioning, policy review, and physical proof. |
| Background monitor, Doze, reboot recovery | Durable local state exists only. | **NOT IMPLEMENTED** | Separate lifecycle architecture and physical evidence. |
| Real Firebase update | No Phase 15 rules or indexes were deployed. | **IMPLEMENTED — VALIDATION BLOCKED** | Explicit owner authorization to change real Firebase configuration. |
