# Android Enforcement Capabilities — Phase 14 Boundary

| Capability | Phase 14 implementation | Consent and platform condition | Evidence status |
|---|---|---|---|
| Usage access readiness | Detect permission through `AppOpsManager`; open the Android Usage Access settings only after a user action. | User must grant Usage Access in Android Settings. | **IMPLEMENTED — PHYSICAL VALIDATION REQUIRED** |
| Foreground application observation | Isolated on-demand Android bridge based on public Usage Stats APIs, returning unsupported/blocked/no-observation truthfully. | Usage Access must be granted; results vary by OEM and Android version. | **IMPLEMENTED — PHYSICAL VALIDATION REQUIRED** |
| Screen-time accounting | Domain/store boundary only. | Requires validated usage data and lifecycle scheduling. | **NOT IMPLEMENTED** |
| Application blocking | Domain restriction intent and unsupported adapter result only. | Android does not provide a universal ordinary-app blocking API; any future route needs policy review and device validation. | **NOT IMPLEMENTED** |
| Accessibility | No service, no auto-enable, no event capture. | Future use requires explicit user consent and policy review. | **NOT IMPLEMENTED** |
| Overlay | Existing readiness path remains separate. | Explicit Android Settings consent. | **NOT USED FOR ENFORCEMENT** |
| Background service/worker/reboot | Durable local recovery model only. | Requires an approved Android lifecycle design and physical-device evidence. | **NOT IMPLEMENTED** |

> Guardian Eye Pro does not use hidden APIs, silently enable Accessibility, bypass Android permission dialogs, or represent a capability readiness flag as effective enforcement.

## Applied-status vocabulary

The adapter reports `notRequested`, `notApplicable`, `unsupported`, `blockedByPermission`, `deferred`, or `applied`. Phase 14 does not return `applied` for app blocking because no system-level blocking mechanism is implemented or verified.
