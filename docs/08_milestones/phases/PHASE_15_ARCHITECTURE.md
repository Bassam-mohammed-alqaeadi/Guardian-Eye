# Phase 15 Architecture — Measured Screen Time and Truthful Enforcement

## Selected vertical slice

Phase 15 adds an Android-ready **measurement and accounting** path, not a universal normal-app blocking implementation.

```text
Explicit Usage Access consent
  → Android UsageStatsManager query for policy-target packages only
  → normalized daily usage snapshot
  → SQLite daily usage ledger + durable Outbox event
  → ScreenTimeEngine (pure)
  → EnforcementEngine / Android adapter
  → status: evaluated → requested → unsupported or applied-with-evidence
```

The source of truth for a child device remains SQLite. A current policy snapshot, daily usage counters, observations, evaluation decision, and any queued telemetry survive process restart. Network recovery may synchronize queued summaries later, but it cannot turn a client calculation into an operating-system enforcement acknowledgement.

## Policy model

`DigitalPolicy` gains an explicit rule mode.

| Rule mode | Required values | Existing policy behavior | Phase 15 behavior |
|---|---|---|---|
| `scheduleRestriction` | Schedule and targets. | Existing deterministic schedule restriction. | Unchanged. |
| `dailyUsageLimit` | Schedule, targets, and daily minutes. | Does not create an immediate schedule block. | Restricts only after current daily measured time reaches the limit. |

The policy resolver keeps schedule precedence unchanged. `ScreenTimeEngine` separately selects the highest-priority enabled and active daily-limit policy for a target. A valid temporary allow wins before either restriction route. This avoids the incorrect interpretation that a 60-minute daily rule should block a target at the start of its schedule.

## Data minimization

The Android bridge receives the set of policy target package identifiers and returns only those package summaries. Guardian Eye persists only package identifier, day boundary, cumulative foreground duration, last-used timestamp, source, and capture time. It does not persist screenshots, content, text, contacts, microphone data, or an unrestricted inventory of unrelated applications.

## Truthful status vocabulary

| Status | Meaning |
|---|---|
| `notRequested` | No eligible rule has been evaluated. |
| `blockedByPermission` | Usage Access was not granted. |
| `unsupported` | API/device/OEM cannot provide the requested capability. |
| `deferred` | Policy is stale, device revoked/suspended, or a safe evaluation cannot occur. |
| `evaluated` | A deterministic local result exists. |
| `enforcementRequested` | A rule exceeded its limit and the adapter was asked to act. |
| `enforcementApplied` | Reserved for future verified operating-system acknowledgement only. |
| `enforcementFailed` | A future supported Android operation returned failure. |

## Authorization

Child usage summaries are device/family scoped. Only the active child identity associated with that device can write a summary; parents may read it. The summary does not grant parent authority to impersonate the child or a child authority to change parent policy. The existing parent-only policy configuration and override rule boundary remain intact.
