# UX Sprint 01 — M4 Gap Audit
## Device Linking & Child Device Onboarding

**Project:** Guardian Eye Pro
**Baseline:** `d72c66d282600b56c0cf882976bcf91e4adc25cd` (M3 GREEN)
**Audit performed against:** `docs/UX_SPRINT_01_M4_SCOPE_AND_CONTRACT.md`
**Author:** Manus AI

---

## 1. Audit Method

Every item in the M4 scope contract was checked directly against the repository implementation (`lib/`), the new tests (`test/m4_*`), the localization map, and the router. Each item is classified with direct evidence. Classifications: **IMPLEMENTED** (full contract behavior present and tested), **PARTIAL** (core contract present, documented limitation), **NOT IMPLEMENTED**, **DEFERRED** (deliberately out of M4 scope per the contract's OUT section).

## 2. Non-Negotiable Scope Items

| # | Contract Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Parent issuance: target-child selection, honest expiry, QR + code, redemption entry | IMPLEMENTED | `lib/presentation/screens/pairing_screen.dart`: dropdown of `runtimeContext.children` (`_IssuanceForm`), expiry derived from the real `expiresAt` timestamp (whole minutes, no fake countdown), `QrImageView` with the `guardian-eye://pair?request=&code=` deep-link payload plus `SelectableText` code display, and a redemption entry that pushes `/device-link`. Actor gating returns the explicit `unauthorizedActor` body for non-parents. |
| 2 | Child redemption screen with explicit outcomes | IMPLEMENTED | `lib/presentation/screens/child_redemption_screen.dart`: canonical `_OutcomeView` machine covering validating / success / codeInvalid / codeExpired / codeLocked / codeAlreadyUsed / alreadyEnrolled / unauthorized / networkUnavailable / unknownError. Every rejection carries its own localized title and explanation; the generic-message fallback is explicitly tested to never appear (`unknown error never renders a generic message`). |
| 3 | Role validation via `FamilyAuthorization.permissionsFor` | IMPLEMENTED | `PairingScreen` gates issuance on `FamilyRuntimeContext.can(FamilyPermission.manageDevices)`, which resolves through the existing `permissionsFor` matrix (owner/parent/coParent hold it; child/spouse do not). The widget test proves a child actor sees the closed unauthorized state with the issuance button absent. No new permissions were added. |
| 4 | Identity invariant `accountUid ≠ memberId ≠ deviceId` | IMPLEMENTED | `lib/application/device_link_service.dart` only consumes `verifyAndEnroll`, which transactionally binds the enrolled device to `targetMemberId` in `devices`/`child_device_states` with the outbox `device.enrolled` mutation. The wrong-family boundary is covered by `m4_device_linking_test.dart` (request created in one family, redemption attempted in another is rejected). |
| 5 | Nine-state lifecycle display with localized labels | IMPLEMENTED | `ChildDeviceStatusScreen` renders the existing `ChildDeviceLifecycle` machine through `ChildDeviceRepository.statesForFamily`; M4 added the localized labels in `app_localizations.dart` (`deviceUnlinked`, `deviceEnrolled`, `deviceActive`, `deviceRevoked`, ...) and the widget rendering is proven by the unchanged `child_device_status_screen` widget tests. |
| 6 | Honest offline behavior | IMPLEMENTED | `DeviceLinkService` maps remote-transport failures (`SocketException`/`HttpException` during server reconciliation) to `RedeemOutcome.networkUnavailable`, which the redemption screen presents as **success locally + explicit "Enrollment pending synchronization"**, never as remote success. The widget test `network unavailable renders the honest pending-sync explanation` asserts both texts. |
| 7 | Unlink affordance | IMPLEMENTED | `ChildDeviceStatusScreen._UnlinkAction` (consumer stateful widget): visible only for `active`/`enrolled` devices, gated on the actor holding `manageDevices`, requires an explicit confirmation dialog, calls `revokeDevice` (owner-only in the repository), and reports an honest snackbar. `child_device_enforcement_test.dart` semantics unchanged; unit test confirms revocation by non-owner fails. |
| 8 | Full AR (RTL) + EN (LTR) localization | IMPLEMENTED | 22 new keys added to `app_localizations.dart` in both languages (issuance: `pairForChild`, `selectChild`, `generatePairing`, `pairingRedeemHint`, `pairingExpiryExpiresAt`; redemption outcomes: `codeInvalid[Body]`, `codeExpired[Body]`, `codeLocked[Body]`, `codeAlreadyUsed`, `alreadyEnrolled`, `unauthorizedRedeem[Body]`, `networkUnavailable`, `unknownRedeemError`, `redeemSuccess[Body]`, `redemptionPendingHint`, `pendingSync`, `goHome`; unlink: `unlinkDevice`, `unlinkConfirmTitle/Body`, `unlinkConfirmed`, `retryRedeemLater`). `isRtl` drives layout direction unchanged. |
| 9 | Canonical routing | IMPLEMENTED | Exactly one new route `/device-link` in `lib/presentation/router/app_router.dart`, receiving `{familyId, requestId, code}` via `extra`, with standard back behavior and the existing `/not-found` path for invalid contexts. |
| 10 | Security regression coverage | IMPLEMENTED | `test/m4_device_linking_test.dart` (8 tests) covers outcome mapping, end-to-end redemption enrollment, idempotency (second attempt rejected as used), malformed codes failing before repository contact, expired-request rejection, wrong-family rejection, second active device for the same child rejected, and revocation owner/non-owner semantics. `test/m4_pairing_widget_test.dart` (10 tests) covers issuance rendering, child listing, unauthorized actor, and every redemption outcome surface including honest pending-sync and the no-generic-message invariant. |

## 3. Known Partial / Deliberate Limitations

| Area | Limitation | Rationale |
|---|---|---|
| Device-side redemption trigger | The child device UI for entering the code / scanning the QR is delivered via the redemption route, but the physical act of scanning (camera) and background provisioning are Android-native work belonging to the device-agent side (Phase 6/6D scope). The screen accepts a manual 6-digit code and the deep-link entry point exists. | M4 is a parent-app UX sprint; camera/background provisioning is device-agent work. |
| Physical evidence | End-to-end verification on a real Android device (QR scan, SMS-less pairing flow on physical hardware) was not performed: no Android device is available in the sandbox. Flutter tests use the FFI in-memory database and the emulator suite covers Firestore/Functions rules. Physical-device evidence is marked **HUMAN ACTION REQUIRED**. | Sandbox has no physical device; emulator is the only available Firebase runtime. |
| Outbox replay | Outbox replay to Firestore after network recovery is exercised through the repository's own idempotency tests (Phase 6A/17 evidence); M4 relies on, but does not add to, that machinery. | Existing evidence stands; no change in M4. |
| Multi-device children | A second active device for the same child is rejected at enrollment (tested). Device replacement flows (unlinked → re-link) work through the existing lifecycle but were not given a dedicated flow UI. | Intentionally deferred; replacement governance belongs to a later device-management milestone. |

## 4. Deliberately Out of M4 (confirmed NOT implemented, per contract OUT section)

Screen-time enforcement and background usage collection, web filtering, AI monitoring/inference and parent-facing AI reports, location/geofencing, chat/audio/screen mirroring, subscriptions and payments (Haseb/Jawal Pay/OneCash), Couple Harmony authority migration, full device-management center, ownership transfer, and family deletion. None of these were touched; each remains a documented future milestone in `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md`.

## 5. Files Changed in M4

| File | Kind | Purpose |
|---|---|---|
| `lib/application/device_link_service.dart` | New | Redemption orchestration + outcome mapping (honest offline handling) |
| `lib/presentation/screens/child_redemption_screen.dart` | New | Canonical redemption screen with all explicit outcomes |
| `lib/presentation/screens/pairing_screen.dart` | Modified | Target-child issuance, honest expiry, redemption entry, actor gating |
| `lib/presentation/screens/child_device_status_screen.dart` | Modified | Owner-only unlink affordance with confirmation |
| `lib/application/guardian_providers.dart` | Modified | Exposes `deviceLinkServiceProvider` |
| `lib/presentation/router/app_router.dart` | Modified | Registers `/device-link` |
| `lib/core/localization/app_localizations.dart` | Modified | 22 new AR+EN keys |
| `test/m4_device_linking_test.dart` | New | 8 security/behavior unit tests |
| `test/m4_pairing_widget_test.dart` | New | 10 widget tests (issuance + redemption surfaces) |

**Unchanged by M4:** `Phase 17/18` security/authorization files (`family_authorization.dart`, `family_runtime_context` semantics, `family_actor_binding_service.dart`, `family_membership_repository.dart`, `child_device_enforcement.dart`, `guardian_repositories.dart` pairing core), Firestore rules, Functions, Firebase configuration, Android native files.
