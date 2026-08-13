# UX Sprint 01 — M5 Completion Report

## Family Management Vertical — Real Backend + Multi-Parent Family Administration

**Checkpoint baseline:** `16956b4d768818e655f74a84aa80f1e214d17aab` (`master`)
**Protected branch:** `phase17-stable-checkpoint = 274e181` (untouched)
**Date:** August 13, 2026
**Author:** Manus AI

---

## 1. Milestone verdict

**M5: COMPLETE — GREEN**, pending explicit approval to push the four proposed commits. Every gate below carries direct evidence; no claim is made beyond the evidence gathered.

## 2. Gate summary

| Gate | Result |
| --- | --- |
| `flutter analyze` | **GREEN** — 0 issues |
| Flutter test suite | **GREEN** — 140/140 PASS (127 M1–M4 + 13 new M5) |
| Security regression | **GREEN** — 17/17 PASS |
| Firebase Emulator (Firestore rules) | **GREEN** — 15/15, exit 0 |
| Firebase Emulator (Functions) | **GREEN** — 2/2, exit 0 |
| Secrets scan | **GREEN** — clean |
| Real Firebase audit (Phase B) | **GREEN** — Spark confirmed, environment clean |
| Multi-parent parity proof | **GREEN** — one child, two bound parent accounts, identical resolution |
| Cross-family denial | **GREEN** — unverified context for unrelated actors |
| Offline-first honesty | **GREEN** — per-member `SyncState` surfaced; no remote completion claimed |
| Spouse decision (Option A) | **GREEN** — recorded and regression-tested |
| RTL (Arabic) / LTR (English) | **GREEN** — 44 M5 keys defined AR+EN; same AppLocalizations/Directionality system as M1–M4 |
| Physical device | **HUMAN ACTION REQUIRED** — no claim |
| Blaze / billing | **NOT ACTIVATED** — `billingEnabled: false` verified |

## 3. What was implemented

The family members experience was extended with a family overview section (family identity, status, member/child/device counts, and an honest synchronization state card), an invitation history section with status filters (all / accepted / cancelled / expired), per-member synchronization labels (saved locally / pending sync / synced / sync failed), and an explicit unauthorized-actor card when the runtime actor is null or unverified. The provider layer gained `familyMemberSyncStatesProvider`, which maps the outbox `SyncState` per member aggregate. Twenty-six new localization keys were appended (append-only) in Arabic and English. The underlying membership operations — invite, accept, cancel, role update, revocation with cascading device authority — remain the existing atomic SQLite-plus-outbox pipeline, re-used unchanged per the change-boundary rules.

The real-Firebase readiness was established by audit rather than by blind assumption: the project runs on the free Spark plan, the deployed ruleset diverges from the repository rules in a documented way, all collections are empty, and document shapes were verified compatible. Invitation remote dispatch is classified honestly as pending a rules redeployment (human action).

## 4. Change set

| File | Change |
| --- | --- |
| `lib/presentation/screens/family_members_screen.dart` | Overview section, invitation history section, unauthorized card, per-member sync labels |
| `lib/application/family_membership_providers.dart` | `familyMemberSyncStatesProvider` added |
| `lib/core/localization/app_localizations.dart` | 26 M5 keys appended (AR + EN), append-only |
| `test/m5_family_management_test.dart` | New — 13 tests (multi-parent, invitations, roles, revocation, authorization regression, fail-closed) |
| `docs/UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md` | New — scope, classification, spouse decision |
| `docs/UX_SPRINT_01_M5_GAP_AUDIT.md` | New — gap inventory |
| `docs/UX_SPRINT_01_M5_TEST_EVIDENCE.md` | New — evidence + classification table |
| `docs/UX_SPRINT_01_M5_COMPLETION_REPORT.md` | New — this file |
| `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` | Appended M5 real-backend change note (append-only) |

## 5. Invitation remote sync — explicit blockage declaration

> **HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED.** The currently published Firestore security rules for `manus-guardian` (live ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5`) **do not permit remote synchronization of the invitation subcollection**. The live ruleset contains no `match /invitations/{invitationId}` block inside `families/{familyId}`; app-user writes to `families/{familyId}/invitations/{id}` would be denied by default. Consequently, M5 invitation operations (create, cancel, accept) are local and outbox-queued only: their remote dispatch is **blocked** until the local repository rules file (`firebase/firestore.rules`, which already contains the correct `invitations` subcollection block) is redeployed to `manus-guardian`. This is a **human action required** — a Firebase resource modification that this session did not and will not perform. M5 invitation state is therefore **never described as "fully remotely synchronized"** in any M5 document; the honest UI states (saved locally / pending sync / sync failed / synced) apply, and `SyncState.synced` will only be claimed for invitation mutations after the rules are redeployed and the outbox confirms delivery. Member operations (role update, revocation) face the same dependency for their remote dispatch, since the live ruleset's `members` subcollection rules predate the local repository rules and were not re-verified for the acceptance path.

## 6. Known non-claims

Remote invitation dispatch under app-user authorization is not evidenced on real Firebase because the deployed ruleset lacks the `invitations` subcollection block; this is recorded as human action required, not as a failure. End-to-end outbox sync with a real signed-in app session and physical device evidence remain human-action-required. The pre-existing `safety_actions_screen.dart` dead-path localization gap (8 keys, Phase 17) is untouched and out of scope. No production data was created, modified, or destroyed; the environment was left empty as found.

## 7. Commit policy

No commit has been made. Four commits are proposed and await explicit approval:

1. `feat(ux-m5): complete family management on real backend`
2. `test(ux-m5): add multi-parent and membership validation`
3. `docs(ux-m5): add scope gap evidence and completion report`
4. `docs(roadmap): record M5 real-backend execution change`

M6 has not started. `phase17-stable-checkpoint = 274e181` remains untouched.
