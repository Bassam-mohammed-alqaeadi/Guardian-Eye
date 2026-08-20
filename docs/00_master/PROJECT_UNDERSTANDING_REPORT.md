# PROJECT UNDERSTANDING REPORT — Guardian Eye Pro

**Date:** August 20, 2026 | **Author:** Manus AI | **Branch:** `feature/design-system-integration` (HEAD `a641e86`, +16 uncommitted files) | **Method:** Read-only inspection of docs, code, tests, and git history. No file was modified, no code was written, no package was added, no redesign was proposed.

---

## 1. The Actual Product Identity and Family Value

Guardian Eye Pro (`guardian_ai`) is an **Arabic-first, bilingual (AR/EN) Android family-safety platform** built in Flutter 3.35.6. Its stated promise is to help families stay *safer, more organized, more informed, and more connected* — delivered through a design philosophy of **honest states**: the app never displays a success the system did not actually confirm, never pretends a background capability works without native confirmation, and never shows a child a screen the child cannot act on. The brand voice ("عين الحارس" / "Guardian Eye Pro" per `appTitle` in `app_localizations.dart`) and the value set — trust, safety, calm, intelligence, family, clarity, responsibility — are embodied in a Material 3 design system with Cairo typography and navy `#0F2A5B` / teal `#00B8A9` semantics.

The product serves three personas. The **primary parent (owner)** holds full authority over web filtering, application control, screen time, location and geofencing, SOS, tasks and rewards, reports, and device enrollment, all enforced through one local policy engine. The **child** operates on a fail-closed enrolled device that obeys policy, may request exceptions, redeems earned points, and sees only its own privacy footprint. The **spouse/co-parent** shares family visibility but holds no device-administration authority, and a documented spouse-authority decision (owner-gated migration) remains open. The long-term commercial target (~USD 600K gross ARR by 2028) constrains monetization to honest value communication — no dark patterns.

**Evidence:** `docs/00_master/GUARDIAN_EYE_MASTER_PRODUCT_BLUEPRINT.md`; `docs/02_product/TARGET_EXPERIENCE_BLUEPRINT.md`; `lib/core/localization/app_localizations.dart`.

## 2. Implemented, Partial, Planned, Mocked, Broken, and Unverified Features

| State | Feature | Basis |
|---|---|---|
| **Implemented + verified** | Phase 0/1 design system (9 primitives, 5-tab navigation) | 380-test baseline, CL-007 |
| **Implemented + verified** | FS-001 Location & Geofencing — 15 screens LO-001..LO-015 | `location_screens.dart` + child screens; 10 green tests |
| **Implemented + verified** | FS-002 Web Filtering — 10 screens WF-001..WF-010 | 11 green tests; real remote wiring |
| **Implemented + verified** | FS-003 Application Control — 8 screens AC-001..AC-008 | 8 green tests |
| **Implemented + verified** | FS-004 Screen & Camera Monitoring — 9 screens SC-001..SC-009 | 11 green tests |
| **Implemented + verified** | FS-005 Custom Modes — 10 screens MD-001..MD-010 | 15 green tests |
| **Implemented + verified** | FS-006 SOS Expansion — 8 screens SO-001..SO-008 | 13 green tests |
| **Implemented + verified** | FS-007 Tasks + FS-008 Rewards — 15 screens TK-001..008 / RW-001..007 | 26 green tests; rule-gated completion, ledger-based points |
| **Implemented + verified** | FS-009 Reports & PDF — 8 screens RP-001..RP-008 | 10 green tests; aggregates FS-001..FS-006 + tasks/rewards |
| **Implemented + verified** | FS-011 Family Rules — 7 screens FR-001..FR-007 | 13 green tests; policy engine w/ execution log |
| **Implemented + verified** | FS-015 Device Linking — 11 screens DL-001..DL-011 | 10 green tests; SHA-256 codes, 5-attempt lockout, owner binding |
| **Implemented, unverified on device** | M1–M3 shells (canonical navigation, child context, enforcement domain) | 14/14 actor-binding tests; screens are decorated skeletons |
| **PARTIAL (complete code, uncommitted)** | **M9 background location tracking** — Kotlin foreground service + Dart coordinator + 22 new tests | 402/402 regression green; analyze 0 errors; Android runtime never validated; awaiting user's explicit commit confirmation |
| **PARTIAL** | Push notifications | Token storage exists (`DeviceTokenRepository`); **no server-side FCM sender exists anywhere** — alerts have no push path |
| **PARTIAL** | Firestore rules | Local `firestore.rules` + ruleset `e22c310a` referenced; deployed copy never compared live from this sandbox |
| **PLANNED** | FS-010 Ephemeral Chat (4), FS-012 Child Mode (5), FS-013 Couple Harmony (7), FS-014 Primary Dashboard (7), FS-016 Startup & Feature Gates (5) | `MASTER_FEATURE_MATRIX.md`, all rows `PLANNED` |
| **PLANNED (deferred)** | Phase 9 telemetry/normalization → Phases 10–11 Guardian AI (9 layers, 13 screens) → Phases 12–14 | User mandate: Guardian AI is the final layer |
| **BROKEN / gap** | `test/headless_validation_test.dart` hangs pre-existingly (excluded from gates) | Test exclusion grep |
| **BROKEN / gap** | Account deletion & data export flows do not exist (regulatory) | l10n audit: only 4 legacy keys, no screens |
| **Not broken** | Code quality — the Aug 20 quality audit found **zero actual code defects** across FS-001..FS-015 | `QUALITY_AUDIT_REPORT.md` |

**Evidence:** `docs/00_master/QUALITY_AUDIT_REPORT.md`; `docs/00_master/MASTER_FEATURE_MATRIX.md`; `docs/00_master/BACKGROUND_LOCATION_CLOSURE_REPORT.md`; `docs/03_security/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md`.

## 3. Repository Architecture and Current Data Flow

The codebase is strictly layered: `lib/core/` (SQLite database, Firebase bootstrap, ~1,375-key AR+EN localization, platform adapters, theme), `lib/domain/` (pure models and engines — policy, incident, screen time, tasks, rewards, rules, SOS, modes, device linking, web filtering), `lib/data/` (22 repositories/services plus remote readers and the outbox executor), `lib/application/` (119 Riverpod providers and coordinators), and `lib/presentation/` (GoRouter shell with 85 canonical paths in 27 screen files). Android side: `com.guardianeye.app` hosts `EnforcementService`, the new `LocationTrackingService`, `BootReceiver`, and MainActivity MethodChannel bridges (`enforcement`, `location_tracking`).

**Data flow is offline-first with honest outbox sync.** Every user action writes to SQLite (`GuardianDatabase`, version 24, idempotent migrations using `PRAGMA table_info` checks), queues an outbox row with an idempotency key, and a single-flight `SyncCoordinator` replays due rows to Firestore/Render. Reads prefer local SQLite; remote readers merge verified server facts honestly (a server removal deletes the local row). Two remote targets coexist: the **Render REST backend** (`guardian-eye-djg8.onrender.com`) — the only deployed provisioning surface, whose source lives **outside this repository** (no `render.yaml`) — and **Firebase** (Auth + Firestore + unpublished Functions). The points ledger (SUM of `delta`) and the task completion log are the sole sources of truth for their domains; no false "synced" or "rewarded" states are ever displayed.

**Evidence:** `docs/01_architecture/SYSTEM_FLOW.md`; `lib/application/sync_coordinator.dart`; `lib/core/database/guardian_database.dart`; `docs/00_master/RENDER_BACKEND_VERIFICATION_REPORT.md`.

## 4. User Roles and Permission Boundaries

Authorization is **centralized**: every permission check flows through `FamilyRuntimeContext.can(FamilyPermission, …)` anchored on `ctx.actor` — verified **zero uses of `ctx.me`** in any screen. The `FamilyPermission` ladder comprises 34 permissions: the **parent** holds all of them; the **spouse** holds all except device administration (`manageDevices`, `enrollDevices`); the **child** holds only view and self-scope permissions (`viewTasks`/`viewRewards` limited to own assignments, guarded by `childSelfScope`), and the device runtime is fail-closed — `ChildDeviceRepository.deliverPolicy` rejects any device that is not enrolled, the child may write only its own-device immutable paths (`usage_summaries`, `enforcement_status`), and it can never see cross-family data. Documented exclusions: ownership transfer is deliberately unimplemented (separate milestone), and child removal routes through membership revocation. The **spouse-authority decision** (migrate spouse to a defined authority set via owner approval) is a required, still-open product decision.

**Evidence:** `lib/domain/family_authorization.dart`; `lib/domain/guardian_models.dart`; `lib/domain/child_device_enforcement.dart`; `docs/01_architecture/POLICY_ENFORCEMENT_MODEL.md`.

## 5. Firebase, Firestore, FCM, Render, SQLite, Riverpod, and Offline-First Status

| Layer | Status |
|---|---|
| **SQLite** | Offline-first source of truth; version 24; 16+ tables spanning all subsystems; idempotent migrations |
| **Outbox sync** | Implemented and test-verified; single-flight `SyncCoordinator`; remote writer injected with real `FirebaseFirestore.instance` (no mock layer) |
| **Firebase Auth** | Bootstrap wired with emulator hooks; real-ID-token Render probes confirm the token flow against project `manus-guardian` |
| **Firestore** | Ruleset `e22c310a` deployed (includes child-device immutable append paths); direct remote readers active for location, web filter, application policy, child delivery, actor binding; **deployed rules never re-verified live** |
| **FCM** | Token registration repository exists; `firebase_options.dart` generated; **no push sender exists server-side** (no `send`/`sendMulticast` in Functions or Render) — FCM is storage without delivery |
| **Render** | Live and contract-verified with real auth (issue/redeem cycle: 200/201/401/404 all match `RemoteProvisioningService` error maps); source external to repo |
| **Firebase Functions** | `src/index.ts` contains the two provisioning `onCall` functions but is **unpublished** (Blaze plan requirement) — Render is the only operational provisioning path |
| **Riverpod** | 119 providers; `appRouterProvider` GoRouter shell; family runtime context propagates through all journeys |
| **Offline-first** | Core pattern holds; sync idle→syncing→synced→failed honest states; WorkManager re-registration documented |

**Evidence:** `docs/00_master/RENDER_BACKEND_VERIFICATION_REPORT.md`; `docs/03_security/REAL_FIREBASE_VALIDATION.md`; `lib/data/outbox_sync_executor.dart`; `lib/data/fcm_token_repository.dart`; `docs/04_backend/FIREBASE_REAL_ENVIRONMENT_SETUP.md`.

## 6. Current Design System and Its Family-Oriented UX Principles

The design system (Phase 0 baseline) specifies Cairo typography for AR/EN parity; navy `#0F2A5B` / deep `#0A1F44` / soft `#163872` and teal `#00B8A9` semantic tokens; Material 3 with 16-radius rounded cards; and shared primitives — `GuardianCard`, `GuardianSection`, `GuardianStateView` (empty/loading/error/offline/permissionRequired), `GuardianOfflineBanner`, `GuardianStatusChip`, `GuardianIconBadge`, `GuardianStatTile`, `GuardianHeroCard`. Images follow the ClipRRect-radius-16 `BoxFit.cover` hero pattern with `GuardianIconBadge` for iconography; 13 brand images sit in `assets/images/` with zero dangling references. The family-oriented principles are verifiable in the code: 22 of 25 screen files compose `GuardianStateView`; `GuardianOfflineBanner` surfaces offline honestly; `GuardianStatusChip` carries sync/device states without fake reassurance; and the interface is deliberately a warm family surface rather than a surveillance console. Bilingual parity is enforced by ~1,375 AR+EN key pairs via `l10n.t('key')`, with key insertion governed by a line-anchored script protocol (never tail-append, never index-based).

**Evidence:** `lib/core/theme/guardian_tokens.dart`; `docs/00_master/PHASE0_BASELINE_REPORT.md`; closure reports' image-placement audits.

## 7. Most Critical Blockers and Risks

1. **No Android execution capability** — the standing constraint prohibits emulator/SDK installation; consequently every Android-runtime claim (foreground services, permissions, boot persistence, battery behavior) is code-and-test-verified but **never observed on real hardware**.
2. **Push notifications are inert** — tokens are stored but nothing can send them; SOS and incident alerts currently have no push path.
3. **Backend change control is external** — Render source lives outside the repo; Functions are unpublished (Blaze gating); adding server paths requires coordination with an environment this sandbox cannot touch.
4. **M9 is uncommitted** — 16 files of completed, fully green work await the user's explicit commit confirmation.
5. **Remaining subsystems (FS-010/012/013/014/016) are unplugged** — the Phase 2.5 journey integration (dead-route sweep, canonical wiring) must follow the FS set.
6. **Telemetry layer does not exist** — Guardian AI's 9-layer system has no Phase 9 foundation yet; AI work cannot safely start before it.
7. **Security/hygiene risks** — ~97 MB `node_modules` in a historical baseline commit (cleanup requires owner approval); missing launcher source icon; two pre-existing flaky isolated widget tests (full suite passes); client-side revocation-after-membership-removal never exercised.

**Evidence:** `docs/03_security/GUARDIAN_EYE_GAP_AND_HUMAN_ACTIONS_REGISTER.md` (GA-1..GA-29); `docs/00_master/CHANGE_LOG.md`.

## 8. Exact Evidence Paths Supporting These Conclusions

The feature-state matrix comes from `docs/00_master/QUALITY_AUDIT_REPORT.md` (code-vs-doc verification of all 95 screens) and the per-FS closure reports FS003..FS015 + FS007_008. The architecture and data-flow claims trace to `docs/01_architecture/SYSTEM_FLOW.md`, `lib/application/sync_coordinator.dart`, and `lib/core/database/guardian_database.dart` (version 24). Role-boundary claims trace to `lib/domain/family_authorization.dart` and the actor-binding test suite (14/14 green). Backend claims trace to `docs/00_master/RENDER_BACKEND_VERIFICATION_REPORT.md` (live HTTP probes with real tokens) and `docs/04_backend/FIREBASE_REAL_ENVIRONMENT_SETUP.md` (Blaze gating). The FCM-absence claim is a repository-wide grep: no `send()`/`sendMulticast` call exists in `firebase/functions/src/` or `lib/`. Test-state claims trace to `/tmp/regression.log` outputs (402/402) and the `flutter analyze` outputs (0 errors). The uncommitted M9 state traces to `git status` (16 files) and `docs/00_master/BACKGROUND_LOCATION_CLOSURE_REPORT.md`.

## 9. Unknowns That Prevent Safe Implementation

The correct Firebase project binding in `firebase_options.dart` is verified only by file presence, not live sign-in; FCM sender/VAPID configuration is unobservable without console access; the deployed Firestore rules have never been re-compared against local `firestore.rules`; whether the external Render environment accepts new endpoints without cross-repo coordination is unknown; real-device behavior of M8/M9 services under Doze and battery optimization is unknown; the Blaze-plan approval status (blocking Functions publishing and any server-side push) is unknown; the spouse-authority product decision is unresolved; and token-revocation-after-membership-removal behavior was never exercised. Any implementation touching server state, push, or real-device paths must wait on these.

## 10. The Single Safest First Task Within Current Scope

**Commit the completed M9 background-location work** with the message `feat(m9): background location tracking + geofence crossing loop closure` — it is 100% code-verified (analyze 0 errors, 402/402 green, closure report written) and carries zero backend, design, or scope change. Immediately afterward the phase-ordered next deliverable is **FS-010 Ephemeral Chat** (the next independent planned row that does not depend on the unresolved spouse decision or the missing telemetry layer). All human actions — real-device validation access, Blaze approval, icon asset, cleanup commit — are listed for the owner's parallel action.

**Report ends here. No implementation has been started; awaiting your approval.**

---

*Prepared read-only; baseline commit `a641e86` plus 16 uncommitted files; evidence scripts/logs available on request.*
