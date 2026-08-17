# UX Sprint 01 v2 — M5 Final GitHub Checkpoint Report

**Family Management Vertical — Real Backend + Multi-Parent Family Administration**
**Date:** August 13, 2026 | **Author:** Manus AI

---

## 1. Checkpoint status

M5 is **GREEN / COMPLETE** with direct evidence on every gate. No commit has been made; this report presents the proposed commits for explicit approval. M6 has **not** started. `phase17-stable-checkpoint = 274e181` is untouched. No Blaze activation, no billing activation, and no production data was created, modified, or destroyed.

## 2. Current workspace state

| Item | Value |
| --- | --- |
| Branch | `master` (equals `origin/master`) |
| HEAD before proposed commits | `16956b4d768818e655f74a84aa80f1e214d17aab` |
| Protected checkpoint | `phase17-stable-checkpoint = 274e181` — untouched |
| Working tree (uncommitted) | M5 source, test, and docs changes listed in Section 5, plus pre-existing Flutter tooling artifacts |

## 3. Final validation results (evidenced, re-run immediately before this report)

| Gate | Result |
| --- | --- |
| `flutter analyze` | **GREEN — No issues found** |
| Full Flutter test suite (M1–M5) | **GREEN — 140/140 PASS** (127 pre-existing M1–M4 + 13 new M5, all unmodified pre-existing tests) |
| Security regression (actor binding + membership + authorization) | **GREEN — 17/17 PASS** |
| Firebase Emulator — Firestore rules | **GREEN — 15/15, fail 0** (13 rules + 2 real-backend validation, exit 0) |
| Firebase Emulator — Functions | **GREEN — 2/2, fail 0, exit 0** |
| Secrets scan | **GREEN — clean** over all M5 changed/new files |
| Real Firebase audit (Phase B) | **GREEN** — `manus-guardian`, Spark plan (`billingEnabled: false`), deployed ruleset `c102428d` inspected, 20 collections enumerated (all empty), evidence documents deleted afterward (DB verified empty again) |

## 4. What was implemented

The family members experience now carries a **family overview section** (identity, status, member/child/device counts, honest synchronization card), an **invitation history section** with status filters, **per-member synchronization labels** (saved locally / pending sync / synced / sync failed) powered by a new `familyMemberSyncStatesProvider`, and an **explicit unauthorized-actor card**. The existing atomic membership operations (invite, accept, cancel, role update, revocation with device cascade) are reused unchanged, queuing to the outbox for real-Firebase dispatch. 13 new tests prove multi-parent parity, cross-family denial, invitation lifecycle, owner-gated role updates, revocation semantics, the recorded Option A spouse decision (read-only `{viewFamily, viewMembers}`), and fail-closed behavior for unbound actors. 26 localization keys were appended in Arabic and English (append-only).

**Spouse decision:** Option A — authority-empty — is explicitly recorded in the scope/contract document and re-enforced by regression tests.

## 5. Proposed commits (proposed, NOT pushed — awaiting explicit approval)

1. `feat(ux-m5): complete family management on real backend` — `lib/presentation/screens/family_members_screen.dart`, `lib/application/family_membership_providers.dart`, `lib/core/localization/app_localizations.dart`
2. `test(ux-m5): add multi-parent and membership validation` — `test/m5_family_management_test.dart` (13 tests)
3. `docs(ux-m5): add scope gap evidence and completion report` — `docs/UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md`, `docs/UX_SPRINT_01_M5_GAP_AUDIT.md`, `docs/UX_SPRINT_01_M5_TEST_EVIDENCE.md`, `docs/UX_SPRINT_01_M5_COMPLETION_REPORT.md`
4. `docs(roadmap): record M5 real-backend execution change` — appended change-log entry and references in `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` (append-only)

Push target: `origin/master`, normal push, no force-push, no history rewrite.

## 6. Invitation remote sync — explicit blockage declaration

> **HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED.** The currently published Firestore security rules for `manus-guardian` (live ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5`) **do not permit remote synchronization of the invitation subcollection**. The live ruleset contains no `match /invitations/{invitationId}` block inside `families/{familyId}`; app-user writes to `families/{familyId}/invitations/{id}` would be denied by default. M5 invitation operations (create, cancel, accept) are therefore local and outbox-queued only; their remote dispatch is **blocked** until the local repository rules file (`firebase/firestore.rules`, which already contains the correct `invitations` subcollection block) is redeployed to `manus-guardian` — a Firebase resource modification this session did not and will not perform. M5 never describes its invitation state as "fully remotely synchronized"; `SyncState.synced` will only be claimed for invitation mutations after the rules are redeployed and the outbox confirms delivery.

## 7. Known non-claims

Remote invitation dispatch under app-user authorization waits on a redeployment of the local `firebase/firestore.rules` to `manus-guardian` (the live ruleset `c102428d` lacks the `invitations` subcollection block) — classified **HUMAN ACTION REQUIRED**, not a failure. End-to-end outbox sync with a real signed-in app session and physical-device evidence remain **HUMAN ACTION REQUIRED**. FCM invitation notifications are **BLOCKED** (Blaze). The pre-existing `safety_actions_screen.dart` dead-path localization gap (8 keys, Phase 17, router-unregistered) is out of scope.

## 8. Awaiting

Explicit approval to execute the four proposed commits and push to `origin/master`. No further action will be taken until approval is received. M6 has not started and will not start without explicit user instruction.
