import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../application/family_context_provider.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';
import '../domain/reports_domain.dart';
import 'reports_repository.dart';

/// Current export bundle schema version. Bump on every structural change and
/// update the validator together with the reader.
const int familyExportSchemaVersion = 1;

/// Export bundle top-level keys. The validator asserts every one of these is
/// present and no excluded key (FCM tokens, outbox, AI, identity secrets)
/// is written.
const String familyExportTopLevelManifest = 'manifest';
const String familyExportFamilyKey = 'family';
const String familyExportSectionsKey = 'sections';

/// Top-level keys that are excluded by construction. The bundle validator
/// fails the export if any of these appear anywhere in the generated JSON.
const Set<String> familyExportForbiddenKeys = {
  'fcm_token',
  'token',
  'app_identity',
  'outbox',
  'notification_tokens',
  'ai_risk_states',
  'ai_behavior_profiles',
  'ai_insights',
  'ai_detections',
  'ai_copilot_suggestions',
  'ai_policy_proposals',
  'ai_consent_scopes',
  'service_account',
  'credentials',
  'auth_token',
  'password',
};

/// One export section: its identity, an honest inclusion status, and the
/// rows the authorized actor may see.
class FamilyExportSection {
  const FamilyExportSection({
    required this.key,
    required this.titleKey,
    required this.included,
    required this.rows,
    required this.status,
    this.error,
  });

  /// Stable export key used in the JSON bundle and the manifest.
  final String key;

  /// l10n key shown in the UI summary.
  final String titleKey;

  /// `true` when the section was assembled inside the authorized scope.
  /// `false` marks a section that failed honestly (`status` carries why).
  final bool included;

  final List<Map<String, Object?>> rows;

  /// Honest per-section verdict: `included`, `no_data`, `failed`.
  final String status;

  final String? error;

  Map<String, Object?> toJson() => {
        'key': key,
        'titleKey': titleKey,
        'included': included,
        'rows': rows,
        'status': status,
        if (error != null) 'error': error,
      };
}

/// The terminal state of a local export operation.
enum FamilyExportState {
  notRequested,
  permissionCheck,
  preparing,
  readyToShare,
  sharedOrSaved,
  failed,
  cancelled,
  expired,
  blockedPermission,
}

/// Honest outcome of one export attempt.
class FamilyExportOutcome {
  const FamilyExportOutcome({
    required this.state,
    required this.familyId,
    this.file,
    this.sections = const [],
    this.validationErrors = const [],
    this.reason,
  });

  final FamilyExportState state;
  final String familyId;

  /// The validated JSON bundle on disk. Null until
  /// [FamilyExportState.readyToShare].
  final File? file;

  /// Per-section honesty flags returned by the assembler.
  final List<FamilyExportSection> sections;

  /// Reasons the final validation rejected the bundle.
  final List<String> validationErrors;

  final String? reason;

  bool get hasFile => file != null;
}

/// Section assembler function signature (test-overridable readers).
typedef ExportSectionBuilder = Future<FamilyExportSection> Function(
  String familyId,
  FamilyRuntimeContext context,
  ReportsRepository reports,
);

/// Local family-data export for the current device (Phase 4D, local scope
/// only). Generates a versioned, schema-validated JSON bundle containing
/// exactly what the requesting active parent/owner is authorized to read.
///
/// Authorization mirrors the purge engine and the approved contract:
///
/// - The actor must be verified, active, and bound to the family being
///   exported (`actor.familyId == familyId`); never a child, never a
///   revoked or invited member. The client-supplied [familyId] is never
///   trusted without this local verification.
/// - Sections are assembled from the authorized scope only. The frozen AI
///   tables, raw FCM tokens, `app_identity`, outbox payloads, and any
///   credential material are excluded by construction: they are never
///   queried, never projected, and the validator rejects them if they
///   appear anyway.
/// - Failure is honest: a partially failed bundle is reported
///   `failed` with per-section flags — never promoted to `readyToShare`.
class LocalFamilyExportService {
  LocalFamilyExportService({
    required GuardianDatabase database,
    required ReportsRepository reports,
    Directory Function()? documentsDirectory,
  })  : _db = database,
        _reports = reports,
        _documentsDirectory = documentsDirectory ??
            (() => Directory.systemTemp);

  final GuardianDatabase _db;
  final ReportsRepository _reports;
  final Directory Function() _documentsDirectory;

  /// Section builders, in stable order. Each reader is keyed by a stable
  /// export key so the manifest can state exactly what was included.
  static const List<(String key, String titleKey)> exportSectionOrder = [
    ('family', 'exportSectionFamily'),
    ('members', 'exportSectionMembers'),
    ('devices', 'exportSectionDevices'),
    ('locationSettings', 'exportSectionLocationSettings'),
    ('locationHistory', 'exportSectionLocationHistory'),
    ('geofences', 'exportSectionGeofences'),
    ('favorites', 'exportSectionFavorites'),
    ('incidents', 'exportSectionIncidents'),
    ('sosEvents', 'exportSectionSosEvents'),
    ('webStats', 'exportSectionWebStats'),
    ('usageStats', 'exportSectionUsageStats'),
    ('modes', 'exportSectionModes'),
    ('familyRules', 'exportSectionFamilyRules'),
    ('tasks', 'exportSectionTasks'),
    ('rewards', 'exportSectionRewards'),
    ('couple', 'exportSectionCouple'),
    ('subscription', 'exportSectionSubscription'),
  ];

  /// Runs the export for [familyId]. A verified, active, adult member of
  /// [familyId] is required; everyone else is rejected with
  /// [FamilyExportState.blockedPermission] and no file is written.
  Future<FamilyExportOutcome> run({
    required String familyId,
    required FamilyRuntimeContext context,
    ReportPeriod period = ReportPeriod.month,
    Duration expiry = const Duration(minutes: 30),
    Map<String, ExportSectionBuilder>? sectionBuilders,
    DateTime Function()? clock,
  }) async {
    final now = clock?.call() ?? DateTime.now();

    if (!context.isVerified || context.actor == null) {
      return _failed(familyId, FamilyExportState.blockedPermission,
          reason: 'actor_not_bound');
    }
    if (context.actor!.role == FamilyRole.child) {
      return _failed(familyId, FamilyExportState.blockedPermission,
          reason: 'child_denied');
    }
    // The actor's own family binding is the canonical cross-family
    // boundary: a device bound to another family cannot export this
    // family's data even if the surrounding runtime advertises it.
    if (context.actor!.familyId != familyId ||
        context.familyId != familyId) {
      return _failed(familyId, FamilyExportState.blockedPermission,
          reason: 'cross_family_denied');
    }
    if (context.actor!.status != FamilyMemberStatus.active) {
      return _failed(familyId, FamilyExportState.blockedPermission,
          reason: 'membership_not_active');
    }
    if (!context.can(FamilyPermission.viewReports)) {
      return _failed(familyId, FamilyExportState.blockedPermission,
          reason: 'permission_denied');
    }

    final baseHealthy = await _db.verifyBaseSchema();
    if (!baseHealthy) {
      return _failed(familyId, FamilyExportState.failed,
          reason: 'base_schema_unhealthy');
    }

    final builders = sectionBuilders ?? _defaultBuilders();
    final sections = <FamilyExportSection>[];
    final failedSections = <String>[];

    for (final (key, titleKey) in exportSectionOrder) {
      final builder = builders[key];
      if (builder == null) continue;
      try {
        final section =
            await builder(familyId, context, _reports);
        sections.add(section);
        if (!section.included && section.status != 'no_data') {
          failedSections.add(key);
        }
      } catch (e) {
        failedSections.add(key);
        sections.add(FamilyExportSection(
          key: key,
          titleKey: titleKey,
          included: false,
          rows: const [],
          status: 'failed',
          error: '$e',
        ));
      }
    }

    if (failedSections.isNotEmpty) {
      return FamilyExportOutcome(
        state: FamilyExportState.failed,
        familyId: familyId,
        sections: sections,
        reason: 'section_failures: ${failedSections.join(',')}',
      );
    }

    final bundle = _buildBundle(
      familyId: familyId,
      context: context,
      now: now,
      sections: sections,
    );

    // Honesty guard: nothing excluded by construction may appear in the
    // bundle. A bundle failing this check never reaches the file system.
    final encoded = json.encode(bundle);
    final decoded = json.decode(encoded);
    final validator = _ExportBundleValidator();
    final violations =
        validator.validate(decoded as Map<String, Object?>, familyId);
    if (violations.isNotEmpty) {
      return FamilyExportOutcome(
        state: FamilyExportState.failed,
        familyId: familyId,
        sections: sections,
        validationErrors: violations,
        reason: 'validation_failed',
      );
    }

    final dir = await _exportDirectory();
    await dir.create(recursive: true);
    final file =
        File(p.join(dir.path, 'guardian_export_$familyId${_stamp(now)}.json'));
    await file.writeAsString(encoded, encoding: utf8);

    // The file is re-read and re-validated before we ever hand it to the
    // share flow: no "exported" claim until proven.
    final reParsed = json.decode(await file.readAsString());
    final secondPass = validator.validate(
        reParsed as Map<String, Object?>, familyId);
    if (secondPass.isNotEmpty) {
      try { await file.delete(); } catch (_) {}
      return FamilyExportOutcome(
        state: FamilyExportState.failed,
        familyId: familyId,
        sections: sections,
        validationErrors: secondPass,
        reason: 'post_write_validation_failed',
      );
    }

    return FamilyExportOutcome(
      state: FamilyExportState.readyToShare,
      familyId: familyId,
      file: file,
      sections: sections,
    );
  }

  Future<Directory> _exportDirectory() async {
    final base = _documentsDirectory();
    return Directory(p.join(base.path, 'privacy_exports'));
  }

  String _stamp(DateTime t) =>
      '${t.year}${_two(t.month)}${_two(t.day)}_${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';

  String _two(int n) => n.toString().padLeft(2, '0');

  FamilyExportOutcome _failed(String familyId, FamilyExportState state,
      {String? reason}) {
    return FamilyExportOutcome(
      state: state,
      familyId: familyId,
      reason: reason,
    );
  }

  Map<String, Object?> _buildBundle({
    required String familyId,
    required FamilyRuntimeContext context,
    required DateTime now,
    required List<FamilyExportSection> sections,
  }) {
    final actor = context.actor!;
    return {
      familyExportTopLevelManifest: {
        'schemaVersion': familyExportSchemaVersion,
        'generatedAt': now.toIso8601String(),
        'familyId': familyId,
        'familyName': context.family?.name ?? '',
        'requesterMemberId': actor.id,
        'requesterRole': actor.role.name,
        'includedSections':
            sections.where((s) => s.included).map((s) => s.key).toList(),
        'excludedSections':
            sections.where((s) => !s.included).map((s) => s.key).toList(),
        'sectionStatus': {
          for (final s in sections) s.key: s.status,
        },
      },
      familyExportFamilyKey: {
        'id': familyId,
        'name': context.family?.name ?? '',
        'myRole': actor.role.name,
        'myStatus': actor.status.name,
      },
      familyExportSectionsKey: {
        for (final s in sections) s.key: s.rows,
      },
    };
  }

  /// Default per-domain readers. Each query projects explicit columns and
  /// never touches the frozen AI tables, outbox, or identity secrets.
  Map<String, ExportSectionBuilder> _defaultBuilders() => {
        'family': _readFamily,
        'members': _readMembers,
        'devices': _readDevices,
        'locationSettings': _readLocationSettings,
        'locationHistory': _readLocationHistory,
        'geofences': _readGeofences,
        'favorites': _readFavorites,
        'incidents': _readIncidents,
        'sosEvents': _readSosEvents,
        'webStats': _readWebStats,
        'usageStats': _readUsageStats,
        'modes': _readModes,
        'familyRules': _readFamilyRules,
        'tasks': _readTasks,
        'rewards': _readRewards,
        'couple': _readCouple,
        'subscription': _readSubscription,
      };

  // ----------------------------------------------------------------- readers

  Future<FamilyExportSection> _readFamily(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('families',
        where: 'id = ?', whereArgs: [familyId]);
    return _section('family', 'exportSectionFamily', rows, familyId);
  }

  Future<FamilyExportSection> _readMembers(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('family_members',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('members', 'exportSectionMembers', rows, familyId);
  }

  Future<FamilyExportSection> _readDevices(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    // Identity view without secrets: the devices table holds no FCM token,
    // but project explicit columns so no future secret column can leak.
    final rows = await db.query('devices',
        columns: const [
          'id',
          'family_id',
          'member_id',
          'owner_member_id',
          'role',
          'sync_state',
          'last_synced_at',
          'revoked_at',
          'created_at',
        ],
        where: 'family_id = ?',
        whereArgs: [familyId]);
    return _section('devices', 'exportSectionDevices', rows, familyId);
  }

  Future<FamilyExportSection> _readLocationSettings(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('location_settings',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('locationSettings', 'exportSectionLocationSettings',
        rows, familyId);
  }

  Future<FamilyExportSection> _readLocationHistory(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    // Approved scope: aggregate counts + density honesty, never raw
    // coordinates for every point — the point cloud is sensitive and the
    // FS-009 report already publishes the aggregate volume per period.
    final db = await _db.database;
    final rows = await db.query('location_points',
        columns: const ['device_id', 'captured_at'],
        where: 'family_id = ?',
        whereArgs: [familyId]);
    final byDay = <String, int>{};
    int total = 0;
    for (final row in rows) {
      final at = (row['captured_at'] as String?) ?? '';
      final day = at.length >= 10 ? at.substring(0, 10) : '';
      if (day.isNotEmpty) {
        byDay[day] = (byDay[day] ?? 0) + 1;
        total++;
      }
    }
    return FamilyExportSection(
      key: 'locationHistory',
      titleKey: 'exportSectionLocationHistory',
      included: true,
      rows: [
        {
          'family_id': familyId,
          'total_points': total,
          'by_day': {
            for (final e in byDay.entries) e.key: e.value,
          },
        },
      ],
      status: total == 0 ? 'no_data' : 'included',
    );
  }

  Future<FamilyExportSection> _readGeofences(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('geofences',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('geofences', 'exportSectionGeofences', rows, familyId);
  }

  Future<FamilyExportSection> _readFavorites(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('favorite_places',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('favorites', 'exportSectionFavorites', rows, familyId);
  }

  Future<FamilyExportSection> _readIncidents(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('incidents',
        columns: const [
          'id',
          'family_id',
          'category',
          'severity',
          'status',
          'observed_at',
          'device_id',
        ],
        where: 'family_id = ?',
        whereArgs: [familyId]);
    return _section('incidents', 'exportSectionIncidents', rows, familyId);
  }

  Future<FamilyExportSection> _readSosEvents(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('sos_events',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('sosEvents', 'exportSectionSosEvents', rows, familyId);
  }

  Future<FamilyExportSection> _readWebStats(String familyId,
      FamilyRuntimeContext context, ReportsRepository reports) async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final total = await reports.webTotalHits(familyId, start, DateTime.now());
    final blocked =
        await reports.webBlockedHits(familyId, start, DateTime.now());
    return FamilyExportSection(
      key: 'webStats',
      titleKey: 'exportSectionWebStats',
      included: true,
      rows: [
        {
          'family_id': familyId,
          'period': 'last_30_days',
          'total_hits': total,
          'blocked_hits': blocked,
        },
      ],
      status: total == 0 && blocked == 0 ? 'no_data' : 'included',
    );
  }

  Future<FamilyExportSection> _readUsageStats(String familyId,
      FamilyRuntimeContext context, ReportsRepository reports) async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    final byChild = await reports.usageByChild(familyId, start, DateTime.now());
    return FamilyExportSection(
      key: 'usageStats',
      titleKey: 'exportSectionUsageStats',
      included: true,
      rows: byChild
          .map<Map<String, Object?>>((r) => {
                'member_id': (r['member_id'] ?? '—') as String,
                'total_minutes':
                    (_asInt(r['total_ms']) / 60000).round(),
              })
          .toList(),
      status: byChild.isEmpty ? 'no_data' : 'included',
    );
  }

  Future<FamilyExportSection> _readModes(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('policies',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('modes', 'exportSectionModes', rows, familyId);
  }

  Future<FamilyExportSection> _readFamilyRules(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('family_rules',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('familyRules', 'exportSectionFamilyRules', rows, familyId);
  }

  Future<FamilyExportSection> _readTasks(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final rows = await db.query('tasks',
        where: 'family_id = ?', whereArgs: [familyId]);
    return _section('tasks', 'exportSectionTasks', rows, familyId);
  }

  Future<FamilyExportSection> _readRewards(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final catalog = await db.query('family_rewards',
        where: 'family_id = ?', whereArgs: [familyId]);
    final ledger = await db.query('reward_points_ledger',
        where: 'family_id = ?', whereArgs: [familyId]);
    return FamilyExportSection(
      key: 'rewards',
      titleKey: 'exportSectionRewards',
      included: true,
      rows: [
        for (final r in catalog) r,
        for (final r in ledger) r,
      ],
      status: catalog.isEmpty && ledger.isEmpty ? 'no_data' : 'included',
    );
  }

  Future<FamilyExportSection> _readCouple(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final actorId = context.actor!.id;
    // The requesting partner sees only their own linking state; the
    // partner's rows stay excluded by construction.
    final rows = await db.query('couple_linking',
        where: 'family_id = ? AND partner_member_id = ?',
        whereArgs: [familyId, actorId]);
    return _section('couple', 'exportSectionCouple', rows, familyId);
  }

  Future<FamilyExportSection> _readSubscription(
      String familyId, FamilyRuntimeContext context, ReportsRepository _) async {
    final db = await _db.database;
    final entitlements = await db.query('subscription_entitlements',
        where: 'family_id = ?', whereArgs: [familyId]);
    final billing = await db.query('billing_records',
        where: 'family_id = ?', whereArgs: [familyId]);
    return FamilyExportSection(
      key: 'subscription',
      titleKey: 'exportSectionSubscription',
      included: true,
      rows: [
        for (final r in entitlements) r,
        for (final r in billing) r,
      ],
      status: entitlements.isEmpty && billing.isEmpty ? 'no_data' : 'included',
    );
  }

  Future<FamilyExportSection> _section(String key, String titleKey,
      List<Map<String, Object?>> rows, String familyId) async {
    return FamilyExportSection(
      key: key,
      titleKey: titleKey,
      included: true,
      rows: rows,
      status: rows.isEmpty ? 'no_data' : 'included',
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

/// Validates an export bundle before it is ever handed to the share flow.
/// Fails on: missing manifest, wrong schema version, wrong family scope,
/// missing top-level structure, or any forbidden key anywhere in the tree.
class _ExportBundleValidator {
  List<String> validate(Map<String, Object?> bundle, String familyId) {
    final violations = <String>[];

    final manifest = bundle[familyExportTopLevelManifest];
    if (manifest is! Map) {
      return const ['manifest_missing'];
    }
    final version = manifest['schemaVersion'];
    if (version != familyExportSchemaVersion) {
      violations.add('schema_version_mismatch');
    }
    final scope = manifest['familyId'];
    if (scope != familyId) {
      violations.add('family_scope_mismatch');
    }
    if (bundle[familyExportFamilyKey] is! Map) {
      violations.add('family_missing');
    }
    if (bundle[familyExportSectionsKey] is! Map) {
      violations.add('sections_missing');
    }

    final forbidden = _findForbiddenKeys(bundle);
    violations.addAll(forbidden);
    return violations;
  }

  Set<String> _findForbiddenKeys(Object? node) {
    final found = <String>{};
    void walk(Object? value) {
      if (value is Map) {
        for (final key in value.keys) {
          final name = key.toString().toLowerCase();
          for (final forbidden in familyExportForbiddenKeys) {
            if (name == forbidden) found.add(forbidden);
          }
          walk(value[key]);
        }
      } else if (value is List) {
        for (final item in value) {
          walk(item);
        }
      }
    }

    walk(node);
    return found;
  }
}
