# Guardian Eye Pro — Current Reconciled Gap Audit (Phase 6)

This audit is based on the current source tree after local SQLite repositories, policy persistence, notification-event contracts, and Firestore rule hardening. It supersedes earlier gap audits where they disagree.

| Requirement | Location | Locally executable | Test/evidence | Environment dependency | Final classification |
|---|---|---|---|---|---|
| Family + primary parent + child + local outbox transaction | `FamilyRepository`; SQLite schema; `local_repository_test.dart` | Yes | Persistence, outbox, and FK rollback tested | None for local behavior | IMPLEMENTED + VERIFIED (local) |
| Role / device-owner authorization | `FamilyAuthorization`; device owner columns | Yes | 3 domain boundary tests | Firebase for server-side enforcement | IMPLEMENTED + VERIFIED (domain) |
| Pairing request, SHA-256, expiry code path, five-attempt lockout, enrollment, owner binding, reuse rejection, revocation | `PairingRepository`; schema v3; repository test | Yes | Lockout, enrollment once, owner mismatch, and revocation tested | Firebase/physical child device for remote pairing | IMPLEMENTED + VERIFIED (local core); expiry needs a controllable clock test |
| Policy priority, conflict, disabled state, temporary override, expiration behavior | `PolicyEngine`, `PolicyRepository`; policy override table | Yes | Priority/override unit test and SQLite policy/outbox test | Firebase for sync | IMPLEMENTED + VERIFIED (local) |
| Policy CRUD UI, remote sync, conflict resolution | Schema/repository only | No full vertical remote path | No sync test | Firebase emulator/backend | PARTIALLY IMPLEMENTED |
| Model unavailable state and risk decision | `SafetyModelAdapter`, `RiskEngine` | Yes | Risk and lifecycle tests | Reviewed model artifact for inference | IMPLEMENTED + VERIFIED (abstraction); AI inference BLOCKED |
| Incident persist, outbox, local notification request, acknowledgement | `IncidentRepository`, notification event table | Yes | SQLite incident/notification/ack test | Firebase/FCM for remote delivery | IMPLEMENTED + VERIFIED (local) |
| SOS pending sync, local outbox, notification request, valid state contract | `SosRepository`, `SosLifecycle` | Yes | SQLite contract test and lifecycle test | FCM/location/SMS/device for final delivery | IMPLEMENTED + VERIFIED (local) |
| Outbox backoff/max attempts | `OutboxRetryPolicy` | Yes | Retry policy tests | Worker/device for recovery validation | IMPLEMENTED + VERIFIED (domain) |
| Outbox executor/idempotency/conflict/recovery | Unique DB key plus contracts | No complete executor | No worker test | Firebase emulator and Android background runtime | PARTIALLY IMPLEMENTED |
| Firebase Auth/context/Firestore repository | Guarded transport only | No configuration | No Firebase runtime evidence | Firebase project + FlutterFire | HUMAN ACTION REQUIRED |
| Family/device/incident/SOS Firestore authorization | `firebase/firestore.rules` | Template only | Emulator security plan created, not executed | Firebase Emulator/project | ARCHITECTURE ONLY / HUMAN ACTION REQUIRED |
| Parent notification architecture | Notification event table + guarded FCM gateway | Local request only | SQLite notification-event test | Backend producer, FCM/APNs, token, device | IMPLEMENTED ARCHITECTURE; PHYSICAL DELIVERY NOT VERIFIED |
| Android/iPhone native verification | Android/iOS host setup | No | No build/device proof this phase | Android SDK/device; macOS/Xcode/iPhone | BLOCKED BY ENVIRONMENT |

> The policy engine and local incident pipeline are now classified by their actual source and test evidence, not by an obsolete audit. No row implies deployed Firebase, FCM delivery, AI inference, APK, or physical-device validation.
