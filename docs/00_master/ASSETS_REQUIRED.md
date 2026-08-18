# ASSETS REQUIRED — Visual Asset Governance Register

**Rule:** every visual asset must be planned before use. An implementing agent that cannot generate an asset records a precise entry here — it never silently ships an inappropriate placeholder. Contract fields: Asset ID, Filename, Description, Dimensions, Format, Theme, Location, Screen, State, Priority, Human-supplied?, AI-generated?, Fallback.

## A. Existing (verified) assets

| Asset ID | Filename | Description | Theme | Screens | Fallback |
| --- | --- | --- | --- | --- | --- |
| ASSET-001 | Material icon set | All UI icons (shields, users, maps, clocks, …) | Navy/teal tint via iconTheme | All | — |
| ASSET-002 | Cairo font | Brand typeface (AR+EN) | guardianTokens.fontFamily | All | system fallback |
| ASSET-003 | App icon / launcher | com.guardianeye.app branding | Navy #0F2A5B + shield motif | Splash | none |

## B. Required — to be produced (AI-generated under brand system, or human-supplied)

| Asset ID | Filename | Description | Dimensions | Format | Theme | Location | Screen | State | Priority | Human? | AI? | Fallback |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ASSET-010 | ge_empty_illustration.png | Family map empty state illustration | 320×220 | PNG | Navy/teal, Cairo-safe | assets/images/ | LO-001 | Empty | Medium | no | yes | solid teal-tinted card |
| ASSET-011 | wf_shield_illustration.png | Web filtering dashboard hero illustration | 320×180 | PNG | Brand | assets/images/ | WF-001 | Default | Medium | no | yes | icon-only hero |
| ASSET-012 | sos_urgent_pattern.png | SOS activation urgent background pattern | full-bleed | PNG | Navy→urgent gradient-safe | assets/images/ | SO-002 | Default | High | no | yes | gradient (existing tokens) |
| ASSET-013 | ai_transparency_illustration.png | AI transparency center illustration | 280×180 | PNG | Calm, intelligent | assets/images/ | AI-010 | Default | Low | no | yes | icon-only |
| ASSET-014 | app_generic_badge.png | Generic app-icon placeholder for unidentifiable apps | 96×96 | PNG | Neutral | assets/images/ | AC-002 | Missing icon | High | no | yes | Material icon Apps |
| ASSET-015 | child_mode_lock_art.png | Child lock screen illustration (age-appropriate, warm) | 300×240 | PNG | Warm family tone | assets/images/ | CM-002 | Locked | Medium | no | yes | plain lock icon |
| ASSET-016 | couple_harmony_illustration.png | Couple harmony dashboard hero (cooperation, not surveillance) | 320×180 | PNG | Warm cooperation tone | assets/images/ | CO-002 | Default | Medium | no | yes | icon-only hero |
| ASSET-017 | report_cover_header.png | PDF report cover header | 1200×300 | PNG | Brand print-safe | assets/images/ | RP-004/005 | Default | High | no | yes | navy solid band |
| ASSET-018 | onboarding_splash_art.png | Splash/role-selection hero art | 720×900 | PNG | Brand | assets/images/ | ST-001 | Splash | High | no | yes | solid navy |

## C. Rules

1. All AI-generated assets follow the brand system: navy `#0F2A5B`, teal `#00B8A9`, Cairo typography, rounded geometry, no photorealism that conflicts with the honest-state brand.
2. Evidence images (screenshots, audio) are NEVER assets — they are privacy-classified runtime data rendered via the evidence viewers.
3. RTL: illustrations must be non-directional or mirrored appropriately; text inside illustrations is prohibited (use code-rendered strings instead).
