# Screen Inventory — Guardian Eye Pro (Phase 1 Complete)

**Status:** Documented · **Branch:** `feature/design-system-integration`

Phase 0 establishes the design-system baseline (tokens, AppTheme, primitives, bottom-nav shell, router normalization) on the first screen (Dashboard). **Phase 1 extends the upgrade to every remaining baseline screen**: raw `Card` widgets, inline `Theme.of(context).colorScheme` colors, and ad-hoc loading/error/empty bodies were replaced with `GuardianCard`, `GuardianStateView`, `GuardianIconBadge`, and `GuardianStatusChip` throughout, while all M1–M9 behavioral contracts (247/247 tests) remain green.

## Baseline Screens (Phase 1 scope)

| Route | Screen | File | Phase 1 Treatment |
| --- | --- | --- | --- |
| `/safety/pairing/:fid` | Pairing | `pairing_screen.dart` | `GuardianStateView` for loading/error/unauthorized/empty; `GuardianCard` + icon badge for the issued QR; expiry via `GuardianStatusChip` |
| `/device-link/:fid` | Device Link | `pairing_screen.dart` | Honest state views replace ad-hoc error bodies |
| — | Child Redemption | `child_redemption_screen.dart` | `GuardianStateView` for validating/error; outcome surface with `GuardianIconBadge` and sync chips |
| `/safety/daily/:fid` | Daily Safety | `family_safety_experience_screens.dart` | Child-daily cards + request review cards use `GuardianCard`, status chips, info `GuardianStateView` |
| `/requests/:fid` | Exception Request Review | `family_safety_experience_screens.dart` | Request cards with status chips; `_Notice` → soft info banner; `_Retry` → `GuardianStateView` |
| `/safety/policies/:fid` | Safety Policies | `safety_policies_screen.dart` | Decision/error/notice/policy cards tokenized |
| `/child/:fid/:cid/policies` | Screen-Time Policies (child-centric) | `screen_time_policies_screen.dart` | `GuardianCard` for all three admin cards; `GuardianStateView` for empty/error; decision chips; read-only banner tokenized |
| `/safety/device-status/:fid` | Child Device Status | `child_device_status_screen.dart` | Device cards tokenized; honest capability and failure states |
| `/family/:fid` | Family Members | `family_members_screen.dart` | Overview/unauthorized/empty tiles + member tiles → `GuardianCard`, honest failure view |
| `/settings` | Settings | `settings_screen.dart` | Inline colors replaced with tokens (minor) |
| `/safety/permissions` | Permissions Ladder | `permissions_screen.dart` | Lone `Card` replaced with `GuardianCard` (minor) |
| `/safety/actions` | Safety Actions | `safety_actions_screen.dart` | `GuardianCard` + icon badges for SOS and sync items |

Screens already upgraded in Phase 0: Dashboard (Decision Center), Child Context, Firebase Session (no cards). Screens from the FS-002→FS-016 specification set (63 screens) will be added in Phase 2 and later, consuming the primitives and shell defined here so the platform remains one visual product.

## FS-002 — Web Filtering (implemented)
All ten WF screens ship under the parent shell, gated by `FamilyRuntimeContext.can()` (`viewPolicies` / `managePolicies`), built exclusively from the nine design primitives, with honest states (loading → empty → error → offline → unauthorized) and full AR/EN via `app_localizations.dart`.

| ID | Screen | Route |
| --- | --- | --- |
| WF-001 | Web Filtering Dashboard | `/safety/web/:familyId` |
| WF-002 | Content Categories | `/safety/web/:familyId/categories` |
| WF-003 | Website Blocklist | `/safety/web/:familyId/blocklist` |
| WF-004 | Web Settings | `/safety/web/:familyId/settings` |
| WF-005 | Block History | `/safety/web/:familyId/history` |
| WF-006 | Block Hit Detail | `/safety/web/:familyId/history/:hitId` |
| WF-007 | Temporary Allow | `/safety/web/:familyId/history/:hitId/allow` |
| WF-008 | Site Allowlist | `/safety/web/:familyId/allowlist` |
| WF-009 | Per-Child Web Policy | `/safety/web/:familyId/child/:childId` |
| WF-010 | Blocked Page (child) | `/safety/web/blocked/:hitId` |

Code modules: `lib/data/web_filter_repository.dart` (SQLite offline-first `WebFilterRepository` + providers), `lib/domain/web_filtering/` (categories and data model), screens split as `web_filter_screens.dart` (WF-001/002), `web_filter_management_screens.dart` (WF-003–006), `web_filter_child_screens.dart` (WF-007–010). Schema: migration `v15` (`web_filter_hits`, `web_filter_domains`, `web_filter_category_rules`, `web_filter_settings`). Local-first with outbox-style sync semantics — no backend contract changes. Entry tile on the Decision Center dashboard → `/safety/web/:familyId`.

## Navigation Graph

Parent shell (5 tabs) → each tab is a canonical go_router path. All intra-app navigation uses `context.push`/`context.go`; unknown paths land on the not-found surface (verified by `m1_shell_test` dead-route cases).

## Screen Spec Format (contract for future FS screens)

Every screen spec added to this directory follows: Header → Primary surface (top to bottom) → Secondary surfaces → Global states (loading/empty/error/offline) → Interactions → Authorization gating → RTL notes. The existing 13 screens are already exercised by M1–M9 behavioral tests, which serve as the executable spec until per-screen written specs are authored per phase.
