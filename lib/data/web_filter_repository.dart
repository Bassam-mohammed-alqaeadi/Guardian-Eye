import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../core/database/guardian_database.dart';
import '../domain/guardian_models.dart';

/// FS-002 — Web Filtering. Local-first store for the web-protection data
/// the parent administers: what was blocked (hits), what the parent pinned
/// as blocked or trusted (domains), per-child category rules, and family
/// web-settings (safe search, blocked-page behavior, exception requests).
///
/// Honesty contract: every value returned is a locally observed value.
/// Nothing is fabricated until the device confirms it. Mutations are
/// local SQLite writes first; delivery to the child device follows the
/// same offline-first outbox rhythm as every other feature — the UI never
/// claims server delivery without real evidence.

/// One observed web-block event. The enforcement layer on the child
/// device records these; the parent app reads them as the Block History.
class WebBlockHit {
  const WebBlockHit({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.childDisplayName,
    required this.domain,
    required this.category,
    required this.blockedAt,
    required this.decision,
    required this.syncState,
    this.overriddenBy,
  });

  final String id;
  final String familyId;
  final String childId;
  final String childDisplayName;
  final String domain;
  final String category;
  final DateTime blockedAt;
  final String decision; // 'blocked' | 'allowed'
  final SyncState syncState;
  final String? overriddenBy;

  factory WebBlockHit.fromMap(Map<String, Object?> row) => WebBlockHit(
      id: row['id']! as String,
      familyId: row['family_id']! as String,
      childId: row['child_id']! as String,
      childDisplayName: (row['child_display_name'] as String?) ??
          (row['child_id']! as String),
      domain: row['domain']! as String,
      category: (row['category'] as String?) ?? 'other',
      blockedAt: DateTime.parse(row['blocked_at']! as String),
      decision: (row['decision'] as String?) ?? 'blocked',
      syncState: _syncStateOf(row['sync_state'] as String?),
      overriddenBy: row['overridden_by'] as String?);
}

/// A domain the parent manages. Kind `block` forces blocking; kind
/// `allow` makes the domain pass every filter (trusted: school, bank).
class WebDomainEntry {
  const WebDomainEntry({
    required this.id,
    required this.familyId,
    required this.domain,
    required this.kind,
    required this.enabled,
    required this.createdAt,
    this.reason,
    this.syncState = SyncState.localOnly,
  });

  final String id;
  final String familyId;
  final String domain;
  final String kind; // 'block' | 'allow'
  final bool enabled;
  final DateTime createdAt;
  final String? reason;
  final SyncState syncState;

  factory WebDomainEntry.fromMap(Map<String, Object?> row) => WebDomainEntry(
      id: row['id']! as String,
      familyId: row['family_id']! as String,
      domain: row['domain']! as String,
      kind: (row['kind'] as String?) ?? 'block',
      enabled: (row['enabled'] as int) == 1,
      createdAt: DateTime.parse(row['created_at']! as String),
      reason: row['reason'] as String?,
      syncState: _syncStateOf(row['sync_state'] as String?));
}

/// Per-child category rule. One row per (family, child, category).
class WebCategoryRule {
  const WebCategoryRule({
    required this.familyId,
    required this.childId,
    required this.childDisplayName,
    required this.category,
    required this.enabled,
    required this.syncState,
  });

  final String familyId;
  final String childId;
  final String childDisplayName;
  final String category;
  final bool enabled;
  final SyncState syncState;
}

/// Family-wide web settings. Keys: `safe_search` ('enforced' | 'off'),
/// `blocked_page_behavior` ('explain' | 'silent'),
/// `exception_requests_allowed` ('on' | 'off').
class WebSetting {
  const WebSetting({required this.key, required this.value});
  final String key;
  final String value;
}

SyncState _syncStateOf(String? raw) =>
    raw == null ? SyncState.localOnly : SyncState.values.byName(raw);

class WebFilterRepository {
  WebFilterRepository(this._database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final GuardianDatabase _database;
  final Uuid _uuid;

  /// Exposed for the remote sync applier: merging verified server facts
  /// into the local store is an honest write, never a fabrication.
  GuardianDatabase get database => _database;

  // ── Hits (block history) ────────────────────────────────────────────────

  Future<List<WebBlockHit>> hitsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('web_hits',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'blocked_at DESC');
    return rows.map(WebBlockHit.fromMap).toList();
  }

  Future<List<WebBlockHit>> hitsForDay(
      String familyId, DateTime day) async {
    final db = await _database.database;
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query('web_hits',
        where:
            'family_id = ? AND blocked_at >= ? AND blocked_at < ?',
        whereArgs: [familyId, start.toIso8601String(), end.toIso8601String()],
        orderBy: 'blocked_at DESC');
    return rows.map(WebBlockHit.fromMap).toList();
  }

  Future<WebBlockHit?> hitById(String hitId) async {
    final db = await _database.database;
    final rows = await db.query('web_hits',
        where: 'id = ?', whereArgs: [hitId]);
    if (rows.isEmpty) return null;
    return WebBlockHit.fromMap(rows.first);
  }

  /// Records one observed block event. Decision and outbox behavior mirror
  /// the honest contract: the child device observed the block locally; the
  /// parent app presents it, and sync proceeds when connectivity returns.
  Future<WebBlockHit> recordHit({
    required String familyId,
    required String childId,
    required String childDisplayName,
    required String domain,
    required String category,
    required DateTime blockedAt,
    String decision = 'blocked',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('web_hits', {
        'id': id,
        'family_id': familyId,
        'child_id': childId,
        'child_display_name': childDisplayName,
        'domain': domain.trim().toLowerCase(),
        'category': category,
        'blocked_at': blockedAt.toUtc().toIso8601String(),
        'decision': decision,
        'sync_state': SyncState.queued.name,
        'overridden_by': null,
        'created_at': now.toIso8601String(),
      });
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': id,
        'operation': 'web.hit',
        'payload_json': jsonEncode({
          'family_id': familyId,
          'hitId': id,
          'childId': childId,
          'childDisplayName': childDisplayName,
          'domain': domain.trim().toLowerCase(),
          'category': category,
          'blockedAt': blockedAt.toUtc().toIso8601String(),
          'decision': decision,
          'recordedAt': now.toIso8601String(),
        }),
        'idempotency_key': 'web.hit:$id',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
    return WebBlockHit(
        id: id,
        familyId: familyId,
        childId: childId,
        childDisplayName: childDisplayName,
        domain: domain.trim().toLowerCase(),
        category: category,
        blockedAt: blockedAt.toUtc(),
        decision: decision,
        syncState: SyncState.queued);
  }

  // ── Domains (blocklist + allowlist) ─────────────────────────────────────

  Future<List<WebDomainEntry>> domainsForFamily(String familyId,
      {String? kind}) async {
    final db = await _database.database;
    final rows = await db.query('web_domains',
        where: kind == null
            ? 'family_id = ?'
            : 'family_id = ? AND kind = ?',
        whereArgs: kind == null ? [familyId] : [familyId, kind],
        orderBy: 'created_at DESC');
    return rows.map(WebDomainEntry.fromMap).toList();
  }

  Future<WebDomainEntry> addDomain({
    required String familyId,
    required String domain,
    required String kind,
    String? reason,
  }) async {
    if (domain.trim().isEmpty) {
      throw ArgumentError('Domain cannot be empty.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final entry = WebDomainEntry(
        id: id,
        familyId: familyId,
        domain: domain.trim().toLowerCase(),
        kind: kind,
        enabled: true,
        createdAt: now,
        reason: reason,
        syncState: SyncState.localOnly);
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('web_domains', {
        'id': id,
        'family_id': familyId,
        'domain': entry.domain,
        'kind': kind,
        'reason': reason,
        'enabled': 1,
        'sync_state': SyncState.queued.name,
        'created_at': now.toIso8601String(),
      });
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': id,
        'operation': 'web.domain',
        'payload_json': jsonEncode({
          'family_id': familyId,
          'domainId': id,
          'domain': entry.domain,
          'kind': kind,
          'reason': reason,
          'createdAt': now.toIso8601String(),
        }),
        'idempotency_key': 'web.domain:$id',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
    return entry;
  }

  Future<void> removeDomain(String entryId) async {
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.delete('web_domains', where: 'id = ?', whereArgs: [entryId]);
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': entryId,
        'operation': 'web.domain.removal',
        'payload_json': jsonEncode({
          'domainId': entryId,
          'removedAt': now.toIso8601String(),
        }),
        'idempotency_key': 'web.domain.removal:$entryId',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
  }

  Future<void> setDomainEnabled(String entryId, bool enabled) async {
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.update('web_domains', {'enabled': enabled ? 1 : 0},
          where: 'id = ?', whereArgs: [entryId]);
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': entryId,
        'operation': 'web.domain.updated',
        'payload_json': jsonEncode({
          'domainId': entryId,
          'enabled': enabled,
          'updatedAt': now.toIso8601String(),
        }),
        'idempotency_key':
            'web.domain.updated:$entryId:${now.millisecondsSinceEpoch}',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
  }

  // ── Category rules (per child) ──────────────────────────────────────────

  /// Resolves rules for a family, filling defaults: every known child
  /// (from family_members) × every known category gets a rule row lazily.
  /// A missing row is interpreted honestly as the policy-engine default:
  /// category enabled for every child.
  Future<List<WebCategoryRule>> rulesForFamily(String familyId,
      {required Iterable<String> children,
      required Iterable<String> categories}) async {
    final db = await _database.database;
    final rows = await db.query('web_category_rules',
        where: 'family_id = ?', whereArgs: [familyId]);
    final byKey = <String, Map<String, Object?>>{};
    for (final row in rows) {
      byKey['${row['child_id']}:${row['category']}'] = row;
    }
    final rules = <WebCategoryRule>[];
    for (final child in children) {
      for (final category in categories) {
        final row = byKey['$child:$category'];
        if (row == null) {
          rules.add(WebCategoryRule(
              familyId: familyId,
              childId: child,
              childDisplayName: child,
              category: category,
              enabled: true,
              syncState: SyncState.localOnly));
        } else {
          rules.add(WebCategoryRule(
              familyId: familyId,
              childId: child,
              childDisplayName:
                  (row['child_display_name'] as String?) ?? child,
              category: row['category']! as String,
              enabled: (row['enabled'] as int) == 1,
              syncState:
                  _syncStateOf(row['sync_state'] as String?)));
        }
      }
    }
    return rules;
  }

  Future<void> setCategoryRule({
    required String familyId,
    required String childId,
    required String childDisplayName,
    required String category,
    required bool enabled,
  }) async {
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    await db.transaction((tx) async {
      final existing = await tx.query('web_category_rules',
          where: 'family_id = ? AND child_id = ? AND category = ?',
          whereArgs: [familyId, childId, category]);
      if (existing.isEmpty) {
        await tx.insert('web_category_rules', {
          'family_id': familyId,
          'child_id': childId,
          'child_display_name': childDisplayName,
          'category': category,
          'enabled': enabled ? 1 : 0,
          'sync_state': SyncState.queued.name,
          'updated_at': now.toIso8601String(),
        });
      } else {
        await tx.update('web_category_rules',
            {'enabled': enabled ? 1 : 0, 'sync_state': SyncState.queued.name},
            where: 'id = ?',
            whereArgs: [existing.first['id']]);
      }
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': '$childId:$category',
        'operation': 'web.category',
        'payload_json': jsonEncode({
          'family_id': familyId,
          'ruleId': '$childId:$category',
          'childId': childId,
          'childDisplayName': childDisplayName,
          'category': category,
          'enabled': enabled,
          'updatedAt': now.toIso8601String(),
        }),
        'idempotency_key':
            'web.category:$familyId:$childId:$category:${now.millisecondsSinceEpoch}',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
  }

  // ── Settings ────────────────────────────────────────────────────────────

  Future<List<WebSetting>> settingsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('web_settings',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows
        .map((row) =>
            WebSetting(key: row['key']! as String, value: row['value']! as String))
        .toList();
  }

  String setting(List<WebSetting> settings, String key, String fallback) {
    for (final setting in settings) {
      if (setting.key == key) return setting.value;
    }
    return fallback;
  }

  Future<void> setSetting({
    required String familyId,
    required String key,
    required String value,
  }) async {
    final db = await _database.database;
    final existing = await db.query('web_settings',
        where: 'family_id = ? AND key = ?',
        whereArgs: [familyId, key]);
    final now = DateTime.now().toUtc();
    if (existing.isEmpty) {
      await db.insert('web_settings',
          {'family_id': familyId, 'key': key, 'value': value});
    } else {
      await db.update('web_settings', {'value': value},
          where: 'family_id = ? AND key = ?',
          whereArgs: [familyId, key]);
    }
    await db.insert('outbox', {
      'id': _uuid.v4(),
      'aggregate_type': 'web',
      'aggregate_id': key,
      'operation': 'web.setting',
      'payload_json': jsonEncode({
        'key': key,
        'value': value,
        'updatedAt': now.toIso8601String(),
      }),
      'idempotency_key': 'web.setting:$familyId:$key:${now.millisecondsSinceEpoch}',
      'state': 'pending',
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    });
  }

  /// Honesty-driven override stamp with real sync: the parent's
  /// temporary-allow decision is a remote-visible mutation, never local-only.
  Future<void> markOverridden(String hitId, String overriddenBy) async {
    final now = DateTime.now().toUtc();
    final db = await _database.database;
    final hit = await hitById(hitId);
    if (hit == null) return;
    await db.transaction((tx) async {
      await tx.update('web_hits', {'overridden_by': overriddenBy},
          where: 'id = ?', whereArgs: [hitId]);
      await tx.insert('outbox', {
        'id': _uuid.v4(),
        'aggregate_type': 'web',
        'aggregate_id': hitId,
        'operation': 'web.hit.overridden',
        'payload_json': jsonEncode({
          'hitId': hitId,
          'overriddenBy': overriddenBy,
          'overriddenAt': now.toIso8601String(),
        }),
        'idempotency_key': 'web.hit.overridden:$hitId',
        'state': 'pending',
        'attempt_count': 0,
        'next_attempt_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });
    });
  }

  /// Convenience: how many hits with decision=blocked occurred for the
  /// family on a given local day. The honest "Blocked Today" number.
  Future<int> blockedCountForDay(String familyId, DateTime day) async {
    final db = await _database.database;
    final start = DateTime.utc(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM web_hits WHERE family_id = ? '
        'AND decision = ? AND blocked_at >= ? AND blocked_at < ?',
        [familyId, 'blocked', start.toIso8601String(), end.toIso8601String()]);
    return (rows.first['n'] as int? ?? 0);
  }

  Future<void> deleteHitsForFamily(String familyId) async {
    final db = await _database.database;
    await db.delete('web_hits', where: 'family_id = ?', whereArgs: [familyId]);
  }
}
