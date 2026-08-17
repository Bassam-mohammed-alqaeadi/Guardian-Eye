# Child Device State Machine

## States

| State | Meaning | May perform policy evaluation | May claim OS enforcement |
|---|---|---:|---:|
| `unlinked` | No verified child device identity is stored. | No | No |
| `pairingPending` | A parent-authorized pairing flow is pending. | No | No |
| `enrolled` | Pairing created a durable device record; first recovery is pending. | Yes, after a valid policy is local | No |
| `active` | Child device is locally usable and not locally marked offline/revoked. | Yes | Only through a verified adapter. |
| `offline` | Connectivity is absent or remote freshness is unavailable; last valid policy is retained. | Yes | Only through a verified adapter. |
| `restricted` | Domain policy currently requests a restriction. | Yes | No implicit OS action. |
| `suspended` | Evaluation/enforcement is intentionally paused pending a trusted action. | No enforcement action | No |
| `revoked` | Device has been invalidated by a parent-authorized flow. | Resolver returns revoked state only. | No |
| `recovering` | A restart or reconciliation is loading durable local state. | After recovery completes | No |

## Valid transitions

```text
unlinked → pairingPending
pairingPending → enrolled | unlinked | revoked
enrolled → recovering | active | suspended | revoked
active ↔ offline
active ↔ restricted
offline ↔ restricted
active | offline | restricted | suspended → recovering | revoked
recovering → active | offline | restricted | suspended | revoked
revoked → (terminal)
```

An invalid transition raises a domain error and does not mutate SQLite. `revoked` is terminal; reenrollment requires a new pairing and a new device identity. The state machine intentionally does not let a child device transition itself to a parent-capable state.

## Durable fields

The child state record persists the family/device/member scope, lifecycle, highest delivered policy version, last valid delivery time, last evaluation time, last telemetry synchronization time, last decision, failure code, and update timestamp. These fields support restart recovery and truthful UI; they are not evidence that Android applied a restriction.
