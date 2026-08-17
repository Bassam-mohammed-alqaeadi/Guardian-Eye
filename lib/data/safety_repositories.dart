import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import '../domain/incident_engine.dart';

class IncidentRepository {
  IncidentRepository(this._database, this._riskEngine, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final RiskEngine _riskEngine;
  final Uuid _uuid;

  Future<GuardianIncident?> recordObservation(
      {required String familyId,
      required SafetyObservation observation}) async {
    final decision = _riskEngine.evaluate(observation);
    if (!decision.createIncident || decision.severity == null) return null;
    final incident = GuardianIncident(
        id: _uuid.v4(),
        familyId: familyId,
        category: observation.category,
        severity: decision.severity!,
        confidence: observation.confidence,
        status: IncidentState.localPending,
        observedAt: observation.observedAt,
        modelVersion: observation.modelVersion,
        deviceId: observation.deviceId,
        actorUid: observation.actorUid);
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('incidents', {
        'id': incident.id,
        'family_id': familyId,
        'category': incident.category.storageKey,
        'severity': incident.severity.storageKey,
        'confidence': incident.confidence,
        'source': observation.source,
        'status': incident.status.storageKey,
        'observed_at': incident.observedAt.toIso8601String(),
        'model_version': incident.modelVersion,
        'device_id': incident.deviceId,
        'actor_uid': incident.actorUid,
        'created_at': DateTime.now().toUtc().toIso8601String()
      });
      await _enqueue(tx,
          aggregateType: 'incident',
          aggregateId: incident.id,
          operation: 'incident.created',
          payload: {
            'familyId': familyId,
            'incidentId': incident.id,
            'category': incident.category.storageKey,
            'severity': incident.severity.storageKey,
            'confidence': incident.confidence,
            'source': observation.source,
            'observedAt': incident.observedAt.toIso8601String(),
            'modelVersion': incident.modelVersion,
            // Identity fields — required for Firestore authorization:
            if (incident.deviceId != null) 'deviceId': incident.deviceId,
            if (incident.actorUid != null) 'actorUid': incident.actorUid,
          });
      await _requestNotification(tx,
          familyId: familyId, incidentId: incident.id, kind: 'incident');
    });
    return incident;
  }

  /// Unacknowledged incidents for a family, newest first. Used by the
  /// dashboard safety signal — a local read over the incidents table; it
  /// performs no mutation and makes no network call.
  Future<List<GuardianIncident>> unacknowledgedIncidentsForFamily(
      String familyId,
      {int limit = 10}) async {
    final db = await _database.database;
    final rows = await db.query(
      'incidents',
      where: 'family_id = ? AND status IN (?, ?)',
      whereArgs: [familyId, IncidentState.localPending.storageKey,
        IncidentState.synced.storageKey],
      orderBy: 'observed_at DESC',
      limit: limit,
    );
    return rows.map(GuardianIncident.fromMap).toList();
  }

  Future<bool> acknowledge({required String incidentId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('incidents',
          where: 'id = ?', whereArgs: [incidentId], limit: 1);
      if (rows.isEmpty) {
        return false;
      }
      final current =
          IncidentState.values.byName(rows.single['status'] as String);
      if (!IncidentLifecycle.canTransition(
          current, IncidentState.acknowledged)) {
        return false;
      }
      await tx.update(
          'incidents', {'status': IncidentState.acknowledged.storageKey},
          where: 'id = ?', whereArgs: [incidentId]);
      await _enqueue(tx,
          aggregateType: 'incident',
          aggregateId: incidentId,
          operation: 'incident.acknowledged',
          payload: {
            'familyId': rows.single['family_id'],
            'incidentId': incidentId
          });
      return true;
    });
  }

  Future<void> _enqueue(Transaction tx,
          {required String aggregateType,
          required String aggregateId,
          required String operation,
          required Map<String, Object?> payload}) async =>
      _enqueueOutbox(tx, _uuid, aggregateType, aggregateId, operation, payload);
}

class SosRepository {
  SosRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final GuardianDatabase _database;
  final Uuid _uuid;

  Future<String> createOfflineEvent(
      {required String familyId,
      String? deviceId,
      double? latitude,
      double? longitude,
      double? accuracyMeters}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('sos_events', {
        'id': id,
        'family_id': familyId,
        'device_id': deviceId,
        'status': SosState.pendingSync.storageKey,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyMeters,
        'created_at': now.toIso8601String()
      });
      await _enqueueOutbox(tx, _uuid, 'sos', id, 'sos.created', {
        'familyId': familyId,
        'sosEventId': id,
        'deviceId': deviceId,
        'status': SosState.pendingSync.storageKey,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'createdAt': now.toIso8601String()
      });
      await _requestNotification(tx,
          familyId: familyId, sosId: id, kind: 'sos');
    });
    return id;
  }

  Future<bool> transition(
      {required String sosId, required SosState next}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('sos_events',
          where: 'id = ?', whereArgs: [sosId], limit: 1);
      if (rows.isEmpty) return false;
      final current = SosState.values.byName(rows.single['status'] as String);
      if (!SosLifecycle.canTransition(current, next)) return false;
      await tx.update(
          'sos_events',
          {
            'status': next.storageKey,
            if (next == SosState.synced)
              'delivered_at': DateTime.now().toUtc().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [sosId]);
      await _enqueueOutbox(tx, _uuid, 'sos', sosId, 'sos.${next.storageKey}',
          {'familyId': rows.single['family_id'], 'sosEventId': sosId});
      return true;
    });
  }
}

Future<void> _requestNotification(Transaction tx,
    {required String familyId,
    String? incidentId,
    String? sosId,
    required String kind}) async {
  const uuid = Uuid();
  final id = uuid.v4();
  final now = DateTime.now().toUtc();
  await tx.insert('notification_events', {
    'id': id,
    'family_id': familyId,
    'incident_id': incidentId,
    'sos_id': sosId,
    'kind': kind,
    'status': NotificationState.pendingBackend.storageKey,
    'requested_at': now.toIso8601String()
  });
  await _enqueueOutbox(tx, uuid, 'notification', id, 'notification.requested',
      {'familyId': familyId, 'notificationId': id, 'kind': kind});
}

Future<void> _enqueueOutbox(Transaction tx, Uuid uuid, String aggregateType,
    String aggregateId, String operation, Map<String, Object?> payload) async {
  final now = DateTime.now().toUtc();
  final id = uuid.v4();
  await tx.insert('outbox', {
    'id': id,
    'aggregate_type': aggregateType,
    'aggregate_id': aggregateId,
    'operation': operation,
    'payload_json': jsonEncode(payload),
    'idempotency_key': id,
    'state': SyncState.queued.storageKey,
    'attempt_count': 0,
    'next_attempt_at': now.toIso8601String(),
    'created_at': now.toIso8601String()
  });
}
