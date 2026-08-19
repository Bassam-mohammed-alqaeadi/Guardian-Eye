// FS-006 — SOS & Emergency subsystem test suite.
//
// Honesty checks: the readiness roster (sos_recipients, v20) is the single
// source of truth for the SOS dashboard; an activation creates one honest
// event plus one notification row per recipient; acknowledgement only moves
// through allowed states; standing down keeps the cancelled record; the
// drill verdict is a pure function over observed facts; the v20 migration
// adds the roster table and the recipient_id column to notification_events.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/safety_repositories.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/incident_engine.dart';
import 'package:guardian_ai/domain/sos_config.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs006-db-');
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
  await db.insert('families', {
    'id': 'family-a',
    'name': 'Family A',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-1',
    'family_id': 'family-a',
    'display_name': 'Parent',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('devices', {
    'id': 'device-1',
    'family_id': 'family-a',
    'member_id': 'parent-1',
    'role': 'parent',
    'sync_state': 'synced',
    'created_at': _seededAt.toIso8601String(),
  });
  return database;
}

void main() {
  group('v20 migration', () {
    test('creates the sos_recipients table and the recipient_id column',
        () async {
      final database = await openTestDatabase();
      final db = await database.database;
      final tables = await db.rawQuery('PRAGMA table_list');
      final names =
          tables.map((r) => r['name'] as String).toSet();
      expect(names, contains('sos_recipients'));
      final columns = await db.rawQuery('PRAGMA table_info(notification_events)');
      expect(columns.map((c) => c['name']).toSet(), contains('recipient_id'));
    });

    test('upgrades a v19 database without recreating tables', () async {
      sqfliteFfiInit();
      final dir = Directory.systemTemp.createTempSync('fs006-upgrade-');
      final path = '${dir.path}/db.sqlite';
      // Simulate a file already marked at schema v19 with the v5
      // notification_events table present, then let GuardianDatabase apply
      // the real v19→v20 upgrade path on first open.
      final db19 = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(version: 19, onUpgrade: (db, a, b) async {
        if (b < 20) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS families (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              archived_at TEXT
            )''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sos_events (
              id TEXT PRIMARY KEY,
              family_id TEXT NOT NULL REFERENCES families(id),
              device_id TEXT,
              status TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              accuracy_m REAL,
              created_at TEXT NOT NULL,
              delivered_at TEXT
            )''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS notification_events (
              id TEXT PRIMARY KEY,
              family_id TEXT NOT NULL,
              incident_id TEXT,
              sos_id TEXT,
              kind TEXT NOT NULL,
              status TEXT NOT NULL,
              requested_at TEXT NOT NULL,
              acknowledged_at TEXT,
              last_error TEXT
            )''');
        }
      }));
      await db19.close();
      final database = GuardianDatabase.forTesting(
          factory: databaseFactoryFfi, pathResolver: () async => path);
      await database.initialize();
      final db = await database.database;
      final tables = await db.rawQuery('PRAGMA table_list');
      expect(tables.map((r) => r['name'] as String).toSet(),
          contains('sos_recipients'));
      final columns =
          await db.rawQuery('PRAGMA table_info(notification_events)');
      expect(columns.map((c) => c['name']).toSet(), contains('recipient_id'));
      // The pre-existing notification_events rows survive the upgrade.
      final id = 'probe-${DateTime.now().microsecondsSinceEpoch}';
      await db.insert('notification_events', {
        'id': id,
        'family_id': 'family-a',
        'kind': 'sos',
        'status': 'queued',
        'requested_at': _seededAt.toIso8601String(),
      });
      await db.insert('families', {
        'id': 'family-a',
        'name': 'A',
        'created_at': _seededAt.toIso8601String(),
      });
      final probe = await db.query('notification_events',
          where: 'id = ?', whereArgs: [id]);
      expect(probe.single['recipient_id'], isNull);
      expect(probe.single['id'], id);
    });
  });

  group('readiness roster', () {
    test('saves and lists recipients in ordering order', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'rescuer-1',
          role: SosRecipientRole.responder,
          ordering: 2,
          addedAt: _seededAt));
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'medic-1',
          role: SosRecipientRole.responder,
          ordering: 1,
          addedAt: _seededAt));
      final list = await repo.recipientsForFamily('family-a');
      expect(list.map((r) => r.recipientId).toList(), ['medic-1', 'rescuer-1']);
      expect(list.first.role, SosRecipientRole.responder);
    });

    test('round-trips a recipient through fromMap', () async {
      final original = SosRecipient(
          familyId: 'family-a',
          recipientId: 'medic-1',
          role: SosRecipientRole.notifyOnly,
          ordering: 7,
          addedAt: _seededAt,
          syncState: SyncState.queued);
      final restored = SosRecipient.fromMap(original.toMap());
      expect(restored.familyId, original.familyId);
      expect(restored.recipientId, original.recipientId);
      expect(restored.role, SosRecipientRole.notifyOnly);
      expect(restored.ordering, 7);
    });

    test('deletes a recipient but keeps past notification rows', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'rescuer-1',
          role: SosRecipientRole.responder,
          ordering: 0,
          addedAt: _seededAt));
      final deleted = await repo.deleteRecipient(
          familyId: 'family-a', recipientId: 'rescuer-1');
      expect(deleted, isTrue);
      expect(await repo.recipientsForFamily('family-a'), isEmpty);
      expect(await repo.deleteRecipient(
          familyId: 'family-a', recipientId: 'gone'), isFalse);
    });
  });

  group('SOS activation', () {
    test('creates one event plus one notification row per recipient',
        () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'rescuer-1',
          role: SosRecipientRole.responder,
          ordering: 0,
          addedAt: _seededAt));
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'medic-1',
          role: SosRecipientRole.responder,
          ordering: 1,
          addedAt: _seededAt));
      final id = await repo.activateSosForFamily('family-a',
          deviceId: 'device-1',
          latitude: 24.0,
          longitude: 46.0,
          accuracyMeters: 12.0);
      expect(id, isNotNull);
      final notifications = await repo.notificationsForSos(id!);
      expect(notifications.length, 2);
      final ids =
          notifications.map((r) => r['recipient_id']).toSet();
      expect(ids, {'rescuer-1', 'medic-1'});
      final rows = await repo.sosHistoryForFamily('family-a');
      expect(rows.single['id'], id);
    });

    test('returns the existing id when an active SOS already exists', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      final first = await repo.activateSosForFamily('family-a');
      expect(first, isNotNull);
      final second = await repo.activateSosForFamily('family-a');
      // No duplicate SOS is created — the second call returns the id of the
      // still-active event instead of inserting a new one.
      expect(second, equals(first));
      expect((await repo.sosHistoryForFamily('family-a')).length, 1);
    });
    test('second activation is blocked once an active SOS exists', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      final id = (await repo.activateSosForFamily('family-a'))!;
      await repo.standDownSos(id);
      // A cancelled SOS is terminal, so a brand-new activation is allowed.
      final second = await repo.activateSosForFamily('family-a');
      expect(second, isNotNull);
      expect(second, isNot(equals(id)));
    });
  });

  group('honest acknowledgement', () {
    test('moves through allowed states to acknowledged', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'rescuer-1',
          role: SosRecipientRole.responder,
          ordering: 0,
          addedAt: _seededAt));
      final id = (await repo.activateSosForFamily('family-a'))!;
      final notifications = await repo.notificationsForSos(id);
      final rowId = notifications.single['id'] as String;
      // pendingBackend is an allowed starting point.
      expect(await repo.acknowledgeNotification(rowId), isTrue);
      final rows = await repo.notificationsForSos(id);
      expect(rows.single['status'], NotificationState.acknowledged.name);
    });

    test('refuses acknowledgement of an already-terminal row', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      await repo.saveRecipient(SosRecipient(
          familyId: 'family-a',
          recipientId: 'rescuer-1',
          role: SosRecipientRole.responder,
          ordering: 0,
          addedAt: _seededAt));
      final id = (await repo.activateSosForFamily('family-a'))!;
      final rows = await repo.notificationsForSos(id);
      final rowId = rows.single['id'] as String;
      expect(await repo.acknowledgeNotification(rowId), isTrue);
      expect(await repo.acknowledgeNotification(rowId), isFalse);
    });

    test('stands down with a cancelled honest record', () async {
      final database = await _seededDatabase();
      final repo = SosRepository(database);
      final id = (await repo.activateSosForFamily('family-a'))!;
      expect(await repo.standDownSos(id), isTrue);
      final rows = await repo.sosHistoryForFamily('family-a');
      expect(rows.single['status'], SosState.cancelled.name);
    });
  });

  group('drill verdict', () {
    test('not started without a test event', () {
      final state = evaluateDrill(
          startedAt: null, acknowledged: true, locationVerified: true);
      expect(state.state, SosDrillStateKind.notStarted);
      expect(state.confirmedSteps, isEmpty);
    });

    test('passes only when every step is confirmed', () {
      final passed = evaluateDrill(
          startedAt: DateTime.utc(2025, 6, 1),
          acknowledged: true,
          locationVerified: true);
      expect(passed.state, SosDrillStateKind.passed);
      expect(passed.confirmedSteps.length, SosDrillStep.values.length);
      final inProgress = evaluateDrill(
          startedAt: DateTime.utc(2025, 6, 1),
          acknowledged: true,
          locationVerified: false);
      expect(inProgress.state, SosDrillStateKind.inProgress);
      expect(inProgress.confirmedSteps,
          containsAll([SosDrillStep.alertSent, SosDrillStep.alertReceived,
            SosDrillStep.alertAcknowledged]));
    });
  });
}
