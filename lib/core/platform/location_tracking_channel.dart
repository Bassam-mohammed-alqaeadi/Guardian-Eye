import 'dart:async';

import 'package:flutter/services.dart';

import 'android_location_tracking_adapter.dart';

/// Real native bridge for the M9 background location tracking contract.
///
/// Connects [AndroidLocationTrackingPlatform] to the Kotlin
/// `com.guardianeye.app/location_tracking` MethodChannel:
///  - `getLocationTrackingState` — the last honest snapshot the
///    transparent location service wrote (enabled flag, last real fix,
///    permissions, interval).
///  - `startLocationTracking` — arms the durable enabled pref and
///    brings up the transparent foreground service (Android 12+
///    declares foregroundServiceType=location; the OS keeps a visible
///    notification while it runs).
///  - `stopLocationTracking` — disarms the pref and stops the service.
///
/// Nothing here claims the OS is tracking. The native side is the only
/// place that can confirm an OS action, and it confirms only what it
/// actually did (pref armed, service started, real GPS/Network fix).
class LocationTrackingChannel implements AndroidLocationTrackingPlatform {
  LocationTrackingChannel({MethodChannel? channel})
      : _channel = channel ??
            const MethodChannel('com.guardianeye.app/location_tracking');
  final MethodChannel _channel;

  @override
  Future<TrackingState> getTrackingState() async {
    try {
      final payload = await _channel
          .invokeMapMethod<Object?, Object?>('getLocationTrackingState');
      return TrackingState.fromMap(payload);
    } on PlatformException catch (exception) {
      return TrackingState(
          enabled: false,
          intervalMs: 60000,
          permissionsGranted: false,
          reason: 'channel_failed:${exception.code}');
    } on MissingPluginException {
      // Running on an unsupported platform (web/desktop/test harness
      // without a mock): report honestly instead of claiming success.
      return const TrackingState(
          enabled: false,
          intervalMs: 60000,
          permissionsGranted: false,
          reason: 'unsupported_platform');
    }
  }

  @override
  Future<TrackingStartResult> startTracking({required int intervalMs}) async {
    try {
      final payload = await _channel.invokeMapMethod<Object?, Object?>(
          'startLocationTracking', {'intervalMs': intervalMs});
      return TrackingStartResult.fromMap(payload);
    } on PlatformException catch (exception) {
      return TrackingStartResult(
          status: 'failed', reason: 'channel_failed:${exception.code}');
    } on MissingPluginException {
      return const TrackingStartResult(
          status: 'unsupported', reason: 'unsupported_platform');
    }
  }

  @override
  Future<void> stopTracking() async {
    try {
      await _channel.invokeMethod<void>('stopLocationTracking');
    } on PlatformException {
      // Disarm is best-effort: the durable enabled pref on the native
      // side guarantees the service will not resurrect itself.
    } on MissingPluginException {
      // Nothing running on unsupported platforms; disarm is a no-op.
    }
  }
}
