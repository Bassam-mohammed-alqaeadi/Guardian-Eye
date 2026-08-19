// FS-003 — Application Control. SQLite data-layer tests.
//
// Honesty checks: every policy write records an audit event in
// `app_block_history`; queued writes stay `queued` until the server
// confirms; allowlist add/remove both leave audit evidence.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/application_policy_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs003-db-');
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
  return database;
}

void main() {
  group('app_policies', () {
    test('save then resolve round-trips a block policy as queued', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18);
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: '',
        target: 'com.example.game',
        action: AppPolicyAction.block,
        ratingMax: 'all',
        syncState: SyncState.queued,
        updatedAt: now,
      ));

      final policies = await repo.resolvePolicies('fam-a');
      expect(policies.length, 1);
      expect(policies.single.action, AppPolicyAction.block);
      expect(policies.single.syncState, SyncState.queued);

      // A fresh write for the same family+target replaces (unique PK).
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: '',
        target: 'com.example.game',
        action: AppPolicyAction.limit,
        timeAllowance: const Duration(minutes: 30),
        ratingMax: 'all',
        syncState: SyncState.queued,
        updatedAt: now.add(const Duration(seconds: 1)),
      ));
      final after = await repo.resolvePolicies('fam-a');
      expect(after.length, 1);
      expect(after.single.action, AppPolicyAction.limit);
      expect(after.single.timeAllowance, const Duration(minutes: 30));
      await database.close();
    });

    test('resolvePolicy prefers a child-scoped policy over a general one',
        () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18);
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: '',
        target: 'com.example.video',
        action: AppPolicyAction.allow,
        ratingMax: '12+',
        syncState: SyncState.synced,
        updatedAt: now,
      ));
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: 'child-7',
        target: 'com.example.video',
        action: AppPolicyAction.block,
        ratingMax: 'all',
        syncState: SyncState.queued,
        updatedAt: now.add(const Duration(seconds: 5)),
      ));

      final childPolicy =
          await repo.resolvePolicy('fam-a', 'child-7', 'com.example.video');
      expect(childPolicy, isNotNull);
      expect(childPolicy!.action, AppPolicyAction.block);
      expect(childPolicy.childId, 'child-7');
      // A general (family-wide) policy resolves only for its own empty
      // child scope — matching a specific other child would silently
      // hide the child-scoped override above.
      final generalPolicy =
          await repo.resolvePolicy('fam-a', '', 'com.example.video');
      expect(generalPolicy?.action, AppPolicyAction.allow);
      expect(generalPolicy?.childId, '');
      await database.close();
    });

    test('deletePolicy removes the family+target row', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18);
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: '',
        target: 'com.example.chat',
        action: AppPolicyAction.block,
        ratingMax: 'all',
        syncState: SyncState.queued,
        updatedAt: now,
      ));
      await repo.deletePolicy('fam-a', 'com.example.chat');
      expect(await repo.resolvePolicies('fam-a'), isEmpty);
      await database.close();
    });

    test('savePolicy records an honest audit event', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18, 10);
      await repo.savePolicy(AppPolicyEntry(
        familyId: 'fam-a',
        childId: 'child-1',
        target: 'com.example.blocked',
        action: AppPolicyAction.block,
        ratingMax: 'all',
        syncState: SyncState.queued,
        updatedAt: now,
      ));
      final events = await repo.blockEvents('fam-a');
      expect(events.length, 1);
      expect(events.single.eventType, AppBlockEventType.block);
      expect(events.single.reason, 'policy:block');
      expect(events.single.childId, 'child-1');
      await database.close();
    });
  });

  group('app_allowlist', () {
    test('add and remove round-trip with audit evidence', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18);
      await repo.addToAllowlist(AppAllowlistEntry(
        familyId: 'fam-a',
        target: 'com.store.safeapp',
        reason: 'school app',
        addedBy: 'parent-1',
        createdAt: now,
      ));

      final entries = await repo.allowlistEntries('fam-a');
      expect(entries.length, 1);
      expect(entries.single.target, 'com.store.safeapp');
      expect(entries.single.reason, 'school app');

      await repo.removeFromAllowlist('fam-a', 'com.store.safeapp');
      expect(await repo.allowlistEntries('fam-a'), isEmpty);

      final events = await repo.blockEvents('fam-a');
      expect(events.length, 2);
      // Newest-first audit order: removal was recorded after addition.
      expect(events[0].eventType, AppBlockEventType.removedFromAllowlist);
      expect(events[1].eventType, AppBlockEventType.addedToAllowlist);
      expect(events[1].reason, 'school app');
      await database.close();
    });

    test('events are limited and newest first', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final base = DateTime.utc(2026, 8, 18);
      for (var i = 0; i < 60; i++) {
        await repo.recordBlockEvent(AppBlockEvent(
          familyId: 'fam-a',
          target: 'com.app.$i',
          eventType: AppBlockEventType.timeout,
          createdAt: base.add(Duration(seconds: i)),
        ));
      }
      final events = await repo.blockEvents('fam-a');
      expect(events.length, 50);
      expect(events.first.target, 'com.app.59');
      await database.close();
    });
  });

  group('usage_alert_settings', () {
    test('save and resolve alert settings', () async {
      final database = await _seededDatabase();
      final repo = ApplicationPolicyRepository(database);
      final now = DateTime.utc(2026, 8, 18);
      await repo.saveAlertSetting(UsageAlertSetting(
        familyId: 'fam-a',
        childId: null,
        target: 'com.example.video',
        threshold: const Duration(minutes: 45),
        enabled: true,
        updatedAt: now,
      ));

      final setting =
          await repo.resolveAlertSetting('fam-a', 'com.example.video');
      expect(setting, isNotNull);
      expect(setting!.threshold, const Duration(minutes: 45));
      expect(setting.enabled, true);

      await repo.saveAlertSetting(UsageAlertSetting(
        familyId: 'fam-a',
        childId: null,
        target: 'com.example.video',
        threshold: const Duration(hours: 1),
        enabled: false,
        updatedAt: now.add(const Duration(seconds: 1)),
      ));
      final updated =
          await repo.resolveAlertSetting('fam-a', 'com.example.video');
      expect(updated?.threshold, const Duration(hours: 1));
      expect(updated?.enabled, false);

      final all = await repo.resolveAlertSettings('fam-a');
      expect(all.length, 1);
      await database.close();
    });
  });

  test('migration v17 creates the FS-003 tables and indexes', () async {
    final database = await _seededDatabase();
    final db = await database.database;
    final tables = await db.query('sqlite_master',
        where: "type = 'table' AND (name LIKE 'app_%' OR name LIKE 'usage_alert_%')",
        columns: const ['name']);
    expect(tables.map((t) => t['name']), containsAll(<Object?>[
      'app_policies',
      'app_allowlist',
      'app_block_history',
      'usage_alert_settings',
    ]));
    final indexes = await db.query('sqlite_master',
        where: "type = 'index' AND name LIKE 'idx_app_%'",
        columns: const ['name']);
    expect(indexes.length, 2);
    await database.close();
  });
}
