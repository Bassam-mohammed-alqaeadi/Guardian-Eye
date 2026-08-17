# Phase 17 Architecture — Canonical Family Membership & Invitation Foundation

## Design decision

Phase 17 extends existing `family_members`; it does not create a second people, account, device, or authorization store. Firebase Auth remains the account source. The local domain `memberId` remains a UUID that owns family-scoped relationships. A nullable `accountUid` binds an accepted adult membership to a Firebase account. A device continues to bind to a family member through the existing `devices.member_id` relationship.

> **Identity invariant:** `account UID ≠ member ID ≠ device ID`. A member can have zero, one, or multiple devices; a Firebase account can have memberships in more than one family; a device cannot derive membership or authority merely from a screen it opens.

## Canonical local model

| Concept | Existing/extended storage | Phase 17 responsibility |
|---|---|---|
| Account | Firebase Auth UID only; no duplicate local account table. | Authentication identity and email matching only. |
| Family | Existing `families`. | Family boundary and owner member reference remain implicit in the existing primary-parent role pending a future ownership-transfer slice. |
| Membership | Extended `family_members`. | `memberId`, `familyId`, name, role, status, nullable `accountUid`, invitation provenance, timestamps, revocation. |
| Device | Existing `devices` and child state tables. | Continues explicit `memberId` relation. No parent device can become a child device by UI navigation. |
| Invitation | New `family_invitations`. | Pending remote/local social artifact with target email, proposed role, expiry, cancellation, acceptance, and idempotency. |
| Permission | New domain enum and matrix only. | Canonical role-to-permission result used by repositories and UI capability decisions. |

## Roles, status, and permissions

Existing storage values remain compatible: `primaryParent` is the **owner** role for this phase, while `parent`, `coParent`, `spouse`, and `child` remain valid legacy role values. `spouse` is deliberately mapped to no authority beyond safe family visibility until a later owner-approved migration assigns it a product meaning; Phase 17 never treats a gendered/relationship label as a privilege primitive.

| Permission | Owner / `primaryParent` | `parent` | `coParent` | `child` | legacy `spouse` |
|---|---:|---:|---:|---:|---:|
| View family/members | Yes | Yes | Yes | scoped self only | Yes |
| View children, usage, child status, timeline | Yes | Yes | Yes | own scope only | No |
| Manage child/policies | Yes | Yes | Yes | No | No |
| Review exception requests | Yes | Yes | Yes | own request only | No |
| Invite/revoke members, change role | Yes | No | No | No | No |
| Manage another member’s device | Yes | No | No | No | No |
| Manage own associated device | Yes | Yes | Yes | child lifecycle only through existing binding | No |

Only `active` membership grants any role permission. `invited`, `revoked`, and `expired` memberships have no authority. Ownership transfer is explicitly **not implemented**; the sole active owner cannot be role-demoted or revoked in Phase 17.

## Invitation lifecycle

```text
owner creates pending invitation
  → local Outbox event
  → pending
  → accepted (target account identity + active family + non-expired + not cancelled)
      → local membership becomes active atomically
      → invitation records accepted identity/time atomically
      → one Outbox acceptance event
  → cancelled by owner
  → expired when read/evaluated after expiry timestamp
```

Invitation targets are email-addressed adult invitations in Phase 17. The target account email must match case-insensitively at acceptance. Acceptance is idempotent for the same account after success, rejects a different account, rejects expired/cancelled/revoked records, and never elevates the recipient above the proposed role. Owner can propose only `parent` or `coParent` in this phase; child creation remains on the established explicit child-profile flow.

The authoritative local acceptance transaction validates owner/invitation/account/expiry, creates or activates the membership, marks the invitation accepted, records a safety timeline-compatible Outbox event, and commits together. No device is silently created or re-associated by invitation acceptance.

## Remote contract and synchronization

New mutations reuse the existing Outbox: `family.member.invited`, `family.invitation.cancelled`, `family.member.accepted`, `family.member.revoked`, and `family.member.role.updated` only where implemented. Every event carries family ID, local member/invitation IDs, status, timestamps, and an idempotency key; `synced` remains owned by the established `OutboxSyncExecutor`.

Remote adult membership uses document path `families/{familyId}/members/{accountUid}` and stores the immutable local `memberId` as a field. This resolves the current rule-path mismatch while leaving SQLite relations UUID-based. Invitation acceptance requires one atomic Firestore batch containing invitation status update and member creation. The existing remote writer/contract will be extended, not replaced, to represent that batch. A client may not emit two independent remote events and claim atomic acceptance.

## Non-goals

Phase 17 does not add ownership transfer, invitation email delivery, FCM, social sign-in, trusted caregiver role, adult-device pairing UX, Device Owner, Accessibility, overlay controls, background monitoring, location, AI, or production Firebase deployment. Physical-device validation is a separate gate.
