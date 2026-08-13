# Firebase Emulator Test Plan — Phase 7

## Environment setup

Install Node.js LTS and Firebase CLI, authenticate locally, initialize Firestore/Auth/Functions emulators for the Firebase project, then configure the Flutter test target to use Emulator host/ports only in a non-production build. Seed two families, two parents, a child, one active child device, one unpaired device, and one revoked device. Do not run the plan against production.

## Required authorization matrix

| Test | Actor | Expected result |
|---|---|---|
| Read Family A | Parent A | Allow. |
| Read Family B | Parent A | Deny. |
| Update policy | Child A | Deny. |
| Change own member role to primary parent | Child A | Deny. |
| Create incident/SOS | Active device A | Allow only for Family A and its bound device ID. |
| Create incident/SOS | Unpaired or revoked device | Deny. |
| Read incident/SOS history | Child A | Deny. |
| Acknowledge incident | Parent A in Family A | Allow. |
| Write notification event | Any mobile client | Deny. |
| Re-submit the same event ID/idempotency key | Active authorized client | Remote state remains one document; no duplicate business record. |

## Flow tests and reset

For the primary flow, authenticate Parent A, create family/member/device records locally, execute due outbox events to Emulator, verify Firestore paths and owner fields, restart the local process, execute again, and verify no duplicate remote business document appears. Repeat with the network disabled before sync, then restored. Between tests, clear Emulator data using the configured export/import reset or stop/restart emulator with a clean data directory.

## Evidence gate

Record exact commands, Firebase CLI version, emulator ports, test output, and denied-rule assertions in `IMPLEMENTATION_EVIDENCE.md`. Until this is done, all Firebase/Emulator claims remain **implemented but not physically verified**.
