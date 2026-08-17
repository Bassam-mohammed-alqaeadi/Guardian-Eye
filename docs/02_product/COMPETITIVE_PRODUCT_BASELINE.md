# Competitive Product Baseline

## Scope and method

This is a lightweight product baseline, not a design or implementation copy. It compares publicly described capability categories from major family-safety products and converts them into a Guardian Eye roadmap. Product claims are attributed to each vendor’s own public material and are not treated as independent performance verification.

| Baseline capability | Public market signal | Guardian classification | Phase 15 relevance |
|---|---|---|---|
| Daily device/app time, schedules, bedtime/school time | Family Link describes daily limits, individual app limits, School Time, and Downtime; Qustodio, Bark, FamiSafe, Norton, and OurPact market time rules/schedules. [1] [2] [3] [4] [5] [6] | **COMPETITIVE_PARITY** | Build deterministic observation and accounting; do not claim blocking yet. |
| App and web management | Major products market app or website limits/filtering. [1] [2] [3] [4] [5] [6] | **COMPETITIVE_PARITY** | Future, because ordinary Android capability does not provide universal app blocking. |
| Parent/child rule dialogue and requests | Norton describes house rules and in-app access requests; Life360 emphasizes open communication and explicit boundaries. [5] [7] | **GUARDIAN_DIFFERENTIATOR** | Add transparent reason/status and an exception-request boundary; do not fabricate remote delivery. |
| Safety alerts and risk insights | Bark, Qustodio, and FamiSafe promote alerts/monitoring; Guardian must handle sensitive data with a narrower, privacy-aware on-device design. [2] [3] [4] | **COMPETITIVE_ADVANTAGE** | Architecture only; no Phase 15 AI/content collection. |
| Location, places, SOS and driving safety | Family Link and Life360 describe family location/place alerts; FamiSafe and Qustodio market related family-safety functions. [1] [3] [7] | **COMPETITIVE_PARITY** | Existing future roadmap only. |
| Family collaboration, agreement and transparency | Competitor messaging increasingly references schedules, boundaries, and requests, but Guardian’s Arabic-first family agreements, clear evidence levels, offline-first local policy, and child explanation are the intended distinctive combination. [5] [7] | **GUARDIAN_DIFFERENTIATOR** | Guide Phase 15 UX. |
| Multi-parent/multi-child/device management | Family-focused products describe child/device management across family accounts. [1] [2] [5] | **COMPETITIVE_PARITY** | Preserve existing family/device architecture; no scope expansion. |
| Advanced managed-device control | Device-policy control belongs to Android managed-device deployments, not a normal consumer app flow. [8] [9] | **FUTURE** | Evaluate only as an explicit, owner-provisioned advanced edition. |

## Product implications

Guardian Eye should match the expected family workflow—enroll a child device, set rules, understand time use, see whether a capability is ready, and discuss exceptions—without mimicking surveillance-first interfaces. The immediate value is a trustworthy distinction among **configured**, **locally delivered**, **evaluated**, **enforcement requested**, and **operating-system applied**.

The Phase 15 selected slice is therefore **Usage Access-backed observation and local screen-time accounting**. It is a prerequisite for reliable limits and reports. Universal application blocking, content capture, location, and AI monitoring remain separate vertical slices with their own consent, platform, policy, and device evidence gates.

## References

[1]: https://families.google/familylink/ "Google Family Link"
[2]: https://www.qustodio.com/en/ "Qustodio parental control"
[3]: https://www.bark.us/learn/top-parental-control-app/ "Bark parental controls"
[4]: https://famisafe.wondershare.com/ "FamiSafe product overview"
[5]: https://us.norton.com/feature/parental-control "Norton Parental Control"
[6]: https://www.ourpact.com/ "OurPact parental controls"
[7]: https://www.life360.com/learn/should-parents-use-life360 "Life360 family location sharing"
[8]: https://developer.android.com/reference/android/app/admin/DevicePolicyManager "Android DevicePolicyManager"
[9]: https://developer.android.com/work/dpc/build-dpc "Build a device policy controller"
