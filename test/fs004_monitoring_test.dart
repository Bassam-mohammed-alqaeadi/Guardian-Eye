// FS-004 — Screen & Camera Monitoring. SQLite data-layer tests.
//
// Honesty checks: shots, requests and schedules stay `queued` until the
// server confirms; flagging a shot creates evidence with a real computed
// `evidenceId` that round-trips; evidence reviews record `decidedBy` and
// `decidedAt`; the v18 migration creates all five tables plus indexes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/monitoring_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs004-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}

final DateTime _seededAt = DateTime.utc(2025, 6, 1);

Future<GuardianDatabase> _seededDatabase() async {
  final database = await openTestDatabase();
  final db = await database.database;
  await db.insert('families',
      {'id': 'fam-a', 'name': 'Family A', 'created_at': _seededAt.toIso8601String()});
  // device_id references devices(id), which references families(id).
  await db.insert('devices', {
    'id': 'device-1',
    'family_id': 'fam-a',
    'member_id': 'child-1',
    'role': 'child',
    'sync_state': 'synced',
    'created_at': _seededAt.toIso8601String(),
  });
  return database;
}

void main() {
  group('monitoring_shots', () {
    test('upsert and query shots round-trip as queued', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      final now = DateTime.utc(2026, 8, 19, 12);

      await repo.upsertShots([
        {
          'family_id': 'fam-a',
          'shot_id': 'shot-1',
          'device_id': 'device-1',
          'child_id': 'child-1',
          'captured_at': now.toIso8601String(),
          'bytes_length': 1024,
          'mime_type': 'image/png',
          'is_evidence': 0,
          'sync_state': SyncState.queued.name,
        },
      ]);

      final shots = await repo.shotsForFamily('fam-a');
      expect(shots.length, 1);
      expect(shots.single.shotId, 'shot-1');
      expect(shots.single.syncState, SyncState.queued);
      expect(shots.single.isEvidence, false);

      // Upserting the same PK replaces (unique composite PK).
      await repo.upsertShots([
        {
          'family_id': 'fam-a',
          'shot_id': 'shot-1',
          'device_id': 'device-1',
          'captured_at': now.add(const Duration(seconds: 1)).toIso8601String(),
          'bytes_length': 2048,
          'mime_type': 'image/jpeg',
          'is_evidence': 1,
          'sync_state': SyncState.synced.name,
        },
      ]);
      final after = await repo.shotsForFamily('fam-a');
      expect(after.length, 1);
      expect(after.single.bytesLength, 2048);
      expect(after.single.isEvidence, true);
      await database.close();
    });

    test('shotById returns null for a missing shot', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      expect(await repo.shotById('fam-a', 'nope'), isNull);
      await database.close();
    });
  });

  group('monitoring_requests', () {
    test('createRequest queues a capture request', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);

      final request = await repo.createRequest(
        familyId: 'fam-a',
        deviceId: 'device-1',
        requestId: 'req-1',
        childId: 'child-1',
        kind: 'shot',
        reason: 'periodic check',
      );

      expect(request.state, 'queued');
      expect(request.syncState, SyncState.queued);

      final all = await repo.requestsForFamily('fam-a');
      expect(all.length, 1);
      expect(all.single.kind, 'shot');
      expect(all.single.reason, 'periodic check');

      // Same family+request_id replaces instead of duplicating.
      await repo.createRequest(
        familyId: 'fam-a',
        deviceId: 'device-1',
        requestId: 'req-1',
        kind: 'live',
      );
      expect((await repo.requestsForFamily('fam-a')).length, 1);
      expect((await repo.requestsForFamily('fam-a')).single.kind, 'live');
      await database.close();
    });

    test('markRequestDelivered updates state with timestamp', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      await repo.createRequest(
        familyId: 'fam-a',
        deviceId: 'device-1',
        requestId: 'req-2',
        kind: 'shot',
      );

      final marked = await repo.markRequestDelivered(
          'fam-a', 'req-2', DateTime.utc(2026, 8, 19, 13));
      expect(marked, greaterThanOrEqualTo(1));

      final delivered = (await repo.requestsForFamily('fam-a')).single;
      expect(delivered.state, 'delivered');
      expect(delivered.deliveredAt, isNotNull);
      await database.close();
    });
  });

  group('monitoring_schedules', () {
    test('save and query capture schedules', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);

      await repo.saveSchedule(
        familyId: 'fam-a',
        scheduleId: 'sched-1',
        deviceId: 'device-1',
        startHour: 8,
        endHour: 20,
        intervalMinutes: 30,
        enabled: true,
      );

      final schedules = await repo.schedulesForFamily('fam-a');
      expect(schedules.length, 1);
      expect(schedules.single.startHour, 8);
      expect(schedules.single.intervalMinutes, 30);
      expect(schedules.single.enabled, true);

      await repo.saveSchedule(
        familyId: 'fam-a',
        scheduleId: 'sched-1',
        deviceId: 'device-1',
        startHour: 9,
        endHour: 21,
        intervalMinutes: 15,
        enabled: false,
      );
      final updated = (await repo.schedulesForFamily('fam-a')).single;
      expect(updated.enabled, false);
      expect(updated.intervalMinutes, 15);
      await database.close();
    });

    test('deleteSchedule removes the row', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      await repo.saveSchedule(
        familyId: 'fam-a',
        scheduleId: 'sched-2',
        startHour: 10,
        endHour: 18,
        intervalMinutes: 60,
        enabled: true,
      );
      await repo.deleteSchedule('fam-a', 'sched-2');
      expect(await repo.schedulesForFamily('fam-a'), isEmpty);
      await database.close();
    });
  });

  group('monitoring_evidence_queue', () {
    test('flagShotAsEvidence creates a review entry', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      await repo.upsertShots([
        {
          'family_id': 'fam-a',
          'shot_id': 'shot-1',
          'device_id': 'device-1',
          'child_id': 'child-1',
          'captured_at': DateTime.utc(2026, 8, 19).toIso8601String(),
          'bytes_length': 512,
          'is_evidence': 0,
          'sync_state': SyncState.queued.name,
        },
      ]);

      final evidence = await repo.flagShotAsEvidence(
        'fam-a',
        shotId: 'shot-1',
        deviceId: 'device-1',
        childId: 'child-1',
        flagReason: 'suspicious activity',
      );

      expect(evidence.evidenceId, isNotEmpty);
      expect(evidence.state, 'queued');
      expect(evidence.flagReason, 'suspicious activity');

      final queue = await repo.evidenceForFamily('fam-a');
      expect(queue.length, 1);
      expect(queue.single.evidenceId, evidence.evidenceId);
      await database.close();
    });

    test('reviewEvidence records the decision', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      final evidence = await repo.flagShotAsEvidence(
        'fam-a',
        shotId: 'shot-2',
        deviceId: 'device-1',
        flagReason: 'check',
      );

      await repo.reviewEvidence(
        'fam-a',
        evidence.evidenceId,
        state: 'reviewed',
        decidedBy: 'parent-1',
      );

      // Reviewing removes the item from the pending review queue — a
      // reviewed decision never re-appears as pending.
      final afterReview = await repo.evidenceForFamily('fam-a');
      expect(afterReview, isEmpty);

      // The decision itself survives in the table with decidedBy and
      // decidedAt recorded (honest audit trail).
      final db = await database.database;
      final reviewedRows = await db.query('monitoring_evidence_queue',
          where: 'family_id = ? AND evidence_id = ?',
          whereArgs: ['fam-a', evidence.evidenceId],
          limit: 1);
      expect(reviewedRows.single['state'], 'reviewed');
      expect(reviewedRows.single['decided_by'], 'parent-1');
      expect(reviewedRows.single['decided_at'], isNotNull);

      // Dismissing updates the stored state.
      await repo.reviewEvidence('fam-a', evidence.evidenceId, state: 'dismissed');
      final dismissedRows = await db.query('monitoring_evidence_queue',
          where: 'family_id = ? AND evidence_id = ?',
          whereArgs: ['fam-a', evidence.evidenceId],
          limit: 1);
      expect(dismissedRows.single['state'], 'dismissed');
      await database.close();
    });
  });

  group('monitoring_sessions', () {
    test('startSession and updateSessionState round-trip', () async {
      final database = await _seededDatabase();
      final repo = MonitoringRepository(database);
      final session = await repo.startSession(
        familyId: 'fam-a',
        deviceId: 'device-1',
        sessionId: 'sess-1',
        kind: 'live',
      );
      expect(session.state, 'pending');

      await repo.updateSessionState(
          'fam-a',
          session.sessionId,
          'started',
          startedAt: DateTime.utc(2026, 8, 19, 12, 5));
      final started =
          (await repo.sessionsForFamily('fam-a')).single;
      expect(started.state, 'started');
      expect(started.startedAt, isNotNull);

      await repo.updateSessionState(
          'fam-a',
          session.sessionId,
          'ended',
          endedAt: DateTime.utc(2026, 8, 19, 13));
      final ended = (await repo.sessionsForFamily('fam-a')).single;
      expect(ended.state, 'ended');
      expect(ended.endedAt, isNotNull);
      await database.close();
    });
  });

  test('migration v18 creates the FS-004 tables and indexes', () async {
    final database = await _seededDatabase();
    final db = await database.database;
    final tables = await db.query('sqlite_master',
        where: "type = 'table' AND name LIKE 'monitoring_%'",
        columns: const ['name']);
    expect(tables.map((t) => t['name']), containsAll(<Object?>[
      'monitoring_shots',
      'monitoring_sessions',
      'monitoring_requests',
      'monitoring_schedules',
      'monitoring_evidence_queue',
    ]));
    final indexes = await db.query('sqlite_master',
        where: "type = 'index' AND name LIKE 'idx_monitoring_%'",
        columns: const ['name']);
    expect(indexes.length, 2);
    await database.close();
  });

  test('foreign key references reject an unknown family', () async {
    final database = await _seededDatabase();
    final db = await database.database;
    await db.rawQuery('PRAGMA foreign_keys = ON');
    await expectLater(
      db.insert('monitoring_shots', {
        'family_id': 'fam-unknown',
        'shot_id': 'shot-x',
        'device_id': 'device-1',
        'captured_at': DateTime.utc(2026, 8, 19).toIso8601String(),
        'bytes_length': 10,
        'sync_state': 'queued',
      }),
      throwsException,
    );
    await database.close();
  });
}
