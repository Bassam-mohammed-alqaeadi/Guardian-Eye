import '../core/platform/android_enforcement_adapter.dart';
import '../data/child_device_repository.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/policy_engine.dart';

/// Duration after which a local decision may no longer drive enforcement
/// without a fresh policy refresh (watermark shared with the resolver).
const Duration m8MaxPolicyAge = Duration(days: 7);

/// Pure-logic M8 coordinator. It consumes the canonical enforcement chain
/// (resolver → engine → adapter), persists the resulting enforcement state
/// in the local SQLite repository, and derives the honest UI snapshot.
/// It never reaches the network; outbox enqueueing happens inside the
/// repository like every other local mutation.
class ChildEnforcementCoordinator {
  const ChildEnforcementCoordinator(this._repository, this._adapter);
  final ChildDeviceRepository _repository;
  final AndroidEnforcementAdapter _adapter;

  /// Evaluates enforcement for the child device right now. Safe to call
  /// offline: all inputs are local. Returns the derived snapshot with
  /// honest freshness and sync evidence.
  Future<EnforcementApplicationSnapshot> evaluate(String deviceId,
      {DateTime? moment,
      Iterable<StoredPolicyOverride> overrides = const [],
      String target = ''}) async {
    final now = (moment ?? DateTime.now()).toUtc();
    final device = await _repository.getState(deviceId);
    if (device == null) {
      return EnforcementApplicationSnapshot(
          deviceId: deviceId,
          state: EnforcementState.notRequested,
          application: EnforcementApplication.notRequested,
          freshness: false,
          syncState: EnforcementSyncState.neverSynced,
          decisionReason: 'device_not_enrolled',
          decidedAt: null,
          appliedAt: null,
          policyVersion: null);
    }
    final deliveries = await _repository.deliveredPolicies(deviceId);
    final resolution = const ChildPolicyResolver().resolve(
        device: device,
        target: target,
        moment: now,
        deliveries: deliveries,
        overrides: overrides);
    final decision =
        const EnforcementEngine().decide(device: device, resolution: resolution, currentTime: now);
    final platformResult = await _adapter.applyAndVerify(decision,
        deviceId: deviceId);
    final state = _deriveState(device, decision, platformResult, now);
    final record = EnforcementStateRecord(
        deviceId: deviceId,
        state: state,
        outcome: decision.outcome,
        reason: platformResult.reason,
        decidedAt: now,
        appliedAt: platformResult.status == AndroidApplicationStatus.applied
            ? now
            : null,
        policyVersion: decision.policyVersion,
        enqueuedForSync: false);
    await _repository.recordEnforcementState(record);
    await _repository.queueEnforcementSync(deviceId);
    final pending = await _repository.pendingEnforcementSyncRowsForDevice(deviceId: deviceId);
    final syncState = pending.isEmpty
        ? EnforcementSyncState.synced
        : EnforcementSyncState.syncPending;
    return EnforcementApplicationSnapshot(
        deviceId: deviceId,
        state: state,
        application: switch (platformResult.status) {
          AndroidApplicationStatus.applied =>
            EnforcementApplication.applied,
          AndroidApplicationStatus.notApplicable =>
            device.lifecycle == ChildDeviceLifecycle.revoked
                ? EnforcementApplication.failed
                : EnforcementApplication.notRequested,
          AndroidApplicationStatus.unsupported =>
            EnforcementApplication.failed,
          AndroidApplicationStatus.blockedByPermission =>
            EnforcementApplication.failed,
          AndroidApplicationStatus.deferred =>
            EnforcementApplication.notRequested,
          AndroidApplicationStatus.notRequested =>
            EnforcementApplication.notRequested,
        },
        freshness: record.isWithinFreshnessWindow(now),
        syncState: syncState,
        decisionReason: platformResult.reason,
        decidedAt: record.decidedAt,
        appliedAt: record.appliedAt,
        policyVersion: record.policyVersion);
  }

  EnforcementState _deriveState(ChildDeviceState device,
      EnforcementDecision decision, AndroidEnforcementResult platformResult,
      DateTime now) {
    switch (decision.outcome) {
      case EnforcementOutcome.deviceRevoked:
        // The device lifecycle was revoked: the child device no longer has
        // authority to act on family policy and cannot synchronize with the
        // parent backend. This is recorded as deviceOffline rather than
        // enforcementFailed because no enforcement action was ever applied.
        return EnforcementState.deviceOffline;
      case EnforcementOutcome.policyStale:
        return EnforcementState.policyStale;
      case EnforcementOutcome.temporaryAllow:
      case EnforcementOutcome.noEnforcement:
        return EnforcementState.evaluationReady;
      default:
        break;
    }
    return switch (platformResult.status) {
      AndroidApplicationStatus.applied =>
        EnforcementState.enforcementApplied,
      AndroidApplicationStatus.notRequested =>
        EnforcementState.notRequested,
      AndroidApplicationStatus.notApplicable =>
        EnforcementState.evaluationReady,
      AndroidApplicationStatus.unsupported =>
        EnforcementState.unsupported,
      AndroidApplicationStatus.blockedByPermission =>
        EnforcementState.permissionDenied,
      AndroidApplicationStatus.deferred =>
        EnforcementState.policyStale,
    };
  }
}
