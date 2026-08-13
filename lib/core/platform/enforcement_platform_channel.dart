import 'dart:async';

import 'package:flutter/services.dart';

import 'android_enforcement_adapter.dart';
import 'android_observation_gateway.dart';

/// Real native bridge for the M8 enforcement contract.
///
/// Connects [AndroidEnforcementPlatform] to the Kotlin
/// `guardian_eye.enforcement` MethodChannel:
///  - `startEnforcementMonitoring` — brings up the transparent foreground
///    monitoring service (records the honest result).
///  - `getLastVerifiedObservation` — the last UsageStats-verified foreground
///    snapshot written by the monitoring service.
///  - `getBootState` — the last boot/restart recorded by the M8 boot
///    receiver.
///
/// Nothing here claims that another app was blocked. The native side is the
/// only place that can confirm an OS action, and it confirms only what it
/// actually did (service started, notification posted, durable record kept).
class EnforcementPlatformChannel implements AndroidEnforcementPlatform {
  EnforcementPlatformChannel({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('guardian_eye.enforcement');

  final MethodChannel _channel;

  @override
  Future<ForegroundApplicationObservation> observeForegroundApplication() async {
    final payload = await _channel
        .invokeMapMethod<String, Object?>('getLastVerifiedObservation');
    if (payload == null) {
      return const ForegroundApplicationObservation(
          status: ForegroundApplicationStatus.noObservation,
          reason: 'no_platform_response');
    }
    final observedAtRaw = payload['observedAt'] as String?;
    DateTime? observedAt;
    if (observedAtRaw != null) {
      observedAt = DateTime.tryParse(observedAtRaw);
    }
    return ForegroundApplicationObservation(
        status: ForegroundApplicationStatus.values.firstWhere(
            (s) => s.name == (payload['status'] as String?),
            orElse: () => ForegroundApplicationStatus.noObservation),
        packageName: payload['packageName'] as String?,
        observedAt: observedAt,
        reason: payload['reason'] as String?);
  }

  @override
  Future<Map<String, Object?>> applyEnforcement({
    required String deviceId,
    required String reason,
    required int policyVersion,
  }) async {
    final payload = await _channel
        .invokeMapMethod<String, Object?>('startEnforcementMonitoring');
    if (payload == null) {
      return {
        'status': 'failed',
        'reason': 'no_platform_response',
        'deviceId': deviceId,
        'policyVersion': policyVersion,
      };
    }
    final started = payload['started'] == true;
    return {
      'status': started ? 'applied' : 'failed',
      'reason':
          started ? 'monitoring_started_and_verified' : payload['reason'],
      'deviceId': deviceId,
      'policyVersion': policyVersion,
      'observation': payload['observation'],
    };
  }

  @override
  Future<Map<String, Object?>> recoverEnforcement({
    required String deviceId,
  }) async {
    // Recovery = re-starting the verified monitoring service and reading the
    // boot state the platform recorded. We report exactly what the platform
    // confirms; an unconfirmed restart is reported as `pending`, never as
    // `applied`.
    final boot = await _channel
        .invokeMapMethod<String, Object?>('getBootState') ??
        <String, Object?>{};
    final monitoring = await _channel
            .invokeMapMethod<String, Object?>('startEnforcementMonitoring') ??
        <String, Object?>{};
    final started = monitoring['started'] == true;
    return {
      'status': started ? 'recovered' : 'pending',
      'reason': started
          ? 'monitoring_restarted_after_recovery'
          : (monitoring['reason'] ?? 'recovery_not_confirmed'),
      'lastBootAt': boot['lastBootAt'],
      'lastBootReason': boot['lastBootReason'],
      'deviceId': deviceId,
    };
  }
}
