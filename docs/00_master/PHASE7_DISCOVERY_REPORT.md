# Phase 7 Discovery Report — FS-014 & FS-016 (Read-Only Audit)

**Status of this document:** READ-ONLY DISCOVERY. No code was written, no files were modified, no commit was created, nothing was pushed, and nothing was deployed during this audit. The repository remains exactly as of commit `18ec4fa` (HEAD of `feature/design-system-integration`), with the pushed checkpoint at `3bc6321`.

**Audit basis.** The repository was inspected file-by-file against the two authoritative planning documents, `MASTER_DEVELOPMENT_PLAN.md` (FS-014 at section 6.14, FS-016 at section 6.16, phase ordering at the Phase 7 row) and `MASTER_SCREEN_INDEX.md` (sections N and P), and against the actual code on `feature/design-system-integration`. All claims below are anchored to the files listed in the evidence paths, and the regression baseline of **510/510 Flutter tests green** and **34/34 backend tests** was confirmed unchanged — no test was run or altered during this audit; the last verified green run is the one committed with FS-010 (`0642365`).

---

# Part A — FS-014: Primary Parent Dashboard & Unlinked Device (7 screens)

## A.1 Feature definition and acceptance surface

FS-014 is defined in the master plan as *"the first-run and aggregate experiences: unlinked entry, family creation/join, authentication confirmation, and the post-capability primary dashboard aggregating all subsystems."* It closes the largest remaining first-run gap in the product: today a newly signed-in user with no family membership lands on the family dashboard and sees only a bare create-family form (`_FamilySetup`), with **no way to join an existing family, no authentication confirmation step, no family identity surface, and no activation funnel**.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| PD-001 | Unlinked Entry | `/` (no membership) | Landing for signed-in but unlinked users | Existing `_FamilySetup` upgraded + clear create/join dual CTA | unauthenticated-family |
| PD-002 | Create Family | `/family/create` | Name, invite first parent, first child | Form sections; honest validation errors | account holder |
| PD-003 | Join Existing Family | `/family/join/:invitationCode` | Accept invitation code flow | Code entry + confirmation | account holder |
| PD-004 | Parent Authentication | `/auth/confirm` | Re-auth confirmation for sensitive operations | Confirmation card + OTP/biometric ladder hooks | account holder |
| PD-005 | Primary Parent Dashboard | `/` (post-capability) | Aggregates: family overview, safety center, location overview, geofence overview, SOS overview | Hero + subsystem overview `GuardianCard`s, each tapping into its subsystem dashboard | parent/owner |
| PD-006 | Family Profile | `/family/:familyId/profile` | Family identity: name, members summary, created date | Profile `GuardianCard` stack | member |
| PD-007 | Setup Checklist | `/family/:familyId/setup` | Guided activation: device linked → first policy → SOS configured | Checklist hero + per-step CTAs with honest progress | parent/owner |

The plan also states that PD-006 "provides the family identity surface (name, members, founded date) every aggregate dashboard presupposes" and that PD-007 "is the activation funnel — an honest setup checklist whose completion directly determines first-week retention."

**Acceptance criteria (plan-derived).** PD-001 must show a genuine dual path (create or join) for any authenticated account with no family membership, never a false-success state. PD-002 must create the family, the primary-parent membership, and the outbox entry atomically, with honest validation errors surfaced before any write. PD-003 must accept an invitation code and materialize the membership with honest expiration handling. PD-004 must gate sensitive operations behind re-authentication with provider ladder hooks. PD-005 must aggregate every implemented subsystem (safety center, location, geofence, SOS, chat, couple harmony, tasks, rewards) behind `FamilyRuntimeContext.can()`. PD-006 must render family identity and a members summary any member can view. PD-007 must show honest per-step progress driven by real state, not stored fiction.

## A.2 Existing code inventory — what is already built

Discovery confirms that FS-014 is **not greenfield**. The following foundations exist, are code-verified, and ship with the FS-010 baseline at 510/510 tests green.

| Building block | Location | What it provides today |
| --- | --- | --- |
| `_FamilySetup` widget | `lib/presentation/screens/dashboard_screen.dart` (lines 44–140) | The PD-001 seed: shown when `data.family == null`, collects family name + parent name, calls `familyRepositoryProvider.createFamily()`. Single-path today — no join CTA. |
| `FamilyRepository.createFamily` | `lib/data/guardian_repositories.dart` | Atomic transaction: inserts `families` row, primary-parent `family_members` row, and a `family.created` outbox entry. The PD-002 write-path already exists verbatim. |
| `FamilyMembershipRepository` | `lib/data/family_membership_repository.dart` | Full invitation lifecycle: `inviteAdult` (creates `family_invitations` + outbox), `acceptInvitation`, `cancelInvitation`, `revokeMember`, `updateAdultRole`, `expireDue`, `bindVerifiedAccount`, plus owner-gate helpers (`requireOwner`). |
| `FamilyRole` / `FamilyMemberStatus` | `lib/domain/guardian_models.dart` | Roles `primaryParent / parent / coParent / spouse / child`; statuses `invited / active / revoked / expired` — the PD-005/PD-007 authorization vocabulary. |
| `FamilyAuthorization` | `lib/domain/family_authorization.dart` | Canonical role-permission matrix; `FamilyRuntimeContext.can(FamilyPermission.xxx)` is the mandated authorization mechanism, never local role checks. |
| `familyActorBindingServiceProvider` | `lib/application/guardian_providers.dart` | Resolves the authenticated account to a family membership (real Firestore reader or honest `_UnavailableFamilyMembershipRemoteReader` when Firebase is not ready). |
| Firestore contracts | `lib/data/firestore_contracts.dart` | `families/$familyId`, `members`, `children`, `devices`, `device_pairings`, `policies` paths all exist — the remote sync surface PD-002/PD-006 need is already contracted. |
| Firebase Auth | `lib/data/firebase_auth_context.dart` + `FirebaseSessionScreen` | Real Firebase Auth: `signInWithEmail`, `createAccount`, `signInAnonymously`, `signOut`; `AuthSession` stream of status `unconfigured / authenticated / none`. `bindVerifiedAccount` links an account to a membership. |
| Outbox sync | `syncCoordinatorCoreProvider` | All family writes flow through the single-flight sync coordinator — local-first semantics the FS-014 screens must preserve. |
| Design primitives | design-system layer | `GuardianCard`, `GuardianHeroCard`, `GuardianStateView`, `GuardianStatusChip`, `GuardianBottomNav`, navy #0F2A5B / teal #00B8A9, Cairo typeface, rounded-16 — PD-005/PD-006/PD-007 compositions reuse these. |
| l10n | `lib/core/localization` (AR + EN) | `createFamily` and adjacent family keys exist; FS-014 will extend the maps for join/re-auth/profile/checklist copy. |

## A.3 Authentication and family-membership lifecycle behavior

The auth-to-membership contract works as follows, and FS-014 must extend it without breaking it. An account signs in via `FirebaseSessionScreen` (email/password or anonymous session). An anonymous session is explicitly honest about its limits — the screen itself states that a temporary session "does not represent a parent account and grants no family membership or permissions." `bindVerifiedAccount` then links the verified account to an existing membership row, and `familyActorBindingProvider(familyId)` resolves the binding for runtime authorization. Invitations are created by an owner with `inviteAdult(targetEmail)`, which writes a `family_invitations` row plus an outbox event; acceptance today is **by invitation UUID** (`acceptInvitation(invitationId: …)`), with honest handling for already-accepted, expired, and revoked cases.

This lifecycle gives FS-014 its two honest pathways — **create** (owner creates family + primary-parent membership + outbox) and **join** (invitee accepts an invitation) — and explains the single material contract gap identified in Section A.7.

## A.4 Authorization rules for FS-014

Every FS-014 screen's auth column in the master plan maps cleanly onto the existing model. `account holder` screens (PD-002, PD-003, PD-004) need a bound, verified membership (`isVerified`); PD-006 is open to any `member`; PD-001 is the unlinked entry state; PD-005 and PD-007 require `parent/owner`, i.e., roles that `FamilyAuthorization` grants aggregate permissions to, checked through `FamilyRuntimeContext.can()` — exactly how the post-FS-010 dashboard already guards `viewChat` and other permissions. The verification-warning card already shown on the current dashboard (`actorVerificationRequired`) proves the honest-unverified state pattern FS-014 must keep.

## A.5 Existing l10n, RTL, design primitives, and settings entry points

The app is bilingual (AR RTL + EN) with the `l10n.t('key')` pattern enforced across screens; FS-014 must add all new keys in both maps simultaneously. The design system is mature enough that PD-005/PD-006/PD-007 are composition work, not new widgets: hero card, subsystem `GuardianCard` grid, profile card stack, checklist hero with per-step CTAs. Settings (`/settings`, `settings_screen.dart`) currently exposes privacy and export tiles but **no family-profile tile** — one is needed as the PD-006/PD-007 entry point, which is a small additive change, not a rewrite.

## A.6 Existing onboarding, invite, join, and family-creation flows

Today's first-run flow is one path: no family → `_FamilySetup` form → `createFamily()` → dashboard. The invite side exists server-side-wise (`inviteAdult` + outbox) but has **no public acceptance surface** — a user who receives an invitation has nowhere in the app to act on it, which is precisely what PD-003 must build. There is no re-authentication surface at all (PD-004), no family profile route (PD-006), and no activation checklist (PD-007). The child landing routes (`/child/:familyId/:childId`, `/child/:familyId/:childId/policies`, `/child/:familyId/:childId/device`) and the couple harmony route (`/couple/:familyId/role`) already provide role-specific landings that PD-005's aggregate must coexist with.

## A.7 Required local and remote contracts — the identified gaps

The audit identified **one hard contract gap** and **four additive gaps**:

| Gap | Nature | Detail |
| --- | --- | --- |
| **PD-003 join-by-code (hard)** | New local contract | `acceptInvitation` today takes `invitationId` (a UUID). The plan's PD-003 route `/family/join/:invitationCode` implies a **human-readable invitation code**. `family_invitations` has no `code` column, no code generator, and no code lookup. This requires a schema migration (v31 candidate: add `code TEXT`, plus a code-generation convention), a lookup method on `FamilyMembershipRepository`, an expiration-aware accept path, and matching AR/EN keys. The outbox mechanism already covers remote sync once the local write is added — no Render endpoint is strictly required, though a server-side code-resolution hook could be added later as an optional enrichment. |
| PD-004 re-auth (additive) | New screen + hooks | No `/auth/confirm` exists. The surface needs a confirmation card plus provider hooks for an OTP/biometric ladder; the plan marks the ladder as "hooks," so the milestone ships the card and the hook points, not the ladder implementation. |
| PD-006 profile (additive) | New route + settings tile | No `/family/:familyId/profile` route exists. `FamilyMembersScreen` (`/family/:familyId`) covers member listing, so PD-006 reuses that data and adds the identity surface (name, members summary, created date) plus a settings entry tile. |
| PD-007 checklist (additive) | New route + persistence | No setup-checklist persistence exists today. `app_identity` (key/value, SQLite) is available but unused for this; the checklist needs either `app_identity` keys or a dedicated `setup_progress` mechanism, plus honest progress computed from real state (`childDeviceStatesProvider`, policy existence, SOS configuration) — never stored fiction. |
| PD-001 dual CTA (additive) | Widget upgrade | `_FamilySetup` becomes a dual create/join entry; no new contract beyond PD-003's lookup. |

**Backend dependency verdict:** FS-014 is predominantly **local-first**. Every new write (family, member, invitation accept) already has an outbox route through the existing sync coordinator and Firestore contracts; no Render API changes are strictly required for code-verification closure. Only the optional server-side code-resolution hook would touch the backend, and it is not a Phase-7 prerequisite.

## A.8 Privacy and deletion implications

New FS-014 data lands in `families`, `family_members`, and `family_invitations` — all of which are **retained tables** (not in `purgedTables`), consistent with the privacy architecture: family identity survives local privacy purge, and family deletion carries its members, children, devices, and invitations with it per the Phase 4C/4D contracts. FS-014 must therefore add nothing to the purge/export forbidden-key scanner except, at most, checklist-progress keys (which are non-sensitive local state). PD-004 re-auth is privacy-protective by design (it strengthens the sensitive-operation gate). The export service (`family_data_export_service.dart`) already forbids sensitive keys; family profile summary data (name, members, created date) is exportable member-facing content and needs no special handling.

## A.9 Test requirements

FS-014 closure requires three tiers: (1) **unit tests** for the new join-by-code lookup, code generation, and expiration handling in `FamilyMembershipRepository` (the single new data-layer surface), plus checklist-progress computation from real providers; (2) **widget tests** for all seven screens covering loading, empty, honest-error, RTL, and verified/unverified states; (3) **full regression** — 510/510 must remain green, and the new FS-014 test file(s) should lift the baseline. No Firestore-emulator rewrite is needed because the new writes ride the existing outbox, though emulator coverage of the new invitation code path would strengthen the rules evidence if the master plan's local `firestore.rules` gains code-based invitation rules.

## A.10 Files that would change vs. files that must remain untouched

| Would change (additive) | Must remain untouched |
| --- | --- |
| `lib/presentation/screens/family_setup_screens.dart` (new — PD-001..007) | `lib/presentation/screens/chat_screens.dart` and all FS-010 contracts (510-test baseline) |
| `lib/data/family_membership_repository.dart` (join-by-code lookup + generator) | `lib/data/privacy_purge_repository.dart` and `lib/data/family_data_export_service.dart` (Phase 4C/4D contracts) |
| `lib/core/database/guardian_database.dart` (v31 migration, `code` column) | Guardian AI layers, `guardian_ai_engine.dart` (frozen per Phase 4 contract) |
| `lib/presentation/router/app_router.dart` (7 new routes) | `lib/application/background_location_service.dart` (M9) |
| `lib/presentation/screens/dashboard_screen.dart` (PD-001 dual CTA upgrade of `_FamilySetup`) | `firebase/firestore.rules` and Render deployment (no deploy without approval) |
| `lib/presentation/screens/settings_screen.dart` (profile tile) | `lib/domain/subscription_entitlements.dart` + `subscription_repository.dart` (local-only semantics) |
| `lib/core/localization` (AR + EN FS-014 keys) | `master` branch (never merged) |
| `test/fs014_family_setup_test.dart` (new) | Phase 4E remote deletion/export (BLOCKED-BACKEND, out of scope) |

---

# Part B — FS-016: Startup & State Machine (5 screens)

## B.1 Feature definition and acceptance surface

FS-016 is defined as *"the app's cold-start experience and subscription-aware feature gating."* It closes the second-largest first-run gap: the app today has **no splash, no role gate, no offline startup card, no role-landing wrappers beyond child routes, and no what's-new surface**. Its screens complete the state machine that FS-014's first-run flows feed into.

| ID | Screen | Route | Purpose | UI composition | Auth |
| --- | --- | --- | --- | --- | --- |
| ST-001 | Onboarding / Splash + Role Selection | splash → role route | Brand entry; route by role | Splash → role gate (parent/child/spouse) | any |
| ST-002 | Feature Lock / Upgrade Gate | inline gate | Free-tier features locked: what's locked, why, upgrade CTA | Lock card (gradient hero) + entitlements list + upgrade CTA | any (post-entitlements) |
| ST-003 | Offline Startup | cold start offline | App usable offline: queued banner, last-known state freshness stamp | Honest startup card + `GuardianOfflineBanner` | any |
| ST-004 | Role Landing Variants | per-role post-gate | Child lands on `/child/:fid/:cid`; spouse lands on harmony dashboard | Role-specific landing wrappers | any member |
| ST-005 | What's New | `/whats-new` | Feature disclosure per version, dismiss with honesty | Version cards + dismiss | any member |

**Acceptance criteria (plan-derived).** ST-001 must route every launch through a role gate that persists the selected role and never silently defaults. ST-002 must gate only genuinely locked features with honest entitlement lists and a real upgrade path (the existing `SubscriptionUpgradeScreen`), never fake payments. ST-003 must keep the app honest about offline state with freshness stamps, reusing `GuardianOfflineBanner`. ST-004 must land each role on its canonical surface. ST-005 must disclose per-version changes and remember dismissal honestly.

## B.2 Current startup sequence

Cold start in `guardian_app.dart` runs the following, all non-blocking: (1) connectivity listening and the sync trigger (fire-and-forget through `syncCoordinatorCoreProvider`); (2) a post-frame callback for M6 policy delivery (`_triggerPolicyDelivery`), which loads the dashboard and synchronizes child device policies; (3) a post-frame callback for Phase-3 notification startup (`_triggerNotificationStartup`), initializing local notifications, wiring FCM handlers, and registering the device token; (4) a manual listener on `firebaseAuthSessionProvider` that re-triggers notification startup on authenticated transitions. Every failure degrades into an honest in-app state — the design law already in force — and startup never awaits anything, so there is **no blocking startup today**.

## B.3 Existing routes — what exists and what does not

Discovery confirms the following with certainty. There is **no splash screen** (no route, no asset-gated welcome); the router's `initialLocation` is `'/'` landing directly on `DashboardScreen` inside the `ShellRoute` with `GuardianBottomNav` (family id optional at shell level, so dependent tabs disable honestly before family creation). There is **no role gate** — no redirect rules based on auth or role state exist in `app_router.dart`; the router comment explicitly delegates authorization to `FamilyRuntimeContext → FamilyAuthorization`, never local checks in the router. There is **no `/whats-new` route**, no `/auth/confirm` route, and no offline startup card. What *does* exist, which shrinks FS-016's remaining scope considerably: the **child landing is partially implemented** (`/child/:familyId/:childId`, `/child/:familyId/:childId/policies`, `/child/:familyId/:childId/device`), and the **spouse landing is partially implemented** through FS-013's `/couple/:familyId/role` harmony flow. In other words, ST-004 is largely a wrapper/orchestration task, not screen-building.

## B.4 Provider init order and race conditions

Provider init in `guardian_providers.dart` is a clean DAG: `firebaseAuthContextProvider` → `firebaseAuthServiceProvider` → `firebaseAuthSessionProvider` (stream from `FirebaseAuthContext.changes`); `familyActorBindingServiceProvider` picks a real Firestore reader or the honest `_UnavailableFamilyMembershipRemoteReader` based on `GuardianFirebaseBootstrap.current.isReady`; `outboxRemoteWriterProvider` returns `UnconfiguredOutboxRemoteWriter` until Firebase is ready; and the sync coordinator serializes executions single-flight. Because the app never awaits any of these at startup and every failure path records an honest state, **no blocking race exists today**. The risk FS-016 must respect: adding a splash/role gate must not introduce an `await` that stalls launch, and the role gate must read the auth session as a **stream**, not a snapshot, to avoid the classic "gate evaluated before auth resolves" race — this is the one race condition to design around.

## B.5 Onboarding completion persistence

The SQLite `app_identity` table (`key TEXT PRIMARY KEY, value TEXT`) exists and is **unused for onboarding persistence** — it currently holds nothing FS-016-specific. ST-001's selected-role persistence and ST-005's dismissal memory can both land in `app_identity` without a schema migration. ST-003's freshness stamp reads from existing sources (`syncCoordinatorProvider` state, notification state) — no persistence needed beyond the honest providers.

## B.6 Offline startup behavior

`GuardianOfflineBanner` already exists and is used inside the chat flow; ST-003 reuses it directly. The honest offline posture is already the product's design law: `FirebaseSessionScreen` shows a faithful "Firebase not configured" message instead of pretending, and the app remains fully usable offline through the SQLite/outbox architecture. ST-003 therefore adds a **cold-start startup card** (brand hero + last-known-state freshness stamp + queued-banner) on top of what already works, in offline and degraded modes alike.

## B.7 Interaction with Privacy Controls, notifications, M9, subscriptions, and the frozen AI

FS-016 touches but must not disturb any of these: Privacy Controls and the export service are untouched (ST-003 is presentation-only over existing providers); M9 background location keeps its own service file; the subscription system is **local-only** (`subscription_entitlements.dart` + `subscription_repository.dart`; providers labeled in code as "ST-001 — Subscription & Entitlements" — see the naming conflict in B.9) with `subscriptionEntitlementsProvider`, `subscriptionUsageMetersProvider`, and `subscriptionBillingProvider` as the ST-002 read surface, and `SubscriptionUpgradeScreen` (route `familySubscriptionUpgrade`) as the honest upgrade path with no payment gateway; and the Guardian AI layers remain frozen per the Phase 4 contract — ST gates read entitlements only, never AI state.

## B.8 l10n, accessibility, and RTL requirements

`FirebaseSessionScreen` is the cautionary exhibit: it is the only screen found with **AR-hardcoded strings** (`'حساب Firebase'`, `'تسجيل الدخول'`, `'إنشاء حساب'`, `'تسجيل الخروج'`…) instead of `l10n.t()` keys. ST-001 will replace/supersede it as the first screen users see, and every ST-001/ST-003/ST-005 string must exist in **both** l10n maps from day one, with RTL layout verified (Splash and role gate are the highest-visibility screens in the product). Accessibility requires `Semantics` on the role gate, meaningful `AutofillHints` on the retained sign-in fields, and honest `ErrorText` presentation (pattern already established in the session screen).

## B.9 Test requirements

ST screens are UI orchestration with provider-driven honesty, so the load is on **widget tests**: role-gate routing (parent/child/spouse + unverified transitions), offline startup card states (online/offline/unconfigured Firebase), entitlement gate rendering for locked/unlocked features, role-landing dispatch, and what's-new cards + dismissal memory. The splash must not be measured by widget-clock tests; launch-time behavior is validated by headless flutter_tester route exercise, never claimed as Android-lifecycle proof. Regression: 510/510 must stay green; the new FS-016 test file lifts the baseline.

## B.10 Files that would change vs. files that remain untouched

| Would change (additive) | Must remain untouched |
| --- | --- |
| `lib/presentation/screens/startup_screens.dart` (new — ST-001/003/005) | All FS-010 chat files and contracts |
| `lib/presentation/screens/role_gate_screens.dart` (new — role gate + ST-004 wrappers) | Phase 4C/4D privacy/export contracts |
| `lib/presentation/router/app_router.dart` (splash, role gate redirect logic, `/whats-new`) | Guardian AI layers (frozen) |
| `lib/application/onboarding_providers.dart` (new — role + dismissal persistence over `app_identity`) | M9 background location service |
| `lib/presentation/screens/subscription_screens.dart` (ST-002 lock card additions) | `firebase/firestore.rules`, Render deployment |
| `lib/core/localization` (AR + EN ST keys) | `master` branch |
| `test/fs016_startup_test.dart` (new) | Phase 4E remote deletion/export (BLOCKED-BACKEND) |
| `lib/presentation/screens/firebase_session_screen.dart` (AR-hardcode remediation via l10n keys) | — |

**Naming conflict (B.9 detail).** The code comments in `guardian_providers.dart` label the subscription/entitlements providers as `ST-001 — Subscription & Entitlements`, while the master plan defines ST-001 as the splash/role gate and ST-002 as the feature-lock gate. The entitlements work shipped in the AI batch under a draft ST numbering that collides with FS-016's screen IDs. This is a **documentation-level conflict only** — no code semantics are affected — but the report flags it as `DOCUMENT-CONFLICT` for the ST prefix, to be reconciled in the closure report of whichever phase lands first.

---

# Part C — Order / Dependency Decision

## C.1 Comparison table

| Item | FS-014 (Primary Dashboard & Unlinked Device) | FS-016 (Startup & State Machine) |
| --- | --- | --- |
| **Current state** | `_FamilySetup` create path fully working (PD-002 seed); invite lifecycle server-side-complete but no public join surface; no profile, no re-auth, no checklist; dashboard exists but single-user-oriented | No splash, no role gate, no offline card, no `/whats-new`; child landing routes already exist (partial ST-004); spouse harmony landing partially exists; entitlements providers + upgrade screen already exist |
| **Missing scope** | 7 screens; PD-003 join-by-code requires new data-layer contract (code column, generator, lookup); PD-007 requires new persistence; PD-004 hooks | 5 screens, all additive; no schema migration strictly required; `app_identity` covers persistence; ST-004 mostly wrappers over existing child/spouse landings |
| **Dependencies** | FS-015 is planned later but FS-014 does not block on it (device-linked checklist step reads existing `childDeviceStatesProvider`); needs PD-003 contract before PD-001 is complete | Depends on nothing new; depends on existing entitlements (delivered), existing providers (delivered); feeds the role gate that FS-014's first-run flows will sit behind |
| **Backend dependency** | None strict — local-first + outbox; optional server-side code-resolution hook only | None — entirely local-first (SQLite, providers, l10n) |
| **Security risk** | Moderate: new invitation code path changes who can materialize membership — must preserve invitation expiration, revocation, and one-use semantics with tests | Low: presentation/state-machine work; risk is confined to not introducing an auth-evaluation race in the gate |
| **Testability** | High: one new repository surface (join-by-code) plus 7 widget screens; emulator coverage optional | High: widget-heavy, provider-driven; headless flutter_tester route exercise sufficient |
| **Recommended order** | **Second** — build it after FS-016's state machine exists, because FS-014's screens will live behind the role gate FS-016 creates | **First** — smaller, zero-migration, zero-backend-risk, and its role gate is the chassis that FS-014's first-run screens will mount on |

## C.2 Rationale

The ordering logic is structural. FS-016 creates the **state machine** — splash, role gate, role landings — that every first-run screen in FS-014 will execute inside. Building FS-014 first would mean wiring its seven routes into today's flat router and then re-architecting them behind a gate that does not yet exist; building FS-016 first costs one additive, migration-free, backend-free phase and gives FS-014 its home. Conversely, FS-014 cannot precede FS-016 without creating exactly that rework. Neither phase blocks the other on data, so the dependency is directional and cheap to respect. Within FS-014 itself, PD-003 (join-by-code) is the only hard contract and should be the first FS-014 screen implemented, since PD-001's dual-CTA entry depends on it.

## C.3 Final status

| Scope | Status |
| --- | --- |
| FS-014 discovery | **PHASE7-DISCOVERY-CONFIRMED** — all seven screens specified against existing foundations; one hard contract gap (PD-003 join-by-code) identified with a clear resolution path; no blocking unknowns |
| FS-016 discovery | **PHASE7-DISCOVERY-CONFIRMED** with one **DOCUMENT-CONFLICT** annotation — the `ST-001` prefix is already used in code comments for the subscription/entitlements providers while the master plan assigns ST-001 to the splash/role gate; semantics unaffected, numbering to be reconciled in the closure report |
| Overall Phase 7 entry | **PHASE7-DISCOVERY-CONFIRMED** — both subsystems are implementable from the current baseline (510/510 green, `18ec4fa`), per the user's instruction not to implement both in the same batch. Recommended entry batch: **FS-016 first, then FS-014**, awaiting explicit user approval before any code, commit, or push |

## C.4 What this audit deliberately did not cover

Phase 4E remote deletion/export remains BLOCKED-BACKEND and untouched; the Guardian AI layers remain frozen; FS-008 one-way audio and FS-015 device linking remain scheduled later per the master plan's Phase 7/FS-015 ordering; Render and production Firebase configuration were not touched or evaluated for change; and no Android-device or emulator validation was performed or claimed during this read-only audit.

---

**Evidence paths.** Master plan sections 6.14 (FS-014) and 6.16 (FS-016); screen index sections N and P; `lib/presentation/screens/dashboard_screen.dart` (44–140); `lib/data/guardian_repositories.dart`; `lib/data/family_membership_repository.dart`; `lib/data/firestore_contracts.dart`; `lib/application/guardian_providers.dart` (175–210, 939–955); `lib/presentation/guardian_app.dart` (55–125); `lib/presentation/router/app_router.dart` (40–120, 937–940); `lib/presentation/screens/firebase_session_screen.dart` (full); `lib/core/database/guardian_database.dart` (329, 809 — `app_identity`); `lib/presentation/screens/subscription_screens.dart` (194–196); Phase 4C/4D contracts in `PHASE4_DELETION_EXPORT_CONTRACT.md`; closure reports at `3bc6321` (pushed) and `18ec4fa` (HEAD).

**Author:** Manus AI · **Date:** 21 August 2026 · **Baseline:** 510/510 Flutter tests, 34/34 backend tests, HEAD `18ec4fa`, pushed checkpoint `3bc6321`.
