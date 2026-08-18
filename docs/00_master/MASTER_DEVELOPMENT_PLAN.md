# Guardian Eye Pro — Master Development Plan (Current → Final Platform Completion)

**Document type:** Single authoritative development constitution — supersedes all previous phase planning documents.
**Baseline:** `5a2bf25` on `feature/design-system-integration` (Phase 0 + Phase 1 complete).
**Companion documents:** `MASTER_SCREEN_INDEX.md`, `MASTER_FEATURE_MATRIX.md`, `MASTER_NAVIGATION_MAP.md`, `MASTER_PHASE_DEPENDENCY_MAP.md`, `AI_AGENT_ENTRY_PROTOCOL.md`, `CHANGE_LOG.md`, `DESIGN_DECISION_LOG.md`.
**Author:** Manus AI · **Date:** August 18, 2026
**Status:** `CURRENT` · Governs all future human and AI development until superseded by a signed successor.

---

## 0. Where the Project Is Now — Read This First

**Guardian Eye Pro is a functionally advanced Phase-18 platform with a strong, verified backend/safety foundation and a UX layer that is currently being completed.** This plan starts exactly where the repository stands and continues to final platform completion. It does not restart M1–M9; those are **HISTORICAL / VERIFIED** foundation.

| Question | Answer |
| --- | --- |
| **WHERE THE PROJECT IS NOW** | Branch `feature/design-system-integration`, commit `5a2bf25`. Design system baseline + all 14 baseline screens upgraded to design primitives. 247/247 tests green. |
| **WHAT HAS ALREADY BEEN BUILT** | Auth, family membership, pairing/enrollment, policy engine, screen-time evaluation, incidents/SOS, offline outbox, canonical `GuardianEvent` contract, AR+EN localization, Material 3 design system, 5-tab navigation shell. |
| **WHAT IS CURRENTLY BEING DEVELOPED** | The product experience / screen system: FS-002 → FS-016 capability screens (~131 new screens beyond the 14 baseline), in the order defined in Section 4. |
| **WHAT COMES NEXT** | FS-002 Web Filtering (immediately), then FS-003, FS-004 … FS-016 per dependency order; then the Guardian AI system (9 layers, ~10 screens); then commercialization and production hardening. |
| **WHAT MUST NOT BE REBUILT** | M1–M9 foundations, Phase 17 security baseline, Phase 18 event/sync core, Firebase contracts, Render backend (`guardian_backend`), the canonical `GuardianEvent` model, `FamilyRuntimeContext` authorization. |

Any AI agent entering this project with zero conversational history can implement the entire remaining platform from this document alone.

---

## 1. Historical Foundation (COMPLETED — Read-Only Context)

The historical work below is **verified history**. Do not reimplement it. Do not spend the active roadmap on it. Reference it when a future change might touch a foundation contract.

### M1–M9 (UX Sprint 01) — FOUNDATION / VERIFIED HISTORY

| Milestone | What was established | Why it matters today |
| --- | --- | --- |
| M1 — App Shell + Canonical Navigation | `GoRouter` shell, dead-route guard, AR+EN LTR/RTL | Every new route must register in this router and obey the dead-route guard |
| M2 — Parent Dashboard Foundation | Family identity, safety signal from real incidents, child overview joined to real device state | The Dashboard screen and its providers are the anchor of the whole UX |
| M3 — Child Context Vertical | `/child/:fid/:cid` vertical with honest capability states | Child-device relationship UI pattern reused by all FS screens |
| M4 — Child Device Setup | Parent pairing UI, device state display | Pairing repository is the enrollment engine FS-015 builds on |
| M5 — Invitation & Join | Multi-parent invite/accept/revoke with idempotency | Membership lifecycle powers FS-013/FS-014 couple and co-parent flows |
| M6 — Policy Administration | Screen-time policy admin with read-only gating | The exact UI contract (addFirstPolicy vs createPolicy) FS-011 rules must not break |
| M7 — Usage Measurement | Daily usage summaries | FS-003/FS-009 report off these aggregates |
| M8 — Child Enforcement | Policy enforcement on child device | FS-005 custom modes and FS-012 child mode consume this |
| M9 — Sync & Offline | SQLite + outbox + retry + idempotent writers | Every FS subsystem inherits offline-first behavior from this |

### Phase 17 — Trusted Actor Binding (COMPLETED / VERIFIED)

The security core: `FamilyRuntimeContext` fail-closed authorization, `FamilyActorBindingService` (account UID ≠ member ID ≠ device ID), `FamilyAuthorization` permission matrix, owner-only sensitive gates, revocation cascading. **Law 1: no screen ever re-implements authorization; every screen calls `FamilyRuntimeContext.can()`.** This contract is the single most protected artifact in the platform.

### Phase 18 — GuardianEvent Contract + Incident/SOS Hardening (COMPLETED / VERIFIED)

Baseline `0caa405`. Canonical `GuardianEvent` model with `actorUid / memberId / childId / deviceId` distinction, `GuardianEventType` enum, `GuardianPrivacyClass` retention classes, `SyncState` outbox lifecycle, incident/SOS hardening, FCM delivery. **This event contract is immutable for the purpose of this plan; new features ADD event types, never modify existing ones.**

---

## 2. Active Starting Point — Current State

### 2.1 Verified repository capabilities

| Layer | Status | Evidence |
| --- | --- | --- |
| Engineering foundation | STRONG / VERIFIED | 247/247 tests, analyze clean, protected checkpoint `phase17-stable-checkpoint` |
| Backend (Firebase + Render) | STRONG / VERIFIED | Models, repositories, outbox, functions — local-verified |
| Safety engine | STRONG / VERIFIED | Policy engine, incident engine, SOS local pipeline |
| Sync / Identity | STRONG / VERIFIED | Outbox, actor binding, membership lifecycle |
| UX / Design system | **CURRENT DEVELOPMENT PRIORITY** | Phase 0/1 complete on baseline screens; FS screens pending |
| Screen system | **CURRENT DEVELOPMENT PRIORITY** | ~131 screens from FS-002→FS-016 not yet implemented |
| Missing product capabilities | NEXT DEVELOPMENT STREAM | Filtering, location, screenshots, audio, chat, reports, modes |
| AI | FUTURE MAJOR PHASE | Layer 1 fail-closed infrastructure only |

### 2.2 Current phase declaration

```text
CURRENT PHASE:            UX Transformation — Screen System Buildout (FS-002 onward)
CURRENT SUB-PHASE:        Phase 2 — FS-002 Web Filtering screens
CURRENT PRODUCT PRIORITY: Complete the 16 approved subsystem screen systems
CURRENT DESIGN PRIORITY:  Every screen built from the 9 Guardian primitives + honest-state views
CURRENT ENGINEERING PRIORITY: Keep 247 tests green; add tests per feature; analyze clean
CURRENT BLOCKERS:         None — sandbox lacks KVM for emulators (user tests on own device; RUN_GUIDE.md)
CURRENT DEPENDENCIES:     Flutter 3.35.6, Firebase config (unchanged), existing providers
CURRENT NEXT DELIVERY:    FS-002 Web Filtering: dashboard, categories, blocklist (3 screens)
```

### 2.3 What exists in code today

The app currently ships 14 screens: dashboard (`/`), child context (`/child/:fid/:cid`), child policies (`/child/:fid/:cid/policies`), family members (`/family/:fid`), safety policies (`/safety/policies/:fid`), device status (`/safety/device-status/:fid`), daily safety (`/safety/daily/:fid`), timeline (`/timeline/:fid`), exception requests (`/requests/:fid`), settings (`/settings`), firebase-session, pairing (`/safety/pairing/:fid`), device-link (`/device-link/:fid`), permissions (`/safety/permissions`). All are upgraded to the design system. The five-tab shell (`Home / Children / DailySafety / SafetyTimeline / Settings`) wraps all routes.

---

## 3. The Roadmap — From Now to Final Platform Completion

The roadmap begins at the current phase and runs to production scale. Seven streams, executed top-down (earlier streams are hard dependencies of later ones; AI streams are parallel-prepared by the event contracts built in the current stream).

```text
STREAM 1 — CURRENT:   Product Experience / Screen System Buildout (FS-001…FS-016)
STREAM 2 — NEXT:      User Journeys & Capability UX Integration (journeys docs, cross-feature wiring)
STREAM 3 — NEXT:      Unified Event / Telemetry Layer (event normalization, consumer contracts)
STREAM 4 — NEXT:      AI Readiness (on-device inference bootstrap, model artifact review)
STREAM 5 — FUTURE:    Guardian AI Foundation + 9 Intelligence Layers (~10 screens)
STREAM 6 — FUTURE:    Advanced Product Experience (automation, reporting/insights, couple harmony maturation)
STREAM 7 — FINAL:     Commercial Scale (subscriptions, entitlements) + Production Hardening + Scale
```

### 3.1 Current-vs-future phase table

| Order | Phase | Purpose | Dependencies | Expected screens | Backend changes | AI relevance | Acceptance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **CURRENT** | Phase 2: FS-002 Web Filtering | First capability vertical on the new design system | Design system (Phase 0/1) | 3 + 1 settings | None | Feeds web-safety AI signals | Tests green, analyze clean |
| NEXT | Phase 3: FS-003 App Control + FS-015 Device Linking | Application allow/block control; child/spouse device enrollment UX | FS-002 patterns | ~12 | None | App-usage signals | Same gate |
| AFTER NEXT | Phase 4: FS-004 Screenshot/Camera + FS-005 Custom Modes + FS-006 SOS expansion | Monitoring surfaces and emergency expansion | Phase 3 | ~18 | None | Screenshot evidence layer | Same gate |
| AFTER NEXT | Phase 5: FS-007 Offline AI Safety + FS-008 One-Way Audio | On-device safety detection UX; live audio with consent gates | Phase 4, AI artifact review | ~18 | None (Render endpoints consumed as-is) | Direct on-device AI UX | Same gate |
| LATER | Phase 6: FS-009 Reports + FS-010 Family Chat + FS-011 Rules Engine + FS-012 Child Mode | Reporting, ephemeral chat, rule engine, child-facing mode | Phase 5 | ~20 | None | Report inputs / rule intelligence | Same gate |
| LATER | Phase 7: FS-013 Couple Harmony + FS-014 Primary Dashboard + FS-016 Startup & Feature Gates | Full role experiences: spouse, onboarding, subscription-aware UX | Phase 6, entitlements doc | ~12 | None | Family context inputs | Same gate |
| LATER | Phase 8: Location & Geofencing (FS-001 completion) | Map, history, geofence CRUD, permission onboarding, alerts | Android permission docs 05 | ~12 | None | Location risk signals | Same gate |
| LATER | Phase 9: Unified Event / Telemetry Layer | Event normalization, consumer registry, AI input stability contracts | All FS phases implemented | 0 UI | None | **Foundational for AI** | Contract tests |
| LATER | Phase 10: Guardian AI Foundation | On-device model bootstrap, risk engine v2, family context store | Phase 9 | ~3 screens | None | THE AI platform | Eval harness GREEN |
| FUTURE | Phase 11: Guardian AI Intelligence Layers | 9 layers: normalization → on-device → behavior → risk → family context → reasoning → family intelligence → copilot → policy intelligence | Phase 10 | ~10 screens | None | The product's intelligence | Eval suite GREEN |
| FUTURE | Phase 12: AI-Powered Experiences + Automation | Smart policy proposals, auto-incident triage, weekly family insights | Phase 11 | ~6 screens | None | Productization of layers | Eval suite GREEN |
| FUTURE | Phase 13: Reporting & Insights maturation + Commercial | Weekly/monthly reports, subscription tiers, billing, usage limits, AI entitlements | Phase 12, Phase 7 | ~8 screens | Entitlement reads only | AI entitlement gating | Tests + payment sandbox |
| FINAL | Phase 14: Production Hardening + Scale | Release signing, production Firebase deploy, reboot/doze/background resilience, scale testing | All above | 0 UI | Deploy config only | Latency budgets | Release checklist |

### 3.2 Hard rules that govern every phase

1. **Never merge to `master`.** All work on `feature/design-system-integration`; merge only when the user explicitly approves a release merge.
2. **Zero backend changes.** No Firestore rules, schema, domain model, sync/outbox, or Render backend modifications. New features consume existing contracts; missing capabilities are built as frontend-facing services over existing endpoints.
3. **Tests are the gate.** The full suite (growing from 247) must be green and `flutter analyze` clean before every commit.
4. **Honest-state UX.** Every screen renders real states — `GuardianStateView` loading/empty/error/offline, `GuardianOfflineBanner`, disabled affordances for unauthorized actors. Never fake success, never silently omit.
5. **Authorization via `FamilyRuntimeContext.can()` only.** No local re-implementation of roles.
6. **Design system inheritance.** Every screen uses the primitives from `guardian_primitives.dart` and tokens from `guardian_tokens.dart` (navy `#0F2A5B`, teal `#00B8A9`, Cairo, 16px radius).
7. **Single source of truth.** The `docs/00_master/` files in this directory are authoritative; feature docs reference them, never duplicate or contradict them.
8. **No silent contract changes.** Any change touching a shared contract (location schema, event types, provider signatures) requires the Section 9 impact-analysis fields before implementation.
9. **AI readiness built in.** Every feature documents what it emits (events), what must remain stable (data/API contracts), and what AI layer will later consume it — even when the AI does not exist yet.
10. **Minimal internet consumption.** All dependencies are local; no new remote deps without user approval.

---

## 4. The 16 Feature Subsystems — Order, Purpose, Dependencies, Screen Counts

The 16 approved subsystem specifications are preserved in intent. They are placed in the implementation order below. The order is driven by dependency graph (event consumers before producers of their inputs, simpler CRUD surfaces before consent-gated media surfaces), not by the original numbering.

| # | Subsystem | Spec source | Status | Screens (approx.) | Depends on | Feeds |
| --- | --- | --- | --- | --- | --- | --- |
| FS-001 | Location & Geofencing | UX docs (11 screens designed) | UX DONE, code PENDING | 12 | Android permission model | Risk engine, reports |
| FS-002 | Web Filtering | `pasted_file_eR4Zl5` | **CURRENT (first)** | 4 | Design system | AI web-safety signals |
| FS-003 | Application System | `pasted_file_g0NMq9` | PLANNED | 4 | FS-002 UI patterns | Usage/AI signals |
| FS-004 | Screenshot & Camera Control | `pasted_file_jJJcSG` | PLANNED | 5 | FS-003 | AI evidence layer |
| FS-005 | Special & Custom Modes | `pasted_file_tMVRXe` | PLANNED | 7 | Policy engine (M6/M8) | Policy intelligence |
| FS-006 | SOS & Emergency | `pasted_file_Bq5QbT` | PLANNED | 6 | SOS pipeline (Phase 18) | Risk engine |
| FS-007 | Offline AI Safety | `pasted_file_VQAyYR` | PLANNED | 6 | FS-004, AI artifact review | On-device AI layer |
| FS-008 | One-Way Audio | `pasted_file_MQgNts` | PLANNED | 12 | FS-007 consent patterns | Behavior intelligence |
| FS-009 | Reports & PDF | `pasted_file_S45lxh` | PLANNED | 5 | All data-producing subsystems | Family intelligence |
| FS-010 | Ephemeral Family Chat | `pasted_file_7sbK3L` | PLANNED | 2 | Membership lifecycle (M5) | Family context |
| FS-011 | Family Rules & Policy Engine | `pasted_file_JBLkUK` | PLANNED | 5 | Policy engine, FS-002/003/005 actions | Policy intelligence |
| FS-012 | Child Mode & Child Device Experience | `pasted_file_02czMG` | PLANNED | 3 | M8 enforcement | Child self-service |
| FS-013 | Couple Harmony Mode | `pasted_file_tzaehl` | PLANNED | 4 | M5 membership, Phase 17 spouse role | Couple context |
| FS-014 | Primary Parent Dashboard & Unlinked Device | `pasted_file_joglQ1` | PLANNED | 5 | All capability phases | Entry/journeys |
| FS-015 | Device Linking & Enrollment | `pasted_file_1QzLnG` | PLANNED | 9 | Pairing repository (M4) | Onboarding |
| FS-016 | Startup & State Machine | `pasted_file_oeZ4F6` | PLANNED | 3 | Role model, entitlements doc | Onboarding |

Total new UI surface: **~131 screens** across 16 subsystems, plus the ~10 AI screens in Phase 11 — the platform's full target of ~150 screens/states.

### 4.1 Dependency graph (condensed)

```text
Design system (Phase 0/1)
    └── FS-002 Web Filtering            (pattern-setter)
          ├── FS-003 App Control        (lists/detail/detail-actions)
          │     ├── FS-004 Screenshot/Camera
          │     │     └── FS-007 Offline AI Safety
          │     │           └── FS-008 One-Way Audio
          │     └── FS-011 Rules Engine
          ├── FS-005 Custom Modes       (needs FS-003 app list + policy engine)
          ├── FS-006 SOS expansion      (standalone; shares safety-actions UX)
          ├── FS-009 Reports            (needs FS-002..008 data producers)
          ├── FS-010 Chat               (needs M5 membership)
          ├── FS-012 Child Mode         (needs FS-005 + M8 enforcement)
          └── FS-013 Couple Harmony     (needs M5 + Phase 17 spouse role)
    ├── FS-015 Device Linking           (needs M4 pairing repo; parallel-possible with FS-002)
    ├── FS-014 Primary Dashboard        (needs FS-001..FS-013 surfaces to aggregate)
    └── FS-016 Startup & Feature Gates  (needs entitlements decided; late)
    FS-001 Location & Geofencing        (parallel track; Android permission docs available)
```

---

## 5. The Screen System — ~150 Screens

The complete per-screen registry lives in `docs/00_master/MASTER_SCREEN_INDEX.md`. The system is organized as **subsystem → screen → workflow → detail → state** with no duplication: a state surface (empty/offline/error) is documented inside its screen, never as a separate screen ID.

### 5.1 Screen ID convention

Every new screen receives an ID of the form `SX-NNN` where `SX` is the subsystem code (`WF` = FS-002 Web Filtering, `AC` = FS-003, `SC` = FS-004, `MD` = FS-005, `SO` = FS-006, `AS` = FS-007, `AU` = FS-008, `RP` = FS-009, `CH` = FS-010, `RL` = FS-011, `CM` = FS-012, `CO` = FS-013, `PD` = FS-014, `DL` = FS-015, `ST` = FS-016, `LO` = FS-001) and `NNN` is a sequence. Example: `WF-001` Web Filtering Dashboard. Full registry: `MASTER_SCREEN_INDEX.md`.

### 5.2 The screen spec contract (what every screen document must contain)

For every screen, the spec (and the implementation) must define all 21 fields below. This contract is what makes the plan executable by any AI model:

| Field | Meaning |
| --- | --- |
| Screen ID | `SX-NNN` |
| Subsystem / Feature | FS-xxx and its purpose |
| Purpose | One sentence: what the user accomplishes here |
| User | Parent / child / spouse / unlinked / system |
| Entry / Exit | Where navigation comes from / goes to |
| Route | Exact `GoRouter` path with parameter names |
| Parent screen / Child screens | Up one level / drill-down targets |
| Primary CTA / Secondary CTA | The one primary action and the secondary action |
| Required permissions | Role permissions via `FamilyRuntimeContext.can()` + Android runtime permissions |
| Required data | Providers/streams this screen consumes |
| Backend dependency | Which existing endpoint(s); NONE new |
| GuardianEvent dependency | Event types read/emitted |
| AI dependency | None now; the future consumer layer |
| Loading / Empty / Offline / Error / Unauthorized / Success | How each state renders (honest-state UX) |
| Accessibility | Semantics, minimum touch targets, contrast |
| RTL / LTR | Cairo layout behavior; mirrors automatically |
| Responsive behavior | Phone-first; tablet behavior |
| Required assets | Icons/images per `ASSETS_REQUIRED.md` |
| Acceptance | Testable assertions |
| Status | PLANNED / IN DESIGN / IN DEVELOPMENT / IMPLEMENTED / TESTED |

### 5.3 Full screen map by subsystem

The table below is the complete map. Each subsystem section in Sections 6–8 expands this into code-ready specifications.

| Subsystem | Screens (ID range) | Count |
| --- | --- | --- |
| FS-002 Web Filtering | WF-001…WF-004 | 4 |
| FS-003 Application System | AC-001…AC-004 | 4 |
| FS-004 Screenshot & Camera | SC-001…SC-005 (+ child active session) | 6 |
| FS-005 Special & Custom Modes | MD-001…MD-007 (+ child active mode) | 8 |
| FS-006 SOS & Emergency | SO-001…SO-006 | 6 |
| FS-007 Offline AI Safety | AS-001…AS-006 (+ settings) | 7 |
| FS-008 One-Way Audio | AU-001…AU-012 | 12 |
| FS-009 Reports & PDF | RP-001…RP-005 | 5 |
| FS-010 Ephemeral Chat | CH-001, CH-002 | 2 |
| FS-011 Family Rules | RL-001…RL-005 | 5 |
| FS-012 Child Mode | CM-001…CM-003 | 3 |
| FS-013 Couple Harmony | CO-001…CO-004 | 4 |
| FS-014 Primary Dashboard | PD-001…PD-005 | 5 |
| FS-015 Device Linking | DL-001…DL-009 | 9 |
| FS-016 Startup & State Machine | ST-001…ST-003 | 3 |
| FS-001 Location & Geofencing | LO-001…LO-012 | 12 |
| **FS subtotal** | | **95** |
| Guardian AI (Phase 11) | AI-001…AI-010 | 10 |
| Baseline (existing, upgraded) | 14 screens | 14 |
| **Platform total** | | **~150 screens/states** |

---

## 6. Subsystem Specifications — Code-Ready (FS-002 through FS-011)

Each subsystem below contains: product intent, user model, screen-by-screen specification (route, purpose, UI composition from the primitives, state variants, data wiring, authorization, navigation), honest-state rules, events, and acceptance. These specifications are written so that an AI model (or a human) can implement each screen without further context.

### 6.1 Shared implementation contract — applies to ALL subsystems

Every screen module in every subsystem follows this structure, enforced by code review:

```text
lib/presentation/screens/<subsystem>/
├── <screen>_screen.dart              # stateless widget; compose-only
├── <screen>_content.dart             # layout sections
└── _providers.dart (per subsystem, if new providers needed)
docs/06_ux/02_screens/<subsystem>/
├── <SCREEN_ID>_<slug>.md             # per-screen spec (21 fields)
└── INDEX.md                          # subsystem screen index
```

**Composition rules (all screens, no exceptions):**
1. Layout is built from the nine primitives: `GuardianCard`, `GuardianHeroCard`, `GuardianSection`, `GuardianStatusChip`, `GuardianStateView`, `GuardianStatTile`, `GuardianIconBadge`, `GuardianOfflineBanner`, `GuardianBottomNav`. Raw `Card`, `ListTile(color: ...)`, ad-hoc `Theme.of(context).colorScheme` color usage are prohibited.
2. Every async surface has a loading state (the primitive's `GuardianStateView(state: loading)` spinner), an empty state (no-data message + primary CTA where a creation path exists), an error state (retry primary action), and an offline banner (`GuardianOfflineBanner()`) whenever outbox-queued mutations exist.
3. Unauthorized actors see `GuardianStateView(state: error)` with the localized unauthorized message and a **retry/escape** action — never a dead end.
4. Primary CTA is always a `FilledButton` styled by the theme; destructive CTAs use the error color; secondary actions are `OutlinedButton` or `TextButton`.
5. All strings come from `AppLocalizations`; every new screen adds AR+EN keys. Cairo renders RTL natively; no per-screen RTL code is needed.
6. Navigation uses `context.push`/`context.pop`; routes register in `app_router.dart` inside the ShellRoute hierarchy. Deep-linkable screens take `:familyId` parameters; the router resolves the family from path when present.
7. New per-screen data needs a Riverpod provider following the existing naming convention (`<feature>Provider(familyId)`), reading from an existing repository. **No new repositories may write to the Firestore schema; local SQLite reads and the outbox for queued mutations only.**
8. Every new testable behavior adds widget/unit tests in `test/` under the same subsystem grouping; the suite must stay green.

**Status vocabulary:** HISTORICAL/VERIFIED, CURRENT, IN DESIGN, IN DEVELOPMENT, IMPLEMENTED, TESTED, DEVICE VERIFIED, BACKEND VERIFIED, GREEN, PARTIAL, BLOCKED, PLANNED, SUPERSEDED, DEPRECATED.

---

### 6.2 FS-002 — Web Filtering (4 screens) — CURRENT

**Product intent:** The parent configures content protection: a category-based filter, an explicit domain blocklist, and per-child policy targeting. The child experiences a blocked-page explanation, not silent failure. Business value: the single highest-demand parental-control capability in the MENA market; it converts free families to paid.

**Filtering model (frontend-facing):** The existing `DigitalPolicy`/`PolicyEngine` contract carries the actions; web filtering is represented as policy rules with action `block`/`allow` scoped to web categories and domains. Offline behavior: queue mutations in the outbox; the child device applies the last delivered policy version until the next sync (honest `GuardianStatusChip` state `pro`/`interruption`).

| ID | Screen | Route | Purpose | UI composition | States | Auth |
| --- | --- | --- | --- | --- | --- | --- |
| WF-001 | Web Filtering Dashboard | `/safety/web/:familyId` | Overview of web protection: protection level, blocked-today count, quick toggles, per-child summary | `GuardianHeroCard` protection level header; `GuardianSection` "Blocked Today" with `GuardianStatTile`(alert kind); section of child tiles as `GuardianCard` with `GuardianStatusChip` per child's protection state; CTA cards → categories/blocklist | loading (all sections), empty (no family/children), offline banner, error with retry | parent/owner: full; spouse: view-only |
| WF-002 | Content Categories | `/safety/web/:familyId/categories` | Enable/disable the 12 category blocks (adult content, gambling, violence, social, streaming, …) with child granularity | `GuardianSection` per category group; each row: `GuardianIconBadge` + title + description + `SwitchListTile`-style toggle rendered through theme; per-child chips via `GuardianStatusChip` | loading, empty, unauthorized | parent/owner |
| WF-003 | Website Blocklist | `/safety/web/:familyId/blocklist` | Add/remove blocked domains; search; empty state invites first entry | `GuardianCard` list rows (domain + reason + delete action); add sheet with domain input + `FilledButton`; empty `GuardianStateView(state: empty)` with primary action "Add first domain" | loading, empty, error, offline | parent/owner |
| WF-004 | Web Filtering Settings | `/safety/web/:familyId/settings` | Safe-search enforcement, blocked-page behavior (explain-to-child vs silent), exception requests allowed | `GuardianCard` toggles + radio groups; info banner about child experience | loading, unauthorized | parent/owner |

**Data wiring:** reads `childPoliciesProvider(familyId)`, `childOverridesProvider(familyId)`, `familyRuntimeContextProvider(familyId)`; category enable mutations enqueue through the existing outbox repository. Events: emits future `WEB_POLICY_UPDATED`, `WEB_BLOCK_HIT` consumers (Phase 9 normalization); today the UI reads only.

**Child experience:** blocked pages are rendered by the existing enforcement layer; no new child screen in this phase (child blocked-page UX is device-side, out of frontend scope).

**Acceptance:** 3 dashboard widget tests (loading/loaded/unauthorized), categories toggle toggles state and queues a mutation, blocklist add/remove updates list and shows empty state after removal, full suite green, analyze clean. Status: **CURRENT** — this is the next commit set.

---

### 6.3 FS-003 — Application System (4 screens)

**Product intent:** Parents see installed applications on linked child devices, apply per-app block/allow policies, and maintain an allowlist that survives mode changes.

| ID | Screen | Route | Purpose | UI composition | States | Auth |
| --- | --- | --- | --- | --- | --- | --- |
| AC-001 | Application Control Dashboard | `/apps/:familyId` | Protection summary: apps blocked today, restriction level, per-child app exposure | Hero card + stat tiles (blockedToday, restrictionLevel) + child section cards with `GuardianStatusChip` | loading/empty/error/offline | parent/owner |
| AC-002 | Installed Applications | `/apps/:familyId/:childId` | List of apps on a child device with current status and block/allow actions | Searchable list; each row `GuardianIconBadge` (app icon fallback: generic badge) + name + `GuardianStatusChip`(active/blocked); swipe-free actions via `GuardianCard` tap → detail | loading, empty (no device), unauthorized | parent/owner |
| AC-003 | Application Details | `/apps/:familyId/:childId/:appId` | Per-app policy: block, time allowance, allowlist membership, usage history | Detail `GuardianCard` stack: status chip, action buttons, time-allowance section, history `GuardianSection` | loading, error | parent/owner |
| AC-004 | Allowlist | `/apps/:familyId/allowlist` | Trusted apps that never get blocked (store, school apps) | `GuardianCard` list + add dialog; empty state CTA | loading, empty | parent/owner |

**Data wiring:** `childDeviceStatesProvider`, usage aggregates from existing daily-usage repositories; app metadata surfaced from what the child device syncs (no new backend fields — consume existing sync payloads). **Future AI consumer:** app-usage behavior intelligence → smart block proposals.

---

### 6.4 FS-004 — Screenshot & Camera Control (6 screens)

**Product intent:** Parents can request screen captures and live screen sessions to verify the child's actual on-screen activity; camera capture is a consent-gated surface.

| ID | Screen | Route | Purpose | UI composition | States | Auth |
| --- | --- | --- | --- | --- | --- | --- |
| SC-001 | Screen & Camera Dashboard | `/monitoring/:familyId` | Entry hub: capture counts, pending requests, device capability honesty | Hero + stat tiles + `GuardianCard` tiles per capability with `GuardianStatusChip` reflecting `notRequested/unsupported/enforced` honesty vocabulary | loading, capability-unavailable honest states | parent/owner |
| SC-002 | Screen Monitoring | `/monitoring/:familyId/screenshots` | Timeline of captured screenshots, filter by child/date | `GuardianCard` grid rows; date section headers; empty state with explanation | loading, empty, error | parent/owner |
| SC-003 | Screenshot Viewer | `/monitoring/:familyId/screenshots/:shotId` | Full-size capture with metadata, evidence tagging | Full-bleed image card + metadata section + tag as evidence CTA | loading, missing | parent/owner |
| SC-004 | Live Screen Session | `/monitoring/:familyId/live` | Real-time mirroring request; connecting/waiting/active/ended states | State-driven `GuardianStateView` for connecting; active tile with `GuardianStatusChip(live)`; duration limit notice | connecting, active, unavailable (device off/doze) | parent/owner |
| SC-005 | Camera Control | `/monitoring/:familyId/camera` | Camera capture policy: enabled/disabled, schedule, capture history | `GuardianCard` toggles + schedule section + history list | loading, unsupported (hardware missing) honest | parent/owner + spouse-consent gate (documented, enforced later in FS-013) |
| SC-006 | Child Active Session | `/monitoring/:familyId/:childId/session` | Child's current app/active state summary | Single `GuardianHeroCard` session summary + `GuardianStatusChip` | loading, no-device | parent/owner |

**AI dependency:** every capture is an evidence object consumed by FS-007 offline AI detection. Contract: captures carry `privacyClass` — never uploaded beyond the family scope.

---

### 6.5 FS-005 — Special & Custom Modes (8 screens)

**Product intent:** Beyond daily screen-time limits, the parent defines situational modes — homework mode, bedtime mode, travel mode — with schedules, child assignment, and temporary overrides.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| MD-001 | Special Modes Dashboard | `/modes/:familyId` | Active modes, scheduled modes, quick-create | Hero (active mode chip) + sections: active / upcoming / custom | parent/owner |
| MD-002 | Mode Details | `/modes/:familyId/:modeId` | Mode config: rules, schedule, assigned children, history | Detail card stack + `GuardianStatusChip` active indicator | parent/owner |
| MD-003 | Create Custom Mode | `/modes/:familyId/new` | Name, apply-to children, category/app restrictions, action (block/slow-down/allowlist-only), schedule | Multi-section form with `GuardianCard` section groups; validation errors inline; save CTA | parent/owner |
| MD-004 | Edit Mode | `/modes/:familyId/:modeId/edit` | Same form pre-filled | As MD-003 | parent/owner |
| MD-005 | Mode Schedule | `/modes/:familyId/:modeId/schedule` | Recurrence: daily/weekly/one-time windows | Schedule builder section | parent/owner |
| MD-006 | Child Assignment | `/modes/:familyId/:modeId/children` | Assign/remove children, per-child exceptions | Child tiles with chips | parent/owner |
| MD-007 | Mode History | `/modes/:familyId/:modeId/history` | Activation log with honest states (applied / requested / failed) | Timeline list | parent/owner |
| MD-008 | Child Active Mode Screen | child device vertical `/child/:fid/:cid/mode` | Child sees which mode is active, remaining time, request exception CTA | Child-facing read-only hero + request CTA | child self-scope |

**Backend dependency:** uses the existing policy/mode evaluation pipeline; new mode records queue via outbox. **AI consumer:** mode suggestions from behavior intelligence.

---

### 6.6 FS-006 — SOS & Emergency (6 screens)

**Product intent:** Expand the existing Phase-18 SOS pipeline into a full emergency experience: activation, live active-SOS state, recipient acknowledgement, emergency location, alerts history.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| SO-001 | SOS Dashboard | `/sos/:familyId` | SOS readiness: recipients configured, last drill, alert history | Hero readiness card + recipients section + history list | parent/owner; child gets own child-scoped view |
| SO-002 | SOS Activation | `/sos/:familyId/activate` | Trigger SOS: confirm dialog, sends via existing pipeline | Full-screen urgent surface: teal→red gradient hero, confirm primary CTA, cancel secondary | any family member (role-checked by pipeline) |
| SO-003 | Active SOS | `/sos/:familyId/active` | Live state: sent, delivered, acknowledged per recipient | State machine rendered by `GuardianStatusChip(live)` per recipient; cancel/stand-down CTA | activator + parents |
| SO-004 | Emergency Location | `/sos/:familyId/location` | Child's live location during SOS (uses FS-001 map surface — build shared `GuardianMapWidget`) | Map card + last-update chip + refresh | recipients + parents |
| SO-005 | Emergency Alert | notification deep link → `/sos/:familyId/alert/:alertId` | Received alert detail, acknowledge CTA | Urgent card + acknowledge button → posts acknowledgement event | SOS recipient |
| SO-006 | Emergency Acknowledgement History | `/sos/:familyId/ack` | Who acknowledged, when; unacknowledged escalation state | Timeline + `GuardianStatusChip` per responder | parents |

**Honest-state emphasis:** SOS never shows "alert sent" unless the outbox confirms queueing; offline SOS uses the existing SMS-fallback contract (displayed as `GuardianStatusChip` state).

---

### 6.7 FS-007 — Offline AI Safety (7 screens)

**Product intent:** The on-device safety-detection experience: safety reports generated by on-device analysis, evidence review, and a parent-maintained custom dictionary (sensitive words/phrases the child should not encounter).

**Constraint:** the actual model artifact is subject to review (historical blocker). These screens must work **fail-closed**: with no model available, the dashboard shows an honest `GuardianStatusChip(off)` with explanation and no fabricated detections.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| AS-001 | AI Safety Dashboard | `/ai-safety/:familyId` | Detection status (on/off/unsupported), detection counts, model version transparency | Hero status + stat tiles + `modelVersion` disclosure row (honesty contract) | parent/owner |
| AS-002 | Safety Reports | `/ai-safety/:familyId/reports` | List of detection reports with severity | Report cards with severity chips | parent/owner |
| AS-003 | Safety Report Detail | `/ai-safety/:familyId/reports/:reportId` | Full report: context, matched terms, confidence band, parent action | Detail stack + action CTAs (talk to child / dismiss / escalate) | parent/owner |
| AS-004 | Screenshot Evidence Viewer | `/ai-safety/:familyId/evidence/:evidenceId` | Evidence image + metadata + redaction state | As SC-003 with redaction note | parent/owner |
| AS-005 | Custom Dictionary | `/ai-safety/:familyId/dictionary` | Parent-managed word/phrase list | List + add/remove; family-shared | parent/owner |
| AS-006 | AI Safety Settings | `/ai-safety/:familyId/settings` | Detection on/off per child, sensitivity, notification preferences | `GuardianCard` toggles | parent/owner |
| AS-007 | Child Safety Explanation | child vertical `/child/:fid/:cid/safety` | Child-facing explanation of what is monitored, in age-appropriate copy | Child-mode hero + explanation sections | child self-scope |

**Events:** consumes `SAFETY_DETECTION` family; emits parent actions as `SAFETY_REPORT_ACTION`. **AI dependency:** this subsystem IS the UI surface of the future on-device AI layer; its contracts must remain stable.

---

### 6.8 FS-008 — One-Way Audio (12 screens)

**Product intent:** Live ambient audio listening to the child's environment — the most sensitive surface in the platform. It carries hard consent gates (Phase 17 sensitive-action law), spouse co-authorization, network policy, duration caps, and full session history with transparency.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| AU-001 | Live Audio Entry | `/audio/:familyId` | Hub: capability status, history link, start CTA (gated) | Capability honesty card + CTA | parent/owner |
| AU-002 | Audio Authorization Gate | `/audio/:familyId/auth` | Sensitive-action confirmation: two-step confirmation + consequence disclosure | Full disclosure card + confirm CTA | parent/owner only |
| AU-003 | Connecting | `/audio/:familyId/listening/connecting` | Connecting state with retry | `GuardianStateView` variant | as AU-001 |
| AU-004 | Active Live Audio | `/audio/:familyId/listening/active` | Live waveform, elapsed time, remaining cap, end CTA | Live hero + timer chip + end CTA | as AU-001 |
| AU-005 | Reconnecting | `/audio/:familyId/listening/reconnecting` | Transient reconnect | State view | — |
| AU-006 | Audio Unavailable | `/audio/:familyId/listening/unavailable` | Reason honesty: device off, permission missing, policy disallows | `GuardianStateView(error)` with reason + ladder to settings | — |
| AU-007 | Audio Policy Settings | `/audio/:familyId/settings/policy` | Whether audio monitoring is permitted at all | Toggle + disclosure | parent/owner |
| AU-008 | Maximum Duration Settings | `/audio/:familyId/settings/duration` | Session cap configuration | Slider/stepper section | parent/owner |
| AU-009 | Network Policy Settings | `/audio/:familyId/settings/network` | Wi-Fi-only / any network | Radio section | parent/owner |
| AU-010 | Audio Session History | `/audio/:familyId/history` | Completed sessions: who, when, duration | History list | parent/owner; spouse sees own sessions |
| AU-011 | Spouse Consent / Authorization Settings | `/audio/:familyId/settings/consent` | Whether spouse approval is required before sessions | Consent toggle + pending approvals list | parent/owner |
| AU-012 | Child Audio Policy | child vertical `/child/:fid/:cid/audio-policy` | Child-facing visibility of audio policy state | Child-mode explanation | child self-scope |

**Authorization note:** AU-002 is the only audio surface an actor can reach without the sensitive-action flag; the gate itself verifies `FamilyRuntimeContext.can(audioMonitor)` before rendering the confirm CTA. **AI consumer:** audio events feed behavior intelligence (with privacy class enforcement).

---

### 6.9 FS-009 — Reports & PDF (5 screens)

**Product intent:** Aggregated family reporting: daily/weekly/monthly, per-child and whole-family, exportable PDF.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| RP-001 | Reports Dashboard | `/reports/:familyId` | Report history + generate new | History list (each a `GuardianCard` with period + child scope) + generate CTA | parent/owner |
| RP-002 | Report Builder | `/reports/:familyId/build` | Choose period, children, sections (usage, filtering, safety, location, SOS) | Section checklist + scope chips + generate CTA | parent/owner |
| RP-003 | Generation Progress | `/reports/:familyId/build/progress/:jobId` | Honest progress: queued/running/done/failed | `GuardianStateView` states + outbox honesty | — |
| RP-004 | Single Child Report | `/reports/:familyId/report/:reportId` | Executive summary + per-section cards + PDF export CTA | Hero summary + `GuardianSection`s per chapter + export | parent/owner |
| RP-005 | All-Children Report | `/reports/:familyId/report/:reportId/all` | Whole-family aggregate report | As RP-004 with per-child comparison sections | parent/owner |

**Data:** aggregates existing daily summaries, policy evaluations, incidents, outbox history. **AI consumer:** family intelligence drafts the executive summary (Phase 11).

---

### 6.10 FS-010 — Ephemeral Family Chat (2 screens)

**Product intent:** In-family messaging with 24-hour auto-expiration. Lightweight: list + chat, no attachments phase 1.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| CH-001 | Chat List | `/chat/:familyId` | Conversations (Family / per-member / spouse) with expiration indicators | List of `GuardianCard` rows with last-message + timer chip | any member (role-scoped threads) |
| CH-002 | Chat Screen | `/chat/:familyId/:threadId` | Bubbles, input, expiration note banner | Bubble list + input bar; `GuardianOfflineBanner` when queued | as CH-001 |

---

### 6.11 FS-011 — Family Rules & Policy Engine (5 screens)

**Product intent:** A user-friendly rule layer over the existing `PolicyEngine`: parents create plain-language rules (when/who/what → action) that compile into delivered policies, with conflict detection and effective-policy preview.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| RL-001 | Rules Dashboard | `/rules/:familyId` | Rules list with enable/disable, status chips | List + toggle per row + create CTA | parent/owner |
| RL-002 | Rule Creation | `/rules/:familyId/new` | Name, apply-to, category/app/domain condition, action, schedule | Form sections + validation | parent/owner |
| RL-003 | Rule Detail | `/rules/:familyId/:ruleId` | Full rule config + effective-policy preview + conflict warning | Detail stack; conflict banner when overlapping rules detected | parent/owner |
| RL-004 | Conflict Warning | inline on RL-003 | Two rules conflict → warning card with resolution options | Warning `GuardianCard`(alert kind) | — |
| RL-005 | Effective Policy Preview | `/rules/:familyId/:ruleId/preview` | Simulated delivered policy for a selected child | Preview sections: daily limit, blocks, modes | parent/owner |

**Backend dependency:** rules compile locally and queue through the existing policy outbox path — no new schema.

---

### 6.12 FS-012 — Child Mode & Child Device Experience (3 screens)

**Product intent:** The child-facing experience: my usage today, my device status, and the ability to request more time (feeding the existing exception-request pipeline).

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| CM-001 | Child Mode Dashboard | child root `/child/:fid/:cid` (upgrade of existing M3 vertical) | My usage today, my status, request-more-time CTA | Existing upgraded vertical + new request CTA + active-mode chip | child self-scope (fail-closed) |
| CM-002 | Child Mode Lock | lock overlay | Device locked: reason, remaining time, parent contact note | Full-screen lock hero (navy) + time chip | child |
| CM-003 | Parent Authorization (unlock request) | `/requests/:familyId/unlock/:requestId` | Parent reviews child's unlock request | Existing request-review cards with approve/deny CTAs | parent/owner |

---

### 6.13 FS-013 — Couple Harmony Mode (4 screens)

**Product intent:** A distinct subsystem (NOT child monitoring): spouses coordinate as equals — shared routines, divided responsibilities, coordinated decisions, emergency roles, and explicit privacy boundaries. Authority is deliberately symmetric; every sensitive action requires mutual or owner-approved consent. **Status: PLANNED.**

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| CO-001 | Partner Linking Flow | `/couple/:familyId/link` | Invite/link a spouse; role selection (spouse vs co-parent) | Link form + role selection + disclosure of authority difference | parent/owner |
| CO-002 | Couple Harmony Dashboard | `/couple/:familyId` | Shared routines, responsibilities, family decisions, emergency roles | Hero "our family today" + three sections: routines / responsibilities / decisions | spouse + co-parent symmetric |
| CO-003 | Permission Review | `/couple/:familyId/permissions` | What each partner can see/do; boundary disclosures | Permission matrix cards with `GuardianStatusChip` | both |
| CO-004 | Family Decisions | `/couple/:familyId/decisions` | Propose/resolve family decisions (new rule, new app allowed, trip mode) | Decision cards + propose CTA + resolved section | both |

**Privacy boundaries (design law):** no partner can view the other's sensitive surfaces (audio history, evidence) without the other's explicit approval; the UI enforces this through `FamilyRuntimeContext.can()` — identical mechanism, symmetric matrix rows.

---

### 6.14 FS-014 — Primary Parent Dashboard & Unlinked Device (5 screens)

**Product intent:** The first-run and aggregate experiences: unlinked entry, family creation/join, authentication confirmation, and the post-capability primary dashboard aggregating all subsystems.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| PD-001 | Unlinked Entry | `/` (no membership) | Landing for signed-in but unlinked users | Existing `_FamilySetup` upgraded + clear create/join dual CTA | unauthenticated-family |
| PD-002 | Create Family | `/family/create` | Name, invite first parent, first child | Form sections; honest validation errors | account holder |
| PD-003 | Join Existing Family | `/family/join/:invitationCode` | Accept invitation code flow | Code entry + confirmation | account holder |
| PD-004 | Parent Authentication | `/auth/confirm` | Re-auth confirmation for sensitive operations | Confirmation card + OTP/biometric ladder hooks | account holder |
| PD-005 | Primary Parent Dashboard | `/` (post-capability) | Aggregates: family overview, safety center, location overview, geofence overview, SOS overview | Hero + subsystem overview `GuardianCard`s, each tapping into its subsystem dashboard | parent/owner |

---

### 6.15 FS-015 — Device Linking & Enrollment (9 screens)

**Product intent:** Complete the M4 pairing foundation with full UX: QR pairing, manual code, child enrollment flow, spouse device linking, permission onboarding with honest failure ladders, role transition, and unlinking.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| DL-001 | Child Device Linking (QR) | `/safety/pairing/:fid` (upgrade) + QR sheet | Scan QR to pair | Existing pairing screen + QR sheet | parent/owner |
| DL-002 | Child Device Linking (code) | `/safety/pairing/:fid/code` | Manual 6-digit code entry with attempt honesty (5-attempt lockout displayed) | Code input + lockout state view | parent/owner |
| DL-003 | Child Enrollment Flow | `/enroll/:fid/:code` | Onboard the linked device: profile, permissions, first policy | Step wizard of `GuardianCard` sections | parent/owner |
| DL-004 | Child Enrollment Confirmation | `/enroll/:fid/:code/confirm` | Summary + confirm; honest "applied/queued" chips | Summary cards + confirm CTA | parent/owner |
| DL-005 | Spouse Device Linking | `/couple/:fid/link-device` | Link the spouse's device | As DL-001/002 variant | spouse |
| DL-006 | Spouse Enrollment | `/couple/:fid/enroll` | Spouse onboarding steps | Wizard | spouse |
| DL-007 | Spouse Role Selection | `/couple/:fid/role` | spouse vs co-parent, authority disclosure | Role cards + disclosure | owner |
| DL-008 | Permission Onboarding | `/onboard/permissions` | Android permission ladder with honest failure states (location/accessibility/usage stats) | Ladder sections; each row honest: granted / requires-settings / unsupported / deferred | device actor |
| DL-009 | Device Unlinking | `/settings/device/:deviceId/unlink` | Revoke a device with consequence disclosure | Disclosure card + confirm | owner |

---

### 6.16 FS-016 — Startup & State Machine (3 screens)

**Product intent:** The app's cold-start experience and subscription-aware feature gating.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| ST-001 | Onboarding / Splash + Role Selection | splash → role route | Brand entry; route by role | Splash → role gate (parent/child/spouse) | any |
| ST-002 | Feature Lock / Upgrade Gate | inline gate | Free-tier features locked: what's locked, why, upgrade CTA | Lock card (gradient hero) + entitlements list + upgrade CTA | any (post-entitlements) |
| ST-003 | Offline Startup | cold start offline | App usable offline: queued banner, last-known state freshness stamp | Honest startup card + `GuardianOfflineBanner` | any |

---

### 6.17 FS-001 — Location & Geofencing (12 screens)

**Product intent:** The designed 11-screen location system (FS-001-UX approved): family map, member location details, location history, geofence list/CRUD, settings, permission onboarding, sharing status, alerts, privacy information. Implemented as a parallel track with the same contracts.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| LO-001 | Family Map | `/location/:familyId` | All members on map, status chips, select-member entry | `GuardianHeroCard` map surface + member chips overlay | parent/owner |
| LO-002 | Member Location Details | `/location/:familyId/:memberId` | Selected member: current location, freshness, battery | Detail hero + `GuardianStatusChip`(fresh/stale/offline) | parent/owner |
| LO-003 | Location History | `/location/:familyId/:memberId/history` | Route trace with date picker | Map trace + timeline list | parent/owner |
| LO-004 | Geofence List | `/location/:familyId/geofences` | Geofences with status (active/entered/exited) | List + create CTA | parent/owner |
| LO-005 | Create Geofence | `/location/:familyId/geofences/new` | Name, place on map, radius, alert rules | Map picker + form sections | parent/owner |
| LO-006 | Edit Geofence | `/location/:familyId/geofences/:gfId/edit` | Modify geofence | As LO-005 pre-filled | parent/owner |
| LO-007 | Location Settings | `/location/:familyId/settings` | Update interval, battery-saver honesty, sharing defaults | Settings sections | parent/owner |
| LO-008 | Location Permission Onboarding | `/onboard/location` | Ladder: coarse → fine → background, honest unsupported display | Permission ladder (shares DL-008 component) | device actor |
| LO-009 | Location Sharing Status | `/location/:familyId/sharing` | Who shares location with whom; revoke honesty | Sharing matrix cards | parent/owner + self-scope members |
| LO-010 | Location Alerts | `/location/:familyId/alerts` | Geofence entry/exit alert history | Alert list + severity chips | parent/owner |
| LO-011 | Location Privacy Information | `/location/:familyId/privacy` | What is collected, retention, who sees it | Disclosure sections | any member |
| LO-012 | Offline Location State | inline banner | Outbox-queued location updates | `GuardianOfflineBanner` | — |

**AI consumer:** location anomalies → risk engine; geofence violations → incident generation.

---

### 6.18 Phase 2.5 — User Journeys & Capability UX Integration

After all 16 subsystems land, an integration pass (no new screens, wiring only): cross-subsystem entry points verified (dashboard subsystem cards tap through; timeline correlates incidents across subsystems; reports pull every data producer), every `context.push` target exists (dead-route guard re-verified), localization sweep (all new keys AR+EN), and the journey docs in `docs/06_ux/03_journeys/` updated with the full parent / child / spouse journeys.

---

## 7. The Guardian AI System — 9 Layers + ~10 Screens (Phase 10–12)

The AI system is the platform's intelligence phase. It is built **after** all FS subsystems are implemented, because every layer consumes the events the FS screens produce. The product identity rule applies: AI is an internal capability ("human-engineered, AI-powered, family-first") — no screen may overclaim, and every AI output carries traceability (`modelVersion`) with a fail-closed path if the model is unavailable.

### 7.1 Architecture pipeline (immutable direction)

```text
FEATURE EVENTS (GuardianEvent family)
      ↓  Layer 1 — Event Normalization
NORMALIZED SIGNALS
      ↓  Layer 2 — On-Device AI (model inference)
DETECTIONS (with confidence bands)
      ↓  Layer 3 — Behavior Intelligence
BEHAVIOR PROFILES (per child, per device)
      ↓  Layer 4 — Risk Engine (fail-closed by Law 1)
RISK STATES (deterministic + model-assisted)
      ↓  Layer 5 — Family Context
CONTEXT MODEL (family norms, routines, exceptions)
      ↓  Layer 6 — Reasoning
EXPLANATIONS (why this matters)
      ↓  Layer 7 — Family Intelligence
FAMILY INSIGHTS (weekly patterns, trends)
      ↓  Layer 8 — Parent Copilot
CONVERSATIONAL GUIDANCE (suggestions, never autonomous action)
      ↓  Layer 9 — AI Action / Policy Intelligence
SMART POLICY PROPOSALS (parent always approves)
+ Evaluation / Continuous Improvement (parallel, all layers)
```

**Governing law:** the AI layer may NEVER bypass deterministic safety/security systems. A detection can raise an incident candidate; only the deterministic pipeline can enforce. Policy proposals require parent approval.

### 7.2 Layer specification contract

Every AI layer documents the same 13 fields: Purpose, Inputs, Sources, Preprocessing, Models, Logic, Outputs, Confidence, Latency, Cost, Privacy, Failure mode, Human override, Downstream consumers.

### 7.3 The 9 layers

| # | Layer | Purpose | Inputs | Outputs | Failure mode | Consumer screens |
| --- | --- | --- | --- | --- | --- | --- |
| L1 | Event Normalization | Canonical signal registry over `GuardianEvent` | All feature event types | Normalized feature vectors | Returns empty features (no crash) | L2–L9 |
| L2 | On-Device AI | Inference on device (text/image/audio classifiers) | Normalized text, captures, audio segments | Detections with confidence bands | Fail-closed: `modelVersion = none`, no detections | AS-001..AS-007 |
| L3 | Behavior Intelligence | Per-child behavior baselines (usage rhythm, app mix) | Usage sessions, app events | Behavior profile deltas | Returns baseline-only profile | L4, RP-004 |
| L4 | Risk Engine | Combine deterministic rules + model signals into risk state | Policy violations, detections, baselines | Risk state per child (safe/watch/alert) | Deterministic path only; model signal ignored | Timeline, dashboard, SO-001 |
| L5 | Family Context | Family norms, routines, known exceptions | Historical events, geofence patterns, modes | Context model | Empty context; rules still fire | L6, L7 |
| L6 | Reasoning | Explain WHY a risk state changed | L4 state diff + L5 context | Natural-language explanations (AR+EN) | Fallback templates, honest "no explanation available" | AI-004 |
| L7 | Family Intelligence | Longitudinal insights (weekly/monthly trends) | L1..L5 aggregates | Insight cards | No insight rendered; no fake trend | AI-005, RP-004 |
| L8 | Parent Copilot | Guided suggestions ("consider a homework mode this week") | L4–L7 outputs, policy state | Suggestion cards with rationale | No suggestions | AI-006..AI-008 |
| L9 | Policy Intelligence | Draft policy changes from observed behavior (parent approves) | L3/L4 deltas, existing policies | Proposed policy diffs | No proposals | AI-009, AI-010 |

**Evaluation / Continuous Improvement** runs parallel: an offline eval harness scores detection precision/recall, explanation quality, and suggestion usefulness against a labeled corpus — this corpus and harness are built during Phase 9 so the model review blocker can be resolved with evidence.

**Model strategy:** on-device models for detection (privacy-class enforcement: detections never leave the device unredacted), cloud models for reasoning/copilot summaries where the family has opted in, and **Guardian-owned logic** (ontology, risk rules, policy intelligence) as the durable differentiator. No general LLM training — orchestration is the IP.

### 7.4 The 10 AI screens

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| AI-001 | AI Insights Hub | `/insights/:familyId` | One place for all AI outputs: detections, insights, suggestions | Hero + three `GuardianSection`s (what we found / what it means / what you can do) | parent/owner |
| AI-002 | Risk Overview | `/insights/:familyId/risk` | Per-child risk states with honesty (model-assisted vs deterministic) | Child rows + `GuardianStatusChip` + transparency note | parent/owner |
| AI-003 | Detection Review | `/insights/:familyId/detections` | Review on-device detections, evidence, action | Cards with confidence bands + action CTAs | parent/owner |
| AI-004 | Explanation View | `/insights/:familyId/detections/:id/explain` | Natural-language "why this matters" (AR+EN) | Explanation card + sources section | parent/owner |
| AI-005 | Weekly Family Insight | `/insights/:familyId/weekly` | Weekly insight report (generated by L7) | Hero insight + trend sections | parent/owner |
| AI-006 | Copilot Suggestions | `/insights/:familyId/copilot` | Suggestion queue: each with rationale + apply/dismiss | Suggestion cards + apply CTA (routes to policy preview) | parent/owner |
| AI-007 | Copilot Conversation | `/insights/:familyId/copilot/chat` | Guided Q&A about the family's safety picture | Chat surface (reuses CH-002 bubble component) | parent/owner |
| AI-008 | Copilot Settings | `/insights/:familyId/copilot/settings` | Opt-in controls, cloud-model consent, explanation language | Consent toggles + disclosure | parent/owner |
| AI-009 | Smart Policy Proposal | `/insights/:familyId/proposals/:proposalId` | AI-drafted policy change with before/after preview | Diff preview (reuses RL-005 component) + approve/reject CTAs | parent/owner |
| AI-010 | AI Transparency Center | `/insights/:familyId/transparency` | What the AI knows, model versions, data used, delete-my-model-data | Disclosure sections + data controls | parent/owner |

### 7.5 AI dependency map (feature → event → data → layer → insight → action)

| Feature | Event | AI layer | Insight | Possible action |
| --- | --- | --- | --- | --- |
| Web Filtering | `WEB_BLOCK_HIT` | L3 | Repeated category attempts | L9 proposes category block |
| App Control | `APP_SESSION` | L3 | App-mix drift at night | L8 suggests bedtime app limits |
| Screenshots | `SCREENSHOT_CAPTURED` | L2 | Visual content detections | L4 raises incident candidate |
| Location | `LOCATION_UPDATE`, `GEOFENCE_EVENT` | L3/L5 | Route anomalies | L8 suggests geofence refinement |
| Geofencing | `GEOFENCE_ENTRY/EXIT` | L4 | Violation patterns | incident + L9 geofence rule proposal |
| SOS | `SOS_ACTIVATED` | L5 | Emergency context | L7 emergency-response insight |
| Notifications/Incidents | `INCIDENT_CREATED` | L1/L6 | Incident explanations | AI-004 |
| Policies | `POLICY_EVALUATED` | L3/L9 | Enforcement friction | L9 smart policy proposals |
| Device State | `DEVICE_STATE_TRANSITION` | L5 | Device health patterns | L8 maintenance suggestions |
| Web Safety (FS-007) | `SAFETY_DETECTION` | L2/L4 | On-device risk | AI-003 review queue |

---

## 8. Commercial, Production Hardening & Scale (Phase 13–14)

### 8.1 Commercial (Phase 13)

The commercial layer is subscription-aware UX built on the entitlements contract defined in the FS-016 gate. No payment infrastructure is invented: it consumes the family entitlement model (server-verified, per-family) and renders the gates.

| ID | Screen | Route | Purpose |
| --- | --- | --- | --- |
| CMR-001 | Plan Overview | `/subscription/:familyId` | Current tier, entitlements, usage meters |
| CMR-002 | Upgrade Flow | `/subscription/:familyId/upgrade` | Tier comparison + payment-bridge CTA (external checkout) |
| CMR-003 | Usage Limits | `/subscription/:familyId/limits` | AI-credit and feature usage meters with honest exhaustion states |
| CMR-004 | Billing & Receipts | `/subscription/:familyId/billing` | History, local-corridor payment notes |

**Tier model (design intent, not implementation):** Free (core safety, 1 child), Premium (all FS capabilities), Family Pro (AI entitlements + multi-child + advanced safety). AI entitlements gate the Phase 11 screens via ST-002.

### 8.2 Production hardening (Phase 14)

Non-UI workstream: release signing, production Firebase deploy (Blaze, real Auth/Firestore, FCM delivery proof), reboot/doze/background resilience (documented gaps in `docs/05_android/ANDROID_LIFECYCLE_AND_RECOVERY.md`), conflict resolution verification, scale testing of the outbox, and the 2028 business target runway (≈8,000 paying families at blended $75/year → $600K ARR, per the verified blueprint scenario).

---

## 9. Governance — Non-Negotiable Operating Rules

### 9.1 Change-impact analysis (mandatory before every meaningful change)

Any agent making a meaningful change records a change proposal with these fields, in `docs/00_master/CHANGE_LOG.md` (the existing `CHANGE_PROPOSAL.md` is the template):

```text
CHANGE-ID            · unique id
REQUEST              · what was asked / why
CURRENT PHASE        · phase at time of change
AFFECTED FEATURE     · subsystem(s)
AFFECTED SCREENS     · screen IDs
AFFECTED FILES       · code + doc files
AFFECTED DATA        · models/providers touched
AFFECTED BACKEND     · contract changes (usually: NONE)
AFFECTED EVENTS      · GuardianEvent types read/emitted
AFFECTED SECURITY    · authorization/privacy surface
AFFECTED CURRENT PHASE      · does it alter in-flight work?
AFFECTED PREVIOUS FOUNDATION · does it touch M1–M9 / Phase 17 / 18?
AFFECTED FUTURE PHASES      · which later phases consume this?
MIGRATION REQUIRED   · data/migration steps
TESTS REQUIRED       · new/updated tests
DOCS REQUIRED        · docs touched
ROLLBACK             · how to undo
STATUS               · proposed/approved/merged
```

### 9.2 Cross-phase impact questions (answer all, silently = violation)

Does it break historical foundation? Does it change the current phase? Does it alter upcoming phases? Does it affect AI inputs? Does it affect future screens? Does it affect Firebase/Render contracts? Does it affect Android feasibility?

### 9.3 Future-phase compatibility (document per feature, before implementation)

What future feature consumes this? What event does it emit? What data must remain stable? What API contract must remain stable? What AI layer will later use it?

### 9.4 Downstream inspection rule

Before changing any shared contract, inspect all consumers. Example: changing the location schema requires inspecting Location UI, Geofence, Reports, Incidents, Firebase, Render, GuardianEvent, AI Context, and the future Risk Engine.

---

## 10. Documentation & Asset Governance

### 10.1 Required file tree (established by this plan; supersedes no existing hierarchy)

```text
docs/
├── 00_master/                       ← single source of truth
│   ├── MASTER_DEVELOPMENT_PLAN.md   ← THIS document (constitution)
│   ├── MASTER_FEATURE_MATRIX.md     ← what to work on next
│   ├── MASTER_SCREEN_INDEX.md       ← all ~150 screens status
│   ├── MASTER_NAVIGATION_MAP.md     ← all routes + gating
│   ├── MASTER_PHASE_DEPENDENCY_MAP.md
│   ├── AI_AGENT_ENTRY_PROTOCOL.md   ← zero-history onboarding
│   ├── CHANGE_LOG.md                ← impact analyses
│   └── DESIGN_DECISION_LOG.md
├── 06_ux/
│   ├── 01_design_system/DESIGN_SYSTEM.md
│   ├── 02_screens/<subsystem>/INDEX.md + per-screen specs
│   └── 03_journeys/INDEX.md
└── (existing 01–05, 07–08 preserved unchanged)
```

Documentation update rule: Impact Analysis → Code → Tests → Documentation → Status → Change Log, for code changes; Product Decision → UX Spec → Navigation → Implementation impact → Test impact → Docs update, for product/UX changes.

### 10.2 Asset governance

Every visual asset is tracked in `docs/00_master/ASSETS_REQUIRED.md` with the contract fields: Asset ID, Filename, Description, Dimensions, Format, Theme, Location, Screen, State, Priority, Human-supplied?, AI-generated?, Fallback. Rule: an implementing agent that cannot generate an asset writes a precise `ASSETS_REQUIRED.md` entry — it never silently ships an inappropriate placeholder. Iconography ships from the Material icon set + brand assets defined in `DESIGN_SYSTEM.md`; generated illustrations follow the navy/teal/Cairo brand system.

---

## 11. Acceptance Criteria — Per Phase

Every phase commit set must satisfy all of: full test suite green (baseline 247, growing), `flutter analyze` zero issues, no merge to `master`, zero backend/schema/event-contract changes, all new strings localized AR+EN, every new screen documented in `MASTER_SCREEN_INDEX.md` with status `IMPLEMENTED`/`TESTED`, impact analyses recorded in `CHANGE_LOG.md`, and the UX honesty audit passed (no fake success, no dead ends, offline banner present where outbox mutations exist). Device verification remains the user's step via the run guide; the sandbox's role is unit/widget test evidence.

| Phase | Test-floor expectation | Docs expected |
| --- | --- | --- |
| FS-002 | ≥255 (247 + 8 new) | WF specs in 02_screens, matrix + index updated |
| Each FS phase | +6 to +15 tests | subsystem docs + master docs updated |
| Phase 2.5 integration | same or higher | journeys updated, dead-route re-verification |
| Phase 9 events | contract tests GREEN | event registry |
| Phase 10–11 AI | eval harness GREEN | layer docs (13 fields each) |
| Phase 13–14 | release checklist complete | production docs |

---

## 12. First Deliverables From This Plan

The immediate next work, in order: (1) populate `MASTER_FEATURE_MATRIX.md`, `MASTER_SCREEN_INDEX.md`, `MASTER_NAVIGATION_MAP.md`, `MASTER_PHASE_DEPENDENCY_MAP.md`, `AI_AGENT_ENTRY_PROTOCOL.md` in `docs/00_master/`; (2) begin Phase 2 — implement WF-001…WF-004 (FS-002 Web Filtering) per the specs in Section 6.2, with tests and docs; (3) update this plan's status fields as work lands. This document is the constitution; those files are its working registers.

---

*This plan supersedes all prior phase-planning documents (`integration_roadmap`, prior sprint plans, and superseded prompt documents). Historical plans remain archived in `docs/08_milestones/` for traceability.*
