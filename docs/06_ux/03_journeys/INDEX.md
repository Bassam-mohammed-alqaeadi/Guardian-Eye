# User Journey Index — Guardian Eye Pro (Phase 0 Baseline)

**Status:** Documented · **Branch:** `feature/design-system-integration`

Phase 0 grounds the journey documentation in what the code already proves through its M1–M9 behavioral test suites. Full per-journey prose (matching the FS-002→FS-016 8-journey map) is authored as later subsystems are integrated; this index is the spine they attach to.

## Journeys Covered by the Existing Baseline

| Journey | Role | Evidence |
| --- | --- | --- |
| First-run / family setup | Parent | `widget_test` (opens empty family setup, no sample data) |
| Shell & navigation | Parent | `m1_shell_test` (themes, RTL, canonical router, dead routes, settings) |
| Child status review | Parent | `m3_child_context_test` (12 widget behaviors incl. loading/error/RTL/deep link) |
| Policy administration | Parent | `m6_policy_administration_test` (20 behaviors incl. preview arithmetic, RTL, outside-family actor) |
| Pairing & enrollment | Parent/Child | `pairing_screen` tests in the M4/M5 suites |
| Screen-time enforcement loop | System | `m7` usage measurement + `m8` enforcement tests |
| SOS / safety actions | Parent/Child | `safety_actions_screen` tests |
| Offline / sync queue | System | Outbox + sync provider tests; `GuardianOfflineBanner` in UI |
| Unverified actor gating | Any | `m1_shell_test` (disabled actions, never dead ends) |
| Firebase identity gate | System | `firebase_contract_test` (unconfigured/unauthenticated rejection, scoping) |

## Cross-Cutting Journey Rules

1. **Role routing** — identity → family membership → role → device relationship → permission scope → screens. One shell per role experience.
2. **Honest state** — every journey's failure modes surface as the four `GuardianStateView` states or disabled affordances; no silent omission.
3. **Failure-closed** — permission and enrollment failures explain and offer a path; they never render dead ends.
4. **RTL parity** — every journey renders correctly under Arabic (verified per-suite in the behavioral tests).
