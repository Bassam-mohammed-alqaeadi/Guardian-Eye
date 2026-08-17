# Screen Inventory — Guardian Eye Pro (Phase 0 Baseline)

**Status:** Documented · **Branch:** `feature/design-system-integration`

Phase 0 establishes the design-system baseline on the **existing 13 production screens**. Screens from the FS-002→FS-016 specification set (63 screens) will be added in later phases, consuming the primitives and shell defined here so the platform remains one visual product.

## Baseline Screens (Phase 0 scope)

| Route | Screen | File | Phase 0 Treatment |
| --- | --- | --- | --- |
| `/` | Primary Parent Dashboard (Decision Center) | `dashboard_screen.dart` | Full integration: hero card, stat tiles, sections, honest state views |
| `/family/:fid` | Family Members | `family_members_screen.dart` | Inherits shell/theme (no inline colors found) |
| `/child/:fid/:cid` | Child Context | `child_context_screen.dart` | Tokenized status icons, honest gating |
| `/child/:fid/:cid/policies` | Screen-Time Policies (child-centric) | `screen_time_policies_screen.dart` | Inherits shell/theme |
| `/safety/policies/:fid` | Safety Policies | `safety_policies_screen.dart` | Inherits shell/theme |
| `/safety/device-status/:fid` | Child Device Status | `child_device_status_screen.dart` | Router-normalized navigation |
| `/safety/daily/:fid` | Daily Safety | `family_safety_experience_screens.dart` | Router-normalized navigation |
| `/timeline/:fid` | Safety Timeline | `family_safety_experience_screens.dart` | Router-normalized navigation |
| `/requests/:fid` | Exception Request Review | `family_safety_experience_screens.dart` | New named route (Phase 0) |
| `/settings` | Settings | `settings_screen.dart` | Router-normalized navigation, theme components |
| `/safety/pairing/:fid` | Pairing | `pairing_screen.dart` | Inherits shell/theme |
| `/device-link/:fid` | Device Link | `pairing_screen.dart` | Inherits shell/theme |
| `/safety/permissions` | Permissions Ladder | `permissions_screen.dart` | Inherits shell/theme |
| `/firebase-session` | Firebase Session | `firebase_session_screen.dart` | New named route (Phase 0) |
| — | Child Redemption | `child_redemption_screen.dart` | Inherits shell/theme |
| — | Safety Actions | `safety_actions_screen.dart` | Inherits shell/theme |

## Navigation Graph

Parent shell (5 tabs) → each tab is a canonical go_router path. All intra-app navigation uses `context.push`/`context.go`; unknown paths land on the not-found surface (verified by `m1_shell_test` dead-route cases).

## Screen Spec Format (contract for future FS screens)

Every screen spec added to this directory follows: Header → Primary surface (top to bottom) → Secondary surfaces → Global states (loading/empty/error/offline) → Interactions → Authorization gating → RTL notes. The existing 13 screens are already exercised by M1–M9 behavioral tests, which serve as the executable spec until per-screen written specs are authored per phase.
