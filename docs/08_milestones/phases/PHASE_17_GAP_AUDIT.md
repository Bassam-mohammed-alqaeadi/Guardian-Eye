# Phase 17 Gap Audit — Family Membership & Multi-Parent Foundation

## Evidence classification

| Requirement | Current implementation | Evidence level | Remaining gap |
|---|---|---|---|
| Neutral multi-parent model | `FamilyMember` and `FamilyRole`; no gendered schema primitive. | **IMPLEMENTED + VERIFIED LOCALLY** | Ownership transfer remains intentionally out of scope. |
| Identity separation | Local member UUID, Firebase account UID, and device ID remain separate fields/relations. | **IMPLEMENTED + VERIFIED LOCALLY** | Existing owner binding can now be persisted only after a matching remote UID-keyed membership verifies it; Flutter runtime evidence is pending. |
| SQLite membership lifecycle | Schema v12 plus transactional invite, accept, cancel, revoke, expiry, role update, and device revocation. | **IMPLEMENTED + VERIFIED LOCALLY** | Process/reboot validation requires Android runtime. |
| Outbox durability | All lifecycle transitions queue one durable event with an idempotency key. | **IMPLEMENTED + VERIFIED LOCALLY** | Client-to-Emulator round trip awaits restored Firebase client options. |
| Invitation acceptance | Local acceptance is atomic; remote contract writes invitation and account-keyed member in one batch. | **IMPLEMENTED + VERIFIED LOCALLY** | Real Firestore write not attempted or authorized. |
| Firestore authorization | Owner invite/cancel and recipient acceptance rules with post-commit membership checks. | **VERIFIED IN EMULATOR** | Rules not deployed in Phase 17. |
| Child restriction | Child role cannot invite, change role, revoke, or accept an adult invitation. | **VERIFIED IN EMULATOR** | Physical authenticated child flow not tested. |
| Cross-family isolation | Rules deny owner from another family and forged family payload. | **VERIFIED IN EMULATOR** | Real-backend evidence absent. |
| Trusted authenticated actor | Server-sourced UID path, local/remote family-member reconciliation, role/status/child boundary checks, and fail-closed result. | **IMPLEMENTED + VERIFIED LOCALLY** (10/10) | Flutter client ↔ Emulator live round trip and physical runtime evidence still pending (outside in-repo scope). |
| Family members UI | RTL/LTR local screen, member/device status, pending invitations, and owner-gated forms. | **IMPLEMENTED + VERIFIED LOCALLY** | Dashboard passes only the verified actor; runtime evidence pending physical-device validation. |
| Full Flutter verification | Full suite. | **VERIFIED — 73/73 PASS** (final reconfirmation 13 Aug 2026, 0 blocked files after Firebase options recovery and localization fixes). | — |
| Android APK | Build. | **VERIFIED — BUILD_SUCCESS** (debug artifact, ≈172 MB, single attempt, Android SDK installed, Gradle remediated). | Release APK and device validation remain separate approvals. |
| iPhone verification | No macOS/Xcode runtime available. | **HUMAN ACTION REQUIRED** | Requires a Mac and Apple signing/device process. |
| Real Firebase Phase 17 deployment | No deployment attempted. | **NOT IMPLEMENTED** | Requires explicit owner approval after local artifact restoration and review. |

## Security observations

The acceptance path is stronger than a client-declared role transition: a recipient can update a pending invitation only if the authenticated email matches its target and the same batch creates the active member document at the recipient UID. That member must carry the invitation’s proposed `parent` or `coParent` role and the exact accepted local member ID. Replaying the operation fails because the invitation is no longer pending.

The UI does not infer authority from local role alone. A view that lacks an explicit active actor member does not render member-management controls. This avoids presenting an unauthenticated device as a family owner, but it means Dashboard-level management must remain unavailable until account-to-member binding has evidence.

## Decision (updated 13 August 2026 — final closure)

Phase 17 now satisfies its full in-repo GREEN acceptance gate: Firebase client configuration recovered and identity-matched, complete Flutter validation (73/73, 0 analyzer issues), emulator validation (15/15 Firestore, 2/2 Functions), and a successful debug APK build. The next engineering action is not UI expansion or Phase 18: it is the remaining runtime/physical validations (physical Android device/AVD, client ↔ Emulator live round trip, and real-backend validation upon explicit owner approval), none of which were performed or authorized in Phase 17. **Do not start Phase 18 without explicit product-owner authorization.**
