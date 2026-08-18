# MASTER NAVIGATION MAP

**Authoritative register of every route.** Current shell: `GoRouter` with a `ShellRoute` (five tabs: Home `/`, Children `/family/:familyId`, DailySafety `/safety/daily/:familyId`, SafetyTimeline `/timeline/:familyId`, Settings `/settings`) wrapping all routes. All navigation uses `context.push`/`context.pop`; unknown paths land on the verified dead-route surface (`m1_shell_test`). Family scoping: routes take `:familyId` and resolve via `_familyIdOf` in `app_router.dart`.

## A. Current routes (implemented, TESTED/GREEN)

| Route | Screen ID | Subsystem | Entry requirement | Permission | Family state | Exit / back behavior | Deep link |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `/` | BX-001 | Baseline | signed-in | member | family or setup | bottom-nav Home | no |
| `/child/:familyId/:childId` | BX-002 | Baseline | member | view children | family | back to nav | no |
| `/child/:familyId/:childId/policies` | BX-003 | Baseline | parent/owner | manage policies | family | back to child | no |
| `/family/:familyId` | BX-004 | Baseline | member | view family | family | bottom-nav Children | no |
| `/safety/policies/:familyId` | BX-005 | Baseline | parent/owner | manage policies | family | back | no |
| `/safety/device-status/:familyId` | BX-006 | Baseline | parent/owner | view devices | family | back | no |
| `/safety/daily/:familyId` | BX-007 | Baseline | member | view daily safety | family | bottom-nav DailySafety | no |
| `/timeline/:familyId` | BX-008 | Baseline | member | view timeline | family | bottom-nav SafetyTimeline | no |
| `/requests/:familyId` | BX-009 | Baseline | parent/owner | review requests | family | back | no |
| `/settings` | BX-010 | Baseline | signed-in | — | any | bottom-nav Settings | no |
| `/firebase-session` | BX-011 | Baseline | signed-in | — | any | back | no |
| `/safety/pairing/:familyId` | BX-012 | Baseline | parent/owner | pair device | family | back | no |
| `/device-link/:familyId` | BX-013 | Baseline | redeeming child | redeem code | family | back | yes (codes) |
| `/safety/permissions` | BX-014 | Baseline | device actor | — | any | back | no |

## B. Future routes by subsystem

### FS-002 Web Filtering
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/safety/web/:familyId` | WF-001 | member | view web policy | no |
| `/safety/web/:familyId/categories` | WF-002 | parent/owner | manage policies | no |
| `/safety/web/:familyId/blocklist` | WF-003 | parent/owner | manage policies | no |
| `/safety/web/:familyId/settings` | WF-004 | parent/owner | manage policies | no |

### FS-003 Application System
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/apps/:familyId` | AC-001 | member | view usage | no |
| `/apps/:familyId/:childId` | AC-002 | parent/owner | manage apps | no |
| `/apps/:familyId/:childId/:appId` | AC-003 | parent/owner | manage apps | no |
| `/apps/:familyId/allowlist` | AC-004 | parent/owner | manage policies | no |

### FS-004 Screenshot & Camera
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/monitoring/:familyId` | SC-001 | parent/owner | view monitoring | no |
| `/monitoring/:familyId/screenshots` | SC-002 | parent/owner | view monitoring | no |
| `/monitoring/:familyId/screenshots/:shotId` | SC-003 | parent/owner | view monitoring | yes |
| `/monitoring/:familyId/live` | SC-004 | parent/owner | monitor live | no |
| `/monitoring/:familyId/camera` | SC-005 | parent/owner + spouse consent | monitor camera | no |
| `/monitoring/:familyId/:childId/session` | SC-006 | parent/owner | view devices | no |

### FS-005 Custom Modes
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/modes/:familyId` | MD-001 | parent/owner | manage modes | no |
| `/modes/:familyId/:modeId` | MD-002 | parent/owner | manage modes | no |
| `/modes/:familyId/new` | MD-003 | parent/owner | manage policies | no |
| `/modes/:familyId/:modeId/edit` | MD-004 | parent/owner | manage policies | no |
| `/modes/:familyId/:modeId/schedule` | MD-005 | parent/owner | manage policies | no |
| `/modes/:familyId/:modeId/children` | MD-006 | parent/owner | manage policies | no |
| `/modes/:familyId/:modeId/history` | MD-007 | parent/owner | view history | no |
| `/child/:familyId/:childId/mode` | MD-008 | child self-scope | fail-closed | no |

### FS-006 SOS
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/sos/:familyId` | SO-001 | member | view SOS | no |
| `/sos/:familyId/activate` | SO-002 | member (role-checked by pipeline) | trigger SOS | no |
| `/sos/:familyId/active` | SO-003 | activator/parents | view SOS | no |
| `/sos/:familyId/location` | SO-004 | recipients/parents | view location | no |
| `/sos/:familyId/alert/:alertId` | SO-005 | SOS recipient | acknowledge | **yes (FCM)** |
| `/sos/:familyId/ack` | SO-006 | parents | view history | no |

### FS-007 Offline AI Safety
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/ai-safety/:familyId` | AS-001 | parent/owner | view safety AI | no |
| `/ai-safety/:familyId/reports` | AS-002 | parent/owner | view safety | no |
| `/ai-safety/:familyId/reports/:reportId` | AS-003 | parent/owner | view safety | no |
| `/ai-safety/:familyId/evidence/:evidenceId` | AS-004 | parent/owner | view evidence | no |
| `/ai-safety/:familyId/dictionary` | AS-005 | parent/owner | manage dictionary | no |
| `/ai-safety/:familyId/settings` | AS-006 | parent/owner | manage policies | no |
| `/child/:familyId/:childId/safety` | AS-007 | child self-scope | fail-closed | no |

### FS-008 One-Way Audio
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/audio/:familyId` | AU-001 | parent/owner | audio monitor | no |
| `/audio/:familyId/auth` | AU-002 | parent/owner + sensitive-action flag | audio monitor | no |
| `/audio/:familyId/listening/connecting` | AU-003 | as AU-001 | — | no |
| `/audio/:familyId/listening/active` | AU-004 | as AU-001 | — | no |
| `/audio/:familyId/listening/reconnecting` | AU-005 | as AU-001 | — | no |
| `/audio/:familyId/listening/unavailable` | AU-006 | as AU-001 | — | no |
| `/audio/:familyId/settings/policy` | AU-007 | parent/owner | manage policies | no |
| `/audio/:familyId/settings/duration` | AU-008 | parent/owner | manage policies | no |
| `/audio/:familyId/settings/network` | AU-009 | parent/owner | manage policies | no |
| `/audio/:familyId/history` | AU-010 | parent/owner | view history | no |
| `/audio/:familyId/settings/consent` | AU-011 | parent/owner | manage consent | no |
| `/child/:familyId/:childId/audio-policy` | AU-012 | child self-scope | fail-closed | no |

### FS-009 Reports
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/reports/:familyId` | RP-001 | parent/owner | view reports | no |
| `/reports/:familyId/build` | RP-002 | parent/owner | generate reports | no |
| `/reports/:familyId/build/progress/:jobId` | RP-003 | parent/owner | — | no |
| `/reports/:familyId/report/:reportId` | RP-004 | parent/owner | view reports | no |
| `/reports/:familyId/report/:reportId/all` | RP-005 | parent/owner | view reports | no |

### FS-010 Chat
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/chat/:familyId` | CH-001 | member | chat | no |
| `/chat/:familyId/:threadId` | CH-002 | member (thread-scoped) | chat | no |

### FS-011 Rules
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/rules/:familyId` | RL-001 | parent/owner | manage policies | no |
| `/rules/:familyId/new` | RL-002 | parent/owner | manage policies | no |
| `/rules/:familyId/:ruleId` | RL-003 | parent/owner | manage policies | no |
| `/rules/:familyId/:ruleId/preview` | RL-005 | parent/owner | manage policies | no |

### FS-013 Couple Harmony
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/couple/:familyId/link` | CO-001 | owner | invite/link | no |
| `/couple/:familyId` | CO-002 | spouse/co-parent | symmetric | no |
| `/couple/:familyId/permissions` | CO-003 | spouse/co-parent | symmetric | no |
| `/couple/:familyId/decisions` | CO-004 | spouse/co-parent | symmetric | no |
| `/couple/:familyId/link-device` | DL-005 | spouse | link device | no |
| `/couple/:familyId/enroll` | DL-006 | spouse | enroll | no |
| `/couple/:familyId/role` | DL-007 | owner | role assignment | no |

### FS-014 Onboarding & Primary Dashboard
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/family/create` | PD-002 | account holder, no family | — | no |
| `/family/join/:invitationCode` | PD-003 | account holder | — | **yes (invites)** |
| `/auth/confirm` | PD-004 | account holder | — | no |

### FS-015 Enrollment & Unlinking
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/safety/pairing/:familyId/code` | DL-002 | parent/owner | pair device | no |
| `/enroll/:familyId/:code` | DL-003 | parent/owner | enroll | no |
| `/enroll/:familyId/:code/confirm` | DL-004 | parent/owner | enroll | no |
| `/onboard/permissions` | DL-008 | device actor | — | no |
| `/settings/device/:deviceId/unlink` | DL-009 | owner | revoke | no |

### FS-001 Location
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/location/:familyId` | LO-001 | parent/owner | view location | no |
| `/location/:familyId/:memberId` | LO-002 | parent/owner | view location | no |
| `/location/:familyId/:memberId/history` | LO-003 | parent/owner | view location | no |
| `/location/:familyId/geofences` | LO-004 | parent/owner | manage geofences | no |
| `/location/:familyId/geofences/new` | LO-005 | parent/owner | manage geofences | no |
| `/location/:familyId/geofences/:gfId/edit` | LO-006 | parent/owner | manage geofences | no |
| `/location/:familyId/settings` | LO-007 | parent/owner | manage policies | no |
| `/onboard/location` | LO-008 | device actor | — | no |
| `/location/:familyId/sharing` | LO-009 | member (self-scope + parent) | view sharing | no |
| `/location/:familyId/alerts` | LO-010 | parent/owner | view alerts | no |
| `/location/:familyId/privacy` | LO-011 | member | — | no |

### Guardian AI (Phase 11)
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/insights/:familyId` | AI-001 | parent/owner | view insights | no |
| `/insights/:familyId/risk` | AI-002 | parent/owner | view insights | no |
| `/insights/:familyId/detections` | AI-003 | parent/owner | review detections | no |
| `/insights/:familyId/detections/:id/explain` | AI-004 | parent/owner | view explanations | no |
| `/insights/:familyId/weekly` | AI-005 | parent/owner | view insights | no |
| `/insights/:familyId/copilot` | AI-006 | parent/owner + AI entitlement | use copilot | no |
| `/insights/:familyId/copilot/chat` | AI-007 | parent/owner + AI entitlement | use copilot | no |
| `/insights/:familyId/copilot/settings` | AI-008 | parent/owner | manage AI settings | no |
| `/insights/:familyId/proposals/:proposalId` | AI-009 | parent/owner | approve proposals | no |
| `/insights/:familyId/transparency` | AI-010 | parent/owner | view transparency | no |

### Commercial (Phase 13)
| Route | Screen ID | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- |
| `/subscription/:familyId` | CMR-001 | owner | view subscription | no |
| `/subscription/:familyId/upgrade` | CMR-002 | owner | billing | no |
| `/subscription/:familyId/limits` | CMR-003 | owner | view limits | no |
| `/subscription/:familyId/billing` | CMR-004 | owner | billing | no |
| `/subscription/:familyId/cancel` | CMR-005 | owner | billing | no |

### Gap-closure route additions (all subsystems, per MASTER_DEVELOPMENT_PLAN.md §6)
| Route | Screen ID | Subsystem | Entry requirement | Permission | Deep link |
| --- | --- | --- | --- | --- | --- |
| `/safety/web/:familyId/history` | WF-005 | FS-002 | parent/owner | view web policy | no |
| `/safety/web/:familyId/history/:hitId` | WF-006 | FS-002 | parent/owner | view web policy | no |
| `/safety/web/:familyId/history/:hitId/allow` | WF-007 | FS-002 | parent/owner | manage policies | no |
| `/safety/web/:familyId/allowlist` | WF-008 | FS-002 | parent/owner | manage policies | no |
| `/safety/web/:familyId/:childId` | WF-009 | FS-002 | parent/owner | manage policies | no |
| device-side `/blocked` | WF-010 | FS-002 | child device | — | **yes (enforcement)** |
| `/apps/:familyId/:childId/:appId/usage` | AC-005 | FS-003 | parent/owner | view usage | no |
| `/apps/:familyId/:childId/:appId/alerts` | AC-006 | FS-003 | parent/owner | manage policies | no |
| `/apps/:familyId/ratings` | AC-007 | FS-003 | parent/owner | manage policies | no |
| `/apps/:familyId/history` | AC-008 | FS-003 | parent/owner | view usage | no |
| `/monitoring/:familyId/requests` | SC-007 | FS-004 | parent/owner | view monitoring | no |
| `/monitoring/:familyId/schedule` | SC-008 | FS-004 | parent/owner | manage policies | no |
| `/monitoring/:familyId/evidence` | SC-009 | FS-004 | parent/owner | review evidence | no |
| `/modes/:familyId/:modeId/template` | MD-009 | FS-005 | parent/owner | manage policies | no |
| `/modes/:familyId/:modeId/conflict` | MD-010 | FS-005 | parent/owner | manage policies | no |
| `/sos/:familyId/recipients` | SO-007 | FS-006 | parent/owner | manage SOS | no |
| `/sos/:familyId/drill` | SO-008 | FS-006 | member (drill-gated) | trigger SOS | no |
| `/ai-safety/:familyId/trend` | AS-008 | FS-007 | parent/owner | view safety | no |
| `/ai-safety/:familyId/templates` | AS-009 | FS-007 | parent/owner | manage dictionary | no |
| `/audio/:familyId/settings/keywords` | AU-014 | FS-008 | parent/owner | manage policies | no |
| `/reports/:familyId/schedule` | RP-006 | FS-009 | parent/owner | generate reports | no |
| `/chat/:familyId/:threadId/settings` | CH-003 | FS-010 | member | chat | no |
| `/rules/:familyId/:ruleId/audit` | RL-006 | FS-011 | parent/owner | view history | no |
| `/rules/:familyId/template` | RL-007 | FS-011 | parent/owner | manage policies | no |
| `/child/:familyId/:childId/requests` | CM-004 | FS-012 | child self-scope | fail-closed | no |
| `/child/:familyId/:childId/privacy` | CM-005 | FS-012 | child self-scope | fail-closed | no |
| `/couple/:familyId/routines/new` | CO-005 | FS-013 | spouse/co-parent | symmetric | no |
| `/couple/:familyId/responsibilities` | CO-006 | FS-013 | spouse/co-parent | symmetric | no |
| `/couple/:familyId/handover` | CO-007 | FS-013 | spouse/co-parent | symmetric | no |
| `/family/:familyId/profile` | PD-006 | FS-014 | member | view family | no |
| `/family/:familyId/setup` | PD-007 | FS-014 | parent/owner | manage family | no |
| `/settings/devices` | DL-010 | FS-015 | parent/owner | view devices | no |
| `/settings/device/:deviceId/transfer` | DL-011 | FS-015 | parent/owner | manage devices | no |
| `/whats-new` | ST-005 | FS-016 | any member | — | no |
| `/location/:familyId/places` | LO-013 | FS-001 | parent/owner | manage geofences | no |
| `/location/:familyId/places/template` | LO-014 | FS-001 | parent/owner | manage geofences | no |
| `/child/:familyId/:childId/location-sharing` | LO-015 | FS-001 | child self-scope | fail-closed | no |
| `/insights/:familyId/digest` | AI-011 | AI Phase 11 | parent/owner + entitlement | view insights | no |
| `/insights/:familyId/outcomes` | AI-012 | AI Phase 11 | parent/owner + entitlement | view insights | no |
| `/insights/:familyId/scorecard` | AI-013 | AI Phase 11 | parent/owner + entitlement | view insights | no |

**Inline screens (no dedicated route):** ST-004 role landings (post-gate routing wrappers), CH-004 expired notice (inline banner), RL-004 conflict warning (inline card), MD-009 templates (inline on MD-003), AS-009 dictionary templates (inline on AS-005), AU-013 session notes (inline on AU-010), RP-007 report share (inline share sheet), CM-004/CO-007 also surface inline — all are documented inside their parent screens in the master plan.

## C. Navigation rules (apply to every future route)

1. Every route registers in `app_router.dart` inside the existing ShellRoute; tab routes carry `:familyId`; leaf routes derive the family from the path.
2. The dead-route guard remains: any unregistered path resolves to the not-found surface (verified by `m1_shell_test`).
3. Deep links exist only where the table says yes: redemption codes, SOS alerts, invitation codes.
4. No screen ever navigates to a route the actor cannot enter; unauthorized entries render `GuardianStateView` with an escape action.
5. Back behavior is always the platform `Navigator.pop` (no custom stacks); the shell back never exits the app on a tab route.
