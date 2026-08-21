# FS-010 Ephemeral Family Chat — Closure Report

**Status:** CLOSED-CODE-VERIFIED
**Commit:** `0642365` (local checkpoint, NOT pushed — awaiting user approval)
**Branch:** `feature/design-system-integration`
**Author:** Manus AI
**Date:** 2026-08-21

## 1. What was delivered

FS-010 implements **Ephemeral Family Chat** (CH-001 through CH-004), the last remaining subsystem of the master plan's Phase 6 row and the final approved feature before Phase 7 (family profile and startup flows). The implementation is **local-first per the zero-backend law**: there is no new backend, no new Firestore paths, and no Render changes. Chat is written locally, enqueued to the existing outbox, and the recipient side will render messages through the same pull contract already in place; remote chat sync is explicitly out of scope and reported as BLOCKED-EXTERNAL until the sync gate is unblocked.

| Screen | Route | Contract screen | Delivered |
|---|---|---|---|
| Family chat list | `/chat/:familyId` (from Settings "Chats" tile) | CH-001 | Yes |
| Chat thread | `/chat/:familyId/:threadId` | CH-002 | Yes |
| Approaching-expiration notice | Banner inside chat | CH-003 | Yes |
| Thread-exhausted notice | Banner when all messages expired | CH-004 | Yes |

The design system is applied consistently: Material 3 cards with 16 px radii, navy `#0F2A5B` / teal `#00B8A9` palette, Cairo typeface, `GuardianStateView` honest-state machine, `GuardianOfflineBanner`, and full AR (RTL) + EN localization with 20 new key pairs inserted in alphabetical blocks in both maps.

## 2. Technical foundation

**Database v30.** The schema adds two tables, `chat_threads` and `chat_messages`, registered in both `_createSchema` (fresh installs) and the v30 incremental migration block (upgrades), so a fresh install at v30 and an upgrade from v29 produce identical outcomes. Every message carries a **unique idempotency key** (`chat:{family}:{thread}:{sender}:{minute-bucket}:{trimmed-body}`), which is the single mechanism that guarantees the duplicate-send test: the same (thread, sender, body, minute) can never be claimed twice.

**Honest send outcomes.** `FamilyChatRepository.sendMessage` returns exactly one of `sent`, `duplicate`, or `failed`. A duplicate detection never writes anything and never claims a state. The send transaction inserts the message and the outbox row atomically, with a `data-only` payload (no push tokens, no outbox state, no device identifiers) following the same hardening pattern as the Phase 3 `/api/notify` contract.

**Read-time expiration sweep.** Messages are never silently deleted. `sweepExpired()` marks rows as `expired` when their real UTC clock has passed the baked `expires_at` (created_at + 24 h), and computes **exhausted threads** — threads with zero non-expired messages — so the UI can render the CH-004 exhausted notice honestly instead of showing an empty chat that pretends to be alive. Active views filter on `state != 'expired'` and `expires_at > now` at read time.

**Family binding denial.** The send path resolves a thread by id and then asserts `thread.familyId == familyId`, throwing `chat_cross_family_thread` on a mismatch — a mismatched family can never deliver a message into another family's thread, and the denial surfaces to the UI with the honest error code instead of a missing-thread ambiguity.

**Authorization.** Two new permissions (`viewChat` on the action surface; a spouse-scoped visibility rule for thread scope) were added to `FamilyPermission` and mapped in `FamilyAuthorization` to `primaryParent`, `parent`, `coParent`, and `spouse` — **children never enter chat**. The service layer fails closed: `_canAct` requires a verified, active actor, `requireViewChat` throws an explicit `StateError` for unauthorized actors, and thread visibility (`_actorCanSee`) enforces the role scoping contract — family threads admit all adults, member threads admit only the named pair, spouse threads admit only the symmetric bound pair.

**Privacy contract (Phase 4 inheritance).** `chat_threads` and `chat_messages` were appended to the safe-purge table list in the correct foreign-key order (after referencing tables, before `family_members`), preserving the disjoint-const purge test. Both tables were added to the export forbidden-key scanner in `family_data_export_service.dart`, so chat data can never enter an export bundle under any code path.

## 3. Verification

| Check | Result |
|---|---|
| Focused FS-010 tests | **16/16 green** — schema v30, thread creation determinism, member-thread guard, 24 h expiration baked at write time, idempotent duplicate send, expired-message exclusion + sweep report, outbox data-only payload, cross-family binding denial, child denial, invited-member fail-closed, unverified fail-closed, spouse pair scoping, member thread scoping, purge inclusion, no device identifiers in payload, AR+EN key completeness |
| Full Flutter regression | **510/510 green** (494 baseline + 16 FS-010) |
| Migration gate tests | **7/7 green** (upgrade mechanics unchanged by v30) |
| flutter analyze (13 changed files) | Clean except the one pre-existing router lint (line 306), present since Phase 4C |
| Secrets / unrelated changes | None — diff is scoped to FS-010 files plus the phase-selection audit artifact |

## 4. Honest boundaries

Three statuses are declared separately and must not be collapsed into "done". **CODE-VERIFIED**: the entire claim above is exercised by real SQLite databases, not mocks. **SERVER-VERIFIED / PRODUCTION-VERIFIED**: not performed — no backend or Render work was done, and remote chat sync remains BLOCKED-EXTERNAL. **DEVICE-VERIFIED**: not performed — the UI state machines, RTL rendering, and share-sheet behavior have not been exercised on a real Android device; headless validation was available but was not re-run for this batch because no code path changed the previously validated foundations. Nothing in this report claims otherwise.

## 5. What remains after this phase

With FS-010 closed, the master plan's next unimplemented row is **Phase 7 — FS-014 (family profile/setup) and FS-016 (startup/onboarding flow)**, followed by Phase 8 (FS-001 location and geofencing, still NOT-IMPLEMENTED) and the external gates: Phase 4E remote deletion/export (BLOCKED-BACKEND), Render deployment, and Android device validation. FS-008 (one-way audio) and FS-010-adjacent remote chat sync are not to be started without explicit approval.
