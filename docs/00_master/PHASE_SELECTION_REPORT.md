# Phase-Selection Report — Read-Only Audit

**Branch:** `feature/design-system-integration` · **HEAD:** `d050b3e` (local) · **origin:** `3bc6321`
**Date:** 21 Aug 2026 · **Author:** Manus AI
**Scope:** Purely read-only. No code was written, no files were modified (this report is the single exception, created as an audit artifact at the user's request), no commit, no push, no deployment.
**Verdict:** **NEXT PHASE SELECTED: FS-010 — Ephemeral Family Chat** (`CH-001…CH-004`), the only surviving Phase 6 capacity subsystem still `PLANNED`. Not an assumption: it is derived below from the authoritative master documents, and the two documents that appear to contradict this verdict are stale by direct evidence.

---

## 1. Document Inventory Read

| Document | Role | State relative to HEAD `d050b3e` |
| --- | --- | --- |
| `MASTER_DEVELOPMENT_PLAN.md` | Constitution — supersedes all earlier planning | Stale for phase order: declares "Phase 2 CURRENT: FS-002", baseline `5a2bf25`, 247 tests — none of which matches the current 494-test repository. Section 3.1 phase table is still its source of truth for ordering. [1] |
| `MASTER_FEATURE_MATRIX.md` | "Authoritative register of what to work on next", one row per feature, read top-down in Phase order | Same row table (Phase 2 FS-002 CURRENT … Phase 7 FS-014/015/016). Row statuses were never updated past CL-007, so its *statuses* are stale but its **Phase ordering column is the only formal ordering device in the plan**. [2] |
| `MASTER_PHASE_DEPENDENCY_MAP.md` | Compact dependency map: Phase 2 FS-002, Phase 3 FS-003+FS-015, Phase 4 FS-004+005+006, Phase 5 FS-007+008, Phase 6 FS-009+010+011+012+013, Phase 7 FS-014+016, Phase 8 FS-001 | Consistent with the matrix table. [3] |
| `MASTER_SCREEN_INDEX.md` | Per-screen registry | WF/LO/AC marked COMPLETED; **SO-001…SO-008, AS-001…AS-009, AU-001…AU-014, RP-001…RP-007, CH-001…CH-004, RL-001…RL-007, CM-001…CM-005, CO-001…CO-007, PD-001…PD-007, DL-001…DL-011, ST-001…ST-005, AI-001…AI-013 all still `PLANNED`** — despite substantial parts of these subsystems actually existing in code (see §3). This is the single largest documentation/implementation divergence. [4] |
| `CHANGE_LOG.md` | Impact register | Ends at CL-007 (coherence audit, tests 274). Nothing records FS-007/008 stabilization, FS-009, FS-011, FS-015, the AI/couple/subscription/M9 batch, or Phase 4A–4D. **Document is stale by ~220 tests of evidence.** [5] |
| `AI_COUPLE_SUBSCRIPTION_CLOSURE_REPORT.md` | Closure of the `3bc6321` batch (pushed) | Section 11 explicitly lists the remaining subsystems **from that batch's own perspective: FS-010, FS-012, FS-014, FS-016**. This is the most recent authoritative "what is left" statement. [6] |
| `PHASE4_DISCOVERY_REPORT.md`, `PHASE4_DELETION_EXPORT_CONTRACT.md` | Phase 4 formal contract | 4C/4D closed local-only; 4E requires a new authenticated owner-only endpoint on the Render backend → **BLOCKED-BACKEND** by your standing contract (no backend changes allowed until explicitly approved). [7] |
| `PHASE4C_CLOSURE_REPORT.md`, `PHASE4D_CLOSURE_REPORT.md` | Local closure reports (commits `d06780f`, `50b65c4`/`d050b3e`) | Both conclude "awaiting user direction": candidates 4E or "the next feature phase in the master plan." [8] [9] |

---

## 2. Actual Repository State vs. Documented Order

The master documents order the FS subsystems into nine phases. Comparing that order with what is actually implemented on `feature/design-system-integration`:

| Master-plan Phase | Subsystems | Documented order | Actual code state on HEAD |
| --- | --- | --- | --- |
| Phase 2 | FS-002 Web Filtering | CURRENT | **DONE** — WF-001…WF-010, `CURRENT`→`COMPLETED` in screen index [4] |
| Phase 3 | FS-003 App Control + FS-015 Device Linking | NEXT | **DONE** — 8 `/apps/…` routes; 11 `/safety/pairing`, `/enroll/…`, `/couple/…/link-device\|enroll\|role`, `/onboard/device-permissions`, `/settings/device/:id/…` routes [10] |
| Phase 4 | FS-004 Screenshot/Camera + FS-005 Custom Modes + FS-006 SOS | AFTER NEXT | **DONE** — 9 `/monitoring/…` routes; 9 `/modes/…` routes (incl. templates/conflict resolver); 8 SOS screens wired (`/sos` surface ~20 route hits) [10] |
| Phase 5 | FS-007 Offline AI Safety + FS-008 One-Way Audio | AFTER NEXT | **PARTIAL — FS-007 screen layer is FROZEN-LOCAL** (user froze the AI batch; `/ai-safety` routes exist in `3bc6321` but the AI layers are FROZEN per your standing constraint); **FS-008 One-Way Audio: `PLANNED`, not implemented** — zero `/audio/…` routes anywhere in the router [10] |
| Phase 6 | FS-009 + **FS-010** + FS-011 + FS-012 + FS-013 | LATER | FS-009: **DONE** (8 `/reports/…` routes). FS-011: **DONE** (7 `/rules/…` routes). FS-012: **`PLANNED` — no routes** (`/child/:fid/:cid/mode` baseline-adjacent exists but child-mode dashboard/lock/requests/privacy are absent). FS-013: **DONE** (7 screens `CoupleHub/Linking/Proposals/NewProposal/Routines/Responsibilities/Handovers` at `/couple/:familyId/{,linking,proposals,proposals/new,routines,responsibilities,handovers}`). **FS-010: `PLANNED` — zero `/chat/` routes** [10] |
| Phase 7 | FS-014 Primary Dashboard + FS-016 Startup & Gates | LATER | **`PLANNED` — not implemented**: `/family/create`, `/family/join/:code`, `/auth/confirm`, `/family/:fid/profile`, `/family/:fid/setup`, `/whats-new` all have 0 router hits. Phase 13 Subscription screens (`/subscription/:fid/*` ×6) exist only as the local-only `3bc6321` paywall, matching "no real payment" law [10] |
| Phase 8 | FS-001 Location & Geofencing | LATER (parallel) | **DONE** — 15 screens, CL-006 closed it [5] |
| Phase 4 (data-governance) | 4C purge / 4D export | — | **CLOSED-CODE-VERIFIED** (commits `d06780f`, `50b65c4`, `d050b3e`) |
| Phase 4E | Remote deletion/export | — | **BLOCKED-BACKEND** (contract requires new Render endpoint + Firebase Auth delete; backend-freeze standing rule) [7] |
| Guardian AI L1–L9 | Deterministic engine | FUTURE | **FROZEN** per your standing constraint; not a candidate |
| Phase 9 | Unified Event/Telemetry Layer | LATER | Not started (Phase-9 event registry was done as fail-closed infrastructure only within `3bc6321`; the normalization layer is untouched) |

**Reading:** every row above Phase 6 that is not explicitly frozen or blocked is done. Inside Phase 6 itself, FS-009, FS-011 and FS-013 are done. The two candidates left are **FS-010** and **FS-012** — both have zero routes. (FS-008 One-Way Audio, Phase 5, is also unimplemented, but your instruction to treat the frozen batch as FROZEN and the Phase 6 row as the active stream makes FS-010/FS-012 the live candidates.)

---

## 3. Why FS-010 (not FS-012, not FS-008)

1. **Ordering rule.** The master constitution's reading rule is explicit: "work down the table in `Phase` order; a row's dependencies must all be `IMPLEMENTED`/`TESTED` before starting it" [2]. FS-010 and FS-012 sit in the same Phase 6 row, and FS-010 is the earlier-numbered, earlier-specified row in every registry (matrix row order, dependency-map order, screen-index section order).
2. **Dependencies are satisfied for FS-010.** Its single hard dependency — "M5 membership lifecycle" — is implemented and verified (invite/accept/revoke, idempotent join, revocation cascading in Phase 17). FS-012's dependencies — FS-005 modes (done) **plus M8 enforcement** — are also satisfied, so the phase-table ordering is the honest tie-breaker, and it points to FS-010.
3. **Most recent "what is left" statement.** The closure report of the last accepted checkpoint (`3bc6321`, pushed) names FS-010 **first** among the four remaining subsystems (FS-010, FS-012, FS-014, FS-016) [6].
4. **FS-010 was explicitly deferred, never closed.** The master plan's FS-010 entry is still `PLANNED` with all four screens `PLANNED` in the screen index, no routes registered, no providers, no tests [4] [10]. It is the cleanest, smallest, fully specified scope among all open rows — a 4-screen subsystem that consumes only existing Firestore contracts (`messages`/`threads` collections under `families/{fid}` pattern) with no new backend, matching the zero-backend-changes law in its hard rules [1].
5. **Not FS-008.** One-Way Audio is the platform's most sensitive surface (Phase 17 sensitive-action law, spouse co-authorization). It was never approved for execution in any user directive; the last relevant directive froze the AI-adjacent batch. It remains a candidate only after an explicit user decision. Not assumed.
6. **Not 4E.** Requires a new Render endpoint (owner-only delete/export contract) — forbidden by the standing backend freeze until you approve backend work. Not assumed.
7. **Not Render deployment / device validation.** Those are external gates on existing work, not a product phase.

**No ambiguity requiring `NEXT-PHASE-BLOCKED-UNKNOWN`:** the plan is internally consistent on ordering. The *stale* parts (matrix row statuses, screen-index statuses, CHANGE_LOG) do not contradict the phase-order column — they merely lag behind commits. Evidence: the CHANGE_LOG's last entry (CL-007) predates 220+ later tests; the screen index still lists CO/MD/SC/AU/RP/RL as `PLANNED` while their routes exist and tests pass (494/494).

---

## 4. Selected Phase Detail — FS-010 Ephemeral Family Chat

| Field | Content |
| --- | --- |
| **Phase ID / name** | **FS-010 — Ephemeral Family Chat** (Phase 6 of the master plan) |
| **Screen IDs** | CH-001 Chat List · CH-002 Chat Screen · CH-003 Chat Settings (inline) · CH-004 Expired Conversation Notice (inline) |
| **Routes** | `/chat/:familyId` · `/chat/:familyId/:threadId` (settings/expired inline) |
| **Product intent** | In-family messaging with **24-hour auto-expiration**. Lightweight: list + chat, no attachments in phase 1. Threads are family / per-member / spouse, role-scoped. [1] |
| **Spec source** | `MASTER_DEVELOPMENT_PLAN.md` §6.10, spec screens CH-001–CH-004; screen registry `MASTER_SCREEN_INDEX.md`; navigation `MASTER_NAVIGATION_MAP.md` (future-routes section, Chat rows) |
| **Current implementation** | **None.** 0 `/chat/…` routes in `app_router.dart`; no chat providers/repos/screens in `lib/`; no chat tests. |
| **Depends on** | M5 membership (invite/join/revoke — DONE), `FamilyRuntimeContext` (Phase 17 — DONE), outbox/offline-first SQLite (M9 — DONE), honest-state UX primitives (`GuardianStateView`, `GuardianOfflineBanner`), l10n AR+EN |
| **Backend dependency** | **NONE new** — messages stored in existing Firestore families collection pattern, outbox-queued for offline writes; expiration enforced by read-time filtering + local TTL (per zero-backend-changes law) [1] |
| **Events** | Future `MESSAGE_SENT` consumer (Phase 9) — the feature documents the emission; implementation stays on existing contracts |
| **Authorization / privacy** | Thread role scoping ("any member, role-scoped threads") — every render and write goes through `FamilyRuntimeContext.can()`; no local role re-implementation. Expired messages must become unreadable with honest notice (CH-004) — never fake-persisted. Child actor isolation per Phase 17 law. Privacy class: ephemeral (delete-after-expiry, no export surface — export controls must skip chat payloads by design, consistent with 4D forbidden-key philosophy). |
| **Honest states** | loading / empty (no threads — invite members CTA) / offline (queued messages, banner) / error (retry) / expired-notice inline / unauthorized (honest error view) |
| **Test requirements** | Widget tests: CH-001 loading/empty/loaded/unauthorized + thread role scoping; CH-002 send/queue/expire behavior; CH-003 settings persistence; CH-004 expired-notice rendering. Full regression must stay ≥494 + new tests, all green; `flutter analyze` clean on new files; AR+EN key pairs verified. |
| **Acceptance criteria** | Per §6.10 + shared contract (§6.1): role-scoped thread list renders; message send survives offline (outbox) and shows honesty banner; 24h expiry is enforced and visible; no unauthorized access paths (child/revoked denied); routes registered in ShellRoute with dead-route guard; analyze clean; tests green. |
| **Risks / blockers** | (1) **BLOCKED-BACKEND risk**: a richer chat later wants a real push channel — phase 1 stays local/outbox-pattern only, consistent with the render-freeze. (2) Docs staleness: screen-index statuses for FS-010 are already `PLANNED`-correct, but a companion CHANGE_LOG entry (CL-008) is owed once work lands — documentation sync is a post-implementation obligation, not a blocker. (3) 494/494 baseline must be preserved; any Phase 4E temptation must be separately approved by you. |

---

## 5. Exclusions Applied (per your instruction)

Guardian AI layers — FROZEN, not evaluated. Phase 4C/4D — CLOSED-CODE-VERIFIED, excluded. Phase 4E — BLOCKED-BACKEND, excluded. Render deployment and Android real-device validation — external gates, excluded (both remain standing obligations on existing work). FS-008 One-Way Audio — sensitive surface, not approved for execution; kept as a user-decision candidate.

## 6. Recommended Next Step (waits on your approval)

Implement **FS-010 Ephemeral Family Chat** (CH-001…CH-004): local-first messaging over existing Firestore contracts, outbox-queued writes, 24h expiration with honest notices, role-scoped threads via `FamilyRuntimeContext.can()`, AR+EN localization, 4 focused tests + full regression ≥494 green, checkpoint commit **without push** until you say "commit", then report for your push approval.

---

## References

[1]: file://docs/00_master/MASTER_DEVELOPMENT_PLAN.md "MASTER_DEVELOPMENT_PLAN.md — §3.1 phase table, §6.10 FS-010 spec, §3.2 hard rules"
[2]: file://docs/00_master/MASTER_FEATURE_MATRIX.md "MASTER_FEATURE_MATRIX.md — phase register and reading rule"
[3]: file://docs/00_master/MASTER_PHASE_DEPENDENCY_MAP.md "MASTER_PHASE_DEPENDENCY_MAP.md — phase dependency order"
[4]: file://docs/00_master/MASTER_SCREEN_INDEX.md "MASTER_SCREEN_INDEX.md — per-screen PLANNED statuses"
[5]: file://docs/00_master/CHANGE_LOG.md "CHANGE_LOG.md — last entry CL-007"
[6]: file://docs/00_master/AI_COUPLE_SUBSCRIPTION_CLOSURE_REPORT.md "AI_COUPLE_SUBSCRIPTION_CLOSURE_REPORT.md — §11 remaining subsystems"
[7]: file://docs/00_master/PHASE4_DELETION_EXPORT_CONTRACT.md "PHASE4_DELETION_EXPORT_CONTRACT.md — remote deletion requires new endpoint"
[8]: file://docs/00_master/PHASE4C_CLOSURE_REPORT.md "PHASE4C_CLOSURE_REPORT.md — §7 next approved step"
[9]: file://docs/00_master/PHASE4D_CLOSURE_REPORT.md "PHASE4D_CLOSURE_REPORT.md — §7 next approved step"
[10]: file://lib/presentation/router/app_router.dart "app_router.dart — registered routes (read-only inspection)"

*All git evidence gathered read-only from branch `feature/design-system-integration`; no modifications were made other than creating this audit report file.*
