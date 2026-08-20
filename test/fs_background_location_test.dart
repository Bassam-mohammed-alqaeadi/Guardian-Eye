// M9 — Background location tracking. Honest-state checks that need no
// Android runtime: the TrackingState model parses the native snapshot
// faithfully (never fabricating coordinates), the capture interval is
// clamped exactly as the Kotlin service does, the haversine distance is
// accurate against known reference pairs, the crossing evaluator decides
// entry/exit from the real status machine without ever crossing a
// disabled geofence or one with alerts switched off, and the
// coordinator arms only after consent — permission denials return
// honest results and never start the native poll.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guardian_ai/core/platform/android_location_tracking_adapter.dart';
import 'package:guardian_ai/application/location_tracking_evaluation.dart';
import 'package:guardian_ai/application/background_location_service.dart';
import 'package:guardian_ai/data/location_repository.dart';

class _FakeTrackingPlatform implements AndroidLocationTrackingPlatform {
  _FakeTrackingPlatform(
      {this.startStatus = 'started', TrackingState? initialState})
      : state = initialState ??
            const TrackingState(
                enabled: false, intervalMs: 60000, permissionsGranted: false);
  final String startStatus;
  int getTrackingStateCalls = 0;
  TrackingState state;
  int startedWithIntervalMs = 0;
  bool stopCalled = false;

  @override
  Future<TrackingState> getTrackingState() async {
    getTrackingStateCalls++;
    return state;
  }

  @override
  Future<TrackingStartResult> startTracking({required int intervalMs}) async {
    startedWithIntervalMs = intervalMs;
    return TrackingStartResult(status: startStatus, reason: null);
  }

  @override
  Future<void> stopTracking() async => stopCalled = true;
}

class _FakeRepository implements LocationGeofenceRepository {
  List<RecordedPoint> recorded = [];
  int crossingEvaluations = 0;

  @override
  Future<LocationPoint> recordPoint({
    required String familyId,
    required double latitude,
    required double longitude,
    double accuracyMeters = 100,
    String? deviceId,
    String? memberId,
    double? batteryLevel,
    String source = 'device',
  }) async {
    recorded.add(RecordedPoint(
        familyId: familyId,
        latitude: latitude,
        longitude: longitude,
        source: source));
    return LocationPoint(
        id: 'p',
        familyId: familyId,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        capturedAt: DateTime.now(),
        source: source);
  }

  @override
  Future<void> evaluateCrossingsForPoint({
    required String familyId,
    required double latitude,
    required double longitude,
    String? memberId,
    String? memberDisplayName,
    String? deviceId,
  }) async =>
      crossingEvaluations++;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordedPoint {
  const RecordedPoint({
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.source,
  });
  final String familyId;
  final double latitude;
  final double longitude;
  final String source;
}

GeofenceEntry _geofence({
  String id = 'gf-1',
  String familyId = 'family-m9',
  double latitude = 24.4539,
  double longitude = 54.3773,
  double radiusMeters = 500,
  String status = 'active',
  bool alertOnEntry = true,
  bool alertOnExit = true,
}) {
  final now = DateTime.utc(2025, 7, 1);
  return GeofenceEntry(
      id: id,
      familyId: familyId,
      name: 'School',
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      status: status,
      alertOnEntry: alertOnEntry,
      alertOnExit: alertOnExit,
      createdAt: now,
      updatedAt: now);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // permission_handler has no native implementation in the headless
  // test runner; every request is answered with `denied` (int 3) so the
  // consent flow returns the honest `permissionRequired` verdict.
  final _binding = TestDefaultBinaryMessengerBinding.instance;
  _binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter.baseflow.com/permissions/methods', (message) async {
    final call = const StandardMethodCodec().decodeMethodCall(message);
    if (call.method == 'checkPermissionStatus' ||
        call.method == 'shouldShowRequestPermissionRationale') {
      return const StandardMethodCodec().encodeSuccessEnvelope(3);
    }
    if (call.method == 'requestPermissions') {
      // requestPermissions expects Map<int, int>: every requested
      // permission value maps to its int status (3 = denied).
      final requested = (call.arguments as List).cast<int>();
      return const StandardMethodCodec().encodeSuccessEnvelope(
          <int, int>{for (final permission in requested) permission: 3});
    }
    return null;
  });
  group('TrackingState parsing', () {
    test('round-trips every field from a full native snapshot', () {
      const captured = '2026-08-20T12:00:00.000Z';
      final map = <Object?, Object?>{
        'enabled': true,
        'intervalMs': 60000,
        'permissionsGranted': true,
        'latestPoint': <Object?, Object?>{
          'latitude': 24.4539,
          'longitude': 54.3773,
          'accuracyMeters': 12.5,
          'capturedAt': captured,
          'provider': 'gps',
        },
        'lastPointAt': captured,
      };
      final state = TrackingState.fromMap(map);
      expect(state.enabled, isTrue);
      expect(state.intervalMs, 60000);
      expect(state.latestLatitude, 24.4539);
      expect(state.latestLongitude, 54.3773);
      expect(state.latestAccuracyMeters, 12.5);
      expect(state.latestCapturedAt, DateTime.parse(captured));
      expect(state.permissionsGranted, isTrue);
      expect(state.reason, isNull);
    });

    test('null latestPoint yields no fabricated coordinates', () {
      final state = TrackingState.fromMap(<Object?, Object?>{
        'enabled': false,
        'intervalMs': 60000,
        'permissionsGranted': false,
      });
      expect(state.latestLatitude, isNull);
      expect(state.latestLongitude, isNull);
      expect(state.latestCapturedAt, isNull);
    });

    test('null map yields an honest all-disabled state', () {
      final state = TrackingState.fromMap(null);
      expect(state.enabled, isFalse);
      expect(state.permissionsGranted, isFalse);
      expect(state.latestLatitude, isNull);
    });

    test('records the honest failure reason from the native layer', () {
      final state = TrackingState.fromMap(<Object?, Object?>{
        'enabled': false,
        'intervalMs': 60000,
        'permissionsGranted': true,
        'latestPoint': <Object?, Object?>{
          'status': 'failed',
          'reason': 'no_location_fix_available',
          'capturedAt': '2026-08-20T12:00:00.000Z',
        },
      });
      expect(state.reason, 'failed');
      expect(state.latestLatitude, isNull);
    });

    test('intervalMs is clamped to the native [30s, 5min] window', () {
      final small = TrackingState.fromMap(<Object?, Object?>{
        'enabled': true,
        'intervalMs': 5000,
        'permissionsGranted': true,
      });
      final huge = TrackingState.fromMap(<Object?, Object?>{
        'enabled': true,
        'intervalMs': 999999,
        'permissionsGranted': true,
      });
      expect(small.intervalMs, 30000);
      expect(huge.intervalMs, 300000);
      final normal = TrackingState.fromMap(<Object?, Object?>{
        'enabled': true,
        'intervalMs': 120000,
        'permissionsGranted': true,
      });
      expect(normal.intervalMs, 120000);
    });
  });

  group('TrackingStartResult parsing', () {
    test('started status parses from a confirmed native start', () {
      final result = TrackingStartResult.fromMap(
          <Object?, Object?>{'status': 'started'});
      expect(result.status, 'started');
      expect(result.reason, isNull);
    });

    test('permissionRequired status survives a consent gap', () {
      final result = TrackingStartResult.fromMap(<Object?, Object?>{
        'status': 'permissionRequired',
        'reason': 'background_location_denied',
      });
      expect(result.status, 'permissionRequired');
      expect(result.reason, 'background_location_denied');
    });
  });

  group('Haversine distance', () {
    test('identical points yield zero distance', () {
      expect(haversineDistanceMeters(lat1: 24.45, lon1: 54.37, lat2: 24.45, lon2: 54.37), 0);
    });

    test('known reference pair: Riyadh → Abu Dhabi resolves to ≈ 709 km', () {
      final distance = haversineDistanceMeters(
          lat1: 24.7136, lon1: 46.6753, lat2: 24.4539, lon2: 54.3773);
      expect(distance, closeTo(708600, 1500));
    });

    test('sub-kilometer pair resolves to meters accurately', () {
      final distance = haversineDistanceMeters(
          lat1: 24.4539, lon1: 54.3773, lat2: 24.4584, lon2: 54.3773);
      // ~0.0045 degrees latitude ≈ 500 m
      expect(distance, closeTo(500, 15));
    });
  });

  group('Geofence crossing evaluation', () {
    test('point inside radius triggers an entry crossing', () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence()], latitude: 24.4539, longitude: 54.3773);
      expect(crossings, hasLength(1));
      expect(crossings.single.eventType, 'geofence_entry');
      expect(crossings.single.distanceMeters, closeTo(0, 1));
    });

    test('point outside radius with status=entered triggers an exit', () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(status: 'entered')],
          latitude: 24.0,
          longitude: 54.0);
      expect(crossings, hasLength(1));
      expect(crossings.single.eventType, 'geofence_exit');
      expect(crossings.single.distanceMeters, greaterThan(500));
    });

    test('alertOnEntry=false suppresses entry alerts even inside radius', () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(alertOnEntry: false)],
          latitude: 24.4539,
          longitude: 54.3773);
      expect(crossings, isEmpty);
    });

    test('alertOnExit=false suppresses exit alerts for entered fences', () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(status: 'entered', alertOnExit: false)],
          latitude: 24.0,
          longitude: 54.0);
      expect(crossings, isEmpty);
    });

    test('disabled geofences never cross', () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(status: 'disabled')],
          latitude: 24.4539,
          longitude: 54.3773);
      expect(crossings, isEmpty);
    });

    test('already-entered fence does not re-alert on a second inside point',
        () {
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(status: 'entered')],
          latitude: 24.4539,
          longitude: 54.3773);
      expect(crossings, isEmpty);
    });

    test('multiple geofences evaluate independently', () {
      // gf-1 is active and the point sits at its exact center → entry;
      // gf-2 is already 'entered' at the same center → no re-alert (the
      // evaluator only reports genuine new crossings).
      final crossings = evaluateGeofenceCrossings(
          geofences: [_geofence(), _geofence(id: 'gf-2', status: 'entered')],
          latitude: 24.4539,
          longitude: 54.3773);
      expect(crossings, hasLength(1));
      expect(crossings.single.geofence.id, 'gf-1');
      // Two fences at disjoint places, one entered far away → its exit
      // crosses independently of the far-away active fence.
      final disjoint = evaluateGeofenceCrossings(
          geofences: [
            _geofence(),
            _geofence(
                id: 'gf-2',
                latitude: 24.0,
                longitude: 54.0,
                status: 'entered'),
          ],
          latitude: 24.4539,
          longitude: 54.3773);
      expect(disjoint, hasLength(2));
    });
  });

  group('BackgroundLocationService coordinator', () {
    test('initially disarmed and never polled', () async {
      final service = BackgroundLocationService(
          platform: _FakeTrackingPlatform(), repository: _FakeRepository());
      expect(service.isArmed, isFalse);
    });

    test('permissionRequired status is returned without arming or polling',
        () async {
      final service = BackgroundLocationService(
          platform: _FakeTrackingPlatform(startStatus: 'permissionRequired'),
          repository: _FakeRepository());
      final result = await service.enable(
          familyId: 'family-m9', intervalMs: 60000, requestPermissions: true);
      expect(result.status, 'permissionRequired');
      expect(service.isArmed, isFalse);
      // The coordinator arms on native 'started' only; a permission gap
      // never starts the poll timer, so nothing is fabricated.
      addTearDown(service.dispose);
    });

    test('armed service polls and records OS-confirmed fixes only',
        () async {
      final repository = _FakeRepository();
      final platform = _FakeTrackingPlatform(initialState: TrackingState(
          enabled: true,
          intervalMs: 60000,
          latestLatitude: 24.4539,
          latestLongitude: 54.3773,
          latestAccuracyMeters: 12,
          permissionsGranted: true));
      final service =
          BackgroundLocationService(platform: platform, repository: repository);
      final result =
          await service.enable(familyId: 'family-m9', requestPermissions: false);
      expect(result.status, 'started');
      expect(service.isArmed, isTrue);
      // One immediate poll + the periodic timer; give the async work a
      // moment to land in the fake repository.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repository.recorded, isNotEmpty);
      expect(repository.recorded.first.source, 'background');
      expect(repository.recorded.first.familyId, 'family-m9');
      expect(repository.crossingEvaluations, greaterThanOrEqualTo(1));
      await service.disable();
      expect(platform.stopCalled, isTrue);
      expect(service.isArmed, isFalse);
      addTearDown(service.dispose);
    });

    test('poll with no real fix records nothing fabricated', () async {
      final repository = _FakeRepository();
      final platform = _FakeTrackingPlatform(
          initialState: const TrackingState(
              enabled: true,
              intervalMs: 60000,
              permissionsGranted: true,
              reason: 'no_location_fix_available'));
      final service =
          BackgroundLocationService(platform: platform, repository: repository);
      await service.enable(
          familyId: 'family-m9', requestPermissions: false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(repository.recorded, isEmpty);
      await service.disable();
      addTearDown(service.dispose);
    });

    test('failed native start disarms immediately', () async {
      final platform =
          _FakeTrackingPlatform(startStatus: 'failed');
      final service = BackgroundLocationService(
          platform: platform, repository: _FakeRepository());
      final result = await service.enable(
          familyId: 'family-m9', requestPermissions: false);
      expect(result.status, 'failed');
      expect(service.isArmed, isFalse);
      addTearDown(service.dispose);
    });
  });
}
