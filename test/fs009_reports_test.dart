// FS-009 — Reports & Export subsystem test suite.
//
// Honesty checks: a report only ever reflects rows the device actually
// recorded inside the chosen window; an empty window produces an honest
// empty verdict on every section; blocked hits only count decision
// 'blocked' (temporary-allow rows are never inflated as blocked); top
// domains order by real occurrence counts; PDF and CSV export produce
// non-empty bytes on disk from the same real snapshot.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/reports_repository.dart';
import 'package:guardian_ai/data/reports_export_service.dart';
import 'package:guardian_ai/domain/reports_domain.dart';
/// Each test gets its own isolated temporary database file — the shared
/// `:memory:` handle (sqflite_common_ffi) would otherwise make every
/// test in this file reuse the same in-memory database.
Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('fs009-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}
final DateTime _seededAt = DateTime.utc(2025, 7, 1, 10, 0, 0);
final DateTime _weekStart = DateTime.utc(2025, 6, 29);
final DateTime _weekEnd = DateTime.utc(2025, 7, 5, 23, 59, 59);
Future<void> _seedAll(Database db) async {
  await db.insert('families', {
    'id': 'family-r',
    'name': 'Reports Family',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-r',
    'family_id': 'family-r',
    'display_name': 'Parent',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-r',
    'family_id': 'family-r',
    'display_name': 'Child',
    'role': 'child',
    'status': 'active',
    'created_at': _seededAt.toIso8601String(),
  });
  // FS-003 device row, needed by the usage-by-child join.
  await db.insert('devices', {
    'id': 'device-r',
    'family_id': 'family-r',
    'member_id': 'child-r',
    'role': 'child_device',
    'sync_state': 'synced',
    'created_at': _seededAt.toIso8601String(),
  });
  // FS-002 web hits — three blocked, one out-of-window, one 'allowed'.
  await db.insert('web_hits', {
    'family_id': 'family-r',
    'child_id': 'child-r',
    'child_display_name': 'Child',
    'domain': 'example-bad.com',
    'category': 'gambling',
    'decision': 'blocked',
    'blocked_at': DateTime.utc(2025, 7, 1, 12, 0, 0).toIso8601String(),
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('web_hits', {
    'family_id': 'family-r',
    'child_id': 'child-r',
    'child_display_name': 'Child',
    'domain': 'example-bad.com',
    'category': 'gambling',
    'decision': 'blocked',
    'blocked_at': DateTime.utc(2025, 7, 2, 12, 0, 0).toIso8601String(),
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('web_hits', {
    'family_id': 'family-r',
    'child_id': 'child-r',
    'child_display_name': 'Child',
    'domain': 'example-bad.com',
    'category': 'gambling',
    'decision': 'allowed',
    'blocked_at': DateTime.utc(2025, 7, 3, 12, 0, 0).toIso8601String(),
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('web_hits', {
    'family_id': 'family-r',
    'child_id': 'child-r',
    'child_display_name': 'Child',
    'domain': 'other-bad.com',
    'category': 'adult',
    'decision': 'blocked',
    'blocked_at': DateTime.utc(2025, 7, 2, 12, 0, 0).toIso8601String(),
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('web_hits', {
    'family_id': 'family-r',
    'child_id': 'child-r',
    'child_display_name': 'Child',
    'domain': 'future-bad.com',
    'category': 'gambling',
    'decision': 'blocked',
    'blocked_at': DateTime.utc(2025, 8, 1, 12, 0, 0).toIso8601String(),
    'created_at': _seededAt.toIso8601String(),
  });
  // FS-003 usage summaries — 90 minutes on day 1, 30 on day 2.
  await db.insert('child_usage_summaries', {
    'family_id': 'family-r',
    'device_id': 'device-r',
    'day_start': DateTime.utc(2025, 7, 1).toIso8601String(),
    'target': 'com.example.game',
    'total_milliseconds': 90 * 60 * 1000,
    'last_used_at': DateTime.utc(2025, 7, 1, 18, 0, 0).toIso8601String(),
    'captured_at': DateTime.utc(2025, 7, 1, 20, 0, 0).toIso8601String(),
  });
  await db.insert('child_usage_summaries', {
    'family_id': 'family-r',
    'device_id': 'device-r',
    'day_start': DateTime.utc(2025, 7, 2).toIso8601String(),
    'target': 'com.example.game',
    'total_milliseconds': 30 * 60 * 1000,
    'last_used_at': DateTime.utc(2025, 7, 2, 18, 0, 0).toIso8601String(),
    'captured_at': DateTime.utc(2025, 7, 2, 20, 0, 0).toIso8601String(),
  });
  // FS-001 location point + alert.
  await db.insert('location_points', {
    'family_id': 'family-r',
    'member_id': 'child-r',
    'device_id': 'device-r',
    'latitude': 24.7,
    'longitude': 46.6,
    'accuracy_meters': 20.0,
    'captured_at': DateTime.utc(2025, 7, 1, 15, 0, 0).toIso8601String(),
    'source': 'gps',
    'created_at': DateTime.utc(2025, 7, 1, 15, 0, 5).toIso8601String(),
  });
  await db.insert('location_alerts', {
    'family_id': 'family-r',
    'member_id': 'child-r',
    'geofence_id': 'geofence-home',
    'event_type': 'exit',
    'occurred_at': DateTime.utc(2025, 7, 1, 16, 0, 0).toIso8601String(),
    'source': 'geofence',
    'created_at': DateTime.utc(2025, 7, 1, 16, 0, 5).toIso8601String(),
  });
  // FS-006 incidents — one normal, one critical, one out of window.
  await db.insert('incidents', {
    'family_id': 'family-r',
    'category': 'web',
    'severity': 'low',
    'confidence': 0.9,
    'source': 'guardian',
    'status': 'open',
    'observed_at': DateTime.utc(2025, 7, 1, 13, 0, 0).toIso8601String(),
    'model_version': '1.0',
    'device_id': 'device-r',
    'actor_uid': 'child-r',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('incidents', {
    'family_id': 'family-r',
    'category': 'incident',
    'severity': 'critical',
    'confidence': 0.95,
    'source': 'guardian',
    'status': 'open',
    'observed_at': DateTime.utc(2025, 7, 2, 13, 0, 0).toIso8601String(),
    'model_version': '1.0',
    'device_id': 'device-r',
    'actor_uid': 'child-r',
    'created_at': _seededAt.toIso8601String(),
  });
  await db.insert('incidents', {
    'family_id': 'family-r',
    'category': 'web',
    'severity': 'low',
    'confidence': 0.9,
    'source': 'guardian',
    'status': 'open',
    'observed_at': DateTime.utc(2025, 8, 1, 13, 0, 0).toIso8601String(),
    'model_version': '1.0',
    'device_id': 'device-r',
    'actor_uid': 'child-r',
    'created_at': _seededAt.toIso8601String(),
  });
  // FS-005 mode config (required by mode_activations FK).
  await db.insert('mode_configs', {
    'mode_id': 'mode-homework',
    'family_id': 'family-r',
    'name': 'Homework',
    'kind': 'homework',
    'action': 'slowDown',
    'enabled': 1,
    'start_minute': 1020,
    'end_minute': 1200,
    'schedule_kind': 'daily',
    'weekdays': '1,2,3,4,5',
    'assigned_child_ids': 'child-r',
    'created_at': _seededAt.toIso8601String(),
    'updated_at': _seededAt.toIso8601String(),
  });
  // FS-005 mode activations.
  await db.insert('mode_activations', {
    'activation_id': 'act-1',
    'family_id': 'family-r',
    'mode_id': 'mode-homework',
    'child_id': 'child-r',
    'state': 'active',
    'started_at': DateTime.utc(2025, 7, 1, 17, 0, 0).toIso8601String(),
    'ends_at': null,
    'created_at': DateTime.utc(2025, 7, 1, 17, 0, 1).toIso8601String(),
  });
  await db.insert('mode_activations', {
    'activation_id': 'act-2',
    'family_id': 'family-r',
    'mode_id': 'mode-homework',
    'child_id': 'child-r',
    'state': 'ended',
    'started_at': DateTime.utc(2025, 7, 3, 17, 0, 0).toIso8601String(),
    'ends_at': DateTime.utc(2025, 7, 3, 19, 0, 0).toIso8601String(),
    'created_at': DateTime.utc(2025, 7, 3, 17, 0, 1).toIso8601String(),
  });
  // FS-006 SOS events.
  await db.insert('sos_events', {
    'family_id': 'family-r',
    'device_id': 'device-r',
    'status': 'delivered',
    'latitude': 24.7,
    'longitude': 46.6,
    'accuracy_m': 20.0,
    'created_at': DateTime.utc(2025, 7, 2, 20, 0, 0).toIso8601String(),
  });
  // FS-008 audio sessions.
  await db.insert('audio_sessions', {
    'id': 'audio-1',
    'family_id': 'family-r',
    'member_id': 'child-r',
    'device_id': 'device-r',
    'status': 'completed',
    'privacy_class': 'safetyEvidence',
    'started_at': DateTime.utc(2025, 7, 1, 21, 0, 0).toIso8601String(),
    'ended_at': DateTime.utc(2025, 7, 1, 21, 0, 30).toIso8601String(),
    'duration_seconds': 30,
    'sync_state': 'synced',
  });
}
Directory _exportDir() {
  final dir = Directory.systemTemp.createTempSync('fs009-export-');
  return dir;
}

void main() {
  group('FS-009 empty window', () {
    test('reports every section as empty with no recorded rows', () async {
      final database = await openTestDatabase();
      final db = await database.database;
      await _seedAll(db);
      final repo = ReportsRepository(database);
      // A window containing no rows at all.
      final snapshot = await repo.snapshotFor(
          familyId: 'family-r',
          period: ReportPeriod.week,
          now: DateTime.utc(2024, 6, 1));
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.sections.length, 7);
      for (final section in snapshot.sections) {
        expect(section.isEmpty, isTrue, reason: section.kind);
      }
    });
  });
  group('FS-009 seeded data', () {
    late GuardianDatabase database;
    late ReportsRepository repo;
    late FamilyReportSnapshot snapshot;
    setUp(() async {
      database = await openTestDatabase();
      await _seedAll(await database.database);
      repo = ReportsRepository(database);
      snapshot = await repo.snapshotFor(
          familyId: 'family-r', period: ReportPeriod.week, now: _weekEnd);
    });
    test('window is not empty and every section reports data', () async {
      expect(snapshot.isEmpty, isFalse);
      for (final section in snapshot.sections) {
        expect(section.isEmpty, isFalse, reason: section.kind);
      }
    });
    test('blocked web metric never counts allowed hits', () async {
      final web =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'web')!;
      final blocked = web.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpHitsBlocked')!;
      expect(int.parse(blocked.value), 3);
      final total = web.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpHitsTotal')!;
      expect(int.parse(total.value), 4);
    });
    test('top blocked domain is ordered by real occurrence count', () async {
      final top = await repo.webTopBlocked(
          'family-r', _weekStart, _weekEnd);
      expect(top.length, 2, reason: 'two domains were blocked in window');
      expect(top.first['domain'], 'example-bad.com');
      expect(top.first['total'], 2);
    });
    test('usage totals derive from stored milliseconds', () async {
      final usage =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'usage')!;
      final total = usage.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpUsageTotal')!;
      // _humanMinutes rounds to hours/minutes: 120 minutes -> '2h 0m'.
      expect(total.value, '2h 0m');
      final activeDays = usage.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpActiveDays')!;
      expect(int.parse(activeDays.value), 2);
    });
    test('location section counts real points and alerts', () async {
      final loc =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'location')!;
      final points = loc.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpPointsTotal')!;
      expect(int.parse(points.value), 1);
      final alerts = loc.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpAlertsTotal')!;
      expect(int.parse(alerts.value), 1);
    });
    test('incidents separate critical from total', () async {
      final safety =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'safety')!;
      final total = safety.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpIncidentsTotal')!;
      expect(int.parse(total.value), 2);
      final critical = safety.metrics.cast<ReportMetric?>().firstWhere((m) => m!.labelKey == 'rpIncidentsCritical')!;
      expect(int.parse(critical.value), 1);
    });
    test('modes and sos count real events', () async {
      final modes =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'modes')!;
      expect(int.parse(modes.metrics
          .cast<ReportMetric?>()
          .firstWhere((m) => m!.labelKey == 'rpModesTotal')!.value), 2);
      final sos =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'sos')!;
      expect(int.parse(sos.metrics
          .cast<ReportMetric?>()
          .firstWhere((m) => m!.labelKey == 'rpSosTotal')!.value), 1);
      final audio =
          snapshot.sections.cast<ReportSection?>().firstWhere((s) => s!.kind == 'audio')!;
      expect(int.parse(audio.metrics
          .cast<ReportMetric?>()
          .firstWhere((m) => m!.labelKey == 'rpAudioSessionsTotal')!.value), 1);
      expect(audio.metrics
          .cast<ReportMetric?>()
          .firstWhere((m) => m!.labelKey == 'rpAudioDurationTotal')!.value, '30s');
    });
  });
  group('FS-009 export artefacts', () {
    test('PDF export produces a non-empty file from a real snapshot',
        () async {
      final database = await openTestDatabase();
      await _seedAll(await database.database);
      final repo = ReportsRepository(database);
      final snapshot = await repo.snapshotFor(
          familyId: 'family-r', period: ReportPeriod.week, now: _weekEnd);
      final file = await ReportExportService(outputDirectory: _exportDir())
          .export(snapshot: snapshot, format: ReportFormat.pdf);
      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(100));
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46],
          reason: 'PDF magic bytes');
    });
    test('CSV export is UTF-8 text containing seeded rows', () async {
      final database = await openTestDatabase();
      await _seedAll(await database.database);
      final repo = ReportsRepository(database);
      final snapshot = await repo.snapshotFor(
          familyId: 'family-r', period: ReportPeriod.week, now: _weekEnd);
      final file = await ReportExportService(outputDirectory: _exportDir())
          .export(snapshot: snapshot, format: ReportFormat.csv);
      final text = await file.readAsString();
      expect(text.length, greaterThan(10));
      expect(text, contains('example-bad.com'));
    });
  });
}
