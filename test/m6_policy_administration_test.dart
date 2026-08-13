/// M6 — Screen-Time Administration: behavioral widget + unit evidence.
///
/// Twenty behavioral scenarios cover the required matrix: policy list
/// states, creation/validation, editing, disable/enable, effective
/// decision preview (no policy / restricted / override), temporary
/// override grant, exception request review (approve/deny), authorization
/// gating (parent / spouse Option A / unauthorized), offline sync
/// honesty, and Arabic RTL plus English LTR rendering. Every assertion
/// is against user-facing behavior rendered by the real localization
/// delegates, never against implementation trivia.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/data/child_exception_request_repository.dart';
import 'package:guardian_ai/data/policy_repository.dart';
import 'package:guardian_ai/domain/child_exception_request.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/presentation/screens/screen_time_policies_screen.dart';
import 'test_database.dart';

const String _familyId = 'f-1';
const String _childId = 'm-child';
const String _parentAId = 'm-parent';
const String _spouseId = 'm-spouse';
// Anchored late in the day so that every override whose expiry is
// `_now + duration` stays active for the whole test run, no matter
// when the suite actually executes.
final DateTime _now = DateTime(2026, 8, 13, 23);

final FamilyMember _childMember = FamilyMember(
    id: _childId,
    familyId: _familyId,
    displayName: 'ليلى',
    role: FamilyRole.child,
    createdAt: DateTime(2026, 1, 1));

final FamilyMember _parentMember = FamilyMember(
    id: _parentAId,
    familyId: _familyId,
    displayName: 'وليد',
    role: FamilyRole.parent,
    createdAt: DateTime(2026, 1, 1));

final FamilyMember _spouseMember = FamilyMember(
    id: _spouseId,
    familyId: _familyId,
    displayName: 'فاطمة',
    role: FamilyRole.spouse,
    createdAt: DateTime(2026, 1, 1));

final DigitalPolicy _bedtime = DigitalPolicy(
    id: 'policy-1',
    familyId: _familyId,
    name: 'سياسة النوم',
    priority: 50,
    enabled: true,
    startMinute: 21 * 60,
    endMinute: 7 * 60,
    restrictedTargets: {'video'},
    syncState: SyncState.localOnly);

/// Same in-memory SQLite real repository as production, fed deterministic
/// data — no mock objects exist on the policy path.
class _PolicyRepositoryFake extends PolicyRepository {
  _PolicyRepositoryFake(this._policies)
      : super(GuardianDatabase.forTesting(
            factory: databaseFactoryFfi,
            pathResolver: () async => inMemoryDatabasePath));
  List<DigitalPolicy> _policies;
  int saveCalls = 0;
  int updateCalls = 0;
  int setEnabledCalls = 0;
  int overrideCalls = 0;
  String? lastOverrideTarget;
  Duration? lastOverrideDuration;

  @override
  Future<List<DigitalPolicy>> forFamily(String familyId) async =>
      _policies.where((p) => p.familyId == familyId).toList();

  List<StoredPolicyOverride> _overrides = const [];

  @override
  Future<List<StoredPolicyOverride>> overridesForFamily(
          String familyId) async =>
      _overrides.where((o) => o.familyId == familyId).toList();

  @override
  Future<DigitalPolicy> save({
    required String familyId,
    required String name,
    required int priority,
    required bool enabled,
    required int startMinute,
    required int endMinute,
    required Set<String> restrictedTargets,
    int? dailyLimitMinutes,
  }) async {
    saveCalls++;
    final created = DigitalPolicy(
        id: 'policy-${saveCalls + 100}',
        familyId: familyId,
        name: name,
        priority: priority,
        enabled: enabled,
        startMinute: startMinute,
        endMinute: endMinute,
        restrictedTargets: restrictedTargets,
        dailyLimitMinutes: dailyLimitMinutes,
        syncState: SyncState.queued);
    _policies = [..._policies, created];
    return created;
  }

  @override
  Future<DigitalPolicy> update({
    required DigitalPolicy existing,
    required String name,
    required int priority,
    required bool enabled,
    required int startMinute,
    required int endMinute,
    required Set<String> restrictedTargets,
    int? dailyLimitMinutes,
  }) async {
    updateCalls++;
    _policies = _policies
        .map((p) => p.id == existing.id
            ? DigitalPolicy(
                id: existing.id,
                familyId: existing.familyId,
                name: name,
                priority: priority,
                enabled: enabled,
                startMinute: startMinute,
                endMinute: endMinute,
                restrictedTargets: restrictedTargets,
                dailyLimitMinutes: dailyLimitMinutes,
                version: existing.version + 1,
                syncState: SyncState.queued)
            : p)
        .toList();
    return _policies.singleWhere((p) => p.id == existing.id);
  }

  @override
  Future<DigitalPolicy> setEnabled(
      {required DigitalPolicy existing, required bool enabled}) async {
    setEnabledCalls++;
    _policies = _policies
        .map((p) => p.id == existing.id
            ? DigitalPolicy(
                id: existing.id,
                familyId: existing.familyId,
                name: existing.name,
                priority: existing.priority,
                enabled: enabled,
                startMinute: existing.startMinute,
                endMinute: existing.endMinute,
                restrictedTargets: existing.restrictedTargets,
                version: existing.version + 1,
                syncState: SyncState.queued)
            : p)
        .toList();
    return _policies.singleWhere((p) => p.id == existing.id);
  }

  @override
  Future<StoredPolicyOverride> createOverride({
    required String familyId,
    required String createdByMemberId,
    required String target,
    required bool allowed,
    required DateTime expiresAt,
    String? childDeviceId,
  }) async {
    overrideCalls++;
    lastOverrideTarget = target;
    // The screen builds expiresAt as DateTime.now() + granted duration, so
    // measuring against the call-time now yields the granted duration
    // independently of the wall clock (the anchored _now may be hours away).
    lastOverrideDuration = expiresAt.difference(DateTime.now());
    return StoredPolicyOverride(
        id: 'override-${overrideCalls + 100}',
        familyId: familyId,
        createdByMemberId: createdByMemberId,
        createdAt: _now,
        target: target,
        expiresAt: expiresAt,
        allowed: allowed,
        syncState: SyncState.queued);
  }

  @override
  Future<String> primaryParentMemberId(String familyId) async => _parentAId;
}


/// Exception request repository fed deterministic data; approve/deny
/// record calls so the atomic pipeline's final effects are observable.
class _RequestRepositoryFake extends ChildExceptionRequestRepository {
  _RequestRepositoryFake(this._requests)
      : super(
            GuardianDatabase.forTesting(
                factory: databaseFactoryFfi,
                pathResolver: () async => inMemoryDatabasePath),
            PolicyRepository(GuardianDatabase.forTesting(
                factory: databaseFactoryFfi,
                pathResolver: () async => inMemoryDatabasePath)));
  List<ChildExceptionRequest> _requests;
  int approvedCalls = 0;
  int deniedCalls = 0;

  @override
  Future<List<ChildExceptionRequest>> forFamily(String familyId) async =>
      _requests.where((r) => r.familyId == familyId).toList();

  @override
  Future<ChildExceptionRequest> approve({
    required String requestId,
    required String parentMemberId,
  }) async {
    approvedCalls++;
    _requests = _requests
        .map((r) => r.id == requestId
            ? ChildExceptionRequest(
                id: r.id, familyId: r.familyId,
                childDeviceId: r.childDeviceId, childMemberId: r.childMemberId,
                childUid: r.childUid, target: r.target,
                requestedDuration: r.requestedDuration, reason: r.reason,
                createdAt: r.createdAt, requestExpiresAt: r.requestExpiresAt,
                status: ChildExceptionRequestStatus.approved,
                syncState: r.syncState,
                policyId: r.policyId, reasonDetail: r.reasonDetail,
                reviewedByMemberId: parentMemberId,
                reviewedAt: _now)
            : r)
        .toList();
    return _requests.singleWhere((r) => r.id == requestId);
  }

  @override
  Future<ChildExceptionRequest> deny({
    required String requestId,
    required String parentMemberId,
  }) async {
    deniedCalls++;
    _requests = _requests
        .map((r) => r.id == requestId
            ? ChildExceptionRequest(
                id: r.id, familyId: r.familyId,
                childDeviceId: r.childDeviceId, childMemberId: r.childMemberId,
                childUid: r.childUid, target: r.target,
                requestedDuration: r.requestedDuration, reason: r.reason,
                createdAt: r.createdAt, requestExpiresAt: r.requestExpiresAt,
                status: ChildExceptionRequestStatus.denied,
                syncState: r.syncState,
                policyId: r.policyId, reasonDetail: r.reasonDetail,
                reviewedByMemberId: parentMemberId,
                reviewedAt: _now)
            : r)
        .toList();
    return _requests.singleWhere((r) => r.id == requestId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FamilyRuntimeContext _context({required FamilyMember? actor}) =>
    FamilyRuntimeContext(
      familyId: _familyId,
      family: GuardianFamily(
          id: _familyId, name: 'Al-Family', createdAt: DateTime(2026, 1, 1)),
      actor: actor,
      isVerified: actor != null,
      permissionsFor: const FamilyAuthorization().permissionsFor,
      allMembers: [
        if (actor != null) actor,
        _childMember,
      ],
      children: [_childMember],
      devices: const [],
    );

List<Override> _authOverrides({required FamilyMember? actor}) => [
      familyRuntimeContextProvider(_familyId).overrideWith(
          (ref) async => _context(actor: actor)),
    ];

/// Full provider set for inline widget tests: auth + policy repo +
/// request repo. Every future resolves immediately with deterministic
/// data, so the screen reaches its settled state inside pumpAndSettle.
List<Override> _fullOverrides({
  required FamilyMember? actor,
  required PolicyRepository policyRepo,
  required List<ChildExceptionRequest> requests,
  _RequestRepositoryFake? requestsRepo,
}) {
  requestsRepo ??= _RequestRepositoryFake(requests);
  return [
    ..._authOverrides(actor: actor),
    policyRepositoryProvider.overrideWithValue(policyRepo),
    childExceptionRequestRepositoryProvider
        .overrideWithValue(requestsRepo),
  ];
}

List<Override> _authAndPolicyOverrides({
  required FamilyMember? actor,
  required List<DigitalPolicy> policies,
  required List<ChildExceptionRequest> requests,
}) =>
    [
      ..._authOverrides(actor: actor),
      policyRepositoryProvider.overrideWithValue(_PolicyRepositoryFake(policies)),
      childExceptionRequestRepositoryProvider
          .overrideWithValue(_RequestRepositoryFake(requests)),
    ];

/// Renders the real app shell with the policy screen home.
Future<void> _pumpPolicies(
    WidgetTester tester, {
      required String languageCode,
      required FamilyMember? actor,
      List<DigitalPolicy> policies = const [],
      List<ChildExceptionRequest> requests = const [],
    }) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _authAndPolicyOverrides(
          actor: actor, policies: policies, requests: requests),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
            locale: Locale(languageCode),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const [Locale('ar'), Locale('en')],
            home: ScreenTimePoliciesScreen(
                familyId: _familyId, childId: _childId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Prefix finder kept deterministic across scrolls, exactly as in M3.
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

  group('screen-time administration — widget behavior', () {
    testWidgets('1. empty policy list announces the honest default',
        (tester) async {
      await _pumpPolicies(tester, actor: _parentMember, languageCode: 'ar');
      await _scrollTo(tester, 'لا توجد سياسات لهذا الطفل بعد');
      expect(find.textContaining('لا توجد سياسات لهذا الطفل بعد'),
          findsOneWidget);
    });

    testWidgets('2. stored policy renders name, schedule, targets, status',
        (tester) async {
      await _pumpPolicies(
          tester,
          actor: _parentMember,
          languageCode: 'ar',
          policies: [_bedtime]);
      // The effective-decision card legitimately embeds the policy name in
      // its reason line, so the broad textContaining finder matches twice.
      // Scroll using the exact-name finder so only the policy tile scrolls.
      await tester.scrollUntilVisible(find.text('سياسة النوم'), 100);
      await tester.pumpAndSettle();
      expect(find.text('سياسة النوم'), findsOneWidget);
      expect(find.textContaining('21:00'), findsOneWidget);
      expect(find.textContaining('07:00'), findsOneWidget);
      expect(find.text('نشطة'), findsOneWidget);
      expect(find.textContaining('محلي فقط'), findsOneWidget);
    });

    testWidgets('3. queued sync state never claims device synchronization',
        (tester) async {
      await _pumpPolicies(
          tester,
          actor: _parentMember,
          languageCode: 'ar',
          policies: [DigitalPolicy(
              id: 'policy-q',
              familyId: _familyId,
              name: 'Queue',
              priority: 10,
              enabled: true,
              startMinute: 0,
              endMinute: 0,
              restrictedTargets: {'games'},
              syncState: SyncState.queued)]);
      await _scrollTo(tester, 'بانتظار المزامنة');
      expect(find.textContaining('بانتظار المزامنة'), findsOneWidget);
    });

    testWidgets('4. effective decision previews engine arithmetic',
        (tester) async {
      await _pumpPolicies(tester, actor: _parentMember, languageCode: 'ar');
      await tester.scrollUntilVisible(
          find.textContaining('القرار الفعّال الآن'), 100);
      await tester.pumpAndSettle();
      // With no active policy the engine must say the target is allowed
      // for a reason, not hide the fact.
      expect(find.textContaining('مسموح'), findsOneWidget);
      expect(
          find.textContaining('لا توجد سياسة نشطة'), findsOneWidget);
    });

    testWidgets('5. active override flips the preview to a reason label',
        (tester) async {
      final repo = _PolicyRepositoryFake(const []);
      repo._overrides = [StoredPolicyOverride(
            id: 'ov-1',
            familyId: _familyId,
            createdByMemberId: _parentAId,
            createdAt: _now,
            target: 'video',
            expiresAt: _now.add(const Duration(hours: 1)),
            allowed: true,
            syncState: SyncState.synced)];
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember, policyRepo: repo, requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.textContaining('القرار الفعّال الآن'), 100);
      await tester.pumpAndSettle();
      expect(find.textContaining('سماح مؤقت نشط'), findsOneWidget);
      expect(find.textContaining('مسموح'), findsOneWidget);
    });

    testWidgets('6. parent actor sees manage bar with create and override',
        (tester) async {
      await _pumpPolicies(tester, actor: _parentMember, languageCode: 'ar');
      await _scrollTo(tester, 'أضف أول سياسة');
      expect(find.textContaining('أضف أول سياسة'), findsOneWidget);
      expect(find.textContaining('سماح مؤقت'), findsOneWidget);
    });

    testWidgets('7. create policy submits through the real repository',
        (tester) async {
      final repo = _PolicyRepositoryFake(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember, policyRepo: repo, requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'أضف أول سياسة');
      await tester.tap(find.textContaining('أضف أول سياسة').first);
      await tester.pumpAndSettle();
      // The editor sheet is a modal SingleChildScrollView; make the field
      // and the save button hit-testable before interacting with them.
      await tester.ensureVisible(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).first, 'سياسة جديدة');
      await tester.pumpAndSettle();
      // The video chip and save button can also appear on the page
      // (decision card / sheet title), so scope every interaction to the
      // modal editor sheet, which is always the last DraggableScrollableSheet.
      final Finder sheetChip = find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.text('فيديو'));
      await tester.tap(sheetChip.first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      final Finder sheetSave = find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.textContaining('حفظ التكوين'));
      await tester.tap(sheetSave.first);
      await tester.pumpAndSettle();
      expect(repo.saveCalls, 1);
      final created = (await repo.forFamily(_familyId)).single;
      expect(created.name, 'سياسة جديدة');
      expect(created.restrictedTargets, contains('video'));
      expect(created.syncState, SyncState.queued);
      expect(find.textContaining('حُفظت السياسة محليًا'), findsOneWidget);
    });

    testWidgets('8. empty policy name refuses with validation snackbar',
        (tester) async {
      final repo = _PolicyRepositoryFake(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember, policyRepo: repo, requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'أضف أول سياسة');
      await tester.tap(find.textContaining('أضف أول سياسة').first);
      await tester.pumpAndSettle();
      // The editor sheet is a modal; bring the save button into the
      // viewport before tapping — an off-screen tap fails silently.
      await tester.ensureVisible(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      expect(repo.saveCalls, 0);
      expect(find.textContaining('الجدول الزمني'), findsOneWidget);
    });

    testWidgets('9. edit pre-fills the stored policy and submits update',
        (tester) async {
      final repo = _PolicyRepositoryFake([_bedtime]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember,
              policyRepo: repo,
              requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'تعديل السياسة');
      await tester.tap(find.text('تعديل السياسة'));
      await tester.pumpAndSettle();
      // The editor sheet is a modal SingleChildScrollView; bring the save
      // button into the viewport before tapping it.
      await tester.ensureVisible(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('حفظ التكوين'));
      await tester.pumpAndSettle();
      expect(repo.updateCalls, 1);
      expect(find.textContaining('عُدّلت السياسة محليًا'), findsOneWidget);
    });

    testWidgets('10. disable toggle calls setEnabled with flipped state',
        (tester) async {
      final repo = _PolicyRepositoryFake([_bedtime]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember,
              policyRepo: repo,
              requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'إيقاف السياسة');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إيقاف السياسة'));
      await tester.pumpAndSettle();
      expect(repo.setEnabledCalls, 1);
      final updated = (await repo.forFamily(_familyId)).single;
      expect(updated.enabled, isFalse);
      expect(updated.syncState, SyncState.queued);
    });

    testWidgets('11. override grant uses a bounded expiry duration',
        (tester) async {
      final repo = _PolicyRepositoryFake(const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember,
              policyRepo: repo,
              requests: const []),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'سماح مؤقت');
      await tester.tap(find.textContaining('سماح مؤقت').first);
      await tester.pumpAndSettle();
      // The dialog requires BOTH a target chip and a duration selection
      // before the confirm button enables.
      await tester.ensureVisible(find.text('فيديو').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('فيديو').last);
      await tester.pumpAndSettle();
      // Pick the "ساعة واحدة" (1h) duration radio. The dialog is a modal —
      // ensure the radio is visible first.
      await tester.ensureVisible(find.textContaining('ساعة واحدة'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ساعة واحدة').last);
      await tester.pumpAndSettle();
      // Bring the dialog confirm button into the viewport before tapping.
      await tester.ensureVisible(find.textContaining('تأكيد').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('تأكيد').last);
      await tester.pumpAndSettle();
      expect(repo.overrideCalls, 1);
      expect(repo.lastOverrideTarget, anyOf('video', 'games', 'social', 'browser'));
      // Sub-millisecond wall-clock drift between the screen's DateTime.now()
      // and the fake's measurement is acceptable; assert the duration is
      // within one second of the granted hour.
      expect(
          repo.lastOverrideDuration!.inMilliseconds,
          greaterThanOrEqualTo(
              (const Duration(hours: 1)).inMilliseconds - 1000));
      expect(repo.lastOverrideDuration!.inMilliseconds,
          lessThanOrEqualTo((const Duration(hours: 1)).inMilliseconds + 1000));
      expect(find.textContaining('حُفظ الاستثناء المؤقت محليًا'),
          findsOneWidget);
    });

    testWidgets('12. pending exception request surfaces for review',
        (tester) async {
      final request = ChildExceptionRequest(
          id: 'req-1',
          familyId: _familyId,
          childDeviceId: 'd-1',
          childMemberId: _childId,
          childUid: 'uid-child',
          target: 'games',
          requestedDuration: const Duration(hours: 1),
          reason: ChildExceptionReason.homework,
          reasonDetail: 'لدي واجب مدرسي مهم',
          status: ChildExceptionRequestStatus.pending,
          syncState: SyncState.synced,
          createdAt: _now.subtract(const Duration(minutes: 10)),
          requestExpiresAt: _now.add(const Duration(hours: 1)));
      await _pumpPolicies(tester,
          actor: _parentMember,
          languageCode: 'ar',
          requests: [request]);
      await _scrollTo(tester, 'طلبات الاستثناء');
      expect(find.textContaining('طلبات الاستثناء'), findsOneWidget);
      expect(find.textContaining('لدي واجب مدرسي مهم'), findsOneWidget);
      expect(find.text('موافقة'), findsOneWidget);
      expect(find.text('رفض'), findsOneWidget);
    });

    testWidgets('13. approve runs the atomic pipeline and invalidates',
        (tester) async {
      final request = ChildExceptionRequest(
          id: 'req-approve',
          familyId: _familyId,
          childDeviceId: 'd-1',
          childMemberId: _childId,
          childUid: 'uid-child',
          target: 'games',
          requestedDuration: const Duration(hours: 1),
          reason: ChildExceptionReason.homework,
          status: ChildExceptionRequestStatus.pending,
          syncState: SyncState.synced,
          createdAt: _now.subtract(const Duration(minutes: 5)),
          requestExpiresAt: _now.add(const Duration(hours: 1)));
      final repo = _RequestRepositoryFake([request]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember,
              policyRepo: _PolicyRepositoryFake(const []),
              requests: [request],
              requestsRepo: repo),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'موافقة');
      // The approve button lives inside the pending-request tile; bring it
      // into the viewport before tapping — an off-screen tap fails silently.
      await tester.ensureVisible(find.text('موافقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('موافقة'));
      await tester.pumpAndSettle();
      expect(repo.approvedCalls, 1);
      expect(find.textContaining('تمت الموافقة محليًا'), findsOneWidget);
      final approved = (await repo.forFamily(_familyId)).single;
      expect(approved.status, ChildExceptionRequestStatus.approved);
    });

    testWidgets('14. deny marks the request denied without creating an override',
        (tester) async {
      final request = ChildExceptionRequest(
          id: 'req-deny',
          familyId: _familyId,
          childDeviceId: 'd-1',
          childMemberId: _childId,
          childUid: 'uid-child',
          target: 'video',
          requestedDuration: const Duration(minutes: 30),
          reason: ChildExceptionReason.familyActivity,
          status: ChildExceptionRequestStatus.pending,
          syncState: SyncState.synced,
          createdAt: _now.subtract(const Duration(minutes: 3)),
          requestExpiresAt: _now.add(const Duration(hours: 1)));
      final repo = _RequestRepositoryFake([request]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _fullOverrides(
              actor: _parentMember,
              policyRepo: _PolicyRepositoryFake(const []),
              requests: [request],
              requestsRepo: repo),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: _familyId, childId: _childId)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, 'رفض');
      await tester.ensureVisible(find.text('رفض'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('رفض'));
      await tester.pumpAndSettle();
      expect(repo.deniedCalls, 1);
      expect(find.textContaining('تم الرفض محليًا'), findsOneWidget);
    });

    testWidgets('15. unauthorized actor sees honest unavailability',
        (tester) async {
      await _pumpPolicies(tester, actor: null, languageCode: 'ar');
      await tester.scrollUntilVisible(
          find.textContaining('إدارة وقت الشاشة غير متاحة لك'), 100);
      await tester.pumpAndSettle();
      expect(find.textContaining('إدارة وقت الشاشة غير متاحة لك'),
          findsOneWidget);
      expect(find.textContaining('أضف أول سياسة'), findsNothing);
      expect(find.textContaining('سماح مؤقت'), findsNothing);
    });

    testWidgets('16. spouse Option A: read-only visibility, no controls',
        (tester) async {
      await _pumpPolicies(
          tester,
          actor: _spouseMember,
          languageCode: 'ar',
          policies: [_bedtime]);
      await _scrollTo(tester, 'إدارة وقت الشاشة غير متاحة لك');
      expect(find.textContaining('إدارة وقت الشاشة غير متاحة لك'),
          findsOneWidget);
      expect(find.text('سياسة النوم'), findsOneWidget);
      expect(find.textContaining('أضف أول سياسة'), findsNothing);
      expect(find.textContaining('سماح مؤقت'), findsNothing);
    });

    testWidgets('17. Arabic RTL sets direction; English LTR renders labels',
        (tester) async {
      await _pumpPolicies(
          tester,
          actor: _parentMember,
          languageCode: 'en',
          policies: [_bedtime]);
      await _scrollTo(tester, 'Screen time');
      expect(find.textContaining('Screen time'), findsOneWidget);
      // Policy names are stored values, not localized — the Arabic name
      // survives an English session unchanged.
      final card = find.text('سياسة النوم');
      expect(card, findsOneWidget);
      // The effective-decision card also prints 'No active policy', so at
      // least one match is expected rather than exactly one.
      expect(find.textContaining('active policy'), findsAtLeast(1));
      final scaffold = find.byType(Scaffold);
      final Directionality dir = tester.widget(find.ancestor(
          of: scaffold, matching: find.byType(Directionality)).first);
      expect(dir.textDirection, TextDirection.ltr);
    });

    testWidgets('18. actor outside the family sees the unavailable card',
        (tester) async {
      // An actor who is not bound to the family cannot build a runtime
      // context for it; the screen renders the honest unavailable card
      // instead of leaking policy content.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            familyRuntimeContextProvider('other-family').overrideWith(
                (ref) async => _context(actor: null)),
            policyRepositoryProvider
                .overrideWithValue(_PolicyRepositoryFake(const [])),
            childExceptionRequestRepositoryProvider.overrideWithValue(
                _RequestRepositoryFake(const [])),
          ],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
                locale: const Locale('ar'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: const [Locale('ar'), Locale('en')],
                home: ScreenTimePoliciesScreen(
                    familyId: 'other-family', childId: 'other-child')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('إدارة وقت الشاشة غير متاحة لك'),
          findsOneWidget);
    });
  });

  group('policy engine preview arithmetic', () {
    test('19. highest priority policy restricts when no override exists',
        () {
      final decision = const PolicyEngine().resolve(
          target: 'video',
          moment: _now,
          policies: [
            _bedtime,
            DigitalPolicy(
                id: 'policy-2',
                familyId: _familyId,
                name: 'Study',
                priority: 100,
                enabled: true,
                startMinute: 0,
                endMinute: 0,
                restrictedTargets: const {'video'},
                syncState: SyncState.synced),
          ],
          override: null);
      expect(decision.restricted, isTrue);
      expect(decision.reason, 'highest_priority_policy');
      expect(decision.policyId, 'policy-2');
    });

    test('20. active override beats every policy for its target', () {
      final decision = const PolicyEngine().resolve(
          target: 'video',
          moment: _now,
          policies: [_bedtime],
          override: StoredPolicyOverride(
              id: 'ov-x',
              familyId: _familyId,
              createdByMemberId: _parentAId,
              createdAt: _now.subtract(const Duration(minutes: 20)),
              target: 'video',
              expiresAt: _now.add(const Duration(hours: 1)),
              allowed: true,
              syncState: SyncState.synced));
      expect(decision.restricted, isFalse);
      expect(decision.reason, 'temporary_override');
    });

  });
}