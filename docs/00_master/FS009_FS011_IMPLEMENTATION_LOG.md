# FS-009 & FS-011 Implementation & Coherence Log

## FS-009 Reports & Export
- **Status**: CODE-VERIFIED.
- **Subsystems Included**: Location, Web, App, Safety (SOS/Incidents), Modes, Audio.
- **Key Fixes**:
    - Added `Cairo` font to `ReportExportService` for Unicode/Arabic support.
    - Replaced non-Unicode characters (dashes) in `ReportsRepository` and `ReportsExportService` to prevent PDF generation failures.
    - Integrated `AudioMonitoring` metrics into domain, repository, and presentation layers.
    - Fixed `Modes` metric to report real activation counts instead of mocked zero.
    - Updated UI with `AudioReportScreen` and detailed metrics.
- **Routes**: `/reports/:familyId`, `/reports/:familyId/audio`, etc.

## FS-011 Family Rules Engine
- **Status**: HARDENING IN PROGRESS.
- **Domain Fixes**:
    - Fixed `FamilyRule.isActiveAt` to correctly handle `oneTime` rules, daily rules (ignoring weekdays if empty), and minute-precision for all-day rules.
- **Repository Fixes**:
    - Fixed `applicableForChild` to properly check `isActiveAt` for schedule enforcement.
- **Presentation Fixes**:
    - Hardened `RuleBuilderScreen` and `RuleEditScreen` to collect `oneshotAt`, `geofenceIds`, `geofenceTrigger`, and `linkedTaskId`.
    - Updated `firestore_contracts.dart` to ensure advanced rule fields are synchronized to Firebase.
- **Pending**:
    - Replace ad-hoc text-entry pickers with real provider-backed selectors for Geofences and Tasks.

## Coherence Audit
- **Database**: v32 schema verified (all tables present).
- **Tests**: 659/659 PASSING (Regression suite verified).
- **Localization**: Added missing keys for reports and advanced rule kinds.
- **Router**: All routes for FS-009 and FS-011 registered and verified.
