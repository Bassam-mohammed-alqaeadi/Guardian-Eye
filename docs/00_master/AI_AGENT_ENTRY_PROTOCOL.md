# AI AGENT ENTRY PROTOCOL

**Mandatory onboarding sequence for every AI agent (or human) entering this project with zero conversational history.** Follow in order. Skipping steps is a violation.

## Step 0 — Orientation (2 minutes)

Read this file in full. Then open `MASTER_PRODUCT_EXECUTION_BLUEPRINT.md` and `MASTER_DEVELOPMENT_PLAN.md` (this directory) to learn WHERE THE PROJECT IS, WHAT IS ALREADY BUILT, WHAT IS BEING BUILT NOW, WHAT COMES NEXT, and WHAT MUST NEVER BE REBUILT.

## Step 1 — Read the Master Reference

`docs/00_master/MASTER_DEVELOPMENT_PLAN.md` — the constitution. Internalize Section 2.3 (what exists today), Section 3.2 (the ten hard rules), and Section 5.2 (the 21-field screen contract).

## Step 2 — Read CURRENT STATE

Repository snapshot: branch `feature/design-system-integration`, baseline commit `5a2bf25`, 247/247 tests green, design system complete (tokens, primitives, five-tab shell). Baseline history: `0caa405` Phase-18 checkpoint. Never touch `master` or `main`.

## Step 3 — Read CURRENT PHASE

`MASTER_FEATURE_MATRIX.md` — find the first row whose Status is not PLANNED/implemented. That is your work. The current phase is **FS-002 Web Filtering**; its screen specs are in Section 6.2 of the master plan.

## Step 4 — Read the Feature Index

`MASTER_FEATURE_MATRIX.md` top to bottom — understand the 16 subsystems, their order, and their dependencies before touching code.

## Step 5 — Read the target feature contract

Open the master plan's subsection for your target feature. It defines product intent, user model, every screen's route/purpose/UI composition/states/auth, events, and acceptance.

## Step 6 — Read affected screens

Check `MASTER_SCREEN_INDEX.md` for the screens your change touches and their current Status. Existing screens referenced by your work must not regress.

## Step 7 — Read navigation

`MASTER_NAVIGATION_MAP.md` — register new routes per the map's conventions; verify no dead routes (`m1_shell_test`); use `context.push` only.

## Step 8 — Read dependencies

`MASTER_PHASE_DEPENDENCY_MAP.md` — confirm your work's dependency type. If you touch a HARD dependency's contract, stop and record a `CHANGE_PROPOSAL.md` entry first.

## Step 9 — Read change governance

`CHANGE_LOG.md` (impact-analysis register) and Section 9 of the master plan. Every meaningful change requires the 17 impact fields before implementation, and must answer the six cross-phase impact questions.

## Step 10 — Read test/acceptance rules

- Full suite green (`flutter test`) before every commit — no exceptions.
- `flutter analyze` zero issues.
- Every new behavior adds tests; the suite only grows.
- Honesty audit: no fake success states, no dead ends, `GuardianOfflineBanner` where outbox mutations exist.
- All new strings localized AR+EN in `lib/core/localization/app_localizations.dart`.

## Step 11 — Inspect the code

Read the actual files your work touches — especially `lib/presentation/widgets/guardian_primitives.dart` (the nine primitives API), `lib/core/theme/guardian_tokens.dart`, `lib/presentation/router/app_router.dart`, `lib/core/localization/app_localizations.dart`, and the relevant providers. Do not rely on memory; read.

## Step 12 — Implement

Compose screens from the primitives only. Authorization only via `FamilyRuntimeContext.can()`. No new backend/schema/event-contract changes. Minimal dependencies.

## Step 13 — Test

Run `flutter test` and `flutter analyze`. Add widget/unit tests for every new behavior. Suite must be green.

## Step 14 — Update documentation

- `MASTER_SCREEN_INDEX.md`: update Status of every screen you implemented.
- `MASTER_FEATURE_MATRIX.md`: update your feature row's Status.
- Per-screen spec in `docs/06_ux/02_screens/<subsystem>/`.
- `CHANGE_LOG.md`: record the impact analysis.

## Step 15 — Update status

Commit on `feature/design-system-integration` (never master) with a descriptive conventional-commit message referencing the phase and feature. Push. Note the new baseline commit.

---

**What you must never break, regardless of the task:**
1. The Phase-17 security baseline (actor binding, permission matrix, fail-closed authorization).
2. The canonical `GuardianEvent` model (`lib/domain/guardian_event.dart`) — append only.
3. The Firestore schema and Render backend contracts.
4. The existing 247 tests and every future test.
5. The design system (tokens, primitives, Cairo, navy/teal).
6. Arabic/RTL support.
7. The honesty contract (never show false success).
