import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/core/platform/capability_gateway.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/child_exception_request.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/domain/screen_time.dart';
import 'package:guardian_ai/presentation/screens/family_safety_experience_screens.dart';

ChildExceptionRequest _request(ChildExceptionRequestStatus status) =>
    ChildExceptionRequest(
        id: status.name,
        familyId: 'family-1',
        childDeviceId: 'device-1',
        childMemberId: 'child-1',
        childUid: 'child-uid',
        target: 'com.google.android.youtube',
        requestedDuration: const Duration(minutes: 15),
        reason: ChildExceptionReason.homework,
        createdAt: DateTime.utc(2026, 8, 12, 12),
        requestExpiresAt: DateTime.utc(2026, 8, 13, 12),
        status: status,
        expiresAt: status == ChildExceptionRequestStatus.approved
            ? DateTime.utc(2026, 8, 12, 12, 15)
            : null,
        syncState: SyncState.queued);

Widget _app(Locale locale, List<ChildExceptionRequest> requests) => ProviderScope(
    overrides: [
      familyExceptionRequestsProvider('family-1')
          .overrideWith((ref) async => requests)
    ],
    child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: const ParentExceptionRequestsScreen(familyId: 'family-1')));

void main() {
  testWidgets('Arabic parent review renders truthful request and queued states',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('ar'), [
      _request(ChildExceptionRequestStatus.pending),
      _request(ChildExceptionRequestStatus.approved),
      _request(ChildExceptionRequestStatus.denied),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('بانتظار مراجعة الوالد'), findsOneWidget);
    expect(find.text('تمت الموافقة على الطلب'), findsOneWidget);
    expect(find.text('تم رفض الطلب'), findsOneWidget);
    expect(find.text('بانتظار المزامنة'), findsNWidgets(3));
    expect(find.text('موافقة'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
  });

  testWidgets('Arabic review renders an expired request state', (tester) async {
    await tester.pumpWidget(
        _app(const Locale('ar'), [_request(ChildExceptionRequestStatus.expired)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('انتهت صلاحية الطلب'), findsOneWidget);
  });

  testWidgets('English parent review renders the same request states',
      (tester) async {
    await tester.pumpWidget(
        _app(const Locale('en'), [_request(ChildExceptionRequestStatus.pending)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Awaiting parent review'), findsOneWidget);
    expect(find.text('Queued for sync'), findsOneWidget);
    expect(find.text('Approval creates a temporary policy allowance. It is not evidence that Android blocked or unblocked an app.'), findsOneWidget);
  });

  testWidgets('Arabic child policy experience explains offline local facts without a blocking claim',
      (tester) async {
    final state = ChildDeviceState(
        deviceId: 'device-1',
        familyId: 'family-1',
        memberId: 'child-1',
        lifecycle: ChildDeviceLifecycle.offline,
        requiredPolicyVersion: 1,
        updatedAt: DateTime.utc(2026, 8, 12),
        lastValidPolicyAt: DateTime.utc(2026, 8, 12));
    const policy = DigitalPolicy(
        id: 'policy-1',
        familyId: 'family-1',
        name: 'وقت الفيديو',
        priority: 1,
        enabled: true,
        startMinute: 0,
        endMinute: 0,
        restrictedTargets: {'com.google.android.youtube'},
        dailyLimitMinutes: 30,
        version: 1);
    const scope = (familyId: 'family-1', deviceId: 'device-1', childUid: 'child-uid');
    await tester.pumpWidget(ProviderScope(overrides: [
      childDeviceStatesProvider('family-1').overrideWith((ref) async => [state]),
      deliveredChildPoliciesProvider('device-1').overrideWith((ref) async => [
            DeliveredChildPolicy(
                deviceId: 'device-1', policy: policy, deliveredAt: DateTime.utc(2026, 8, 12))
          ]),
      childUsageForTodayProvider('device-1').overrideWith((ref) async => [
            DailyUsageSummary(
                deviceId: 'device-1', familyId: 'family-1', target: 'com.google.android.youtube',
                dayStart: DateTime.utc(2026, 8, 12), totalMilliseconds: 600000,
                capturedAt: DateTime.utc(2026, 8, 12))
          ]),
      childExceptionRequestsProvider(scope).overrideWith((ref) async => [
            _request(ChildExceptionRequestStatus.approved)
          ]),
      capabilityStatusProvider.overrideWith((ref) async => <CapabilityStatus>[]),
    ], child: const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: [Locale('ar'), Locale('en')],
        home: ChildPolicyExperienceScreen(familyId: 'family-1', deviceId: 'device-1', childUid: 'child-uid'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('دون اتصال'), findsOneWidget);
    expect(find.text('هذه القاعدة تساعد عائلتك على إدارة الوقت بوضوح. لا تعني تلقائيًا أن Android حظر تطبيقًا.'), findsOneWidget);
    expect(find.text('يلزم منح الوصول من إعدادات Android قبل الملاحظة.'), findsOneWidget);
    expect(find.textContaining('10 min'), findsOneWidget);
  });
}
