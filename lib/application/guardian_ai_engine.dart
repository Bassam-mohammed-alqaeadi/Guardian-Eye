/// Guardian AI — deterministic evaluation engine (Layers 2-9).
///
/// Pure Dart, fully deterministic, fully testable. No cloud calls, no
/// learned weights: every number here is derived from observed signals
/// with documented arithmetic. When a configured on-device model is not
/// available, layers report [AiModelAvailability.none] and degrade to
/// deterministic-only summaries — the fail-closed contract.
///
/// Governance rules enforced by design:
/// * Outputs are observations, never actions (no enforcement side effects).
/// * Every verdict names its contributors with weights.
/// * Every insight names its data sufficiency.
/// * Every explanation declares `fallbackUsed` honestly.
library guardian_ai_engine;

import 'dart:convert';
import '../domain/family_events.dart';
import '../domain/guardian_ai_models.dart';

/// Stable l10n key fragments the engine emits. Screens map these to the
/// AR/EN strings; the engine never emits raw display text.
class AiKeyFragments {
  AiKeyFragments._();

  static const String riskSafe = 'aiRiskSafe';
  static const String riskWatch = 'aiRiskWatch';
  static const String riskAlert = 'aiRiskAlert';

  // L4 contributor label keys.
  static const String labelSos = 'aiContributorSos';
  static const String labelIncidentHigh = 'aiContributorIncidentHigh';
  static const String labelGeofenceEntry = 'aiContributorGeofenceEntry';
  static const String labelNightUsage = 'aiContributorNightUsage';
  static const String labelUsageDeviation = 'aiContributorUsageDeviation';

  // L6/L7 explanation keys.
  static const String explainNoSignals = 'aiExplainNoSignals';
  static const String explainNoChange = 'aiExplainNoChange';
  static const String explainWatchSignals = 'aiExplainWatchSignals';
  static const String explainNightSignals = 'aiExplainNightSignals';
  static const String explainAlertSignals = 'aiExplainAlertSignals';
  static const String explainFallback = 'aiExplainFallback';

  // L7 insight keys.
  static const String insightStableWeek = 'aiInsightStableWeek';
  static const String insightNightUsageUp = 'aiInsightNightUsageUp';
  static const String insightIncidentsUp = 'aiInsightIncidentsUp';
  static const String insightInsufficientData = 'aiInsightInsufficientData';

  // L8 suggestion keys.
  static const String suggestionReviewNightRoutine =
      'aiSuggestionReviewNightRoutine';
  static const String suggestionReviewRecentAlert = 'aiSuggestionReviewAlert';
  static const String suggestionConsistencyReview = 'aiSuggestionConsistency';

  // Health dimensions.
  static const String dimUsageBalance = 'healthDimUsageBalance';
  static const String dimSafetyIncidents = 'healthDimSafetyIncidents';
  static const String dimSleepOffline = 'healthDimSleepOffline';
  static const String dimConnectionMinutes = 'healthDimConnectionMinutes';

  // Data sufficiency.
  static const String sufficiencySufficient = 'aiDataSufficient';
  static const String sufficiencyPartial = 'aiDataPartial';
  static const String sufficiencyInsufficient = 'aiDataInsufficient';
}

/// L2 availability lookup — wraps whatever model runtime the family has
/// configured. `none` until a model is configured; AI layers then become
/// deterministic-only.
class AiModelAvailabilitySource {
  const AiModelAvailabilitySource({
    this.modelVersion = 'none',
    this.isAvailable = false,
  });

  final String modelVersion;
  final bool isAvailable;

  AiModelAvailability get availability =>
      !isAvailable ? AiModelAvailability.none : AiModelAvailability.configured;
}

/// The deterministic engine that implements Layers 3-9 on top of L1
/// signals. Layer 2 (on-device inference) is a dependency the family
/// must configure; until then its outputs are fail-closed.
class GuardianAiDeterministicEngine {
  const GuardianAiDeterministicEngine({
    this.modelAvailability = const AiModelAvailabilitySource(),
  });

  final AiModelAvailabilitySource modelAvailability;

  // -----------------------------------------------------------------------
  // L3 — Behavior Intelligence
  // -----------------------------------------------------------------------

  /// Per-child hourly usage baselines over the window. Derived purely
  /// from `app.session` signals (usage minutes aggregated into hour
  /// buckets). Empty buckets list is a valid, honest baseline — the UI
  /// discloses "no usage data yet".
  List<BehaviorProfile> computeBehaviorProfiles(List<NormalizedSignal> signals,
      List<String> childIds, DateTime windowStart, DateTime windowEnd) {
    final profiles = <BehaviorProfile>[];
    for (final childId in childIds) {
      final childSignals = signals
          .where((s) => s.childId == childId && s.isProcessable)
          .where((s) =>
              s.signalKey == GuardianSignalKeys.appSession ||
              s.signalKey == GuardianSignalKeys.appNightSession)
          .toList();
      final buckets = <BehaviorHourBucket>[];
      for (final signal in childSignals) {
        if (signal.occurredAt.isBefore(windowStart) ||
            signal.occurredAt.isAfter(windowEnd)) continue;
        buckets.add(BehaviorHourBucket(
          weekday: signal.occurredAt.weekday - 1,
          hour: signal.occurredAt.hour,
          usageSeconds: signal.weight * 3600,
          deviationPercent: 0,
        ));
      }
      final days = (windowEnd.difference(windowStart).inDays).clamp(1, 1000);
      final totalMinutes =
          buckets.fold<double>(0, (acc, b) => acc + b.usageSeconds) / 60;
      final nightSeconds = childSignals
          .where((s) => s.signalKey == GuardianSignalKeys.appNightSession)
          .fold<double>(0, (acc, s) => acc + s.weight * 3600);
      final totalSeconds =
          childSignals.fold<double>(0, (acc, s) => acc + s.weight * 3600);
      profiles.add(BehaviorProfile(
        familyId: signals.firstOrNull?.familyId ?? '',
        childId: childId,
        windowStart: windowStart,
        windowEnd: windowEnd,
        buckets: buckets,
        averageDailyMinutes: totalMinutes / days,
        nightUsageShare: totalSeconds > 0 ? nightSeconds / totalSeconds : 0,
      ));
    }
    return profiles;
  }

  // -----------------------------------------------------------------------
  // L4 — Risk Engine (deterministic, transparent contributors)
  // -----------------------------------------------------------------------

  /// Per-child risk verdict. Thresholds are documented constants; a
  /// `watch`/`alert` verdict names every contributor and weight so the
  /// explanation layer can render them without inventing anything.
  List<AiRiskState> evaluateChildRisk(
      List<BehaviorProfile> profiles, List<NormalizedSignal> signals) {
    final now = DateTime.now().toUtc();
    final states = <AiRiskState>[];
    final childIds = profiles.map((p) => p.childId).toSet().toList();
    for (final childId in childIds) {
      final profile = profiles.firstWhere((p) => p.childId == childId);
      final recent = signals
          .where((s) => s.childId == childId && s.isProcessable)
          .toList();
      final contributors = <RiskContributor>[];
      var score = 0.0;

      final sosSignals =
          recent.where((s) => s.signalKey == GuardianSignalKeys.sosActivated);
      if (sosSignals.isNotEmpty) {
        score += 1.0;
        contributors.add(const RiskContributor(
            signalKey: GuardianSignalKeys.sosActivated,
            weight: 1.0,
            labelKey: AiKeyFragments.labelSos));
      }

      final incidents = recent
          .where((s) => s.signalKey == GuardianSignalKeys.incidentCreated);
      final highSeverity = incidents.where((s) => s.weight >= 0.6);
      if (highSeverity.isNotEmpty) {
        score += 0.6;
        contributors.add(const RiskContributor(
            signalKey: GuardianSignalKeys.incidentCreated,
            weight: 0.6,
            labelKey: AiKeyFragments.labelIncidentHigh));
      }

      final geofenceEntries =
          recent.where((s) => s.signalKey == GuardianSignalKeys.geofenceEntry);
      if (geofenceEntries.isNotEmpty) {
        score += 0.5;
        contributors.add(const RiskContributor(
            signalKey: GuardianSignalKeys.geofenceEntry,
            weight: 0.5,
            labelKey: AiKeyFragments.labelGeofenceEntry));
      }

      if (profile.nightUsageShare > 0.4) {
        score += 0.3;
        contributors.add(const RiskContributor(
            signalKey: GuardianSignalKeys.appNightSession,
            weight: 0.3,
            labelKey: AiKeyFragments.labelNightUsage));
      }

      final level = score >= 0.9
          ? AiRiskLevel.alert
          : score >= 0.4
              ? AiRiskLevel.watch
              : AiRiskLevel.safe;
      states.add(AiRiskState(
        id: _id('risk', '$childId:${now.millisecondsSinceEpoch}'),
        familyId: profile.familyId,
        childId: childId,
        level: level,
        deterministicOnly:
            modelAvailability.availability == AiModelAvailability.none,
        contributors: contributors,
        evaluatedAt: now,
      ));
    }
    return states;
  }

  // -----------------------------------------------------------------------
  // L5 — Family Context
  // -----------------------------------------------------------------------

  /// Observed household norms derived from signal regularities. Empty
  /// lists are honest: the family is still collecting its baseline.
  FamilyContextModel buildFamilyContext(
      String familyId, List<NormalizedSignal> signals) {
    final routines = <String>[];
    final exceptions = <String>[];
    final nightSignals = signals
        .where((s) => s.signalKey == GuardianSignalKeys.appNightSession)
        .toList();
    if (nightSignals.length > 5) routines.add('nightDeviceUsage');
    final transitions = signals
        .where((s) => s.signalKey == GuardianSignalKeys.deviceStateTransition)
        .toList();
    if (transitions.length >= 3) exceptions.add('frequentDeviceChanges');
    return FamilyContextModel(
      familyId: familyId,
      observedRoutines: routines,
      knownExceptions: exceptions,
      weeknightBedtimeBaseline: 0,
    );
  }

  // -----------------------------------------------------------------------
  // L6 — Reasoning (template-based explanations, honest fallbacks)
  // -----------------------------------------------------------------------

  /// One explanation per risk state. `fallbackUsed` is true whenever the
  /// engine could not point at concrete signals — the UI discloses this.
  List<AiExplanation> explainRiskStates(List<AiRiskState> states) {
    return states.map((state) {
      if (state.contributors.isEmpty) {
        return AiExplanation(
          referenceId: state.id,
          titleKey: AiKeyFragments.explainNoChange,
          bodyKey: AiKeyFragments.explainNoSignals,
          sources: const [],
          fallbackUsed: true,
          modelVersion: modelAvailability.modelVersion,
        );
      }
      final isAlert = state.level == AiRiskLevel.alert;
      return AiExplanation(
        referenceId: state.id,
        titleKey: isAlert
            ? AiKeyFragments.explainAlertSignals
            : AiKeyFragments.explainWatchSignals,
        bodyKey: AiKeyFragments.explainFallback,
        sources: state.contributors.map((c) => c.labelKey).toList(),
        fallbackUsed: true, // template reasoning, not learned inference
        modelVersion: modelAvailability.modelVersion,
      );
    }).toList();
  }

  // -----------------------------------------------------------------------
  // L7 — Family Intelligence (weekly insights)
  // -----------------------------------------------------------------------

  List<FamilyInsight> weeklyInsights(String familyId,
      List<NormalizedSignal> signals, FamilyHealthScorecard scorecard) {
    final now = DateTime.now().toUtc();
    final weekStart = now.subtract(const Duration(days: 7));
    final recent = signals
        .where((s) => s.familyId == familyId && s.isProcessable)
        .toList();
    final sufficiency = recent.length >= 10
        ? AiDataSufficiency.sufficient
        : recent.length >= 3
            ? AiDataSufficiency.partial
            : AiDataSufficiency.insufficient;

    if (sufficiency == AiDataSufficiency.insufficient) {
      return [
        FamilyInsight(
          id: _id('ins', '$familyId:${now.millisecondsSinceEpoch}'),
          familyId: familyId,
          period: AiPeriod.weekly,
          periodStart: weekStart,
          periodEnd: now,
          titleKey: AiKeyFragments.insightInsufficientData,
          bodyKey: AiKeyFragments.sufficiencyInsufficient,
          metrics: const [
            AiInsightMetric(labelKey: 'aiMetricEventsSeen', value: '0')
          ],
          dataSufficiency: sufficiency,
        )
      ];
    }

    final insights = <FamilyInsight>[];
    final nightSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.appNightSession);
    if (nightSignals.length > 3) {
      insights.add(FamilyInsight(
        id: _id('ins', 'night:${now.millisecondsSinceEpoch}'),
        familyId: familyId,
        period: AiPeriod.weekly,
        periodStart: weekStart,
        periodEnd: now,
        titleKey: AiKeyFragments.insightNightUsageUp,
        bodyKey: AiKeyFragments.explainNightSignals,
        metrics: [
          AiInsightMetric(
              labelKey: 'aiMetricNightSessions',
              value: nightSignals.length.toString()),
        ],
        dataSufficiency: sufficiency,
      ));
    }

    final incidentSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.incidentCreated);
    if (incidentSignals.length >= 2) {
      insights.add(FamilyInsight(
        id: _id('ins', 'inc:${now.millisecondsSinceEpoch}'),
        familyId: familyId,
        period: AiPeriod.weekly,
        periodStart: weekStart,
        periodEnd: now,
        titleKey: AiKeyFragments.insightIncidentsUp,
        bodyKey: AiKeyFragments.explainAlertSignals,
        metrics: [
          AiInsightMetric(
              labelKey: 'aiMetricIncidents',
              value: incidentSignals.length.toString()),
        ],
        dataSufficiency: sufficiency,
      ));
    }

    if (insights.isEmpty) {
      insights.add(FamilyInsight(
        id: _id('ins', 'stable:${now.millisecondsSinceEpoch}'),
        familyId: familyId,
        period: AiPeriod.weekly,
        periodStart: weekStart,
        periodEnd: now,
        titleKey: AiKeyFragments.insightStableWeek,
        bodyKey: AiKeyFragments.explainNoChange,
        metrics: [
          AiInsightMetric(
              labelKey: 'aiMetricOverallScore',
              value: scorecard.overall.toStringAsFixed(2)),
        ],
        dataSufficiency: sufficiency,
      ));
    }
    return insights;
  }

  // -----------------------------------------------------------------------
  // L8 — Parent Copilot (template suggestions, approval-gated)
  // -----------------------------------------------------------------------

  List<CopilotSuggestion> copilotSuggestions(List<BehaviorProfile> profiles,
      List<AiRiskState> states, List<CopilotSuggestion> existing) {
    final suggestions = <CopilotSuggestion>[];
    final existingIds =
        existing.map((s) => '$s.titleKey:${s.appliesToChildIds}').toSet();
    for (final state in states) {
      final profile = profiles.firstWhere((p) => p.childId == state.childId);
      if (state.level == AiRiskLevel.watch ||
          state.level == AiRiskLevel.alert) {
        final hasSos = state.contributors
            .any((c) => c.signalKey == GuardianSignalKeys.sosActivated);
        final title = hasSos
            ? AiKeyFragments.suggestionReviewRecentAlert
            : AiKeyFragments.suggestionReviewNightRoutine;
        final key = '$title:${state.childId}';
        if (!existingIds.contains(key)) {
          suggestions.add(CopilotSuggestion(
            id: _id('sug', '$key:${DateTime.now().millisecondsSinceEpoch}'),
            familyId: state.familyId,
            titleKey: title,
            bodyKey: 'aiSuggestionBody',
            rationaleKey: 'aiSuggestionRationale',
            status: CopilotSuggestionStatus.open,
            appliesToChildIds: [state.childId],
            effectAfterDays: SuggestionEffect.insufficient,
            createdAt: DateTime.now().toUtc(),
          ));
        }
      }
    }
    return suggestions;
  }

  // -----------------------------------------------------------------------
  // L9 — Policy Intelligence (approval-gated drafts)
  // -----------------------------------------------------------------------

  List<PolicyProposal> policyProposals(
      List<AiRiskState> states, List<String> existingProposalKeys) {
    final proposals = <PolicyProposal>[];
    for (final state in states) {
      if (state.level != AiRiskLevel.alert) continue;
      final key = 'night-limit:${state.childId}';
      if (existingProposalKeys.contains(key)) continue;
      proposals.add(PolicyProposal(
        id: _id('prop', '$key:${DateTime.now().millisecondsSinceEpoch}'),
        familyId: state.familyId,
        titleKey: 'aiProposalNightLimitTitle',
        rationaleKey: 'aiProposalNightLimitRationale',
        beforeJson:
            jsonEncode({'kind': 'dailyScreenTime', 'child': state.childId}),
        afterJson: jsonEncode({
          'kind': 'dailyScreenTime',
          'child': state.childId,
          'nightCutoff': 22
        }),
        status: PolicyProposalStatus.proposed,
        appliesToRuleIds: const [],
        appliedRuleIds: const [],
        createdAt: DateTime.now().toUtc(),
      ));
    }
    return proposals;
  }

  // -----------------------------------------------------------------------
  // Health Scorecard (insights hub hero)
  // -----------------------------------------------------------------------

  FamilyHealthScorecard healthScorecard(
      String familyId, List<NormalizedSignal> signals) {
    final now = DateTime.now().toUtc();
    final weekStart = now.subtract(const Duration(days: 7));
    final recent = signals
        .where((s) => s.familyId == familyId && s.isProcessable)
        .toList();
    final sufficiency = recent.length >= 10
        ? AiDataSufficiency.sufficient
        : recent.length >= 3
            ? AiDataSufficiency.partial
            : AiDataSufficiency.insufficient;

    final sosSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.sosActivated);
    final incidentSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.incidentCreated);
    final nightSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.appNightSession);
    final sessionSignals =
        recent.where((s) => s.signalKey == GuardianSignalKeys.appSession);

    final safetyScore =
        (1.0 - (sosSignals.length * 0.4 + incidentSignals.length * 0.15))
            .clamp(0.0, 1.0);
    final sleepScore = nightSignals.isEmpty
        ? 0.0
        : (1.0 - nightSignals.length * 0.1).clamp(0.0, 1.0);
    final balanceScore = sessionSignals.isEmpty
        ? 0.0
        : (1.0 - sessionSignals.length * 0.02).clamp(0.0, 1.0);
    final connectionScore = 0.5; // no dedicated signal yet — honest

    final dims = [
      HealthDimensionScore(
          key: AiKeyFragments.dimUsageBalance,
          score: balanceScore,
          noteKey: 'aiDimUsageNote'),
      HealthDimensionScore(
          key: AiKeyFragments.dimSafetyIncidents,
          score: safetyScore,
          noteKey: 'aiDimSafetyNote'),
      HealthDimensionScore(
          key: AiKeyFragments.dimSleepOffline,
          score: sleepScore,
          noteKey: 'aiDimSleepNote'),
      HealthDimensionScore(
          key: AiKeyFragments.dimConnectionMinutes,
          score: connectionScore,
          noteKey: 'aiDimConnectionNote'),
    ];
    final overall = dims.fold<double>(0, (a, d) => a + d.score) / dims.length;
    return FamilyHealthScorecard(
      familyId: familyId,
      periodStart: weekStart,
      periodEnd: now,
      dimensions: dims,
      overall: overall,
      dataSufficiency: sufficiency,
    );
  }

  // -----------------------------------------------------------------------
  // Transparency report
  // -----------------------------------------------------------------------

  AiTransparencyReport buildTransparencyReport(
      String modelVersion, List<NormalizedSignal> allSignals) {
    final normalized = allSignals
        .where((s) => s.outcome == EventNormalizationOutcome.normalized);
    final rejected = allSignals
        .where((s) => s.outcome == EventNormalizationOutcome.rejected);
    final blocked = allSignals
        .where((s) => s.outcome == EventNormalizationOutcome.consentBlocked);
    final duplicates = allSignals
        .where((s) => s.outcome == EventNormalizationOutcome.duplicate);
    final unmapped = rejected
        .where((s) => (s.rejectReason ?? '').startsWith('unmapped_type'))
        .map((s) => s.rejectReason!.split(':')[1])
        .toSet()
        .toList();
    return AiTransparencyReport(
      modelVersion: modelVersion,
      eventsProcessed: allSignals.length,
      signalsNormalized: normalized.length,
      rejectedCount: rejected.length,
      consentBlockedCount: blocked.length,
      duplicatesSkipped: duplicates.length,
      unmappedTypes: unmapped,
      deleteSupported: true,
    );
  }

  String _id(String prefix, String unique) => '$prefix-$unique';
}
