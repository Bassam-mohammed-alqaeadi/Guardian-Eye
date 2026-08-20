import 'dart:async';

/// Honest result model for the M9 background location tracking platform.
///
/// This family-safety product (consumer Android, no device-owner or
/// system privileges) cannot force silent background tracking. The
/// strongest truthful behavior available is a transparent foreground
/// location service: a visible notification tells the family device
/// owner that tracking runs, and coordinates are only surfaced when
/// the operating system actually confirmed a fix.
///
/// - [enabled] — the Kotlin service is armed (durable pref + service
///   alive or expected after boot).
/// - [permissionsGranted] — fine + background location permissions.
///   False means the native layer honestly refused to arm the service.
/// - [latest*] fields exist only when the OS returned a real fix.
///   Never synthetic, never silently stale-claimed: [reason] explains
///   what the native layer last observed.
class TrackingState {
  const TrackingState({
    required this.enabled,
    required this.intervalMs,
    this.latestLatitude,
    this.latestLongitude,
    this.latestAccuracyMeters,
    this.latestCapturedAt,
    required this.permissionsGranted,
    this.reason,
  });

  final bool enabled;
  final int intervalMs;
  final double? latestLatitude;
  final double? latestLongitude;
  final double? latestAccuracyMeters;
  final DateTime? latestCapturedAt;
  final bool permissionsGranted;
  final String? reason;

  factory TrackingState.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const TrackingState(
          enabled: false, intervalMs: 60000, permissionsGranted: false);
    }
    final latest = map['latestPoint'];
    Map<Object?, Object?>? latestMap;
    if (latest is Map<Object?, Object?>) {
      latestMap = latest;
    }
    final status = latestMap?['status'] as String?;
    double? latitude;
    double? longitude;
    double? accuracy;
    DateTime? capturedAt;
    String? reason;
    if (latestMap != null && status != 'noPoint' && status != 'failed') {
      final lat = latestMap['latitude'];
      final lon = latestMap['longitude'];
      if (lat is num && lon is num) {
        latitude = lat.toDouble();
        longitude = lon.toDouble();
      }
      final acc = latestMap['accuracyMeters'];
      if (acc is num) {
        accuracy = acc.toDouble();
      }
      final at = latestMap['capturedAt'];
      if (at is String) {
        capturedAt = DateTime.tryParse(at);
      }
    } else if (latestMap != null) {
      reason = status ?? (latestMap['reason'] as String?) ?? 'unknown';
    }
    final intervalRaw = map['intervalMs'];
    int intervalMs = 60000;
    if (intervalRaw is num) {
      // Native-side clamp mirror: [30000, 300000] (30s .. 5min).
      intervalMs = intervalRaw.toInt().clamp(30000, 300000);
    }
    return TrackingState(
        enabled: map['enabled'] == true,
        intervalMs: intervalMs,
        latestLatitude: latitude,
        latestLongitude: longitude,
        latestAccuracyMeters: accuracy,
        latestCapturedAt: capturedAt,
        permissionsGranted: map['permissionsGranted'] == true,
        reason: reason);
  }

  TrackingState copyWith({
    bool? enabled,
    int? intervalMs,
    double? latestLatitude,
    double? latestLongitude,
    double? latestAccuracyMeters,
    DateTime? latestCapturedAt,
    bool? permissionsGranted,
    String? reason,
  }) {
    return TrackingState(
      enabled: enabled ?? this.enabled,
      intervalMs: intervalMs ?? this.intervalMs,
      latestLatitude: latestLatitude ?? this.latestLatitude,
      latestLongitude: latestLongitude ?? this.latestLongitude,
      latestAccuracyMeters: latestAccuracyMeters ?? this.latestAccuracyMeters,
      latestCapturedAt: latestCapturedAt ?? this.latestCapturedAt,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      reason: reason ?? this.reason,
    );
  }

  Map<String, Object?> toMap() => {
        'enabled': enabled,
        'intervalMs': intervalMs,
        if (latestLatitude != null) 'latestLatitude': latestLatitude,
        if (latestLongitude != null) 'latestLongitude': latestLongitude,
        if (latestAccuracyMeters != null)
          'latestAccuracyMeters': latestAccuracyMeters,
        if (latestCapturedAt != null)
          'latestCapturedAt': latestCapturedAt!.toIso8601String(),
        'permissionsGranted': permissionsGranted,
        if (reason != null) 'reason': reason,
      };

  @override
  String toString() => 'TrackingState(enabled:$enabled '
      'intervalMs:$intervalMs lat:$latestLatitude lon:$latestLongitude '
      'permissions:$permissionsGranted reason:$reason)';
}

/// Honest start result. `status` is one of:
/// `started` — native confirmed: pref armed, service brought up.
/// `permissionRequired` — fine/background permission missing.
/// `failed` — service could not start (fg-service-type restriction, etc).
/// `unsupported` — device cannot run the monitor.
class TrackingStartResult {
  const TrackingStartResult({required this.status, this.reason});

  final String status;
  final String? reason;

  factory TrackingStartResult.fromMap(Map<Object?, Object?>? map) {
    return TrackingStartResult(
        status: (map?['status'] as String?) ?? 'failed',
        reason: map?['reason'] as String?);
  }
}

/// M9 background location tracking contract.
///
/// Only the Android platform can confirm an OS action here, so the Dart
/// layer never treats policy intent as tracking. [getTrackingState] is
/// the single source of truth and is polled by the coordinator service
/// while armed; [startTracking] arms the durable native state and the
/// transparent foreground service; [stopTracking] disarms both.
abstract class AndroidLocationTrackingPlatform {
  /// Honest snapshot of what the native layer actually does.
  Future<TrackingState> getTrackingState();

  /// Arms tracking with a capture interval clamped to [30000, 300000] ms.
  Future<TrackingStartResult> startTracking({required int intervalMs});

  /// Disarms tracking; idempotent.
  Future<void> stopTracking();
}
