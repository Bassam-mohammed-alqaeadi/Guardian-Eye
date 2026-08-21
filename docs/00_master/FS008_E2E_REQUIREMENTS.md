# FS-008 End-to-End Audio Integration Requirements

## Status Classification
- **PARTIAL-IMPLEMENTATION** — LOCAL CAPTURE PRESENT, BACKEND STREAMING INCOMPLETE, REAL DEVICE UNVERIFIED.
- Do not change this status until the full end-to-end path is actually verified.

## Phase A — Confirm the authoritative backend phase
1. Read the current master plan, phase registry, backend specifications, Firebase contracts, Render service documentation, and existing server code.
2. Verify whether the planned backend streaming phase is truly Phase 10.
3. Inspect existing infrastructure:
    - Render backend application
    - Firebase Auth integration
    - Firestore session and device documents
    - Device-pairing and registration contracts
    - Firestore security rules
    - Session authorization model
    - Outbox and synchronization layer
    - Notification and foreground-service behavior
    - Audio policy and consent models
    - Encryption and transport configuration
    - Android and iOS platform configuration.
4. Do not invent a protocol if an existing backend contract exists. If no backend contract exists, define one explicitly before coding and document its security properties.

## Phase B — Implement the real end-to-end path
Complete the missing production path between the child device, Firebase authorization/session signaling, the Render backend, and the parent client.
- No `Future.delayed`, local-file simulation, audioplayers-as-receiver simulation, fake success, or mock services in production code.
- Required behavior:
    1. Parent request only when `FamilyRuntimeContext` and `FamilyAuthorization` permit.
    2. Child device must be registered and paired.
    3. Child receives request via Firebase/Render signaling.
    4. Child-side service requires correct policy and explicit consent before capture.
    5. Child receives persistent, visible active-monitoring notification.
    6. Parent receives actual audio stream through approved authenticated transport.
    7. Fail closed on invalid auth, pairing, policy, consent, etc.
    8. Authoritative service enforces maximum duration.
    9. Handle disconnects, stale sessions, duplicate starts, etc. honestly.
    10. No data retention unless explicitly required; define encryption/retention if needed.
    11. Authenticated and protected transport (replay, cross-family access).
    12. No weakening of Firestore rules.

## Phase C — Verify frontend and platform completeness
Verify screens AU-001 through AU-014 and all audio routes.
- Routes resolve from clean launch.
- No route overwrites.
- Real provider state connection.
- Honest state rendering (loading, offline, error, etc.).
- AR/EN localization and RTL/LTR layout.
- Accessibility semantics.
- Accurate child notification state.
- No "live" claims if backend is unavailable.
- Policy change propagation.
- Authorization via `FamilyRuntimeContext`.

## Phase D — Verification without false closure
Add/update tests for all aspects (auth, pairing, signaling, policy, consent, transport, isolation, etc.).
- Test doubles only in tests.
- Run: `dart format`, `flutter analyze`, focused tests, route/widget tests, Firebase rules tests, backend integration tests, full regression, secret checks.
- Do not call emulator/headless testing "real-device validation".

## Required Final Status
Use exactly one of:
- `FS008-END-TO-END-CODE-VERIFIED`
- `FS008-BLOCKED-BACKEND`
- `FS008-PARTIAL-IMPLEMENTATION`
- `FS008-FAILED`
