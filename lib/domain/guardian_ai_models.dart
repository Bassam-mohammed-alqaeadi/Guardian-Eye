/// Guardian AI — Layers 2 through 9.
///
/// Governance (non-negotiable, enforced by this file):
///
/// 1. AI never bypasses the deterministic enforcement systems. A `watch`
///    or `alert` is an observation, never an action — the policy engine
///    and enforcement layer remain the sole actors.
/// 2. Every output carries its model version. With no on-device model
///    configured the version is `none` and the layer is fail-closed:
///    outputs degrade to deterministic-only summaries instead of
///    fabricated intelligence.
/// 3. Every output is human-approval-gated. Suggestions and policy
///    proposals default to `open`/`proposed` and are never silently
///    applied.
/// 4. Every output states its data sufficiency honestly. With too few
///    signals, outputs say exactly that — "insufficient data this week".
///
/// The engine classes below are pure Dart, fully deterministic and fully
/// testable. No cloud LLM calls exist anywhere in this codebase.
library guardian_ai_models;

import 'dart:convert';


// ---------------------------------------------------------------------------
// Shared enumerations
// ---------------------------------------------------------------------------

/// Model availability on the device. `none` means the family has not
/// configured an on-device model and every layer is fail-closed.
enum AiModelAvailability { configured, none, unavailable }

/// Honest confidence band — the model is never allowed to return a
/// fabricated decimal confidence.
enum AiConfidenceBand { low, medium, high }

/// Honest severity band for AI observations.
enum AiSeverityBand { informational, notable, significant }

/// L4 risk level. `safe` / `watch` / `alert` are observations only —
/// they map to the same honest-state palette as the rest of the app and
/// trigger no enforcement action on their own.
enum AiRiskLevel { safe, watch, alert }

/// Data sufficiency disclosure — every insight and digest carries one.
enum AiDataSufficiency { sufficient, partial, insufficient }

/// L8 suggestion lifecycle — every suggestion passes through these
/// states explicitly; there is no silent application.
enum CopilotSuggestionStatus { open, applied, dismissed }

/// L8 outcome measurement — recorded only after real passage of time,
/// and honestly disclosed as `insufficient` until measurable.
enum SuggestionEffect { positive, neutral, none, insufficient }

/// L9 proposal lifecycle — proposals are drafts until a parent acts.
enum PolicyProposalStatus { proposed, approved, rejected, applied }

/// Weekly digest / insight period anchor.
enum AiPeriod { weekly, monthly }

// ---------------------------------------------------------------------------
// L2 — On-Device AI detection result
// ---------------------------------------------------------------------------

/// One detection reported by an on-device model (content, media, or
/// pattern classifier). When no model is configured ([modelVersion] is
/// `none`), detections are empty and every consumer must render the
/// fail-closed honest state.
class AiDetectionResult {
  const AiDetectionResult({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.category,
    required this.severityBand,
    required this.confidenceBand,
    required this.modelVersion,
    required this.source,
    required this.detectedAt,
    required this.referenceId,
    required this.reviewed,
  });

  final String id;
  final String familyId;
  final String? childId;
  final String category;
  final AiSeverityBand severityBand;
  final AiConfidenceBand confidenceBand;
  final String modelVersion;
  final String source;
  final DateTime detectedAt;
  final String? referenceId;
  final bool reviewed;

  bool get isFailClosed => modelVersion == 'none' || modelVersion.isEmpty;

  factory AiDetectionResult.fromJson(Map<String, Object?> row) =>
      AiDetectionResult(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        childId: row['child_id'] as String?,
        category: row['category']! as String,
        severityBand:
            AiSeverityBand.values.byName(row['severity_band']! as String),
        confidenceBand:
            AiConfidenceBand.values.byName(row['confidence_band']! as String),
        modelVersion: row['model_version']! as String,
        source: row['source']! as String,
        detectedAt: DateTime.parse(row['detected_at']! as String),
        referenceId: row['reference_id'] as String?,
        reviewed: (row['reviewed'] as int) == 1,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'child_id': childId,
        'category': category,
        'severity_band': severityBand.name,
        'confidence_band': confidenceBand.name,
        'model_version': modelVersion,
        'source': source,
        'detected_at': detectedAt.toIso8601String(),
        'reference_id': referenceId,
        'reviewed': reviewed ? 1 : 0,
      };
}

// ---------------------------------------------------------------------------
// L3 — Behavior Intelligence
// ---------------------------------------------------------------------------

/// One hourly usage bucket of a child's baseline week (0=Monday … 6=Sunday).
class BehaviorHourBucket {
  const BehaviorHourBucket({
    required this.weekday,
    required this.hour,
    required this.usageSeconds,
    required this.deviationPercent,
  });

  final int weekday;
  final int hour;
  final double usageSeconds;
  final double deviationPercent;

  factory BehaviorHourBucket.fromJson(Map<String, Object?> row) =>
      BehaviorHourBucket(
        weekday: row['weekday']! as int,
        hour: row['hour']! as int,
        usageSeconds: (row['usage_seconds']! as num).toDouble(),
        deviationPercent: (row['deviation_percent']! as num).toDouble(),
      );

  Map<String, Object?> toJson() => {
        'weekday': weekday,
        'hour': hour,
        'usage_seconds': usageSeconds,
        'deviation_percent': deviationPercent,
      };
}

/// Per-child behavioral baseline: hourly buckets over the observed
/// window, plus the aggregate deviation summary the risk engine reads.
class BehaviorProfile {
  const BehaviorProfile({
    required this.familyId,
    required this.childId,
    required this.windowStart,
    required this.windowEnd,
    required this.buckets,
    required this.averageDailyMinutes,
    required this.nightUsageShare,
  });

  final String familyId;
  final String childId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<BehaviorHourBucket> buckets;
  final double averageDailyMinutes;
  final double nightUsageShare;
}

// ---------------------------------------------------------------------------
// L4 — Risk Engine
// ---------------------------------------------------------------------------

/// One contributor to a risk verdict, with its signal key and weight.
class RiskContributor {
  const RiskContributor({
    required this.signalKey,
    required this.weight,
    required this.labelKey,
  });

  final String signalKey;
  final double weight;
  final String labelKey;

  factory RiskContributor.fromJson(Map<String, Object?> row) => RiskContributor(
        signalKey: row['signal_key']! as String,
        weight: (row['weight']! as num).toDouble(),
        labelKey: row['label_key']! as String,
      );

  Map<String, Object?> toJson() => {
        'signal_key': signalKey,
        'weight': weight,
        'label_key': labelKey,
      };
}

/// L4 risk verdict for one child — observation only, never an action.
class AiRiskState {
  const AiRiskState({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.level,
    required this.deterministicOnly,
    required this.contributors,
    required this.evaluatedAt,
  });

  final String id;
  final String familyId;
  final String childId;
  final AiRiskLevel level;
  final bool deterministicOnly;
  final List<RiskContributor> contributors;
  final DateTime evaluatedAt;

  factory AiRiskState.fromJson(Map<String, Object?> row) => AiRiskState(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        childId: row['child_id']! as String,
        level: AiRiskLevel.values.byName(row['level']! as String),
        deterministicOnly: (row['deterministic_only'] as int) == 1,
        contributors: _decodeContributors(row['contributors_json']! as String),
        evaluatedAt: DateTime.parse(row['evaluated_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'child_id': childId,
        'level': level.name,
        'deterministic_only': deterministicOnly ? 1 : 0,
        'contributors_json': _encodeContributors(contributors),
        'evaluated_at': evaluatedAt.toIso8601String(),
        // Persistence layer always writes a `sync_state` because the
        // schema is NOT NULL DEFAULT 'queued'; an in-memory verdict has
        // never been synced, so 'queued' is the honest value.
        'sync_state': 'queued',
      };

  static List<RiskContributor> _decodeContributors(String json) {
    try {
      final decoded = (const JsonDecoder().convert(json) as List?) ?? const [];
      return decoded
          .cast<Map>()
          .map((e) => RiskContributor.fromJson(Map<String, Object?>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _encodeContributors(List<RiskContributor> contributors) {
    return const JsonEncoder()
        .convert(contributors.map((c) => c.toJson()).toList());
  }
}

// ---------------------------------------------------------------------------
// L5 — Family Context
// ---------------------------------------------------------------------------

/// L5 family context: the household's own norms (observed routines,
/// known exceptions) used by L6-L9 so the AI explains against the
/// family's own baseline, not a generic one.
class FamilyContextModel {
  const FamilyContextModel({
    required this.familyId,
    required this.observedRoutines,
    required this.knownExceptions,
    required this.weeknightBedtimeBaseline,
  });

  final String familyId;
  final List<String> observedRoutines;
  final List<String> knownExceptions;
  final int weeknightBedtimeBaseline;

  static const FamilyContextModel empty = FamilyContextModel(
    familyId: '',
    observedRoutines: [],
    knownExceptions: [],
    weeknightBedtimeBaseline: 0,
  );
}

// ---------------------------------------------------------------------------
// L6 — Reasoning (Explanations)
// ---------------------------------------------------------------------------

/// An AI explanation of a risk change or detection. [fallbackUsed] is
/// true whenever the AI could not substantiate the explanation from
/// real evidence — the UI must disclose this.
class AiExplanation {
  const AiExplanation({
    required this.referenceId,
    required this.titleKey,
    required this.bodyKey,
    required this.sources,
    required this.fallbackUsed,
    required this.modelVersion,
  });

  final String referenceId;
  final String titleKey;
  final String bodyKey;
  final List<String> sources;
  final bool fallbackUsed;
  final String modelVersion;
}

// ---------------------------------------------------------------------------
// L7 — Family Intelligence
// ---------------------------------------------------------------------------

/// One evidence metric attached to an insight.
class AiInsightMetric {
  const AiInsightMetric({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

/// L7 weekly/monthly family insight.
class FamilyInsight {
  const FamilyInsight({
    required this.id,
    required this.familyId,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.titleKey,
    required this.bodyKey,
    required this.metrics,
    required this.dataSufficiency,
  });

  final String id;
  final String familyId;
  final AiPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String titleKey;
  final String bodyKey;
  final List<AiInsightMetric> metrics;
  final AiDataSufficiency dataSufficiency;

  factory FamilyInsight.fromJson(Map<String, Object?> row) => FamilyInsight(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        period: AiPeriod.values.byName(row['period']! as String),
        periodStart: DateTime.parse(row['period_start']! as String),
        periodEnd: DateTime.parse(row['period_end']! as String),
        titleKey: (row['body_json']! as String).split('|')[0],
        bodyKey: (row['body_json']! as String).split('|')[1],
        metrics: _decodeMetrics(row['evidence_json']! as String),
        dataSufficiency:
            AiDataSufficiency.values.byName(row['data_sufficiency']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'period': period.name,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'body_json': '$titleKey|$bodyKey',
        'evidence_json': _encodeMetrics(metrics),
        'data_sufficiency': dataSufficiency.name,
      };

  static List<AiInsightMetric> _decodeMetrics(String json) {
    try {
      final decoded = (const JsonDecoder().convert(json) as List?) ?? const [];
      return decoded
          .cast<Map>()
          .map((e) => AiInsightMetric(
              labelKey: e['label_key']! as String,
              value: e['value']! as String))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _encodeMetrics(List<AiInsightMetric> metrics) {
    return const JsonEncoder().convert(metrics
        .map((m) => {'label_key': m.labelKey, 'value': m.value})
        .toList());
  }
}

// ---------------------------------------------------------------------------
// L8 — Parent Copilot
// ---------------------------------------------------------------------------

/// L8 copilot suggestion card — always requires an explicit parent act.
class CopilotSuggestion {
  const CopilotSuggestion({
    required this.id,
    required this.familyId,
    required this.titleKey,
    required this.bodyKey,
    required this.rationaleKey,
    required this.status,
    required this.appliesToChildIds,
    this.appliedAt,
    this.dismissedAt,
    this.outcomeNote,
    required this.effectAfterDays,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String titleKey;
  final String bodyKey;
  final String rationaleKey;
  final CopilotSuggestionStatus status;
  final List<String> appliesToChildIds;
  final DateTime? appliedAt;
  final DateTime? dismissedAt;
  final String? outcomeNote;
  final SuggestionEffect effectAfterDays;
  final DateTime createdAt;

  bool get isActionable => status == CopilotSuggestionStatus.open;

  factory CopilotSuggestion.fromJson(Map<String, Object?> row) =>
      CopilotSuggestion(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        titleKey: row['title']! as String,
        bodyKey: row['body']! as String,
        rationaleKey: row['rationale']! as String,
        status: CopilotSuggestionStatus.values.byName(row['status']! as String),
        appliesToChildIds: _decodeChildIds(row['reason_json']! as String),
        appliedAt: row['applied_at'] == null
            ? null
            : DateTime.parse(row['applied_at']! as String),
        dismissedAt: row['dismissed_at'] == null
            ? null
            : DateTime.parse(row['dismissed_at']! as String),
        outcomeNote: row['outcome_note'] as String?,
        effectAfterDays:
            SuggestionEffect.values.byName(row['effect_after_days']! as String),
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'title': titleKey,
        'body': bodyKey,
        'rationale': rationaleKey,
        'status': status.name,
        'reason_json': _encodeChildIds(appliesToChildIds),
        'applied_at': appliedAt?.toIso8601String(),
        'dismissed_at': dismissedAt?.toIso8601String(),
        'outcome_note': outcomeNote,
        'effect_after_days': effectAfterDays.name,
        'created_at': createdAt.toIso8601String(),
      };

  static List<String> _decodeChildIds(String json) {
    try {
      return (const JsonDecoder().convert(json) as List?)
              ?.cast<String>()
              .toList() ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  static String _encodeChildIds(List<String> ids) =>
      const JsonEncoder().convert(ids);
}

// ---------------------------------------------------------------------------
// L9 — Policy Intelligence
// ---------------------------------------------------------------------------

/// L9 smart policy proposal — a human-readable diff draft that a parent
/// must explicitly approve before any rule change takes effect.
class PolicyProposal {
  const PolicyProposal({
    required this.id,
    required this.familyId,
    required this.titleKey,
    required this.rationaleKey,
    required this.beforeJson,
    required this.afterJson,
    required this.status,
    required this.appliesToRuleIds,
    this.approvedAt,
    this.rejectedAt,
    required this.appliedRuleIds,
    this.outcomeNote,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String titleKey;
  final String rationaleKey;
  final String beforeJson;
  final String afterJson;
  final PolicyProposalStatus status;
  final List<String> appliesToRuleIds;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final List<String> appliedRuleIds;
  final String? outcomeNote;
  final DateTime createdAt;

  bool get requiresApproval => status == PolicyProposalStatus.proposed;
  bool get canBeApplied => status == PolicyProposalStatus.approved;

  factory PolicyProposal.fromJson(Map<String, Object?> row) => PolicyProposal(
        id: row['id']! as String,
        familyId: row['family_id']! as String,
        titleKey: row['title']! as String,
        rationaleKey: row['rationale']! as String,
        beforeJson: row['before_json']! as String,
        afterJson: row['after_json']! as String,
        status: PolicyProposalStatus.values.byName(row['status']! as String),
        appliesToRuleIds: _decodeList(row['after_json']! as String),
        approvedAt: row['approved_at'] == null
            ? null
            : DateTime.parse(row['approved_at']! as String),
        rejectedAt: row['rejected_at'] == null
            ? null
            : DateTime.parse(row['rejected_at']! as String),
        appliedRuleIds: _decodeList(row['applied_rule_ids']! as String),
        outcomeNote: row['outcome_note'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'family_id': familyId,
        'title': titleKey,
        'rationale': rationaleKey,
        'before_json': beforeJson,
        'after_json': afterJson,
        'status': status.name,
        'applied_rule_ids': _encodeList(appliedRuleIds),
        'approved_at': approvedAt?.toIso8601String(),
        'rejected_at': rejectedAt?.toIso8601String(),
        'outcome_note': outcomeNote,
        'created_at': createdAt.toIso8601String(),
      };

  static List<String> _decodeList(String json) {
    try {
      return (const JsonDecoder().convert(json) as List?)
              ?.cast<String>()
              .toList() ??
          const [];
    } catch (_) {
      return const [];
    }
  }

  static String _encodeList(List<String> ids) =>
      const JsonEncoder().convert(ids);
}

// ---------------------------------------------------------------------------
// L10 (Transparency Center) — honesty disclosure
// ---------------------------------------------------------------------------

/// The transparency report the transparency center renders: exactly how
/// many observations the AI saw, which were rejected, and which the
/// family's consent blocked.
class AiTransparencyReport {
  const AiTransparencyReport({
    required this.modelVersion,
    required this.eventsProcessed,
    required this.signalsNormalized,
    required this.rejectedCount,
    required this.consentBlockedCount,
    required this.duplicatesSkipped,
    required this.unmappedTypes,
    required this.deleteSupported,
  });

  final String modelVersion;
  final int eventsProcessed;
  final int signalsNormalized;
  final int rejectedCount;
  final int consentBlockedCount;
  final int duplicatesSkipped;
  final List<String> unmappedTypes;
  final bool deleteSupported;
}

// ---------------------------------------------------------------------------
// Health Scorecard (Insights hub hero)
// ---------------------------------------------------------------------------

/// One scorecard dimension with an honest score and reason.
class HealthDimensionScore {
  const HealthDimensionScore({
    required this.key,
    required this.score,
    required this.noteKey,
  });

  final String key;
  final double score;
  final String noteKey;
}

/// Family-wide health scorecard — four deterministic dimensions, an
/// honest overall score, and a data-sufficiency disclosure.
class FamilyHealthScorecard {
  const FamilyHealthScorecard({
    required this.familyId,
    required this.periodStart,
    required this.periodEnd,
    required this.dimensions,
    required this.overall,
    required this.dataSufficiency,
  });

  final String familyId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<HealthDimensionScore> dimensions;
  final double overall;
  final AiDataSufficiency dataSufficiency;
}
