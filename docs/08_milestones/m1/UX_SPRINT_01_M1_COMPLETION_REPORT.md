# Experience Sprint 01 v2 — Milestone M1 Completion Report

**Project:** Guardian Eye Pro
**Milestone:** M1 — App Shell + Canonical Navigation
**Baseline commit:** `ff432a0` (UX Sprint 01 v2 Reconciliation, master)
**Author:** Manus AI
**Date:** August 13, 2026
**Status:** M1 GREEN (gates evidenced directly; see `UX_SPRINT_01_M1_TEST_EVIDENCE.md`)

---

## 1. Purpose

The read-only reconciliation (`docs/UX_SPRINT_01_V2_RECONCILIATION.md`) established that the application shell felt like an engineering console rather than a family product: an inline theme bypassed the canonical design system, eight screens navigated through imperative `Navigator.push` calls, three prototype routes pointed at dead screens, and technical terminology (Firebase, sync) appeared in primary user-facing navigation.

M1 turned that shell into a coherent family product shell: one theme, one source of navigation truth, a real settings surface, and a consistent RTL/LTR foundation.

## 2. What Was Built

### 2.1 Canonical Router (`lib/presentation/router/app_router.dart`) — NEW

The existing GoRouter architecture was repaired rather than replaced, which satisfies the reconciliation preference ("use the existing GoRouter architecture if it can be repaired cleanly without introducing a second routing model"). Exactly one routing system exists now. The router exposes nine canonical routes, all targeting live screens:

| Route | Screen | Product meaning |
|---|---|---|
| `/` | `DashboardScreen` | Family home |
| `/family/:familyId` | `FamilyMembersScreen` | Family members |
| `/safety/policies/:familyId` | `SafetyPoliciesScreen` | Safety policies |
| `/safety/device-status/:familyId` | `ChildDeviceStatusScreen` | Child device status |
| `/safety/daily/:familyId` | `FamilyDailySafetyScreen` | Daily safety |
| `/timeline/:familyId` | `FamilySafetyTimelineScreen` | Timeline |
| `/settings` | `SettingsScreen` | Settings |
| `/safety/pairing/:familyId` | `PairingScreen` | Device pairing |
| `/safety/permissions` | `PermissionsScreen` | Permission ladder |

The router is exposed through a single `appRouterProvider`, and its `errorBuilder` renders a localized `_RouterNotFoundPage` (Arabic: «الصفحة غير موجودة» with a safe «العودة إلى الشاشة الرئيسة» affordance). Dead prototype routes (`/welcome`, `/child-profile`, `/parent-dashboard`) now land on that page instead of prototype screens. All authorization decisions remain delegated to `FamilyRuntimeContext` → `FamilyAuthorization`; the router itself performs no role checks.

### 2.2 App Shell (`lib/presentation/guardian_app.dart`) — REWRITTEN

The inline `ThemeData` construction was removed. The shell is now a `MaterialApp.router` consuming:

- `AppTheme.lightTheme` / `AppTheme.darkTheme` (canonical Cairo + Material3 system) with `ThemeMode.system`
- `appRouterProvider` as the single routing truth
- `localeProvider` (ar/en) for RTL/LTR, with all four localization delegates preserved
- The `GuardianApp` class name was preserved so the existing widget tests continue to reference it

### 2.3 Settings Surface (`lib/presentation/screens/settings_screen.dart`) — NEW

Technical and session controls were moved out of the family-home app bar. The single settings surface exposes, in product voice only:

- **Account & session** → `FirebaseSessionScreen` (product label «الحساب والجلسة», no Firebase terminology in primary navigation)
- **Language** — Arabic/English segmented control wired to `localeProvider`, with a «حُفظت الإعدادات» confirmation SnackBar (informative feedback)
- **Permission ladder** entry → canonical route `/safety/permissions`

### 2.4 Family Home (`lib/presentation/screens/dashboard_screen.dart`) — MODIFIED

The app bar now contains a single settings icon (product label «الإعدادات» with tooltip and semantic label) that pushes `/settings` via the canonical router. The former Firebase icon and language toggle were removed from the app bar. Navigation buttons are grouped into three labeled `_NavGroup` sections — family members (المجموعة، إضافة طفل، ربط جهاز), safety policies (إدارة السياسات، حالة الجهاز، السلامة اليومية), and permissions — using only `context.push` against canonical routes. Each gated button reads `can(FamilyPermission.*)` from the verified `FamilyRuntimeContext`, exactly as before: no local role check was introduced as a substitute.

### 2.5 RTL/LTR Shell

Directionality is driven by `AppLocalizations.isRtl` (locale `ar` → RTL, `en` → LTR) at the shell level, so navigation order, icon direction, and alignment follow the locale automatically. Manual left/right positioning is not used where `Directionality` handles it. The not-found page derives its own direction from the same localization source.

### 2.6 Localization (`lib/core/localization/app_localizations.dart`) — EXTENDED

Both AR and EN maps gained the product-voice keys required by the shell: `settings`, `accountSession`, `languagePreference`, `appPreferences`, `signOut`, `signedInAs`, `notSignedIn`, `settingsSaved`, `settingsLanguageAr`, `settingsLanguageEn`, `goHome`, `pageNotFound`, `pageNotFoundBody`. No key was removed; existing copy is preserved.

## 3. Dead-Path Retirement

Per the reconciliation dead-path inventory, each candidate was verified for references before deletion. `welcome_screen.dart`, `parent_dashboard_screen.dart`, `child_profile_screen.dart`, and `providers/router_provider.dart` had no live references outside themselves (confirmed by project-wide grep), so they were deleted. Their route paths remain unreachable: deep links now resolve to the localized not-found page, which was verified by widget test.

## 4. Boundary Compliance

No change touched any security, business, or domain artifact: `FamilyRuntimeContext`, `DeviceRuntimeContext`, `FamilyActorBindingService`, `FamilyAuthorization`, `PolicyEngine`, `ChildPolicyResolver`, SQLite repositories, outbox, Firestore rules, Functions, and Firebase configuration were all left unmodified. `app_theme.dart` and `app_colors.dart` were not modified — the canonical theme was consumed, not duplicated.

## 5. Test Evidence Summary

- `flutter analyze`: 0 issues (evidenced in `UX_SPRINT_01_M1_TEST_EVIDENCE.md`)
- Full suite: 89/89 pass — the original 80 tests unchanged in outcome (one test was updated only because its finder referenced a shell element deliberately removed by M1; its semantic assertion was preserved, see test evidence doc) plus 9 new M1 widget tests
- Firebase emulators: 15/15 Firestore rule tests + 2/2 Functions tests pass

**M1 STATUS: GREEN.**
