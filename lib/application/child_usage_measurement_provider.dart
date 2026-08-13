import '../core/firebase/guardian_firebase_bootstrap.dart';
import '../core/platform/android_observation_gateway.dart';
import '../domain/screen_time.dart';
import '../data/child_device_repository.dart';
import 'child_screen_time_coordinator.dart';
import 'child_usage_measurement.dart';

/// Threshold after which a locally captured usage reading is presented as
/// stale. Intentionally short so the UI never implies an old measurement is
/// current.
const Duration usageFreshnessThreshold = Duration(hours: 2);

/// Honest derivation of [UsageSyncState] from the actual outbox row state for
/// the device's usage observations. `synced` is ONLY returned when evidence
/// exists (no queued/failed/blocked rows remain and a remote writer is
/// configured); `syncPending` ONLY when queued/failed/syncing rows exist;
/// `failed` ONLY when a `blocked` row carries a last_error. Anything else is
/// `localOnly`.
Future<UsageSyncState> _resolveUsageSyncState({
  required ChildDeviceRepository repository,
  required String deviceId,
}) async {
  final pending =
      await repository.pendingUsageSyncRowsForDevice(deviceId: deviceId);
  final ready = GuardianFirebaseBootstrap.current.isReady;
  if (!ready || pending.isEmpty) {
    return UsageSyncState.localOnly;
  }
  final blocked = pending.where((row) => row['state'] == 'blocked').toList();
  final queued = pending
      .where((row) => row['state'] != 'blocked')
      .toList();
  if (queued.isNotEmpty) {
    return UsageSyncState.queued;
  }
  if (blocked.isNotEmpty && blocked.any((row) => row['last_error'] != null)) {
    return UsageSyncState.failed;
  }
  return UsageSyncState.localOnly;
}

/// Derives [UsageObservationState] from the gateway observation status and
/// the freshness of the captured reading. Stale and offline states are
/// derivations over the honest base states, never replacements.
UsageObservationState _observationStateFrom({
  required ForegroundApplicationStatus status,
  required DateTime? capturedAt,
  required DateTime now,
  required bool hasOfflineStored,
}) {
  switch (status) {
    case ForegroundApplicationStatus.permissionRequired:
      return UsageObservationState.permissionRequired;
    case ForegroundApplicationStatus.permissionDenied:
      return UsageObservationState.permissionDenied;
    case ForegroundApplicationStatus.unsupported:
      return UsageObservationState.unsupported;
    case ForegroundApplicationStatus.unavailable:
      return UsageObservationState.unavailable;
    case ForegroundApplicationStatus.noObservation:
      return hasOfflineStored && capturedAt == null
          ? UsageObservationState.offlineCached
          : UsageObservationState.observing;
    case ForegroundApplicationStatus.observed:
      if (capturedAt != null &&
          now.difference(capturedAt) > usageFreshnessThreshold) {
        return hasOfflineStored
            ? UsageObservationState.offlineCached
            : UsageObservationState.stale;
      }
      return hasOfflineStored
          ? UsageObservationState.offlineCached
          : UsageObservationState.observed;
    case ForegroundApplicationStatus.blockedByPermission:
      return UsageObservationState.permissionDenied;
  }
}

/// Maps the native gateway status to the honest observation state even when
/// no observation arrived. Prevents "observing" claims without captured data.
UsageObservationState _emptyObservationStateFor(
        ForegroundApplicationStatus status) =>
    switch (status) {
      ForegroundApplicationStatus.observed ||
      ForegroundApplicationStatus.noObservation =>
        UsageObservationState.noObservation,
      ForegroundApplicationStatus.permissionRequired =>
        UsageObservationState.permissionRequired,
      ForegroundApplicationStatus.permissionDenied ||
      ForegroundApplicationStatus.blockedByPermission =>
        UsageObservationState.permissionDenied,
      ForegroundApplicationStatus.unsupported =>
        UsageObservationState.unsupported,
      ForegroundApplicationStatus.unavailable =>
        UsageObservationState.unavailable
    };

/// Builds per-target snapshots from the coordinator run and stored summaries.
/// A zero total with a real capture is a measured zero; absence of data is
/// `noObservation`. The two must never be conflated.
List<TargetUsage> _targetSnapshots({
  required List<ScreenTimeTargetReport> targetReports,
  required ForegroundApplicationStatus status,
  required DateTime capturedAt,
}) =>
    targetReports
        .map((report) => TargetUsage(
            target: report.target,
            totalMilliseconds: report.evaluation.used.inMilliseconds,
            capturedAt: capturedAt,
            lastUsedAt: null,
            observationState: status == ForegroundApplicationStatus.observed
                ? UsageObservationState.observed
                : _emptyObservationStateFor(status),
            evaluation: report.evaluation))
        .toList(growable: false);

/// On-demand M7 measurement snapshot for a child device's current local day.
/// Reuses the coordinator's consent-gated observation; extends it with
/// freshness, sync evidence, and per-target policy comparison. Never claims
/// enforcement; never fabricates sync states.
Future<UsageMeasurementSnapshot> buildUsageMeasurementSnapshot({
  required ChildScreenTimeCoordinator coordinator,
  required ChildDeviceRepository repository,
  required String deviceId,
  required DateTime now,
}) async {
  final report = await coordinator.evaluateNow(deviceId);
  final state = await repository.getState(deviceId);
  if (state == null) {
    return UsageMeasurementSnapshot(
        deviceId: deviceId,
        familyId: '',
        dayStart: DateTime.now().toUtc(),
        targets: const [],
        totalMilliseconds: 0,
        lastObservedAt: null,
        observationState: UsageObservationState.unavailable,
        syncState: UsageSyncState.localOnly,
        isOfflineCapable: false,
        measuredAt: now,
        evaluation: const EvaluationSummary(
            state: EvaluationCondition.unableToEvaluate, targets: []));
  }
  final stored = await repository.usageForDeviceDay(
      deviceId: deviceId, day: now);
  final synced = await _resolveUsageSyncState(
      repository: repository, deviceId: deviceId);
  final observationState = report.observation.capturedAt == null &&
          report.targets.isEmpty
      ? _emptyObservationStateFor(report.observation.status)
      : _observationStateFrom(
          status: report.observation.status,
          capturedAt: report.observation.capturedAt,
          now: now,
          hasOfflineStored: stored.isNotEmpty);
  final targets = _targetSnapshots(
      targetReports: report.targets,
      status: report.observation.status,
      capturedAt: report.observation.capturedAt ?? now);
  return UsageMeasurementSnapshot(
      deviceId: deviceId,
      familyId: state.familyId,
      dayStart: now.toUtc(),
      targets: targets,
      totalMilliseconds: stored.fold(0, (total, summary) =>
          total + summary.totalMilliseconds),
      lastObservedAt: report.observation.capturedAt,
      observationState: observationState,
      syncState: synced,
      isOfflineCapable: stored.isNotEmpty,
      measuredAt: now,
      evaluation: EvaluationSummary.from(targets));
}
