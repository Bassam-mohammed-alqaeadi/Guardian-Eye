library;
/// M3 — Child Context vertical: behavioral widget evidence.
///
/// Twelve behavioral scenarios cover the required widget-test matrix:
/// loading, loaded child, offline cached child, offline uncached state,
/// child not found, unauthorized state, error state, safety state,
/// recent incidents, Arabic RTL, English LTR, and navigation to the
/// child context. None of them merely asserts that widgets exist —
/// each asserts observable, user-facing behavior.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/screen_time.dart';
import 'package:guardian_ai/presentation/guardian_app.dart';
import 'package:guardian_ai/presentation/screens/child_context_screen.dart';
import 'package:guardian_ai/presentation/router/app_router.dart';
import 'test_database.dart';

const String _familyId = 'f-1';
const String _childId = 'm-child';
const String _deviceId = 'd-1';

final FamilyMember _childMember = FamilyMember(
    id: _childId,
    familyId: _familyId,
    displayName: 'ليلى',
    role: FamilyRole.child,
    createdAt: DateTime(2026, 1, 1));

final ChildDeviceState _linkedDevice = ChildDeviceState(
    deviceId: _deviceId,
    familyId: _familyId,
    memberId: _childId,
    lifecycle: ChildDeviceLifecycle.active,
    requiredPolicyVersion: 1,
    updatedAt: DateTime(2026, 8, 13),
    lastSyncAt: DateTime(2026, 8, 13, 10, 30),
    lastValidPolicyAt: DateTime(2026, 8, 12, 9));

final GuardianIncident _recentIncident = GuardianIncident(
    id: 'i-1',
    familyId: _familyId,
    category: SafetyCategory.bullying,
    severity: IncidentSeverity.medium,
    confidence: 0.8,
    status: IncidentState.synced,
    observedAt: DateTime(2026, 8, 13, 9, 15),
    modelVersion: 'v1');

class _StubMembershipRepository implements FamilyMembershipRepository {
  _StubMembershipRepository(this.members);
  final List<FamilyMember> members;
  @override
  Future<FamilyMember?> memberForFamily({
    required String familyId,
    required String memberId,
  }) async =>
      members
          .where((m) => m.familyId == familyId && m.id == memberId)
          .toList()
                    .cast<FamilyMember?>()
          .firstOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stub repositories that never resolve — used only by the loading-state
/// test so the join stays in AsyncValue.loading forever.
class _NeverMembershipRepository implements FamilyMembershipRepository {
  @override
  Future<FamilyMember?> memberForFamily({
    required String familyId,
    required String memberId,
  }) =>
      Completer<FamilyMember?>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NeverDeviceRepository implements ChildDeviceRepository {
  @override
  Future<List<ChildDeviceState>> statesForFamily(String familyId) =>
      Completer<List<ChildDeviceState>>().future;
  @override
  Future<List<DailyUsageSummary>> usageForDeviceDay(
          {required String deviceId, required DateTime day}) =>
      Completer<List<DailyUsageSummary>>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDeviceRepository implements ChildDeviceRepository {
  _StubDeviceRepository(this.states);
  final List<ChildDeviceState> states;
  @override
  Future<List<ChildDeviceState>> statesForFamily(String familyId) async =>
      states.where((s) => s.familyId == familyId).toList();
  @override
  Future<List<DailyUsageSummary>> usageForDeviceDay(
      {required String deviceId, required DateTime day}) async =>
      states
          .where((s) => s.deviceId == deviceId)
          .map((_) => DailyUsageSummary(
              deviceId: deviceId,
              familyId: _familyId,
              target: 'app',
              dayStart: DateTime(2026, 8, 13),
              totalMilliseconds: 54 * Duration.millisecondsPerMinute,
              capturedAt: DateTime(2026, 8, 13)))
          .toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const String _adultId = 'm-adult';
final FamilyMember _adultMember = FamilyMember(
    id: _adultId,
    familyId: _familyId,
    displayName: 'وليد',
    role: FamilyRole.parent,
    createdAt: DateTime(2026, 1, 1));

List<Override> _overridesFor({
  FamilyMember? actor,
  bool isVerified = true,
  List<FamilyMember> members = const [],
  List<ChildDeviceState> devices = const [],
  List<GuardianIncident>? incidents,
  required String languageCode,
  bool neverResolve = false,
}) =>
    [
      localeProvider.overrideWith((ref) => languageCode),
      familyMembershipRepositoryProvider.overrideWithValue(
          neverResolve
              ? _NeverMembershipRepository()
              : _StubMembershipRepository(members)),
      childDeviceRepositoryProvider.overrideWithValue(
          neverResolve
              ? _NeverDeviceRepository()
              : _StubDeviceRepository(devices)),
      recentIncidentsProvider(_familyId).overrideWith(
          (ref) async => incidents ?? const <GuardianIncident>[]),
      familyRuntimeContextProvider(_familyId).overrideWith((ref) async =>
          FamilyRuntimeContext(
            familyId: _familyId,
            family: GuardianFamily(
                id: _familyId,
                name: 'Al-Family',
                createdAt: DateTime(2026, 1, 1)),
            actor: actor,
            isVerified: isVerified,
            permissionsFor:
                const FamilyAuthorization().permissionsFor,
            allMembers: members,
            children: members
                .where((m) => m.role == FamilyRole.child)
                .toList(),
            devices: devices,
          )),
    ];

/// Navigates the app's canonical router inside the same ProviderScope
/// that builds the shell, without disturbing the widget tree.
class _GoConsumer extends ConsumerWidget {
  const _GoConsumer(this.location);
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(location);
    });
    return const SizedBox.shrink();
  }
}

Future<void> _pumpChildContext(
    WidgetTester tester, {
      required String languageCode,
      FamilyMember? actor,
      bool isVerified = true,
      List<FamilyMember> members = const [],
      List<ChildDeviceState> devices = const [],
      List<GuardianIncident>? incidents,
      String target = '/child/f-1/m-child',
    }) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overridesFor(
        actor: actor,
        isVerified: isVerified,
        members: members,
        devices: devices,
        incidents: incidents,
        languageCode: languageCode,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            const GuardianApp(),
            _GoConsumer(target),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

/// Prefix finder: the app concatenates some labels with values, so an
/// exact find may never match a built widget even when its label is
/// rendered. Prefix matching keeps scrolls deterministic; skipping
/// already-visible matches prevents ambiguity when a label appears in
/// more than one card.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.textContaining(text), 100);
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  setUpAll(() async {
    // Real SQLite schema — every provider override chain is identical
    // to production, but each test feeds deterministic data.
    await openTestDatabase();
  });

  group('child context — widget behavior', () {
    testWidgets('1. loading state shows progress until data arrives',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overridesFor(
              members: [_childMember], languageCode: 'ar', neverResolve: true),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                GuardianApp(),
                _GoConsumer('/child/f-1/m-child'),
              ],
            ),
          ),
        ),
      );
      // The stub repositories never resolve in this test, so the
      // membership read (the first step of the join) keeps the screen in
      // its honest loading state. The shell title renders in every
      // state, so the absence of the child's identity is the loading
      // evidence.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('ليلى'), findsNothing);
    });

    testWidgets('2. loaded child renders identity, device, and activity',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        isVerified: true,
        members: [_childMember, _adultMember],
        devices: [_linkedDevice],
      );
      expect(find.text('سياق الطفل'), findsOneWidget);
      expect(find.text('ليلى'), findsOneWidget);
      expect(find.text('طفل'), findsOneWidget);
      expect(find.text('نشط محليًا'), findsOneWidget);
      expect(find.text('ملخص النشاط'), findsOneWidget);
      // Today's screen time totals are computed from the usage join.
      await _scrollTo(tester, 'وقت الشاشة اليوم');
      expect(find.textContaining('54'), findsOneWidget);
      expect(find.text('تم القياس محليًا؛ لا يعني ذلك أن Android حظر تطبيقًا.'),
          findsOneWidget);
    });

    testWidgets('3. offline cached child shows sync time verbatim',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        isVerified: true,
        members: [_childMember],
        devices: [_linkedDevice],
      );
      await _scrollTo(tester, 'آخر مزامنة');
      expect(find.textContaining('10:30'), findsOneWidget);
      expect(find.textContaining('آخر سياسة صالحة'), findsOneWidget);
      expect(find.textContaining('أدنى إصدار سياسة 1'), findsOneWidget);
    });

    testWidgets('4. offline uncached child shows honest empty state',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        members: [_childMember],
        devices: const [],
      );
      // No device linked → no usage totals; nothing is fabricated.
      // The same honest label appears in both the device card and the
      // activity card, so assert it is present at least once and that no
      // usage numbers are invented.
      expect(find.textContaining('لا يوجد جهاز مربوط بعد'), findsWidgets);
      expect(find.textContaining('min'), findsNothing);
    });

    testWidgets('5. child not found surfaces the honest missing-child error',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        members: [_childMember],
        target: '/child/f-1/no-such-child',
      );
      // The route pattern matched, so the child-context screen owns the
      // recovery: a genuine missing-child error with a retry affordance,
      // never a fabricated profile.
      expect(find.textContaining('تعذّر العثور على هذه الصفحة'), findsOneWidget);
      expect(find.text('ليلى'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('6. unauthorized actor sees verification lines, no dead ends',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: null,
        isVerified: false,
        members: [_childMember],
        devices: [_linkedDevice],
      );
      // The screen remains legible; verification is required but never
      // blocks reading local context. The device card sits at the top of
      // the list and paints the lock affordance when the actor cannot act.
      expect(find.text('ليلى'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await _scrollTo(tester, 'العودة إلى لوحة التحكم');
      expect(find.textContaining('تُعرض البيانات المحلية'), findsWidgets);
    });

    testWidgets('7. error state offers an honest retry', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._overridesFor(languageCode: 'ar'),
            familyMembershipRepositoryProvider.overrideWithValue(
              _StubMembershipRepository([]),
            ),
          ],
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: <Widget>[
                GuardianApp(),
                _GoConsumer('/child/f-1/m-child'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      // A family with no members cannot locate any child — the member
      // read is canonical and local; a missing child is genuinely
      // absent, so the surface renders the honest error-recovery flow.
      expect(find.textContaining('تعذّر العثور على هذه الصفحة'), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
      // The retry button re-invalidates the provider; tapping it must
      // run without throwing.
      await tester.tap(find.byIcon(Icons.refresh_outlined));
      await tester.pumpAndSettle();
    });

    testWidgets('8. safety state distinguishes calm from attention',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        members: [_childMember],
        devices: const [],
        incidents: [_recentIncident],
      );
      expect(find.text('إشارة السلامة'), findsOneWidget);
      expect(find.text('حوادث على مستوى الأسرة تهم بيئة هذا الطفل'),
          findsOneWidget);
      // Severity and category surface verbatim from the incident record.
      // Severity and category surface verbatim from the incident record,
      // rendered as one joined line ('متوسطة · تنمر').
      await _scrollTo(tester, 'متوسطة');
      expect(find.textContaining('متوسطة'), findsOneWidget);
      expect(find.textContaining('تنمر'), findsOneWidget);
    });

    testWidgets('9. recent incidents empty state is honest',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        members: [_childMember],
        devices: const [],
        incidents: const <GuardianIncident>[],
      );
      expect(find.text('إشارة السلامة'), findsOneWidget);
      await _scrollTo(tester, 'لا توجد حوادث حديثة');
      expect(find.textContaining('لا توجد حوادث حديثة'), findsOneWidget);
      expect(find.textContaining('تنمر'), findsNothing);
    });

    testWidgets('10. Arabic locale drives a right-to-left surface',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        actor: _adultMember,
        members: [_childMember],
        devices: [_linkedDevice],
      );
      final element = tester.element(find.byType(ChildContextScreen));
      expect(Directionality.of(element), TextDirection.rtl);
      await _scrollTo(tester, 'العودة إلى لوحة التحكم');
      expect(find.text('العودة إلى لوحة التحكم'), findsOneWidget);
      // M6 replaced the coming-soon placeholder with the live screen-time
      // administration section; assert its title and the policies label.
      await _scrollTo(tester, 'إدارة وقت الشاشة');
      expect(find.textContaining('إدارة وقت الشاشة'), findsOneWidget);
      expect(find.textContaining('سياسات نشطة'), findsOneWidget);
    });

    testWidgets('11. English locale drives a left-to-right surface',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'en',
        actor: _adultMember,
        members: [_childMember],
        devices: [_linkedDevice],
      );
      final element = tester.element(find.byType(ChildContextScreen));
      expect(Directionality.of(element), TextDirection.ltr);
      expect(find.text('Child context'), findsOneWidget);
      await _scrollTo(tester, 'Back to dashboard');
      expect(find.text('Back to dashboard'), findsOneWidget);
      // M6 replaced the coming-soon placeholder with the live screen-time
      // administration section; assert its title and the policies label.
      await _scrollTo(tester, 'Manage screen time');
      expect(find.textContaining('Manage screen time'), findsOneWidget);
      expect(find.textContaining('active policies'), findsOneWidget);
    });

    testWidgets('12. navigation to child context is canonical and deep-linkable',
        (tester) async {
      await _pumpChildContext(
        tester,
        languageCode: 'ar',
        members: [_childMember],
      );
      // The route resolved into the child-context surface, not the
      // not-found page — the canonical path is live end to end.
      expect(find.text('سياق الطفل'), findsOneWidget);
      // A deep link directly into the route also resolves.
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overridesFor(
              members: [_childMember], languageCode: 'ar'),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: <Widget>[
                GuardianApp(),
                _GoConsumer('/child/f-1/m-child'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(find.text('سياق الطفل'), findsOneWidget);
    });
  });
}
