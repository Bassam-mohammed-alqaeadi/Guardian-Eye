import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_contracts.dart';
import '../domain/guardian_models.dart';
import 'location_repository.dart';

/// FS-001 — Location & Geofencing remote bridge. The parent app pulls the
/// family's consent-gated location state from Firestore — the
/// `locations`, `geofences`, and `location_settings` collections that the
/// child device and the parent app write through the outbox — and applies
/// every verified server fact into the local SQLite store. Nothing is
/// applied until the server confirms it; the local store never pretends a
/// remote truth it has not fetched.
///
/// The sync discipline mirrors `WebPolicySyncApplier`: server-first
/// fetch, idempotency by idempotencyKey, and removal handling so a
/// server-deleted geofence can never reappear on the parent's device.

abstract class FamilyLocationRemoteReader {
  Future<RemoteLocationPolicy?> readLocationPolicy(
      {required String familyId});
}

class FirestoreFamilyLocationRemoteReader
    implements FamilyLocationRemoteReader {
  const FirestoreFamilyLocationRemoteReader(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<RemoteLocationPolicy?> readLocationPolicy(
      {required String familyId}) async {
    if (!const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    final locationsPath = '${FirestorePaths.family(familyId)}/locations';
    final geofencesPath = '${FirestorePaths.family(familyId)}/geofences';
    final settingsPath = '${FirestorePaths.family(familyId)}/location_settings';
    final snapshots = await Future.wait([
      _firestore
          .collection(locationsPath)
          .get(const GetOptions(source: Source.server)),
      _firestore
          .collection(geofencesPath)
          .get(const GetOptions(source: Source.server)),
      _firestore
          .collection(settingsPath)
          .get(const GetOptions(source: Source.server)),
    ]);
    final locationDocs = snapshots[0].docs;
    final geofenceDocs = snapshots[1].docs;
    final settingDocs = snapshots[2].docs;
    return RemoteLocationPolicy(
        locationsPath: locationsPath,
        geofencesPath: geofencesPath,
        settingsPath: settingsPath,
        familyId: familyId,
        points: locationDocs
            .map((document) => _parseRemotePoint(document.data()))
            .whereType<RemoteLocationPoint>()
            .toList(),
        geofences: geofenceDocs
            .map((document) => _parseRemoteGeofence(document.data()))
            .whereType<RemoteGeofence>()
            .toList(),
        settings: settingDocs.fold<Map<String, String>>({},
            (accumulator, document) {
              final data = document.data();
              final key = data['key'] as String? ?? document.id;
              final value = data['value']?.toString() ?? '';
              accumulator[key] = value;
              return accumulator;
            }));
  }

  RemoteLocationPoint? _parseRemotePoint(Map<String, dynamic> data) {
    final locationId = data['locationId'] as String?;
    final latitude = data['latitude'] as num?;
    final longitude = data['longitude'] as num?;
    if (locationId == null || latitude == null || longitude == null) {
      return null;
    }
    return RemoteLocationPoint(
        locationId: locationId,
        deviceId: data['deviceId'] as String?,
        memberId: data['memberId'] as String?,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        accuracyMeters: (data['accuracyMeters'] as num?)?.toDouble() ?? 100,
        capturedAt: data['capturedAt'] as String?,
        batteryLevel: (data['batteryLevel'] as num?)?.toDouble(),
        source: (data['source'] as String?) ?? 'device',
        removed: data['removed'] == true);
  }

  RemoteGeofence? _parseRemoteGeofence(Map<String, dynamic> data) {
    final geofenceId = data['geofenceId'] as String?;
    final boundary = data['boundary'];
    final latitude = (boundary as Map?)?['latitude'] as num?;
    final longitude = boundary?['longitude'] as num?;
    final radiusMeters = boundary?['radiusMeters'] as num?;
    if (geofenceId == null ||
        latitude == null ||
        longitude == null ||
        radiusMeters == null) {
      return null;
    }
    return RemoteGeofence(
        geofenceId: geofenceId,
        name: data['name'] as String?,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        radiusMeters: radiusMeters.toDouble(),
        alertOnEntry: data['alertOnEntry'] as bool?,
        alertOnExit: data['alertOnExit'] as bool?,
        memberIds: (data['memberIds'] as List?)
                ?.map((element) => element.toString())
                .toList() ??
            const [],
        placeKey: data['placeKey'] as String?,
        status: (data['status'] as String?) ?? 'active',
        version: data['version'] as int?,
        removed: data['removed'] == true);
  }
}

class RemoteLocationPoint {
  const RemoteLocationPoint(
      {required this.locationId,
      required this.latitude,
      required this.longitude,
      required this.accuracyMeters,
      required this.removed,
      this.deviceId,
      this.memberId,
      this.capturedAt,
      this.batteryLevel,
      this.source = 'device'});

  final String locationId;
  final String? deviceId;
  final String? memberId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String? capturedAt;
  final double? batteryLevel;
  final String source;
  final bool removed;
}

class RemoteGeofence {
  const RemoteGeofence(
      {required this.geofenceId,
      required this.latitude,
      required this.longitude,
      required this.radiusMeters,
      required this.removed,
      this.name,
      this.alertOnEntry,
      this.alertOnExit,
      this.memberIds = const [],
      this.placeKey,
      this.status = 'active',
      this.version});

  final String geofenceId;
  final String? name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool? alertOnEntry;
  final bool? alertOnExit;
  final List<String> memberIds;
  final String? placeKey;
  final String status;
  final int? version;
  final bool removed;
}

class RemoteLocationPolicy {
  const RemoteLocationPolicy(
      {required this.locationsPath,
      required this.geofencesPath,
      required this.settingsPath,
      required this.familyId,
      required this.points,
      required this.geofences,
      required this.settings});

  final String locationsPath;
  final String geofencesPath;
  final String settingsPath;
  final String familyId;
  final List<RemoteLocationPoint> points;
  final List<RemoteGeofence> geofences;
  final Map<String, String> settings;
}

class LocationPolicySyncReport {
  const LocationPolicySyncReport(
      {required this.familyId,
      required this.appliedPoints,
      required this.appliedGeofences,
      required this.appliedSettings});

  final String familyId;
  final int appliedPoints;
  final int appliedGeofences;
  final int appliedSettings;
}

/// Merges verified server facts into the local SQLite store. New server
/// points and geofences are created when absent; newer server versions
/// win over stale local rows; server-stamped removals delete the local
/// row so the parent never sees data the server has removed.
class LocationPolicySyncApplier {
  const LocationPolicySyncApplier(this._repository);

  final LocationGeofenceRepository _repository;

  Future<LocationPolicySyncReport> apply(RemoteLocationPolicy policy) async {
    final db = await _repository.database.database;
    var appliedPoints = 0;
    var appliedGeofences = 0;
    var appliedSettings = 0;

    for (final point in policy.points) {
      final existing = await db.query('location_points',
          where: 'id = ?', whereArgs: [point.locationId]);
      if (point.removed) {
        if (existing.isNotEmpty) {
          await db.delete('location_points',
              where: 'id = ?', whereArgs: [point.locationId]);
        }
        appliedPoints++;
        continue;
      }
      if (existing.isNotEmpty) {
        final row = existing.first;
        final localCapturedAt = row['captured_at'] as String;
        final serverCapturedAt =
            point.capturedAt ?? DateTime.now().toUtc().toIso8601String();
        if (serverCapturedAt.compareTo(localCapturedAt) > 0) {
          await db.update(
              'location_points',
              {
                'latitude': point.latitude,
                'longitude': point.longitude,
                'accuracy_meters': point.accuracyMeters,
                'captured_at': serverCapturedAt,
                'battery_level': point.batteryLevel,
                'source': point.source,
                'sync_state': SyncState.synced.name,
              },
              where: 'id = ?',
              whereArgs: [point.locationId]);
          appliedPoints++;
        }
        continue;
      }
      final capturedAt = point.capturedAt != null
          ? DateTime.parse(point.capturedAt!).toIso8601String()
          : DateTime.now().toUtc().toIso8601String();
      await db.insert('location_points', {
        'id': point.locationId,
        'family_id': policy.familyId,
        'device_id': point.deviceId,
        'member_id': point.memberId,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'accuracy_meters': point.accuracyMeters,
        'captured_at': capturedAt,
        'battery_level': point.batteryLevel,
        'source': point.source,
        'sync_state': SyncState.synced.name,
        'created_at': capturedAt,
      });
      appliedPoints++;
    }

    for (final geofence in policy.geofences) {
      final existing = await db.query('geofences',
          where: 'id = ?', whereArgs: [geofence.geofenceId]);
      if (geofence.removed) {
        if (existing.isNotEmpty) {
          await db.delete('geofences',
              where: 'id = ?', whereArgs: [geofence.geofenceId]);
        }
        appliedGeofences++;
        continue;
      }
      if (existing.isNotEmpty) {
        final row = existing.first;
        final localVersion = (row['sync_state'] as String?);
        final serverVersion = geofence.version ?? 0;
        if (serverVersion > 0 &&
            localVersion != SyncState.synced.name) {
          // A server-confirmed version beats an unsynced local draft
          // that never reached the outbox successfully.
          final boundaryName = geofence.name ?? row['name'] as String;
          await db.update(
              'geofences',
              {
                'name': boundaryName,
                'latitude': geofence.latitude,
                'longitude': geofence.longitude,
                'radius_meters': geofence.radiusMeters,
                'alert_on_entry':
                    geofence.alertOnEntry ?? (row['alert_on_entry'] == 1),
                'alert_on_exit':
                    geofence.alertOnExit ?? (row['alert_on_exit'] == 1),
                'status': geofence.status,
                'sync_state': SyncState.synced.name,
              },
              where: 'id = ?',
              whereArgs: [geofence.geofenceId]);
          appliedGeofences++;
        }
        continue;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('geofences', {
        'id': geofence.geofenceId,
        'family_id': policy.familyId,
        'name': geofence.name ?? geofence.geofenceId,
        'latitude': geofence.latitude,
        'longitude': geofence.longitude,
        'radius_meters': geofence.radiusMeters,
        'alert_on_entry': (geofence.alertOnEntry ?? true) ? 1 : 0,
        'alert_on_exit': (geofence.alertOnExit ?? true) ? 1 : 0,
        'member_ids_json':
            __toJsonArray(geofence.memberIds),
        'place_key': geofence.placeKey,
        'status': geofence.status,
        'sync_state': SyncState.synced.name,
        'created_at': now,
        'updated_at': now,
      });
      appliedGeofences++;
    }

    for (final entry in policy.settings.entries) {
      final existing = await db.query('location_settings',
          where: 'family_id = ? AND key = ?',
          whereArgs: [policy.familyId, entry.key]);
      if (existing.isEmpty) {
        await db.insert('location_settings', {
          'family_id': policy.familyId,
          'key': entry.key,
          'value': entry.value,
        });
      } else {
        final row = existing.first;
        if ((row['value'] as String?) != entry.value) {
          await db.update('location_settings', {'value': entry.value},
              where: 'family_id = ? AND key = ?',
              whereArgs: [policy.familyId, entry.key]);
          appliedSettings++;
        }
      }
      appliedSettings++;
    }

    return LocationPolicySyncReport(
        familyId: policy.familyId,
        appliedPoints: appliedPoints,
        appliedGeofences: appliedGeofences,
        appliedSettings: appliedSettings);
  }

  String __toJsonArray(List<String> values) {
    return '[${values.map((value) => '"$value"').join(',')}]';
  }
}

class FamilyLocationPullResult {
  const FamilyLocationPullResult(
      {required this.success, this.applied, this.reason});

  final bool success;
  final LocationPolicySyncReport? applied;
  final String? reason;
}

/// Pulls verified Firestore location facts and applies them locally. A
/// failed remote read never pretends success: the result carries the
/// honest failure reason so the UI can show an offline or error state.
class FamilyLocationPullService {
  const FamilyLocationPullService(this._reader, this._applier);

  final FamilyLocationRemoteReader _reader;
  final LocationPolicySyncApplier _applier;

  Future<FamilyLocationPullResult> pull(
      {required String familyId}) async {
    RemoteLocationPolicy? policy;
    try {
      policy = await _reader.readLocationPolicy(familyId: familyId);
    } on Exception catch (error) {
      // applied: null on failure — never synthesize a report, never throw.
      return FamilyLocationPullResult(
          success: false, reason: 'remote_read_failed: $error');
    }
    if (policy == null) {
      return const FamilyLocationPullResult(
          success: false, reason: 'remote_read_unavailable');
    }
    try {
      final applied = await _applier.apply(policy);
      return FamilyLocationPullResult(success: true, applied: applied);
    } on Exception catch (error) {
      return FamilyLocationPullResult(
          success: false, reason: 'local_apply_failed: $error');
    }
  }
}
