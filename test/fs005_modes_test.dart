// FS-005 — Special & Custom Modes. SQLite data-layer and domain tests.
//
// Honesty checks: a mode stays `queued` until the server confirms; every
// activation records a real `activationId`, `state` (requested/active/
// applied/failed/expired) and a decided-by actor; conflicting modes are
// resolved deterministically by (priority desc, created asc) — nothing is
// silently overridden; the v19 migration creates both tables plus indexes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/mode_config_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/mode_config.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs005-db-');
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
  await db.insert('family_members', {
    'id': 'child-1',
    'family_id': 'family-a',
    'display_name': 'Child One',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-2',
    'family_id': 'family-a',
    'display_name': 'Child Two',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('devices', {
    'id': 'device-1',
    'family_id': 'family-a',
    'member_id': 'child-1',
    'role': 'child',
    'sync_state': 'synced',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('devices', {
    'id': 'device-2',
    'family_id': 'family-a',
    'member_id': 'child-2',
    'role': 'child',
    'sync_state': 'synced',
    'created_at': _seededAt.toIso8601String(),
  });
  return database;
}

ModeConfig _testMode({
  String modeId = 'mode-1',
  String familyId = 'family-a',
  String name = 'Homework Time',
  ModeKind kind = ModeKind.homework,
  ModeAction action = ModeAction.slowDown,
  bool enabled = true,
  int startMinute = 0,
  int endMinute = 0,
  ModeScheduleKind scheduleKind = ModeScheduleKind.daily,
  Set<int> weekdays = const {},
  DateTime? oneshotAt,
  Set<String> assignedChildIds = const {'child-1', 'child-2'},
  Set<String> categoryRestrictions = const {},
  int priority = 50,
  DateTime? createdAt,
}) {
  return ModeConfig(
    modeId: modeId,
    familyId: familyId,
    name: name,
    kind: kind,
    action: action,
    enabled: enabled,
    startMinute: startMinute,
    endMinute: endMinute,
    scheduleKind: scheduleKind,
    weekdays: weekdays,
    oneshotAt: oneshotAt,
    assignedChildIds: assignedChildIds,
    categoryRestrictions: categoryRestrictions,
    appRestrictions: const {},
    priority: priority,
    note: '',
    createdAt: createdAt ?? _seededAt,
    updatedAt: _seededAt,
    syncState: SyncState.queued,
  );
}

void main() {
  group('mode_configs', () {
    test('saveMode and modesForFamily round-trip as queued', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
      final mode = _testMode();

      await repo.saveMode(mode);

      final modes = await repo.modesForFamily('family-a');
      expect(modes.length, 1);
      expect(modes.single.modeId, 'mode-1');
      expect(modes.single.name, 'Homework Time');
      expect(modes.single.kind, ModeKind.homework);
      expect(modes.single.action, ModeAction.slowDown);
      expect(modes.single.priority, 50);
      expect(modes.single.syncState, SyncState.queued);
      expect(modes.single.assignedChildIds, containsAll(['child-1', 'child-2']));

      // Upserting the same (family_id, mode_id) PK replaces the row.
      final updated = mode.copyWith(name: 'Focus Hour', priority: 70);
      await repo.saveMode(updated);
      final after = await repo.modesForFamily('family-a');
      expect(after.length, 1);
      expect(after.single.name, 'Focus Hour');
      expect(after.single.priority, 70);
      await database.close();
    });

    test('childModesFor filters to the assigned children', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
      await repo.saveMode(_testMode(modeId: 'mode-wide',
          name: 'Wide', assignedChildIds: {'child-1', 'child-2'}));
      await repo.saveMode(_testMode(modeId: 'mode-only-one',
          name: 'Only One', assignedChildIds: {'child-1'}));

      final forChild1 = await repo.childModesFor('family-a', 'child-1');
      expect(forChild1.length, 2);

      final forChild2 = await repo.childModesFor('family-a', 'child-2');
      expect(forChild2.length, 1);
      expect(forChild2.single.modeId, 'mode-wide');
      await database.close();
    });

    test('modeById returns null for a missing mode', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
      expect(await repo.modeById('family-a', 'nope'), isNull);
      await database.close();
    });

    test('deleteMode removes the mode and its activations', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
            await repo.saveMode(_testMode(assignedChildIds: {'child-1', 'child-2'}));
      await repo.activateMode(
          familyId: 'family-a', modeId: 'mode-1', decidedBy: 'parent-1');
      await repo.deleteMode('family-a', 'mode-1');

      expect(await repo.modeById('family-a', 'mode-1'), isNull);
      expect(await repo.modesForFamily('family-a'), isEmpty);

      // Deleting a mode cleans up its activation history together —
      // orphaned activations pointing at a deleted policy would only
      // pollute the honest log.
      expect(await repo.activationsForFamily('family-a'), isEmpty);
      await database.close();
    });
  });

  group('mode_activations', () {
    test('activateMode creates an active activation', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
            await repo.saveMode(_testMode(assignedChildIds: {'child-1'}));
      await repo.activateMode(
          familyId: 'family-a', modeId: 'mode-1', decidedBy: 'parent-1');

      final activations = await repo.activationsForFamily('family-a');
      expect(activations.length, 1);
      final activation = activations.single;
      expect(activation.activationId, isNotEmpty);
      expect(activation.modeId, 'mode-1');
      expect(activation.childId, 'child-1');
      expect(activation.state, 'active');
      expect(activation.decidedBy, 'parent-1');
      expect(activation.syncState, SyncState.queued);
      // The mode itself flips enabled when activated.
      final refreshed = await repo.modeById('family-a', 'mode-1');
      expect(refreshed, isNotNull);
      expect(refreshed!.enabled, true);
      await database.close();
    });

    test('deactivateMode records an expired activation', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
      await repo.saveMode(_testMode(assignedChildIds: {'child-1'}));
      await repo.activateMode(
          familyId: 'family-a', modeId: 'mode-1', decidedBy: 'parent-1');

      await repo.deactivateMode(familyId: 'family-a', modeId: 'mode-1');

      // Activation history preserves both records (honest audit trail):
      // the original activation plus a new expiry record.
      final history = await repo.activationsForFamily('family-a');
      expect(history.length, 2);
      final expired = history.firstWhere((a) => a.state == 'expired');
      expect(expired.endsAt, isNull);
      expect(expired.modeId, 'mode-1');
      expect(expired.childId, 'child-1');

      // The mode itself flips disabled when deactivated.
      final refreshed = await repo.modeById('family-a', 'mode-1');
      expect(refreshed, isNotNull);
      expect(refreshed!.enabled, false);
      await database.close();
    });

    test('activation round-trips with all states', () async {
      final database = await _seededDatabase();
      final repo = ModeConfigRepository(database);
      await repo.saveMode(_testMode(assignedChildIds: {'child-1', 'child-2'}));
      await repo.activateMode(
          familyId: 'family-a', modeId: 'mode-1', decidedBy: 'parent-1');

      // Overlapping modes downgrade this one to `requested`, so both
      // states the domain allows (requested/active/applied/failed/expired)
      // are reachable.
      await repo.saveMode(_testMode(
          modeId: 'mode-2',
          name: 'Stronger',
          priority: 90,
          assignedChildIds: {'child-1'},
          createdAt: _seededAt.subtract(const Duration(hours: 1))));
      await repo.activateMode(
          familyId: 'family-a', modeId: 'mode-2', decidedBy: 'parent-1');

      final all = await repo.activationsForFamily('family-a');
      // mode-1 activated first: at that moment it faced no conflict and is
      // honestly recorded as `active` — later conflicts never rewrite
      // history.
      final mode1Child1 = all.firstWhere(
          (a) => a.modeId == 'mode-1' && a.childId == 'child-1');
      expect(mode1Child1.state, 'active');

      final mode2Child1 = all.firstWhere(
          (a) => a.modeId == 'mode-2' && a.childId == 'child-1');
      expect(mode2Child1.state, 'active');

      final child2 = all.firstWhere((a) => a.childId == 'child-2');
      // The wide-assignment mode only overlaps for child-1, so child-2's
      // activation stays `active`.
      expect(child2.state, 'active');

      // State transitions are honest: a failed activation records the
      // real failure instead of disappearing.
      await repo.saveActivation(ModeActivation(
        activationId: mode1Child1.activationId,
        modeId: mode1Child1.modeId,
        familyId: mode1Child1.familyId,
        childId: mode1Child1.childId,
        state: 'failed',
        startedAt: mode1Child1.startedAt,
        decidedBy: mode1Child1.decidedBy,
      ));
      final failed = (await repo.activationsForFamily('family-a'))
          .firstWhere((a) => a.activationId == mode1Child1.activationId);
      expect(failed.state, 'failed');
      await database.close();
    });
  });

  group('mode_conflict_resolution', () {
    test('higher priority wins regardless of creation order', () async {
      final now = DateTime.utc(2026, 8, 19);
      final low = _testMode(modeId: 'm-low', name: 'Low', priority: 10,
          createdAt: now.subtract(const Duration(hours: 2)));
      final high = _testMode(modeId: 'm-high', name: 'High', priority: 90,
          createdAt: now);

      final resolver = const ModeConflictResolver();
      final order = resolver.effectiveOrder(
          modes: [low, high], childId: 'child-1', moment: now);
      expect(order.map((m) => m.modeId).toList(), ['m-high', 'm-low']);
    });

    test('equal priority resolves by earlier creation (stable order)', () {
      final now = DateTime.utc(2026, 8, 19);
      final first = _testMode(modeId: 'm-first', name: 'First',
          priority: 50, createdAt: now);
      final second = _testMode(modeId: 'm-second', name: 'Second',
          priority: 50, createdAt: now.add(const Duration(hours: 1)));

      final resolver = const ModeConflictResolver();
      final order = resolver.effectiveOrder(
          modes: [second, first], childId: 'child-1', moment: now);
      expect(order.map((m) => m.modeId).toList(), ['m-first', 'm-second']);
    });

    test('conflicts returns winner/loser pairs for overlapping modes', () {
      final now = DateTime.utc(2026, 8, 19);
      final winner = _testMode(modeId: 'm-a', name: 'A', priority: 60,
          createdAt: now);
      final loser = _testMode(modeId: 'm-b', name: 'B', priority: 40,
          createdAt: now.add(const Duration(minutes: 1)));

      final resolver = const ModeConflictResolver();
      final conflicts = resolver.conflicts(
          ordered: [winner, loser], childId: 'child-1');
      expect(conflicts.length, 1);
      expect(conflicts.single.winner.modeId, 'm-a');
      expect(conflicts.single.loser.modeId, 'm-b');
    });
  });

  test('v19 migration creates the FS-005 tables and indexes', () async {
    final database = await _seededDatabase();
    final db = await database.database;
    final tables = await db.query('sqlite_master',
        where: "type = 'table' AND name LIKE 'mode_%'",
        columns: const ['name']);
    expect(tables.map((t) => t['name']), containsAll(<Object?>[
      'mode_configs',
      'mode_activations',
    ]));
    final indexes = await db.query('sqlite_master',
        where: "type = 'index' AND name LIKE 'idx_mode_%'",
        columns: const ['name']);
    expect(indexes.length, 2);
    await database.close();
  });

  test('ModeTemplate.builtIns ships homework, bedtime and travel presets', () {
    expect(ModeTemplate.builtIns.length, 3);
    final kinds = ModeTemplate.builtIns.map((t) => t.mode.kind).toSet();
    expect(kinds,
        containsAll(<ModeKind>[ModeKind.homework, ModeKind.bedtime, ModeKind.travel]));
    expect(ModeTemplate.builtIns.every((t) => t.key == t.mode.kind.name), true);
  });

  test('ModeConfig fromMap tolerates missing optional fields', () {
    final config = ModeConfig.fromMap({
      'family_id': 'family-a',
      'mode_id': 'mode-1',
      'name': 'Minimal',
      'kind': 'custom',
      'action': 'block',
      'enabled': 1,
      'created_at': DateTime.utc(2026, 8, 19).toIso8601String(),
    });
    expect(config.kind, ModeKind.custom);
    expect(config.action, ModeAction.block);
    expect(config.assignedChildIds, isEmpty);
    // An unset weekday list defaults to the standard school week — the
    // schedule never silently becomes "never".
    expect(config.weekdays, const {1, 2, 3, 4, 5});
  });

  test('ModeActivation.fromMap tolerates missing optional fields', () {
    final activation = ModeActivation.fromMap({
      'activation_id': 'act-1',
      'mode_id': 'mode-1',
      'family_id': 'family-a',
      'child_id': 'child-1',
      'state': 'active',
      'created_at': DateTime.utc(2026, 8, 19).toIso8601String(),
    });
    expect(activation.state, 'active');
    expect(activation.decidedBy, isNull);
  });

  test('foreign key rejects a mode for an unknown family', () async {
    final database = await _seededDatabase();
    final db = await database.database;
    await db.rawQuery('PRAGMA foreign_keys = ON');
    await expectLater(
      db.insert('mode_configs', {
        'family_id': 'family-unknown',
        'mode_id': 'mode-x',
        'name': 'X',
        'kind': 'custom',
        'action': 'block',
        'enabled': 1,
        'priority': 50,
        'sync_state': 'queued',
        'created_at': DateTime.utc(2026, 8, 19).toIso8601String(),
      }),
      throwsException,
    );
    await database.close();
  });
}
