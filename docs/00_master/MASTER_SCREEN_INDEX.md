# MASTER SCREEN INDEX — Guardian Eye Pro (170 named screens, ~200 states)

**Authoritative registry of every screen.** Status values: HISTORICAL/VERIFIED, CURRENT, IN DESIGN, IN DEVELOPMENT, IMPLEMENTED, TESTED, DEVICE VERIFIED, BACKEND VERIFIED, GREEN, PARTIAL, BLOCKED, PLANNED, SUPERSEDED, DEPRECATED. Per-screen 21-field specs live in `docs/06_ux/02_screens/<subsystem>/`. Companion: `MASTER_FEATURE_MATRIX.md`, `MASTER_NAVIGATION_MAP.md`.

## A. Baseline Screens (upgraded Phase 0/1)

| Screen ID | Name | Subsystem | Status | Route | Spec |
| --- | --- | --- | --- | --- | --- |
| BX-001 | Dashboard (Decision Center) | Baseline | TESTED / GREEN | `/` | docs/06_ux/02_screens/INDEX.md |
| BX-002 | Child Context | Baseline | TESTED / GREEN | `/child/:familyId/:childId` | — |
| BX-003 | Child Screen-Time Policies | Baseline | TESTED / GREEN | `/child/:familyId/:childId/policies` | — |
| BX-004 | Family Members | Baseline | TESTED / GREEN | `/family/:familyId` | — |
| BX-005 | Safety Policies | Baseline | TESTED / GREEN | `/safety/policies/:familyId` | — |
| BX-006 | Child Device Status | Baseline | TESTED / GREEN | `/safety/device-status/:familyId` | — |
| BX-007 | Daily Safety | Baseline | TESTED / GREEN | `/safety/daily/:familyId` | — |
| BX-008 | Safety Timeline | Baseline | TESTED / GREEN | `/timeline/:familyId` | — |
| BX-009 | Exception Request Review | Baseline | TESTED / GREEN | `/requests/:familyId` | — |
| BX-010 | Settings | Baseline | TESTED / GREEN | `/settings` | — |
| BX-011 | Firebase Session | Baseline | TESTED / GREEN | `/firebase-session` | — |
| BX-012 | Pairing | Baseline | TESTED / GREEN | `/safety/pairing/:familyId` | — |
| BX-013 | Device Link (redemption) | Baseline | TESTED / GREEN | `/device-link/:familyId` | — |
| BX-014 | Permissions Ladder | Baseline | TESTED / GREEN | `/safety/permissions` | — |

## B. FS-002 Web Filtering

| Screen ID | Name | Status | Route | Spec |
| --- | --- | --- | --- | --- |
| WF-001 | Web Filtering Dashboard | CURRENT | `/safety/web/:familyId` | docs/06_ux/02_screens/web_filtering/ |
| WF-002 | Content Categories | COMPLETED | `/safety/web/:familyId/categories` | — |
| WF-003 | Website Blocklist | COMPLETED | `/safety/web/:familyId/blocklist` | — |
| WF-004 | Web Filtering Settings | COMPLETED | `/safety/web/:familyId/settings` | — |
| WF-005 | Block History | COMPLETED | `/safety/web/:familyId/history` | — |
| WF-006 | Block Hit Detail | COMPLETED | `/safety/web/:familyId/history/:hitId` | — |
| WF-007 | Temporary Allow | COMPLETED | `/safety/web/:familyId/history/:hitId/allow` | — |
| WF-008 | Site Allowlist | COMPLETED | `/safety/web/:familyId/allowlist` | — |
| WF-009 | Per-Child Web Policy | COMPLETED | `/safety/web/:familyId/:childId` | — |
| WF-010 | Blocked Page Explanation | COMPLETED | device-side `/blocked` | — |

## C. FS-003 Application System

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| AC-001 | Application Control Dashboard | PLANNED | `/apps/:familyId` |
| AC-002 | Installed Applications | PLANNED | `/apps/:familyId/:childId` |
| AC-003 | Application Details | PLANNED | `/apps/:familyId/:childId/:appId` |
| AC-004 | Allowlist | PLANNED | `/apps/:familyId/allowlist` |
| AC-005 | App Usage Detail | PLANNED | `/apps/:familyId/:childId/:appId/usage` |
| AC-006 | Usage Alert Settings | PLANNED | `/apps/:familyId/:childId/:appId/alerts` |
| AC-007 | Age-Rating Policy | PLANNED | `/apps/:familyId/ratings` |
| AC-008 | App Block History | PLANNED | `/apps/:familyId/history` |

## D. FS-004 Screenshot & Camera Control

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| SC-001 | Screen & Camera Dashboard | PLANNED | `/monitoring/:familyId` |
| SC-002 | Screen Monitoring (timeline) | PLANNED | `/monitoring/:familyId/screenshots` |
| SC-003 | Screenshot Viewer | PLANNED | `/monitoring/:familyId/screenshots/:shotId` |
| SC-004 | Live Screen Session | PLANNED | `/monitoring/:familyId/live` |
| SC-005 | Camera Control | PLANNED | `/monitoring/:familyId/camera` |
| SC-006 | Child Active Session | PLANNED | `/monitoring/:familyId/:childId/session` |
| SC-007 | Capture Request History | PLANNED | `/monitoring/:familyId/requests` |
| SC-008 | Camera Schedule | PLANNED | `/monitoring/:familyId/schedule` |
| SC-009 | Evidence Review Queue | PLANNED | `/monitoring/:familyId/evidence` |

## E. FS-005 Special & Custom Modes

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| MD-001 | Special Modes Dashboard | PLANNED | `/modes/:familyId` |
| MD-002 | Mode Details | PLANNED | `/modes/:familyId/:modeId` |
| MD-003 | Create Custom Mode | PLANNED | `/modes/:familyId/new` |
| MD-004 | Edit Mode | PLANNED | `/modes/:familyId/:modeId/edit` |
| MD-005 | Mode Schedule | PLANNED | `/modes/:familyId/:modeId/schedule` |
| MD-006 | Child Assignment | PLANNED | `/modes/:familyId/:modeId/children` |
| MD-007 | Mode History | PLANNED | `/modes/:familyId/:modeId/history` |
| MD-008 | Child Active Mode Screen | PLANNED | `/child/:familyId/:childId/mode` |
| MD-009 | Mode Templates | PLANNED | inline on MD-003 |
| MD-010 | Mode Conflict Resolver | PLANNED | inline on MD-002 |

## F. FS-006 SOS & Emergency

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| SO-001 | SOS Dashboard | PLANNED | `/sos/:familyId` |
| SO-002 | SOS Activation | PLANNED | `/sos/:familyId/activate` |
| SO-003 | Active SOS | PLANNED | `/sos/:familyId/active` |
| SO-004 | Emergency Location | PLANNED | `/sos/:familyId/location` |
| SO-005 | Emergency Alert (deep link) | PLANNED | `/sos/:familyId/alert/:alertId` |
| SO-006 | Acknowledgement History | PLANNED | `/sos/:familyId/ack` |
| SO-007 | SOS Recipient Management | PLANNED | `/sos/:familyId/recipients` |
| SO-008 | SOS Drill / Readiness Test | PLANNED | `/sos/:familyId/drill` |

## G. FS-007 Offline AI Safety

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| AS-001 | AI Safety Dashboard | PLANNED | `/ai-safety/:familyId` |
| AS-002 | Safety Reports | PLANNED | `/ai-safety/:familyId/reports` |
| AS-003 | Safety Report Detail | PLANNED | `/ai-safety/:familyId/reports/:reportId` |
| AS-004 | Screenshot Evidence Viewer | PLANNED | `/ai-safety/:familyId/evidence/:evidenceId` |
| AS-005 | Custom Dictionary | PLANNED | `/ai-safety/:familyId/dictionary` |
| AS-006 | AI Safety Settings | PLANNED | `/ai-safety/:familyId/settings` |
| AS-007 | Child Safety Explanation | PLANNED | `/child/:familyId/:childId/safety` |
| AS-008 | Detection Trend | PLANNED | `/ai-safety/:familyId/trend` |
| AS-009 | Dictionary Templates | PLANNED | inline on AS-005 |

## H. FS-008 One-Way Audio

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| AU-001 | Live Audio Entry | PLANNED | `/audio/:familyId` |
| AU-002 | Audio Authorization Gate | PLANNED | `/audio/:familyId/auth` |
| AU-003 | Connecting | PLANNED | `/audio/:familyId/listening/connecting` |
| AU-004 | Active Live Audio | PLANNED | `/audio/:familyId/listening/active` |
| AU-005 | Reconnecting | PLANNED | `/audio/:familyId/listening/reconnecting` |
| AU-006 | Audio Unavailable | PLANNED | `/audio/:familyId/listening/unavailable` |
| AU-007 | Audio Policy Settings | PLANNED | `/audio/:familyId/settings/policy` |
| AU-008 | Maximum Duration Settings | PLANNED | `/audio/:familyId/settings/duration` |
| AU-009 | Network Policy Settings | PLANNED | `/audio/:familyId/settings/network` |
| AU-010 | Audio Session History | PLANNED | `/audio/:familyId/history` |
| AU-011 | Spouse Consent Settings | PLANNED | `/audio/:familyId/settings/consent` |
| AU-012 | Child Audio Policy | PLANNED | `/child/:familyId/:childId/audio-policy` |
| AU-013 | Session Notes | PLANNED | inline on AU-010 |
| AU-014 | Keyword Alert Settings | PLANNED | `/audio/:familyId/settings/keywords` |

## I. FS-009 Reports & PDF

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| RP-001 | Reports Dashboard | PLANNED | `/reports/:familyId` |
| RP-002 | Report Builder | PLANNED | `/reports/:familyId/build` |
| RP-003 | Generation Progress | PLANNED | `/reports/:familyId/build/progress/:jobId` |
| RP-004 | Single Child Report | PLANNED | `/reports/:familyId/report/:reportId` |
| RP-005 | All-Children Report | PLANNED | `/reports/:familyId/report/:reportId/all` |
| RP-006 | Scheduled Reports | PLANNED | `/reports/:familyId/schedule` |
| RP-007 | Report Share | PLANNED | inline on RP-004/005 |

## J. FS-010 Ephemeral Family Chat

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CH-001 | Chat List | PLANNED | `/chat/:familyId` |
| CH-002 | Chat Screen | PLANNED | `/chat/:familyId/:threadId` |
| CH-003 | Chat Settings | PLANNED | inline on CH-001 |
| CH-004 | Expired Conversation Notice | PLANNED | inline on CH-002 |

## K. FS-011 Family Rules & Policy Engine

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| RL-001 | Rules Dashboard | PLANNED | `/rules/:familyId` |
| RL-002 | Rule Creation | PLANNED | `/rules/:familyId/new` |
| RL-003 | Rule Detail | PLANNED | `/rules/:familyId/:ruleId` |
| RL-004 | Conflict Warning (inline) | PLANNED | inline on RL-003 |
| RL-005 | Effective Policy Preview | PLANNED | `/rules/:familyId/:ruleId/preview` |
| RL-006 | Rule History / Audit | PLANNED | inline on RL-003 |
| RL-007 | Rule Templates | PLANNED | inline on RL-002 |

## L. FS-012 Child Mode & Child Experience

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CM-001 | Child Mode Dashboard | PLANNED | `/child/:familyId/:childId` (upgrade) |
| CM-002 | Child Mode Lock | PLANNED | lock overlay |
| CM-003 | Parent Authorization (unlock) | PLANNED | `/requests/:familyId/unlock/:requestId` |
| CM-004 | My Exception Requests | PLANNED | `/child/:familyId/:childId/requests` |
| CM-005 | My Privacy View | PLANNED | `/child/:familyId/:childId/privacy` |

## M. FS-013 Couple Harmony

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CO-001 | Partner Linking Flow | PLANNED | `/couple/:familyId/link` |
| CO-002 | Couple Harmony Dashboard | PLANNED | `/couple/:familyId` |
| CO-003 | Permission Review | PLANNED | `/couple/:familyId/permissions` |
| CO-004 | Family Decisions | PLANNED | `/couple/:familyId/decisions` |
| CO-005 | Shared Routine Builder | PLANNED | `/couple/:familyId/routines/new` |
| CO-006 | Responsibility Board | PLANNED | `/couple/:familyId/responsibilities` |
| CO-007 | Co-Parent Handover | PLANNED | inline on CO-002 |

## N. FS-014 Primary Parent Dashboard & Unlinked Device

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| PD-001 | Unlinked Entry | PLANNED | `/` (no membership) |
| PD-002 | Create Family | PLANNED | `/family/create` |
| PD-003 | Join Existing Family | PLANNED | `/family/join/:invitationCode` |
| PD-004 | Parent Authentication | PLANNED | `/auth/confirm` |
| PD-005 | Primary Parent Dashboard | PLANNED | `/` (post-capability) |
| PD-006 | Family Profile | PLANNED | `/family/:familyId/profile` |
| PD-007 | Setup Checklist | PLANNED | `/family/:familyId/setup` |

## O. FS-015 Device Linking & Enrollment

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| DL-001 | Child Linking (QR) | PLANNED | `/safety/pairing/:familyId` (upgrade) |
| DL-002 | Child Linking (code) | PLANNED | `/safety/pairing/:familyId/code` |
| DL-003 | Child Enrollment Flow | PLANNED | `/enroll/:familyId/:code` |
| DL-004 | Enrollment Confirmation | PLANNED | `/enroll/:familyId/:code/confirm` |
| DL-005 | Spouse Device Linking | PLANNED | `/couple/:familyId/link-device` |
| DL-006 | Spouse Enrollment | PLANNED | `/couple/:familyId/enroll` |
| DL-007 | Spouse Role Selection | PLANNED | `/couple/:familyId/role` |
| DL-008 | Permission Onboarding | PLANNED | `/onboard/permissions` |
| DL-009 | Device Unlinking | PLANNED | `/settings/device/:deviceId/unlink` |
| DL-010 | Device Health Dashboard | PLANNED | `/settings/devices` |
| DL-011 | Replace / Transfer Device | PLANNED | `/settings/device/:deviceId/transfer` |

## P. FS-016 Startup & State Machine

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| ST-001 | Onboarding / Splash + Role Selection | PLANNED | splash → role gate |
| ST-002 | Feature Lock / Upgrade Gate | PLANNED | inline gate |
| ST-003 | Offline Startup | PLANNED | cold start |
| ST-004 | Role Landing Variants | PLANNED | per-role post-gate |
| ST-005 | What's New | PLANNED | `/whats-new` |

## Q. FS-001 Location & Geofencing

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| LO-001 | Family Map | COMPLETED | `/location/:familyId` |
| LO-002 | Member Location Details | COMPLETED | `/location/:familyId/:memberId` |
| LO-003 | Location History | COMPLETED | `/location/:familyId/:memberId/history` |
| LO-004 | Geofence List | COMPLETED | `/location/:familyId/geofences` |
| LO-005 | Create Geofence | COMPLETED | `/location/:familyId/geofences/new` |
| LO-006 | Edit Geofence | COMPLETED | `/location/:familyId/geofences/:gfId/edit` |
| LO-007 | Location Settings | COMPLETED | `/location/:familyId/settings` |
| LO-008 | Location Permission Onboarding | COMPLETED | `/onboard/location` |
| LO-009 | Location Sharing Status | COMPLETED | `/location/:familyId/sharing` |
| LO-010 | Location Alerts | COMPLETED | `/location/:familyId/alerts` |
| LO-011 | Location Privacy Information | COMPLETED | `/location/:familyId/privacy` |
| LO-012 | Offline Location State | COMPLETED | inline banner |
| LO-013 | Favorite Places | COMPLETED | `/location/:familyId/places` |
| LO-014 | Geofence Templates | COMPLETED | inline on LO-005 |
| LO-015 | Child Sharing Visibility | COMPLETED | `/child/:familyId/:childId/location-sharing` |

## R. Guardian AI Screens (Phase 11)

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| AI-001 | AI Insights Hub | PLANNED | `/insights/:familyId` |
| AI-002 | Risk Overview | PLANNED | `/insights/:familyId/risk` |
| AI-003 | Detection Review | PLANNED | `/insights/:familyId/detections` |
| AI-004 | Explanation View | PLANNED | `/insights/:familyId/detections/:id/explain` |
| AI-005 | Weekly Family Insight | PLANNED | `/insights/:familyId/weekly` |
| AI-006 | Copilot Suggestions | PLANNED | `/insights/:familyId/copilot` |
| AI-007 | Copilot Conversation | PLANNED | `/insights/:familyId/copilot/chat` |
| AI-008 | Copilot Settings | PLANNED | `/insights/:familyId/copilot/settings` |
| AI-009 | Smart Policy Proposal | PLANNED | `/insights/:familyId/proposals/:proposalId` |
| AI-010 | AI Transparency Center | PLANNED | `/insights/:familyId/transparency` |
| AI-011 | Weekly AI Digest | PLANNED | via RP-006 + `/insights/:familyId/digest` |
| AI-012 | Suggestion Outcomes | PLANNED | inline on AI-006 |
| AI-013 | Family Health Scorecard | PLANNED | `/insights/:familyId/scorecard` |

## S. Commercial Screens (Phase 13)

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CMR-001 | Plan Overview | PLANNED | `/subscription/:familyId` |
| CMR-002 | Upgrade Flow | PLANNED | `/subscription/:familyId/upgrade` |
| CMR-003 | Usage Limits | PLANNED | `/subscription/:familyId/limits` |
| CMR-004 | Billing & Receipts | PLANNED | `/subscription/:familyId/billing` |
| CMR-005 | Cancel / Pause Flow | PLANNED | `/subscription/:familyId/cancel` |

## Totals

| Group | Count |
| --- | --- |
| Baseline (implemented) | 14 |
| FS subsystems (FS-001…FS-016) | 135 |
| Guardian AI (Phase 11) | 13 |
| Commercial (Phase 13) | 5 |
| **Platform total** | **167 named screens + inline states (≈200 screen/states)** |
