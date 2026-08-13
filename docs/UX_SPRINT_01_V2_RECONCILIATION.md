# UX Sprint 01 v2 — Read-Only Reconciliation Report

**Baseline inspected:** `master` branch tip `e1d0d2c` (Phase 18 canonical family runtime context), Guardian Eye Pro, Flutter 3.35.5.
**Method:** Strictly read-only. No source file was modified, no test was changed, no Firebase configuration was touched, and `phase17-stable-checkpoint` was not modified. The inspection covered the thirteen screen files, the application shell, the theme layer, the localization sources, the navigation infrastructure, and the current test suite, each measured against the authoritative UX sources: the UX Forensic Audit heritage, the UX Master Flow mission, the Experience Design Principles, the Design System inventory, the Motion System expectations, and the Iconography and Illustration Guide [1] [2] [3].
**Author:** Manus AI — **Date:** 2026-08-13

---

## 1. Current UX Baseline

The master branch is a **functionally complete Phase 18 platform with an unskinned user experience**. The application shell (`lib/presentation/guardian_app.dart`, 27 lines) is a plain `MaterialApp` that wires localization (Arabic/English with full delegates) but constructs its theme inline from a seed color rather than using the project's own `AppTheme`. There is no first-run experience: the app opens directly onto `DashboardScreen`, which shows an inline `_FamilySetup` form when no family exists. Navigation between screens is performed through raw `Navigator.push(MaterialPageRoute(...))` calls scattered across eight call sites. Three prototype screens (`welcome_screen`, `parent_dashboard_screen`, `child_profile_screen`) and a legacy GoRouter provider exist in the tree but are unwired and unreachable from the live app.

The live surface consists of `DashboardScreen` (family home, 353 lines), `FamilyMembersScreen` (418 lines), `SafetyPoliciesScreen` (422 lines), `ChildDeviceStatusScreen` (210 lines), `FirebaseSessionScreen` (204 lines), `FamilySafetyExperienceScreens` (528 lines — the richest UX file, containing the parent daily safety view, the parent exception review, the child policy experience with the exception request form, and the family safety timeline), plus `PairingScreen`, `PermissionsScreen`, and `SafetyActionsScreen`. The `app_localizations.dart` catalog holds 370 entries across Arabic and English, keyed as `AppLocalizations.t('key')`.

| Layer | State on master |
| --- | --- |
| App shell | Material3, seeded inline theme, no design-system token shell |
| Navigation | Imperative `Navigator.push` at 8 sites; GoRouter exists but unwired |
| First run | Inline two-field family form inside dashboard; no journey |
| Family home | Title + three metrics + wall of seven buttons + bare child list |
| Child experience | `ChildPolicyExperienceScreen` (form-style request) reached from parent flow |
| Localization | 370 AR/EN keys; `t('key')` API |
| Tests | 24 test files, 2 widget tests, no journey tests |

## 2. Existing Design-System Inventory

The project carries a complete but dormant token layer in `lib/core/theme/`. `AppColors` defines fourteen semantic colors (primary/success/warning/error/info in light and dark, backgrounds, surfaces, text hierarchy), and `AppTheme` provides `lightTheme` and `darkTheme` built on the **Cairo** typeface with a display/headline/body scale, 16-point card radius, elevation 2 philosophy, and full button styles. This is the closest existing equivalent of the "canonical design system" the sprint mission requires.

Critically, the v1 Sprint 01 design-system implementation (`GeTokens`, `GeTheme`, `GePrimitives`, `GeSurfaces` under `lib/core/design/`) was destroyed in the sandbox reset and does not exist on master. The reconciliation therefore recommends **activating and extending the existing `AppTheme`/`AppColors` layer rather than rebuilding a second library**, in line with the governance rule "do not create a second component library — any new visual value must become a token" [2].

| Design-system asset | Status on master |
| --- | --- |
| Color tokens (`AppColors`) | Present, complete, unused by shell |
| Typography scale (`AppTheme.textTheme`, Cairo) | Present, unused by shell |
| Radius / elevation philosophy (`cardTheme`, `elevatedButtonTheme`) | Present, unused by shell |
| Light + dark themes | Present, dormant |
| Iconography rules document | Not in repo; spec exists in mission document [1] |
| Motion tokens | Not in repo; spec exists in mission document [1] |
| Illustration language | Not in repo; spec exists in mission document [1] |
| GeTokens / GeTheme / GePrimitives / GeSurfaces (v1) | **Lost in reset — MISSING** |

## 3. Current Live User Journey

The only real journey on master is the **setup-and-metrics journey**: the app opens on the family home; if no family exists, the same screen renders a title, two text fields (family name, parent name), and a create button; once created, the same screen shows the family name, an offline-reassurance line, a verification warning when the actor is unverified, three metric tiles (children, incidents today, sync queue), a wrap of seven equal-weight action buttons, and a minimal children list in which every child reads "إعداد مطلوب / setup required". From there the parent can push into member management (which has a real invitation sheet and a confirmation dialog with closure), policy management (a sheet-based form with validation and no save preview), device pairing, permissions, child device status, daily safety, and the exception-review and timeline screens.

Two facts define this journey's character. First, it answers **engineering questions** (sync queue, device status, incidents) rather than the parent questions the information-architecture spec demands ("Is my family okay today?", "What needs my attention?", "Are there requests waiting?"). Second, the journey never produces a **first-value closure moment** — there is no "عائلتك جاهزة" screen and no dominant next action such as "أضف طفلك".

## 4. Gaps Against the UX Master Flow

The master flow prescribed by the mission is `WELCOME → CREATE/JOIN FAMILY → FAMILY SETUP → SUCCESS → ADD CHILD → FIRST VALUE`, followed by the Golden Journey `FIRST OPEN → FAMILY HOME → CHILD HOME → FAMILY RULE → EXCEPTION REQUEST` [2]. The reconciliation against each phase:

| Master Flow step | Status on master | Evidence |
| --- | --- | --- |
| Welcome surface | **MISSING** | `welcome_screen.dart` exists but is unwired prototype code using the obsolete `translate()` API |
| Create / join family | **PARTIAL** | Inline `_FamilySetup` inside dashboard; create only (no join path); no progressive disclosure |
| Family setup (name + parent) | **PARTIAL** | Fields are minimal as the spec requires, but the flow is a form, not a journey; no explanations per field |
| Success / closure moment | **MISSING** | No "عائلتك جاهزة" moment; creation drops back into the metric dashboard |
| First value ("أضف طفلك") | **MISSING** | Add child is one of seven equal buttons |
| Family home hierarchy (greeting → health → children → attention → requests → tonight → story) | **NEEDS REFACTOR** | Actual: title → offline line → verification card → 3 metrics → 7 buttons → bare child list |
| Child card with hero "time remaining" | **MISSING** | Child ListTile shows name + "setup required" only |
| Child home (childCanvas feel, rule, remaining, why, exception, one action) | **MISSING** | No dedicated child home screen; only `ChildPolicyExperienceScreen` reached from parent flow |
| Policy as family agreement + save preview | **NEEDS REFACTOR** | Sheet form, validation, direct save; the v1 preview dialog was lost and is absent on master |
| Exception conversation (chips, durations, respectful status) | **PARTIAL** | Form with dropdowns instead of chips; truthful status texts and approval notice exist |
| Timeline storytelling | **PARTIAL** | Event titles are narrative l10n keys, but subtitles are raw timestamps; no story framing |
| Settings surface | **MISSING** | Firebase session and language controls live in the family-home app bar — a direct spec violation |

## 5. Gaps Against Shneiderman's Eight Golden Rules

**Consistency** is partially present: live screens share `Directionality` handling, `l10n.t()` terminology, and Material card patterns, but button hierarchies mix seven equal-weight outlines, the theme is not centralized, and the three prototype screens use a different localization API entirely, making them un-compilable against the current catalog [3]. **Universal usability** is undermined by engineering-language surfaces (sync queue, device lifecycle states, verification card in technical wording) and by a permissions screen reached by an ungated button. **Informative feedback** exists for destructive membership actions (confirmation dialog) and policy validation, but policy save gives only a validation message and no result confirmation, and the dashboard shows no contextual feedback for sync completion. **Dialogs yielding closure** are implemented for member removal but missing for policy creation (no preview), family creation (no success screen), and exception requests (no conversational progression). **Error prevention** is real and commendable: permission-gating disables impossible actions on four of seven buttons, form validation runs before submission, and the offline line never over-promises. **Reversibility** is present for exceptions (pending requests remain visible with expiry) and membership removal (confirm-then-delete) but absent for policy saves and family creation. **User control** (rule 7) is adequate — pull-to-refresh and retry exist on every async surface. **Short-term memory load** (rule 8) is high on the dashboard, which asks the parent to map seven buttons to the six parent questions instead of answering the questions directly.

## 6. Prototype / Dead-Path Inventory

| Dead path | Location | Why dead |
| --- | --- | --- |
| `WelcomeScreen` | `lib/presentation/screens/welcome_screen.dart` | Only referenced by unwired `router_provider.dart`; uses obsolete `loc.translate()` API |
| `ParentDashboardScreen` | `lib/presentation/screens/parent_dashboard_screen.dart` | Same; unreachable from the live app |
| `ChildProfileScreen` | `lib/presentation/screens/child_profile_screen.dart` | Same; unreachable |
| `routerProvider` (GoRouter) | `lib/presentation/providers/router_provider.dart` | Never passed to `MaterialApp.router`; routes point at the three prototype screens |
| v1 design system (`GeTokens`/`GeTheme`/`GePrimitives`/`GeSurfaces`) | was `lib/core/design/` | Destroyed by sandbox reset; absent from master |
| v1 Sprint 01 screens (first run, settings, child home) | — | Destroyed by reset; absent from master |

These files should be retired in the refactor pass — none of them is reachable, and the two prototype screens cannot compile against the current localization API.

## 7. Localization Gaps

The catalog is structurally healthy (370 AR/EN pairs, RTL detection, full delegates) and truthful — terms like `temporaryExceptionUntil` and `offlineFirst` are honest. The gaps are **experiential vocabulary**, all required by the sprint's screen plan:

| Missing key group | Example missing keys | Needed by |
| --- | --- | --- |
| First-run and first value | `greeting`, `firstValueFamilyReady`, `addChildYourChild` | First-run sheets, closure moment |
| Child home experience | `timeRemaining`, `hero`, `remaining`, `today`, `childExperience` | Child home screen |
| Policy agreement framing | `familyAgreement`, `policyPreview`, `policyPreviewTitle`, `approvalCreates` | Policy preview dialog |
| Exception conversation | Reason-chip and duration-chip labels (currently dropdown strings), conversational submit/confirmation | Exception conversation |
| Dashboard hierarchy | Greeting variants (morning/afternoon/evening), section headers, attention copy | Refactored dashboard |

No English-only or Arabic-only keys were found among the 370 entries — the bilingual discipline of the spec holds.

## 8. Motion, Iconography, and Illustration Gaps

**Motion:** no motion tokens or animation controller layer exists; every transition is the default MaterialPageRoute fade. The spec's purposeful-motion list (onboarding progression, family creation, device connection, invitation states, policy changes, request submission, approval, timeline appearance, sync state) is entirely unimplemented, as are reduced-motion accommodations. **Iconography:** screens use raw `Icons.*` Material glyphs ad hoc (people, warning, sync_problem, qr_code, bedtime, groups, phonelink_lock, today) with no semantic-family discipline and no documented RTL-mirroring rule; the v1 audit's requirement of a unified semantic family across the eighteen named domains is not met. **Illustration:** the tree contains zero illustration or imagery assets — no empty-state anchors, no onboarding visuals, no family-setup warmth; the mission's "visual anchor + explanation + next action" empty-state rule is currently satisfied only by text (e.g., `noChildren`, `noData`).

## 9. Accessibility Gaps

The live screens carry a solid foundation: every surface applies the correct `Directionality` per locale, Material components contribute implicit semantics, and permission gating provides affordance-based prevention. The gaps are: no explicit `SemanticsLabel` layer on icon-only buttons beyond tooltips; no contrast verification against the new token palette (Cairo at 14/16pt in secondary gray may fall below 4.5:1 on some surfaces); no dynamic-text (`MediaQuery.textScaler`) stress handling in fixed layouts such as the seven-button wrap; no `ExcludeSemantics`/reader-order management in the dashboard sections; and no reduced-motion consideration in the navigation system. None of these are blocking for entry to the sprint, but all belong to the P3 polish scope.

## 10. Priority Matrix

| Requirement | Impact | Effort | Priority | Verdict |
| --- | --- | --- | --- | --- |
| Wire `AppTheme` as real app shell + RTL/LTR locale surface | High | Low | **P0** | NEEDS REFACTOR |
| First-run journey (welcome → family name → setup → closure → add child) | High | Medium | **P0** | MISSING |
| Canonical navigation (router) replacing 8 inline pushes | Medium | Medium | **P0** | NEEDS REFACTOR |
| Dashboard hierarchy refactor (answer parent questions in 5–10 s) | High | Medium | **P1** | NEEDS REFACTOR |
| Child card with "time remaining" hero | High | Low | **P1** | MISSING |
| Child home screen (childCanvas) | High | Medium | **P1** | MISSING |
| Move Firebase/language controls to settings surface | Medium | Low | **P1** | NEEDS REFACTOR |
| Policy agreement framing + save preview dialog | Medium | Low | **P2** | NEEDS REFACTOR |
| Exception conversation (chips, durations, respectful states) | Medium | Medium | **P2** | NEEDS REFACTOR |
| Timeline storytelling polish | Medium | Low | **P3** | NEEDS REFACTOR |
| Motion tokens + purposeful transitions + reduced motion | Medium | High | **P3** | MISSING |
| Iconography semantic families + RTL rules | Medium | Medium | **P3** | MISSING |
| Illustration language (empty states, onboarding, warmth) | Medium | High | **P3** | MISSING |
| Accessibility hardening (contrast, text scaling, semantics) | Medium | Medium | **P3** | NEEDS REFACTOR |
| Journey widget test suite (14 categories) | High (gate) | Medium | **P0–P2** | MISSING |

## Implementation Order

**P0 — App Shell + First Run + Family Setup.** Wire `AppTheme.lightTheme`/`darkTheme` through the app shell with the locale surface; retire the three prototype screens and the unwired router; rebuild canonical navigation; implement the first-run journey ending in the "عائلتك جاهزة" closure with the dominant "أضف طفلك" action; move the Firebase session and language entries into a settings surface; back the work with widget tests.

**P1 — Parent Family Home + Child Home.** Refactor the dashboard to the prescribed hierarchy (greeting → family health → children → attention → requests → tonight → recent story) with gated, grouped actions; give every child card the "time remaining" hero, device status, and attention state; build the child home experience on a childCanvas surface with current rule, remaining time, why-the-rule-exists, exception state, and exactly one primary action, enforcing the banned-vocabulary list.

**P2 — Policy + Exception Dialogue.** Reframe policy creation as a family agreement with a human-language save preview describing the resulting state; convert the exception request form into the conversation pattern (need-more-time opener, reason chips, duration chips, truthful sent/approved/not-approved states) and mirror the decision language back into the timeline and the parent review card.

**P3 — Timeline + Polish.** Upgrade the timeline from timestamped log to narrative story; introduce motion tokens and purposeful transitions with reduced-motion respect; codify the iconography families and RTL rules; commission the illustration language for empty states and onboarding; harden contrast, dynamic text, and semantic labels.

## Non-Claims

This report asserts only what was directly observed on master tip `e1d0d2c`. It does not estimate durations, does not propose architecture changes to `FamilyRuntimeContext`, `FamilyActorBinding`, `FamilyAuthorization`, SQLite, Outbox, or Firestore rules, and it treats the v1 Sprint 01 design-system code as unrecoverable for this session's purposes. The phase17-stable-checkpoint branch was not modified.

---

**EXPERIENCE SPRINT 01 V2 — READY FOR IMPLEMENTATION**

## References

[1]: Guardian Eye Pro — Master Experience Engineering Mission (authoritative UX mission document, sections: Non-Negotiable UX Law, Shneiderman's Eight Golden Rules, Design System, Iconography, Illustrations, Motion Design, Information Architecture, Accessibility, Arabic-First Quality).
[2]: Guardian Eye Pro — UX Execution Sprint 01, "Golden User Journey" mission brief (Phases 1–9: App Shell, First Run, First Value, Family Home, Child Card, Child Home, Policy Experience, Exception Request, Design System Governance).
[3]: Target Experience Blueprint (docs/TARGET_EXPERIENCE_BLUEPRINT.md) — role-based experience model: parent command center, child supportive environment, co-parent as first-class participant.
