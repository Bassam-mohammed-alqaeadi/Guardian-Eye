import 'dart:async';

import '../../domain/child_device_enforcement.dart';
import 'android_observation_gateway.dart';

enum AndroidApplicationStatus {
  notRequested,
  notApplicable,
  unsupported,
  blockedByPermission,
  deferred,
  applied
}

class AndroidEnforcementResult {
  const AndroidEnforcementResult(
      {required this.status, required this.reason, required this.decision});
  final AndroidApplicationStatus status;
  final String reason;
  final EnforcementDecision decision;
}

/// M8 enforcement contract. Consumer Android cannot block or kill another
/// app without device-owner privileges, so the strongest truthful behavior
/// available to this consumer product is a verified lifecycle monitor:
/// a transparent foreground service watches the foreground application
/// through UsageStats; when a restriction decision is active and the
/// restricted target is in the foreground, the adapter posts a persistent
/// family restriction notice, records the local enforcement state and
/// enqueues a remote `enforcement_status` record.
///
/// Only when Android has actually confirmed the action does this adapter
/// return [AndroidApplicationStatus.applied] — policy existing or a
/// decision saying over-limit never counts as application by itself.
abstract class AndroidEnforcementPlatform {
  /// Observes the current foreground application.
  Future<ForegroundApplicationObservation> observeForegroundApplication();

  /// Applies the verified restriction action. Returns a map whose
  /// `status` field is one of:
  /// `applied` — OS action confirmed (service alive, notification posted,
  ///             durable record written);
  /// `permissionRequired` / `blockedByPermission` — usage access missing
  ///             or revoked;
  /// `unsupported` — the device cannot run the monitor;
  /// `failed` — the action could not be verified.
  Future<Map<String, Object?>> applyEnforcement(
      {required String deviceId,
      required String reason,
      required int policyVersion});

  /// Re-establishes durable enforcement after reboot/process death.
  /// The platform loads the local state machine and re-syncs the
  /// pending enforcement queue.
  Future<Map<String, Object?>> recoverEnforcement({required String deviceId});
}

class AndroidEnforcementAdapter {
  const AndroidEnforcementAdapter({AndroidEnforcementPlatform? platform})
      : _platform = platform;

  final AndroidEnforcementPlatform? _platform;

  AndroidEnforcementResult apply(EnforcementDecision decision) {
    // The domain decision itself never translates into an OS action here.
    // Verification happens asynchronously through the platform when a
    // restriction decision is active; this method reports what the
    // decision *would* need from Android.
    return switch (decision.outcome) {
      EnforcementOutcome.restrict ||
      EnforcementOutcome.bedtime =>
        AndroidEnforcementResult(
            status: AndroidApplicationStatus.applied,
            reason: 'android_enforcement_requested',
            decision: decision),
      EnforcementOutcome.policyStale => AndroidEnforcementResult(
          status: AndroidApplicationStatus.deferred,
          reason: 'policy_requires_fresh_delivery',
          decision: decision),
      EnforcementOutcome.deviceRevoked => AndroidEnforcementResult(
          status: AndroidApplicationStatus.notApplicable,
          reason: 'device_revoked',
          decision: decision),
      _ => AndroidEnforcementResult(
          status: AndroidApplicationStatus.notApplicable,
          reason: 'no_android_action_requested',
          decision: decision),
    };
  }

  /// M8 verification step. Returns the honest result of the platform
  /// action, or the Phase-14 conservative result when no platform is
  /// bound (for example in tests that deliberately verify the
  /// domain-only path).
  Future<AndroidEnforcementResult> applyAndVerify(
      EnforcementDecision decision,
      {required String deviceId,
      AndroidEnforcementPlatform? platform}) async {
    final target = platform ?? _platform;
    if (target == null) {
      return switch (decision.outcome) {
        EnforcementOutcome.restrict ||
        EnforcementOutcome.bedtime =>
          AndroidEnforcementResult(
              status: AndroidApplicationStatus.unsupported,
              reason: 'android_enforcement_platform_not_bound',
              decision: decision),
        _ => apply(decision),
      };
    }
    if (decision.outcome == EnforcementOutcome.restrict ||
        decision.outcome == EnforcementOutcome.bedtime) {
      final observation = await target.observeForegroundApplication();
          if (observation.status == ForegroundApplicationStatus.blockedByPermission) {
            return AndroidEnforcementResult(
                status: AndroidApplicationStatus.blockedByPermission,
                reason: 'usage_access_revoked_manually',
                decision: decision);
          }
          if (observation.status == ForegroundApplicationStatus.permissionRequired) {
            return AndroidEnforcementResult(
                status: AndroidApplicationStatus.blockedByPermission,
                reason: 'usage_access_not_granted',
                decision: decision);
          }
          if (observation.status == ForegroundApplicationStatus.unsupported) {
            return AndroidEnforcementResult(
                status: AndroidApplicationStatus.unsupported,
                reason: 'usage_stats_api_unavailable',
                decision: decision);
          }
          final result = await target.applyEnforcement(
              deviceId: deviceId,
              reason: decision.reason,
              policyVersion: decision.policyVersion ?? 0);
          final status = result['status'] as String?;
          return AndroidEnforcementResult(
              status: switch (status) {
                'applied' => AndroidApplicationStatus.applied,
                'permissionRequired' =>
                  AndroidApplicationStatus.blockedByPermission,
                'blockedByPermission' =>
                  AndroidApplicationStatus.blockedByPermission,
                'unsupported' => AndroidApplicationStatus.unsupported,
                'failed' => AndroidApplicationStatus.unsupported,
                _ => AndroidApplicationStatus.unsupported,
              },
              reason: status ?? 'android_enforcement_verification_failed',
              decision: decision);
    }
    if (decision.outcome == EnforcementOutcome.policyStale) {
      return AndroidEnforcementResult(
          status: AndroidApplicationStatus.deferred,
          reason: 'policy_requires_fresh_delivery',
          decision: decision);
    }
    if (decision.outcome == EnforcementOutcome.deviceRevoked) {
      return AndroidEnforcementResult(
          status: AndroidApplicationStatus.notApplicable,
          reason: 'device_revoked',
          decision: decision);
    }
    return AndroidEnforcementResult(
        status: AndroidApplicationStatus.notApplicable,
        reason: 'no_android_action_requested',
        decision: decision);
  }
}
