import '../domain/screen_time.dart';

/// Honest synchronization state for a device's usage observations. Derived
/// only from the actual outbox row state — never guessed.
enum UsageSyncState { localOnly, queued, failed, synced }

/// Per-target measured usage for one local day, with the honest state that
/// produced the number. Zero is a number; `noObservation` is an absence of
/// measurement — the UI must never conflate the two.
class TargetUsage {
  const TargetUsage({
    required this.target,
    required this.totalMilliseconds,
    required this.capturedAt,
    required this.lastUsedAt,
    required this.observationState,
    this.evaluation,
  });

  final String target;
  final int totalMilliseconds;
  final DateTime capturedAt;
  final DateTime? lastUsedAt;
  final UsageObservationState observationState;
  final ScreenTimeEvaluation? evaluation;

  Duration get totalDuration => Duration(milliseconds: totalMilliseconds);
  bool get isZero => totalMilliseconds == 0;

  /// Convenience labels for tests and UI. Zero with a real capture is a
  /// measured zero; null observation is a genuine absence of data.
  bool get isMeasured =>
      observationState == UsageObservationState.observed ||
      observationState == UsageObservationState.offlineCached ||
      observationState == UsageObservationState.stale ||
      observationState == UsageObservationState.syncPending ||
      observationState == UsageObservationState.syncFailed;
}

/// The aggregated M7 measurement snapshot for a child device on a local day.
/// Every field is derived from evidence: a repository read, an engine
/// evaluation, or an outbox row.
class UsageMeasurementSnapshot {
  const UsageMeasurementSnapshot({
    required this.deviceId,
    required this.familyId,
    required this.dayStart,
    required this.targets,
    required this.totalMilliseconds,
    required this.lastObservedAt,
    required this.observationState,
    required this.syncState,
    required this.isOfflineCapable,
    required this.measuredAt,
    required this.evaluation,
  });

  final String deviceId;
  final String familyId;
  final DateTime dayStart;
  final List<TargetUsage> targets;
  final int totalMilliseconds;
  final DateTime? lastObservedAt;
  final UsageObservationState observationState;
  final UsageSyncState syncState;
  final bool isOfflineCapable;
  final DateTime measuredAt;
  final EvaluationSummary evaluation;

  Duration get totalDuration => Duration(milliseconds: totalMilliseconds);
  bool get hasObservedUsage => lastObservedAt != null;
}

/// Best-effort overall policy condition across the device's evaluated
/// targets, ordered from worst to best. This is a measurement statement
/// only — never an enforcement claim.
class EvaluationSummary {
  const EvaluationSummary({required this.state, required this.targets});

  /// Best-effort overall policy condition across the device's evaluated
  /// targets, ordered from worst to best. This is a measurement statement
  /// only — never an enforcement claim.
  factory EvaluationSummary.from(List<TargetUsage> targets) =>
      EvaluationSummary(
          state: conditionFor(targets),
          targets: List<TargetUsage>.unmodifiable(targets));

  final EvaluationCondition state;
  final List<TargetUsage> targets;
}

enum EvaluationCondition {
  withinLimit,
  nearLimit,
  overLimit,
  noActivePolicy,
  unableToEvaluate
}

/// Best-effort overall policy condition across the device's evaluated
/// targets, ordered from worst to best. This is a measurement statement
/// only — never an enforcement claim.
EvaluationCondition conditionFor(List<TargetUsage> targets) {
  if (targets.isEmpty) {
    return EvaluationCondition.unableToEvaluate;
  }
  if (targets.any((target) => target.evaluation?.exceeded ?? false)) {
    return EvaluationCondition.overLimit;
  }
  if (targets.any((target) => target.evaluation?.limit != null &&
      target.evaluation!.remaining != null &&
      target.evaluation!.remaining!.inSeconds < 10 * 60)) {
    return EvaluationCondition.nearLimit;
  }
  if (targets.any(
      (target) => target.evaluation?.status == EnforcementStatus.evaluated)) {
    return EvaluationCondition.withinLimit;
  }
  if (targets.any(
      (target) => target.evaluation?.status == EnforcementStatus.notRequested)) {
    return EvaluationCondition.noActivePolicy;
  }
  return EvaluationCondition.unableToEvaluate;
}

/// Selects the target whose remaining policy allowance is smallest — the
/// one a parent should read first. Null when no target is approaching its
/// limit.
TargetUsage? nearestEvaluationTarget(List<TargetUsage> targets) {
  final candidates = targets
      .where((target) =>
          target.evaluation?.limit != null && !target.evaluation!.exceeded)
      .toList()
    ..sort((left, right) {
      final leftRemaining =
          (left.evaluation?.remaining ?? Duration.zero).inMilliseconds;
      final rightRemaining =
          (right.evaluation?.remaining ?? Duration.zero).inMilliseconds;
      return leftRemaining.compareTo(rightRemaining);
    });
  return candidates.isEmpty ? null : candidates.first;
}
