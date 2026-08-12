import '../core/platform/android_enforcement_adapter.dart';
import '../core/platform/android_observation_gateway.dart';
import '../data/child_device_repository.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/screen_time.dart';

class ScreenTimeTargetReport {
  const ScreenTimeTargetReport(
      {required this.target,
      required this.evaluation,
      required this.androidResult});
  final String target;
  final ScreenTimeEvaluation evaluation;
  final AndroidEnforcementResult androidResult;
}

class ScreenTimeRunReport {
  const ScreenTimeRunReport(
      {required this.observation,
      required this.targets,
      required this.ranAt});
  final PolicyUsageObservation observation;
  final List<ScreenTimeTargetReport> targets;
  final DateTime ranAt;
}

/// Coordinates an on-demand, consent-gated use of Android Usage Stats with
/// persisted child policy and usage state. It never starts a background loop
/// and never claims that an unsupported Android restriction was applied.
class ChildScreenTimeCoordinator {
  ChildScreenTimeCoordinator(
      this._repository, this._observationGateway, this._adapter,
      {ScreenTimeEngine? engine, DateTime Function()? clock})
      : _engine = engine ?? const ScreenTimeEngine(),
        _clock = clock ?? DateTime.now;

  final ChildDeviceRepository _repository;
  final AndroidObservationGateway _observationGateway;
  final AndroidEnforcementAdapter _adapter;
  final ScreenTimeEngine _engine;
  final DateTime Function() _clock;

  Future<ScreenTimeRunReport> evaluateNow(String deviceId) async {
    final now = _clock().toUtc();
    final state = await _repository.getState(deviceId);
    if (state == null || state.lifecycle == ChildDeviceLifecycle.revoked) {
      return ScreenTimeRunReport(
          observation: const PolicyUsageObservation(
              status: ForegroundApplicationStatus.unavailable,
              dayStart: null,
              capturedAt: null,
              summaries: [],
              reason: 'child_device_unavailable'),
          targets: const [],
          ranAt: now);
    }
    final policies = await _repository.deliveredPolicies(deviceId);
    final dailyPolicies = policies
        .map((delivered) => delivered.policy)
        .where((policy) => policy.dailyLimitMinutes != null)
        .toList(growable: false);
    final targets = dailyPolicies
        .expand((policy) => policy.restrictedTargets)
        .toSet();
    final observation = await _observationGateway.observeDailyUsage(targets);
    final byTarget = {
      for (final summary in observation.summaries) summary.packageName: summary
    };
    final reports = <ScreenTimeTargetReport>[];
    for (final target in targets) {
      final nativeSummary = byTarget[target];
      final stored = nativeSummary == null
          ? await _repository.usageForTarget(
              deviceId: deviceId, target: target, day: now)
          : await _repository.upsertUsageSummary(
              deviceId: deviceId,
              target: target,
              cumulativeMilliseconds: nativeSummary.totalMilliseconds,
              observedAt: observation.capturedAt ?? now,
              lastUsedAt: nativeSummary.lastUsedAt);
      final baseEvaluation = _engine.evaluate(
          target: target,
          moment: now,
          policies: dailyPolicies,
          usage: stored);
      final evaluation = switch (observation.status) {
        ForegroundApplicationStatus.permissionRequired ||
        ForegroundApplicationStatus.permissionDenied ||
        ForegroundApplicationStatus.blockedByPermission => ScreenTimeEvaluation(
            target: target,
            status: EnforcementStatus.blockedByPermission,
            reason: observation.reason ?? 'usage_access_required',
            used: baseEvaluation.used,
            limit: baseEvaluation.limit,
            policyId: baseEvaluation.policyId,
            policyVersion: baseEvaluation.policyVersion),
        ForegroundApplicationStatus.unsupported ||
        ForegroundApplicationStatus.unavailable => ScreenTimeEvaluation(
            target: target,
            status: EnforcementStatus.unsupported,
            reason: observation.reason ?? 'usage_observation_unsupported',
            used: baseEvaluation.used,
            limit: baseEvaluation.limit,
            policyId: baseEvaluation.policyId,
            policyVersion: baseEvaluation.policyVersion),
        _ => baseEvaluation
      };
      await _repository.recordScreenTimeEvaluation(
          deviceId: deviceId, evaluation: evaluation, evaluatedAt: now);
      final decision = _engine.toDecision(
          device: state, evaluation: evaluation, currentTime: now);
      reports.add(ScreenTimeTargetReport(
          target: target,
          evaluation: evaluation,
          androidResult: _adapter.apply(decision)));
    }
    return ScreenTimeRunReport(
        observation: observation, targets: reports, ranAt: now);
  }
}
