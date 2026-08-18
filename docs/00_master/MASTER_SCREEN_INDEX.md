# MASTER SCREEN INDEX — Guardian Eye Pro (~150 screens/states)

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
| WF-002 | Content Categories | PLANNED | `/safety/web/:familyId/categories` | — |
| WF-003 | Website Blocklist | PLANNED | `/safety/web/:familyId/blocklist` | — |
| WF-004 | Web Filtering Settings | PLANNED | `/safety/web/:familyId/settings` | — |

## C. FS-003 Application System

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| AC-001 | Application Control Dashboard | PLANNED | `/apps/:familyId` |
| AC-002 | Installed Applications | PLANNED | `/apps/:familyId/:childId` |
| AC-003 | Application Details | PLANNED | `/apps/:familyId/:childId/:appId` |
| AC-004 | Allowlist | PLANNED | `/apps/:familyId/allowlist` |

## D. FS-004 Screenshot & Camera Control

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| SC-001 | Screen & Camera Dashboard | PLANNED | `/monitoring/:familyId` |
| SC-002 | Screen Monitoring (timeline) | PLANNED | `/monitoring/:familyId/screenshots` |
| SC-003 | Screenshot Viewer | PLANNED | `/monitoring/:familyId/screenshots/:shotId` |
| SC-004 | Live Screen Session | PLANNED | `/monitoring/:familyId/live` |
| SC-005 | Camera Control | PLANNED | `/monitoring/:familyId/camera` |
| SC-006 | Child Active Session | PLANNED | `/monitoring/:familyId/:childId/session` |

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

## F. FS-006 SOS & Emergency

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| SO-001 | SOS Dashboard | PLANNED | `/sos/:familyId` |
| SO-002 | SOS Activation | PLANNED | `/sos/:familyId/activate` |
| SO-003 | Active SOS | PLANNED | `/sos/:familyId/active` |
| SO-004 | Emergency Location | PLANNED | `/sos/:familyId/location` |
| SO-005 | Emergency Alert (deep link) | PLANNED | `/sos/:familyId/alert/:alertId` |
| SO-006 | Acknowledgement History | PLANNED | `/sos/:familyId/ack` |

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

## I. FS-009 Reports & PDF

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| RP-001 | Reports Dashboard | PLANNED | `/reports/:familyId` |
| RP-002 | Report Builder | PLANNED | `/reports/:familyId/build` |
| RP-003 | Generation Progress | PLANNED | `/reports/:familyId/build/progress/:jobId` |
| RP-004 | Single Child Report | PLANNED | `/reports/:familyId/report/:reportId` |
| RP-005 | All-Children Report | PLANNED | `/reports/:familyId/report/:reportId/all` |

## J. FS-010 Ephemeral Family Chat

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CH-001 | Chat List | PLANNED | `/chat/:familyId` |
| CH-002 | Chat Screen | PLANNED | `/chat/:familyId/:threadId` |

## K. FS-011 Family Rules & Policy Engine

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| RL-001 | Rules Dashboard | PLANNED | `/rules/:familyId` |
| RL-002 | Rule Creation | PLANNED | `/rules/:familyId/new` |
| RL-003 | Rule Detail | PLANNED | `/rules/:familyId/:ruleId` |
| RL-004 | Conflict Warning (inline) | PLANNED | inline on RL-003 |
| RL-005 | Effective Policy Preview | PLANNED | `/rules/:familyId/:ruleId/preview` |

## L. FS-012 Child Mode & Child Experience

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CM-001 | Child Mode Dashboard | PLANNED | `/child/:familyId/:childId` (upgrade) |
| CM-002 | Child Mode Lock | PLANNED | lock overlay |
| CM-003 | Parent Authorization (unlock) | PLANNED | `/requests/:familyId/unlock/:requestId` |

## M. FS-013 Couple Harmony

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CO-001 | Partner Linking Flow | PLANNED | `/couple/:familyId/link` |
| CO-002 | Couple Harmony Dashboard | PLANNED | `/couple/:familyId` |
| CO-003 | Permission Review | PLANNED | `/couple/:familyId/permissions` |
| CO-004 | Family Decisions | PLANNED | `/couple/:familyId/decisions` |

## N. FS-014 Primary Parent Dashboard & Unlinked Device

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| PD-001 | Unlinked Entry | PLANNED | `/` (no membership) |
| PD-002 | Create Family | PLANNED | `/family/create` |
| PD-003 | Join Existing Family | PLANNED | `/family/join/:invitationCode` |
| PD-004 | Parent Authentication | PLANNED | `/auth/confirm` |
| PD-005 | Primary Parent Dashboard | PLANNED | `/` (post-capability) |

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

## P. FS-016 Startup & State Machine

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| ST-001 | Onboarding / Splash + Role Selection | PLANNED | splash → role gate |
| ST-002 | Feature Lock / Upgrade Gate | PLANNED | inline gate |
| ST-003 | Offline Startup | PLANNED | cold start |

## Q. FS-001 Location & Geofencing

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| LO-001 | Family Map | PLANNED | `/location/:familyId` |
| LO-002 | Member Location Details | PLANNED | `/location/:familyId/:memberId` |
| LO-003 | Location History | PLANNED | `/location/:familyId/:memberId/history` |
| LO-004 | Geofence List | PLANNED | `/location/:familyId/geofences` |
| LO-005 | Create Geofence | PLANNED | `/location/:familyId/geofences/new` |
| LO-006 | Edit Geofence | PLANNED | `/location/:familyId/geofences/:gfId/edit` |
| LO-007 | Location Settings | PLANNED | `/location/:familyId/settings` |
| LO-008 | Location Permission Onboarding | PLANNED | `/onboard/location` |
| LO-009 | Location Sharing Status | PLANNED | `/location/:familyId/sharing` |
| LO-010 | Location Alerts | PLANNED | `/location/:familyId/alerts` |
| LO-011 | Location Privacy Information | PLANNED | `/location/:familyId/privacy` |
| LO-012 | Offline Location State | PLANNED | inline banner |

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

## S. Commercial Screens (Phase 13)

| Screen ID | Name | Status | Route |
| --- | --- | --- | --- |
| CMR-001 | Plan Overview | PLANNED | `/subscription/:familyId` |
| CMR-002 | Upgrade Flow | PLANNED | `/subscription/:familyId/upgrade` |
| CMR-003 | Usage Limits | PLANNED | `/subscription/:familyId/limits` |
| CMR-004 | Billing & Receipts | PLANNED | `/subscription/:familyId/billing` |

## Totals

| Group | Count |
| --- | --- |
| Baseline (implemented) | 14 |
| FS subsystems (FS-001…FS-016) | 95 |
| Guardian AI (Phase 11) | 10 |
| Commercial (Phase 13) | 4 |
| **Platform total** | **123 named screens + inline states (≈150 screen/states)** |
