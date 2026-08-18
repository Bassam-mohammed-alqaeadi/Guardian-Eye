# MASTER PHASE DEPENDENCY MAP

**Authoritative register of phase ordering from the current point onward.** Dependency types: **HARD** (cannot start before), **SOFT** (should follow, can overlap with care), **PARALLEL** (independent tracks), **AI** (feeds or consumes AI layers), **BACKEND** (touches backend contracts — prohibited unless marked NONE), **ANDROID** (requires platform capability research).

## Phase sequence

| Phase | Type | Hard dependencies | Soft dependencies | Backend dep | Android dep | AI relationship |
| --- | --- | --- | --- | --- | --- | --- |
| Phase 2: FS-002 Web Filtering | CURRENT | Design system (Phase 0/1) | — | NONE | NONE | emits web-safety events |
| Phase 3: FS-003 App Control + FS-015 Linking | NEXT | Phase 2 (UI patterns) | FS-015 can start in parallel (pairing repo ready) | NONE | DL-008 permission ladder uses docs/05 | none |
| Phase 4: FS-004 + FS-005 + FS-006 | AFTER NEXT | Phase 3 | FS-006 parallel (SOS pipeline ready) | NONE | SC capture/monitoring research | emits evidence events |
| Phase 5: FS-007 + FS-008 | AFTER NEXT | Phase 4, AI artifact review (human decision) | FS-008 after FS-007 consent patterns | NONE | audio research (docs/05) | **AI surface built early, model optional (fail-closed)** |
| Phase 6: FS-009/010/011/012/013 | LATER | Phase 5; M5/M8/M6 foundations | FS-010/FS-013 parallel with FS-009 | NONE | none | consumers of event streams |
| Phase 7: FS-014 + FS-016 | LATER | Phase 6 (aggregation surfaces need capability screens) | FS-016 entitlements doc needed (product decision) | NONE | none | gate for AI entitlements |
| Phase 8: FS-001 Location | LATER (parallel track) | Android permission research (docs/05) | can start anytime after Phase 2 | NONE | location/background research | emits location/geofence events |
| Phase 2.5: Journey integration | AFTER FS SET | All FS phases implemented | — | NONE | none | verifies event emission |
| Phase 9: Unified Event Layer | AFTER FS SET | All FS phases implemented | Phase 2.5 | NONE (registry only) | none | **FOUNDATIONAL: L1 input contract** |
| Phase 10: Guardian AI Foundation | FUTURE | Phase 9, model artifact review, eval corpus | on-device inference research | NONE | inference runtime research | bootstrap of all layers |
| Phase 11: AI Intelligence Layers | FUTURE | Phase 10 | — | NONE (cloud opt-in only) | none | THE intelligence system |
| Phase 12: AI Experiences | FUTURE | Phase 11 | — | NONE | none | productization |
| Phase 13: Commercial | FUTURE | Phase 11 (AI entitlements), Phase 7 (gates) | entitlements contract doc | Entitlement READS only | none | entitlement gating |
| Phase 14: Production Hardening | FINAL | All above | — | deploy config only | reboot/doze/background (docs/05 gap) | latency budgets |

## Dependency notes

- **Hard vs soft:** a soft dependency means the phase may start while its dependency is in flight only if no shared contract is touched; the moment a shared contract (provider signature, event type, route) is involved, it becomes hard.
- **No backend dependencies exist in the active roadmap.** Every phase consumes existing contracts. The only future backend-adjacent work is Phase 13 entitlement reads and Phase 14 deploy configuration — both marked explicitly.
- **AI phases are prepared, not blocked:** Phase 9's event registry and the FS phases' event emissions are built without any model existing; the AI layers plug into stable inputs later.
- **Android dependencies are research, not code:** `docs/05_android/` documents capture, monitoring, location, and permission research; no Android-native code changes are planned within this roadmap's scope.
- **GuardianEvent immutability:** existing event types are frozen; new phases append. This is a hard dependency of Phases 9–11.

## Parallel-work summary

Three tracks can run concurrently without contract conflicts: (1) the main FS sequence (Phases 2–8), (2) the location track (Phase 8, independent subsystem), and (3) Phase 9's event-registry design work (documentation + contract tests, no UI) once Phase 5 lands. AI work (Phases 10–12) is strictly sequential after Phase 9.
