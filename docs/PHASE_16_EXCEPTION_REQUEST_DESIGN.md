# Phase 16 Exception Request Design

## Product contract

The Phase 16 path is **rule → explanation → measurement → decision → dialogue → exception**. A request is a child-authored proposal; it is not a policy mutation and cannot apply a device restriction or a parent policy change.

| Actor | Permitted local action | Prohibited action |
|---|---|---|
| Child device | Create, read, and cancel its own pending exception request. | Edit family policy, approve/deny any request, create an override directly, request for another device. |
| Parent | Read family requests and approve/deny a pending request. | Reassign request child/device/family or forge child identity. |
| Resolver | Treat a valid approved override as temporary allowance until its timestamp expires. | Depend on a background worker for expiry correctness. |

## Domain model

`ChildExceptionRequest` contains `requestId`, `familyId`, `childDeviceId`, `childMemberId`, `childUid`, `target`, optional `policyId`, requested `Duration`, reason code/text, `createdAt`, status, review data, optional `overrideId`, optional `expiresAt`, and a sync state derived from the durable Outbox.

The finite state machine is:

```text
pending ──parent approve──> approved ──time >= expiresAt──> expired
   │
   ├──parent deny─────────> denied
   └──child cancel────────> cancelled
```

Only `pending` is reviewable. `approved`, `denied`, `expired`, and `cancelled` are terminal. Invalid/empty targets, empty child UIDs, blank reasons, non-positive or excessive durations, revoked devices, non-child devices, duplicate pending requests for the same device/target, and unauthorized reviewers are rejected.

## Atomic approval

Approval occurs in a single SQLite transaction:

```text
expire due request states
  → validate family/device/child/request/reviewer
  → mark request approved with reviewer and expiry
  → PolicyRepository.createOverrideInTransaction(...)
  → queue policy.override.created
  → queue child.exception.approved
```

The approval method invokes `PolicyRepository`'s transaction-aware override helper. It does not introduce an override table, policy engine, or remote sync path. Any exception in the transaction rolls back request status, override row, and both Outbox rows.

Denial/cancellation similarly update only the eligible pending request and queue their durable request event. On every request list/read and child/parent dashboard evaluation, `expireDue()` derives timestamp expiration locally, changes approved requests to `expired`, and queues a local expiry event if necessary. The existing `StoredPolicyOverride.isActiveAt()` remains the source of truth for whether the temporary allowance is still active.

## Data and sync boundaries

The SQLite upgrade adds one `child_exception_requests` table and a partial unique index on `(child_device_id, target)` for `pending` requests. A timeline is a local read model composed from existing Outbox records, policy overrides, child usage/evaluation records, and request/review rows. It does not create a second event bus or synchronization engine.

Remote Firestore data is limited to one family-scoped exception-request document. Child rules permit a create/read of only the active device matching its own authenticated UID. Parent rules permit review transition from `pending` to `approved` or `denied`; child cancellation is limited to its own `pending` record. Phase 16 rules are Emulator-only unless an owner explicitly approves a real-backend change.
