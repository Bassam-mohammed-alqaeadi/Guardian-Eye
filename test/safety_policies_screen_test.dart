import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/presentation/screens/safety_policies_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PolicyRepositoryFake extends PolicyRepository {
  _PolicyRepositoryFake(this._policy)
      : super(GuardianDatabase.forTesting(
            factory: databaseFactoryFfi,
            pathResolver: () async => inMemoryDatabasePath));

  DigitalPolicy _policy;
  bool setEnabledCalled = false;

  @override
  Future<List<DigitalPolicy>> forFamily(String familyId) async => [_policy];

  @override
  Future<List<StoredPolicyOverride>> overridesForFamily(
          String familyId) async =>
      const [];

  @override
  Future<DigitalPolicy> setEnabled(
      {required DigitalPolicy existing, required bool enabled}) async {
    setEnabledCalled = true;
    _policy = DigitalPolicy(
        id: existing.id,
        familyId: existing.familyId,
        name: existing.name,
        priority: existing.priority,
        enabled: enabled,
        startMinute: existing.startMinute,
        endMinute: existing.endMinute,
        restrictedTargets: existing.restrictedTargets,
        version: existing.version + 1,
        syncState: SyncState.queued);
    return _policy;
  }
}

void main() {
  testWidgets('policy manager renders stored policy and toggles its real state',
      (tester) async {
    final policies = _PolicyRepositoryFake(const DigitalPolicy(
        id: 'policy-1',
        familyId: 'family-1',
        name: 'Bedtime',
        priority: 50,
        enabled: true,
        startMinute: 1260,
        endMinute: 420,
        restrictedTargets: {'video'},
        syncState: SyncState.queued));

    await tester.pumpWidget(ProviderScope(
        overrides: [policyRepositoryProvider.overrideWithValue(policies)],
        child: const MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: [Locale('ar'), Locale('en')],
            home: SafetyPoliciesScreen(familyId: 'family-1'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.textContaining('بانتظار المزامنة'), findsOneWidget);
    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    final scrollableFinder = find.ancestor(
        of: toggle, matching: find.byType(Scrollable));
    expect(scrollableFinder, findsOneWidget);
    await tester.scrollUntilVisible(toggle, 200.0);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(policies.setEnabledCalled, isTrue);
    expect((await policies.forFamily('family-1')).single.enabled, isFalse);
  });
}
