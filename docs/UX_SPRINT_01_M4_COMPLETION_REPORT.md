# UX Sprint 01 — M4 Completion Report
## Device Linking & Child Device Onboarding

**Project:** Guardian Eye Pro
**Baseline:** `d72c66d282600b56c0cf882976bcf91e4adc25cd` (M3 GREEN)
**Author:** Manus AI
**Date:** August 13, 2026

---

## 1. Mission

M4 closes the Device Linking vertical end-to-end: a parent can issue a pairing code (or QR) targeted at a specific child member, the child device can redeem the code through a canonical screen with an explicit outcome for every possible result, and the resulting device lifecycle appears honestly in the existing Child Device Status and Child Context surfaces. The M3 verticals then display real device relationships instead of seed data.

## 2. Architecture of the M4 Addition

M4 adds exactly one service, one screen, one route, and 22 localization keys, and it *consumes* the existing pairing core without touching it.

```text
PairingScreen (parent)                    ChildRedemptionScreen (child device)
├── actor gate: FamilyRuntimeContext
│       .can(manageDevices)               ├── 6-digit code entry (format-first validation)
├── target-child dropdown:                ├── DeviceLinkService.redeem(familyId, requestId, code)
│       runtimeContext.children           │   ├── malformed → codeInvalid (no repo contact)
├── issue:                                │   ├── verifyAndEnroll (existing, transactional)
│       PairingRepository               │   │   └── enrolled devices + child_device_states
│       .createParentAuthorizedRequest    │   └── outcome mapping (10 distinct outcomes)
│       (targetMemberId, 10-min expiry)   └── _OutcomeView: success / invalid / expired /
├── display: QrImageView                        locked / used / enrolled / unauthorized /
│       + SelectableText code                   networkUnavailable(pending sync) / unknown
└── entry: push /device-link            (never a generic "Something went wrong")
```

The identity invariant `accountUid ≠ memberId ≠ deviceId` is preserved end-to-end: the enrollment binds the device to `targetMemberId` inside `PairingRepository.verifyAndEnroll`, the actor bound by Phase 17's `FamilyActorBindingService` is what authorizes the parent-side issuance, and the child-side redemption carries no actor authority (binding happens after enrollment through the trusted pairing contract).

## 3. Data Flow

The issuance writes a `pairing_sessions` row with a SHA-256-hashed 6-digit code and a 10-minute `expiresAt`. Redemption validates format locally, then runs the transactional `verifyAndEnroll` path: request existence → revocation → expiry → single-use → code match with 5-attempt lockout → one-active-device-per-child. Success writes `devices` and `child_device_states` (`enrolled` lifecycle) and queues the outbox mutation `device.enrolled` (idempotency key = row id). Unlinking goes through the owner-only `revokeDevice`, flipping the lifecycle to `revoked` and queueing `device.revoked`. The Child Device Status screen reads the real nine-state lifecycle through `ChildDeviceRepository.statesForFamily`, which is exactly what the M3 Child Context surface renders.

## 4. Honest Offline Behavior

`DeviceLinkService` catches transport failures during server reconciliation and returns `RedeemOutcome.networkUnavailable`. The redemption screen then shows **local success plus the explicit "Enrollment pending synchronization" acknowledgement**. Local SQLite success is never presented as remote success, and no fabricated sync state is displayed. Reconciliation completes through the existing outbox machinery (Phase 6A/17 evidence), which M4 relies on without modification.

## 5. Navigation

Exactly one new canonical route, `/device-link`, is registered in the existing GoRouter, receiving `{familyId, requestId, code}` through route `extra`, with standard back behavior and the existing `/not-found` path for invalid contexts. The issuance screen provides the entry point; the child-context and device-status surfaces remain the consumption points.

## 6. Security

Issuance is gated on `FamilyRuntimeContext.can(FamilyPermission.manageDevices)`, which resolves through the unchanged `FamilyAuthorization.permissionsFor` matrix (owner, parent, co-parent hold it; child and spouse do not). A child actor attempting issuance sees the fail-closed unauthorized state with no affordance. Cross-family redemption is rejected at the repository boundary. The Phase 17/18 files (`family_authorization.dart`, `family_actor_binding_service.dart`, `family_membership_repository.dart`, `child_device_enforcement.dart`, the pairing core in `guardian_repositories.dart`), Firestore rules, Functions, and Firebase configuration were **not modified**.

## 7. Test Evidence

| Suite | Requirement | Result |
|---|---|---|
| `flutter analyze` | 0 issues | **PASS** |
| Full `flutter test` | All tests pass | **PASS — 127/127** |
| `test/m4_device_linking_test.dart` | Redemption logic and boundaries | **PASS — 8/8** |
| `test/m4_pairing_widget_test.dart` | Issuance and redemption surfaces | **PASS — 10/10** |
| Security regression (binding/membership/authorization) | Phase 17 integrity | **PASS — 17/17** |
| Firebase Emulator (rules + functions) | Backend contracts | **PASS — 10/10, exit 0** |
| Secrets scan | No credentials in M4 changes | **PASS — clean** |

The detailed per-test breakdown is in `docs/UX_SPRINT_01_M4_TEST_EVIDENCE.md`; the per-contract item audit is in `docs/UX_SPRINT_01_M4_GAP_AUDIT.md`.

## 8. Non-Claims

M4 does **not** claim: physical-device verification (no Android device in the sandbox; QR scanning and camera-based redemption on real hardware is **HUMAN ACTION REQUIRED**); device-agent background provisioning (Android-native work in device-agent scope); outbox replay evidence (covered by Phase 6A/17 and unchanged); screen-time enforcement or any AI, location, communication, or commercial capability (deferred to later milestones per `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md`).

## 9. What Remains After M4

The pairing vertical is functionally closed on the parent-app side. The outstanding items are the device-agent side of redemption (camera QR scanning, background provisioning agent, Android foreground/background execution — device-agent milestone), physical-device smoke verification (human action), and the screen-time enforcement layer that consumes the now-real device lifecycle (next UX milestones per the canonical roadmap: Family Management seats, then Screen Time policy creation and enforcement).

## 10. Checkpoint State

The repository HEAD remains `d72c66d` (M3). M4 work is complete and gated green but **not committed or pushed**; it awaits the user's final-gate approval. `phase17-stable-checkpoint` (`274e181`) was not modified.
