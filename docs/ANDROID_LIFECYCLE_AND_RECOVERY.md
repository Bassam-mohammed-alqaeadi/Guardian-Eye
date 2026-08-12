# Android Lifecycle and Recovery — Phase 15

## What is implemented

SQLite stores the latest child policy, policy version, daily usage summary, local observation timestamp, last evaluation, and Outbox events. On the next supported application entry point, the repository reloads those records and repeats deterministic evaluation. Duplicate policy deliveries stay idempotent and cumulative usage summaries are upserted by `(device, local day, package)` rather than added repeatedly.

## What is not implemented

Phase 15 does not claim an always-running Flutter process, scheduled continuous monitoring, reboot receiver, persistent foreground service, Doze exemption, or universal immediate enforcement. Android UsageStats data is queried only when the application invokes the disclosed bridge. Android documents that background execution can be affected by standby buckets, network constraints, and device state. [1]

| Scenario | Current expected behavior | Evidence boundary |
|---|---|---|
| Process death / restart | Durable local state is reloaded; a user/service entry point can re-evaluate. | Local repository tests. |
| Network loss | Uses last valid local policy; usage summaries queue locally. | Local tests. |
| Network recovery | Existing Outbox may retry due events. | Existing Outbox tests; physical network test pending. |
| Duplicate capture | Daily summary replaces current cumulative total; no additive duplication. | Local repository tests. |
| Reboot / Doze | No background trigger is claimed. | Physical-device + future lifecycle slice required. |

## Physical-device validation protocol

Use an Android device/AVD with Usage Access granted, open a policy-target app, invoke the disclosed measurement from Guardian Eye, then force-stop/reopen Guardian Eye and verify the same daily total is restored. Repeat with network disabled/enabled. Reboot and Doze cases must remain **not verified** until a dedicated background/lifecycle design is implemented and device evidence is captured.

## References

[1]: https://developer.android.com/reference/android/app/usage/UsageStatsManager "UsageStatsManager and app standby behavior"
