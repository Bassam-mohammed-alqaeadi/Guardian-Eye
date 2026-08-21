# Guardian Eye Pro — Final Verification Baseline & Canonical Registry

**Authoritative baseline established by final verification agent loop.**

## 1. Repository Baseline
- **Root:** `/home/ubuntu/guardian_eye_repo`
- **Branch:** `feature/design-system-integration`
- **HEAD:** `b99a1c19b13e2e39e76691afe193a24ba3c779ed`
- **Status:** `CLEAN` (All changes committed in current session)
- **Flutter:** 3.35.6 (Dart 3.9.2)
- **Package:** `guardian_ai`
- **DB Version:** `v32` (verified in `guardian_database.dart`)
- **Tests:** `659/659 GREEN` (last verified)
- **Analyze:** `CLEAN` (0 errors)

## 2. Canonical Phase Registry (FS-001 to FS-016)

| ID | Name | Status | Screens | Evidence |
| --- | --- | --- | --- | --- |
| FS-001 | Location & Geofencing | COMPLETE-CODE-VERIFIED | 15 | `location_screens.dart`, `location_repository.dart`, `geofences` table |
| FS-002 | Web Filtering | COMPLETE-CODE-VERIFIED | 10 | `web_filter_screens.dart`, `web_hits` table, Render endpoints |
| FS-003 | Application Control | COMPLETE-CODE-VERIFIED | 8 | `application_screens.dart`, `AC-001..AC-008` routes |
| FS-004 | Screenshot & Camera | PARTIAL-IMPLEMENTATION | 9 | `monitoring_screens.dart`, `monitoring_repository.dart` (Service PENDING) |
| FS-005 | Special & Custom Modes | PARTIAL-IMPLEMENTATION | 10 | `modes_screens.dart`, `mode_config_repository.dart` (Service PENDING) |
| FS-006 | SOS & Emergency | COMPLETE-CODE-VERIFIED | 8 | `sos_screens.dart`, `sos_events` table |
| FS-007 | Tasks & Rewards | COMPLETE-CODE-VERIFIED | 10 | `tasks_screens.dart`, `tasks` table |
| FS-008 | One-Way Audio | COMPLETE-INTEGRATION-VERIFIED | 14 | `audio_screens.dart`, `audio_capture_service.dart`, Render relay |
| FS-009 | Reports & PDF | COMPLETE-CODE-VERIFIED | 7 | `reports_screens.dart`, `reports_repository.dart` |
| FS-010 | Family Chat | COMPLETE-CODE-VERIFIED | 4 | `chat_screens.dart`, `messages` table |
| FS-011 | Family Rules | COMPLETE-CODE-VERIFIED | 7 | `rules_screens.dart`, `policy_overrides` table |
| FS-012 | Child Mode | COMPLETE-CODE-VERIFIED | 5 | `child_mode_screens.dart`, `child_device_states` table |
| FS-013 | Couple Harmony | COMPLETE-CODE-VERIFIED | 7 | `couple_screens.dart`, `partner_linking` flow |
| FS-014 | Family Setup | COMPLETE-CODE-VERIFIED | 7 | `family_setup_screens.dart`, `PD-001..PD-007` routes |
| FS-015 | Device Linking | COMPLETE-CODE-VERIFIED | 11 | `device_linking_screens.dart`, `pairing_sessions` table |
| FS-016 | Startup & State | COMPLETE-CODE-VERIFIED | 5 | `startup_screens.dart`, `splash` → `role gate` flow |

## 3. High-Risk System Audit (FS-008)
- **Microphone:** `record` package used in `audio_capture_service.dart`.
- **Relay:** Render `/api/audio/upload/:sessionId` and `/api/audio/stream/:sessionId` verified in `guardian_backend/index.js`.
- **Notification:** Persistent foreground notification with ID `808` verified in `audio_capture_service.dart`.
- **Authorization:** `requireAuth` middleware in Render backend; `FamilyRuntimeContext` on app side.

## 4. Pending Gaps
- **FS-004/FS-005:** Screens are implemented but background services for screenshots/camera and custom mode enforcement are partial.
- **Kiosk Mode:** `ChildModeLockScreen` is presentation-only (no OS-level pinning).
- **Production Parity:** Render backend is verified in code but NOT deployed to production.
- **FS-007/FS-008 Ambiguity:** Master plan uses FS-007 for Tasks and FS-008 for Rewards, but One-Way Audio is also labeled FS-008. Canonical registry resolves this by keeping One-Way Audio as FS-008 and merging Tasks/Rewards as a safety vertical.
