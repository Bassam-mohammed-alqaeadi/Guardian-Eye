# REMAINING WORK ROADMAP — Guardian Eye Pro

**Date:** August 21, 2026
**Commit:** `e175959`
**Phase:** 9–14 (Intelligence & Hardening)

## 1. Phase 9: Unified Event & Telemetry Registry
*   **Objective:** Normalize signals from all 16 subsystems for AI consumption.
*   **Tasks:**
    1.  Extend `FamilyEventRegistryRepository` to ingest Web, App, and Audio signals.
    2.  Implement `EventNormalizer` logic to convert raw events into `NormalizedSignal` feature vectors.
    3.  Define the `AiConsentScope` UI for granular privacy control.
*   **Evidence:** `lib/domain/guardian_event.dart` and `lib/data/family_event_registry_repository.dart` are foundational but incomplete.

## 2. Phase 10-11: Guardian AI Intelligence Rollout
*   **Objective:** Move from deterministic rules to the 9-layer intelligence engine.
*   **Tasks:**
    1.  Implement the 9-layer `GuardianAiDeterministicEngine` (L1-L9) in the application layer.
    2.  Complete the **Insights Hub** (A-001) with real scorecard data.
    3.  Build the **Copilot** (A-006, A-007) chat and suggestion surfaces.
    4.  Implement **Smart Policy Proposals** (A-009) where AI suggests rule changes for parent approval.
*   **Evidence:** `insights_screens.dart` contains UI shells but lacks deep integration with the AI engine.

## 3. Phase 12: Automated Safety Workflows
*   **Objective:** AI-driven incident triage and response.
*   **Tasks:**
    1.  Implement automated "Safe/Watch/Alert" status transitions for family members.
    2.  Build the **Risk Overview** (A-002) and **Explanation View** (A-004).
*   **Evidence:** `guardian_ai_models.dart` defines the risk levels, but the triage engine is missing.

## 4. Phase 13: Commercial Maturation
*   **Objective:** Production-ready entitlements and subscription management.
*   **Tasks:**
    1.  Implement real **Usage Metering** (e.g., number of listening minutes used).
    2.  Connect the **Paywall** (CMR-002) to a real billing provider (or mock production flow).
    3.  Verify **Entitlement Enforcement** across all AI and monitoring features.
*   **Evidence:** `subscription_screens.dart` exists but is currently local-only.

## 5. Phase 14: Production Hardening & Resilience
*   **Objective:** Ensure the app survives real-world Android constraints.
*   **Tasks:**
    1.  **Doze/App Standby Resilience:** Harden background services (Location, Audio) against OS termination.
    2.  **Reboot Persistence:** Ensure services restart automatically on device boot.
    3.  **Production Firebase Config:** Switch from emulator/test seeds to production security rules and indexes.
    4.  **Final APK/Bundle Signing:** Prepare for Store distribution.
*   **Evidence:** No dedicated resilience or hardening files found yet.

## 6. Summary of Status
The platform has a **complete skeleton** and **functional muscles** (all subsystems). We are now building the **nervous system** (Phase 9) and the **brain** (Phase 10-12).
