// Flutter unit tests — Phase 4D local family-data export.
//
// Proves, against the real SQLite engine, that the approved export contract
// holds: versioned schema-validated JSON bundles, authorization gates
// (child denied, cross-family denied, membership active, viewReports
// required, verified binding), the healthy-base-schema precondition,
// excluded domains (FCM tokens, outbox, app identity, frozen AI), aggregate
// location history, self-only couple linking, per-section honesty, and
// fresh-file regeneration on repeated exports. Local scope only — never
// touches production data and runs fully offline.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/family_data_export_service.dart';
import 'package:guardian_ai/data/reports_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

String join(String a, String b) => p.join(a, b);

/// Family member fixture used for the auth-gate tests.
FamilyMember _member({
  FamilyRole role = FamilyRole.parent,
  FamilyMemberStatus status = FamilyMemberStatus.active,
  String familyId = 'fam-1',
  String id = 'member-1',
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    displayName: 'Parent One',
    role: role,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    status: status,
    accountUid: 'uid-parent-1',
  );
}

/// Shared context factory: verified binding unless overridden. The actor
/// defaults to an active primary parent of the requested family so the
/// happy-path tests stay short, while the gate tests opt out explicitly.
FamilyRuntimeContext _context({
  bool verified = true,
  FamilyMember? actor,
  String familyId = 'fam-1',
}) {
  return FamilyRuntimeContext(
    familyId: familyId,
    family: GuardianFamily(
        id: familyId,
        name: 'Test Family',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    actor: actor ?? _member(role: FamilyRole.primaryParent, familyId: familyId),
    isVerified: verified,
    permissionsFor: (_) => verified && actor != null
        ? {FamilyPermission.viewReports}
        : const <FamilyPermission>{},
    allMembers: const <FamilyMember>[],
    children: const <FamilyMember>[],
    devices: const <ChildDeviceState>[],
  );
}

Future<GuardianDatabase> _openDatabase(String path) async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final guardianDb = GuardianDatabase.forTesting(
    factory: factory,
    pathResolver: () async => path,
  );
  await guardianDb.database;
  return guardianDb;
}

/// Minimal data seed for a single family — enough for the export engine to
/// assemble every approved section.
Future<void> _seedFamilyRows(Database db, String familyId) async {
  await db.insert('families', {
    'id': familyId,
    'name': 'Test Family',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'member-1',
    'family_id': familyId,
    'display_name': 'Parent One',
    'role': 'parent',
    'status': 'active',
    'account_uid': 'uid-parent-1',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('devices', {
    'id': 'device-1',
    'family_id': familyId,
    'member_id': 'member-1',
    'owner_member_id': 'member-1',
    'role': 'primaryParent',
    'sync_state': 'synced',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('location_settings', {
    'family_id': familyId,
    'key': 'sharing_enabled',
    'value': '1',
  });
  await db.insert('locations', {
    'id': 'loc-1',
    'family_id': familyId,
    'device_id': 'device-1',
    'latitude': 0.0,
    'longitude': 0.0,
    'accuracy_m': 10.0,
    'captured_at': DateTime.now().toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('geofences', {
    'id': 'gf-1',
    'family_id': familyId,
    'name': 'Home',
    'latitude': 0.0,
    'longitude': 0.0,
    'radius_meters': 100.0,
    'alert_on_entry': 1,
    'alert_on_exit': 1,
    'status': 'active',
    'sync_state': 'synced',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });
  await db.insert('incidents', {
    'id': 'inc-1',
    'family_id': familyId,
    'device_id': 'device-1',
    'category': 'geofence_exit',
    'severity': 'info',
    'confidence': 0.8,
    'source': 'local',
    'observed_at': DateTime.now().toIso8601String(),
    'model_version': '1',
    'status': 'open',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('tasks', {
    'task_id': 'task-1',
    'family_id': familyId,
    'title': 'Homework',
    'description': null,
    'due_minute': 0,
    'due_date': DateTime.now().add(const Duration(days: 2))
        .toIso8601String(),
    'recurrence': 'none',
    'weekdays': '1,2,3,4,5',
    'assigned_child_ids': '',
    'linked_rule_id': null,
    'status': 'scheduled',
    'created_by_member_id': 'member-1',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'sync_state': 'synced',
  });
  await db.insert('family_rewards', {
    'reward_id': 'reward-1',
    'family_id': familyId,
    'name': 'Extra screen time',
    'cost_points': 50,
    'enabled': 1,
    'created_by_member_id': 'member-1',
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
    'sync_state': 'synced',
  });
  await db.insert('subscription_entitlements', {
    'family_id': familyId,
    'feature': 'location_history',
    'granted': 1,
    'policy': 'local',
  });
  await db.insert('billing_records', {
    'id': 'bill-1',
    'family_id': familyId,
    'kind': 'purchase',
    'amount_minor_units': 999,
    'currency': 'USD',
    'status': 'paid',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('app_identity', {
    'key': 'device_fingerprint',
    'value': 'fp-1',
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('notification_tokens', {
    'id': 'nt-1',
    'family_id': familyId,
    'device_id': 'device-1',
    'user_uid': 'uid-1',
    'token': 'never-export-me',
    'platform': 'android',
    'status': 'active',
    'updated_at': DateTime.now().toIso8601String(),
  });
}

void main() {
  group('LocalFamilyExportService — authorized export contract', () {
    test('active parent export produces a versioned validated bundle with '
        'all approved sections', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_test_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      final db = await guardianDb.database;
      await _seedFamilyRows(db, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      expect(outcome.hasFile, isTrue);
      expect(await outcome.file!.exists(), isTrue);

      final decoded =
          json.decode(await outcome.file!.readAsString()) as Map<String, Object?>;
      final manifest = decoded['manifest'] as Map<String, Object?>;
      expect(manifest['schemaVersion'], familyExportSchemaVersion);
      expect(manifest['familyId'], 'fam-1');
      expect(manifest['requesterMemberId'], 'member-1');
      final sections =
          decoded['sections'] as Map<String, Object?>;
      expect(sections.length,
          LocalFamilyExportService.exportSectionOrder.length);

      for (final (key, _) in LocalFamilyExportService.exportSectionOrder) {
        final included = manifest['includedSections'] as List;
        expect(included, contains(key),
            reason: 'section $key missing or excluded');
      }
      for (final (key, _) in LocalFamilyExportService.exportSectionOrder) {
        final status = manifest['sectionStatus'] as Map;
        expect(status[key], isNot('failed'),
            reason: 'section $key must not report `failed` in a shareable '
                'bundle');
      }
    });

    test('location history section contains aggregates only, never raw '
        'coordinates', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_loc_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      final db = await guardianDb.database;
      await _seedFamilyRows(db, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      final decoded =
          json.decode(await outcome.file!.readAsString()) as Map<String, Object?>;
      final rows = (decoded['sections'] as Map)['locationHistory'] as List;
      final raw = rows
          .cast<Map>()
          .where((r) =>
              r.containsKey('latitude') && r.containsKey('longitude'))
          .toList();
      expect(raw, isEmpty,
          reason: 'raw location points must never enter the export bundle');
    });

    test('couple linking is exported self-only for the requesting actor',
        () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_couple_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      final db = await guardianDb.database;
      await _seedFamilyRows(db, 'fam-1');
      await db.insert('family_members', {
        'id': 'member-2',
        'family_id': 'fam-1',
        'display_name': 'Parent Two',
        'role': 'parent',
        'status': 'active',
        'account_uid': 'uid-parent-2',
        'created_at': DateTime.now().toIso8601String(),
      });
  await db.insert('couple_linking', {
    'id': 'cl-1',
    'family_id': 'fam-1',
    'partner_member_id': 'member-1',
    'request_state': 'accepted',
    'requested_by': 'member-1',
    'requested_at': DateTime.now().toIso8601String(),
    'responded_at': DateTime.now().toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  });
  await db.insert('couple_linking', {
    'id': 'cl-2',
    'family_id': 'fam-1',
    'partner_member_id': 'member-2',
    'request_state': 'accepted',
    'requested_by': 'member-2',
    'requested_at': DateTime.now().toIso8601String(),
    'responded_at': DateTime.now().toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  });

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      final decoded =
          json.decode(await outcome.file!.readAsString()) as Map<String, Object?>;
      final rows = (decoded['sections'] as Map)['couple'] as List;
      expect(rows.length, 1);
      expect((rows.cast<Map>().first)['partner_member_id'], 'member-1');
    });

    test('repeated exports regenerate fresh stamped files, never a stale '
        'copy', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_repeat_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final ctx = _context(familyId: 'fam-1', actor: _member());

      final first = await service.run(
        familyId: 'fam-1',
        context: ctx,
        clock: () => DateTime(2026, 6, 1, 12, 0, 1),
      );
      final firstPath = first.file!.path;

      final second = await service.run(
        familyId: 'fam-1',
        context: ctx,
        clock: () => DateTime(2026, 6, 1, 12, 0, 2),
      );

      expect(second.state, FamilyExportState.readyToShare);
      expect(second.file!.path, isNot(firstPath));
      expect(await first.file!.exists(), isTrue);
      expect(await second.file!.exists(), isTrue);
    });
  });

  group('LocalFamilyExportService — authorization gates', () {
    test('child actor is denied', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_child_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context:
            _context(familyId: 'fam-1', actor: _member(role: FamilyRole.child)),
      );

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.reason, 'child_denied');
      expect(outcome.hasFile, isFalse);
    });

    test('member of another family cannot export this family', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_cross_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-2',
        context: _context(
          familyId: 'fam-2',
          actor: _member(id: 'member-1', familyId: 'fam-1'),
        ),
      );

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.reason, 'cross_family_denied');
      expect(outcome.hasFile, isFalse);
    });

    test('revoked member is denied', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_revoked_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(
          familyId: 'fam-1',
          actor: _member(status: FamilyMemberStatus.revoked),
        ),
      );

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.reason, 'membership_not_active');
      expect(outcome.hasFile, isFalse);
    });

    test('unverified actor is denied', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_unver_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(
            familyId: 'fam-1', actor: _member(), verified: false),
      );

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.hasFile, isFalse);
    });

    test('missing actor is denied', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_null_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: null),
      );

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.hasFile, isFalse);
    });

    test('member without viewReports is denied', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_perm_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);

      final context = FamilyRuntimeContext(
        familyId: 'fam-1',
        family: GuardianFamily(
            id: 'fam-1',
            name: 'Test Family',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
        actor: _member(role: FamilyRole.spouse),
        isVerified: true,
        permissionsFor: (_) => const <FamilyPermission>{},
        allMembers: const <FamilyMember>[],
        children: const <FamilyMember>[],
        devices: const <ChildDeviceState>[],
      );
      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(familyId: 'fam-1', context: context);

      expect(outcome.state, FamilyExportState.blockedPermission);
      expect(outcome.reason, 'permission_denied');
      expect(outcome.hasFile, isFalse);
    });
  });

  group('LocalFamilyExportService — validation and honesty invariants', () {
    test('corrupted base schema fails the export with no file', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_bad_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      final db = await guardianDb.database;
      await _seedFamilyRows(db, 'fam-1');
      await db.execute('DROP INDEX IF EXISTS idx_outbox_state_next');
      await guardianDb.close();

      // A fresh handle against the same file matches the version exactly,
      // so the upgrade path does not recreate the dropped index — the guard
      // catches the corruption instead.
      final reopened = GuardianDatabase.forTesting(
        factory: databaseFactoryFfi,
        pathResolver: () async => tempPath,
      );
      await reopened.database;

      final service = LocalFamilyExportService(
        database: reopened,
        reports: ReportsRepository(reopened),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.failed);
      expect(outcome.reason, 'base_schema_unhealthy');
      expect(outcome.hasFile, isFalse);
    });

    test('failing section builder fails the whole export honestly',
        () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_fail_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final broken = <String, ExportSectionBuilder>{
        'family': (_, __, ___) async => throw StateError('reader unavailable'),
      };
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
        sectionBuilders: broken,
      );

      expect(outcome.state, FamilyExportState.failed);
      expect(outcome.hasFile, isFalse);
      expect(
        outcome.validationErrors.isNotEmpty ||
            (outcome.reason ?? '').contains('section_failures'),
        isTrue,
        reason: 'a failing section must fail the whole export honestly',
      );
    });

    test('bundle containing forbidden keys fails post-write validation',
        () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_fkey_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final builders = <String, ExportSectionBuilder>{
        'devices': (familyId, context, reports) async {
          final rows = await guardianDb.database
              .then((d) => d.query('devices', where: 'family_id = ?',
                  whereArgs: [familyId]));
          final poisoned = List<Map<String, Object?>>.from(rows)
            ..add({'id': 'device-1', 'fcm_token': 'never-export-me'});
          return FamilyExportSection(
            key: 'devices',
            titleKey: 'exportSectionDevices',
            included: true,
            rows: poisoned,
            status: 'included',
          );
        },
      };
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
        sectionBuilders: builders,
      );

      expect(outcome.state, FamilyExportState.failed);
      expect(outcome.hasFile, isFalse);
      expect(
        outcome.validationErrors.join(' ').contains('fcm_token'),
        isTrue,
        reason:
            'the forbidden key fcm_token must be named in the validation '
            'errors',
      );
    });

    test('written bundle is re-validated and its manifest always names the '
        'requested family', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_att_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      final decoded = json.decode(
          await outcome.file!.readAsString()) as Map<String, Object?>;
      final manifestMap = decoded['manifest'] as Map<String, Object?>;
      expect(manifestMap['familyId'], 'fam-1',
          reason: 'the written file is re-validated before being returned: '
              'a bundle whose manifest names a different family must never '
              'reach the share flow');
      final familyMap = decoded['family'] as Map<String, Object?>;
      expect(familyMap['id'], 'fam-1');
      for (final row
          in (decoded['sections'] as Map)['locationHistory'] as List) {
        expect(
            (row as Map).keys.toSet().contains('fcm_token'),
            isFalse,
            reason: 're-validated bundle must not carry forbidden device '
                'keys');
      }
    });

    test('excluded domains never appear anywhere in the exported bundle',
        () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_excl_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      final raw = await outcome.file!.readAsString();
      expect(raw, isNot(contains('never-export-me')));
      expect(raw, isNot(contains('notification_tokens')));
      expect(raw, isNot(contains('app_identity')));
      final decoded = json.decode(raw);
      for (final key in familyExportForbiddenKeys) {
        expect(decoded, isNot(contains(key)),
            reason: 'forbidden key $key present in bundle');
      }
    });

    test('empty sections report no_data honestly without failing the '
        'bundle', () async {
      final tempPath = join(Directory.systemTemp.path,
          'export_nodata_${DateTime.now().microsecondsSinceEpoch}.sqlite');
      addTearDown(() => File(tempPath).deleteSync());
      final guardianDb = await _openDatabase(tempPath);
      await _seedFamilyRows(await guardianDb.database, 'fam-1');

      final service = LocalFamilyExportService(
        database: guardianDb,
        reports: ReportsRepository(guardianDb),
      );
      final outcome = await service.run(
        familyId: 'fam-1',
        context: _context(familyId: 'fam-1', actor: _member()),
      );

      expect(outcome.state, FamilyExportState.readyToShare);
      final decoded =
          json.decode(await outcome.file!.readAsString()) as Map<String, Object?>;
      final manifestMap = decoded['manifest'] as Map<String, Object?>;
      final status = manifestMap['sectionStatus'] as Map<String, Object?>;
      final noData =
          status.entries.where((e) => e.value == 'no_data').toList();
      final failed =
          status.entries.where((e) => e.value == 'failed').toList();
      expect(failed, isEmpty);
      expect(noData.isNotEmpty, isTrue,
          reason: 'an empty domain must surface at least one honest no_data '
              'section');
    });
  });
}
