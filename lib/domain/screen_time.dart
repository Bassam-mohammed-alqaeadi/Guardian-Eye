import 'child_device_enforcement.dart';
import 'policy_engine.dart';

enum UsageObservationState {
  unavailable,
  permissionRequired,
  permissionDenied,
  unsupported,
  observing,
  noObservation,
  observed,
  stale,
  offlineCached,
  syncPending,
  syncFailed
}

/// How fresh a locally observed usage measurement is relative to now.
/// Kept coarse on purpose: the UI must never pretend an old reading
/// is current. [staleThreshold] is intentionally short (2 hours).
enum UsageFreshness { fresh, stale }

/// [UsageFreshness] derived from the observation capture moment.
UsageFreshness freshnessFor(DateTime capturedAt, DateTime now,
        {Duration threshold = const Duration(hours: 2)}) =>
    now.difference(capturedAt) > threshold ? UsageFreshness.stale : UsageFreshness.fresh;

enum EnforcementStatus {
  notRequested,
  blockedByPermission,
  unsupported,
  deferred,
  evaluated,
  enforcementRequested,
  enforcementApplied,
  enforcementFailed
}

class DailyUsageSummary {
  const DailyUsageSummary(
      {required this.deviceId,
      required this.familyId,
      required this.target,
      required this.dayStart,
      required this.totalMilliseconds,
      required this.capturedAt,
      this.lastUsedAt});

  final String deviceId;
  final String familyId;
  final String target;
  final DateTime dayStart;
  final int totalMilliseconds;
  final DateTime capturedAt;
  final DateTime? lastUsedAt;

  Duration get totalDuration => Duration(milliseconds: totalMilliseconds);
}

class ScreenTimeEvaluation {
  const ScreenTimeEvaluation(
      {required this.target,
      required this.status,
      required this.reason,
      required this.used,
      this.limit,
      this.policyId,
      this.policyVersion});

  final String target;
  final EnforcementStatus status;
  final String reason;
  final Duration used;
  final Duration? limit;
  final String? policyId;
  final int? policyVersion;

  Duration? get remaining =>
      limit == null ? null : (limit! - used).isNegative ? Duration.zero : limit! - used;
  bool get exceeded => limit != null && used >= limit!;
}

class ScreenTimeEngine {
  const ScreenTimeEngine();

  ScreenTimeEvaluation evaluate(
      {required String target,
      required DateTime moment,
      required Iterable<DigitalPolicy> policies,
      required DailyUsageSummary? usage,
      TemporaryOverride? override}) {
    final now = moment.toUtc();
    if (override != null &&
        override.target == target &&
        override.allowed &&
        override.isActiveAt(now)) {
      return ScreenTimeEvaluation(
          target: target,
          status: EnforcementStatus.evaluated,
          reason: 'temporary_override',
          used: usage?.totalDuration ?? Duration.zero);
    }
    final candidates = policies
        .where((policy) =>
            policy.dailyLimitMinutes != null &&
            policy.isActiveAt(now) &&
            policy.restrictedTargets.contains(target))
        .toList()
      ..sort((left, right) => right.priority.compareTo(left.priority));
    if (candidates.isEmpty) {
      return ScreenTimeEvaluation(
          target: target,
          status: EnforcementStatus.notRequested,
          reason: 'no_daily_limit_policy',
          used: usage?.totalDuration ?? Duration.zero);
    }
    final policy = candidates.first;
    final limit = Duration(minutes: policy.dailyLimitMinutes!);
    final used = usage?.totalDuration ?? Duration.zero;
    return ScreenTimeEvaluation(
        target: target,
        status: used >= limit
            ? EnforcementStatus.enforcementRequested
            : EnforcementStatus.evaluated,
        reason: used >= limit ? 'daily_limit_exceeded' : 'daily_limit_remaining',
        used: used,
        limit: limit,
        policyId: policy.id,
        policyVersion: policy.version);
  }

  EnforcementDecision toDecision(
      {required ChildDeviceState device,
      required ScreenTimeEvaluation evaluation,
      required DateTime currentTime}) {
    if (device.lifecycle == ChildDeviceLifecycle.revoked) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.deviceRevoked,
          reason: 'device_revoked',
          evaluatedAt: currentTime.toUtc());
    }
    if (evaluation.status == EnforcementStatus.deferred) {
      return EnforcementDecision(
          outcome: EnforcementOutcome.policyStale,
          reason: evaluation.reason,
          evaluatedAt: currentTime.toUtc(),
          policyId: evaluation.policyId,
          policyVersion: evaluation.policyVersion);
    }
    return EnforcementDecision(
        outcome: evaluation.exceeded
            ? EnforcementOutcome.restrict
            : EnforcementOutcome.allow,
        reason: evaluation.reason,
        evaluatedAt: currentTime.toUtc(),
        policyId: evaluation.policyId,
        policyVersion: evaluation.policyVersion);
  }
}
