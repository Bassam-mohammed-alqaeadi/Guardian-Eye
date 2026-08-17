# UX SPRINT 01 — M6 Scope and Contract: Screen-Time Administration

**Project:** Guardian Eye Pro (`com.guardianeye.app`)
**Baseline:** M5 GitHub checkpoint `4049c9d`; current HEAD `9dec093` (M5 backend promotion documentation)
**Phase:** M6 — Screen-Time Administration (current)
**Author:** Manus AI
**Date:** 2026-08-13

---

## 1. Executive Summary

M6 converts the already-existing screen-time policy domain (`DigitalPolicy`, `PolicyEngine`, `PolicyRepository`, `TemporaryOverride`, `ChildExceptionRequest`, `ChildPolicyResolver`) into a coherent, production-quality **parent screen-time administration experience**. The parent journey is child-centric: Parent Dashboard → Child → Child Context → Screen Time → Policies, where the parent can view, create, edit, disable, and preview the effective result of policies, grant temporary overrides with bounded expiry, and review the child's exception requests — with an honest synchronization state displayed for every object.

M6 is **policy administration, not measurement and not enforcement**. M7 (screen-time measurement) and M8 (enforcement and background resilience) capabilities are explicitly excluded and must not be implemented early, claimed, or implied. No fabricated usage data will ever appear in the M6 surface.

---

## 2. Scope In / Out

### In scope (M6 approved)

| Capability | Source of truth |
| --- | --- |
| View current policies for a child | `PolicyRepository.forFamily` + existing child-device linkage |
| Create a policy (what / how much / when / status) | `PolicyRepository.save` |
| Edit a policy | `PolicyRepository.update` |
| Disable / archive a policy (soft) | `PolicyRepository.setEnabled` (enabled = false) |
| Effective decision preview | `PolicyEngine.resolve` semantics, exact — no new resolution logic |
| Temporary override (bounded expiry, mandatory) | `PolicyRepository.createOverride` |
| Review child exception request (approve / deny) | `ChildExceptionRequestRepository.approve` / `deny` (atomic) |
| View pending / reviewed exception requests | `ChildExceptionRequestRepository.forFamily` / `forChild` |
| Honest sync state (local / queued / synced / failed / blocked) | Repository `_syncStateFor` via outbox |
| Offline-first queueing | Existing outbox + `FirestoreOutboxRemoteWriter` contracts |
| Arabic RTL + English LTR | `AppLocalizations` keys appended, no hard-coded text |
| Authorization (owner / parent / coParent / child / spouse / unbound / cross-family) | `FamilyAuthorization.permissionsFor(role)` — sole permission source |

### Out of scope (later milestones)

| Excluded | Belongs to |
| --- | --- |
| Continuous usage collection | M7 |
| Android background measurement, UsageStats | M7 |
| App blocking / accessibility / overlay enforcement | M8 |
| Reboot receivers, Doze recovery | M8 |
| Ownership transfer, family deletion | M5 explicitly excluded |
| Paywall, subscription, Haseb, Jawal Pay, OneCash | M15 / M16 |
| Blaze activation | Never autonomous |
| New policy dimensions beyond existing contracts | N/A |

---

## 3. Existing Domain — Reuse, Do Not Rewrite

The repository already contains complete policy infrastructure. M6 is a **canonical client** of it:

- `lib/domain/policy_engine.dart` — `DigitalPolicy`, `TemporaryOverride`, `StoredPolicyOverride`, `PolicyDecision`, `PolicyEngine.resolve` (temporary override wins while matching and active; otherwise highest-priority active window policy; `no_active_policy` fallback).
- `lib/domain/child_exception_request.dart` — status machine (`pending → approved/denied/expired/cancelled`; `approved → expired`), reasons (`homework`, `schoolAssignment`, `familyActivity`, `importantCommunication`, `other`).
- `lib/data/policy_repository.dart` — `save`, `forFamily`, `update`, `setEnabled`, `createOverride`, `createOverrideInTransaction`, `overridesForFamily`, `primaryParentMemberId`, internal `_syncStateFor` / `_enqueue` (queued, synced, blocked, failed, localOnly).
- `lib/data/child_exception_request_repository.dart` — `create` (duplicate-pending guard), `approve` (atomic: expire-if-due → requireParent → verify active child device → createOverrideInTransaction → enqueue `child.exception.approved`), `deny`, `cancel`, `forFamily`, `forChild`, `expireDue`.
- `lib/data/firestore_contracts.dart` — remote writer paths `families/{familyId}/policies/{policyId}`, `/policy_overrides/{overrideId}`, `/exception_requests/{requestId}` with operations `policy.created`, `policy.updated`, `policy.override.created`, `child.exception.requested/approved/denied`.
- `lib/domain/child_device_enforcement.dart` — `ChildPolicyResolver` (read-only consumer).

**Prohibited:** a second policy model, a second repository, a second override system, a second permission model, modification of `FamilyAuthorization`, `FamilyRuntimeContext`, `FamilyActorBindingService`, `PolicyEngine`, `ChildPolicyResolver`, or the SQLite repositories' semantics.

---

## 4. Backend Classification Table

| Operation | Classification | Evidence |
| --- | --- | --- |
| Policy read | **Real Firebase (CLASS A)** | Deployed rules `allow read: if member(familyId)` on `/policies/{policyId}`; subcollection paths supported by writer contracts |
| Policy create / update / disable | **Real Firebase (CLASS A)** | Deployed rules `allow create, update, delete: if parent(familyId)`; repo enqueues to outbox; writer contracts cover `policy.created` / `policy.updated` |
| Override create | **Real Firebase (CLASS A)** | Deployed rules `allow create: if parent(familyId)` on `/policy_overrides/{overrideId}`; contract covers `policy.override.created` |
| Exception request create (child) | **Real Firebase (CLASS A)** | Deployed rules allow child-only create with strict payload validation on `/exception_requests/{requestId}` |
| Exception approve / deny (parent) | **Real Firebase (CLASS A)** | Deployed rules allow parent update `status in ['approved','denied']` with diff allowlist; repo atomic pipeline |
| Policy disable/archive | **Real Firebase (CLASS A)** | Via `setEnabled` (enabled = false); delete exists in rules but repo deliberately offers soft-disable only |
| Security isolation tests | **Emulator (CLASS B)** | Deployed-rules harness pattern established in M5 (`deployed_rules_tests.mjs`) |
| Destructive tests (deny flows, revocation denial) | **Emulator (CLASS B)** | Isolated emulator DB |
| Real signed-in app session proof (Auth UID from APK on physical device) | **HUMAN ACTION REQUIRED (CLASS C)** | No fabricated sessions; documented non-claim |
| `SyncState.synced` on production via real outbox delivery | **REAL FIREBASE PATH OPEN; delivery confirmation requires live executor run** | Outbox/remote-writer integration proven in emulator; production delivery evidence recorded where possible |
| Blaze / paid services | **Not required** | Spark confirmed; no activation |

> **Production rules state (verified 2026-08-13):** deployed ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc` is **byte-identical** to local `firebase/firestore.rules` (md5 `bc8278d80e28f41cf64da976314c9886`) and contains the `/policies/`, `/policy_overrides/`, and `/exception_requests/` match blocks. **No new rule deployment is required for M6.** This is a materially better starting position than M5's initial state.

---

## 5. Authorization Contract

| Actor | M6 authority | Mechanism |
| --- | --- | --- |
| Owner | Full policy administration (create/edit/disable/override/review) | `parent(familyId)` rule branch; domain `FamilyPermission.managePolicies` |
| Parent | Full policy administration | Same as owner |
| coParent | Follows current permission matrix | Only what `permissionsFor(coParent)` grants; rules branch `parent(familyId)` interpreted via membership role |
| Child | Read own family policies; create own exception requests | Rules: child create on `/exception_requests/` requires `childUid == request.auth.uid` and active-owned device; parent-only update denied |
| Spouse | **Option A preserved from M5:** `{viewFamily, viewMembers}` — read-only, zero M6 administration | No screen may invent additional spouse authority |
| Unbound actor (`null`) | Fail closed | `can(permission)` returns `false` |
| Cross-family actor | Denied | Membership keyed to family; rules scoped by `familyId` |

The UI hides unauthorized controls, but **authorization is enforced at repository and rules layers**; UI affordances are never the security boundary.

---

## 6. Offline-First Contract

Online: `UI → local transaction (SQLite) → outbox (queued) → Real Firebase → confirmation → SyncState.synced`.
Offline: `UI → local transaction → queued → honest pending state`.

The word **"Synced" is never displayed** until `OutboxSyncExecutor` confirms remote delivery. Statuses rendered: saved locally (`local`), queued (`queued`), synchronized (`synced`), failed (`failed`), blocked (`blocked`), unavailable (`unavailable` — e.g., device revoked or family unknown).

---

## 7. Test Contract

Unit tests cover policy mapping, precedence presentation, override states, exception states, sync states, authorization outcomes, and validation. Widget tests cover the 18 minimum scenarios (list, empty, loading, error, offline, create, edit, disable, effective decision, conflicts, temporary override, override expiry, pending/approve/deny exception, unauthorized, Arabic RTL, English LTR). Emulator security tests run the **deployed** rules content (not only local assumptions) covering owner/parent allowed, coParent per matrix, child denied for parent writes, spouse denied, cross-family denied, revoked actor denied, override lifecycle, exception lifecycle. Existing M1–M5 tests must remain GREEN and are never weakened.

---

## 8. Acceptance Gates (GREEN only with direct evidence)

`flutter analyze = 0` · all M1–M5 tests GREEN · all M6 tests PASS · create/read/update/disable flows verified · effective decision uses `PolicyEngine` exactly · overrides use `TemporaryOverride` lifecycle with mandatory bounded expiry · exceptions use the atomic lifecycle · security boundaries correct · real-Firebase operations validated · emulator security tests PASS · honest offline state · `synced` only after confirmation · AR-RTL + EN-LTR · accessibility on critical actions · no enforcement claims · clean git / secrets · `phase17-stable-checkpoint` untouched · **no push without explicit user approval**.

---

## References

1. `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` — governing roadmap
2. `docs/GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md` — governing blueprint
3. `docs/UX_SPRINT_01_M5_COMPLETION_REPORT.md` — closed M5 baseline
4. `docs/UX_SPRINT_01_M5_BACKEND_PROMOTION_CLOSURE.md` — deployed ruleset identity `e22c310a`
5. `/home/ubuntu/upload/pasted_content_15.txt` — M6 master execution prompt
