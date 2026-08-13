# Guardian Eye Pro — Master Product Blueprint & Canonical Roadmap

**Document type:** Single authoritative product blueprint and canonical development roadmap
**Baseline:** `d72c66d282600b56c0cf882976bcf91e4adc25cd` (master, M3 GREEN checkpoint)
**Protected checkpoint:** `phase17-stable-checkpoint = 274e181` (untouched, immutable)
**Companion document:** `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` (milestone definitions M4–M17)
**Author:** Manus AI
**Date:** August 13, 2026
**Constraint:** This task is documentation and strategic reconciliation only. No Dart code, Android code, Firebase configuration, Firestore rules, dependencies, tests, or feature implementation was changed. No commit or push was performed.

---

## 1. Executive Summary

Guardian Eye Pro is positioned as a **Family Operating System**: one coherent product integrating family management, child management, device management, parental controls, safety monitoring, emergency capabilities, communication, intelligence, offline reliability, security, reporting, and commercialization. Its identity is **human-engineered, AI-powered, family-first** — AI is an internal capability that earns its place where it provides real value, not the product's public identity.

The verified engineering state is strong for an early-stage product: M1 (canonical shell and navigation), M2 (parent dashboard with family identity, child overview, and honest safety signal), and M3 (child context vertical) are all GREEN at `d72c66d`, with 109/109 Flutter tests, zero analysis issues, and GREEN emulator evidence (15/15 Firestore + 2/2 Functions), built on an untouched Phase 17 security baseline. Beneath the experience layer, the repository already holds implemented, tested domain assets for membership, pairing, policy, screen-time decisions, incidents, SOS, and an idempotent offline outbox.

The blueprint's central strategic finding is that the **next twenty months of work are about vertical integration, not new domains**: device linking (M4), family management completion (M5), the screen-time vertical in three stages (M6–M8), production promotion (M9), and intelligence (M10–M11). The product's durable competitive position rests on three evidence-supported pillars that the current architecture already encodes: Arabic/RTL-first design with regional payment corridors, offline-first reliability suited to weak-connectivity regions, and an honesty-based enforcement vocabulary that competitors structurally cannot copy without rewriting their cloud-dependent architectures.

The $600,000 annual revenue target for 2028 is achievable under an explicit base scenario — approximately 8,000 paying families at a blended $75/year average revenue per family — but it depends on a small number of business-critical capabilities: family onboarding that survives activation friction (M4/M5), a daily-engagement loop (M2/M3 dashboard quality), premium-conversion triggers (M8 enforcement, M10 AI alerts, M11 reports), and low-infrastructure-cost economics that on-device AI and offline-first design uniquely provide. The recommended immediate next milestone is **M4 — Device Linking and Child Device Onboarding**, for reasons documented in Section 25 and in the companion roadmap.

---

## 2. Product Vision

Guardian Eye Pro is not merely a parental-control app, a screen-time app, an AI app, or a monitoring app. It is a **Family Operating System** — software that helps families manage, protect, coordinate, and respond to the major digital and safety problems modern families face. The vision requires the product to treat the family, not the child, as the primary unit of value: parents collaborate rather than surveil alone, children are members with their own explained context rather than monitored targets, and the system remains dependable when connectivity, power, or platform support fail. This coherence — every capability serving one family-level picture — is the reason the roadmap is written as a single milestone sequence (Section 24) rather than a feature backlog.

---

## 3. Product Identity

The product identity statement is:

> **Human-engineered. AI-powered. Family-first.**

What this means operationally: the design constitution, UX copy, and marketing materials must present Guardian Eye Pro as a professionally engineered family safety and management system that uses AI where it provides real value. Public positioning must never invite the assumption "this is an AI app," and no public claim about engineering experience may exceed what is factually supportable. The identity shows up in design through the honesty contract already proven in M1–M3: capabilities report true states (granted / requires settings / unsupported), enforcement reports true levels (evaluated / requested / applied), and absence of data is never rendered as presence.

---

## 4. AI Positioning

AI is an internal technology capability, and the blueprint separates it into layers that are never marketed or engineered as a monolith: **infrastructure** (the fail-closed `RiskEngine` adapter, implemented), **model artifact** (blocked until review), **on-device inference**, **detection and classification**, **incident generation**, **parent alerts**, **reporting**, and **longitudinal insights**. The product experience leads with family workflows — device state, screen-time conversations, exception requests, safety signals — and AI appears in them as an enhancement that meets the same honesty standards as every other signal: AI-generated incidents carry `modelVersion` traceability, never fabricated composite risk scores, and the fail-closed path remains intact if the model is unavailable. This positioning is both an integrity decision and a defensive moat: competitors selling "AI magic" cannot easily imitate a product that refuses to overclaim.

---

## 5. Design Constitution

The product UX is governed by **Ben Shneiderman's Eight Golden Rules of Interface Design**, applied product-wide as a Design Constitution rather than a per-screen checklist. The M1–M3 work already conforms substantially: consistency through a canonical router and one localization system; informative feedback through explicit loading/success/empty/error/queued states; clear closure through the exception-request lifecycle (pending → approved/denied → expired); error prevention through permission ladders that disable impossible actions before they fail; user control through pull-to-refresh and retry on every async surface; reduced memory load being the principal remaining weakness (the M2 dashboard's seven action buttons map imperfectly to six parent questions, per the UX reconciliation); and prevention of errors through idempotent pairing codes and five-attempt lockouts. Every future milestone must preserve these principles and re-verify them in its acceptance gates.

---

## 6. Target Users

The primary user is the **modern Arab/MENA parent** — a digitally native caregiver managing one or more children's devices, often alongside a spouse or co-parent, in households where the dominant competitor alternatives are either free but limited (Family Link), English-centric (Qustodio, Bark), or regionally absent (Bark is explicitly unavailable outside the US, South Africa, and Australia [5]). Secondary users include **bilingual households** (the app is AR+EN RTL-first), **multi-parent families** (step-parents, co-parents — directly supported by the invitation/role model), and **families in weak-connectivity regions** for whom offline-first behavior is not a convenience but a requirement. Enterprise/education use is explicitly deferred until a consumer stabilization point.

---

## 7. User Roles

The authoritative role model is derived from the repository's `FamilyRole`/`FamilyPermission` architecture, extended with operational definitions:

| Role | Identity | Responsibilities | Permissions | Prohibited | Visibility | Device Relationship |
|---|---|---|---|---|---|---|
| **Owner (primaryParent)** | Member who created the family | Family lifecycle, membership, billing anchor | All permissions including invite/revoke/role-change/ownership | None except child self-scope; cannot self-demote in Phase 17 | Full family | Own parent device |
| **Parent** | Invited adult member | Day-to-day policy and child management | View/manage children, view/manage policies, review exceptions | Invite/revoke, role changes, billing | Full family except billing | Own parent device |
| **Secondary Parent (coParent)** | Invited adult member | Symmetric day-to-day management | Identical to parent in current matrix | Same as parent | Full family except billing | Own parent device |
| **Child** | Family member with `role == child` | Device usage, exception requests | Scoped self-only views and requests | Any adult action; cannot act as adult (fail-closed binding) | Own profile/state | Child device(s) bound via member |
| **Spouse / Couple participant** | `spouse` role member | Presence in the family picture | Visibility only (deliberately authority-empty) until owner-approved migration (M12) | Policy, membership, child actions | Family presence only | Spouse device |
| **Unlinked user/device** | Outside any membership | None | None — actor binding returns closed context | Everything | Nothing | No relationship |
| **SOS recipient** | Designated responder(s) | Emergency response | Receive SOS alerts, acknowledge | No family administration | SOS events only | Any device with notification path |

The invariant that governs all roles is the Phase 17 identity separation: **account UID ≠ member ID ≠ device ID**. A device derives no authority from the screen it opens; only a verified, active membership does.

---

## 8. Family Model

The canonical conceptual model, reconciled with the repository's actual data layer:

```text
User (Firebase Auth account)
   ↓ accountUid binding (nullable, fail-closed)
Family Membership (FamilyMember: role, status, familyId, accountUid)
   ↓
Family (GuardianFamily: id, name, owner reference, created)
   ↓ members with role == child
Child (FamilyMember where role == child — one child record, many parents)
   ↓ devices.member_id
Device (ChildDeviceState: lifecycle 9 values, lastSyncAt, policy version)
   ↓ delivered policies
Policy (DigitalPolicy: targets, schedules, limits, version)
   ↓ evaluations
Incident (GuardianIncident: family-scoped, severity, acknowledgement)
   → Alert (notification events → FCM / local)
   → Report (aggregations over DailyUsageSummary / timeline)
   ↓ (future)
Subscription (entitlement: server-verified, per-family)
```

This model supports the **One Child → Many Parent Accounts** requirement natively: a child is a single member; adults join through email-addressed invitations that bind their account UID; authorization is membership-scoped, so no duplicated child records or inconsistent authorization can arise from additional parents. Existing repository models validate every element of this model (`GuardianFamily`, `FamilyMember`, `FamilyInvitation`, `ChildDeviceState`, `DigitalPolicy`, `GuardianIncident`, `DailyUsageSummary`, `SafetyObservation`, `PairingLifecycle`, `ScreenTimeEvaluation`), with one legacy artifact noted: `family_entity.dart` contains an older `FamilyEntity`/`FamilyMember` schema that is superseded by the Phase 17/18 canonical models.

---

## 9. Child Model

A child in Guardian Eye Pro is simultaneously a **member** of the family (carrying identity, membership status, and authorization scope) and the **anchor of a device relationship** (one or more devices bound through `devices.member_id`). The child's operational surface is deliberately bounded on both sides: as a member, the child cannot perform any adult action because the actor binding fails closed for child-role accounts; as a device anchor, the child's device receives delivered policies and produces usage observations that feed evaluations. The child also has an **explained context**: the M3 vertical presents the child's own state (device lifecycle, today's usage, safety card) rather than hiding the child inside the parent's dashboard, and the exception-request flow (Phase 16) gives the child a voice in the policy conversation with visible pending/expired states. Child removal, reassignment, and lifecycle events are deferred to the M17 governance vertical.

## 10. Device Model

Devices are first-class, role-typed entities: `parentDevice`, `childDevice`, `spouseDevice`, `coParentDevice`, governed by a nine-value lifecycle machine (`unlinked → pairingPending → enrolled → active → offline → restricted → suspended → revoked → recovering`). Linking flows through the pairing system: one-time SHA-256-hashed codes with expiry, five-attempt lockout, enrollment-once semantics, owner binding, reuse rejection, and revocation that cascades to all member devices. The model's discipline is its honesty vocabulary (`notRequested / blockedByPermission / unsupported / deferred / evaluated / enforcementRequested / enforcementApplied / enforcementFailed`) — a device never reports `applied` for a capability that has not been system-verified. Parent devices and spouse devices are modeled but currently carry only display roles; their interactive surfaces (device status, permission ladder) belong to M4–M5.

## 11. Product Domains

All twelve intended product domains and their current state:

| Domain | Scope | Current State |
|---|---|---|
| A. Family Management | creation, identity, members, roles, invitations, lifecycle, deletion | Implemented repository + partial UI (M5) |
| B. Child Management | profile, context, status, device relationship, removal | Implemented core (M3); removal deferred (M17) |
| C. Device Management | pairing, QR/PIN, link/unlink, replacement, state, ladder, roles | Pairing core GREEN; redemption UI + ladder verification (M4) |
| D. Modes | parent/child/couple harmony | Parent+child contexts exist; couple authority deferred (M12) |
| E. Parental Controls | screen time, bedtime, schedules, custom modes, filtering, location, geofencing, device controls | Policy/admin GREEN locally; measurement (M7), enforcement (M8); filtering/location NOT started |
| F. Safety | on-device AI, content analysis, incidents, severity, alerts, SOS, offline SOS, SMS fallback, location sharing | Local pipelines GREEN; AI blocked; SMS/location deferred |
| G. Communication | chat, parent-child communication, audio, mirroring | Table stub only; deferred (M14) |
| H. Intelligence | infrastructure→inference→detection→classification→incidents→alerts→reporting→insights | Layer 1 fail-closed GREEN; layers 2–8 (M10–M11) |
| I. Reports | daily/weekly/monthly, safety, activity, family summaries | Daily totals exist; reporting engine (M11) |
| J. Reliability | offline-first, SQLite, cache, pending ops, retries, sync, conflict, process death, reboot, doze, chaos, background | SQLite/outbox/retry GREEN; reboot/doze/background NOT implemented |
| K. Security/Privacy | auth, isolation, membership, child ownership, actor binding, rules, sensitive actions, consent, retention, deletion, recovery, auditability | Binding/matrix/isolation GREEN locally; deletion/audit/consent (M17); production rules (M9) |
| L. Commercial | subscription, tiers, trial, multi-child/parent pricing, local payments | Not started (M15/M16); entitlement-awareness optional in M9 |

## 12. Security Model

Security is the non-negotiable foundation, expressed as four enforced laws. **Law 1 — fail-closed identity:** every permission decision flows through `FamilyRuntimeContext`, which returns no authority for null, unverified, or inactive actors; no screen may reimplement authorization. **Law 2 — single permission matrix:** `FamilyAuthorization.permissionsFor(role)` is the only permission source; new capabilities extend the matrix with explicit per-role columns, never ad-hoc checks. **Law 3 — identity separation:** account UID, member ID, and device ID are distinct; devices derive no authority from local presence. **Law 4 — server-authoritative boundaries:** the client is offline-first but never trust-authoritative; Firestore rules must deny child writes, cross-family writes, and evidence fabrication even under client compromise. The current evidence base satisfies Laws 1–3 locally (14/14 regression tests) and Law 4 at emulator level (15/15 rules tests); Law 4's real-world proof is M9's gate. Sensitive actions (invite, revoke, role change, policy mutation) are owner/parent-gated and outbox-queued with idempotency keys, and no secret material may ever enter the repository.

## 13. Offline Model

The offline model is **local canonical**: SQLite holds the complete truth of family, members, devices, policies, incidents, SOS states, and usage summaries; all reads are local-first; mutations enqueue to an idempotent outbox that reconciles on reconnect; and every surface renders honest states (synced / queued / blocked / unavailable) with no optimistic defaults. The remote writer is presently unconfigured (`UnconfiguredOutboxRemoteWriter`), meaning local truth is complete but networked sync is not yet promoted — this is the M9 decision. Two obligations bind all future work: offline behavior must never relax security (a revoked restriction stays revoked offline) and offline states must remain legible (the M1–M3 vocabulary `noDevicesLinked`, `syncUnavailable`, `screenTimeUnavailable` extends to every new domain).

## 14. Reliability Model

Reliability is layered: **transactional reliability** (SQLite FK transactions, outbox idempotency, cumulative usage upserts — verified), **retry reliability** (backoff/max-attempt policies — verified at domain level), **process resilience** (durable state reloads on re-entry — verified locally; process death recovery — documented pattern, not yet background-verified), and **environmental resilience** (reboot, Doze, force-stop, network chaos — explicitly **not implemented**; Android provides no claimed guarantees until the M8 background design is evidenced on physical devices). The reliability model therefore distinguishes what the codebase *proves* (transactions, idempotency, retries) from what it *disclaims* (background survival), and the roadmap never lets the second category masquerade as the first.

## 15. Android Capability Model

Android capability is the scarcest strategic resource and is modeled as a capability ladder, not a binary: each capability (`notifications`, `location`, `microphone`, `usageStats`, `accessibility`, `overlay`, `screenCapture`) reports `supported / granted / requiresSettings / notGranted` through `CapabilityGateway` without ever claiming a grant it does not hold. Three structural facts bound the product: Android provides **no universal app-blocking API** for ordinary consumer apps — any enforcement path (UsageStats observation, foreground service, WorkManager, possibly Device Owner) requires explicit legitimacy review and physical-device evidence; **background survival** (reboot/Doze) requires new native design the repository explicitly disclaims; and **platform-specific boundaries** (MediaProjection consent for mirroring, accessibility-service consent, overlay consent) are never silently enabled. The applied-status vocabulary (`notRequested → evaluated → enforcementRequested → enforcementApplied`) is the product's signature: competitors report "blocked" liberally; Guardian Eye Pro reports only what the operating system has actually applied.

---

## 16. Competitive Analysis

| Dimension | Google Family Link [1] | Qustodio [2] [3] | Bark [4] [5] | Guardian Eye Pro |
|---|---|---|---|---|
| Price | Free | Free / $54.95–59.95/yr (5 devices) / $99.95/yr (unlimited) | $99/yr Android, $148/yr iOS, hardware tiers | One family subscription, whole family, $49–99/yr planned |
| Screen time | Daily limits, School Time/Downtime, per-app limits, blocking | Time limits, scheduled breaks, pauses, routines | Limits, scheduling, app/site blocking | Same breadth (M6–M8), plus offline enforcement honesty |
| Content safety | Filters on Google services only | Web/app filtering, social monitoring, call/message tracking | AI content scanning (texts/email/social/web) | Local policy pipeline (M8); on-device AI alerts (M10) |
| Location | Live map, geofence arrival/leave, ring device | Family locator, geofences | Live GPS, check-ins, alerts | Deferred (M12); consent-minimized by design |
| Family structure | Two-parent groups | Family groups | One subscription unlimited kids | Explicit multi-parent roles + invitations (M5) |
| Offline behavior | Cloud-dependent | Cloud-dependent | Cloud-dependent (Sync hardware for iOS) | Offline-first canonical (architectural differentiator) |
| Arabic/RTL | Yes (supported language) | Limited | No | **Arabic-first, RTL-native** |
| MENA presence | Global | Global, limited Arabic depth | **US/SA/AU only** | **Regional-first strategy** |
| AI positioning | None | Basic AI alerts (Complete) | Core AI identity | AI as internal capability, never overclaimed |
| Local payments | Google Play only | Google Play / Stripe | Stripe (US-centric) | Haseb / Jawal Pay / OneCash planned (M16) |

**What users already have:** a free baseline (Family Link) covering time limits and content filters on Google services, and well-funded cloud monitoring (Bark, Qustodio) covering content scanning at subscription prices. **What competitors do well:** Family Link's OS-level integration and friction-free onboarding; Qustodio's reporting breadth; Bark's AI alert sensitivity. **What Guardian Eye Pro must match:** family onboarding speed, screen-time limit breadth, incident alerts, and report cadence — these are table stakes, not differentiators. **What it cannot pretend to match** in year one: years of tuned content-classification data (Bark's model maturity) or OS-level account control (Family Link's Google-account authority). Those are matched through *different mechanisms* — on-device classification that improves per family without cloud exposure, and honesty-based enforcement that preserves trust — rather than head-on.

## 17. Differentiation

**Table stakes** (must have): family onboarding flow, screen-time limits and schedules, app awareness, safety alerts, reports, location basics — delivered through M4–M11. **Differentiators** (meaningful separation): first, **Arabic-first with genuine RTL experience** — competitors localize labels; Guardian Eye Pro designs the whole information architecture around Arabic, and this maps to a market where Bark is absent entirely [5] and the MEA parental-control market is projected to grow from $146M (2025) toward $413M by 2033 [6]; second, **offline-first reliability** — every competitor surface degrades without connectivity, while Guardian Eye Pro's local canonical store keeps policy enforcement and safety states truthful offline, an advantage that compounds in weak-connectivity regions; third, the **honesty-based enforcement vocabulary** — the market trains users to distrust apps that claim "blocked" while meaning "requested"; reporting only applied enforcement builds a trust brand competitors cannot imitate without rebuilding cloud-dependent architectures. **Long-term moat:** the family-graph data asset (multi-parent cohesion, child lifecycle history, exception-request conversation patterns, longitudinal reports) accrued per family — switching costs that grow with family tenure — combined with on-device AI that improves with local evidence while keeping cloud costs near zero, giving the product a structural margin advantage over cloud-scanning competitors.

## 18. Business Model

The model is a **single family subscription** (Bark-pattern: one subscription covers every child and device, unlike Qustodio's per-device pricing [2]), with three tiers planned: **Free** (family creation, one child context, offline reading — activation engine, no enforcement), **Standard** (screen-time administration and measurement, alerts, one-child household), and **Premium** (enforcement, AI alerts, reports, multi-child, multi-parent collaboration, SOS history). Free-to-premium conversion is triggered by capability events the roadmap deliberately sequences: enforcement activation (M8), first AI alert (M10), first weekly report (M11). Local payment corridors (Haseb, Jawal Pay, OneCash) remove the most common MENA purchase failure mode — lack of international cards — and are introduced only after the entitlement backbone exists (M16). Pricing reference points are market-proven: $49/year Standard and $99/year Premium align with Qustodio Basic/Complete band [3] and under Bark's $99 [4], justified by whole-family coverage and regional payment convenience. Infrastructure economics favor the model structurally: offline-first writes and on-device AI keep per-family cloud cost a fraction of cloud-monitoring competitors' costs.

## 19. $600k / 2028 Model

The target is **$600,000 annual revenue by end of 2028**, modeled transparently. All figures below are planning assumptions, not forecasts.

| Scenario | Paying Families (2028) | Blended ARPU/yr | Annual Revenue | Key Assumptions |
|---|---|---|---|---|
| Conservative | 3,500 | $40 (free-heavy mix, regional pricing) | $140,000 | Slow regional adoption; premium conversion < 5% of onboarded families |
| **Base** | **8,000** | **$75** (≈ 60% Standard $49 + 40% Premium $99) | **$600,000** | MVP released by mid-2027; 40k installs; ~20% family activation; ~20% of activated families convert within 12 months; annual churn ≤ 25% |
| Aggressive | 14,000 | $85 (early Premium skew + school/organization licenses) | $1,190,000 | Arabic-market first-mover advantage; local payment corridors unlock cardless households; B2B2C education pilots |

The funnel that makes the base scenario self-consistent: installs → family creation (M2 shell quality) → **child device linking, the decisive activation gate (M4)** → daily engagement (dashboard, M2/M3) → premium conversion triggered by enforcement and reports (M8–M11) → retention via reports and multi-child expansion. The capabilities that matter most commercially are therefore, in order: **M4 (activation), M8 (conversion), M11 (retention), M5 (multi-parent expansion), M16 (payment friction removal)**. The honest caveat: none of these numbers is a forecast; they are constraints that tell the roadmap which capabilities are business-critical and which are optional.

## 20. MVP Definition

The **Guardian Eye Pro MVP** is the smallest release that is a credible family safety product rather than a collection of screens. **Must-have capabilities:** family creation and identity, honest multi-parent display, child profiles, child-device linking (pairing issue + redemption + lifecycle), screen-time administration and *measurement*, safety signal display with real incidents, exception-request conversation, SOS send with honest queued/offline states, and an AR+EN RTL-native parent dashboard. **Must-have platform:** SQLite canonical store, idempotent outbox, fail-closed actor binding, single permission matrix, capability ladder. **Minimum security bar:** server-denied child writes and cross-family writes (emulator-evidenced rules), no fabricated states anywhere. **Minimum Android enforcement:** an honestly-labeled usage-observation path on a physical device (M7 evidence protocol); blocking enforcement may ship as "advisory + schedule guidance" if system enforcement fails legitimacy review, but never as a false claim. **Minimum offline behavior:** every MVP surface usable and truthful offline. **Minimum UX quality:** Shneiderman-consistent, pull-to-refresh/retry everywhere, zero dead routes. **Minimum supportability:** crash reporting, observable sync states, localization-complete AR+EN. **Explicitly NOT MVP:** location/geofencing, web filtering, chat/audio/mirroring, Couple Harmony authority, AI monitoring, SMS SOS fallback, subscription UI, local payments, ownership transfer, family deletion.

---

## 21. Production Definition

"Production Ready" for Guardian Eye Pro means the product satisfies all fifteen dimensions below — no dimension may be claimed by the others. Functionality means each capability performs end-to-end on a real device; UX means the Design Constitution is verified per screen; reliability means the offline and outbox paths are exercised on device; security means the server authoritatively rejects every forbidden write; privacy means consent and data-minimization flows exist; Android enforcement means system-applied states have physical-device evidence; offline behavior means full function across connectivity transitions; lifecycle resilience means process death, reboot, and Doze have evidence; testing means the full suite (unit + widget + emulator + physical) passes with no weakened assertions; observability means crashes and sync anomalies surface; crash handling means no user-visible crashes in evidence; localization means AR+EN complete with RTL layout verified; performance means cold start and screen transitions within budget on mid-tier Android; release readiness means store listing, entitlements, and rollback plan; and monetization means entitlement verification works in a live sandbox. Production is declared only when evidence covers every dimension, never when tests alone pass.

## 22. Capability Maturity Matrix

Maturity levels: NOT STARTED / PLANNED / UI ONLY / PARTIAL / DOMAIN READY / BACKEND READY / ANDROID READY / OFFLINE READY / SECURITY VERIFIED / TEST VERIFIED / PRODUCTION READY. Verified against the current repository; nothing is asserted without repository or documented evidence.

| Domain | Capability | Current Reality | Maturity | Missing Pieces | Priority |
|---|---|---|---|---|---|
| Family | Family creation & identity | Implemented domain + repository; UI partial | DOMAIN READY / OFFLINE READY | Full UI flow, M5 | Critical |
| Family | Membership invitations (owner→parent) | Repository complete; UI pending | BACKEND READY | Redemption UI, FCM invitation path | Critical |
| Family | Multiple parents/roles | Matrix implemented; roles displayed | DOMAIN READY | Role promotion UI, governance | High |
| Family | Member removal / revocation | Repository complete (owner-gated) | BACKEND READY | UI, audit trail | High |
| Family | Family deletion / ownership transfer | Not implemented | PLANNED | M17 | Deferred |
| Child | Child profile & context | M3 GREEN (provider + screen + tests) | TEST VERIFIED / OFFLINE READY | Production polish | Critical |
| Child | Child device relationship | Member↔device binding implemented | DOMAIN READY | Device list UI | Critical |
| Child | Child removal / reassignment | Not implemented | PLANNED | M17 | Deferred |
| Device | Pairing code issuance | GREEN (SHA-256, lockout, once-only) | TEST VERIFIED | Physical-device verification | Critical |
| Device | Pairing redemption (child device) | Repository complete; UI not built | BACKEND READY | M4 redemption flow | Critical |
| Device | Unlinking / replacement | Revocation + re-enrollment implemented | DOMAIN READY | UI, migration path | High |
| Device | Permission ladder verification | Contract implemented | DOMAIN READY | Physical-device evidence | High |
| Controls | Screen-time policy creation/admin | Local admin GREEN | TEST VERIFIED / OFFLINE READY | Synced admin | Critical |
| Controls | Screen-time measurement | Usage capture domain + daily summaries | DOMAIN READY / OFFLINE READY | UsageStats physical evidence (M7) | Critical |
| Controls | Screen-time enforcement | Domain contract; adapter disclaims system blocking | PLANNED / PARTIAL | M8 legitimacy review + evidence | Critical |
| Controls | Bedtime / schedules | Within policy domain (schedules) | DOMAIN READY | Dedicated UX | High |
| Controls | Web filtering | Not started | NOT STARTED | Research + consent design | Low |
| Controls | Location / geofencing | Not started | NOT STARTED | M12 | Deferred |
| Safety | Incident pipeline (local) | Observation→classification→incident→ack GREEN | TEST VERIFIED | Production severity UX | Critical |
| Safety | On-device AI classification | Fail-closed adapter GREEN; model blocked | PLANNED | Model review + artifact | High |
| Safety | SOS online/local | GREEN (queue, retry, acknowledgement) | TEST VERIFIED / OFFLINE READY | Server endpoint | Critical |
| Safety | SMS fallback | Not started | NOT STARTED | Physical evidence + consent | Low |
| Safety | Location sharing (SOS) | Not started | NOT STARTED | M12 | Deferred |
| Comm | Chat / audio / mirroring | Table stub | UI ONLY | Privacy review | Deferred |
| Intelligence | AI infrastructure | RiskEngine fail-closed GREEN | SECURITY VERIFIED | — | Done |
| Intelligence | Parent-facing reports | Daily totals; no report engine | PARTIAL | M11 engine | High |
| Reliability | SQLite canonical store | GREEN | TEST VERIFIED / OFFLINE READY | — | Done |
| Reliability | Outbox + retries | GREEN (idempotency, backoff) | TEST VERIFIED | Remote writer config | High |
| Reliability | Sync/conflict handling | Server-authoritative design; writer unconfigured | PLANNED | M9 promotion | High |
| Reliability | Reboot / Doze / process-death background | Documented pattern, NOT implemented | PLANNED | Physical evidence (M8+) | High |
| Security | Actor binding / permission matrix | 14/14 regression GREEN | SECURITY VERIFIED | Live server proof (M9) | Done |
| Security | Data deletion / consent / retention | Not implemented | NOT STARTED | M17 / M9 | High |
| Commercial | Subscription tiers | Not started | NOT STARTED | M15/M16 | High |
| Commercial | Local payments (Haseb/Jawal Pay/OneCash) | Not started | NOT STARTED | M16 | Medium |

## 23. Dependency Graph

Derived from repository dependency relationships (not assumed): `FamilyRuntimeContext ← ActorBinding ← Membership ← Family`. Capability dependencies, in topological order with prerequisites, blockers, and parallelizable work:

```text
[FAMILY INFRASTRUCTURE]
  Family creation/identity ──────┐
  Membership & invitations ──────┤── prerequisite for EVERYTHING
  Actor binding (Phase 17) ──────┘
        │
        ▼
[DEVICE LINKING] ← prerequisite for: all device-dependent capabilities
  Pairing issuance (GREEN) → Redemption UI (M4) → Lifecycle honesty → Device ladder
        │
        ├──▶ SCREEN-TIME VERTICAL ─────────────────────┐
        │   M6 Admin (UI, GREEN locally)               │
        │   M7 Measurement (UsageStats physical ev.)   │──▶ M8 Enforcement
        │   └──▶ M8 Enforcement (legitimacy review)    │      (applied-status)
        └──────────────────────────────────────────────┘
        │
        ▼
[PRODUCTION PROMOTION — M9]
  Remote outbox writer │ Firestore rules prod │ entitlement spine │ observability
        │
        ▼
[INTELLIGENCE — M10/M11]  (needs: incidents pipeline + reports engine + enforcement data)
  On-device AI alerts ← model review ← classification ← reporting
        │
        ▼
[EXPANSION — M12/M13/M14]
  Location/geofencing │ Couple Harmony authority │ Communication (chat/audio/mirror)
        │
        ▼
[COMMERCIAL — M15/M16]
  Entitlement verification │ Subscription UI │ Local payment corridors
        │
        ▼
[GOVERNANCE — M17]
  Family deletion │ ownership transfer │ consent/retention │ child removal
```

**Critical path:** M4 (linking) → M6/M7/M8 (screen-time vertical) → M9 (production) — this path is the only sequence that converts the existing GREEN foundations into a shippable product; every other vertical branches off it in parallel where evidence permits. **Blockers:** Android system-blocking legitimacy review (blocks honest enforcement claims), AI model review (blocks intelligence), reboot/Doze physical evidence (blocks resilience claims). **Parallelizable:** M5 (family management UI) runs parallel to M4; M12 (location) and M11 (reports) can run in parallel after M9; local payments research can start during M9–M14.

## 24. Canonical Roadmap

One authoritative sequence, derived from the dependency graph. Milestone definitions (ID, objective, dependencies, in/out scope, requirements, gates, evidence) are in the companion document `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md`; this section is the sequence and its rationale:

| # | Milestone | Product Outcome | Architecture Outcome | Depends On |
|---|---|---|---|---|
| M4 | Device Linking & Child Device Onboarding | Parent issues code, child device enrolled, honest device states | Redemption flow, lifecycle UI, device ladder | M3, Phase 17 binding |
| M5 | Family Management Vertical | Create/join family, invitations accepted, roles visible | Membership UI, invitation redemption, multi-parent display | M4 parallel |
| M6 | Screen-Time Administration | Limit creation/edit/archive for a child's device | Policy admin surfaces over GREEN local engine | M4 |
| M7 | Screen-Time Measurement | Real usage data, daily totals, honest gaps | UsageStats physical evidence on device | M4, Phase 14 pattern |
| M8 | Screen-Time Enforcement | Honestly-labeled enforcement (advisory→applied) | Legitimacy-reviewed enforcement path, applied-status evidence | M6, M7 |
| M9 | Production Promotion | Production-synced family data, entitlement spine, observability | Remote outbox writer, prod rules, crash/telemetry | M5–M8 core |
| M10 | On-Device AI Safety Alerts | AI-flagged incidents with model traceability | Model-reviewed classification layer over GREEN pipeline | M8, M9 |
| M11 | Family Reports | Daily/weekly activity and safety reports | Report engine over usage + incident data | M10, M9 |
| M12 | Location & Safety Expansion | Consent-minimized location, geofence alerts, couple authority | Location capability ladder, couple role promotion | M9 |
| M13 | Resilience Hardening | Reboot/Doze/background evidence | Physical-device resilience program | M8, M9 |
| M14 | Family Communication | Parent-child chat, SOS escalation channels | Privacy-reviewed communication layer | M9, M10 |
| M15 | Premium Structure | Subscription tiers, entitlement verification live | Entitlement spine, server-verified premium gates | M9 |
| M16 | Regional Payments | Haseb/Jawal Pay/OneCash for the target market | Payment gateway integration | M15 |
| M17 | Family Governance | Deletion, transfer, consent, retention, audit | Governance repository and flows | M12, M15 |

The sequence obeys the roadmap principle: architectural correctness, security, real Android capability, offline reliability, product value, retention, commercial viability, testability, and differentiation — never screen count, feature count, or visual completeness.

## 25. Critical Path

The critical path is **M4 → (M5 parallel) → M6 → M7 → M8 → M9 → M11**. Its logic is unambiguous: every post-M3 capability either requires a linked device (controls, measurement, enforcement, AI signals about the child's device) or a real family (communication, reports, commercial), and M4 is the only milestone that closes the linking gap. M3's screens display seeded/empty data until a real device exists; the pairing repository is already GREEN, so M4 is the shortest possible step to a materially more valuable product. M9 gates all cloud-dependent verticals (reports aggregation, entitlements, live AI alert delivery); M11 is the retention engine the revenue model depends on. **What must be completed before M4 starts:** nothing beyond the existing M3 checkpoint — the prerequisite evidence (binding tests, pairing lifecycle tests, emulator suite) is already GREEN. **Why M4 is next:** (1) `ChildDeviceRepository.deliverPolicy` rejects unenrolled devices — the entire screen-time capital cannot begin before linking; (2) M2/M3 surfaces remain unvalidated by real data until a device exists; (3) linking is the funnel's activation gate in the revenue model; (4) the pairing core is the most complete unshipped asset in the repository.

## 26. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Android system-blocking remains illegitimate/unavailable for consumer apps | High | High (M8 conversion trigger) | Honest advisory mode; legitimacy review gate; never claim `applied` |
| Reboot/Doze background survival fails physical evidence | High | Medium (reliability claims) | M13 program; document disclaimers until evidenced |
| AI model review delayed or fails | Medium | High (M10/M11 delays) | Fail-closed infrastructure preserves pipeline; roadmap doesn't stall |
| MENA adoption slower than base scenario | Medium | High ($600k target) | Conservative scenario accepted as possible outcome; regional payments accelerate conversion |
| Google policy/action on usage-stats based products | Low-Medium | High | Consent-first design; honest vocabulary; monitor platform policy |
| Competitor enters Arabic-first segment (e.g., Kahf Kids adjacent) | Medium | Medium | Speed-to-MVP; trust brand; family-graph moat |
| Remote sync conflicts in multi-parent writes | Medium | Medium | Server-authoritative design; idempotency keys; conflict tests before M9 |
| Payment corridors unreliable or blocked by platform stores | Medium | Medium | Store-first entitlements; local payments as supplement (M16) |

## 27. Technical Debt

The repository's debt inventory is small and deliberate. First, `family_entity.dart` is a legacy entity superseded by the Phase 17/18 canonical models and should be retired when family UI work touches that file. Second, the remote outbox writer is unconfigured (`UnconfiguredOutboxRemoteWriter`) — intentional until M9, but every screen built before M9 must render queued states honestly rather than assuming sync. Third, the seven-action M2 dashboard does not perfectly map the six parent questions identified by the UX reconciliation — acceptable at M2's foundation stage, but the dashboard restructure belongs to M6–M8. Fourth, several "NOT IMPLEMENTED" capability gates (blocking, accessibility, overlay, location) carry truthful disclaimers; they are not debt until a roadmap milestone requires them. Fifth, Android Gradle and native toolchain artifacts accumulated across environment changes; they are stable now but deserve a documented baseline check before M9's release engineering. None of this debt blocks M4–M6.

## 28. Deferred Features

Explicitly deferred, with placement: web filtering (NOT STARTED; post-M12 after consent design), SMS SOS fallback (NOT STARTED; physical-evidence requirement; M12+), location sharing within SOS (M12), geofencing (M12), chat/audio/screen-mirroring (M14, after privacy review — high sensitivity, no early milestone), Couple Harmony authority promotion (M12 — spouse role intentionally authority-empty today), ownership transfer and family deletion (M17), child removal/reassignment (M17), consent/retention/audit (M9 consent-minimal + M17 full), local payments (M16), and enterprise/education editions (post-M17, explicitly provisioned-only). Each deferral is deliberate: the feature either lacks a trust/consent foundation (communication, filtering), a platform foundation (SMS, location), or a business trigger (commercial) — none is abandoned.

## 29. Roadmap Change Control

After approval of this blueprint, roadmap changes follow a gated process: **New discovery → Impact analysis → Dependency analysis → Business impact → Security impact → Roadmap Change Request → Approval → Roadmap update.** Milestones are not spontaneously reordered during implementation. Changes require an evidence-based request, an analysis of which gates, dependencies, and revenue-model assumptions are affected, explicit approval recorded in the Decision Log (Section 30), and a single updated `GUARDIAN_EYE_CANONICAL_ROADMAP.md` commit so that one canonical source always exists.

## 30. Decision Log

| Date | Decision | Rationale | Status |
|---|---|---|---|
| 2026-08 | M1–M3 declared GREEN historical checkpoints | Evidence: 109/109 tests, 0 analyze issues, emulator GREEN | Approved |
| 2026-08 | Product identity: human-engineered, AI-powered, family-first | AI overclaim is a trust and differentiation risk | Approved |
| 2026-08 | Single-family subscription model (Bark-pattern) over per-device | Family-unit value; multi-child expansion revenue lever | Approved |
| 2026-08 | Honesty-based enforcement vocabulary is product signature | Competitors cannot copy without architectural rewrite | Approved |
| 2026-08 | M4 Device Linking next; M5 parallel | Dependency graph + activation gate + most complete unshipped asset | Approved |
| 2026-08 | Child is one member record; multi-parent via invitations | One Child → Many Parents without duplication or inconsistent auth | Approved |
| 2026-08 | Communication (chat/audio/mirror) deferred to M14 | Privacy/consent foundation required first | Approved |
| 2026-08 | AI monitoring gated by model review; fail-closed until then | Security law: no unverified classification in production | Approved |

---

## References

**Repository (internal evidence):**
- [A] `docs/GUARDIAN_EYE_CANONICAL_ROADMAP.md` — canonical milestone definitions M4–M17
- [B] `docs/UX_SPRINT_01_M1_COMPLETION_REPORT.md`, [C] `docs/UX_SPRINT_01_M2_COMPLETION_REPORT.md`, [D] `docs/UX_SPRINT_01_M3_COMPLETION_REPORT.md`
- [E] `docs/PHASE_17_ARCHITECTURE.md` / `docs/PHASE_17_STABLE_CHECKPOINT.md` / `docs/PHASE_17_CLOSURE_REPORT.md` — security baseline
- [F] `docs/phases/PHASE_18_ARCHITECTURE.md` / `docs/phases/PHASE_18_COMPLETION_REPORT.md` — family runtime context
- [G] `docs/PHASE_13_FEATURE_MATRIX.md`, [H] `docs/PHASE_14_ARCHITECTURE.md`, [I] `docs/PHASE_15_ARCHITECTURE.md`, [J] `docs/PHASE_16_BASELINE.md`
- [K] `docs/ANDROID_ENFORCEMENT_CAPABILITIES.md`, [L] `docs/ANDROID_ENFORCEMENT_RESEARCH.md`, [M] `docs/ANDROID_PERMISSION_MODEL.md`
- [N] `docs/COMPETITIVE_PRODUCT_BASELINE.md`, [O] `docs/UX_SPRINT_01_V2_RECONCILIATION.md`
- [P] Implementation: `lib/domain/`, `lib/data/` (membership, pairing, policy, outbox, safety repos), `lib/application/`, `lib/presentation/`

**External (competitive and market):**
- [1] Google Family Link — [families.google/familylink](https://families.google/familylink/)
- [2] Qustodio features & pricing — [qustodio.com](https://www.qustodio.com/en/) and [qustodio.com/en/premium](https://www.qustodio.com/en/premium/)
- [3] Qustodio plan pricing 2026 — [safewise.com review](https://www.safewise.com/kids-safety/parental-control-apps/qustodio/)
- [4] Bark app pricing — [bark.us/pricing](https://www.bark.us/pricing)
- [5] Bark regional availability (US/SA/AU only) — [bark.us](https://www.bark.us/)
- [6] MEA Parental Control Software Market ($146.19M 2025 → $412.66M 2033) — [Databridge Market Research](https://www.databridgemarketresearch.com/reports/middle-east-and-africa-parental-control-software-market)
- [7] Shneiderman, B. — *Designing the User Interface* (Eight Golden Rules)
- [8] Android DevicePolicyManager — [developer.android.com](https://developer.android.com/reference/android/app/admin/DevicePolicyManager)

---

**END OF MASTER PRODUCT BLUEPRINT** — Approved baseline. Any future change must pass the change-control process in Section 29 and be recorded in Section 30.
