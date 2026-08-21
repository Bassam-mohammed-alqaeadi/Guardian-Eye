# PHASE 09 — Unified Event & Telemetry Layer

**Status:** `PLANNED`
**Objective:** Formalize the normalization of all subsystem signals into a unified telemetry stream for the Guardian AI engine.

## 1. The Gap
While `GuardianEvent` and `FamilyEventRegistryRepository` exist, they currently only handle a subset of subsystems. We need to:
1.  **Ingest all subsystems:** Add event types and normalization rules for Location, Web, App, Audio, Tasks, and SOS.
2.  **Normalize Signals:** Implement the `EventNormalizer` that converts raw events into `NormalizedSignal` feature vectors (the actual input for AI L1-L9).
3.  **Privacy Control:** Implement the `AiConsentScope` UI so parents can granularly control what data the AI sees.

## 2. Implementation Steps

### Step 1: Extend Event Domain
*   Update `GuardianEventType` in `lib/domain/guardian_event.dart` to include all missing subsystem signals.
*   Add metadata schemas for each new event type.

### Step 2: Implement Event Normalizer
*   Create `lib/application/event_normalizer.dart`.
*   Implement rules to map raw events (e.g., `webBlockHit`) to normalized signals (e.g., `web_safety_risk` with weight `0.8`).
*   Ensure the normalizer respects `AiConsentScope`.

### Step 3: AI Consent UI
*   Build `lib/presentation/screens/ai_consent_screen.dart`.
*   Allow parents to toggle processing for: Operational, Behavioural, Location, and Biometric (Audio/Camera) classes.

### Step 4: Registry Integration
*   Update `FamilyEventRegistryRepository` to automatically trigger normalization on event record.

## 3. Acceptance Criteria
*   [ ] Every subsystem (FS-001 to FS-016) emits at least one canonical event.
*   [ ] `NormalizedSignal` table in SQLite contains feature vectors from all active subsystems.
*   [ ] AI Consent screen correctly gates data ingestion into the signal table.
*   [ ] 659+ tests remain green.
