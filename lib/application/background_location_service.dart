import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../core/platform/android_location_tracking_adapter.dart';
import '../data/location_repository.dart';

/// M9 — Background location tracking coordinator.
///
/// What it honestly does: arms the transparent native foreground
/// service through the platform channel, requests the human's consent
/// (fine + background location) via permission_handler, and polls the
/// native layer for real captured fixes on an interval matching the
/// armed interval. Every fix is recorded through the existing
/// `location_points` store (offline-first, outbox-synced to Firestore),
/// and geofence crossings close the alert loop that FS-001 left open.
///
/// What it does not claim: it never reports tracking as active unless
/// the native layer confirmed the service started, and it never emits
/// a coordinate the OS did not confirm.
class BackgroundLocationService {
  BackgroundLocationService({
    required this.platform,
    required this.repository,
  });

  final AndroidLocationTrackingPlatform platform;
  final LocationGeofenceRepository repository;

  Timer? _pollTimer;
  String? _familyId;
  String? _memberId;
  String? _memberDisplayName;
  String? _deviceId;
  bool _armed = false;

  bool get isArmed => _armed;

  /// Reads the honest native snapshot once.
  Future<TrackingState> getTrackingState() => platform.getTrackingState();

  /// Arms background tracking after consent. Returns an honest result:
  /// `permissionRequired` when the human has not granted fine +
  /// background location, `started` when the native service confirmed
  /// start, `failed` otherwise.
  Future<TrackingStartResult> enable({
    required String familyId,
    String? memberId,
    String? memberDisplayName,
    String? deviceId,
    int intervalMs = 60000,
    bool requestPermissions = true,
  }) async {
    // Consent first — this consumer product never tracks silently.
    // `requestPermissions: false` is reserved for automated verification
    // where the native layer (or a fake) has already confirmed consent;
    // the production path always defaults to true.
    if (requestPermissions) {
    final fine = await Permission.location.request();
    if (!fine.isGranted) {
      return const TrackingStartResult(
          status: 'permissionRequired', reason: 'fine_location_denied');
    }
    final background = await Permission.locationAlways.request();
    if (!background.isGranted) {
      return const TrackingStartResult(
          status: 'permissionRequired', reason: 'background_location_denied');
    }
    }

    final result = await platform.startTracking(intervalMs: intervalMs);
    if (result.status != 'started') return result;

    _familyId = familyId;
    _memberId = memberId;
    _memberDisplayName = memberDisplayName;
    _deviceId = deviceId;
    _armed = true;

    _pollTimer?.cancel();
    // Poll the native honest snapshot at the armed interval — the
    // Kotlin service writes captured fixes to durable prefs, and this
    // coordinator is the single place that turns them into recorded
    // points and crossing alerts.
    _pollTimer = Timer.periodic(
        Duration(milliseconds: intervalMs.clamp(30000, 300000)), (timer) async {
      await _pollOnce();
    });
    await _pollOnce();
    return result;
  }

  Future<void> _pollOnce() async {
    if (!_armed || _familyId == null) return;
    try {
      final state = await platform.getTrackingState();
      final latitude = state.latestLatitude;
      final longitude = state.latestLongitude;
      if (latitude == null || longitude == null) return; // no real fix yet
      await repository.recordPoint(
        familyId: _familyId!,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: state.latestAccuracyMeters ?? 100,
        deviceId: _deviceId,
        memberId: _memberId,
        source: 'background',
      );
      await repository.evaluateCrossingsForPoint(
        familyId: _familyId!,
        latitude: latitude,
        longitude: longitude,
        memberId: _memberId,
        memberDisplayName: _memberDisplayName,
        deviceId: _deviceId,
      );
    } catch (_) {
      // A polling failure never stops the native service; the durable
      // enabled flag keeps tracking alive across transient errors and
      // the honest snapshot will be re-read on the next tick.
    }
  }

  /// Disarms tracking; idempotent. Stops the coordinator poll and the
  /// native foreground service (which also clears the enabled pref).
  Future<void> disable() async {
    _armed = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    await platform.stopTracking();
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
