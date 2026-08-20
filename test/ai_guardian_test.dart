// Guardian AI (9-layer deterministic system) — honest-state checks:
// normalization never fabricates signals; consent gates block processing
// for non-consented privacy classes; the risk engine scores deterministically
// with no data (safe/baseline); JSON round-trips preserve every field; and
// the repository persists L1 events, normalized signals and L2-L9 outputs
// through the real v28 SQLite schema.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/ai_repository.dart';
import 'package:guardian_ai/data/family_event_registry_repository.dart';
import 'package:guardian_ai/application/guardian_ai_engine.dart';
import 'package:guardian_ai/domain/family_events.dart';
import 'package:guardian_ai/domain/guardian_ai_models.dart';
import 'package:guardian_ai/domain/guardian_event.dart';

Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('ai-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}

final DateTime _seededAt = DateTime.utc(2025, 7, 1, 10, 0, 0);

GuardianFeatureEvent _event({
  required String eventId,
  required GuardianEventType type,
  GuardianPrivacyClass privacyClass = GuardianPrivacyClass.operational,
  Map<String, String> attributes = const {},
}) =>
    GuardianFeatureEvent(
      id: eventId,
      familyId: 'family-ai',
      type: type,
      occurredAt: _seededAt,
      privacyClass: privacyClass,
      childId: 'child-ai',
      attributes: attributes,
      createdAt: _seededAt,
    );

void main() {
  group('L1 — event normalization honesty', () {
    test('known event types map to canonical signal keys', () {
      final normalizer = const EventNormalizer();
      expect(
          normalizer.signalKeyFor(
              _event(eventId: 'e1', type: GuardianEventType.sosCreated)),
          GuardianSignalKeys.sosActivated);
      expect(
          normalizer.signalKeyFor(
              _event(eventId: 'e2', type: GuardianEventType.usageObserved)),
          GuardianSignalKeys.appSession);
      expect(
          normalizer.signalKeyFor(_event(
              eventId: 'e3',
              type: GuardianEventType.incidentCreated,
              attributes: {'domain': 'content'})),
          GuardianSignalKeys.screenshotFlagged);
      expect(
          normalizer.signalKeyFor(_event(
              eventId: 'e4',
              type: GuardianEventType.incidentCreated,
              attributes: {'domain': 'geofence_entry'})),
          GuardianSignalKeys.geofenceEntry);
      expect(
          normalizer.signalKeyFor(_event(
              eventId: 'e5', type: GuardianEventType.enforcementApplied)),
          GuardianSignalKeys.usageLimitEvaluated);
      expect(
          normalizer.signalKeyFor(
              _event(eventId: 'e6', type: GuardianEventType.deviceEnrolled)),
          GuardianSignalKeys.deviceStateTransition);
    });

    test('unknown event type rejects to "unmapped", never invents a signal',
        () {
      final normalizer = const EventNormalizer();
      final signal = normalizer.normalizeOne(
          _event(eventId: 'e7', type: GuardianEventType.familyCreated),
          const {},
          (_) => true);
      expect(signal.outcome, EventNormalizationOutcome.rejected);
      expect(signal.signalKey, 'unmapped');
      expect(signal.weight, 0);
      expect(signal.rejectReason, isNotNull);
    });

    test('non-consented privacy class blocks processing honestly', () {
      final normalizer = const EventNormalizer();
      final consent =
          (GuardianPrivacyClass c) => c == GuardianPrivacyClass.operational;
      final signal = normalizer.normalizeOne(
          _event(
              eventId: 'e8',
              type: GuardianEventType.incidentCreated,
              privacyClass: GuardianPrivacyClass.locationSensitive),
          const {},
          consent);
      expect(signal.outcome, EventNormalizationOutcome.consentBlocked);
      expect(signal.weight, 0);
    });

    test('consented operational events normalize with positive weight', () {
      final normalizer = const EventNormalizer();
      final signal = normalizer.normalizeOne(
          _event(eventId: 'e9', type: GuardianEventType.sosCreated),
          const {},
          (_) => true);
      expect(signal.outcome, EventNormalizationOutcome.normalized);
      expect(signal.weight, greaterThan(0));
      expect(signal.isProcessable, true);
    });
  });

  group('L1 — AiConsentScope', () {
    test('defaults fail closed for sensitive classes', () {
      const scope = AiConsentScope();
      expect(scope.isConsented(GuardianPrivacyClass.operational), true);
      expect(scope.isConsented(GuardianPrivacyClass.behavioural), false);
      expect(scope.isConsented(GuardianPrivacyClass.locationSensitive), false);
      expect(scope.isConsented(GuardianPrivacyClass.biometric), false);
    });

    test('copyWith preserves family id and enables classes explicitly', () {
      final scope = const AiConsentScope(familyId: 'family-ai')
          .copyWith(processBehavioural: true, processLocation: false);
      expect(scope.familyId, 'family-ai');
      expect(scope.isConsented(GuardianPrivacyClass.behavioural), true);
      expect(scope.isConsented(GuardianPrivacyClass.operational), true);
    });
  });

  group('L2-L9 — deterministic engine honesty', () {
    final engine = GuardianAiDeterministicEngine(
        modelAvailability: AiModelAvailabilitySource(modelVersion: 'none'));

    test('empty signal set evaluates every child to safe risk', () {
      final profiles = engine.computeBehaviorProfiles(
          const [],
          const ['child-ai'],
          _seededAt.subtract(const Duration(days: 7)),
          _seededAt);
      final states = engine.evaluateChildRisk(profiles, const []);
      expect(states, hasLength(1));
      expect(states.first.level, AiRiskLevel.safe);
      expect(states.first.deterministicOnly, true);
    });

    test('health scorecard with no data returns a baseline score', () {
      final card = engine.healthScorecard('family-ai', const []);
      expect(card.overall, inInclusiveRange(0, 100));
      expect(card.dataSufficiency, AiDataSufficiency.insufficient);
      expect(card.dimensions, isNotEmpty);
    });

    test('sos-heavy week escalates deterministically to alert', () {
      final normalizer = const EventNormalizer();
      final events = List.generate(12,
          (i) => _event(eventId: 'sos-$i', type: GuardianEventType.sosCreated));
      final signals = normalizer.normalize(events, const {}, (_) => true);
      final profiles = engine.computeBehaviorProfiles(
          signals,
          const ['child-ai'],
          _seededAt.subtract(const Duration(days: 7)),
          _seededAt);
      final states = engine.evaluateChildRisk(profiles, signals);
      expect(states.first.level, AiRiskLevel.alert);
    });
  });

  group('L2-L9 — model JSON round-trips', () {
    test('AiRiskState persists every field through JSON', () {
      final state = AiRiskState(
        id: 'risk-1',
        familyId: 'family-ai',
        childId: 'child-ai',
        level: AiRiskLevel.watch,
        deterministicOnly: true,
        contributors: const [
          RiskContributor(
              signalKey: 'sos.activated',
              weight: 1.0,
              labelKey: 'aiContributorSos'),
        ],
        evaluatedAt: _seededAt,
      );
      final restored = AiRiskState.fromJson(state.toJson());
      expect(restored.id, state.id);
      expect(restored.level, AiRiskLevel.watch);
      expect(restored.deterministicOnly, true);
      expect(restored.contributors.first.signalKey, 'sos.activated');
      expect(restored.evaluatedAt, _seededAt);
    });

    test('FamilyInsight and CopilotSuggestion round-trip through JSON', () {
      final insight = FamilyInsight(
        id: 'insight-1',
        familyId: 'family-ai',
        period: AiPeriod.weekly,
        periodStart: _seededAt,
        periodEnd: _seededAt.add(const Duration(days: 7)),
        titleKey: 'aiInsightNightUsageUp',
        bodyKey: 'aiInsightNightUsageUpBody',
        metrics: const [],
        dataSufficiency: AiDataSufficiency.partial,
      );
      final restoredInsight = FamilyInsight.fromJson(insight.toJson());
      expect(restoredInsight.titleKey, insight.titleKey);
      expect(restoredInsight.dataSufficiency, AiDataSufficiency.partial);

      final suggestion = CopilotSuggestion(
        id: 'sug-1',
        familyId: 'family-ai',
        titleKey: 'aiSuggestionReviewNightRoutine',
        bodyKey: 'aiSuggestionBody',
        rationaleKey: 'aiSuggestionRationale',
        status: CopilotSuggestionStatus.open,
        createdAt: _seededAt,
        appliesToChildIds: const ['child-ai'],
        effectAfterDays: SuggestionEffect.none,
      );
      final restoredSuggestion =
          CopilotSuggestion.fromJson(suggestion.toJson());
      expect(restoredSuggestion.status, CopilotSuggestionStatus.open);
      expect(restoredSuggestion.id, 'sug-1');
    });
  });

  group('AI repository round-trips', () {
    late GuardianDatabase database;
    late AiInsightRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      final db = await database.database;
      await db.insert('families', {
        'id': 'family-ai',
        'name': 'AI Family',
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('family_members', {
        'id': 'parent-ai',
        'family_id': 'family-ai',
        'display_name': 'Parent',
        'role': 'primary_parent',
        'status': 'active',
        'created_at': _seededAt.toIso8601String(),
      });
      await db.insert('family_members', {
        'id': 'child-ai',
        'family_id': 'family-ai',
        'display_name': 'Child',
        'role': 'child',
        'status': 'active',
        'created_at': _seededAt.toIso8601String(),
      });
      repo = AiInsightRepository(database: database);
    });

    test('events and normalized signals persist through the real schema',
        () async {
      await repo.registerEvent(
          _event(eventId: 'rt-1', type: GuardianEventType.sosCreated));
      await repo.insertSignal(NormalizedSignal(
        id: 'sig-1',
        familyId: 'family-ai',
        childId: 'child-ai',
        signalKey: GuardianSignalKeys.sosActivated,
        weight: 1.0,
        occurredAt: _seededAt,
        outcome: EventNormalizationOutcome.normalized,
        privacyClass: GuardianPrivacyClass.operational,
      ));
      expect((await repo.listSignals(familyId: 'family-ai')).length, 1);
      expect((await repo.listDetections(familyId: 'family-ai')).length, 0);
    });

    test('detection round-trip with markReviewed', () async {
      await repo.recordDetection(AiDetectionResult(
        id: 'det-1',
        familyId: 'family-ai',
        childId: 'child-ai',
        category: 'test.category',
        severityBand: AiSeverityBand.informational,
        confidenceBand: AiConfidenceBand.medium,
        modelVersion: 'none',
        source: 'on_device',
        detectedAt: _seededAt,
        referenceId: 'det-ref-1',
        reviewed: false,
      ));
      final before = await repo.listDetections(familyId: 'family-ai');
      expect(before.first.reviewed, false);
      await repo.markDetectionReviewed('family-ai', 'det-1');
      final after = await repo.listDetections(familyId: 'family-ai');
      expect(after.first.reviewed, true);
    });

    test('deleteFamilyAiData wipes L1 and L2-L9 outputs together', () async {
      await repo.registerEvent(
          _event(eventId: 'wipe-1', type: GuardianEventType.sosCreated));
      await repo.recordRiskStates([
        AiRiskState(
          id: 'risk-wipe',
          familyId: 'family-ai',
          childId: 'child-ai',
          level: AiRiskLevel.safe,
          deterministicOnly: true,
          contributors: const [],
          evaluatedAt: _seededAt,
        )
      ]);
      await repo.deleteFamilyAiData('family-ai');
      final db = await database.database;
      expect((await db.query('family_events')).length, 0);
      expect((await db.query('normalized_signals')).length, 0);
      expect((await db.query('ai_risk_states')).length, 0);
    });
  });
}
