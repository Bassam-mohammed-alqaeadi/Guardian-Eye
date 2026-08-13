import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/core/platform/android_enforcement_adapter.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/core/platform/capability_gateway.dart';
import 'package:guardian_ai/presentation/screens/child_device_status_screen.dart';

void main() {
  test('Android adapter never claims an unimplemented app block was applied',
      () {
    final decision = EnforcementDecision(
        outcome: EnforcementOutcome.restrict,
        reason: 'policy_match',
        evaluatedAt: DateTime.utc(2026, 8, 12, 22));
    final result = const AndroidEnforcementAdapter().apply(decision);
    expect(result.status, AndroidApplicationStatus.unsupported);
    expect(result.reason, 'android_app_blocking_not_implemented');
  });

  testWidgets(
      'child device status shows real supplied state and enforcement boundary',
      (tester) async {
    final state = ChildDeviceState(
        deviceId: 'device-1',
        familyId: 'family-1',
        memberId: 'child-1',
        lifecycle: ChildDeviceLifecycle.restricted,
        requiredPolicyVersion: 5,
        updatedAt: DateTime.utc(2026, 8, 12, 22),
        lastValidPolicyAt: DateTime.utc(2026, 8, 12, 21),
        lastDecision: EnforcementOutcome.restrict);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          childDeviceStatesProvider('family-1')
              .overrideWith((ref) async => [state]),
          childUsageForTodayProvider('device-1')
              .overrideWith((ref) async => const []),
          capabilityStatusProvider.overrideWith((ref) async => const [
                CapabilityStatus(
                    capability: GuardianCapability.usageStats,
                    granted: false,
                    supported: true,
                    requiresSettings: true)
              ])
        ],
        child: const MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: [Locale('ar'), Locale('en')],
            home: ChildDeviceStatusScreen(familyId: 'family-1'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('حالة جهاز الطفل'), findsOneWidget);
    expect(find.text('طلبت السياسة تقييدًا'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('لا تمثل دليلاً'), findsOneWidget);
    expect(find.textContaining('يلزم منح الوصول'), findsOneWidget);
  });
}
