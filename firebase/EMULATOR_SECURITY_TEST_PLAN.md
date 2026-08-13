# Firebase Emulator Security Test Plan

The current Firestore rules are an **un-deployed template**. Run the following cases in a Firebase Emulator before using any production project. Each case must authenticate the named actor and assert `allow` or `deny` against the real deployed rule set.

| Case | Expected result |
|---|---|
| Parent A reads family B | Deny. |
| Child or spouse changes a policy | Deny. |
| Primary parent creates an active device owned by themselves | Allow. |
| Parent other than the recorded device owner changes that device | Deny. |
| Unpaired or revoked device creates incident/location/SOS | Deny because it is not an active owned device. |
| Active child device creates an incident for its family | Allow. |
| Active child device reads incidents, locations, or SOS history | Deny. |
| Parent acknowledges an incident in their family | Allow. |
| Parent writes to another family’s notification event | Deny. |
| Any client writes notification events directly | Deny; a privileged backend service must produce notifications. |

Do not call the rule set verified until the emulator commands and results are captured in `IMPLEMENTATION_EVIDENCE.md`.
