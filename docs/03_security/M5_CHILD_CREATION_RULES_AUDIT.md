# M5 — Child-Creation Permission-Denied: Read-Only Root-Cause Audit

**Status:** AUDIT ONLY — no code, rules, Functions, or data were modified.
**Date:** 2026-08-14
**Trigger:** M9 physical testing produced outbox op `fd902107` (`member.created`, `attempt=1`, `permission-denied`) — an accidental child-creation mutation rejected by the real Firestore ruleset.

---

## 1. Root Cause

The client's `addChild` flow enqueues a `member.created` outbox operation whose remote target is
`families/{familyId}/members/{localUuid}` with `role: 'child'`, `memberUid: null`, and a
random local member UUID as the document ID.

The deployed ruleset **intentionally prohibits any third-party member-document creation**.
The `members/{memberId}` `allow create` branch accepts exactly two shapes, and **both require
`memberId == request.auth.uid`**:

1. **Family bootstrap** — the actor creating their own family also creates their own
   `primaryParent` member record.
2. **Invitation acceptance** — the invited account creates its **own** member record
   (`role` ∈ `parent`/`coParent`) only after proving an accepted invitation.

A parent writing a `child`-role member document for a local UUID that is not their own
Auth UID matches **neither** branch → `permission-denied`. This is not a rules bug;
it is the rules' core anti-forgery invariant: *no client may create a membership document
for another identity*.

**Consequence:** the local child record persists in SQLite (correct), but the paired
remote write can never succeed under the deployed ruleset. The op correctly enters the
honest `blocked` retry state.

---

## 2. Exact Firestore Path

```
families/{familyId}/members/{memberId}
```

- `memberId` = the child's random local UUID (e.g. the `id` of the locally created `FamilyMember`).
- Payload (from `lib/data/firestore_contracts.dart`, `case 'member.created'`):
  `memberId`, `displayName`, `role: 'child'`, `memberUid: null`, plus
  `familyId`, `idempotencyKey`, `updatedByUid`, `syncStatus: 'client_submitted'`.

The accidental op `fd902107` targeted exactly this path.

---

## 3. Exact Rule That Rejects the Write

`firebase/firestore.rules` → `match /families/{familyId}/members/{memberId}`:

```javascript
allow create: if (creatingOwnFamily(familyId)
    && memberId == request.auth.uid
    && request.resource.data.role == 'primaryParent'
    && request.resource.data.memberUid == request.auth.uid
    && request.resource.data.status == 'active') || (
      signedIn()
      && memberId == request.auth.uid
      && request.resource.data.memberUid == request.auth.uid
      && request.resource.data.status == 'active'
      && request.resource.data.role in ['parent', 'coParent']
      && request.resource.data.invitationId is string
      && exists(/databases/$(database)/documents/families/$(familyId)/invitations/$(request.resource.data.invitationId))
      && getAfter(...).data.status == 'accepted'
      && getAfter(...).data.acceptedAccountUid == request.auth.uid
      && getAfter(...).data.acceptedMemberId == request.resource.data.memberId
      && getAfter(...).data.proposedRole == request.resource.data.role
    );
```

Why the app's write fails:
- Branch 1: `memberId != request.auth.uid` (local UUID vs. parent UID) and `role != 'primaryParent'` → false.
- Branch 2: `memberId != request.auth.uid`, `role` not in `['parent','coParent']`, no `invitationId` → false.
- Result: **deny**.

This matches the deployed production ruleset `e22c310a-c24e-4101-abb7-9df31c57e5cc`
(verified by `firebase/tests/deployed_rules_tests.mjs`) and was confirmed empirically on
the physical device during M9 (`permission-denied`).

---

## 4. Current Intended M5 Architecture (repository + rules + Functions evidence)

- **Membership documents are keyed by account UID** (`families/{familyId}/members/{accountUid}`)
  — documented in `docs/UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md` §6 and
  `docs/backend/FIRESTORE_DATA_MODEL.md` ("`members/{memberId}` … writer: Primary parent or
  privileged backend").
- **A membership document is created only by the member's own authenticated account**
  (self-create at bootstrap or invitation acceptance) **or by the privileged backend**
  (Firebase Functions using the Admin SDK). `memberUid` is immutable after create
  (`allow update` forces `request.resource.data.memberUid == resource.data.memberUid`),
  freezing identity binding.
- **Child identity is local-first.** The canonical roadmap records "Child identity
  (child = member)" as IMPLEMENTED but **"Local only"** — remote child identity is expected
  to be established through device onboarding, not by a direct parent write.
- **The server-authorized child path already exists in Functions** (`firebase/functions/src/index.ts`):
  - `createChildDeviceProvisioning` (parent issues a pairing code **targeting an existing child member** —
    fails with `target_child_member_required` if the remote child member doc does not exist).
  - `redeemChildDeviceProvisioning` (child device redeems; **the Admin SDK writes
    `members/{childUid}` with `role: 'child'`** — the only sanctioned remote creation of a
    child membership document). This path is prepared but not yet wired to a client screen
    (recorded in `GAP_AUDIT_RECONCILED_PHASE8`).
- **The local pairing core** (`PairingRepository.verifyAndEnroll`) enqueues `device.enrolled`
  outbox operations and is what M4 currently uses; the Functions callables are the prepared
  production path.

---

## 5. Is the Client Operation Correct?

**No — the client `member.created` remote write is architecturally inconsistent with the
deployed rules and the intended model.**

Evidence of inconsistency:

1. **Keying mismatch:** the canonical model keys remote member docs by **Auth UID**
   (`members/{accountUid}`); `addChild` writes to `members/{randomLocalUuid}` with
   `memberUid: null` — a pre-identity placeholder that the rules never authorize.
2. **No sanctioned creator for the target path:** the rules allow no third-party member
   creation at all; the only server-authorized child-member creation is the Functions
   redemption path (`members/{childUid}`), which the app does not invoke from `addChild`.
3. **Gap audits already flagged it:** `GAP_AUDIT_PHASE_5.md` lists "Child profile creation …
   `addChild` persists a child and queues `member.created`" as **IMPLEMENTED + NOT YET
   VERIFIED**; `GAP_AUDIT_RECONCILED.md` marks repository-level child creation
   "IMPLEMENTED + NOT YET FULLY VERIFIED".
4. **Harness contradiction:** `firebase/tests/real_backend_validation.mjs` asserts
   `child_member_write` → **200** (parent creates a child member doc directly). This
   expectation is **inconsistent with the deployed ruleset** — that check could never pass
   against `e22c310a` and reflects an earlier/aspirational contract, not the deployed one.
   The authoritative deployed-ruleset harness (`deployed_rules_tests.mjs`, 23/23) contains
   no parent-creates-child-member success case.
5. **Local UI correctness:** the local SQLite child record, the dashboard child list, and
   the offline-first display are all correct. Only the remote-write half of the flow is
   unauthorized.

---

## 6. Security Risk of Loosening the Rule

Any rule change that lets a `parent(familyId)` create `members/{memberId}` for arbitrary
IDs would weaken the core anti-forgery invariant:

- A compromised or malicious parent account could mint **arbitrary membership documents**
  (spoofed children, phantom members), polluting every family surface that derives from
  `members`.
- Allowing `memberUid` to be set at create time would let a client **pre-bind a victim's
  Auth UID** to a child role, then pair/associate that identity — an identity-forgery and
  potential account-binding attack the current design explicitly prevents
  ("a client may never self-escalate"; `memberUid` immutability).
- The `update` rule already hardens identity (`memberUid`/`memberId`/`familyId` immutable
  on update); a looser `create` would be the odd exception and a prime escalation target.
- Redemption semantics depend on the child member doc existing with a **trusted** binding;
  client-minted docs would make `redeemChildDeviceProvisioning`'s `target_missing`
  guard meaningless.

Conclusion: loosening the rules without a server-authorized creator is **not** a
minimal or safe fix.

---

## 7. Recommended Minimal Fix (NOT implemented — pending owner review)

**Align the client with the intended server-authorized architecture instead of loosening
the rules.** Two options, in recommended order:

**Option 1 — Privileged-backend child creation (preferred).**
Add a small `onCall` Firebase Function (e.g. `createChildMember`) that the parent invokes
from the `addChild` flow; the Admin SDK writes `members/{localUuid}` (or the canonical
`members/{childUid}` after identity exists) with `role: 'child'`, preserving the rules'
no-third-party-client-create invariant ("privileged backend" is already the documented
writer in `FIRESTORE_DATA_MODEL.md`). The outbox op for child creation either targets a
server-confirmed document or is marked local-only until server confirmation.
This is consistent with the prepared Functions redemption path and unblocks M4 pairing
(which already requires the remote child member doc to exist before issuance).

**Option 2 — Local-only child records (zero backend change).**
Stop enqueueing a remote `member.created` write for `role: 'child'` members entirely.
Child records remain local-first (as the roadmap already records "Local only"); the remote
child member document is created **only** by `redeemChildDeviceProvisioning` during device
onboarding. The local outbox row, if any, is treated as local-state-only with an honest
non-syncable state.

Both options preserve the rules, keep `memberUid` binding server-frozen, and eliminate the
permanently-blocked `member.created` op. **No rule change is required for either option.**

---

## 8. Files That Would Need Modification

Option 1:
- `firebase/functions/src/index.ts` — add `createChildMember` (Admin SDK write).
- `lib/data/guardian_repositories.dart` — `addChild` invokes the callable (or the outbox
  payload carries a server-confirmed member doc).
- `lib/data/firestore_contracts.dart` — `member.created` mapping for child-role payloads.
- `lib/data/firestore_outbox_remote_writer.dart` — child-member delivery/confirmation path.

Option 2:
- `lib/data/guardian_repositories.dart` — `addChild` stops enqueueing `member.created`
  (or enqueues with a local-only marker).
- `lib/data/firestore_contracts.dart` / writer — reject or skip child-role remote writes.
- Shared: `docs/GAP_AUDIT_*`, this report, and `firebase/tests/real_backend_validation.mjs`
  (`child_member_write` expectation must be corrected or removed regardless of option).

No change required to `firebase/firestore.rules` in either option.

---

## 9. Whether Firestore Rules Need Modification

**No.** The deployed ruleset `e22c310a` already expresses the correct invariant
(no third-party member creation). The gap is that the client assumes a write the rules
never authorized. Fix the client/backend path, not the rules.

---

## 10. Tests Required

- **Flutter unit/widget:** `addChild` produces the correct local record and either
  (a) invokes the privileged callable, or (b) records an honest local-only/non-syncable
  state — never a doomed remote `member.created`.
- **Outbox contract tests:** child-role `member.created` payloads are never emitted as
  remote writes under Option 2; under Option 1 they target a server-confirmed document.
- **Rules tests (emulator):** keep 15/15 GREEN — add a case asserting a parent **cannot**
  create `members/{foreignId}` (guards the invariant), and that only the Admin SDK path
  may create child-role docs.
- **Deployed-ruleset harness:** 23/23 remains GREEN; correct the contradictory
  `child_member_write` assertion in `real_backend_validation.mjs`.
- **Functions tests:** `createChildMember` (Option 1) enforces parent-only, idempotency,
  and `memberUid` immutability.
- **Full gates:** `flutter analyze`, `flutter test` (231/231 baseline), APK build.

---

## 11. Real-Device Revalidation Required

After the chosen fix:

1. Create a child from the app UI on `RFCT420YY9B`.
2. Verify the outbox op never enters a doomed remote `member.created` (Option 2) or
   reaches `synced` via the server path (Option 1).
3. Re-issue the M4 pairing flow and confirm `redeemChildDeviceProvisioning` writes
   `members/{childUid}` (real Firestore).
4. Verify the previously blocked op `fd902107` either resolves via the new path or is
   honestly retired — never a permanent `permission-denied` retry loop.
5. Confirm family sync-state UI remains honest (E3) through the transition.

---

## Critical Question — Verdict

**A (direct parent client creation of a member) is NOT part of the intended architecture
and is intentionally blocked by the deployed rules.**

The repository evidence points to a **server-authorized / pairing-based flow (B/C hybrid)**:
- Adults join through **invitation acceptance** (self-create with proof) — rules-sanctioned.
- Children get their remote membership through the **privileged backend** — the prepared
  Functions redemption path (`redeemChildDeviceProvisioning` → `members/{childUid}`),
  the documented "privileged backend" writer in `FIRESTORE_DATA_MODEL.md`, and the
  roadmap's "Local only" child identity.
- The parent's `addChild` should create the **local** child record; the **remote**
  child membership document is created server-side (optionally via a new
  `createChildMember` callable so M4 pairing issuance, which requires the remote child
  member doc to exist, can proceed).

This verdict is based entirely on repository and deployed-rules evidence (ruleset
`e22c310a`, `firebase/firestore.rules`, `firebase/functions/src/index.ts`,
`docs/backend/FIRESTORE_DATA_MODEL.md`, M4/M5 scope & gap docs), not preference.
