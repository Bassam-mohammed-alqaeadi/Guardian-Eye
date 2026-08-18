# Guardian Eye Pro — Handoff Guide for arena.ai

**Repository:** [Bassam-mohammed-alqaeadi/Guardian-Eye](https://github.com/Bassam-mohammed-alqaeadi/Guardian-Eye)
**Branch to start from:** `feature/design-system-integration`
**Latest commit:** `a26ee1e` — *"Phase 18: brand assets, splash, headless validation harness, project status report; APK build verified"*
**Never merge to `master`.** All future work must continue on `feature/design-system-integration` (or short-lived feature branches merged only into it).

---

## 1. What this project is

Guardian Eye Pro is a **Flutter 3.35.6 (Dart) family-safety Android app** (package `guardian_ai`). It gives parents visibility and control over their children's devices: location and geofencing, web filtering, screen-time policies, device linking, and a planned Guardian AI layer. It uses an offline-first architecture: SQLite (sqflite) locally, Firebase Auth + Firestore remotely, with an outbox-sync coordinator bridging the two. State management is Riverpod; navigation is GoRouter with a 5-tab bottom shell. The design system is Material 3 with navy `#0F2A5B`, teal `#00B8A9`, Cairo typeface, and full Arabic RTL support.

## 2. What is already complete (commit `a26ee1e`)

| Area | Status |
|---|---|
| Baseline subsystems M1–M9 (dashboard, members, safety experience, devices, policies, quick actions, settings, timeline, Firebase session) | Complete — ~30 screens |
| FS-001 Location & Geofencing (LO-001…LO-015, 15 screens, dependency-free canvas map, SQLite v16 tables, real Firestore pull bridge) | Complete |
| FS-002 Web Filtering (WF-001…WF-010 + child screens, 17 screens, SQLite v15, real Firestore backend) | Complete |
| Design system (9 primitives, dark/light tokens, localized strings ~1,143 keys AR+EN) | Complete |
| Master documentation (8 master docs under `docs/00_master/`, incl. `MASTER_DEVELOPMENT_PLAN.md`) | Complete |
| Tests: 274/274 Flutter tests passing; `flutter analyze`: 0 errors, 8 pre-existing warnings | Verified |
| Brand assets: app icon, navy splash, 4 onboarding illustrations wired into dashboard hero, location onboarding (LO-010), web-filter dashboard (WF-001) | Complete |
| Release APK builds successfully (`flutter build apk --release`, ~90 MB) | Verified — artifact at `build/app/outputs/flutter-apk/app-release.apk` |

The detailed current state is in `docs/00_master/PROJECT_STATUS_REPORT.md` in the branch.

## 3. What arena.ai must do (in priority order)

### Priority 0 — Real-device validation (the thing that could NOT be completed here)
The sandbox had no Android device/runtime, so real-device testing was never performed. The APK is built and valid; install it on a real Android device (or via Firebase Test Lab with an uploaded APK) and:

1. Install `app-release.apk` on an Android device, run it, and navigate every reachable screen (42 routes registered in `lib/presentation/router/app_router.dart`).
2. Validate the two parent journeys: dashboard → child tile → child context → policies; dashboard → geofence create → save.
3. Validate Arabic RTL layout and English LTR on the actual renderer (the headless harness already covered the widget layer; you must verify fonts, text shaping, and SafeArea behavior on device).
4. Validate offline behavior: put the device in airplane mode, create a geofence and a web-filter rule, return online, confirm outbox sync completes (check `PendingSyncBadge` / settings sync status screen).
5. Validate Firebase Auth end-to-end: sign in with a real Firebase project (you must create/attach a Firebase project and drop `google-services.json` into `android/app/`; the Render backend URL lives in `lib/core/` config — do not change Firestore rules or the Render schema).
6. Fix any device-only defects, re-run `flutter test` (must stay 274/274 green), rebuild the APK, and retest until clean.

### Priority 1 — Complete the remaining subsystems FS-003 … FS-016
Follow the master plan in `docs/00_master/MASTER_DEVELOPMENT_PLAN.md` and its phase documents. The established pattern per subsystem (follow it exactly — every previous subsystem followed it):

1. Write `FS-0XX-UX` (user stories, flows, IA, screen-by-screen spec) → `FS-0XX-TECH` → `FS-0XX-SECURITY` under `docs/`, in `docs/00_master/` update progress.
2. Build screens in `lib/presentation/screens/` (one widget per screen, grouped in subsystem files), register routes in `lib/presentation/router/app_router.dart`, add localization keys to `lib/core/localization/app_localizations.dart` for AR and EN, use design-system primitives from `lib/presentation/widgets/guardian_design_primitives.dart`.
3. Build the data layer in `lib/data/` (SQLite tables via `GuardianDatabase` migration bumping `version` in `lib/core/database/guardian_database.dart`, plus a real Firestore bridge in `lib/data/firestore_contracts.dart`).
4. Add Riverpod providers in `lib/application/guardian_providers.dart`, always scoped by family ID, authorization always via `FamilyRuntimeContext.can(...)` — never local role re-checks.
5. Add widget/unit tests; keep the full suite green.

### Priority 2 — Guardian AI layer (the platform's unique differentiator)
Planned after all subsystems complete (see master plan). This is the risk-scoring, incident-classification, and recommendation engine over the family data already collected by FS-001/FS-002.

## 4. Hard rules arena.ai must respect

- **Backend discipline:** no changes to existing Firebase rules, Firestore schema, or the Render backend. New subsystems extend — never modify.
- **Real integration only:** no mocks in production code paths; offline-first with outbox sync is mandatory for every new subsystem.
- **Honest-state UX:** every screen must show its real states (loading, empty, error, offline, permission-denied) — never fake success.
- **Design consistency:** Material 3, navy/teal tokens, rounded-16 cards, Cairo font, RTL-first Arabic.
- **Authorization:** always `FamilyRuntimeContext.can(...)`; runtime context provider pattern is `familyRuntimeContextProvider(familyId)` in `lib/application/family_context_provider.dart`.
- **Tests:** `flutter test` must pass (274+ tests growing with each subsystem); `flutter analyze` must stay at 0 errors.
- **Branch:** never merge to `master`; work on `feature/design-system-integration`.

## 5. Known environment caveat (so arena.ai doesn't waste time on it)

`test/headless_validation_test.dart` (the full-app headless harness) can stall in some software-rendered test environments when it repeatedly repumps the full app tree. The 274 core tests are stable; if the harness stalls, reduce screenshots to once per language and navigate routes via `GoRouter` within one pumped tree rather than repumping the whole app. Flutter 3.35.6, JDK 21, and Android SDK (platform-35, build-tools 34.0.0, NDK 28.2) are the verified build toolchain; note `android/app/proguard-rules.pro` must exist (empty is fine) or R8 fails.

---
*Prepared by Manus AI, 18 August 2026.*
