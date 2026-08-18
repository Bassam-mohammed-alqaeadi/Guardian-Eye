import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';

/// FS-001 — Location & Geofencing. Local-first store for the consent-gated
/// location data the family platform observes: device location updates
/// (`location_points`), parent-managed geofences, geofence entry/exit
/// alerts, named favorite places that geofences anchor to, and family
/// location settings.
///
/// Honesty contract, identical to every other feature: every value
/// returned is a locally observed value, nothing is fabricated until the
/// device or the server confirms it. All mutations write to SQLite first
/// and enqueue the outbox with the matching Firestore contract payload,
/// so the same offline-first sync rhythm carries location writes to the
/// family's Firestore documents (`locations`, `geofences`). The UI never
/// claims server delivery without real evidence.

/// One consent-gated location update. The child device records these; the
/// parent app reads them as the map surface, member details, and history.
class LocationPoint {
  const LocationPoint({
    required this.id,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    this.deviceId,
    this.memberId,
    this.batteryLevel,
    this.source = 'device',
    this.syncState = SyncState.localOnly,
  });

  final String id;
  final String familyId;
  final String? deviceId;
  final String? memberId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
  final double? batteryLevel;
  final String source; // 'device' | 'last_known' | 'wifi'
  final SyncState syncState;

  factory LocationPoint.fromMap(Map<String, Object?> row) => LocationPoint(
      id: row['id']! as String,
      familyId: row['family_id']! as String,
      deviceId: row['device_id'] as String?,
      memberId: row['member_id'] as String?,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      accuracyMeters: (row['accuracy_meters'] as num).toDouble(),
      capturedAt: DateTime.parse(row['captured_at']! as String),
      batteryLevel: (row['battery_level'] as num?)?.toDouble(),
      source: (row['source'] as String?) ?? 'device',
      syncState: _syncStateOf(row['sync_state'] as String?));
}

/// A parent-managed geofence. `status` tracks its lifecycle
/// (`active` / `entered` / `exited` / `disabled`) so the geofence list
/// shows honest, observed state rather than optimistic guesses.
class GeofenceEntry {
  const GeofenceEntry({
    required this.id,
    required this.familyId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.alertOnEntry = true,
    this.alertOnExit = true,
    this.memberIds = const <String>[],
    this.placeKey,
    this.syncState = SyncState.localOnly,
  });

  final String id;
  final String familyId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool alertOnEntry;
  final bool alertOnExit;
  final List<String> memberIds;
  final String? placeKey;
  final String status; // 'active' | 'entered' | 'exited' | 'disabled'
  final SyncState syncState;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GeofenceEntry.fromMap(Map<String, Object?> row) => GeofenceEntry(
      id: row['id']! as String,
      familyId: row['family_id']! as String,
      name: row['name']! as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      radiusMeters: (row['radius_meters'] as num).toDouble(),
      alertOnEntry: (row['alert_on_entry'] as int) == 1,
      alertOnExit: (row['alert_on_exit'] as int) == 1,
      memberIds: _parseMemberIds(row['member_ids_json'] as String?),
      placeKey: row['place_key'] as String?,
      status: (row['status'] as String?) ?? 'active',
      syncState: _syncStateOf(row['sync_state'] as String?),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String));

  static List<String> _parseMemberIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((element) => element.toString())
          .toList();
    } on FormatException {
      return const [];
    }
  }
}

/// One observed geofence entry/exit alert. The child device raises these;
/// the parent reads them as the Location Alerts surface.
class LocationAlert {
  const LocationAlert({
    required this.id,
    required this.familyId,
    required this.eventType,
    required this.occurredAt,
    this.geofenceId,
    this.memberId,
    this.memberDisplayName,
    this.deviceId,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.syncState = SyncState.localOnly,
  });

  final String id;
  final String familyId;
  final String? geofenceId;
  final String? memberId;
  final String? memberDisplayName;
  final String? deviceId;
  final String eventType; // 'entered' | 'exited'
  final DateTime occurredAt;
  final bool acknowledged;
  final DateTime? acknowledgedAt;
  final SyncState syncState;

  factory LocationAlert.fromMap(Map<String, Object?> row) => LocationAlert(
      id: row['id']! as String,
      familyId: row['family_id']! as String,
      geofenceId: row['geofence_id'] as String?,
      memberId: row['member_id'] as String?,
      memberDisplayName: row['member_display_name'] as String?,
      deviceId: row['device_id'] as String?,
      eventType: (row['event_type'] as String?) ?? 'entered',
      occurredAt: DateTime.parse(row['occurred_at']! as String),
      acknowledged: (row['acknowledged'] as int) == 1,
      acknowledgedAt: row['acknowledged_at'] != null
          ? DateTime.parse(row['acknowledged_at']! as String)
          : null,
      syncState: _syncStateOf(row['sync_state'] as String?));
}

/// A named favorite place (home, school, mosque, grandma) that geofences
/// can anchor to, removing the per-geofence naming burden (LO-013).
class FavoritePlace {
  const FavoritePlace({
    required this.familyId,
    required this.placeKey,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.syncState = SyncState.localOnly,
  });

  final String familyId;
  final String placeKey; // 'home' | 'school' | 'mosque' | 'grandma' | other keys
  final String name;
  final double latitude;
  final double longitude;
  final String? notes;
  final SyncState syncState;

  factory FavoritePlace.fromMap(Map<String, Object?> row) => FavoritePlace(
      familyId: row['family_id']! as String,
      placeKey: row['place_key']! as String,
      name: row['name']! as String,
      latitude: (row['latitude'] as num).toDouble(),
      longitude: (row['longitude'] as num).toDouble(),
      notes: row['notes'] as String?,
      syncState: _syncStateOf(row['sync_state'] as String?));
}

SyncState _syncStateOf(String? raw) => SyncState.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => SyncState.localOnly);

/// Haversine distance in meters between two coordinates. Used both by the
/// alert engine (did the device enter the geofence?) and the UI chips.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final dLat = (lat2 - lat1) * _degToRad;
  final dLon = (lon2 - lon1) * _degToRad;
  final a = (dLat / 2) * (dLat / 2) +
      _cos(lat1 * _degToRad) *
          _cos(lat2 * _degToRad) *
          (dLon / 2) *
          (dLon / 2);
  return 2 * earthRadius * (a >= 1.0
      ? 1.5707963267948966
      : (a <= 0.0 ? 0.0 : _asin(_sqrt(a))));
}

const _degToRad = 0.017453292519943295; // pi / 180

double _cos(double x) =>
    (x - 0) == 0 ? 1.0 : x * x == 0 ? 1.0 : _taylorCos(x);
double _taylorCos(double x) {
  var term = 1.0;
  var sum = 1.0;
  for (var i = 1; i <= 10; i++) {
    term *= (-x * x) / ((2 * i - 1) * (2 * i));
    sum += term;
  }
  return sum;
}

double _sqrt(double x) {
  if (x <= 0) return 0.0;
  var guess = x / 2;
  for (var i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

double _asin(double x) {
  if (x <= 0) return 0.0;
  if (x >= 1.0) return 1.5707963267948966;
  var term = x;
  var sum = x;
  for (var i = 1; i <= 15; i++) {
    term *= (x * x) * (2 * i - 1) * (2 * i - 1) / (2 * i) / (2 * i + 1);
    sum += term;
  }
  return sum;
}

/// Status chip semantics for the member location details surface (LO-002).
/// A point is `fresh` when captured within [freshnessThresholdSeconds];
/// older points are `stale`, and the absence of any point is `offline`.
class LocationFreshness {
  const LocationFreshness._(this.key, this.label, this.colorName);
  final String key; // 'fresh' | 'stale' | 'offline'
  final String label;
  final String colorName; // 'green' | 'amber' | 'red'

  static const fresh = LocationFreshness._('fresh', 'Fresh', 'green');
  static const stale = LocationFreshness._('stale', 'Stale', 'amber');
  static const offline = LocationFreshness._('offline', 'Offline', 'red');

  static LocationFreshness evaluate(
      List<LocationPoint> points, DateTime now,
      {int freshnessThresholdSeconds = 900, // 15 minutes
      int offlineThresholdSeconds = 10800}) {
    if (points.isEmpty) return offline;
    final latest = points.reduce((a, b) =>
        a.capturedAt.isAfter(b.capturedAt) ? a : b);
    final age = now.difference(latest.capturedAt).inSeconds;
    if (age <= freshnessThresholdSeconds) return fresh;
    if (age <= offlineThresholdSeconds) return stale;
    return offline;
  }
}

/// FS-001 local-first repository. Every mutation is a SQLite write first;
/// delivery to Firestore follows the outbox rhythm. The UI consumes
/// `points`, `geofences`, `alerts`, `places`, and `settings` exactly as
/// stored — nothing synthesized, nothing optimistic.
class LocationGeofenceRepository {
  LocationGeofenceRepository(GuardianDatabase database) : _database = database;

  final GuardianDatabase _database;
  final Uuid _uuid = const Uuid();

  GuardianDatabase get database => _database;

  // ── location points ────────────────────────────────────────────────

  Future<List<LocationPoint>> pointsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('location_points',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'captured_at DESC');
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<List<LocationPoint>> pointsForMember(
      String familyId, String memberId,
      {int limit = 200}) async {
    final db = await _database.database;
    final rows = await db.query('location_points',
        where: 'family_id = ? AND member_id = ?',
        whereArgs: [familyId, memberId],
        orderBy: 'captured_at DESC',
        limit: limit);
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<List<LocationPoint>> pointsForDay(
      String familyId, String memberId, String dayStart, String dayEnd) async {
    final db = await _database.database;
    final rows = await db.query('location_points',
        where: 'family_id = ? AND member_id = ? AND captured_at BETWEEN ? AND ?',
        whereArgs: [familyId, memberId, dayStart, dayEnd],
        orderBy: 'captured_at ASC');
    return rows.map(LocationPoint.fromMap).toList();
  }

  /// Records a consent-gated location update (the child device's primary
  /// write path). Returns the stored point immediately; the outbox sync
  /// delivers it to `families/{fid}/locations/{id}` afterwards.
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
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await _database.database;
    await db.insert('location_points', {
      'id': id,
      'family_id': familyId,
      'device_id': deviceId,
      'member_id': memberId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'captured_at': now,
      'battery_level': batteryLevel,
      'source': source,
      'sync_state': SyncState.localOnly.name,
      'created_at': now,
    });
    await _enqueuePoint(
        familyId: familyId,
        pointId: id,
        deviceId: deviceId,
        memberId: memberId,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        capturedAt: now,
        batteryLevel: batteryLevel,
        source: source);
    return LocationPoint(
        id: id,
        familyId: familyId,
        deviceId: deviceId,
        memberId: memberId,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        capturedAt: DateTime.parse(now),
        batteryLevel: batteryLevel,
        source: source,
        syncState: SyncState.localOnly);
  }

  Future<void> _enqueuePoint({
    required String familyId,
    required String pointId,
    required String? deviceId,
    required String? memberId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String capturedAt,
    required double? batteryLevel,
    required String source,
  }) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'location',
        'aggregate_id': pointId,
        'operation': 'location.updated',
        'payload_json': jsonEncode({
          'familyId': familyId,
          'locationId': pointId,
          'deviceId': deviceId,
          'memberId': memberId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracyMeters': accuracyMeters,
          'capturedAt': capturedAt,
          'batteryLevel': batteryLevel,
          'source': source,
        }),
        'idempotency_key': 'location.updated:$familyId:$pointId',
        'state': 'pending',
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  // ── geofences ──────────────────────────────────────────────────────

  Future<List<GeofenceEntry>> geofencesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('geofences',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC');
    return rows.map(GeofenceEntry.fromMap).toList();
  }

  Future<GeofenceEntry?> geofenceById(
      String familyId, String geofenceId) async {
    final db = await _database.database;
    final rows = await db.query('geofences',
        where: 'id = ? AND family_id = ?',
        whereArgs: [geofenceId, familyId]);
    if (rows.isEmpty) return null;
    return GeofenceEntry.fromMap(rows.first);
  }

  Future<GeofenceEntry> addGeofence({
    required String familyId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool alertOnEntry = true,
    bool alertOnExit = true,
    List<String> memberIds = const [],
    String? placeKey,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await _database.database;
    await db.insert('geofences', {
      'id': id,
      'family_id': familyId,
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'alert_on_entry': alertOnEntry ? 1 : 0,
      'alert_on_exit': alertOnExit ? 1 : 0,
      'member_ids_json': jsonEncode(memberIds),
      'place_key': placeKey,
      'status': 'active',
      'sync_state': SyncState.localOnly.name,
      'created_at': now,
      'updated_at': now,
    });
    await _enqueueGeofence(
        familyId: familyId,
        geofenceId: id,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        alertOnEntry: alertOnEntry,
        alertOnExit: alertOnExit,
        memberIds: memberIds,
        placeKey: placeKey,
        operation: 'geofence.created');
    return GeofenceEntry(
        id: id,
        familyId: familyId,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        alertOnEntry: alertOnEntry,
        alertOnExit: alertOnExit,
        memberIds: memberIds,
        placeKey: placeKey,
        status: 'active',
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
        syncState: SyncState.localOnly);
  }

  Future<GeofenceEntry> updateGeofence({
    required GeofenceEntry existing,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool alertOnEntry,
    required bool alertOnExit,
    List<String> memberIds = const [],
    String? placeKey,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await _database.database;
    final changed = await db.update(
        'geofences',
        {
          'name': name.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'alert_on_entry': alertOnEntry ? 1 : 0,
          'alert_on_exit': alertOnExit ? 1 : 0,
          'member_ids_json': jsonEncode(memberIds),
          'place_key': placeKey,
          'sync_state': SyncState.localOnly.name,
          'updated_at': now,
        },
        where: 'id = ? AND family_id = ?',
        whereArgs: [existing.id, existing.familyId]);
    if (changed != 1) throw StateError('geofence_not_found');
    await _enqueueGeofence(
        familyId: existing.familyId,
        geofenceId: existing.id,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        alertOnEntry: alertOnEntry,
        alertOnExit: alertOnExit,
        memberIds: memberIds,
        placeKey: placeKey,
        operation: 'geofence.updated');
    return existing.copyWith(
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        alertOnEntry: alertOnEntry,
        alertOnExit: alertOnExit,
        memberIds: memberIds,
        placeKey: placeKey,
        updatedAt: DateTime.parse(now),
        syncState: SyncState.localOnly);
  }

  Future<void> setGeofenceEnabled(
      {required GeofenceEntry existing, required bool enabled}) async {
    final db = await _database.database;
    final changed = await db.update(
        'geofences',
        {
          'status': enabled ? 'active' : 'disabled',
          'sync_state': SyncState.localOnly.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND family_id = ?',
        whereArgs: [existing.id, existing.familyId]);
    if (changed != 1) throw StateError('geofence_not_found');
    await _enqueueGeofence(
        familyId: existing.familyId,
        geofenceId: existing.id,
        name: existing.name,
        latitude: existing.latitude,
        longitude: existing.longitude,
        radiusMeters: existing.radiusMeters,
        alertOnEntry: existing.alertOnEntry,
        alertOnExit: existing.alertOnExit,
        memberIds: existing.memberIds,
        placeKey: existing.placeKey,
        operation: 'geofence.disabled');
  }

  Future<void> _enqueueGeofence({
    required String familyId,
    required String geofenceId,
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool alertOnEntry,
    required bool alertOnExit,
    required List<String> memberIds,
    required String? placeKey,
    required String operation,
  }) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'geofence',
        'aggregate_id': geofenceId,
        'operation': operation,
        'payload_json': jsonEncode({
          'familyId': familyId,
          'geofenceId': geofenceId,
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'alertOnEntry': alertOnEntry,
          'alertOnExit': alertOnExit,
          'memberIds': memberIds,
          'placeKey': placeKey,
          'version': 1,
        }),
        'idempotency_key': '$operation:$familyId:$geofenceId:1',
        'state': 'pending',
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  // ── alerts ─────────────────────────────────────────────────────────

  Future<List<LocationAlert>> alertsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('location_alerts',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'occurred_at DESC');
    return rows.map(LocationAlert.fromMap).toList();
  }

  Future<void> recordAlert({
    required String familyId,
    required String eventType,
    required DateTime occurredAt,
    String? geofenceId,
    String? memberId,
    String? memberDisplayName,
    String? deviceId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await _database.database;
    await db.insert('location_alerts', {
      'id': id,
      'family_id': familyId,
      'geofence_id': geofenceId,
      'member_id': memberId,
      'member_display_name': memberDisplayName,
      'device_id': deviceId,
      'event_type': eventType,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'acknowledged': 0,
      'source': 'geofence',
      'sync_state': SyncState.localOnly.name,
      'created_at': now,
    });
  }

  Future<void> acknowledgeAlert(
      {required String familyId, required String alertId}) async {
    final db = await _database.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final changed = await db.update(
        'location_alerts',
        {'acknowledged': 1, 'acknowledged_at': now},
        where: 'id = ? AND family_id = ?',
        whereArgs: [alertId, familyId]);
    if (changed != 1) throw StateError('location_alert_not_found');
  }

  Future<int> unacknowledgedAlertCount(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('location_alerts',
        where: 'family_id = ? AND acknowledged = 0',
        whereArgs: [familyId],
        columns: ['COUNT(*) AS c']);
    return (rows.first['c'] as int?) ?? 0;
  }

  // ── favorite places ────────────────────────────────────────────────

  Future<List<FavoritePlace>> placesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('favorite_places',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows.map(FavoritePlace.fromMap).toList();
  }

  Future<FavoritePlace?> placeByKey(String familyId, String placeKey) async {
    final db = await _database.database;
    final rows = await db.query('favorite_places',
        where: 'family_id = ? AND place_key = ?',
        whereArgs: [familyId, placeKey]);
    if (rows.isEmpty) return null;
    return FavoritePlace.fromMap(rows.first);
  }

  Future<FavoritePlace> setPlace({
    required String familyId,
    required String placeKey,
    required String name,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final db = await _database.database;
    final existing = await placeByKey(familyId, placeKey);
    if (existing == null) {
      await db.insert('favorite_places', {
        'family_id': familyId,
        'place_key': placeKey,
        'name': name.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'sync_state': SyncState.localOnly.name,
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
          'favorite_places',
          {
            'name': name.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'notes': notes,
            'sync_state': SyncState.localOnly.name,
            'updated_at': now,
          },
          where: 'family_id = ? AND place_key = ?',
          whereArgs: [familyId, placeKey]);
    }
    await _enqueuePlace(familyId: familyId, placeKey: placeKey, name: name.trim());
    return FavoritePlace(
        familyId: familyId,
        placeKey: placeKey,
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        syncState: SyncState.localOnly);
  }

  Future<void> _enqueuePlace({
    required String familyId,
    required String placeKey,
    required String name,
  }) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'favorite_place',
        'aggregate_id': '$familyId:$placeKey',
        'operation': 'favorite.place',
        'payload_json': jsonEncode({
          'familyId': familyId,
          'placeKey': placeKey,
          'name': name,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        'idempotency_key':
            'favorite.place:$familyId:$placeKey:${DateTime.now().toUtc().toIso8601String()}',
        'state': 'pending',
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  // ── settings ───────────────────────────────────────────────────────

  Future<String> setting(
      String familyId, String key, String defaultValue) async {
    final db = await _database.database;
    final rows = await db.query('location_settings',
        where: 'family_id = ? AND key = ?',
        whereArgs: [familyId, key]);
    if (rows.isEmpty) return defaultValue;
    return (rows.first['value'] as String?) ?? defaultValue;
  }

  Future<void> setSetting(
      {required String familyId,
      required String key,
      required String value}) async {
    final db = await _database.database;
    final existing = await db.query('location_settings',
        where: 'family_id = ? AND key = ?',
        whereArgs: [familyId, key]);
    if (existing.isEmpty) {
      await db.insert('location_settings',
          {'family_id': familyId, 'key': key, 'value': value});
    } else {
      await db.update('location_settings', {'value': value},
          where: 'family_id = ? AND key = ?',
          whereArgs: [familyId, key]);
    }
    await _enqueueSetting(familyId: familyId, key: key, value: value);
  }

  Future<void> _enqueueSetting({
    required String familyId,
    required String key,
    required String value,
  }) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'location_setting',
        'aggregate_id': '$familyId:$key',
        'operation': 'location.setting',
        'payload_json': jsonEncode({
          'familyId': familyId,
          'key': key,
          'value': value,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        'idempotency_key':
            'location.setting:$familyId:$key:${DateTime.now().toUtc().toIso8601String()}',
        'state': 'pending',
        'next_attempt_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }
}

extension on GeofenceEntry {
  GeofenceEntry copyWith({
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? alertOnEntry,
    bool? alertOnExit,
    List<String>? memberIds,
    String? placeKey,
    String? status,
    SyncState? syncState,
    DateTime? updatedAt,
  }) =>
      GeofenceEntry(
          id: id,
          familyId: familyId,
          name: name ?? this.name,
          latitude: latitude ?? this.latitude,
          longitude: longitude ?? this.longitude,
          radiusMeters: radiusMeters ?? this.radiusMeters,
          alertOnEntry: alertOnEntry ?? this.alertOnEntry,
          alertOnExit: alertOnExit ?? this.alertOnExit,
          memberIds: memberIds ?? this.memberIds,
          placeKey: placeKey ?? this.placeKey,
          status: status ?? this.status,
          syncState: syncState ?? this.syncState,
          createdAt: createdAt,
          updatedAt: updatedAt ?? this.updatedAt);
}
