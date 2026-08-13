import 'package:flutter/services.dart';

enum ForegroundApplicationStatus {
  unavailable,
  permissionRequired,
  permissionDenied,
  observed,
  noObservation,
  blockedByPermission,
  unsupported
}

class ForegroundApplicationObservation {
  const ForegroundApplicationObservation(
      {required this.status, this.packageName, this.observedAt, this.reason});
  final ForegroundApplicationStatus status;
  final String? packageName;
  final DateTime? observedAt;
  final String? reason;
}

class PolicyUsageObservation {
  const PolicyUsageObservation(
      {required this.status,
      required this.dayStart,
      required this.capturedAt,
      required this.summaries,
      this.reason});
  final ForegroundApplicationStatus status;
  final DateTime? dayStart;
  final DateTime? capturedAt;
  final List<PolicyUsageSummary> summaries;
  final String? reason;
}

class PolicyUsageSummary {
  const PolicyUsageSummary(
      {required this.packageName,
      required this.totalMilliseconds,
      this.lastUsedAt});
  final String packageName;
  final int totalMilliseconds;
  final DateTime? lastUsedAt;
}

/// On-demand public Android Usage Stats observation. This has no background
/// polling, does not use Accessibility, and cannot report app blocking.
class AndroidObservationGateway {
  const AndroidObservationGateway();
  static const _channel = MethodChannel('com.guardianeye.app/capabilities');

  Future<ForegroundApplicationObservation>
      observeForegroundApplication() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
              'observeForegroundApplication') ??
          const <String, dynamic>{};
      final name = raw['status'] as String?;
      final status = ForegroundApplicationStatus.values
          .where((candidate) => candidate.name == name)
          .firstOrNull;
      final observedAt = raw['observedAt'] as String?;
      return ForegroundApplicationObservation(
          status: status ?? ForegroundApplicationStatus.unsupported,
          packageName: raw['packageName'] as String?,
          observedAt: observedAt == null ? null : DateTime.tryParse(observedAt),
          reason: raw['reason'] as String?);
    } on MissingPluginException {
      return const ForegroundApplicationObservation(
          status: ForegroundApplicationStatus.unsupported,
          reason: 'android_bridge_unavailable');
    } on PlatformException catch (error) {
      return ForegroundApplicationObservation(
          status: ForegroundApplicationStatus.unsupported, reason: error.code);
    }
  }

  Future<PolicyUsageObservation> observeDailyUsage(
      Set<String> targets) async {
    if (targets.isEmpty) {
      return const PolicyUsageObservation(
          status: ForegroundApplicationStatus.noObservation,
          dayStart: null,
          capturedAt: null,
          summaries: [],
          reason: 'no_policy_targets');
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
              'queryPolicyUsage', {'targets': targets.toList()}) ??
          const <String, dynamic>{};
      final name = raw['status'] as String?;
      final status = ForegroundApplicationStatus.values
              .where((candidate) => candidate.name == name)
              .firstOrNull ??
          ForegroundApplicationStatus.unsupported;
      final records = (raw['summaries'] as List? ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) {
        final map = Map<String, dynamic>.from(entry);
        return PolicyUsageSummary(
            packageName: map['packageName'] as String,
            totalMilliseconds: map['totalMilliseconds'] as int,
            lastUsedAt: (map['lastUsedAt'] as String?) == null
                ? null
                : DateTime.tryParse(map['lastUsedAt'] as String));
      }).toList(growable: false);
      return PolicyUsageObservation(
          status: status,
          dayStart: (raw['dayStart'] as String?) == null
              ? null
              : DateTime.tryParse(raw['dayStart'] as String),
          capturedAt: (raw['capturedAt'] as String?) == null
              ? null
              : DateTime.tryParse(raw['capturedAt'] as String),
          summaries: records,
          reason: raw['reason'] as String?);
    } on MissingPluginException {
      return const PolicyUsageObservation(
          status: ForegroundApplicationStatus.unsupported,
          dayStart: null,
          capturedAt: null,
          summaries: [],
          reason: 'android_bridge_unavailable');
    } on PlatformException catch (error) {
      return PolicyUsageObservation(
          status: ForegroundApplicationStatus.unsupported,
          dayStart: null,
          capturedAt: null,
          summaries: const [],
          reason: error.code);
    }
  }
}
