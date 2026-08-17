# Android Permission Model — Phase 15

## Consent-oriented readiness

| Capability | Why Guardian Eye asks | User action | Denied/unsupported behavior | Phase 15 status |
|---|---|---|---|---|
| Usage Access | Measures foreground duration only for packages named by an active family policy. Android requires both declaration of `PACKAGE_USAGE_STATS` and an explicit Settings grant. [1] | User chooses **Open Usage Access** and enables Guardian Eye in Android Settings. | Measurement returns `blockedByPermission`; no counter or protection success is shown. | Implemented boundary; physical validation required. |
| Notifications | Optional parent-visible status/alerts in later slices. | Android runtime permission flow. | No notification delivery is claimed. | Existing capability only. |
| Accessibility | Not selected for Phase 15. Google Play requires disclosure/consent/declaration and restricts autonomous behavior. [2] | No request is shown. | App-blocking remains unsupported. | Not implemented. |
| Device Owner / DPC | Potential future managed-device edition, not a consumer default. | Separate explicit provisioning and organization/device-owner consent. [3] | Normal device reports unsupported for package blocking. | Not implemented. |

## In-product language

The child device must be told that Usage Access helps the family measure agreed app time, which app identifiers are included, and that denying access means the app cannot measure time or prove a limit was exceeded. The parent view must distinguish **permission ready** from **usage observed** and **OS enforcement applied**.

## References

[1]: https://developer.android.com/reference/android/app/usage/UsageStatsManager "UsageStatsManager API reference"
[2]: https://support.google.com/googleplay/android-developer/answer/10964491?hl=en "Google Play AccessibilityService policy"
[3]: https://developer.android.com/work/dpc/build-dpc "Build a device policy controller"
