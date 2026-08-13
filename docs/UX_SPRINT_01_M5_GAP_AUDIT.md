# UX Sprint 01 — M5 Gap Audit

## Family Management Vertical — Real Backend + Multi-Parent Family Administration

**Checkpoint baseline:** `16956b4d768818e655f74a84aa80f1e214d17aab` (`master`)
**Protected branch:** `phase17-stable-checkpoint = 274e181` (untouched)
**Date:** August 13, 2026
**Author:** Manus AI

---

## 1. Purpose

This audit reconciles the implemented M5 family management vertical against the UX specification, the M5 scope and contract, and the existing M1–M4 baseline. Gaps are stated honestly: each is classified as closed, mitigated, deferred, or blocked, with the evidence basis for the classification.

## 2. Gap inventory

### 2.1 Closed gaps (implemented and evidenced in this milestone)

| # | Gap | Closure evidence |
| --- | --- | --- |
| G1 | Family overview surface (identity, status, member/child/device counts) missing from the members screen | `_familyOverviewSection` implemented on `family_members_screen.dart`, driven by `familyRuntimeContextProvider`, `familyMembersProvider`, and `familyMemberDeviceCountsProvider` |
| G2 | No honest per-member synchronization state in the UI | `familyMemberSyncStatesProvider` (outbox `SyncState` per member aggregate) wired into `_MemberTile`; labels "Saved locally / Pending sync / Synced / Sync failed" in AR+EN |
| G3 | Invitation history not exposed | `_InvitationHistorySection` with filter chips (all / accepted / cancelled / expired) implemented from the existing `familyInvitationsProvider` |
| G4 | Unauthorized actor state not rendered on the members surface | `_unauthorizedSection` renders the explicit fail-closed card when the actor is null or unverified |
| G5 | No automated multi-parent parity proof | 13 new tests in `test/m5_family_management_test.dart`: two parent accounts observe identical members and children; cross-family read denied; unbound UID produces an unverified context |
| G6 | No real-Firebase environment audit | Phase B audit completed: Spark plan confirmed, deployed ruleset inspected, 20 collections enumerated (all empty), divergence documented |

### 2.2 Mitigated gaps (honest-state design instead of claimed remote completion)

| # | Gap | Mitigation |
| --- | --- | --- |
| G7 | Outbox mutations cannot yet reach the remote `invitations` subcollection under the **deployed** ruleset | UI surfaces `Pending sync` and `Saved locally` honestly; the outbox queue retains the mutation; remote completion is never claimed until `SyncState.synced` is confirmed |
| G8 | FCM push notification for invitations unavailable (no FCM infrastructure; Functions need Blaze) | The in-app pending/accepted/expired/cancelled sections are the authoritative invitation surface; push delivery is recorded as a deferred capability |

### 2.3 Deferred / blocked gaps (classified honestly — not claimed)

> **Declaration — `HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED`:** the currently published Firestore security rules for `manus-guardian` (live ruleset `c102428d`) **do not permit remote synchronization of the invitation subcollection**. The live ruleset contains no `match /invitations/{invitationId}` block inside `families/{familyId}`; app-user writes to `families/{familyId}/invitations/{id}` would be denied by default. M5 invitation operations are local and outbox-queued only; their remote dispatch is blocked until the local repository rules file (`firebase/firestore.rules`, which already contains the correct block) is redeployed to `manus-guardian` — a Firebase resource modification this session did not perform. M5 never describes invitations as "fully remotely synchronized."

| # | Gap | Classification | Required action |
| --- | --- | --- | --- |
| G9 | Remote invitation dispatch (`families/{id}/invitations/{id}`) under real rules-gated authorization | **HUMAN ACTION REQUIRED** | Redeploy the local `firebase/firestore.rules` (which already contains the `invitations` subcollection block) to `manus-guardian` — a Firebase resource modification that this session did not perform |
| G10 | End-to-end outbox sync with a real app Auth session (real user sign-in → `FirestoreOutboxRemoteWriter`) | **HUMAN ACTION REQUIRED / physical** | Requires a real signed-in app user on a device/emulator against the real project |
| G11 | FCM invitation notification | **BLOCKED** | Requires Blaze + FCM server integration |
| G12 | Physical device evidence (child phone pairing, camera redemption by invited parents) | **HUMAN ACTION REQUIRED** | Real device only |
| G13 | Blaze / billing activation | **BLOCKED** | Owner-only external action; never autonomous |

### 2.4 Pre-existing inventory gap (not introduced by M5, recorded for completeness)

Eight localization keys used by `safety_actions_screen.dart` (`sosTitle`, `sendSos`, `sosConfirmation`, `sosDescription`, `sosStored`, `safetyActions`, `syncNow`, `syncResult`) remain absent from both the AR and EN localization maps. This file is a Phase 17 artifact (commit `a869d78`), is **not registered in the canonical router**, and its keys were already absent at the M4 checkpoint (`16956b4`) and the phase-17 checkpoint (`274e181`). M5 localization changes are append-only (33 additions, 1 punctuation line modified, zero deletions), and every key used by the M5 experience (44 unique `t()` keys) is defined in both languages. Fixing this dead-path gap is out of M5 scope.

## 3. Scope compliance check

The implementation stays inside the contracted scope. Ownership transfer, family deletion, account deletion, child removal, location, web filtering, screen-time enforcement, AI monitoring, chat, audio, screen mirroring, subscriptions, and payments are all untouched; no router route, repository, provider, or test references them. The spouse decision (Option A — authority-empty, read-only `{viewFamily, viewMembers}`) is preserved exactly as the authorization matrix stands; `FamilyAuthorization` was not modified.

## 4. Boundary integrity

The change boundary is respected on all axes: `FamilyRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, the SQLite repositories, the outbox schema, the Firestore rules file, and the Functions source were not modified. Firebase configuration files (`firebase_options.dart`, `google-services.json`, `firebase.json`, `.firebaserc`) were not touched. Only three source files were modified (`family_members_screen.dart`, `family_membership_providers.dart`, `app_localizations.dart`), one test file and one document file were added, and two Flutter-tool-generated artifacts remain as the only unrelated touched files.

## 5. Conclusion

All scope-contracted gaps are closed with direct evidence. The remaining gaps (G9–G13) are correctly classified as human-action-required or blocked, and the UI never claims remote completion for operations whose remote path is not yet evidenced.
