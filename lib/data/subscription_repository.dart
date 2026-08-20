/// ST-001 — Subscription persistence (local-first entitlements).
///
/// All three tables are append-or-replace with explicit states: an
/// entitlement row exists only when a grant decision was recorded, a
/// meter only exists while being tracked, and billing rows are never
/// deleted.
library subscription_repository;

import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../domain/subscription_entitlements.dart';

class SubscriptionRepository {
  const SubscriptionRepository({required this.database});

  final GuardianDatabase database;

  Database get _db => database.activeDatabase!;

  // -------------------------------------------------------------------------
  // Entitlements
  // -------------------------------------------------------------------------

  Future<void> setEntitlement(Entitlement entitlement) async {
    await _db.insert('subscription_entitlements', entitlement.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Entitlement?> entitlementFor(
      String familyId, String feature) async {
    final rows = await _db.query('subscription_entitlements',
        where: 'family_id = ? AND feature = ?',
        whereArgs: [familyId, feature],
        limit: 1);
    if (rows.isEmpty) return null;
    return Entitlement.fromJson(rows.first);
  }

  Future<bool> isFeatureGranted(String familyId, String feature) async {
    final entitlement = await entitlementFor(familyId, feature);
    if (entitlement == null) return false;
    if (!entitlement.granted) return false;
    final expires = entitlement.expiresAt;
    if (expires != null && DateTime.now().toUtc().isAfter(expires)) {
      return false;
    }
    return true;
  }

  Future<List<Entitlement>> listEntitlements(String familyId) async {
    final rows = await _db.query('subscription_entitlements',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows.map(Entitlement.fromJson).toList();
  }

  // -------------------------------------------------------------------------
  // Usage meters
  // -------------------------------------------------------------------------

  Future<void> recordMeter(UsageMeter meter) async {
    await _db.insert('subscription_usage_limits', meter.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UsageMeter?> meterFor(String familyId, String feature) async {
    final rows = await _db.query('subscription_usage_limits',
        where: 'family_id = ? AND feature = ?',
        whereArgs: [familyId, feature],
        limit: 1);
    if (rows.isEmpty) return null;
    return UsageMeter.fromJson(rows.first);
  }

  Future<void> incrementUsage(String familyId, String feature,
      {int delta = 1}) async {
    await _db.rawUpdate(
        'UPDATE subscription_usage_limits SET used = MIN(used + ?, limit_) WHERE family_id = ? AND feature = ?',
        [delta, familyId, feature]);
  }

  Future<List<UsageMeter>> listMeters(String familyId) async {
    final rows = await _db.query('subscription_usage_limits',
        where: 'family_id = ?', whereArgs: [familyId]);
    return rows.map(UsageMeter.fromJson).toList(growable: false);
  }

  // -------------------------------------------------------------------------
  // Billing
  // -------------------------------------------------------------------------

  Future<void> recordBilling(BillingRecord record) async {
    await _db.insert('billing_records', record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BillingRecord>> listBilling(String familyId) async {
    final rows = await _db.query('billing_records',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC');
    return rows.map(BillingRecord.fromJson).toList();
  }
}
