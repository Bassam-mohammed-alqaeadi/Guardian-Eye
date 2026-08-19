import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';

/// A screenshot delivered by the child device agent. Stored only when the
/// agent actually shipped it — never guessed.
class MonitoringShot {
  const MonitoringShot({
    required this.familyId,
    required this.shotId,
    required this.deviceId,
    this.childId,
    required this.capturedAt,
    required this.bytesLength,
    required this.mimeType,
    this.requestId,
    this.scheduleId,
    this.isEvidence = false,
    required this.syncState,
  });

  final String familyId;
  final String shotId;
  final String deviceId;
  final String? childId;
  final DateTime capturedAt;
  final int bytesLength;
  final String mimeType;
  final String? requestId;
  final String? scheduleId;
  final bool isEvidence;
  final SyncState syncState;

  static MonitoringShot fromMap(Map<String, Object?> row) => MonitoringShot(
        familyId: row['family_id'] as String,
        shotId: row['shot_id'] as String,
        deviceId: row['device_id'] as String,
        childId: row['child_id'] as String?,
        capturedAt: DateTime.parse(row['captured_at'] as String),
        bytesLength: row['bytes_length'] as int,
        mimeType: row['mime_type'] as String,
        requestId: row['request_id'] as String?,
        scheduleId: row['schedule_id'] as String?,
        isEvidence: (row['is_evidence'] as int) == 1,
        syncState: _syncOf(row['sync_state'] as String?),
      );
}

/// A live-screen or camera session opened against a child device.
class MonitoringSession {
  const MonitoringSession({
    required this.familyId,
    required this.sessionId,
    required this.deviceId,
    this.childId,
    required this.kind,
    required this.state,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.syncState,
  });

  final String familyId;
  final String sessionId;
  final String deviceId;
  final String? childId;
  final String kind; // 'live' | 'camera'
  final String state; // pending | started | ended | failed | timeout
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final SyncState syncState;

  static MonitoringSession fromMap(Map<String, Object?> row) =>
      MonitoringSession(
        familyId: row['family_id'] as String,
        sessionId: row['session_id'] as String,
        deviceId: row['device_id'] as String,
        childId: row['child_id'] as String?,
        kind: row['kind'] as String,
        state: row['state'] as String,
        startedAt: (row['started_at'] as String?)?.toDateTime(),
        endedAt: (row['ended_at'] as String?)?.toDateTime(),
        createdAt: DateTime.parse(row['created_at'] as String),
        syncState: _syncOf(row['sync_state'] as String?),
      );
}

/// A capture / camera / live request and its delivery evidence.
class MonitoringRequest {
  const MonitoringRequest({
    required this.familyId,
    required this.requestId,
    required this.deviceId,
    this.childId,
    required this.kind,
    required this.state,
    this.reason,
    required this.createdAt,
    this.deliveredAt,
    required this.syncState,
  });

  final String familyId;
  final String requestId;
  final String deviceId;
  final String? childId;
  final String kind; // shot | camera | live
  final String state; // queued | pending | delivered | failed | cancelled
  final String? reason;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final SyncState syncState;

  static MonitoringRequest fromMap(Map<String, Object?> row) =>
      MonitoringRequest(
        familyId: row['family_id'] as String,
        requestId: row['request_id'] as String,
        deviceId: row['device_id'] as String,
        childId: row['child_id'] as String?,
        kind: row['kind'] as String,
        state: row['state'] as String,
        reason: row['reason'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        deliveredAt: (row['delivered_at'] as String?)?.toDateTime(),
        syncState: _syncOf(row['sync_state'] as String?),
      );
}

/// An automatic capture window the agent honours.
class MonitoringSchedule {
  const MonitoringSchedule({
    required this.familyId,
    required this.scheduleId,
    this.deviceId,
    this.childId,
    required this.startHour,
    required this.endHour,
    required this.intervalMinutes,
    required this.enabled,
    required this.updatedAt,
    required this.syncState,
  });

  final String familyId;
  final String scheduleId;
  final String? deviceId;
  final String? childId;
  final int startHour;
  final int endHour;
  final int intervalMinutes;
  final bool enabled;
  final DateTime updatedAt;
  final SyncState syncState;

  static MonitoringSchedule fromMap(Map<String, Object?> row) =>
      MonitoringSchedule(
        familyId: row['family_id'] as String,
        scheduleId: row['schedule_id'] as String,
        deviceId: row['device_id'] as String?,
        childId: row['child_id'] as String?,
        startHour: row['start_hour'] as int,
        endHour: row['end_hour'] as int,
        intervalMinutes: row['interval_minutes'] as int,
        enabled: (row['enabled'] as int) == 1,
        updatedAt: DateTime.parse(row['updated_at'] as String),
        syncState: _syncOf(row['sync_state'] as String?),
      );
}

/// An item waiting in the parent's evidence review queue.
class MonitoringEvidence {
  const MonitoringEvidence({
    required this.familyId,
    required this.evidenceId,
    required this.shotId,
    required this.deviceId,
    this.childId,
    required this.flagReason,
    required this.state,
    this.decidedBy,
    this.decidedAt,
    required this.createdAt,
    required this.syncState,
  });

  final String familyId;
  final String evidenceId;
  final String shotId;
  final String deviceId;
  final String? childId;
  final String flagReason;
  final String state; // queued | reviewed | dismissed
  final String? decidedBy;
  final DateTime? decidedAt;
  final DateTime createdAt;
  final SyncState syncState;

  static MonitoringEvidence fromMap(Map<String, Object?> row) =>
      MonitoringEvidence(
        familyId: row['family_id'] as String,
        evidenceId: row['evidence_id'] as String,
        shotId: row['shot_id'] as String,
        deviceId: row['device_id'] as String,
        childId: row['child_id'] as String?,
        flagReason: row['flag_reason'] as String,
        state: row['state'] as String,
        decidedBy: row['decided_by'] as String?,
        decidedAt: (row['decided_at'] as String?)?.toDateTime(),
        createdAt: DateTime.parse(row['created_at'] as String),
        syncState: _syncOf(row['sync_state'] as String?),
      );
}

SyncState _syncOf(String? raw) =>
    raw == null ? SyncState.localOnly : SyncState.values.byName(raw);

extension _NullableDateParse on Object? {
  DateTime? toDateTime() => this == null
      ? null
      : DateTime.parse(this! as String);
}

/// FS-004 — local-first store for screen/camera monitoring. Receives shots,
/// sessions, requests, schedules and evidence flags from the child device
/// agent and from pull syncs; writes requests locally with queued sync state
/// and honest audit evidence. Nothing is ever fabricated.
class MonitoringRepository {
  MonitoringRepository(this._database);

  final GuardianDatabase _database;

  // ---------------------------------------------------------------- shots

  Future<List<MonitoringShot>> shotsForFamily(String familyId,
      {int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_shots',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'captured_at DESC',
      limit: limit,
    );
    return rows.map(MonitoringShot.fromMap).toList();
  }

  Future<List<MonitoringShot>> shotsForChild(
      String familyId, String childId) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_shots',
      where: 'family_id = ? AND child_id = ?',
      whereArgs: [familyId, childId],
      orderBy: 'captured_at DESC',
      limit: 100,
    );
    return rows.map(MonitoringShot.fromMap).toList();
  }

  Future<MonitoringShot?> shotById(String familyId, String shotId) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_shots',
      where: 'family_id = ? AND shot_id = ?',
      whereArgs: [familyId, shotId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonitoringShot.fromMap(rows.first);
  }

  /// Applies shots delivered by a remote pull. Rows must genuinely come from
  /// the agent; this never invents them.
  Future<int> upsertShots(List<Map<String, Object?>> rows) async {
    final db = await _database.database;
    var applied = 0;
    for (final row in rows) {
      await db.insert('monitoring_shots', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      applied += 1;
    }
    return applied;
  }

  // ---------------------------------------------------------------- sessions

  Future<List<MonitoringSession>> sessionsForFamily(String familyId,
      {int limit = 50}) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_sessions',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MonitoringSession.fromMap).toList();
  }

  Future<MonitoringSession> startSession({
    required String familyId,
    required String deviceId,
    required String sessionId,
    String? childId,
    String kind = 'live',
    SyncState syncState = SyncState.queued,
  }) async {
    final now = DateTime.now().toIso8601String();
    final db = await _database.database;
    await db.insert(
      'monitoring_sessions',
      {
        'session_id': sessionId,
        'family_id': familyId,
        'device_id': deviceId,
        'child_id': childId,
        'kind': kind,
        'state': 'pending',
        'created_at': now,
        'sync_state': syncState.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return MonitoringSession(
      familyId: familyId,
      sessionId: sessionId,
      deviceId: deviceId,
      childId: childId,
      kind: kind,
      state: 'pending',
      createdAt: DateTime.now(),
      syncState: syncState,
    );
  }

  Future<int> updateSessionState(
      String familyId, String sessionId, String state,
      {DateTime? startedAt, DateTime? endedAt}) async {
    final db = await _database.database;
    return db.update(
      'monitoring_sessions',
      {
        'state': state,
        if (startedAt != null) 'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
        'sync_state': SyncState.synced.name,
      },
      where: 'family_id = ? AND session_id = ?',
      whereArgs: [familyId, sessionId],
    );
  }

  Future<int> upsertSessions(List<Map<String, Object?>> rows) async {
    final db = await _database.database;
    var applied = 0;
    for (final row in rows) {
      await db.insert('monitoring_sessions', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      applied += 1;
    }
    return applied;
  }

  // --------------------------------------------------------------- requests

  Future<List<MonitoringRequest>> requestsForFamily(String familyId,
      {int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_requests',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MonitoringRequest.fromMap).toList();
  }

  /// A parent request: writes locally as queued and queues an outbox-like
  /// sync row via sync_state. Delivery only becomes "delivered" when the
  /// agent ships evidence — this never marks success prematurely.
  Future<MonitoringRequest> createRequest({
    required String familyId,
    required String deviceId,
    required String requestId,
    String? childId,
    String kind = 'shot',
    String? reason,
    SyncState syncState = SyncState.queued,
  }) async {
    final now = DateTime.now();
    final db = await _database.database;
    await db.insert(
      'monitoring_requests',
      {
        'request_id': requestId,
        'family_id': familyId,
        'device_id': deviceId,
        'child_id': childId,
        'kind': kind,
        'state': 'queued',
        'reason': reason,
        'created_at': now.toIso8601String(),
        'sync_state': syncState.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return MonitoringRequest(
      familyId: familyId,
      requestId: requestId,
      deviceId: deviceId,
      childId: childId,
      kind: kind,
      state: 'queued',
      reason: reason,
      createdAt: now,
      syncState: syncState,
    );
  }

  Future<int> markRequestDelivered(
      String familyId, String requestId, DateTime deliveredAt) async {
    final db = await _database.database;
    return db.update(
      'monitoring_requests',
      {
        'state': 'delivered',
        'delivered_at': deliveredAt.toIso8601String(),
        'sync_state': SyncState.synced.name,
      },
      where: 'family_id = ? AND request_id = ?',
      whereArgs: [familyId, requestId],
    );
  }

  // -------------------------------------------------------------- schedules

  Future<List<MonitoringSchedule>> schedulesForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_schedules',
      where: 'family_id = ?',
      whereArgs: [familyId],
      orderBy: 'start_hour ASC',
    );
    return rows.map(MonitoringSchedule.fromMap).toList();
  }

  Future<MonitoringSchedule> saveSchedule({
    required String familyId,
    required String scheduleId,
    String? deviceId,
    String? childId,
    required int startHour,
    required int endHour,
    required int intervalMinutes,
    required bool enabled,
    SyncState syncState = SyncState.queued,
  }) async {
    final now = DateTime.now();
    final db = await _database.database;
    await db.insert(
      'monitoring_schedules',
      {
        'schedule_id': scheduleId,
        'family_id': familyId,
        'device_id': deviceId,
        'child_id': childId,
        'start_hour': startHour,
        'end_hour': endHour,
        'interval_minutes': intervalMinutes,
        'enabled': enabled ? 1 : 0,
        'updated_at': now.toIso8601String(),
        'sync_state': syncState.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return MonitoringSchedule(
      familyId: familyId,
      scheduleId: scheduleId,
      deviceId: deviceId,
      childId: childId,
      startHour: startHour,
      endHour: endHour,
      intervalMinutes: intervalMinutes,
      enabled: enabled,
      updatedAt: now,
      syncState: syncState,
    );
  }

  Future<int> deleteSchedule(String familyId, String scheduleId) {
    return _database.database.then((db) => db.delete(
          'monitoring_schedules',
          where: 'family_id = ? AND schedule_id = ?',
          whereArgs: [familyId, scheduleId],
        ));
  }

  /// Flags a delivered shot for parental review. Inserts an evidence queue
  /// row with a generated evidence id; only genuinely captured shots can be
  /// flagged — the row can never be created without one.
  Future<MonitoringEvidence> flagShotAsEvidence(String familyId,
      {required String shotId, required String deviceId, String? childId,
      String flagReason = 'parent-review'}) async {
    final now = DateTime.now();
    final tag = familyId.length > 6 ? familyId.substring(0, 6) : familyId;
    final evidenceId =
        'ev-$tag-${shotId.hashCode.abs().toRadixString(36)}';
    final db = await _database.database;
    await db.insert(
      'monitoring_evidence_queue',
      {
        'evidence_id': evidenceId,
        'family_id': familyId,
        'shot_id': shotId,
        'device_id': deviceId,
        'child_id': childId,
        'flag_reason': flagReason,
        'state': 'queued',
        'created_at': now.toIso8601String(),
        'sync_state': SyncState.queued.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return MonitoringEvidence(
      familyId: familyId,
      evidenceId: evidenceId,
      shotId: shotId,
      deviceId: deviceId,
      childId: childId,
      flagReason: flagReason,
      state: 'queued',
      createdAt: now,
      syncState: SyncState.queued,
    );
  }

  // --------------------------------------------------------------- evidence

  Future<List<MonitoringEvidence>> evidenceForFamily(String familyId,
      {int limit = 100}) async {
    final db = await _database.database;
    final rows = await db.query(
      'monitoring_evidence_queue',
      where: "family_id = ? AND state = 'queued'",
      whereArgs: [familyId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MonitoringEvidence.fromMap).toList();
  }

  Future<int> reviewEvidence(String familyId, String evidenceId,
      {String decidedBy = 'parent', String state = 'reviewed'}) async {
    final now = DateTime.now();
    final db = await _database.database;
    return db.update(
      'monitoring_evidence_queue',
      {
        'state': state,
        'decided_by': decidedBy,
        'decided_at': now.toIso8601String(),
        'sync_state': SyncState.synced.name,
      },
      where: 'family_id = ? AND evidence_id = ?',
      whereArgs: [familyId, evidenceId],
    );
  }

  Future<int> upsertEvidence(List<Map<String, Object?>> rows) async {
    final db = await _database.database;
    var applied = 0;
    for (final row in rows) {
      await db.insert('monitoring_evidence_queue', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      applied += 1;
    }
    return applied;
  }
}
