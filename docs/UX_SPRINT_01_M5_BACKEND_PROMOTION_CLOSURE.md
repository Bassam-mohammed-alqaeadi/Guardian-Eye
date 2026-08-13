# UX Sprint 01 — M5 Backend Promotion Closure

**Document type:** Evidence closure — real Firebase backend promotion
**Date:** 2026-08-13
**Author:** Manus AI
**Related documents:** `UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md`, `UX_SPRINT_01_M5_COMPLETION_REPORT.md`, `UX_SPRINT_01_M5_TEST_EVIDENCE.md`, `UX_SPRINT_01_M5_FINAL_CHECKPOINT_REPORT.md`

---

## 1. Purpose

M5 (Family Management) shipped to GitHub with the `REMOTE INVITATION SYNC BLOCKED` classification, because the then-deployed Firestore ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5` did not carry the `families/{familyId}/invitations/{invitationId}` rules needed for remote invitation synchronization. This closure document records the controlled promotion of the local rules (`firebase/firestore.rules`, 181 lines) to the real `manus-guardian` project and the resulting verification evidence. No new commits were created during this promotion: this document is a read-only evidence artifact pending a future documentation commit to be approved by the user.

## 2. Promotion execution

The promotion was executed only after the user's explicit written approval ("نعم") of the CLI deploy path. The browser-based Console path was attempted first but the Firebase Console required a Google sign-in session that could not be completed in the available browser environments, so the user approved the CLI path as the alternative.

| Step | Action | Evidence |
| --- | --- | --- |
| 1 | Verified local rules content (181 lines, `match /invitations/{invitationId}` at line 60, md5 `bc8278d80e28f41cf64da976314c9886`) | `md5sum firebase/firestore.rules` |
| 2 | Executed `firebase deploy --only firestore:rules --project manus-guardian` with explicit approval | `✔ firestore: released rules firebase/firestore.rules to cloud.firestore` |
| 3 | Confirmed no Blaze activation, no Functions change, no data deletion | `billingEnabled: false` (unchanged); `functions:list` empty before and after |
| 4 | Read the deployed release via the Firebaserules REST API | New ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc`, updateTime `2026-08-13T16:36:43.443388Z` |
| 5 | Byte-for-byte comparison of deployed content vs. local file | `IDENTICAL: true`, md5 `bc8278d80e28f41cf64da976314c9886` |

> The deployed production rules are now byte-identical to `firebase/firestore.rules` in the repository. The published ruleset is `e22c310a-c24e-4101-abb7-9df31c57e5cc`, replacing `c102428d-6ff7-4d00-a00a-32aadfbb41d5`.

## 3. Verification of the deployed rules against the M5 operations

A dedicated test harness (`firebase/tests/deployed_rules_tests.mjs`) reads the **deployed** ruleset content through the Rules API (not the local file) and executes it against the isolated Firestore emulator. This proves that the live production rules — as they now run on `manus-guardian` — grant and deny exactly the documented M5 behaviors. All four tests passed: 4/4 PASS, 0 fail.

| # | Verified behavior against DEPLOYED rules | Result |
| --- | --- | --- |
| 1 | Owner creates a family-scoped adult invitation (owner-gated, `proposedRole` in `[parent, coParent]`, future `expiresAt` timestamp) | PASS |
| 2 | Intended account accepts the invitation and joins the family atomically in a write batch (invitation → `accepted` with `acceptedAccountUid`/`acceptedMemberId`; member create with `role == proposedRole`) | PASS |
| 3 | Only the owner can create invitations, update adult roles, and revoke members; coParent, child, and cross-family owner writes are denied; a role update cannot demote the primary parent | PASS |
| 4 | Member and invitation reads are denied for non-members; invitation reads are scoped to the owner or to the pending recipient whose Auth token email matches `targetEmail` | PASS |

The invitation lifecycle on production now follows the full chain: **Invite → Accept → Role Update → Revoke → Outbox (`queued`) → Firestore (`families/{id}/invitations/{id}`, `members/{uid}`) → `SyncState.synced`** after the `OutboxSyncExecutor` confirms real delivery.

## 4. Regression and isolation re-verification

All pre-existing gates were re-run after the promotion and remain green, confirming the promotion introduced no regression in application code, security logic, or the emulator suite.

| Gate | Result |
| --- | --- |
| `flutter analyze` | 0 issues |
| Full Flutter test suite (M1–M5) | 140/140 PASS |
| Security regression (`family_actor_binding_service_test`, `family_membership_test`) | PASS (actor binding closed on every unbound/mismatched/revoked scenario) |
| Firestore emulator rules suite | 15/15 PASS (exit 0) |
| Functions emulator suite | 2/2 PASS (exit 0) |
| Cross-family isolation | PASS: unrelated-family actors are denied invitation/member reads and writes in both the deployed-rules harness and the M5 unit tests |
| Production data integrity | Untouched: top-level collections remain empty, as found |

## 5. Reclassification

The following M5 classifications are updated by this closure.

| Item | Previous classification | New classification |
| --- | --- | --- |
| Invitation create / cancel | HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED | **REAL FIREBASE — rules published**; end-to-end remote invitation sync enabled (acceptance requires a real signed-in app session and an acceptance worker; see §6) |
| Member role update / revocation | HUMAN ACTION REQUIRED / REMOTE MEMBER SYNC BLOCKED | **REAL FIREBASE — rules published**; member remote writes now rule-permitted for the owner |
| Family/member/invitation reads | Real Firebase | Unchanged — still Real Firebase |
| Device lifecycle mutations (M4 pipeline) | Real Firebase | Unchanged |
| Blaze-required operations | Emulator | Unchanged — Spark confirmed, Blaze not activated |
| Real signed-in app session (Auth + app binaries) | HUMAN ACTION REQUIRED | **Remains HUMAN ACTION REQUIRED** — a real signed-in app user has not been provisioned; no production data was written |

## 6. Honest non-claims

This closure does **not** claim that a real signed-in app session was exercised against production. The production database remains empty by design; verification of the deployed rules used the downloaded ruleset content executed in an isolated emulator, which is the standard Firebase rules verification method and proves the production rule text exactly. The end-to-end acceptance path additionally depends on: (a) a real Firebase Auth session created from the released app binary on a physical device (HUMAN ACTION REQUIRED), and (b) an acceptance worker or the existing local sync machinery completing the `queued → synced` transition, whose remote writer (`FirestoreOutboxRemoteWriter`) targets the same rule-gated paths now proven to be open for the owner and the intended recipient. `SyncState.synced` will only ever be declared after the `OutboxSyncExecutor` confirms a real delivery confirmation, preserving the honest-sync contract established in M5.

Ownership transfer and family deletion remain out of M5 scope and were not promoted or tested. M6 has not started and will not start until explicit user instruction. No new commits were created in this promotion; the proposed documentation updates (`docs(ux-m5)` amendment recording this closure, and an append-only `docs(roadmap)` entry) are presented below for user approval.

## 7. Proposed commits (pending user approval)

1. `docs(ux-m5): record real-backend rules promotion and closure evidence` — amendment of `UX_SPRINT_01_M5_COMPLETION_REPORT.md`, `UX_SPRINT_01_M5_TEST_EVIDENCE.md`, `UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md` (reclassification tables and blockage removal), plus this new closure document.
2. `docs(roadmap): record M5 real-backend promotion in change log` — append-only roadmap entry.

No source code, tests, Firebase configuration, or phase17-stable-checkpoint content is modified by either commit.
