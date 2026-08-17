# Phase 16 Local Safety Timeline Model

The Phase 16 timeline is a local, evidence-labelled read model. It composes durable records instead of emitting a duplicate global event stream.

| Source | Timeline event | Local truth label |
|---|---|---|
| `policies` + policy Outbox | Created, updated, enabled/disabled. | Local event / sync queued / synced / blocked / failed. |
| `child_device_policies` + Outbox | Policy delivered. | Local persistence; remote state only if an Outbox row is synced. |
| `child_usage_observations` | Usage measured. | Local measurement. |
| `child_usage_evaluations` | Limit approached/reached or a measurement status. | Evaluated locally; never OS restriction applied. |
| `child_exception_requests` | Requested, approved, denied, expired, cancelled. | Local state plus Outbox-derived sync label. |
| `policy_overrides` | Temporary exception active/expired. | Timestamp evaluated locally. |
| device state | Device revoked/offline/recovery. | Local device state. |

`queued`, `syncing`, `failed`, and `blocked` mean **sync queued**. Only an Outbox state of `synced` means **synced**. The timeline does not display “remote confirmed” because the current mobile contract records only client submission; no server acknowledgement model exists in Phase 16.
