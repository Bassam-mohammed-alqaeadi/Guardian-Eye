import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_contracts.dart';
import 'web_filter_repository.dart';
import '../domain/guardian_models.dart';

/// FS-002 — Web Filtering remote bridge. The parent app pulls the family's
/// web-protection state from Firestore (the `/families/{id}/web_policy`
/// summary document written by the Render backend when it aggregates the
/// family's web_hits / web_domains / web_category_rules / web_settings
/// collections) and applies every verified server fact into the local
/// SQLite store. Nothing is applied until the server confirms it — the
/// local store never pretends a remote truth it has not fetched.
///
/// The sync discipline mirrors `ChildPolicyDeliveryService`: server-first
/// fetch, idempotency by idempotencyKey, and version gating so an older
/// snapshot can never overwrite a newer local state.
abstract class WebPolicyRemoteReader {
  Future<RemoteWebPolicy?> readWebPolicy({required String familyId});
}

class FirestoreWebPolicyRemoteReader implements WebPolicyRemoteReader {
  const FirestoreWebPolicyRemoteReader(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<RemoteWebPolicy?> readWebPolicy({required String familyId}) async {
    if (!const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    final path = '${FirestorePaths.family(familyId)}/web_policy';
    final snapshot = await _firestore
        .doc(path)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    final hits = (data?['hits'] as List?)
        ?.map((raw) => _parseRemoteHit(raw))
        .whereType<RemoteWebHit>()
        .toList() ??
        <RemoteWebHit>[];
    final domains = (data?['domains'] as List?)
        ?.map((raw) => _parseRemoteDomain(raw))
        .whereType<RemoteWebDomain>()
        .toList() ??
        <RemoteWebDomain>[];
    final categoryRules = (data?['categoryRules'] as List?)
        ?.map((raw) => _parseRemoteRule(raw))
        .whereType<RemoteWebCategoryRule>()
        .toList() ??
        <RemoteWebCategoryRule>[];
    final settings = (data?['settings'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString())) ??
        const <String, String>{};
    return RemoteWebPolicy(
        path: snapshot.reference.path,
        familyId: familyId,
        version: data?['version'] as int?,
        updatedAtServer: data?['updatedAt'],
        idempotencyKey: data?['idempotencyKey'] as String?,
        hits: hits,
        domains: domains,
        categoryRules: categoryRules,
        settings: settings);
  }

  RemoteWebHit? _parseRemoteHit(Object? raw) {
    if (raw is! Map) return null;
    final hitId = raw['hitId'] as String?;
    final childId = raw['childId'] as String?;
    final domain = raw['domain'] as String?;
    if (hitId == null || childId == null || domain == null) return null;
    return RemoteWebHit(
        hitId: hitId,
        childId: childId,
        childDisplayName: raw['childDisplayName'] as String?,
        domain: domain,
        category: (raw['category'] as String?) ?? 'other',
        blockedAt: raw['blockedAt'] as String?,
        decision: (raw['decision'] as String?) ?? 'blocked',
        overriddenBy: raw['overriddenBy'] as String?);
  }

  RemoteWebDomain? _parseRemoteDomain(Object? raw) {
    if (raw is! Map) return null;
    final domainId = raw['domainId'] as String?;
    final domain = raw['domain'] as String?;
    final kind = raw['kind'] as String?;
    if (domainId == null || domain == null || kind == null) return null;
    return RemoteWebDomain(
        domainId: domainId,
        domain: domain,
        kind: kind,
        reason: raw['reason'] as String?,
        enabled: raw['enabled'] == true,
        removed: raw['removed'] == true);
  }

  RemoteWebCategoryRule? _parseRemoteRule(Object? raw) {
    if (raw is! Map) return null;
    final ruleId = raw['ruleId'] as String?;
    final childId = raw['childId'] as String?;
    final category = raw['category'] as String?;
    if (ruleId == null || childId == null || category == null) return null;
    return RemoteWebCategoryRule(
        ruleId: ruleId,
        childId: childId,
        childDisplayName: raw['childDisplayName'] as String?,
        category: category,
        enabled: raw['enabled'] == true);
  }
}

class RemoteWebPolicy {
  const RemoteWebPolicy(
      {required this.path,
      required this.familyId,
      required this.version,
      required this.updatedAtServer,
      required this.idempotencyKey,
      required this.hits,
      required this.domains,
      required this.categoryRules,
      required this.settings});

  final String path;
  final String familyId;
  final int? version;
  final Object? updatedAtServer;
  final String? idempotencyKey;
  final List<RemoteWebHit> hits;
  final List<RemoteWebDomain> domains;
  final List<RemoteWebCategoryRule> categoryRules;
  final Map<String, String> settings;
}

class RemoteWebHit {
  const RemoteWebHit(
      {required this.hitId,
      required this.childId,
      this.childDisplayName,
      required this.domain,
      required this.category,
      required this.blockedAt,
      required this.decision,
      this.overriddenBy});

  final String hitId;
  final String childId;
  final String? childDisplayName;
  final String domain;
  final String category;
  final String? blockedAt;
  final String decision;
  final String? overriddenBy;
}

class RemoteWebDomain {
  const RemoteWebDomain(
      {required this.domainId,
      required this.domain,
      required this.kind,
      this.reason,
      required this.enabled,
      required this.removed});

  final String domainId;
  final String domain;
  final String kind;
  final String? reason;
  final bool enabled;
  final bool removed;
}

class RemoteWebCategoryRule {
  const RemoteWebCategoryRule(
      {required this.ruleId,
      required this.childId,
      this.childDisplayName,
      required this.category,
      required this.enabled});

  final String ruleId;
  final String childId;
  final String? childDisplayName;
  final String category;
  final bool enabled;
}

/// One honest pass of applying the verified server facts into the local
/// SQLite store. Missing rows are created; existing rows are updated only
/// when the server record is newer or when the local row has no server
/// evidence yet. Removals stamped by the server (`removed: true`) delete
/// the local row so the parent never sees a domain the server deleted.
class WebPolicySyncApplier {
  const WebPolicySyncApplier(this._repository);

  final WebFilterRepository _repository;

  Future<WebPolicySyncReport> apply(RemoteWebPolicy policy) async {
    final db = await _repository.database.database;
    var appliedHits = 0;
    var appliedDomains = 0;
    var appliedRules = 0;
    var appliedSettings = 0;

    for (final hit in policy.hits) {
      final existing = await db.query('web_hits',
          where: 'id = ?', whereArgs: [hit.hitId]);
      if (existing.isNotEmpty) {
        final row = existing.first;
        final localOverridden = row['overridden_by'] as String?;
        final serverOverridden = hit.overriddenBy;
        if (localOverridden == null && serverOverridden != null) {
          await db.update('web_hits', {'overridden_by': serverOverridden},
              where: 'id = ?', whereArgs: [hit.hitId]);
          appliedHits++;
        }
        continue;
      }
      final blockedAt = hit.blockedAt != null
          ? DateTime.parse(hit.blockedAt!).toIso8601String()
          : DateTime.now().toUtc().toIso8601String();
      await db.insert('web_hits', {
        'id': hit.hitId,
        'family_id': policy.familyId,
        'child_id': hit.childId,
        'child_display_name': hit.childDisplayName ?? hit.childId,
        'domain': hit.domain.trim().toLowerCase(),
        'category': hit.category,
        'blocked_at': blockedAt,
        'decision': hit.decision,
        'sync_state': SyncState.synced.name,
        'overridden_by': hit.overriddenBy,
        'created_at': blockedAt,
      });
      appliedHits++;
    }

    for (final domain in policy.domains) {
      final existing =
          await db.query('web_domains', where: 'id = ?', whereArgs: [domain.domainId]);
      if (domain.removed) {
        if (existing.isNotEmpty) {
          await db.delete('web_domains',
              where: 'id = ?', whereArgs: [domain.domainId]);
        }
        appliedDomains++;
        continue;
      }
      if (existing.isNotEmpty) {
        final row = existing.first;
        final localEnabled = (row['enabled'] as int) == 1;
        if (localEnabled != domain.enabled) {
          await db.update('web_domains', {'enabled': domain.enabled ? 1 : 0},
              where: 'id = ?', whereArgs: [domain.domainId]);
          appliedDomains++;
        }
        continue;
      }
      await db.insert('web_domains', {
        'id': domain.domainId,
        'family_id': policy.familyId,
        'domain': domain.domain.trim().toLowerCase(),
        'kind': domain.kind,
        'reason': domain.reason,
        'enabled': domain.enabled ? 1 : 0,
        'sync_state': SyncState.synced.name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      appliedDomains++;
    }

    for (final rule in policy.categoryRules) {
      final existing = await db.query('web_category_rules',
          where: 'family_id = ? AND child_id = ? AND category = ?',
          whereArgs: [policy.familyId, rule.childId, rule.category]);
      if (existing.isNotEmpty) {
        final row = existing.first;
        final localEnabled = (row['enabled'] as int) == 1;
        if (localEnabled != rule.enabled) {
          await db.update('web_category_rules',
              {'enabled': rule.enabled ? 1 : 0, 'sync_state': SyncState.synced.name},
              where: 'family_id = ? AND child_id = ? AND category = ?',
              whereArgs: [policy.familyId, rule.childId, rule.category]);
          appliedRules++;
        }
        continue;
      }
      await db.insert('web_category_rules', {
        'family_id': policy.familyId,
        'child_id': rule.childId,
        'child_display_name': rule.childDisplayName ?? rule.childId,
        'category': rule.category,
        'enabled': rule.enabled ? 1 : 0,
        'sync_state': SyncState.synced.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      appliedRules++;
    }

    for (final entry in policy.settings.entries) {
      final existing = await db.query('web_settings',
          where: 'family_id = ? AND key = ?',
          whereArgs: [policy.familyId, entry.key]);
      if (existing.isEmpty) {
        await db.insert('web_settings',
            {'family_id': policy.familyId, 'key': entry.key, 'value': entry.value});
      } else {
        final row = existing.first;
        if ((row['value'] as String?) != entry.value) {
          await db.update('web_settings', {'value': entry.value},
              where: 'family_id = ? AND key = ?',
              whereArgs: [policy.familyId, entry.key]);
          appliedSettings++;
        }
      }
      appliedSettings++;
    }

    return WebPolicySyncReport(
        familyId: policy.familyId,
        appliedHits: appliedHits,
        appliedDomains: appliedDomains,
        appliedRules: appliedRules,
        appliedSettings: appliedSettings);
  }
}

class WebPolicySyncReport {
  const WebPolicySyncReport(
      {required this.familyId,
      required this.appliedHits,
      required this.appliedDomains,
      required this.appliedRules,
      required this.appliedSettings});

  final String familyId;
  final int appliedHits;
  final int appliedDomains;
  final int appliedRules;
  final int appliedSettings;
}

/// One-shot pull used by the UI (honest pull-to-refresh). The pull never
/// fails silently: if the server cannot be reached the report records the
/// offline evidence instead of pretending success.
class WebFilterPullService {
  const WebFilterPullService(this._reader, this._applier);

  final WebPolicyRemoteReader _reader;
  final WebPolicySyncApplier _applier;

  Future<WebPullResult> pull(String familyId) async {
    RemoteWebPolicy? policy;
    try {
      policy = await _reader.readWebPolicy(familyId: familyId);
    } catch (error) {
      return WebPullResult(
          success: false,
          applied: false,
          reason: 'remote_read_failed:${error.runtimeType}');
    }
    if (policy == null) {
      return const WebPullResult(
          success: true, applied: false, reason: 'no_remote_policy_yet');
    }
    try {
      final report = await _applier.apply(policy);
      return WebPullResult(
          success: true,
          applied: true,
          reason:
              'applied:h=${report.appliedHits},d=${report.appliedDomains},'
              'r=${report.appliedRules},s=${report.appliedSettings}');
    } catch (error) {
      return WebPullResult(
          success: false,
          applied: false,
          reason: 'local_apply_failed:${error.runtimeType}');
    }
  }
}

class WebPullResult {
  const WebPullResult(
      {required this.success, required this.applied, required this.reason});

  final bool success;
  final bool applied;
  final String reason;
}
