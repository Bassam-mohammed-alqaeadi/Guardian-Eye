# Guardian Eye Pro — Design System (Phase 0)

**Status:** Implemented · **Branch:** `feature/design-system-integration` · **Code:** `lib/core/theme/`, `lib/presentation/widgets/`

This document is the canonical reference for the visual layer of Guardian Eye Pro. It closes the gap identified by the `UX_SPRINT_01_V2_RECONCILIATION` audit, which found the master branch to be a functionally complete Phase 18 platform with an unskinned user experience (inline theme, no first-run affordances, raw `Navigator` calls, prototype screens). Phase 0 replaces that audit's findings with a production design system while touching **zero** domain, data, sync, or Firebase code.

## 1. Brand Tokens

All visual decisions derive from `lib/core/theme/guardian_tokens.dart` (`GuardianTokens`). Screens never use ad-hoc `Colors.xxx` values — every color passes through a token or the theme.

| Token | Value | Meaning |
| --- | --- | --- |
| `guardianNavy` | `#0F2A5B` | Primary brand — headers, app bar, bottom navigation |
| `guardianTeal` | `#00B8A9` | Trust-and-action accent — success-adjacent states, active indicators |
| `guardianTealLight` | `#7FE5DA` | Light accent for highlights on dark surfaces |
| `guardianGradient` | navy → teal diagonal | Hero surfaces (score card, family identity, first-run value) |
| `fontFamily` | Cairo | Arabic-first typeface; identical fallback for Latin text |

## 2. Semantic / Status Palette

The platform's **honest-state taxonomy** (`GuardianStatusKind`) maps every measurable condition to exactly one status. New statuses are a documented decision, never a color choice inside a screen.

| Status | Color | Usage |
| --- | --- | --- |
| `safe` | `#1E8E3E` | Verified protection active |
| `watch` | `#E8A000` | Elevated attention needed |
| `alert` | `#D93025` | Immediate parent action required |
| `offline` | `#5F6368` | Honest network state (changes are queued, not lost) |
| `sos` | `#D93025` | Emergency state (separate affordance from alert) |
| `pro` | `#6C5CE7` | Pro-subscription feature marker |
| `neutral` | `#4A5A78` | Informational |

## 3. Layout Tokens

`radiusCard = 16`, `radiusCardLarge = 20` (hero), `radiusButton = 14`, `radiusPill = 100`. Section spacing `12`; card content padding `16`.

## 4. Component Library (`lib/presentation/widgets/guardian_primitives.dart`)

| Primitive | Contract |
| --- | --- |
| `GuardianCard` | Flat, hairline-bordered, 16-radius workhorse surface; optional tap |
| `GuardianHeroCard` | Brand-gradient hero surface, white text |
| `GuardianSection` | Titled group of content with optional trailing action |
| `GuardianStatusChip` | Honest state pill; `live: true` adds breathing dot |
| `GuardianStateView` | The universal loading / empty / error / offline view with retry |
| `GuardianStatTile` | Value + label metric tile (safe status colors) |
| `GuardianIconBadge` | Circular icon mark for cards and lists |
| `GuardianOfflineBanner` | Network-state reminder above the bottom navigation |
| `GuardianBottomNav` | The five-tab role shell (see §5) |

## 5. Navigation Shell

`GuardianBottomNav` is wired as a `ShellRoute` in `app_router.dart`. Tabs: **Home** (`/`), **Children** (`/family/:familyId`), **Daily Safety** (`/safety/daily/:familyId`), **Safety Timeline** (`/timeline/:familyId`), **Settings** (`/settings`). Tabs that require family context disable themselves honestly when no family exists, instead of crashing or showing empty shells. The shell family ID resolves from the route path first, then from `dashboardProvider` — no additional provider machinery.

Raw `Navigator.push` sites were eliminated in Phase 0: `settings_screen`, `child_device_status_screen`, and `family_safety_experience_screens` now use `context.push('/...')` against the canonical router, and two new named routes were added (`/requests/:familyId` for exception-request review, `/firebase-session` for the session surface).

## 6. Component Themes (Material 3)

`lib/core/theme/app_theme.dart` provides the full canonical `AppTheme`: navy-based `ColorScheme`, Cairo typography, rounded-14 buttons with sane minimum sizes (`Filled 120×48`, `Outlined 88×44`), hairline card style, elevated dialogs, and bottom-sheet theming. `guardian_app.dart` already wires this theme; no wiring change was required.

## 7. Honest-State Rules (hard requirements)

1. Every list/detail surface shows one of the four `GuardianStateView` states — never a blank or a spinner that never resolves.
2. Offline is displayed, not hidden: the `GuardianOfflineBanner` tells the parent that queued changes are saved and will sync.
3. Permission and verification failures disable affordances with an explanation, never dead ends.
4. Status colors come from `GuardianStatusKind.palette`, never ad-hoc.
5. The shell never shows content the actor is not authorized to see; tabs instead disable and explain.

## 8. RTL / Arabic

Cairo is the application typeface. All strings flow through `AppLocalizations.t(...)`, and screens wrap content in `Directionality` driven by the locale. The bottom nav, hero card, and primitives are layout-direction neutral.

## 9. What Phase 0 Does NOT Change

Domain models, repositories, providers, sync/outbox, Firebase rules, the Render backend, and the Phase 18 GuardianEvent contract are untouched. Phase 0 is a pure presentation-layer integration; every behavior test (247/247) passes unmodified in principle — test fixes were limited to the shell scaffold finder (the shell adds one `Scaffold`) and were behavior-preserving.
