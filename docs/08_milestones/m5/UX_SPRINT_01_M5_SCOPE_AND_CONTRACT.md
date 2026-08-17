# UX Sprint 01 — M5 Scope and Contract

## Family Management Vertical — Real Backend + Multi-Parent Family Administration

**Checkpoint baseline:** `16956b4d768818e655f74a84aa80f1e214d17aab` (`16956b4`, `master`)
**Repository:** [Guardian-Eye](https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye.git)
**Protected branch:** `phase17-stable-checkpoint = 274e181` (untouched, read-only)
**Date:** August 13, 2026
**Author:** Manus AI

---

## 1. Strategic context

The product owner explicitly authorized early real-backend integration for capabilities that are technically available without paid billing activation. M5 therefore distinguishes three execution classes:

| Class | Meaning in M5 |
| --- | --- |
| **CLASS A — Real Firebase** | Operations that are free and safe under the current project configuration, validated against the real `manus-guardian` project. |
| **CLASS B — Emulator / Sandbox** | Operations whose production deployment requires Blaze, external credentials, or destructive/unsafe exercise against production. |
| **CLASS C — Human Action Required** | Operations that require an owner-only external action (billing activation, account activation, physical device evidence). |

M9 remains the production promotion gate. M5's early real-backend usage refines the execution model but does not cancel M9.

## 2. Real Firebase environment audit (Phase B evidence)

The following was verified against the live `manus-guardian` project in read-only mode before any M5 change:

| Item | Verified value |
| --- | --- |
| Project ID / number / display name | `manus-guardian` / `165160049292` / `Manus-guardian-eye`, state `ACTIVE` |
| Billing | `billingEnabled: false`, no billing account attached → **Spark plan, Blaze not active** |
| Deployed Firestore rules release | `projects/manus-guardian/releases/cloud.firestore`, ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5`, updated `2026-08-12T14:07:06Z` |
| Deployed rules vs local repo | **Divergence found.** Deployed rules are 72 lines; local `firebase/firestore.rules` is 181 lines. The deployed ruleset lacks the `invitations` subcollection rules, the invitation-acceptance path in `members`, the `exception_requests`, `enforcement_status`, and `usage_summaries` collections, and the `activeMember()` semantics |
| Firestore indexes | 4 deployed: `incidents` (familyId+observedAt), `notification_events`, `sos`, `sync_metadata` |
| Cloud Functions | None deployed (`firebase functions:list` → no functions) |
| Collections probed | 20 candidate collections, all **empty** (0 documents) |
| Test data | None exists; the project contains no real families, test families, or account fixtures |

**Data-safety conclusion:** the environment is clean. There are no unknown real families to protect against; isolated M5 test families may be created under explicit scope. No destructive operation against production data is possible because no production data exists.

## 3. M5 scope

### 3.1 In scope

The Family Management experience exposes: family overview (identity, status, member/child/device counts), members and devices view, invitation lifecycle (create, pending, accepted, expired, cancelled, history), role management (owner-gated `parent ↔ coParent`), and member revocation with cascading device authority revocation and queued/synchronized status. Multi-parent support proves **one child → many parent accounts** within a single child identity.

### 3.2 Explicitly out of scope

Ownership transfer, family deletion, account deletion, child removal as a new destructive system, location, web filtering, screen-time enforcement, AI monitoring, chat, audio, screen mirroring, subscriptions, payments, and any Couple Harmony authority beyond the explicitly recorded M5 spouse decision.

## 4. Backend classification (every M5 operation)

| M5 operation | Class | Evidence basis |
| --- | --- | --- |
| Family read / identity | **REAL FIREBASE (local cache authoritative, remote actor binding verified)** | `familyRuntimeContextProvider` → `FamilyActorBindingService` reads server-sourced membership via `FirestoreFamilyMembershipRemoteReader` |
| Member list / device counts | **REAL FIREBASE (SQLite canonical + remote mirror)** | `FamilyMembershipRepository.membersForFamily`, `activeDeviceCountsForFamily` |
| Invite member (outbox enqueue) | **REAL FIREBASE (queued; REMOTE INVITATION SYNC BLOCKED — see declaration below)** | `family.member.invited` → `families/{familyId}/invitations/{id}` via `FirestoreOutboxRemoteWriter` + `_enqueue` |
| Cancel invitation | **REAL FIREBASE (queued; REMOTE INVITATION SYNC BLOCKED — see declaration below)** | `family.invitation.cancelled` |
| Accept invitation | **REAL FIREBASE (queued; real acceptance path validated on emulator; REMOTE INVITATION SYNC BLOCKED — see declaration below)** | `family.member.accepted` → invitation status + `members/{accountUid}` |
| Role update | **REAL FIREBASE (queued)** | `family.member.role.updated` |
| Member revocation + device cascade | **REAL FIREBASE (queued)** | `family.member.revoked` + device revocation writes |
| Invitation lifecycle security rules | **EMULATOR** (deployed ruleset lacks `invitations` rules) → **REAL after redeployment** | Declared below |

> **Declaration — `HUMAN ACTION REQUIRED / REMOTE INVITATION SYNC BLOCKED`:** the currently published Firestore security rules for `manus-guardian` (live ruleset `c102428d-6ff7-4d00-a00a-32aadfbb41d5`) **do not permit remote synchronization of the invitation subcollection** — no `match /invitations/{invitationId}` block exists inside `families/{familyId}` in the live ruleset, so app-user writes would be denied by default. M5 invitation operations are local and outbox-queued only; remote dispatch is blocked until the local repository rules file (`firebase/firestore.rules`, which already contains the correct block) is redeployed to `manus-guardian` — a Firebase resource modification this session did not perform. M5 never describes invitations as "fully remotely synchronized."
| Outbox sync end-to-end | **REAL FIREBASE requires an app Auth session** | `FirestoreOutboxRemoteWriter` needs `AuthenticatedIdentity` from `FirebaseAuthContext` |
| FCM invitation notification | **BLOCKED / HUMAN ACTION REQUIRED** | No FCM infrastructure; Cloud Functions need Blaze |
| Physical device evidence | **HUMAN ACTION REQUIRED** | Real child device only |
| Production rules redeployment | **HUMAN ACTION REQUIRED** | Deploying `firebase/firestore.rules` to `manus-guardian` |
| Blaze / billing | **HUMAN ACTION REQUIRED** | Owner-only action; never autonomous |

## 5. Spouse decision (Couple Harmony — Section 27)

`FamilyAuthorization.permissionsFor(FamilyRole.spouse)` returns exactly `{viewFamily, viewMembers}` — no administrative authority.

> **Decision: Option A — spouse remains authority-empty.** The current authorization matrix is the sole permission source and is preserved unchanged. No write, invite, role, or revocation authority is granted to the spouse role in M5. This is recorded explicitly; it is a deliberate product decision, not an omission.

## 6. Multi-parent model

One child identity coexists with many parent accounts through `FamilyMembership` (`families/{familyId}/members/{accountUid}` keyed by Auth UID). Parent A and Parent B each bind to the same family with roles `parent`/`coParent`; both read the same child documents; `FamilyAuthorization.permissionsFor(child)` contains no administrative permission, so the child cannot act as a parent; `FamilyRuntimeContext.can()` returns `false` for unbound/revoked/unrelated actors, enforcing cross-family denial.

## 7. Offline-first contract

Reads show cached canonical data; mutations enqueue through the existing SQLite `outbox` (`SyncState.queued`) inside the same transaction as the local state change; UI surfaces honest states — saved locally, pending sync, sync unavailable, failed, synchronized. Remote completion is never claimed without evidence (`SyncState.synced` only after `OutboxSyncExecutor` confirmation).

## 8. Security boundaries

| Boundary | Enforcer |
| --- | --- |
| Family isolation (A ≠ B) | `FamilyRuntimeContext.can()` fail-closed; server rules re-enforce |
| Owner-only operations | `FamilyAuthorization.canManageFamily` (`manageMembers`) + repo `_requireOwner` gate |
| Co-parent boundaries | `permissionsFor(coParent)` — view/manage children, policies, devices; no membership authority |
| Spouse | Option A — view only |
| Child isolation | `permissionsFor(child)` — self-only permissions |
| Revoked member | `activeMember()` check; `isActive` false → `can()` false |
| Cross-family denial | UID-keyed member paths; unrelated UID reads return unverified context |

## 9. Test strategy

Unit tests cover member/invitation/role state mapping, authorization outcomes, offline/pending mapping, and real-backend response/error mapping. Widget tests cover family overview, member list, invitation list, invite, cancel invitation, revoke confirmation, role update, unauthorized state, offline state, queued state, Arabic RTL, and English LTR. Security tests cover owner allowed, parent allowed, coParent permitted operations, spouse denied, child denied, unrelated family denied, cross-family denied, and revoked member denied. Real Firebase acceptance records request, actor, target family, expected/actual result, authorization result, and synchronization result per operation.

## 10. Required documentation outputs

`UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md` (this file), `UX_SPRINT_01_M5_GAP_AUDIT.md`, `UX_SPRINT_01_M5_TEST_EVIDENCE.md`, `UX_SPRINT_01_M5_COMPLETION_REPORT.md`, plus a Roadmap Change Note appended to `GUARDIAN_EYE_CANONICAL_ROADMAP.md`.

## 11. Commit policy

Proposed commits (after full validation, pending explicit approval):

1. `feat(ux-m5): complete family management on real backend`
2. `test(ux-m5): add multi-parent and membership validation`
3. `docs(ux-m5): add scope gap evidence and completion report`
4. `docs(roadmap): record M5 real-backend execution change`

No force-push, no history rewrite, no modification of `phase17-stable-checkpoint`.
