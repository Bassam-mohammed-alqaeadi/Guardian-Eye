import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/location_remote_service.dart';
import 'package:guardian_ai/data/location_repository.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';

const _identity = AuthenticatedIdentity(
    uid: 'parent-1', email: 'parent@example.com', isAnonymous: false);

GuardianDatabase _testDatabase() {
  return GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async =>
          inMemoryDatabasePath); // fresh, isolated DB per test run
}

/// Inserts a real family row so the location_* tables' family_id FK is
/// satisfied.
Future<void> _seedFamily(LocationGeofenceRepository repository) async {
  await repository.database.database.then((db) => db.insert(
        'families',
        {
          'id': 'fam-1',
          'name': 'Test Family',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ));
}

void main() {
  group('FirestoreEventContract — FS-001 location operations', () {
    const contract = FirestoreEventContract();

    test('location.updated maps to a real locations document', () {
      final mutation = contract.businessMutation(
        operation: 'location.updated',
        identity: _identity,
        idempotencyKey: 'location.updated:fam-1:loc-7:1',
        payload: {
          'familyId': 'fam-1',
          'locationId': 'loc-7',
          'deviceId': 'device-1',
          'memberId': 'child-2',
          'latitude': 24.7136,
          'longitude': 46.6753,
          'accuracyMeters': 30,
          'capturedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/locations/loc-7');
      expect(mutation.data['latitude'], 24.7136);
      expect(mutation.data['memberId'], 'child-2');
    });

    test('geofence.created upserts a real geofences document', () {
      final mutation = contract.businessMutation(
        operation: 'geofence.created',
        identity: _identity,
        idempotencyKey: 'geofence.created:fam-1:gf-3:1',
        payload: {
          'familyId': 'fam-1',
          'geofenceId': 'gf-3',
          'name': 'School',
          'latitude': 24.7136,
          'longitude': 46.6753,
          'radiusMeters': 150,
          'alertOnEntry': true,
          'alertOnExit': false,
          'memberIds': ['child-2'],
          'createdAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/geofences/gf-3');
      final boundary = mutation.data['boundary'] as Map<String, dynamic>;
      expect(boundary['radiusMeters'], 150.0);
      expect(mutation.data['status'], 'active');
    });

    test('geofence.updated bumps the version and stamps the update', () {
      final mutation = contract.businessMutation(
        operation: 'geofence.updated',
        identity: _identity,
        idempotencyKey: 'geofence.updated:fam-1:gf-3:2',
        payload: {
          'familyId': 'fam-1',
          'geofenceId': 'gf-3',
          'name': 'School Zone',
          'latitude': 24.7136,
          'longitude': 46.6753,
          'radiusMeters': 200,
          'version': 1,
          'updatedAt': '2026-08-18T10:05:00Z',
        },
      );
      expect(mutation.data['version'], 2);
      expect(mutation.data['updatedAtClient'], '2026-08-18T10:05:00Z');
    });

    test('geofence.disabled stamps the server disable marker', () {
      final mutation = contract.businessMutation(
        operation: 'geofence.disabled',
        identity: _identity,
        idempotencyKey: 'geofence.disabled:fam-1:gf-3:3',
        payload: {
          'familyId': 'fam-1',
          'geofenceId': 'gf-3',
          'updatedAt': '2026-08-18T10:10:00Z',
        },
      );
      expect(mutation.data['status'], 'disabled');
    });

    test('favorite.place writes a real favorite_places document', () {
      final mutation = contract.businessMutation(
        operation: 'favorite.place',
        identity: _identity,
        idempotencyKey: 'favorite.place:fam-1:home:1',
        payload: {
          'familyId': 'fam-1',
          'placeKey': 'home',
          'name': 'Home',
          'updatedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/favorite_places/home');
      expect(mutation.data['name'], 'Home');
    });

    test('location.setting writes a real location_settings document', () {
      final mutation = contract.businessMutation(
        operation: 'location.setting',
        identity: _identity,
        idempotencyKey: 'location.setting:fam-1:battery_saver:1',
        payload: {
          'familyId': 'fam-1',
          'key': 'battery_saver',
          'value': 'on',
          'updatedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/location_settings/battery_saver');
      expect(mutation.data['value'], 'on');
    });

    test('incomplete FS-001 payloads fail loudly instead of writing garbage',
        () {
      expect(
        () => contract.businessMutation(
            operation: 'location.updated',
            identity: _identity,
            idempotencyKey: 'k',
            payload: {'familyId': 'fam-1', 'locationId': 'loc-1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => contract.businessMutation(
            operation: 'geofence.created',
            identity: _identity,
            idempotencyKey: 'k',
            payload: {'familyId': 'fam-1', 'geofenceId': 'gf-1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => contract.businessMutation(
            operation: 'location.setting',
            identity: _identity,
            idempotencyKey: 'k',
            payload: {'familyId': 'fam-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LocationPolicySyncApplier — verified server facts merge honestly',
      () {
    late LocationGeofenceRepository repository;
    late LocationPolicySyncApplier applier;

    setUp(() async {
      final database = _testDatabase();
      repository = LocationGeofenceRepository(database);
      applier = LocationPolicySyncApplier(repository);
      await _seedFamily(repository);
    });

    test('applies new server points, geofences and settings locally', () async {
      const policy = RemoteLocationPolicy(
          locationsPath: 'families/fam-1/locations',
          geofencesPath: 'families/fam-1/geofences',
          settingsPath: 'families/fam-1/location_settings',
          familyId: 'fam-1',
          points: [
            RemoteLocationPoint(
                locationId: 'loc-9',
                latitude: 24.7136,
                longitude: 46.6753,
                accuracyMeters: 30,
                capturedAt: '2026-08-18T10:00:00Z',
                memberId: 'child-2',
                removed: false),
          ],
          geofences: [
            RemoteGeofence(
                geofenceId: 'gf-5',
                latitude: 24.7136,
                longitude: 46.6753,
                radiusMeters: 150,
                name: 'School',
                removed: false),
          ],
          settings: {'battery_saver': 'on'});

      final report = await applier.apply(policy);
      expect(report.appliedPoints, 1);
      expect(report.appliedGeofences, 1);
      expect(report.appliedSettings, 1);

      final points = await repository.pointsForFamily('fam-1');
      expect(points.any((p) => p.id == 'loc-9'), true);

      final geofences = await repository.geofencesForFamily('fam-1');
      expect(geofences.any((g) => g.id == 'gf-5'), true);
    });

    test('server removals delete the local rows so stale data never appears',
        () async {
      final point = await repository.recordPoint(
          familyId: 'fam-1',
          latitude: 24.7136,
          longitude: 46.6753,
          memberId: 'child-2');
      final removalPolicy = RemoteLocationPolicy(
          locationsPath: 'families/fam-1/locations',
          geofencesPath: 'families/fam-1/geofences',
          settingsPath: 'families/fam-1/location_settings',
          familyId: 'fam-1',
          points: [
            RemoteLocationPoint(
                locationId: point.id,
                latitude: point.latitude,
                longitude: point.longitude,
                accuracyMeters: point.accuracyMeters,
                capturedAt: DateTime.now()
                    .toUtc()
                    .toIso8601String(),
                removed: true),
          ],
          geofences: const [],
          settings: const {});

      await applier.apply(removalPolicy);
      final points = await repository.pointsForFamily('fam-1');
      expect(points.any((p) => p.id == point.id), false);
    });
  });

  group('LocationPullService — a failed remote read never pretends success',
      () {
    test('read failure surfaces an honest reason', () async {
      final database = _testDatabase();
      final repository = LocationGeofenceRepository(database);
      final service = FamilyLocationPullService(
          _FailingReader(), LocationPolicySyncApplier(repository));
      await _seedFamily(repository);
      final result = await service.pull(familyId: 'fam-1');
      expect(result.success, false);
      expect(result.applied, isNull);
      expect(result.reason, contains('remote_read_failed'));
    });
  });
}

class _FailingReader extends FamilyLocationRemoteReader {
  _FailingReader();
  @override
  Future<RemoteLocationPolicy?> readLocationPolicy(
          {required String familyId}) =>
      Future<RemoteLocationPolicy?>.error(Exception('network_unavailable'));
}
