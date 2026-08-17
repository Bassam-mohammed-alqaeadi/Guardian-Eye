# Guardian Eye Pro — Gap Audit Before Vertical Slices

**Audit basis:** source tree, SQLite schema, Flutter analysis, widget tests, Firebase rule templates, and platform-host files present in the current project.

| Requirement | Classification | Evidence and precise gap |
|---|---|---|
| Flutter canonical stack | IMPLEMENTED + VERIFIED | The active source is Flutter/Dart; `flutter analyze` and the available widget test previously passed in the executable environment. |
| Family creation and local persistence | IMPLEMENTED + NOT YET VERIFIED | `FamilyRepository.createFamily` writes the family, primary parent, and outbox event transactionally. A repository test is still missing. |
| Child profile creation | IMPLEMENTED + NOT YET VERIFIED | `addChild` persists a child and queues `member.created`; update/remove and validation tests are missing. |
| Child device link, ownership, and state | PARTIALLY IMPLEMENTED | Device table and roles exist; lifecycle, owner binding, state transitions, revoke/unlink, and UI are absent. |
| Pairing request | PARTIALLY IMPLEMENTED | Random six-digit request, SHA-256 hash, expiry, and QR representation are present. Code verification, enrollment, ownership, rejection/revoke, and offline failure lifecycle are absent. |
| Parent authorization | ARCHITECTURE ONLY | Role enum and Firestore rule template exist; no local authorization service or verified Firebase account context exists. |
| Policy engine | NOT IMPLEMENTED | Policy storage schema exists, but no domain evaluator, precedence logic, override lifecycle, repository, UI, outbox flow, or test exists. |
| Incident / safety lifecycle | ARCHITECTURE ONLY | Incident table and status enums exist; there is no model adapter, risk evaluator, incident repository, acknowledgement flow, outbox event, or notification event. |
| On-device AI inference | BLOCKED BY ENVIRONMENT | No reviewed TensorFlow Lite artifact, labels, model card, threshold specification, or device validation is available. |
| SOS local event | IMPLEMENTED + NOT YET VERIFIED | SOS action stores a local event/outbox payload with consent-gated location. Repository tests and all state transitions are absent. |
| SOS remote delivery and parent acknowledgement | NOT IMPLEMENTED | No backend command handler, FCM event, acknowledgement service, or delivery evidence exists. |
| Offline outbox and retry | PARTIALLY IMPLEMENTED | Outbox schema and Firebase guarded sender exist; no deterministic retry/backoff worker, conflict policy implementation, duplicate test, or process-death test exists. |
| Firebase auth / Firestore backend | HUMAN ACTION REQUIRED | Flutter package references and rule templates exist, but no Firebase project/configuration, generated options, authenticated runtime, or deployed rules exist. |
| Firestore family isolation and role boundaries | ARCHITECTURE ONLY | Rule templates express the intended boundary; emulator deployment and authorization tests are missing. |
| FCM notification delivery | HUMAN ACTION REQUIRED | Firebase Messaging package is present, but APNs/FCM credentials, handlers, tokens, backend event producer, and physical delivery tests are absent. |
| Android platform capabilities | IMPLEMENTED + NOT YET VERIFIED | Manifest declarations and a transparent settings channel exist; physical Android validation and policy review are required. |
| iPhone host / privacy strings | IMPLEMENTED + NOT YET VERIFIED | iOS host and usage descriptions exist; macOS/Xcode build, signing, and device tests are required. |
| Payments and carrier SMS | NOT IMPLEMENTED | No official merchant/carrier APIs or credentials are supplied. |

> UI-only work is not classified as completed functionality. Each upcoming slice must include domain behavior, SQLite persistence, outbox semantics, error/recovery states, and tests; Firebase delivery remains conditional on valid configuration and authorization.
