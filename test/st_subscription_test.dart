// ST — Subscription & Entitlements paywall — honest-state checks against
// the real v28 SQLite schema: entitlement round-trips have NO fabricated id
// field; usage meters persist the keyword-safe limit_ column; feature gates
// return exactly what was granted (never inferred from a plan name); and
// billing records are audit-only history.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/subscription_repository.dart';
import 'package:guardian_ai/domain/subscription_entitlements.dart';

Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('st-db-');
  final database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => '${dir.path}/db.sqlite');
  await database.initialize();
  return database;
}

Future<void> seedFamily(GuardianDatabase database) async {
  final db = await database.database;
  final now = DateTime.utc(2025, 7, 1);
  await db.insert('families', {
    'id': 'family-st',
    'name': 'Subscription Family',
    'created_at': now.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-st',
    'family_id': 'family-st',
    'display_name': 'Parent',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': now.toIso8601String(),
  });
}

void main() {
  group('Entitlement model', () {
    test('round-trip preserves every field with no id column', () {
      final now = DateTime.utc(2025, 7, 1);
      final entitlement = Entitlement(
        familyId: 'family-st',
        feature: EntitlementFeature.aiInsights,
        granted: true,
        policyKey: 'plan_plus',
        grantedAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      );
      final json = entitlement.toJson();
      expect(json.containsKey('id'), false);
      final restored = Entitlement.fromJson(json);
      expect(restored.familyId, 'family-st');
      expect(restored.granted, true);
      expect(restored.policyKey, 'plan_plus');
      expect(restored.expiresAt, now.add(const Duration(days: 30)));
    });

    test('not-granted entitlement fails the feature gate', () {
      final entitlement = Entitlement(
        familyId: 'family-st',
        feature: EntitlementFeature.coupleHarmony,
        granted: false,
        policyKey: 'plan_free',
      );
      expect(entitlement.granted, false);
    });
  });

  group('UsageMeter model', () {
    test('fromJson reads the keyword-safe limit_ column', () {
      final meter = UsageMeter.fromJson({
        'family_id': 'family-st',
        'feature': EntitlementFeature.unlimitedChildren,
        'used': 2,
        'limit_': 4,
        'period_start': DateTime.utc(2025, 7, 1).toIso8601String(),
        'period_end': DateTime.utc(2025, 7, 31).toIso8601String(),
      });
      expect(meter.used, 2);
      expect(meter.limit, 4);
    });

    test('fromJson prefers the keyword-safe limit_ over legacy limit', () {
      final meter = UsageMeter.fromJson({
        'family_id': 'family-st',
        'feature': EntitlementFeature.unlimitedChildren,
        'used': 5,
        'limit_': 7,
        'limit': 3,
        'period_start': DateTime.utc(2025, 7, 1).toIso8601String(),
        'period_end': DateTime.utc(2025, 7, 31).toIso8601String(),
      });
      expect(meter.limit, 7);
      expect(meter.toJson()['limit_'], 7);
    });
  });

  group('SubscriptionRepository round-trips', () {
    late GuardianDatabase database;
    late SubscriptionRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await seedFamily(database);
      repo = SubscriptionRepository(database: database);
    });

    test('entitlements persist and the feature gate reads them exactly',
        () async {
      await repo.setEntitlement(Entitlement(
        familyId: 'family-st',
        feature: EntitlementFeature.aiInsights,
        granted: true,
        policyKey: 'plan_plus',
        grantedAt: DateTime.utc(2025, 7, 1),
      ));
      await repo.setEntitlement(Entitlement(
        familyId: 'family-st',
        feature: EntitlementFeature.coupleHarmony,
        granted: false,
        policyKey: 'plan_free',
      ));
      expect(
          await repo.isFeatureGranted(
              'family-st', EntitlementFeature.aiInsights),
          true);
      expect(
          await repo.isFeatureGranted(
              'family-st', EntitlementFeature.coupleHarmony),
          false);
      expect((await repo.listEntitlements('family-st')).length, 2);
    });

    test('usage meters round-trip with the limit_ column', () async {
      await repo.recordMeter(UsageMeter(
        familyId: 'family-st',
        feature: EntitlementFeature.unlimitedChildren,
        used: 3,
        limit: 5,
        periodStart: DateTime.utc(2025, 7, 1),
        periodEnd: DateTime.utc(2025, 7, 31),
      ));
      final meters = await repo.listMeters('family-st');
      expect(meters.length, 1);
      expect(meters.first.used, 3);
      expect(meters.first.limit, 5);
    });

    test('billing records are append-only audit history', () async {
      await repo.recordBilling(BillingRecord(
        id: 'bill-1',
        familyId: 'family-st',
        kind: 'tier_change',
        amountMinorUnits: 0,
        currency: 'USD',
        status: 'succeeded',
        createdAt: DateTime.utc(2025, 7, 1),
      ));
      await repo.recordBilling(BillingRecord(
        id: 'bill-2',
        familyId: 'family-st',
        kind: 'tier_change',
        amountMinorUnits: 0,
        currency: 'USD',
        status: 'succeeded',
        createdAt: DateTime.utc(2025, 7, 2),
      ));
      final records = await repo.listBilling('family-st');
      expect(records.length, 2);
      // Descending audit order: newest record first.
      expect(records.first.createdAt, DateTime.utc(2025, 7, 2));
      expect(records.last.createdAt, DateTime.utc(2025, 7, 1));
    });

    test('unrelated families never see each other data', () async {
      await repo.setEntitlement(Entitlement(
        familyId: 'family-st',
        feature: EntitlementFeature.reportsPdfExport,
        granted: true,
        policyKey: 'plan_plus',
      ));
      expect(
          await repo.isFeatureGranted(
              'other-family', EntitlementFeature.reportsPdfExport),
          false);
      expect((await repo.listEntitlements('other-family')).length, 0);
    });
  });
}
