import 'dart:math' as math;

import '../data/location_repository.dart';

/// Pure-Dart geofence crossing evaluator for M9 background tracking.
///
/// Deliberately free of I/O: it decides crossings from a snapshot
/// (current point + geofence rows). The repository layer is the only
/// place that records the resulting alerts and mutates geofence status,
/// which keeps this logic unit-testable without SQLite or the device.

/// Haversine distance in meters between two WGS-84 points.
double haversineDistanceMeters({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusMeters = 6371008.8;
  final lat1Rad = lat1 * _deg2Rad;
  final lat2Rad = lat2 * _deg2Rad;
  final dLat = (lat2 - lat1) * _deg2Rad;
  final dLon = (lon2 - lon1) * _deg2Rad;
  final h = _sin2(dLat / 2) + _cos2(lat1Rad) * _cos2(lat2Rad) * _sin2(dLon / 2);
  return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
}

const double _deg2Rad = 3.1415926535897932 / 180.0;
double _sin2(double x) {
  final s = math.sin(x);
  return s * s;
}

double _cos2(double x) {
  final c = math.cos(x);
  return c * c;
}

/// A single geofence crossing decision.
class GeofenceCrossing {
  const GeofenceCrossing({
    required this.geofence,
    required this.eventType,
    required this.distanceMeters,
  });

  final GeofenceEntry geofence;

  /// `geofence_entry` | `geofence_exit`.
  final String eventType;
  final double distanceMeters;
}

/// Evaluates crossings for one captured point against the active
/// geofences of the family.
///
/// Honesty rules:
///  - a disabled geofence never crosses;
///  - an alert is generated only when the matching alert flag is on;
///  - the status machine is consulted (`active`↔`entered`↔`exited`) so
///    a re-entry after an exit can alert again.
List<GeofenceCrossing> evaluateGeofenceCrossings({
  required List<GeofenceEntry> geofences,
  required double latitude,
  required double longitude,
}) {
  final crossings = <GeofenceCrossing>[];
  for (final geofence in geofences) {
    if (geofence.status == 'disabled') continue;
    final distance = haversineDistanceMeters(
      lat1: latitude,
      lon1: longitude,
      lat2: geofence.latitude,
      lon2: geofence.longitude,
    );
    final inside = distance <= geofence.radiusMeters;
    if (inside && geofence.status != 'entered' && geofence.alertOnEntry) {
      crossings.add(GeofenceCrossing(
          geofence: geofence,
          eventType: 'geofence_entry',
          distanceMeters: distance));
    } else if (!inside &&
        geofence.status == 'entered' &&
        geofence.alertOnExit) {
      crossings.add(GeofenceCrossing(
          geofence: geofence,
          eventType: 'geofence_exit',
          distanceMeters: distance));
    }
  }
  return crossings;
}
