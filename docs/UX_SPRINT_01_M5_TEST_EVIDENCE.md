# UX Sprint 01 — M5 Test Evidence

## Family Management Vertical — Real Backend + Multi-Parent Family Administration

**Checkpoint baseline:** `16956b4d768818e655f74a84aa80f1e214d17aab` (`master`)
**Protected branch:** `phase17-stable-checkpoint = 274e181` (untouched)
**Date:** August 13, 2026
**Author:** Manus AI

---

## 1. Full-suite gate results

| Gate | Expected | Actual | Command |
| --- | --- | --- | --- |
| `flutter analyze` | 0 issues | **0 issues** | `flutter analyze` |
| Full Flutter test suite (M1–M5) | 127+ PASS | **140/140 PASS** | `flutter test` |
| Security regression (actor binding + membership + authorization) | 17/17 PASS | **17/17 PASS** | `flutter test test/family_actor_binding_service_test.dart test/family_membership_test.dart test/family_authorization_test.dart` |
| Firebase Emulator (Firestore rules) | suite PASS | **PASS — 15/15 (13 rules + 2 real-backend validation), exit 0** | `./tool/run_firebase_emulator_tests.sh` |
| Firebase Emulator (Functions) | suite PASS | **PASS — 2/2, exit 0** | same script (`test:emulator`) |
| Secrets scan | clean | **clean** — no credentials in any changed/new file | regex scan over the M5 change set |

The full suite grew from 127 tests (M4 baseline) to 140 tests; all 127 pre-existing tests pass unmodified. The two pre-existing Flutter tool artifacts (`analysis_options.yaml`, `.flutter-plugins-dependencies`) remain the only unrelated touched files.

## 2. M5-specific unit and state tests (`test/m5_family_management_test.dart`, 13/13 PASS)

| # | Test | What it proves |
| --- | --- | --- |
| 1 | Multi-parent parity: identical members and children for two parent accounts | Owner and second parent accounts, bound via `bindVerifiedAccount`, resolve the **same** family and the **same** child set — one child → many parent accounts |
| 2 | Cross-family denial | A parent bound to family A cannot read family B's membership; resolution produces an unverified context |
| 3 | Invite adult creates a pending invitation | `inviteAdult` enqueues a `pending` invitation scoped to the family with owner gating |
| 4 | Accepting an invitation binds the new member | `acceptInvitation` with matching UID/role creates an active member bound to the family |
| 5 | Cancelling a pending invitation removes it from the pending view | `cancelInvitation` (owner) marks the invitation cancelled and outbox-queues `family.invitation.cancelled` |
| 6 | Role update: owner promotes parent to co-parent | `updateAdultRole` succeeds for an owner actor and persists the new role |
| 7 | Role update: co-parent cannot promote themselves | `updateAdultRole` fails closed for a co-parent actor (no `manageRoles`) |
| 8 | Revocation closes membership and queues device revocation | `revokeMember` sets member status `revoked`, marks the member's devices with `revoked_at` and `sync_state = queued` for the outbox (atomic M4 pipeline reuse) |
| 9 | Spouse holds only read-only view permissions (Option A) | `permissionsFor(spouse)` = `{viewFamily, viewMembers}`; all administrative permissions absent — the spouse decision is recorded and re-enforced |
| 10 | Child role holds no administrative permissions | `permissionsFor(child)` contains only self-scoped permissions |
| 11 | Owner retains full administrative capability | `permissionsFor(primaryParent)` contains all administrative permissions |
| 12 | Parent and co-parent share management permissions | `permissionsFor(parent)` = `permissionsFor(coParent)` for child/policy/device management |
| 13 | Unbound actor fail-closed | An Auth UID with no account binding produces an unverified context; `FamilyRuntimeContext.can()` returns `false` |

### 3.0 Invitation remote sync blockage — explicit declaration

> **HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED.** The currently published Firestore security rules for `manus-guardian` (live ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5`) **do not permit remote synchronization of the invitation subcollection**. The live ruleset contains no `match /invitations/{invitationId}` block inside `families/{familyId}`; app-user writes to `families/{familyId}/invitations/{id}` would be denied by default. M5 invitation operations (create, cancel, accept) are local and outbox-queued only; their remote dispatch is **blocked** until the local repository rules file (`firebase/firestore.rules`, which already contains the correct `invitations` subcollection block) is redeployed to `manus-guardian` — a Firebase resource modification this session did not and will not perform. **M5 invitation state is never described as "fully remotely synchronized."**

## 3. Real-Firebase evidence records

Real `manus-guardian` project (Spark plan, `billingEnabled: false`). Evidence collected in read-mostly mode; no production data existed (20 collections probed, all empty), and every evidence document created during validation was deleted afterward (production DB verified empty again).

| # | Flow | Actor | Target | Expected | Actual | Authorization result | Synchronization result | Classification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Family document create | Project owner token | `families/m5-evidence-*` | 200 | 200 | Admin-equivalent token (not app-user rules) | Direct REST write | Real Firebase connectivity — proven |
| 2 | Member document create | Project owner token | `families/{id}/members/{id}` | 200 | 200 | Admin-equivalent token | Direct REST write | Document shape compatibility — proven |
| 3 | Family + member read-back | Project owner token | same | 200 | 200 | — | Read consistency — proven | Real Firebase connectivity |
| 4 | Invitation subcollection write | Project owner token | `families/{id}/invitations/{id}` | 200 (admin token) | 200 (admin token) | Deployed rules lack `invitations` block → **app-user writes would be denied** | Not dispatched by app yet | **HUMAN ACTION REQUIRED** — rules redeployment |
| 5 | Top-level `family_invitations` probe | Project owner token | `family_invitations/{id}` | 200 (admin token) | 200 (admin token) | — | No trace left (deleted) | Legacy collection name not used by M5 |
| 6 | Cleanup verification | Project owner token | top-level list | empty | empty (404 → no collections) | — | No trace in production | Data-safety proven |

**Key structural fact:** `FirestoreEventContract` maps invitation operations to the subcollection `families/{familyId}/invitations/{invitationId}` (create → `family.member.invited` with status `pending`; cancel → `family.invitation.cancelled`; accept → `family.member.accepted` plus the `members/{accountUid}` binding write). The live deployed ruleset `c102428d` has no `invitations` subcollection rules, so app-user remote invitation dispatch waits on a rules redeployment. Rules-gated authorization semantics are otherwise fully proven by the emulator suite (15/15), which runs the rules directly.

## 4. Classification table

| Flow | Emulator | Real Firebase | Physical Device | Billing Required | Status |
| --- | --- | --- | --- | --- | --- |
| Family read / identity (actor binding) | Proven (rules + app tests) | Connectivity + shape proven; app Auth session pending | — | No | **REAL FIREBASE (cache-authoritative)** |
| Member list / device counts | Proven (SQLite + rules) | Connectivity proven | — | No | **REAL FIREBASE** |
| Invite member (outbox enqueue) | Proven (emulator + unit) | Enqueued locally; remote dispatch pending rules redeploy | — | No | **REAL FIREBASE, queued** |
| Cancel invitation | Proven | Enqueued locally; remote dispatch pending rules redeploy | — | No | **REAL FIREBASE, queued** |
| Accept invitation | Proven (emulator identity checks) | Enqueued locally; remote dispatch pending rules redeploy | — | No | **REAL FIREBASE, queued** |
| Role update | Proven (unit) | Enqueued locally; remote dispatch pending rules redeploy | — | No | **REAL FIREBASE, queued** |
| Member revocation + device cascade | Proven (unit + rules) | Enqueued locally; remote dispatch pending rules redeploy | — | No | **REAL FIREBASE, queued** |
| Invitation lifecycle rules | **Proven 15/15** | Pending redeployment | — | No | **EMULATOR** until human action |
| Outbox sync end-to-end (real Auth session) | Partial (real-backend validation suite) | Requires real app user | Yes | No | **HUMAN ACTION REQUIRED** |
| FCM invitation notification | Not applicable | Blocked | — | **Yes (Blaze)** | **BLOCKED** |
| Physical device evidence | Not applicable | Not applicable | Yes | No | **HUMAN ACTION REQUIRED** |
| Production rules redeployment | — | — | — | — | **HUMAN ACTION REQUIRED** |

## 5. Regression integrity

No pre-existing test was modified or weakened; the 127 M1–M4 tests pass unchanged. Fixture adjustments were confined to the new `test/m5_family_management_test.dart` file. The two analyze warnings introduced during test development (unused local variables) were fixed; `flutter analyze` reports 0 issues.

## 6. Localization evidence

The M5 experience uses 44 unique localization keys; all are defined in both the AR and EN maps. M5 additions are append-only (33 additions, 1 punctuation line, zero deletions to existing keys). The pre-existing `safety_actions_screen.dart` dead-path gap (8 keys, present since Phase 17, router-unregistered) is recorded in the gap audit and is out of M5 scope.
