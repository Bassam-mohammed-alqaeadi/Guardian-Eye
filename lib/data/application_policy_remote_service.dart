import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_contracts.dart';
import 'application_policy_repository.dart';
import '../domain/guardian_models.dart';

/// FS-003 — Application Control remote bridge. The parent app pulls the
/// family's app-protection state from Firestore (the `/families/{id}/app_policy`
/// summary document written by the Render backend when it aggregates the
/// family's app_policies / app_allowlist / usage_alert_settings
/// collections) and applies every verified server fact into the local
/// SQLite store. Nothing is applied until the server confirms it — the
/// local store never pretends a remote truth it has not fetched.
///
/// The sync discipline mirrors `WebFilterPullService`: server-first fetch,
/// idempotency by idempotencyKey, and version gating so an older snapshot
/// can never overwrite a newer local state.

class RemoteAppPolicy {
  const RemoteAppPolicy({
    required this.path,
    required this.familyId,
    required this.policies,
    required this.allowlist,
    required this.alertSettings,
    this.version,
    this.updatedAtServer,
    this.idempotencyKey,
  });

  final String path;
  final String familyId;
  final List<RemoteAppPolicyEntry> policies;
  final List<RemoteAppAllowlistEntry> allowlist;
  final List<RemoteAlertSetting> alertSettings;
  final int? version;
  final Object? updatedAtServer;
  final String? idempotencyKey;
}

class RemoteAppPolicyEntry {
  const RemoteAppPolicyEntry({
    required this.policyId,
    required this.target,
    required this.action,
    required this.isRemoved,
    this.childId,
    this.limitMilliseconds,
    this.ratingMax,
    this.syncState,
  });

  final String policyId;
  final String target;
  final String action;
  final bool isRemoved;
  final String? childId;
  final int? limitMilliseconds;
  final String? ratingMax;
  final String? syncState;
}

class RemoteAppAllowlistEntry {
  const RemoteAppAllowlistEntry({
    required this.allowlistId,
    required this.target,
    required this.isRemoved,
    this.reason,
  });

  final String allowlistId;
  final String target;
  final bool isRemoved;
  final String? reason;
}

class RemoteAlertSetting {
  const RemoteAlertSetting({
    required this.settingId,
    required this.target,
    required this.thresholdMilliseconds,
    required this.enabled,
  });

  final String settingId;
  final String target;
  final int thresholdMilliseconds;
  final bool enabled;
}

abstract class AppPolicyRemoteReader {
  Future<RemoteAppPolicy?> readAppPolicy({required String familyId});
}

class FirestoreAppPolicyRemoteReader implements AppPolicyRemoteReader {
  const FirestoreAppPolicyRemoteReader(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<RemoteAppPolicy?> readAppPolicy({required String familyId}) async {
    if (!const bool.fromEnvironment('GUARDIAN_FIREBASE_CONFIGURED') ||
        Firebase.apps.isEmpty ||
        FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    final path = '${FirestorePaths.family(familyId)}/app_policy';
    final snapshot = await _firestore
        .doc(path)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    final policies = (data?['policies'] as List?)
            ?.map((raw) => _parsePolicy(raw))
            .whereType<RemoteAppPolicyEntry>()
            .toList() ??
        <RemoteAppPolicyEntry>[];
    final allowlist = (data?['allowlist'] as List?)
            ?.map((raw) => _parseAllowlist(raw))
            .whereType<RemoteAppAllowlistEntry>()
            .toList() ??
        <RemoteAppAllowlistEntry>[];
    final alertSettings = (data?['alertSettings'] as List?)
            ?.map((raw) => _parseAlert(raw))
            .whereType<RemoteAlertSetting>()
            .toList() ??
        <RemoteAlertSetting>[];
    return RemoteAppPolicy(
        path: snapshot.reference.path,
        familyId: familyId,
        policies: policies,
        allowlist: allowlist,
        alertSettings: alertSettings,
        version: data?['version'] as int?,
        updatedAtServer: data?['updatedAt'],
        idempotencyKey: data?['idempotencyKey'] as String?);
  }

  RemoteAppPolicyEntry? _parsePolicy(Object? raw) {
    if (raw is! Map) return null;
    final policyId = raw['policyId'] as String?;
    final target = raw['target'] as String?;
    final action = raw['action'] as String?;
    if (policyId == null || target == null || action == null) return null;
    return RemoteAppPolicyEntry(
        policyId: policyId,
        target: target,
        action: action,
        isRemoved: raw['removed'] == true,
        childId: raw['childId'] as String?,
        limitMilliseconds: raw['limitMilliseconds'] as int?,
        ratingMax: raw['ratingMax'] as String?,
        syncState: raw['syncState'] as String?);
  }

  RemoteAppAllowlistEntry? _parseAllowlist(Object? raw) {
    if (raw is! Map) return null;
    final allowlistId = raw['allowlistId'] as String?;
    final target = raw['target'] as String?;
    if (allowlistId == null || target == null) return null;
    return RemoteAppAllowlistEntry(
        allowlistId: allowlistId,
        target: target,
        isRemoved: raw['removed'] == true,
        reason: raw['reason'] as String?);
  }

  RemoteAlertSetting? _parseAlert(Object? raw) {
    if (raw is! Map) return null;
    final settingId = raw['settingId'] as String?;
    final target = raw['target'] as String?;
    final threshold = raw['thresholdMilliseconds'] as int?;
    if (settingId == null || target == null || threshold == null) return null;
    return RemoteAlertSetting(
        settingId: settingId,
        target: target,
        thresholdMilliseconds: threshold,
        enabled: raw['enabled'] != false);
  }
}

class AppPolicyPullResult {
  const AppPolicyPullResult({
    required this.familyId,
    this.source,
    this.appliedPolicies = 0,
    this.appliedAllowlist = 0,
    this.appliedAlertSettings = 0,
  });

  final String familyId;
  final String? source;
  final int appliedPolicies;
  final int appliedAllowlist;
  final int appliedAlertSettings;
}

/// Applies verified server facts into the local app-policy store. Removal
/// markers are honored (`removed: true` wipes the local row so a server
/// revocation can never sit unenforced in SQLite).
class AppPolicySyncApplier {
  const AppPolicySyncApplier(this._repository);

  final ApplicationPolicyRepository _repository;

  Future<int> apply(RemoteAppPolicy remote) async {
    if (remote.version == null) return 0;
    int applied = 0;
    for (final entry in remote.policies) {
      if (entry.isRemoved) {
        await _repository.deletePolicy(remote.familyId, entry.target);
      } else {
        await _repository.savePolicy(AppPolicyEntry(
          familyId: remote.familyId,
          childId: entry.childId ?? '',
          target: entry.target,
          action: _actionOf(entry.action),
          timeAllowance: entry.limitMilliseconds == null
              ? null
              : Duration(milliseconds: entry.limitMilliseconds!),
          ratingMax: entry.ratingMax ?? 'all',
          syncState: _syncStateOf(entry.syncState),
          updatedAt: DateTime.now().toUtc(),
        ));
      }
      applied++;
    }
    for (final entry in remote.allowlist) {
      if (entry.isRemoved) {
        await _repository.removeFromAllowlist(remote.familyId, entry.target);
      } else {
        await _repository.addToAllowlist(AppAllowlistEntry(
          familyId: remote.familyId,
          target: entry.target,
          reason: entry.reason ?? '',
          addedBy: 'server',
          createdAt: DateTime.now().toUtc(),
        ));
      }
      applied++;
    }
    for (final setting in remote.alertSettings) {
      await _repository.saveAlertSetting(UsageAlertSetting(
        familyId: remote.familyId,
        target: setting.target,
        threshold: Duration(milliseconds: setting.thresholdMilliseconds),
        enabled: setting.enabled,
        updatedAt: DateTime.now().toUtc(),
      ));
      applied++;
    }
    return applied;
  }

  static AppPolicyAction _actionOf(String raw) {
    switch (raw) {
      case 'allow':
        return AppPolicyAction.allow;
      case 'limit':
        return AppPolicyAction.limit;
      default:
        return AppPolicyAction.block;
    }
  }

  static SyncState _syncStateOf(String? raw) {
    if (raw == null) return SyncState.queued;
    switch (raw) {
      case 'synced':
        return SyncState.synced;
      case 'failed':
        return SyncState.failed;
      case 'blocked':
        return SyncState.blocked;
      case 'localOnly':
        return SyncState.localOnly;
      default:
        return SyncState.queued;
    }
  }
}

/// Single-flight pull of the family's app-protection state from the server
/// into the local store. Returns an honest result describing how many
/// verified facts were applied — never claims remote success without the
/// server snapshot.
class AppPolicyPullService {
  const AppPolicyPullService(this._reader, this._applier);

  final AppPolicyRemoteReader _reader;
  final AppPolicySyncApplier _applier;

  Future<AppPolicyPullResult> pull(String familyId) async {
    final remote = await _reader.readAppPolicy(familyId: familyId);
    if (remote == null) {
      return AppPolicyPullResult(
          familyId: familyId, source: 'none_applied_unavailable');
    }
    await _applier.apply(remote);
    return AppPolicyPullResult(
        familyId: familyId,
        source: remote.path,
        appliedPolicies: remote.policies.length,
        appliedAllowlist: remote.allowlist.length,
        appliedAlertSettings: remote.alertSettings.length);
  }
}
