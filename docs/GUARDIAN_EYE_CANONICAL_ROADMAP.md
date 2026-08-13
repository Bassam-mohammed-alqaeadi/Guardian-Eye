# Guardian Eye Pro — Canonical Roadmap (Post-M3)

**Document type:** Single authoritative roadmap — planning and analysis only
**Baseline:** `d72c66d282600b56c0cf882976bcf91e4adc25cd` (master, M3 GREEN checkpoint)
**Protected checkpoint:** `phase17-stable-checkpoint = 274e181` (untouched)
**Author:** Manus AI
**Date:** August 13, 2026
**Constraint:** This document is the only artifact created by this task. No source, test, Firebase, Android, or dependency changes were made. No commits or pushes were performed.

---

## 1. Executive Summary

Guardian Eye Pro has completed the first three experience milestones: the canonical app shell (M1), the parent dashboard with family identity, child overview, and safety signal (M2), and the child context vertical (M3). All three are GREEN with direct test evidence: 109/109 Flutter tests, 0 static analysis issues, 15/15 Firestore Emulator tests, and 2/2 Functions Emulator tests.

Beneath the experience layer, the repository already contains a substantial security and data architecture from Phases 5 through 18: a fail-closed trusted-actor binding, a canonical family runtime context, a complete multi-parent membership system with invitation lifecycle, a versioned policy delivery system, an incident pipeline, an outbox with idempotent retry, and a screen-time decision engine. What is missing is not the domain — it is the **vertical integration** that connects the domain to real devices, real remote sync, and real Android background execution.

The reconciled roadmap therefore does not propose new domains. It proposes a sequence of vertical slices that close the gap between "implemented locally" and "credible production product". The critical path passes through device linking (M4), family management completion (M5), the screen-time vertical in three distinct stages — administration, measurement, enforcement (M6, M7, M8) — and only then AI monitoring (M9–M11) and the commercial layer (M13+). Communication features, location/geofencing, web filtering, and Couple Harmony authority are explicitly placed on the full roadmap only, where they cannot block the MVP.

The single most important finding of this reconciliation is:

> **The recommended next milestone is M4 — Device Linking and Child Device Onboarding — not Screen Time and not Family Management.** The entire M3 child context surface (device state, screen time, safety per child) displays seeded or absent data until a real device enrollment exists, and every downstream enforcement capability requires an enrolled child device as its substrate. The pairing core is already implemented and emulator-verified; the gap is the product-facing vertical.

---

## 2. Current Verified State

The current baseline is `d72c66d` on `master`, equal to `origin/master`. The protected checkpoint `phase17-stable-checkpoint` (`274e181`) is untouched. The working tree contains only pre-existing Flutter tooling artifacts (`.flutter-plugins-dependencies`, `analysis_options.yaml`) and the emulator log (`firestore-debug.log`); no source, test, or configuration file was modified by this task.

| Milestone | Content | Evidence |
|---|---|---|
| M1 — App Shell + Canonical Navigation | `guardian_app.dart`, canonical `GoRouter` (9 routes), AR+EN RTL/LTR, dead-route guard, 9 widget tests | `flutter test` GREEN; dead-routes test GREEN [1] |
| M2 — Parent Dashboard Foundation | Family identity card, safety signal from real unacknowledged incidents, child overview joined with real `ChildDeviceState.lifecycle`, sync-queue honesty, 9 tests | `flutter test` 89/89; Emulator 15/15 + 2/2 [2] |
| M3 — Child Context Vertical | `ChildContextScreen` at `/child/:familyId/:childId`: identity, device state, safety, today's screen-time total, coming-soon entries (text only, no dead routes), 8 unit + 12 widget tests | `flutter test` 109/109; analyze 0 issues [3] |

The security and runtime regression suite (actor binding + membership) is GREEN at 14/14, and no Phase 17/18 security artifact (`FamilyRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, SQLite repositories, outbox, Firestore rules, Functions) was modified by M1–M3.

**Known environmental gaps (HUMAN ACTION REQUIRED, documented in prior phases):** no physical Android device or AVD validation has been performed in the sandbox; the Firebase remote outbox writer is unconfigured (`UnconfiguredOutboxRemoteWriter`); production Firebase deploy (Blaze, real Auth/Firestore, FCM delivery proof, release signing) has deliberately not been executed; no reviewed on-device AI model artifact exists.

---

## 3. Product Capability Audit

This section classifies every major product capability against repository evidence. The classification vocabulary is: **IMPLEMENTED** (domain + data + tests proven), **PARTIAL** (meaningful parts exist, gaps documented), **PLACEHOLDER** (abstraction exists, behavior fail-closed), **DEAD CODE** (present but unreachable), **INFRASTRUCTURE ONLY** (plumbing exists, no behavior), **PRODUCTION-READY** (validated end-to-end), **BLOCKED** (cannot proceed without external input), and **DEFERRED** (deliberately scheduled later). "Implemented" never means "production-ready" in this product; the two are separated deliberately.

| # | Product Area | Classification | Direct Evidence | Production-Ready? |
|---|---|---|---|---|
| 1 | Authenticated account identity | IMPLEMENTED (fail-closed foundation) | `FirebaseAuthContext`, bootstrap fail-closed; real Auth UID callable verified [4] | No — production deploy pending |
| 2 | Family creation | IMPLEMENTED + verified local | `FamilyRepository` SQLite transaction + outbox; local persistence tests GREEN | No — remote sync unconfigured |
| 3 | Multi-parent membership (invite, accept, revoke, role update) | IMPLEMENTED | `FamilyMembershipRepository` full lifecycle + idempotency + owner gates; regression 14/14 [5] | No — remote delivery unproven |
| 4 | Membership management UI | PARTIAL | `FamilyMembersScreen`: list, owner-gated invite FAB, device counts; **no** revoke/role-update/invitation-history surfaces | No |
| 5 | Child identity (child = member) | IMPLEMENTED | `FamilyRole.child` member filter in `FamilyContextResolver`; M2/M3 render it | Local only |
| 6 | Family runtime context (single source of truth) | IMPLEMENTED (local canonical) | `FamilyRuntimeContext` + `FamilyContextResolver` + `familyRuntimeContextProvider` [6] | Local only |
| 7 | Device pairing core (code, SHA-256, lockout, lifecycle) | IMPLEMENTED + emulator-verified | `PairingRepository` 5-attempt lockout, enrollment-once, owner binding, revocation; Functions Emulator 2/2 [7] | No — child redemption UI absent, no physical device |
| 8 | Child redemption / child-device onboarding UI | NOT IMPLEMENTED | Phase 13 feature matrix explicitly lists child redemption as absent [8] | No |
| 9 | Device unlinking / revocation logic | IMPLEMENTED (repo) | `revokeMember` revokes all member devices atomically with queued sync [5] | UI absent |
| 10 | Device lifecycle state machine (9 values) | IMPLEMENTED | `ChildDeviceStateMachine` + `ChildDeviceRepository.transition` | Local only |
| 11 | Child context display (M3) | IMPLEMENTED | `childContextProvider` + 20 tests | Local; data meaningful only after real device linking |
| 12 | Parent dashboard (M2) | IMPLEMENTED | 3 vertical widgets + providers + tests | Local |
| 13 | Safety policy model (schedules, overrides, precedence) | IMPLEMENTED | `PolicyEngine`, `PolicyRepository`, `DigitalPolicy`, `TemporaryOverride`, `ChildExceptionRequest` | Local only |
| 14 | Policy administration UI (CRUD, effective decision, override) | IMPLEMENTED (local vertical) | Phase 13 P0 vertical slice: `SafetyPoliciesScreen`, effective-decision states, emulator sync [8] | Production admin local-only |
| 15 | Screen-time usage measurement (capture) | PARTIAL | `DailyUsageSummary` cumulative upsert, `android_observation_gateway`, UsageStats method channel, on-demand `ChildScreenTimeCoordinator`; **no background collector** | No — device unverified |
| 16 | Screen-time decision engine | IMPLEMENTED (domain) | `ScreenTimeEngine.evaluate(usage, policies, override)` + evaluation persistence | Local only |
| 17 | Screen-time enforcement (blocking on child device) | NOT IMPLEMENTED | `android_enforcement_adapter` interface only; no OS-level enforcement proven, no UsageStats background worker | No |
| 18 | Bedtime | PARTIAL (policy-shaped, no enforcement) | `DigitalPolicy` carries `startMinute`/`endMinute`; no bedtime engine or worker | No |
| 19 | Location / geofencing | NOT IMPLEMENTED | `locations` table + `geolocator` dependency only | No |
| 20 | Web / content filtering | NOT IMPLEMENTED | Policy JSON payload can carry rules; no Android enforcement adapter or rules engine | No |
| 21 | Safety incident pipeline | IMPLEMENTED (local, no AI input) | `IncidentRepository`, notification contract, `GuardianIncident` family-scoped model | Local only |
| 22 | AI infrastructure | PLACEHOLDER (fail-closed) | `RiskEngine` + `UnconfiguredSafetyModelAdapter` fails safely | No |
| 23 | AI monitoring / inference | BLOCKED | Phase 9 production matrix: no reviewed model artifact; inference impossible until model review [4] | No |
| 24 | AI-generated safety incidents | NOT IMPLEMENTED | Depends on 23 | No |
| 25 | Parent-facing reports | NOT IMPLEMENTED | `DailyUsageSummary` totals exist; no aggregation/export/reporting engine | No |
| 26 | SOS local pipeline | IMPLEMENTED (local) | `SosRepository` + lifecycle + outbox (Phase 6 reconciled audit) [9] | No — FCM/SMS/device unproven |
| 27 | SOS SMS fallback | NOT IMPLEMENTED | — | No |
| 28 | Outbox sync to remote | PARTIAL (infrastructure complete) | Retry policy + executor + idempotency domain-verified; remote writer unconfigured | No |
| 29 | Offline-first cache | IMPLEMENTED (local) | All M1–M3 reads are SQLite; honest empty states proven by tests | Local canonical |
| 30 | Lifecycle / process-death / reboot / Doze recovery | NOT IMPLEMENTED | `ANDROID_LIFECYCLE_AND_RECOVERY.md` explicitly disclaims reboot receiver, persistent service, and Doze exemption [10] | No |
| 31 | Family chat | NOT IMPLEMENTED | `messages` SQLite table only | No |
| 32 | One-way audio | NOT IMPLEMENTED | — | No |
| 33 | Screen mirroring | NOT IMPLEMENTED | MediaProjection referenced in architecture only [11] | No |
| 34 | Couple Harmony Mode | PLACEHOLDER | `spouse` role exists with **no authority** until an owner-approved migration assigns product meaning [12] | No |
| 35 | Subscription / premium model | NOT IMPLEMENTED | No entitlement model exists anywhere | No |
| 36 | Local payments (Haseb / Jawal Pay / OneCash) | NOT IMPLEMENTED | — | No |
| 37 | Capability / permission ladder UI | IMPLEMENTED (surface) | `CapabilityGateway` + `PermissionsScreen` (supported/granted/requiresSettings), no false grant claims | Device verification pending |
| 38 | Push notifications (FCM) | PARTIAL (architecture) | Notification events + FCM token repository; physical delivery never evidenced [4] | No |
| 39 | Legacy prototype screens (`WelcomeScreen`, `ParentDashboardScreen`, `ChildProfileScreen`, legacy `router_provider`) | DEAD CODE (deliberately out of scope) | UX V2 reconciliation inventory; unreachable from live app [13] | N/A |
| 40 | Ownership transfer | NOT IMPLEMENTED (explicit) | Repository throws `family_ownership_transfer_not_implemented` [5] | No |
| 41 | Family deletion / account deletion / child removal / parent removal | NOT IMPLEMENTED | No family-deletion operation in `FamilyRepository`; removal exists only via member revocation | No |
| 42 | Audit history (administrative actions log) | NOT IMPLEMENTED | Outbox events are a mutation queue, not a reviewable audit trail | No |

Two structural observations follow from this audit. First, the repository's depth is greatest in **domain and local data** (items 3, 6, 7, 13, 16, 21, 26, 28 are all implemented and tested) and shallowest in **Android background execution and physical-device behavior** (items 17, 30, 38). Second, every capability the roadmap must deliver is blocked by the same three cross-cutting conditions: a configured remote sync path, a physical Android device session, and a production Firebase deployment. Those three conditions are human-action gates, not engineering tasks, and the milestone definitions below mark them explicitly.

---

## 4. Actual-vs-Planned Matrix

| Capability | Planned (vision) | Exists (domain) | Partial (vertical) | Missing (enforcement/device) | Production-Ready | Key Dependencies |
|---|---|---|---|---|---|---|
| Family creation & identity | Yes | GREEN | Dashboard UI GREEN | Remote sync | NO | Auth, SQLite, outbox |
| Multiple parents per child | Yes | GREEN (invite/accept/revoke) | List + invite UI only | Revoke/role/change UI | NO | Membership repo (ready) |
| Child profiles | Yes | GREEN (child = member) | M2/M3 display | Enrichment (blocked by contract) | NO | Membership |
| Device pairing (QR/PIN) | Yes | GREEN (SHA-256, lockout) | Parent issue partial | Child redemption UI, physical pairing proof | NO | Functions, device |
| Device lifecycle & unlinking | Yes | GREEN (9-value machine) | M2/M3 display | Unlinking UI | NO | Membership, pairing |
| Permission ladder | Yes | GREEN (domain matrix) | Ladder UI GREEN | Per-capability recovery | Device-only | CapabilityGateway |
| Screen time — policy creation | Yes | GREEN | Policy admin vertical GREEN (Phase 13) | Remote sync hardening | NO (local only) | Policy engine, UI |
| Screen time — measurement | Yes | GREEN (engine + summaries) | On-demand capture partial | Background collector | NO | UsageStats, Android worker |
| Screen time — enforcement | Yes | Interface only | — | OS enforcement, reboot/Doze resilience | NO | M7 + Android background |
| Bedtime | Yes | Policy-shaped | — | Bedtime engine + enforcement | NO | Screen-time vertical |
| Web filtering | Yes | Payload-shaped | — | Rules engine + enforcement adapter | NO | Android platform |
| Location / geofencing | Yes | Table stub | — | Capture, consent, engine, map UI | NO | Geolocator + consent |
| AI monitoring | Yes | Abstraction only | — | Model artifact, on-device inference | NO | Model review (blocked) |
| Safety incidents & alerts | Yes | GREEN (local) | Dashboard signal GREEN | FCM delivery proof | NO | Outbox + FCM |
| SOS (online/offline/SMS) | Yes | Local pipeline GREEN | Action UI partial | History UI, SMS fallback, background | NO | Device + FCM |
| Chat | Yes | Table stub | — | Domain, encryption, delivery, UI | NO | Realtime backend |
| One-way audio | Yes | — | — | Everything | NO | Privacy + Android |
| Screen mirroring | Yes | Concept only | — | Everything | NO | MediaProjection |
| Offline-first & sync | Yes | GREEN (cache) | Outbox executor partial | Remote writer configured | NO | Blaze + project access |
| Reboot / Doze / process-death recovery | Yes | Reload on re-entry only | — | Receiver, service, exemptions | NO | Android background design |
| Reports | Yes | Daily totals only | — | Aggregation, export, UI | NO | Data pipeline |
| Couple Harmony Mode | Yes | Role placeholder | — | Authority migration | NO | Family management |
| Subscription & payments | Yes | — | — | Everything | NO | After core capability |

---

## 5. Dependency Graph

The graph below is derived from the repository's actual type and provider relationships, not from assumed product ordering. Three facts drive it: `FamilyRuntimeContext` requires a verified actor before any permission holds; `ChildDeviceRepository.deliverPolicy` rejects any device that is not enrolled; `ChildScreenTimeCoordinator` requires both a persisted policy and an observation gateway; and the exception-request vertical (Phase 16) requires a device-scoped override path that presupposes device enrollment.

```text
Firebase Auth account
        │  (fail-closed identity)
        ▼
Trusted Actor Binding (FamilyActorBindingService)
        │
        ▼
Family Runtime Context ── FamilyAuthorization matrix
        │
        ├──► Family Membership
        │         create family → invite adult → accept → revoke → role update
        │              │
        │              ▼
        │        Roles & Permissions (parent / coParent / child / spouse authority)
        │
        └──► Child Device Enrollment
                  parent pairing issue (SHA-256 code) → child redemption
                        │
                        ▼
                  Device lifecycle (enrolled → active → offline → restricted → …)
                        │
                        ▼
                  Policy delivery to device (versioned, idempotent)
                        │
                        ├──► Usage measurement (Android UsageStats capture)
                        │         │
                        │         ▼
                        │   Decision engine (ScreenTimeEngine + exception overrides)
                        │         │
                        │         ▼
                        │   Enforcement (background + reboot + Doze resilience)
                        │
                        └──► Child Context display (M2/M3) + Timeline
                                      │
                                      ▼
                              AI infrastructure (fail-closed adapter)
                                      │
                                      ▼
                              AI monitoring → safety incidents → alerts → reports
                                      │
                                      ▼
                              SOS (online/offline/SMS fallback) ── late-stage vertical
                              Communication (chat / audio / mirroring) ── late-stage vertical
                              Commercial layer (subscription → local payments) ── after core
```

Cross-cutting prerequisites that gate **every** vertical: outbox remote sync configured (replaces `UnconfiguredOutboxRemoteWriter`), offline honesty preserved under network loss, and authorization boundaries enforced server-side (Firestore rules) rather than client-side. No vertical above can be declared production-ready while these three remain open.

---

## 6. MVP Critical Path

The MVP is defined as *the smallest sequence that makes Guardian Eye Pro a credible production parental-control product*: a parent can create a family, add a child, link the child's device, set screen-time limits, have those limits actually enforced on the device, receive honest safety signals, and have all of it survive offline periods and device restarts.

```text
M3 (complete) ──► M4 Device Linking ──► M5 Family Management
        │                                    │
        └────────────────┬───────────────────┘
                         ▼
                  M6 Screen Time Administration
                         │
                         ▼
                  M7 Screen Time Measurement
                         │
                         ▼
                  M8 Enforcement + Background Resilience
                         │
                         ▼
                  M9 Production Sync Gate (Blaze, rules, FCM evidence)
                         │
                         ▼
                  M10 AI Monitoring Baseline ──► M11 Reports & SOS Baseline
```

Capabilities **excluded** from the MVP critical path: location/geofencing, web filtering, chat, one-way audio, screen mirroring, Couple Harmony authority migration, subscription/commercial layer, and the late-stage communication vertical. These remain on the full roadmap (Section 7) precisely so that their platform dependencies (realtime backend, MediaProjection, Play policy compliance, payment integrations) never block the core product.

---

## 7. Full Product Roadmap

| Wave | Milestones | Scope |
|---|---|---|
| Wave 1 — Foundation (complete) | M1, M2, M3 | Shell, dashboard, child context |
| Wave 2 — Core linkage | M4, M5 | Device onboarding end-to-end; membership completion |
| Wave 3 — Core control | M6, M7, M8 | Screen time policy → measurement → enforcement + resilience |
| Wave 4 — Production gates | M9 | Remote sync, FCM evidence, physical-device validation program |
| Wave 5 — Intelligence | M10, M11 | AI monitoring baseline; reports and SOS baseline |
| Wave 6 — Enrichment | M12 | Couple Harmony authority; location/geofencing starter |
| Wave 7 — Advanced safety | M13 | Web filtering (Play-compliant); SOS SMS fallback |
| Wave 8 — Communication | M14 | Chat; one-way audio; screen mirroring (each gated by privacy review) |
| Wave 9 — Commercial | M15, M16 | Subscription model; local payments (Haseb, Jawal Pay, OneCash) |
| Continuous | M17 | Governance vertical: deletion, audit history, consent, retention, privacy settings |

The wave structure is a prioritization tool, not a commitment to fixed dates. Each milestone's acceptance gates in Section 8 are the binding definitions; the document supersedes any earlier milestone ordering implied by previous phase reports.

---

## 8. Milestone Definitions (M4 onward)

### M4 — Device Linking and Child Device Onboarding

**Objective.** Close the pairing vertical end-to-end: a parent issues a one-time pairing code or QR, the child device redeems it, the device binds to the correct member with the correct role, and the family's device status surface reflects the real lifecycle.

**Why now.** This is the highest evidence-to-effort decision available after M3. The pairing core (SHA-256 codes, five-attempt lockout, enrollment-once, owner binding, reuse rejection, revocation) is already implemented and Functions-emulator-verified, while the product-facing half (child redemption UI, role assignment surface, device status management) is explicitly absent — the Phase 13 feature matrix lists child redemption as missing and every M2/M3 display currently renders seeded or empty device data. Furthermore, `ChildDeviceRepository.deliverPolicy` rejects non-enrolled devices, which means the entire screen-time vertical cannot begin until device linking is closed.

**Dependencies.** Pairing core (GREEN); membership repository (GREEN); Functions emulator (GREEN); child role semantics in `FamilyRole` (GREEN). Requires a physical Android child device or AVD for redemption proof — flagged HUMAN ACTION REQUIRED in the gates.

**Included.** Parent pairing-issue flow (existing `PairingScreen` extended to real issuance with expiry display); child redemption screen (code entry, validation feedback, one-use semantics); role assignment confirmation for the enrolled device; device status list with real lifecycle values and an honest unlinking affordance; `PairingLifecycle` display states.

**Excluded.** Device management (revoke UI beyond unlinking), background measurement, any enforcement claim, FCM notifications, physical remote provisioning.

**Backend requirements.** None new — the existing Functions provisioning contract is reused; no rule or Function modification.

**Android/native requirements.** Method-channel proof of device capability presence on the redeemed child device; UsageStats/accessibility/overlay capability read on the child device (via the existing `CapabilityGateway`).

**Offline requirements.** Redemption must complete from the local pairing record when the network is unavailable; the outbox must queue the enrollment mutation and reconcile on reconnect. No fabricated "paired and synced" states.

**Security requirements.** No change to `FamilyActorBindingService`, `FamilyAuthorization`, or Firestore rules. Redemption must fail closed: wrong code, expired code, already-enrolled device, and child-role account attempts all produce explicit rejections. The child UID separation invariant (`account UID ≠ member ID ≠ device ID`) must hold in redemption tests.

**Acceptance gates.** Flutter analyze 0 issues; full suite GREEN (109+ plus new pairing/redemption tests, no regressions); Functions emulator 2/2; emulator pairing lifecycle tests GREEN; redemption happy path and four rejection paths GREEN; offline redemption GREEN.

**Expected evidence.** A completion report naming every new test, a redlined router diff showing only the redemption route, and a physical-device or AVD session record for the redemption flow.

---

### M5 — Family Management Completion

**Objective.** Turn the implemented membership repository into the complete family-administration surface: invitation management (create, view, cancel, history), member lifecycle (revoke with device revocation, role update), and the honest treatment of the `spouse` role.

**Why now.** The repository is fully implemented and regression-tested, but the UI exposes only a list and an invite button. Leaving admin actions repository-only creates a product gap precisely where trust is formed: parents must be able to see who is in the family and remove them. Placement immediately after M4 is deliberate — M4 establishes the *child* vertical's substrate; M5 establishes the *adult* vertical's substrate — and both complete the family graph that M6's policy administration assumes (owner-only policy mutation requires a clear owner surface).

**Dependencies.** Membership repository (GREEN); `FamilyRuntimeContext` (GREEN); owner permission gates (GREEN).

**Included.** Invitation list/history with status and expiry display; cancel invitation; revoke member with explicit confirmation and honest display of cascading device revocation; role update (parent ↔ coParent, owner-gated); the **spouse authority decision** (Phase 17 documents that `spouse` currently holds no authority; M5 must either migrate spouse to a defined authority set via owner approval or document the deferred product decision — this is a required deliverable, not an optional polish).

**Excluded.** Ownership transfer (explicitly `family_ownership_transfer_not_implemented` in the repository — this is a separate, deliberate milestone later, after multi-parent stability); child removal as a distinct flow (child lifecycle removal is routed through membership revocation semantics, which M5 documents); family deletion (deferred to the governance vertical, M17).

**Backend requirements.** None new; existing invitation/member outbox events reused.

**Android/native requirements.** None.

**Offline requirements.** All admin mutations queue through the outbox; revocation must apply locally immediately (local canonical) with honest queued-remote state.

**Security requirements.** Owner-only gates (`_requireOwner` with `inviteMembers`, `revokeMembers`, `manageRoles`) remain the sole authorization path; no new permission values may be invented; the child-identity-cannot-act-as-adult invariant must be re-asserted in new widget tests.

**Acceptance gates.** Analyze 0 issues; full suite GREEN with new tests for invite/cancel/revoke/role-update UI flows; 14/14 security regression unchanged; emulator 15/15 + 2/2.

**Expected evidence.** Completion report with the spouse-authority decision recorded verbatim, plus the full diff confined to `family_members_screen.dart`-adjacent files.

---

### M6 — Screen Time Administration

**Objective.** Harden the policy-administration vertical (already delivered as the Phase 13 P0 slice) into a first-class parent surface: editable schedules, clear effective-decision display, temporary-override lifecycle with honest expiry, and per-target policy state (video / social / games / browser and beyond).

**Why now.** The domain (`DigitalPolicy`, `PolicyEngine` precedence, `TemporaryOverride`, `ChildExceptionRequest`) and the local vertical exist and were emulator-verified, but they predate the experience sprint and were never reconciled with the M1–M3 canonical navigation and localization conventions. M6 reconciles them: policy administration must live inside the canonical router family, AR+EN keys, and the honest-state vocabulary (pending/blocked/effective), before the measurement and enforcement milestones give it real device data to administer.

**Dependencies.** Policy engine (GREEN); policy repository (GREEN); exception-request runtime (Phase 16 GREEN); canonical router (M1 GREEN).

**Included.** Policy list/editor consuming `policyRepositoryProvider`; effective-decision panel per target; temporary override creation with bounded duration and visible expiry; child exception request review surface for parents (approve/deny with the existing atomic transaction); sync state honesty (queued/pending/blocked) per policy.

**Excluded.** Usage data display (belongs to M7 measurement), any enforcement claim (M8), AI input to decisions (M10), schedule import from child device (later).

**Backend requirements.** None new; policy Firestore contract from Phase 13 reused.

**Android/native requirements.** None — explicitly device-independent, per the Phase 13 selection rationale.

**Offline requirements.** Policy save/review must complete locally with outbox queuing; the effective decision must compute from the local policy set with no network.

**Security requirements.** Owner/parent/coParent write boundaries per the `FamilyAuthorization` matrix; child read-only self-scope; no cross-family writes (emulator deny tests must cover).

**Acceptance gates.** Analyze 0 issues; full suite GREEN with policy-admin widget tests added; emulator policy allow/deny/idempotency GREEN.

**Expected evidence.** Completion report showing the reconciliation diff (navigation, localization, state vocabulary) and the retained Phase 13 test semantics.

---

### M7 — Screen Time Measurement

**Objective.** Move usage measurement from on-demand manual capture to a disciplined, consent-gated, replay-safe collection path on the child device: UsageStats reads, cumulative per-target daily summaries, and evaluation records — with honest permission states when usage access is denied.

**Dependencies.** M4 (enrolled device required); M6 (policies to evaluate against); `android_observation_gateway` and `ChildScreenTimeCoordinator` (existing, on-demand only).

**Included.** Consent-gated measurement flow honoring the capability ladder; cumulative upsert semantics (device + local day + target, never additive duplication); evaluation recording via `recordScreenTimeEvaluation`; honest states (`permissionRequired`, `permissionDenied`, `unsupported`, `observed`, `noObservation`); measurement visible on the child context activity card (per-app breakdowns, the documented M3 extension point).

**Excluded.** Background continuous collection (requires the Android background design of M8); enforcement actions from measurements; any claim about apps not covered by UsageStats.

**Backend requirements.** Usage-observation outbox events already queued by the repository; no new contract.

**Android/native requirements.** `UsageStatsManager` read path; Usage Access permission flow with transparent non-claiming UI; measurement proven on a physical child device or AVD — the Phase 15 validation protocol (force-stop and reopen, verify restored totals; network off/on).

**Offline requirements.** Summaries persist locally and display offline verbatim; sync queues when remote writer is configured (M9).

**Security requirements.** Measurement reads are family-scoped by device membership; no cross-member usage exposure; evidence remains immutable (existing `child_usage_observations` semantics).

**Acceptance gates.** Analyze 0 issues; suite GREEN with new coordinator tests; Phase 15 physical-device protocol executed and evidenced (the single largest gate of M7).

**Expected evidence.** Device session record: granted/withheld measurement, totals surviving force-stop, and offline display parity.

---

### M8 — Screen Time Enforcement and Background Resilience

**Objective.** Convert policy decisions into actual device behavior, and make the entire safety loop survive process death, reboot, and Doze. This is the milestone that changes the product's category from "dashboard" to "parental control".

**Dependencies.** M7 (measurements flowing); M4 (enrolled device); Android background design (a new architecture slice is required — this milestone must begin with a written background/lifecycle design and end with physical evidence).

**Included.** App-blocking or restriction enforcement through a legitimate Android path (documented, Play-policy-compliant, with a stated bypass-handling policy); bedtime window enforcement derived from `DigitalPolicy` schedules; watchdog that re-evaluates on process restart using durable policy/usage state (the reload-on-reentry pattern already proven in Phase 15 must be extended to a receiver/service design); reboot and Doze behavior with explicit, evidenced claims; transparent on-device indication when enforcement is active.

**Excluded.** System-wide surveillance claims; accessibility-service abuse; Device Owner provisioning (out of consumer scope unless a future enterprise decision is made); SMS fallback (M13); AI-driven enforcement (M10+).

**Backend requirements.** None new; enforcement is device-local by design, consistent with the offline-first architecture.

**Android/native requirements.** Foreground service or WorkManager design with documented standby-bucket behavior; BOOT_COMPLETED or equivalent recovery path; `device_admin`/Device Owner explicitly evaluated and recorded as in or out of scope; physical device evidence for every recovery claim.

**Offline requirements.** Enforcement decisions compute from the last valid local policy; network loss must never relax an active restriction.

**Security requirements.** Enforcement state is driven by `ChildPolicyResolver` against delivered policies; a stale-policy outcome must fail to `policyStale` handling, never to an open state.

**Acceptance gates.** Analyze 0 issues; suite GREEN with new background/recovery tests (mocked channels); **physical-device evidence** for: enforcement applied, process death recovery, reboot recovery, Doze resilience, and network-loss non-relaxation. This is the milestone most likely to require iteration; a GREEN gate requires the evidence, not the attempt.

**Expected evidence.** A device evidence appendix with dated sessions per scenario.

---

### M9 — Production Sync Gate

**Objective.** Convert the offline-first local truth into a synchronized product: configure the remote outbox writer (replace `UnconfiguredOutboxRemoteWriter`), harden Firestore rules against the real project, and prove FCM notification delivery.

**Dependencies.** All prior gates GREEN; Blaze plan and deployment access (HUMAN ACTION REQUIRED — explicitly out of scope for code work until the user approves); production rules review.

**Included.** Remote writer configuration and delivery tests; conflict/stale-data handling reconciliation; notification fan-out proof on a real device (token registration → event → display → acknowledgement); sync status honesty on all surfaces (no `synced` claims without delivery proof).

**Excluded.** Any new product feature; this milestone is purely infrastructure promotion.

**Backend requirements.** Real Firestore deployment, functions deployment, FCM setup — all behind user approval and a documented Firebase change inventory.

**Android/native requirements.** FCM registration on a physical device.

**Offline requirements.** All existing offline behavior preserved unchanged during promotion; chaos testing (network cut mid-sync) with evidenced recovery.

**Security requirements.** Production rules review against the Phase 9 family-isolation plan; no client-writable incident/notification evidence paths.

**Acceptance gates.** Emulator suite GREEN; delivery test GREEN on the real project with a test account; family-isolation rules evidenced; rollback plan documented.

**Expected evidence.** Firebase change inventory + delivery session record.

---

### M10 — AI Monitoring Baseline

**Objective.** Graduate the AI pipeline from fail-closed placeholder to a real, privacy-governed monitoring loop: onboard-device model artifact review, on-device inference wiring, and AI-generated safety incidents with the same honesty vocabulary as M2/M3.

**Dependencies.** M9 (incident sync to real backend); Phase 9's model-artifact blocker resolved (HUMAN ACTION REQUIRED — model review and legal/privacy assessment).

**Included.** `SafetyModelAdapter` concrete implementation behind the existing `RiskEngine`; confidence and model-version fields on `SafetyObservation`; AI incidents entering the family incident store with `modelVersion` traceability; parent-facing AI signal display with the existing verbatim-severity honesty (no fabricated risk scores).

**Excluded.** Cloud AI processing (privacy boundary); any inference without a reviewed model; per-child verdicts (the domain is family-scoped; per-child AI is a domain extension, already classified DEFERRED/BLOCKED in M3).

**Backend requirements.** Incident sync path from M9; model artifact hosting decision.

**Android/native requirements.** On-device inference runtime; encrypted local evidence storage semantics.

**Offline requirements.** Inference runs locally offline; incidents queue via the outbox.

**Security requirements.** Minimization and retention rules for AI evidence; explicit consent surface before monitoring activates.

**Acceptance gates.** Analyze 0 issues; suite GREEN with model-fixture tests; false-positive rate documented against fixtures; privacy-review sign-off recorded.

**Expected evidence.** Model review record + fixture evaluation report.

---

### M11 — Reports and SOS Baseline

**Objective.** Ship the parent-facing reporting surface (weekly screen-time, incident summary, device state history from persisted data only) and the SOS vertical's remaining half: history UI, offline SOS with honest queued/blocked states, and the online SOS delivery path proven through M9's notification infrastructure.

**Dependencies.** M7 (usage history), M2/M3 (incident display), M9 (delivery path), M10 optional (AI signals in reports).

**Included.** Report derivation strictly from persisted local data with empty/offline/error states; SOS history and state display; online SOS delivery via the proven notification path; honest offline SOS semantics.

**Excluded.** SMS fallback (M13); location sharing in SOS (blocked by location not being implemented); continuous family live-location (deferred to M12's location starter).

**Acceptance gates.** Analyze 0 issues; suite GREEN; report empty-state and offline tests GREEN; SOS state-machine tests GREEN.

---

### M12–M16 (Full-roadmap milestones)

| ID | Name | Core Content | Criticality |
|---|---|---|---|
| M12 | Couple Harmony + Location Starter | Owner-approved spouse authority migration; location capture with consent minimization; geofence model | MEDIUM |
| M13 | Web Filtering + SOS SMS Fallback | Play-compliant filtering adapter; SMS fallback behind local pipeline | MEDIUM |
| M14 | Communication Vertical | Chat (encrypted, queued, offline-first); one-way audio; screen mirroring — each with separate privacy review; NOT early milestones | LOW |
| M15 | Subscription Model | Entitlement domain (server-verified, never UI-unlockable), plans, paywall, restore/manage UI | LOW |
| M16 | Local Payments | Haseb → Jawal Pay → OneCash adapters, each with receipt verification; introduced only after M15's entitlement server exists | LOW |

Communication (M14) is placed late deliberately: it requires a realtime backend, end-to-end encryption decisions, participant authorization beyond the current matrix, and privacy review that the current evidence base does not yet support. Commercialization (M15/M16) is placed after core capability because unlocking access from a client-side plan would violate the Phase 13 security principle ("no access unlock from UI-only or client-provided plan") and because the local payment integrations require business agreements outside engineering scope.

### M17 — Governance Vertical (continuous)

**Scope.** The missing-work inventory from the vision reconciliation: ownership transfer, family deletion, account deletion, child/parent removal as distinct flows, device replacement, audit history (reviewable log distinct from the mutation outbox), consent records, data retention policy, privacy settings, notification preferences, sync-conflict UI, and stale-data handling. These are deliberately grouped into one governance milestone rather than scattered, because they share a design requirement — every destructive action needs a confirmation + evidence trail — and none of them blocks the MVP.

---

## 9. Security Dependencies

Security is a prerequisite layer, not a milestone feature. Three dependencies bind every future milestone:

1. **Fail-closed actor binding.** `FamilyRuntimeContext.can()` returns false whenever the actor is null, unverified, or inactive. No UI may ever reimplement this check locally; every screen must consume the runtime context. M4–M17 must each preserve this invariant in new tests.
2. **Single permission matrix.** `FamilyAuthorization.permissionsFor(role)` is the only permission source. Adding capabilities (location, chat, audio) requires matrix extension with explicit owner/parent/coParent/child columns — the Phase 17 permission-table pattern — never ad-hoc role checks.
3. **Server-authoritative boundaries.** The client is offline-first but never trust-authoritative: Firestore rules must deny child writes, cross-family writes, and evidence fabrication even when the client is compromised. M9's production rules review is the gate that promotes this from emulator evidence to real evidence.

Additionally: the spouse role's empty authority set is itself a security decision (Phase 17) and must not be loosened implicitly by M12; AI evidence must follow minimization and retention rules before M10 activates monitoring; and no milestone may introduce a secret, pairing secret material, or signing key into the repository.

---

## 10. Android Dependencies

Android capability is the project's scarcest resource, and the roadmap's critical path reflects that. The dependency chain is:

1. **UsageStats access** — required by M7 measurement; granted via the capability ladder's transparent non-claiming UI. Unverified on any physical device to date.
2. **Enforcement path** — M8 must choose and prove a legitimate Android mechanism (foreground service, WorkManager, possibly Device Owner) with explicit Play-policy compliance and a documented bypass behavior. The current codebase proves no such mechanism exists.
3. **Background survival** — reboot, Doze, and force-stop recovery require new native design (receivers/services/exemptions) that the repository explicitly disclaims today (`ANDROID_LIFECYCLE_AND_RECOVERY.md`).
4. **MediaProjection** — screen mirroring (M14) depends on a user-consented projection session; nothing exists.
5. **FCM token lifecycle** — M9 depends on real token registration and delivery proof; architecture only today.
6. **Physical device program** — every Android dependency above shares one gate: a real child device or AVD session. The sandbox has none; this is the single largest HUMAN ACTION REQUIRED item in the entire roadmap and it gates M4's redemption proof, M7's measurement proof, and M8's enforcement proof.

---

## 11. Offline Dependencies

The offline-first architecture (SQLite canonical store + idempotent outbox + retry policy) is one of the project's strongest verified assets, and it is also the substrate every milestone builds on. Three dependencies deserve explicit statement:

1. **Remote writer configuration.** Today the repository degrades through `UnconfiguredOutboxRemoteWriter`: local truth is complete, but nothing reaches the cloud. M4–M8 may all deliver GREEN under local semantics, yet the product is not a networked product until M9 replaces this writer. Milestones M4–M8 must therefore define their acceptance evidence in *local* terms only, and M9's gates are the promotion gates.
2. **Sync-conflict and stale-data handling.** The domain already proves idempotency at the mutation level (policy delivery's `applied/ignoredOlder/idempotent`, invitation idempotency, cumulative usage upserts). What remains unproven is the *user-visible* conflict story: what a parent sees when the same family is edited on two devices. This belongs to M9's chaos testing and M17's conflict UI — it must not be silently inherited by policy or membership screens.
3. **Honesty contract preservation.** M1–M3 established a strict rule: never render absent data as present. Every offline-dependent milestone (M7 measurements, M8 enforcement state, M10 AI signals, M11 SOS) must extend the existing empty-state vocabulary (`noDevicesLinked`, `syncUnavailable`, `screenTimeUnavailable`) rather than inventing optimistic defaults. The offline dependency is therefore behavioral: honesty, not just connectivity.

---

## 12. AI Dependencies

AI work must be sequenced as four distinct layers, because the repository's current state proves only the first:

1. **Infrastructure (placeholder, fail-closed).** The `RiskEngine` + `UnconfiguredSafetyModelAdapter` pipeline exists and fails safely — verified as an abstraction. No milestone may remove the fail-closed path.
2. **Model artifact (BLOCKED).** Phase 9 documents that no reviewed on-device model exists; inference is impossible until a model passes review. This is a HUMAN ACTION REQUIRED gate (model selection, legal/privacy assessment for the target market), and it blocks layer 3 entirely.
3. **Monitoring (M10).** Real inference, `modelVersion`-traceable `SafetyObservation`s, AI incidents flowing into the family-scoped incident store. Per-child AI verdicts remain a domain extension (family-scoped `GuardianIncident` has no child identifier) and stay BLOCKED until the domain is deliberately extended.
4. **Parent-facing reports (M11).** AI signals surfaced in reports with the verbatim-severity honesty rule — never a fabricated composite risk score.

No milestone should bundle layers 2 and 3: the model gate is external (review, privacy, possibly regulation), while the monitoring integration is internal engineering. Bundling them would let an external blocker masquerade as an engineering delay.

---

## 13. Family Management Placement

Family management is split across **M5 (completion of the adult-admin vertical) and M17 (governance)**, rather than one monolithic milestone or a single M4 placement, for three evidence-based reasons:

1. **The repository is already complete for the M5 slice.** `FamilyMembershipRepository` implements invite/accept/cancel/revoke/role-update with owner gates, idempotency, and revocation cascading to devices. The missing half is the UI surface — a bounded, well-understood effort that fits one milestone without new backend risk.
2. **The One-Child → Many-Parent model is already natively supported by the domain.** A child is a `FamilyMember` with `role == child`; adults join through invitations addressed to accounts (`accountUid` binding), and a child record is never duplicated per parent. Authorization is membership-scoped, so adding a second parent cannot create inconsistent child authorization. M5's job is to make this visible (invitation history, multi-parent display with device counts), not to invent it.
3. **Ownership transfer and destructive family lifecycle are deliberately excluded from M5.** The repository throws `family_ownership_transfer_not_implemented` by design, and family/child/account deletion have no repository support. Mixing these into M5 would import unproven destructive semantics into the milestone that establishes multi-parent trust. They belong to the M17 governance vertical, after the non-destructive surfaces have stabilized in production.

Couple Harmony Mode shares family membership and authentication with this vertical (it is a role on `FamilyMember`, not a separate system) but its *authority* question is independent and is deferred to M12, after core parental controls — see Section 15.

---

## 14. Device Linking Placement

Device linking is placed as **M4, the immediate next milestone, before any additional parental controls**, and this ordering is derived from the repository rather than assumed:

1. **`ChildDeviceRepository.deliverPolicy` rejects non-enrolled devices.** Policy delivery — the mechanism behind every future screen-time, bedtime, or filtering action — has an explicit `child_device_not_enrolled` failure path. No control milestone can run on an unlinked device.
2. **The M3 child context's most important card is the device state card**, and today it renders seeded fixture data or honest empty states. The product's central promise — "I can see my child's device" — is only honest once a real enrollment loop exists.
3. **The pairing core is the most-verified unused asset in the repo**: SHA-256 code semantics, five-attempt lockout, enrollment-once, owner binding, reuse rejection, and Functions provisioning are all implemented and emulator-verified. Completing the vertical (redemption UI + role assignment + status surface) is therefore the highest value-per-effort step available, and it creates no new security surface — it consumes an existing one.

Consequences of this placement: M4 must include the **child redemption UI** (the explicitly missing half per the Phase 13 matrix), an honest unlinking affordance backed by the existing revocation logic, and a physical-device or AVD redemption proof. It must *not* expand into device management breadth (revoke lists, replacement flows — deferred to M5/M17) or into enforcement claims.

---

## 15. Commercialization Placement

Commercialization is placed **after core product capability (M15 after M11, with M16 for local payments)**, as a separate commercialization wave, for structural reasons:

1. **The entitlement model does not exist.** There is no plan/entitlement domain anywhere in the codebase, and the Phase 13 security principle forbids client-side access unlocking. M15 must therefore build the entitlement backbone (server-verified) before any paywall UI.
2. **Premium gating before capability would gate features that do not yet exist.** Introducing subscription before M11 means selling a product whose enforcement (M8) and AI (M10) are unproven — bad-faith commercialization that the trust-based category cannot absorb.
3. **Local payments (Haseb, Jawal Pay, OneCash) carry external dependencies** — business agreements, settlement accounts, and receipt-verification semantics — that are outside engineering scope. They arrive only after M15's entitlement server can verify receipts from any source.
4. **The exception to the ordering:** lightweight infrastructure for entitlement *awareness* (a stub `EntitlementContext` consulted by the runtime context, fail-open to "no plan") could be introduced in M9 without a paywall, so that M15 later wires real plans without restructuring. This is optional and noted for M9's design review.

---

## 16. Deferred Features

The following capabilities are deliberately deferred beyond the MVP critical path. Each entry records the reason, so that deferral is a decision rather than an omission:

| Feature | Placement | Reason for deferral |
|---|---|---|
| Ownership transfer | M17 | Explicitly unimplemented in the repository by design; destructive semantics need a governance framework |
| Family / account / child / parent deletion | M17 | No repository support today; destructive lifecycle must not enter before the non-destructive vertical stabilizes |
| Location / geofencing | M12 | Only a table stub exists; consent, minimization, retention, and map UI are a full vertical of their own |
| Web / content filtering | M13 | No Android enforcement adapter; Play-policy compliance review required before any enforcement claim |
| Family chat | M14 | Requires realtime backend, encryption design, participant authorization, and moderation policy |
| One-way audio | M14 | Privacy and platform-risk surface too large for the current trust base |
| Screen mirroring | M14 | MediaProjection consent UX and privacy review not yet designed |
| Couple Harmony authority | M12 | `spouse` role deliberately authority-empty; authority migration needs an owner-approved product decision |
| AI per-child verdicts | BLOCKED until domain extension | `GuardianIncident` is family-scoped; extension must be deliberate, not incidental |
| SMS SOS fallback | M13 | Depends on device background capability (M8) and delivery proof (M9) |
| Subscription / payments | M15/M16 | After core capability; local payments carry external business dependencies |
| Audit history, consent records, retention | M17 | Governance shared design; outbox is a mutation queue, not a reviewable log |
| Notification preferences, privacy settings | M17 | Requires settings surface extension beyond the M1 settings scope |
| Legacy prototype screens | Permanent (excluded) | Dead paths per UX reconciliation; kept out of scope to preserve M1 dead-routes GREEN |

---

## 17. Technical Debt

The following debt items were identified during the audit and should be addressed opportunistically inside the milestone they touch, never as a standalone debt sprint:

1. **Legacy router and prototype screens** (`router_provider.dart`, `WelcomeScreen`, `ParentDashboardScreen`, `ChildProfileScreen`) remain in the tree as dead code. They are deliberately excluded from M1–M3 work to protect the dead-routes test, but a single cleanup commit (with a preserved dead-routes test proving the cleanup) is owed — best attached to M4's router change.
2. **Fragmented screen-time surfaces.** `ChildScreenTimeCoordinator` (Phase 15), the screen-time engine, and the M3 activity card evolved in separate sprints with different conventions; M6/M7 should consolidate onto the canonical navigation and localization vocabulary established in M1–M3.
3. **Reserved but unconsumed localization keys.** Keys such as `noRecentData`, `incidentsOpen`, and `syncing` were added in earlier passes and never consumed. M6–M7 should audit and consume or remove them.
4. **Unowned error taxonomies.** Repository error strings (`child_device_revoked`, `family_invitation_expired`, etc.) are tested but not yet surfaced through a user-facing error catalog; M4–M6 should map these to the honest localization vocabulary instead of leaking technical strings.
5. **No real remote writer.** This is infrastructure debt of the highest order but is gated by M9's production decisions, not by engineering debt-sprints.
6. **Missing AVD/device evidence everywhere.** The single largest debt: every Android capability in the codebase is unverified on a physical device. The physical-device program (M4/M7/M8 gates) is the repayment plan.

---

## 18. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | Android enforcement path proves non-compliant or unprovable on target devices | Medium | High | M8 begins with a design slice and legitimacy review; fallback to honest "advisory mode" if enforcement fails |
| 2 | Physical-device evidence unavailable (sandbox limit, device access) | High | High | Every milestone's gates explicitly separate sandbox-verifiable and device-verifiable evidence; device program tracked as HUMAN ACTION REQUIRED |
| 3 | Production Firebase deploy delayed (Blaze, approvals) | Medium | Medium | M9 is structured so M4–M8 deliver local truth unaffected; no milestone's gates depend on remote sync |
| 4 | AI model review stalls indefinitely | Medium | Medium | M10 fails closed; product ships honest non-AI safety signals (M2/M3 precedent) until the gate opens |
| 5 | Ownership-transfer decision pressure forces premature destructive features | Medium | Medium | Kept in M17 by explicit design; M5 documents the decision as deferred |
| 6 | Offline honesty regressions as surfaces multiply | Medium | Medium | Every milestone inherits the verbatim-honesty contract with dedicated empty-state tests |
| 7 | Couple Harmony or chat features introduced early under user enthusiasm | Low | Medium | Deferred placements are documented in this roadmap; any early attempt must update this document first |
| 8 | Local payment integrations misread as prerequisite to launch | Low | Medium | Commercial wave is explicitly post-capability in this roadmap |

---

## 19. Recommended Next Milestone

> **What should we implement immediately after M3, and why?**

**M4 — Device Linking and Child Device Onboarding.**

This is the answer the repository evidence forces, not the one that sounds most natural. Three independent evidence lines converge:

1. **The display layer has outgrown the data layer.** M2 and M3 built honest, well-tested surfaces for device state, screen time, and safety — but every one of them reads seeded fixtures or renders "no device linked" until a real enrollment loop exists. The next unit of user value is not another dashboard surface; it is the mechanism that populates the existing ones.
2. **The missing half is small and the present half is verified.** The pairing core is implemented and Functions-emulator-verified; the Phase 13 matrix identifies exactly one missing piece (child redemption UI) plus role-assignment and status surfaces. Nothing else in the backlog has this ratio of verified foundation to remaining work.
3. **Downstream milestones are structurally blocked without it.** `ChildDeviceRepository.deliverPolicy` rejects non-enrolled devices, which means the screen-time vertical (M6–M8) — the product's core parental-control promise — cannot even begin until linking is closed.

What this recommendation explicitly **rejects**, and why: Screen Time as the next milestone would front-load administration (already delivered in Phase 13) while its measurement and enforcement halves have no device substrate; Family Management first would deliver administrative value to a product whose primary user promise — visibility and control of the child's device — remains empty. Device linking first makes both subsequent milestones strictly easier, because M5's member-device-count surfaces and M6's device-scoped policies both consume the enrollment truth M4 establishes.

After M4's gates pass, the prescribed order is M5, then M6–M8 as the screen-time vertical in its three deliberate stages, then the production sync gate (M9), then AI and reports (M10–M11). No milestone beyond M3 has been implemented, and none will begin without explicit instruction.

---

## 20. Roadmap Change Log

| Entry | Date | Author | Change |
|---|---|---|---|
| 1 | 2026-08-13 | Manus AI | Created `GUARDIAN_EYE_CANONICAL_ROADMAP.md` as the post-M3 authoritative roadmap, superseding prior milestone-ordering hints in Phase 13–16 reports for planning purposes. Defines M4–M17, MVP critical path, full roadmap, and deferral table. |
| 2 | 2026-08-13 | Manus AI | Placed Device Linking at M4 (before Screen Time and Family Management), derived from `deliverPolicy` enrollment rejection, M3's fixture-limited data layer, and the verified pairing core. |
| 3 | 2026-08-13 | Manus AI | Split Family Management into M5 (non-destructive completion) and M17 (governance/destructive lifecycle), preserving the `family_ownership_transfer_not_implemented` design decision. |
| 4 | 2026-08-13 | Manus AI | Split Screen Time into three milestones (M6 administration, M7 measurement, M8 enforcement/resilience), consistent with the Phase 13 separation of policy creation from device enforcement. |
| 5 | 2026-08-13 | Manus AI | Deferred communication (chat/audio/mirroring) to M14, Couple Harmony authority to M12, commercialization to M15/M16, and location/filtering to M12/M13 — none may block the MVP critical path. |
| 6 | 2026-08-13 | Manus AI | Declared M9 a pure infrastructure-promotion milestone (remote writer, rules, FCM proof) gated by HUMAN ACTION REQUIRED Firebase decisions; M4–M8 evidence defined in local terms only. |
| 7 | 2026-08-13 | Manus AI | M5 executed with early real-backend integration under the owner-authorized execution model: real `manus-guardian` (Spark, `billingEnabled: false`) audited read-only (Phase B), document shapes verified compatible, outbox-backed operations (invite/cancel/accept/role update/revocation) classified REAL FIREBASE — queued until the local `firebase/firestore.rules` is redeployed (the live ruleset `c102428d` lacked the `invitations` subcollection block). M9 remains the production promotion gate; this change refined the execution model without cancelling M9. |
| 8 | 2026-08-13 | Manus AI | M5 Backend Promotion Closure: with explicit owner approval, the local `firebase/firestore.rules` (md5 `bc8278d80e28f41cf64da976314c9886`) was deployed to real `manus-guardian` (`firebase deploy --only firestore:rules`). The production ruleset is now `e22c310a-c24e-4101-abb7-9df31c57e5cc`, byte-identical to the repository file, carrying the `families/{familyId}/invitations/{invitationId}` block. Deployed-rules verification passed 4/4: owner invitation create, atomic acceptance batch, owner-only role update and revocation with cross-family denial, and scoped member/invitation reads. Invitation, role-update, and revocation remote sync were reclassified from REMOTE INVITATION SYNC BLOCKED to REAL FIREBASE; only a real signed-in app Auth session remains HUMAN ACTION REQUIRED. No Blaze activation, no Functions deployment, no production data written — the production database remains empty as found. See [18].
| 9 | 2026-08-13 | Manus AI | M6 Screen-Time Administration executed and closed GREEN: new `ScreenTimePoliciesScreen` (`/child/:familyId/:childId/policies`) with policy list, effective-decision preview (`PolicyEngine.resolve`), editor bottom sheet, mandatory bounded-expiry temporary overrides, child exception request review (approve/deny atomic pipeline), inline enable/disable, and honest `SyncState` display; `_ComingSoonSection` replaced by a live `_ScreenTimeSection`; ~45 Arabic/English localization keys; 20 new tests; deployed-rules harness extended to 5 M6 cases (parent CRUD policies, child denied, parent override, child exception request with parent review, foreign-family denial). Full evidence: `flutter analyze` 0 errors/0 warnings; suite 160/160; security regression 17/17; Emulator 15/15 + 2/2; deployed-ruleset harness 9/9. Honest non-claims preserved: no enforcement claims in the UI, `SyncState.synced` only after real outbox delivery (HUMAN ACTION REQUIRED), and the deployed ruleset does not validate a mandatory `expiresAt` payload at rule level (client-side guard documented in the harness). No changes to `PolicyEngine`, membership, binding, rules, Functions, or Firebase configuration; no Blaze; M7 NOT started. See [19]–[23]. |


| 10 | 2026-08-13 | Manus AI | M7 Screen-Time Measurement executed and closed GREEN: consent-gated, on-demand usage measurement on the child's linked device presented in the child-context screen. New honest observation states (`stale`, `offlineCached`, `syncPending`, `syncFailed`) and `UsageFreshness` with a 2-hour freshness threshold; zero-as-data rule (0 observed minutes renders as a measured total; absence-of-observation renders distinct copy); per-target breakdown with honest policy comparison labels (`policy condition detected` / `over limit` — never "Blocked"); sync evidence derived from pending outbox rows with `SyncState.synced` reachable only via real outbox delivery. Files: `screen_time.dart` (domain), `child_usage_measurement.dart` + `child_usage_measurement_provider.dart` (snapshot models/provider), `child_device_repository.dart` (pending-usage outbox read extension), `child_context_screen.dart` (measurement section), `app_localizations.dart` (29 AR/EN keys), `childUsageMeasurementProvider` in guardian providers; 37 new M7 tests; deployed-rules harness extended to 7 M7 cases (parent read, child own-device write, lineage invariants incl. zero/negative totals, parent write denial, immutable append-only summaries, revoked-device write denial, foreign-family isolation). Evidence: `flutter analyze` 0 errors/0 warnings; suite 197/197 (M3 regressions repaired via honest stub fixtures, evidence strengthened); security regression 14/14; Emulator 15/15 + 2/2; deployed-rules harness (`e22c310a`) 16/16. Honest non-claims preserved: Gate 13 (physical device/AVD) HUMAN ACTION REQUIRED; REAL SIGNED-IN APP AUTH + REAL OUTBOX DELIVERY to `SyncState.synced` HUMAN ACTION REQUIRED; no enforcement, no background service, no AI; no changes to `PolicyEngine`, membership, binding, SQLite, outbox, rules, Functions, or Firebase configuration; no Blaze; M8 NOT started. See [24]–[27]. |
| 11 | 2026-08-14 | Manus AI | M8 Screen-Time Enforcement and Background Resilience executed and closed GREEN: honest notification-verified enforcement on the child's Android device, replacing the Phase-14 conservative stub. New honest enforcement vocabulary (`EnforcementState` — 11 values, incl. `enforcementApplied`, `enforcementFailed`, `policyStale`, `recoveryPending`, `permissionDenied` — never "Blocked"), `EnforcementApplication`/`EnforcementSyncState`/snapshot models, and `child_enforcement_coordinator.dart` (resolver → engine → adapter observe → adapter apply → durable state → sync queue); SQLite schema v13 `child_enforcement_states` (fresh + upgrade paths); a transparent foreground service (`EnforcementService.kt`, `UsageStatsManager`, persistent family notification), a `BOOT_COMPLETED` receiver re-establishing WorkManager evaluation, and `MainActivity.kt` channel implementations; permissions `FOREGROUND_SERVICE`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`; child-context enforcement UI section with 22 AR/EN localization keys. Design: consumer apps cannot block other apps without device-owner privileges, so enforcement is recorded as `applied` only on verified OS confirmation; stale/missing/monotonically-invalid policies can never reach enforcement (fail to `policyStale`); offline enforcement holds on local truth until the 7-day watermark; revocation drops authority immediately; M6 bounded overrides flow through unchanged and expired overrides fall back to the policy decision. Evidence: `flutter analyze` 0 errors/0 warnings; suite 217/217 (3 transient fixture-level regressions repaired and strengthened — retired Phase-14 guardrail updated to the honest contract, M6 decision-preview scroll finder scoped, probe wipe order fixed); M8 unit suite 19/19; security regression 14/14; Emulator 15/15 + 2/2; deployed-rules harness (`e22c310a`) 23/23 after appending 7 `enforcement_status` scenarios (parent read; child writes own active device with `statusId == 'current'` + lineage invariants; parent write denied; delete denied for everyone; revoked-device write denied; foreign-family isolation). Honest non-claims preserved: Gate 13 physical-device evidence (enforcement applied, process death, force-stop, reboot, Doze, network loss, permission revocation, stale policy) HUMAN ACTION REQUIRED (GA-08–GA-15); REAL SIGNED-IN APP AUTH + REAL OUTBOX DELIVERY to `SyncState.synced` HUMAN ACTION REQUIRED; `foregroundServiceType` (Android 14+) prepared-for-production-promotion; override expiry guard client-side with the parent-only rule non-claim preserved (GA-22); no Blaze; no Firebase configuration change; no production data; no changes to `PolicyEngine`, membership, binding, SQLite core, outbox core, rules, or Functions beyond the enforcement schema/table additions; M9 NOT started. See [29]–[33]. |
This document is a living artifact. Any deviation from its milestone ordering must be recorded here before implementation begins, and no M4+ implementation may start without explicit user instruction, per the standing user requirements.

---

## References
[24]: docs/UX_SPRINT_01_M7_SCOPE_AND_CONTRACT.md "M7 Scope and Contract"
[25]: docs/UX_SPRINT_01_M7_GAP_AUDIT.md "M7 Gap Audit"
[26]: docs/UX_SPRINT_01_M7_TEST_EVIDENCE.md "M7 Test Evidence"
[27]: docs/UX_SPRINT_01_M7_COMPLETION_REPORT.md "M7 Completion Report"
[28]: docs/UX_SPRINT_01_M7_FINAL_CHECKPOINT_REPORT.md "M7 Final Checkpoint Report"
[29]: docs/UX_SPRINT_01_M8_ANDROID_ENFORCEMENT_DESIGN.md "M8 Android Enforcement Design"
[30]: docs/UX_SPRINT_01_M8_GAP_AUDIT.md "M8 Gap Audit"
[31]: docs/UX_SPRINT_01_M8_TEST_EVIDENCE.md "M8 Test Evidence"
[32]: docs/UX_SPRINT_01_M8_COMPLETION_REPORT.md "M8 Completion Report"
[33]: docs/UX_SPRINT_01_M8_FINAL_CHECKPOINT_REPORT.md "M8 Final Checkpoint Report"

[1]: docs/UX_SPRINT_01_M1_COMPLETION_REPORT.md "M1 Completion Report"
[2]: docs/UX_SPRINT_01_M2_COMPLETION_REPORT.md "M2 Completion Report"
[3]: docs/UX_SPRINT_01_M3_COMPLETION_REPORT.md "M3 Completion Report"
[4]: docs/PHASE_9_PRODUCTION_READINESS_MATRIX.md "Phase 9 Production Readiness Matrix"
[5]: lib/data/family_membership_repository.dart "Family Membership Repository (implementation evidence)"
[6]: lib/application/family_context_provider.dart "Family Runtime Context (Phase 18 architecture)"
[7]: docs/phases/PHASE_18_COMPLETION_REPORT.md "Phase 18 Completion Report"
[8]: docs/PHASE_13_FEATURE_MATRIX.md "Phase 13 Feature Matrix"
[9]: docs/GAP_AUDIT_RECONCILED_PHASE6.md "Phase 6 Reconciled Gap Audit"
[10]: docs/ANDROID_LIFECYCLE_AND_RECOVERY.md "Android Lifecycle and Recovery"
[11]: docs/ARCHITECTURE_STATUS.md "Architecture Status"
[12]: docs/PHASE_17_ARCHITECTURE.md "Phase 17 Architecture — Canonical Family Membership"
[13]: docs/UX_SPRINT_01_V2_RECONCILIATION.md "UX Sprint 01 v2 Reconciliation — dead-path inventory"
[14]: docs/UX_SPRINT_01_M5_SCOPE_AND_CONTRACT.md "M5 Scope and Contract"
[15]: docs/UX_SPRINT_01_M5_GAP_AUDIT.md "M5 Gap Audit"
[16]: docs/UX_SPRINT_01_M5_TEST_EVIDENCE.md "M5 Test Evidence"
[17]: docs/UX_SPRINT_01_M5_COMPLETION_REPORT.md "M5 Completion Report"
[18]: docs/UX_SPRINT_01_M5_BACKEND_PROMOTION_CLOSURE.md "M5 Backend Promotion Closure"
[19]: docs/UX_SPRINT_01_M6_SCOPE_AND_CONTRACT.md "M6 Scope and Contract"
[20]: docs/UX_SPRINT_01_M6_GAP_AUDIT.md "M6 Gap Audit"
[21]: docs/UX_SPRINT_01_M6_TEST_EVIDENCE.md "M6 Test Evidence"
[22]: docs/UX_SPRINT_01_M6_COMPLETION_REPORT.md "M6 Completion Report"
[23]: docs/UX_SPRINT_01_M6_FINAL_CHECKPOINT_REPORT.md "M6 Final Checkpoint Report"

*Implementation evidence cited above was verified read-only against the repository at commit `d72c66d`. No file was modified in producing this document.*
