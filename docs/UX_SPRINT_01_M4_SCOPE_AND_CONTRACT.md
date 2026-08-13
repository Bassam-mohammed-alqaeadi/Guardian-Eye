# UX Sprint 01 — M4 Scope & Contract

## Device Linking & Child Device Onboarding

**Project:** Guardian Eye Pro
**Baseline:** `d72c66d282600b56c0cf882976bcf91e4adc25cd` (M3 GREEN)
**Governing documents:** `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md`, `docs/GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md`
**Author:** Manus AI

---

## 1. Objective

Close the Device Linking vertical end-to-end so that a real child device can be securely associated with the correct child member using the existing pairing infrastructure, and the parent can see the resulting device lifecycle honestly. The M3 Child Context vertical then reflects a real device relationship instead of seed/empty data.

## 2. Target User Journey

```text
Parent → Family → Child
  → Issue Pairing Code / QR (target child)          [extend PairingScreen]
  → Child Device enters code or scans QR
  → Validate (format, expiry, attempts, enrollment, binding, role)
  → Explicit outcome (success / expired / locked / used / unauthorized / offline)
  → Enroll: device bound to correct child member, outbox queued
  → Child Context shows real lifecycle + honest sync state
  → Parent may unlink (reuse existing revocation, confirm first)
```

## 3. Reuse, Not Rewrite

The existing pairing core in `PairingRepository` (`lib/data/guardian_repositories.dart`) is authoritative and is **not** modified. Reused contracts:

| Contract | Behavior (existing) |
|---|---|
| `createParentAuthorizedRequest` | 6-digit code, SHA-256 hash storage, 10-minute expiry, optional `targetMemberId`, `pairing_sessions` row |
| `verifyAndEnroll` | Transactional: request not found / revoked / expired / already used / code mismatch with 5-attempt lockout / active device already linked → enrolled `devices` + `child_device_states` (lifecycle `enrolled`) + outbox `device.enrolled` (idempotent, queued sync) |
| `revokeDevice` | Owner-only revocation → `revoked_at`, lifecycle `revoked`, outbox `device.revoked` |
| `ChildDeviceRepository.statesForFamily / getState` | Actual nine-state lifecycle for the Child Context device card |
| Outbox | Existing mutation types, idempotency key = row id, queued state, retry policy preserved |

New classes only *consume* these contracts. No second pairing system, no plaintext persistence of codes beyond creation time, no lockout weakening.

## 4. Non-Negotiable Scope (IN)

1. **Parent issuance:** extend `PairingScreen` — target child selection (only `child` members), per-request expiry derived from the actual `expiresAt` timestamp (no fake countdowns), QR + code display, redemption entry.
2. **Child redemption:** new canonical `ChildRedemptionScreen` with explicit states: loading, success (enrolled), invalid code, expired, locked (5 attempts), already used, unauthorized actor, offline/pending sync, unknown error. Never a generic "Something went wrong."
3. **Role validation:** issuance gated on the actor holding the appropriate role via `FamilyAuthorization.permissionsFor(role)` (owner/parent/coParent). Child actor attempting a parent operation fails closed. No new permissions are added.
4. **Identity invariant:** `accountUid ≠ memberId ≠ deviceId` is preserved; the final binding goes through trusted actor + membership + pairing contracts.
5. **Device lifecycle display:** UI derived from the existing nine-state `ChildDeviceLifecycle` machine, mapped to localized user-facing labels (`deviceUnlinked`, `deviceEnrolled`, ...). Enum names are never exposed directly.
6. **Honest offline behavior:** redemption that depends on remote reconciliation shows "Enrollment pending synchronization" until the real sync state exists. Local SQLite success is never presented as remote success.
7. **Unlink affordance:** minimal, owner-only, confirms → local revocation → lifecycle `revoked` → queued remote mutation. No full device-replacement management.
8. **Localization:** full AR (RTL) + EN (LTR) coverage for every M4 user-facing string, including all validation outcomes and lifecycle labels.
9. **Routing:** exactly one new canonical route `/device-link` integrated into the existing GoRouter, with valid back behavior and a real not-found path for invalid contexts.
10. **Security regression coverage:** tests for valid redemption plus every rejection scenario, wrong-family boundary, child-actor misuse, and revocation removing device authority.

## 5. Explicitly OUT of M4

Screen-time enforcement and background collection, web filtering, AI monitoring and inference, location tracking and geofencing, chat / audio / screen mirroring, subscriptions and payments, Couple Harmony authority migration, full device-management center, ownership transfer, family deletion, and any other destructive governance feature. These belong to later milestones per the canonical roadmap.

## 6. Offline Contract (verified from architecture)

The provisioning architecture is **C (remote reconciliation)**: the outbox queue carries `device.enrolled` / `device.revoked` to the server when connectivity exists. Locally the device is enrolled and its lifecycle is real; its sync state is honestly `queued/pending`. The UI displays "Enrollment pending synchronization" and the dashboard's sync-queue counter reflects pending work. Offline redemption is never claimed.

## 7. Acceptance Gates

| Gate | Criterion |
|---|---|
| 1 Code | `flutter analyze = 0` |
| 2 Regression | All M1/M2/M3 tests remain GREEN |
| 3 Pairing core | Existing pairing tests remain GREEN, unmodified |
| 4 Redemption | Valid child-device redemption works end-to-end |
| 5 Rejection | Invalid / expired / locked / used / unauthorized / wrong-family scenarios work |
| 6 Security | Family and actor boundaries remain GREEN |
| 7 Lifecycle | Real lifecycle appears on the child device card after enrollment |
| 8 Child Context | M3 screen reflects the newly enrolled device and sync state |
| 9 Offline | Offline/pending behavior is proven and honestly represented |
| 10 Localization | AR RTL and EN LTR pass |
| 11 Android/device | AVD/physical evidence: **HUMAN ACTION REQUIRED** (sandbox has no Android device) — not falsely declared GREEN |
| 12 Git | No unintended files, no secrets, no generated junk |

## 8. Deliverables

| Document | Purpose |
|---|---|
| `UX_SPRINT_01_M4_SCOPE_AND_CONTRACT.md` | This contract |
| `UX_SPRINT_01_M4_GAP_AUDIT.md` | Capability classification (IMPLEMENTED / PARTIAL / NOT IMPLEMENTED / BLOCKED / DEFERRED) |
| `UX_SPRINT_01_M4_TEST_EVIDENCE.md` | Exact commands, counts, emulator evidence |
| `UX_SPRINT_01_M4_COMPLETION_REPORT.md` | Final checkpoint report with gates and gaps |

## 9. Git Discipline

Logical commits only: `feat(ux-m4): ...`, `test(ux-m4): ...`, `docs(ux-m4): ...`. No history modification, no force-push, no push to GitHub until explicit user approval. `phase17-stable-checkpoint` (274e181) untouched.
