import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import '../domain/incident_engine.dart';
import '../domain/sos_config.dart';

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

  /// Applies remotely-delivered recipient documents for the readiness
  /// roster. Replaces the local row regardless of timestamp — the roster
  /// is authoritatively maintained by the parent platform. Never
  /// fabricates rows for malformed documents.
  Future<int> upsertRecipients(List<Map<String, Object?>> documents) async {
    final db = await _database.database;
    var applied = 0;
    for (final doc in documents) {
      final familyId = doc['familyId'] as String?;
      final recipientId = doc['recipientId'] as String?;
      if (familyId == null || recipientId == null) continue;
      await db.insert('sos_recipients', {
        'family_id': familyId,
        'recipient_id': recipientId,
        'role': doc['role'] ?? SosRecipientRole.responder.storageKey,
        'ordering': doc['ordering'] ?? 0,
        'added_at': doc['addedAt'] ??
            DateTime.now().toUtc().toIso8601String(),
        'sync_state': SyncState.synced.name
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      applied += 1;
    }
    return applied;
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

// ─────────────────────────── FS-006 extensions ───────────────────────
//
// SOS readiness: the recipient roster, the honest acknowledgement chain,
// and the guided drill. Nothing is ever assumed delivered — every row
// reflects an observed state.

extension SosRepositoryExtensions on SosRepository {
  /// Returns responders + notify-only recipients for a family, ordered.
  Future<List<SosRecipient>> recipientsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('sos_recipients',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'ordering ASC, added_at ASC');
    return rows.map(SosRecipient.fromMap).toList();
  }

  /// Stores (inserts or replaces) one roster recipient. Honesty: the roster
  /// is the single source of truth for the readiness dashboard.
  Future<void> saveRecipient(SosRecipient recipient) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('sos_recipients', recipient.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _enqueueOutbox(tx, _uuid, 'sosRecipient', recipient.recipientId,
          'sos.recipient', {
        'familyId': recipient.familyId,
        'recipientId': recipient.recipientId,
        'role': recipient.role.storageKey,
        'ordering': recipient.ordering,
        'addedAt': recipient.addedAt.toUtc().toIso8601String()
      });
    });
  }

  /// Removes a recipient from the roster. Does not delete past alert
  /// rows — acknowledgement history stays honest.
  Future<bool> deleteRecipient(
      {required String familyId, required String recipientId}) async {
    final db = await _database.database;
    final deleted = await db.delete('sos_recipients',
        where: 'family_id = ? AND recipient_id = ?',
        whereArgs: [familyId, recipientId]);
    return deleted > 0;
  }

  /// Activates SOS for the family: one honest event plus one notification
  /// row per recipient, so the acknowledgement chain is recipient-scoped.
  /// Returns the new event id, or null when an active SOS already exists.
  Future<String?> activateSosForFamily(String familyId,
      {String? deviceId,
      double? latitude,
      double? longitude,
      double? accuracyMeters}) async {
    final db = await _database.database;
    String? existingId;
    await db.transaction((tx) async {
      final events = await tx.query('sos_events',
          where:
              'family_id = ? AND status NOT IN (?, ?)',
          whereArgs: [familyId, SosState.cancelled.storageKey,
            SosState.acknowledged.storageKey],
          orderBy: 'created_at DESC',
          limit: 1);
      if (events.isNotEmpty) {
        existingId = events.single['id'] as String;
        return;
      }
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();
      await tx.insert('sos_events', {
        'id': id,
        'family_id': familyId,
        'device_id': deviceId,
        'status': SosState.localCreated.storageKey,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyMeters,
        'created_at': now.toIso8601String()
      });
      await _enqueueOutbox(tx, _uuid, 'sos', id, 'sos.created', {
        'familyId': familyId,
        'sosEventId': id,
        'deviceId': deviceId,
        'status': SosState.localCreated.storageKey,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'createdAt': now.toIso8601String()
      });
      // One honest notification row per roster recipient — the recipient
      // id is what acknowledgement and history screens key off of.
      final roster = await tx.query('sos_recipients',
          where: 'family_id = ?',
          whereArgs: [familyId],
          orderBy: 'ordering ASC');
      final nowStr = now.toIso8601String();
      for (final row in roster) {
        final recipientId = row['recipient_id'] as String;
        await tx.insert('notification_events', {
          'id': _uuid.v4(),
          'family_id': familyId,
          'sos_id': id,
          'recipient_id': recipientId,
          'kind': 'sos',
          'status': NotificationState.pendingBackend.storageKey,
          'requested_at': nowStr
        });
        await _enqueueOutbox(tx, _uuid, 'notification', id,
            'notification.requested', {
          'familyId': familyId,
          'notificationId': id,
          'sosId': id,
          'recipientId': recipientId,
          'kind': 'sos'
        });
      }
      existingId = id;
    });
    return existingId;
  }

  /// All notification rows (with recipient identity) for one SOS event.
  Future<List<Map<String, Object?>>> notificationsForSos(String sosId) async {
    final db = await _database.database;
    return db.query('notification_events',
        where: 'sos_id = ?',
        whereArgs: [sosId],
        orderBy: 'requested_at ASC');
  }

  /// The SOS event id that owns the given notification row — needed by
  /// SO-005, which is addressed by the notification row id but must scope
  /// its provider and drill queries to the parent sos event.
  Future<String?> sosIdForNotification(String notificationId) async {
    final db = await _database.database;
    final rows = await db.query('notification_events',
        where: 'id = ?', whereArgs: [notificationId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.single['sos_id'] as String?;
  }

  /// The currently live SOS event for a family, if any.
  Future<Map<String, Object?>?> activeSosForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('sos_events',
        where:
            'family_id = ? AND status NOT IN (?, ?)',
        whereArgs: [familyId, SosState.cancelled.storageKey,
          SosState.acknowledged.storageKey],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return rows.single;
  }

  /// Stands an SOS down. The honest record keeps the event as cancelled
  /// rather than erasing it.
  Future<bool> standDownSos(String sosId) =>
      transition(sosId: sosId, next: SosState.cancelled);

  /// A recipient acknowledges one SOS notification row. Only honest states
  /// are allowed to move (pendingBackend → ... → acknowledged).
  Future<bool> acknowledgeNotification(String notificationId) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final rows = await tx.query('notification_events',
          where: 'id = ?', whereArgs: [notificationId], limit: 1);
      if (rows.isEmpty) return false;
      final row = rows.single;
      final current =
          NotificationState.values.byName(row['status'] as String);
      final allowed = {
        NotificationState.pendingBackend,
        NotificationState.queued,
        NotificationState.notified,
      };
      if (!allowed.contains(current)) return false;
      final now = DateTime.now().toUtc().toIso8601String();
      await tx.update('notification_events',
          {'status': NotificationState.acknowledged.storageKey,
            'acknowledged_at': now},
          where: 'id = ?',
          whereArgs: [notificationId]);
      await _enqueueOutbox(tx, _uuid, 'notification', notificationId,
          'notification.acknowledged', {
        'familyId': row['family_id'],
        'notificationId': notificationId,
        'sosId': row['sos_id'],
        'recipientId': row['recipient_id'],
        'acknowledgedAt': now
      });
      // Advance the parent event to acknowledged only when every responder
      // row has acknowledged — the responder chain is the honest gate.
      final events = await tx.query('sos_events',
          where: 'id = ?', whereArgs: [row['sos_id']], limit: 1);
      if (events.isEmpty) return true;
      final event = events.single;
      final responders = await tx.query('notification_events',
          where: 'sos_id = ? AND recipient_id IS NOT NULL',
          whereArgs: [row['sos_id']]);
      final allRespondersAcks = responders.every((r) =>
          NotificationState.values.byName(r['status'] as String) ==
          NotificationState.acknowledged);
      final currentEvent = SosState.values.byName(event['status'] as String);
      if (allRespondersAcks &&
          SosLifecycle.canTransition(currentEvent, SosState.acknowledged)) {
        await tx.update('sos_events',
            {'status': SosState.acknowledged.storageKey,
              'delivered_at': DateTime.now().toUtc().toIso8601String()},
            where: 'id = ?',
            whereArgs: [event['id']]);
      }
      return true;
    });
  }

  /// Recent SOS events for the alert history view (SO-001).
  Future<List<Map<String, Object?>>> sosHistoryForFamily(String familyId,
      {int limit = 20}) async {
    final db = await _database.database;
    return db.query('sos_events',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC',
        limit: limit);
  }
}
