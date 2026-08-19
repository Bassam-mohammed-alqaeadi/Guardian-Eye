import 'package:sqflite/sqflite.dart';
import '../core/database/guardian_database.dart';
import '../domain/reports_domain.dart';

/// FS-009 — Reports & Export. Pure aggregation layer over the subsystem
/// tables. Every section declares the exact window it read and returns an
/// [ReportSection.isEmpty] verdict when the table held no rows in the
/// window — never a fabricated total.
///
/// Reads-only: it never mutates any subsystem table.
class ReportsRepository {
  ReportsRepository(this._database);

  final GuardianDatabase _database;

  /// The canonical window for a reporting period, anchored on [now].
  (DateTime, DateTime) windowFor(ReportPeriod period, {DateTime? now}) {
    final t = now ?? DateTime.now();
    if (period == ReportPeriod.week) {
      final start = DateTime(t.year, t.month, t.day - 6);
      return (start, DateTime(t.year, t.month, t.day, 23, 59, 59));
    }
    if (period == ReportPeriod.month) {
      final start = DateTime(t.year, t.month, 1);
      return (start, DateTime(t.year, t.month, t.day, 23, 59, 59));
    }
    return (DateTime(1970, 1, 1), t);
  }

  String _iso(DateTime t) => t.toIso8601String();

  Future<String> _familyName(String familyId) async {
    final db = await _database.database;
    final rows =
        await db.query('families', where: 'id = ?', whereArgs: [familyId]);
    if (rows.isEmpty) return '—';
    return (rows.first['name'] as String?) ?? '—';
  }

  int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }

  // ------------------------------------------------------------------ web

  /// Blocked/allowed web hits within the window, grouped by ISO day.
  Future<List<Map<String, Object?>>> webHitsByDay(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT DATE(blocked_at) AS day, COUNT(*) AS total, '
        "SUM(CASE WHEN decision = 'blocked' THEN 1 ELSE 0 END) AS blocked "
        'FROM web_hits WHERE family_id = ? AND blocked_at >= ? AND blocked_at <= ? '
        'GROUP BY day ORDER BY day',
        [familyId, _iso(start), _iso(end)]);
    return rows
        .map((r) => {
              'day': r['day'],
              'total': _asInt(r['total']),
              'blocked': _asInt(r['blocked']),
            })
        .toList();
  }

  /// Top blocked domains in the window.
  Future<List<Map<String, Object?>>> webTopBlocked(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT domain, category, child_display_name, COUNT(*) AS total '
        'FROM web_hits WHERE family_id = ? AND blocked_at >= ? AND '
        "blocked_at <= ? AND decision = 'blocked' "
        'GROUP BY domain ORDER BY total DESC LIMIT 10',
        [familyId, _iso(start), _iso(end)]);
    return rows;
  }

  /// Blocked hit counts grouped by content category.
  Future<List<Map<String, Object?>>> webHitsByCategory(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT category, COUNT(*) AS total FROM web_hits '
        'WHERE family_id = ? AND blocked_at >= ? AND blocked_at <= ? '
        'GROUP BY category ORDER BY total DESC',
        [familyId, _iso(start), _iso(end)]);
    return rows;
  }

  Future<int> webTotalHits(String familyId, DateTime start, DateTime end,
      {String? childId}) async {
    final db = await _database.database;
    final where = 'family_id = ? AND blocked_at >= ? AND blocked_at <= ?' +
        (childId == null ? '' : ' AND child_id = ?');
    final args = childId == null
        ? [familyId, _iso(start), _iso(end)]
        : [familyId, _iso(start), _iso(end), childId];
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM web_hits WHERE $where', args)) ??
        0;
  }

  Future<int> webBlockedHits(String familyId, DateTime start, DateTime end,
      {String? childId}) async {
    final db = await _database.database;
    final where = 'family_id = ? AND blocked_at >= ? AND blocked_at <= ?' +
        " AND decision = 'blocked'" +
        (childId == null ? '' : ' AND child_id = ?');
    final args = childId == null
        ? [familyId, _iso(start), _iso(end)]
        : [familyId, _iso(start), _iso(end), childId];
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM web_hits WHERE $where', args)) ??
        0;
  }

  // ----------------------------------------------------------------- usage

  Future<List<Map<String, Object?>>> usageTopTargets(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT target, SUM(total_milliseconds) AS total_ms, '
        'MAX(last_used_at) AS last_used '
        'FROM child_usage_summaries WHERE family_id = ? AND day_start >= ? '
        'AND day_start <= ? GROUP BY target ORDER BY total_ms DESC LIMIT 10',
        [familyId, _iso(start), _iso(end)]);
    return rows;
  }

  Future<List<Map<String, Object?>>> usageByDeviceDay(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT device_id, DATE(day_start) AS day, '
        'SUM(total_milliseconds) AS total_ms '
        'FROM child_usage_summaries WHERE family_id = ? AND day_start >= ? '
        'AND day_start <= ? GROUP BY device_id, day ORDER BY day',
        [familyId, _iso(start), _iso(end)]);
    return rows;
  }

  /// Per-child total screen time in milliseconds for the window.
  Future<List<Map<String, Object?>>> usageByChild(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT d.member_id, SUM(cs.total_milliseconds) AS total_ms '
        'FROM child_usage_summaries cs '
        'INNER JOIN devices d ON d.id = cs.device_id '
        'WHERE cs.family_id = ? AND cs.day_start >= ? AND cs.day_start <= ? '
        'GROUP BY d.member_id ORDER BY total_ms DESC',
        [familyId, _iso(start), _iso(end)]);
    return rows;
  }

  // -------------------------------------------------------------- location

  Future<int> locationPointsCount(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM location_points '
        'WHERE family_id = ? AND captured_at >= ? AND captured_at <= ?',
        [familyId, _iso(start), _iso(end)]);
    return (rows.first['total'] as int? ?? 0);
  }

  Future<List<Map<String, Object?>>> locationAlerts(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query('location_alerts',
        where: 'family_id = ? AND occurred_at >= ? AND occurred_at <= ?',
        whereArgs: [familyId, _iso(start), _iso(end)],
        orderBy: 'occurred_at DESC');
    return rows;
  }

  Future<List<Map<String, Object?>>> geofenceEntries(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query('geofences',
        where: 'family_id = ? AND updated_at >= ?',
        whereArgs: [familyId, _iso(start)]);
    return rows;
  }

  // -------------------------------------------------------------- safety

  Future<List<Map<String, Object?>>> incidentsInRange(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query('incidents',
        where: 'family_id = ? AND observed_at >= ? AND observed_at <= ?',
        whereArgs: [familyId, _iso(start), _iso(end)],
        orderBy: 'observed_at DESC');
    return rows;
  }

  Future<int> incidentsBySeverity(String familyId, DateTime start,
      DateTime end, String severity) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM incidents '
        'WHERE family_id = ? AND severity = ? AND observed_at >= ? '
        'AND observed_at <= ?',
        [familyId, severity, _iso(start), _iso(end)]);
    return (rows.first['total'] as int? ?? 0);
  }

  // ---------------------------------------------------------------- modes

  Future<List<Map<String, Object?>>> modeActivations(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query('mode_activations',
        where: 'family_id = ? AND started_at >= ? AND started_at <= ?',
        whereArgs: [familyId, _iso(start), _iso(end)],
        orderBy: 'started_at DESC');
    return rows;
  }

  Future<int> modeActivationsCount(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM mode_activations '
        'WHERE family_id = ? AND started_at >= ? AND started_at <= ?',
        [familyId, _iso(start), _iso(end)]);
    return (rows.first['total'] as int? ?? 0);
  }

  // ----------------------------------------------------------------- sos

  Future<int> sosEventsCount(String familyId, DateTime start, DateTime end,
      {String? type}) async {
    final db = await _database.database;
    String where = 'family_id = ? AND created_at >= ? AND created_at <= ?';
    final args = <Object?>[familyId, _iso(start), _iso(end)];
    if (type != null) {
      where += ' AND event_type = ?';
      args.add(type);
    }
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM sos_events WHERE $where', args);
    return (rows.first['total'] as int? ?? 0);
  }

  Future<List<Map<String, Object?>>> sosEvents(
      String familyId, DateTime start, DateTime end) async {
    final db = await _database.database;
    final rows = await db.query('sos_events',
        where: 'family_id = ? AND created_at >= ? AND created_at <= ?',
        whereArgs: [familyId, _iso(start), _iso(end)],
        orderBy: 'created_at DESC');
    return rows;
  }

  // ----------------------------------------------------------- aggregates

  /// Builds the honest per-section snapshot for the given period. Sections
  /// with no data in the window are still emitted, flagged [ReportSection.isEmpty].
  Future<FamilyReportSnapshot> snapshotFor({
    required String familyId,
    required ReportPeriod period,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();
    final (start, end) = windowFor(period, now: t);
    final name = await _familyName(familyId);

    final webTotal = await webTotalHits(familyId, start, end);
    final webBlocked = await webBlockedHits(familyId, start, end);
    final webByDay = await webHitsByDay(familyId, start, end);
    final webTop = await webTopBlocked(familyId, start, end);
    // Active-day count: days within the window that recorded any web
    // activity — honest context about how spread-out browsing was.
    final webActiveDays = webByDay.where((row) => _asInt(row['total']) > 0).length;
    final webSection = ReportSection(
      kind: ReportSectionKind.web,
      titleKey: 'rpWebTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: webTotal == 0,
      metrics: [
        ReportMetric(
            labelKey: 'rpHitsTotal', value: '$webTotal', numericValue: webTotal),
        ReportMetric(
            labelKey: 'rpHitsBlocked',
            value: '$webBlocked',
            numericValue: webBlocked,
            tone: webBlocked > 0 ? ReportTone.warning : ReportTone.neutral),
        if (webByDay.isNotEmpty)
          ReportMetric(
              labelKey: 'rpActiveDays',
              value: '$webActiveDays',
              numericValue: webActiveDays,
              tone: ReportTone.neutral),
      ],
            rows: webTop
          .map<List<String>>((r) => [
                (r['domain'] ?? '—') as String,
                (r['category'] ?? '—') as String,
                '${_asInt(r['total'])}',
              ])
          .toList(),
    );
    final usageChildren = await usageByChild(familyId, start, end);
    final usageTop = await usageTopTargets(familyId, start, end);
    final usageDays = (await usageByDeviceDay(familyId, start, end))
        .map((r) => r['day'] ?? '')
        .toSet()
        .length;
    int usageTotalMs = 0;
    final usageRows = <List<String>>[];
    for (final r in usageChildren) {
      usageTotalMs += _asInt(r['total_ms']);
      usageRows.add([(r['member_id'] ?? '—') as String, _humanMinutes(_asInt(r['total_ms']))]);
    }
    final usageSection = ReportSection(
      kind: ReportSectionKind.usage,
      titleKey: 'rpUsageTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: usageTotalMs == 0,
      metrics: [
        ReportMetric(labelKey: 'rpUsageTotal', value: _humanMinutes(usageTotalMs)),
        ReportMetric(labelKey: 'rpActiveDays', value: '$usageDays'),
        ReportMetric(labelKey: 'rpTopTargets', value: '${usageTop.length}'),
      ],
      rows: usageRows,
    );

    final points = await locationPointsCount(familyId, start, end);
    final alerts = await locationAlerts(familyId, start, end);
    final locationSection = ReportSection(
      kind: ReportSectionKind.location,
      titleKey: 'rpLocationTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: points == 0 && alerts.isEmpty,
      metrics: [
        ReportMetric(labelKey: 'rpPointsTotal', value: '$points'),
        ReportMetric(
            labelKey: 'rpAlertsTotal',
            value: '${alerts.length}',
            tone: alerts.isNotEmpty ? ReportTone.warning : ReportTone.neutral),
      ],
    );

    final incidents = await incidentsInRange(familyId, start, end);
    final critical =
        await incidentsBySeverity(familyId, start, end, 'critical');
    final safetySection = ReportSection(
      kind: ReportSectionKind.safety,
      titleKey: 'rpSafetyTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: incidents.isEmpty,
      metrics: [
        ReportMetric(
            labelKey: 'rpIncidentsTotal', value: '${incidents.length}'),
        ReportMetric(
            labelKey: 'rpIncidentsCritical',
            value: '$critical',
            tone: critical > 0 ? ReportTone.critical : ReportTone.neutral),
      ],
    );

    final modes = await modeActivations(familyId, start, end);
    final modeSection = ReportSection(
      kind: ReportSectionKind.modes,
      titleKey: 'rpModesTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: modes.isEmpty,
      metrics: [
        ReportMetric(labelKey: 'rpModesTotal', value: '${modes.length}'),
        ReportMetric(labelKey: 'rpModesActive',
            value: '${modes.where((m) => m['state'] == 'applied').length}'),
      ],
    );

    final sosCount = await sosEventsCount(familyId, start, end);
    final sosSection = ReportSection(
      kind: ReportSectionKind.sos,
      titleKey: 'rpSosTitle',
      dataStart: start,
      dataEnd: end,
      isEmpty: sosCount == 0,
      metrics: [
        ReportMetric(labelKey: 'rpSosTotal', value: '$sosCount',
            tone: sosCount > 0 ? ReportTone.critical : ReportTone.neutral),
      ],
    );

    return FamilyReportSnapshot(
      familyId: familyId,
      familyName: name,
      period: period,
      start: start,
      end: end,
      sections: [
        webSection,
        usageSection,
        locationSection,
        safetySection,
        modeSection,
        sosSection,
      ],
      capturedAt: t,
    );
  }

  String _humanMinutes(int totalMs) {
    final minutes = (totalMs / 60000).round();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}
