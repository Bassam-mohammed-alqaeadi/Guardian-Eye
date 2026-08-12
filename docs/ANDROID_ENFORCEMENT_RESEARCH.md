# Android Enforcement Research — Phase 15

## Conclusion

An ordinary consumer Android application cannot responsibly claim universal arbitrary-app blocking. The defensible Phase 15 mechanism is **Usage Access-backed observation plus deterministic local screen-time accounting**, with an explicit enforcement request/status boundary. It supplies real measurement where Android/OEM access permits, works from a locally persisted policy while offline, and never calls an unimplemented restriction “applied.”

| Candidate | Public API / requirement | Can actually block arbitrary apps? | Consent / Play boundary | Offline/reboot considerations | Phase 15 decision |
|---|---|---:|---|---|---|
| Usage Access (`UsageStatsManager`) | `PACKAGE_USAGE_STATS`; user must grant it in Android Settings. It exposes usage history, event queries, and aggregated usage data. [1] | No | Explicit settings grant; no Accessibility required. | Locally queried data is usable offline once permission exists; unavailable when the platform returns no data or device is locked. [1] | **Selected for observation/accounting.** |
| Device Owner / DPC | `DevicePolicyManager` methods are for device administrators/controllers or suitable roles; provisioning includes education and consent screens. [2] [3] | Yes, on appropriately provisioned managed devices. | Managed-device/enterprise-style provisioning and Play/DPC approval implications. | Device policy can be local but requires a dedicated managed-device model. | **Future opt-in advanced path; not enabled.** |
| Accessibility Service | A service may require prominent disclosure, consent, and Play declaration; autonomous plan/decision/action behavior is prohibited except within narrow policy conditions. [4] | It is not a reliable or appropriate Phase 15 blocking route. | High disclosure, policy, and user-data burden. | Service lifecycle/OEM behavior needs device evidence. | **Rejected for this phase.** |
| Overlay / launcher interception | No public universal system enforcement guarantee for a normal app. | No | Would risk deceptive behavior if used to simulate a block. | Fragile across launchers/OEMs/reboot. | **Rejected.** |
| VPN/DNS web filtering | Separate network filtering product capability. | Websites only, not arbitrary apps. | Consent, network/privacy review required. | Requires dedicated service/lifecycle design. | **Future.** |

## Selected enforcement semantics

When a measured daily allowance is exceeded, the domain can truthfully produce `RESTRICT`. The Android adapter must report `ENFORCEMENT_REQUESTED` followed by `UNSUPPORTED` for a normal unmanaged device. It must return `ENFORCEMENT_APPLIED` only after a future approved device-owner operation reports success from Android. Phase 15 introduces no Device Owner provisioning, no package suspension, no Accessibility service, no overlay interception, and no hidden API.

## References

[1]: https://developer.android.com/reference/android/app/usage/UsageStatsManager "UsageStatsManager API reference"
[2]: https://developer.android.com/reference/android/app/admin/DevicePolicyManager "DevicePolicyManager API reference"
[3]: https://developer.android.com/work/dpc/build-dpc "Build a device policy controller"
[4]: https://support.google.com/googleplay/android-developer/answer/10964491?hl=en "Google Play AccessibilityService policy"
