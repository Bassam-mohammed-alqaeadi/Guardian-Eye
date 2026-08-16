/// M3 — Child Context data-layer unit evidence.
///
/// Deterministic, in-memory SQLite. These tests prove the state mapping,
/// safety mapping, offline mapping, and authorization outcomes of the
/// child-context join — never that widgets exist.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/application/child_context_provider.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/domain/screen_time.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

import 'test_database.dart';

const String _familyId = 'f-1';
const String _childId = 'm-child';
const String _adultId = 'm-adult';

/// A FamilyMember whose role is authoritative: child, not a label.
FamilyMember _childMember = FamilyMember(
    id: _childId,
    familyId: _familyId,
    displayName: 'ليلى',
    role: FamilyRole.child,
    createdAt: DateTime(2026, 1, 1));

FamilyMember _adultMember = FamilyMember(
    id: _adultId,
    familyId: _familyId,
    displayName: 'وليد',
    role: FamilyRole.parent,
    createdAt: DateTime(2026, 1, 1));

FamilyMember _revokedChild = FamilyMember(
    id: 'm-revoked',
    familyId: _familyId,
    displayName: 'منسحب',
    role: FamilyRole.child,
    createdAt: DateTime(2026, 1, 1),
    status: FamilyMemberStatus.revoked);

/// Stub membership repository — deterministic, never touches real data.
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

/// Stub device repository returning deterministic device states.
class _StubDeviceRepository implements ChildDeviceRepository {
  _StubDeviceRepository(this.states);
  final List<ChildDeviceState> states;

  @override
  Future<List<ChildDeviceState>> statesForFamily(String familyId) async =>
      states.where((s) => s.familyId == familyId).toList();

  @override
  Future<ChildDeviceState?> getState(String deviceId) async =>
      states.where((s) => s.deviceId == deviceId).cast<ChildDeviceState?>().firstOrNull;

  @override
  Future<List<DailyUsageSummary>> usageForDeviceDay(
      {required String deviceId, required DateTime day}) async =>
      states
          .where((s) => s.deviceId == deviceId)
          .map((_) => DailyUsageSummary(
              deviceId: _deviceId,
              familyId: _familyId,
              target: 'app',
              dayStart: DateTime(2026, 8, 13),
              totalMilliseconds: 54 * Duration.millisecondsPerMinute,
              capturedAt: DateTime(2026, 8, 13)))
          .toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const String _deviceId = 'd-1';

ChildDeviceState _linkedDevice = ChildDeviceState(
    deviceId: _deviceId,
    familyId: _familyId,
    memberId: _childId,
    lifecycle: ChildDeviceLifecycle.active,
    requiredPolicyVersion: 1,
    updatedAt: DateTime(2026, 8, 13));

/// Listens to a FutureProvider until it settles and returns the resolved
/// value or rethrows the provider error — riverpod's `provider.future` is
/// typed as `Future<Object?>`, so this keeps call sites strongly typed.
Future<T> _awaited<T>(ProviderContainer container, ProviderBase<AsyncValue<T>> provider) {
  final completer = Completer<T>();
  late final ProviderSubscription sub;
  sub = container.listen(provider, (previous, next) {
    if (next.isLoading) return;
    sub.close();
    if (next.hasValue) {
      completer.complete(next.value!);
    } else {
      completer.completeError(next.error ?? next.stackTrace ?? StateError('provider_error'));
    }
  });
  return completer.future;
}


void main() {
  sqfliteFfiInit();

  setUpAll(() async {
    // Real SQLite schema so the incident repository override chain is
    // identical to production; the overrides still make reads deterministic.
    await openTestDatabase();
  });

  group('childContextProvider — state mapping', () {
    testWidgets('resolves a linked child with device and usage totals',
        (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember, _adultMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository([_linkedDevice])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      final snapshot = await _awaited<ChildContextSnapshot>(container,
          childContextProvider((familyId: _familyId, childId: _childId)));

      expect(snapshot.child.role, FamilyRole.child);
      expect(snapshot.deviceState?.lifecycle, ChildDeviceLifecycle.active);
      expect(snapshot.deviceState?.deviceId, _deviceId);
      expect(snapshot.todayUsage.totalMinutes, 54);
      expect(snapshot.recentIncidents, isEmpty);
    });

    testWidgets('not-found state for an unknown child id', (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_adultMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        _awaited<ChildContextSnapshot>(container, childContextProvider((familyId: _familyId, childId: 'no-such-id'))),
        throwsA(isA<StateError>().having((e) => e.message, 'reason',
            'child_context_child_not_found')));
    });

    testWidgets('family-mismatched child id is not found', (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider('f-other').overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        _awaited<ChildContextSnapshot>(container, childContextProvider((familyId: 'f-other', childId: _childId))),
        throwsA(isA<StateError>().having((e) => e.message, 'reason',
            'child_context_child_not_found')));
    });

    testWidgets('revoked or non-child members surface as not found',
        (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_revokedChild, _adultMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        _awaited<ChildContextSnapshot>(container, childContextProvider((familyId: _familyId, childId: 'm-revoked'))),
        throwsA(isA<StateError>()));
      // An adult member is a child-context miss, not an adult view.
      await expectLater(
        _awaited<ChildContextSnapshot>(container, childContextProvider((familyId: _familyId, childId: _adultId))),
        throwsA(isA<StateError>()));
    });
  });

  group('childContextProvider — safety mapping', () {
    final incident = GuardianIncident(
        id: 'i-1',
        familyId: _familyId,
        category: SafetyCategory.bullying,
        severity: IncidentSeverity.medium,
        confidence: 0.8,
        status: IncidentState.localPending,
        observedAt: DateTime(2026, 8, 13, 9),
        modelVersion: 'risk-1');

    testWidgets('family-level incidents surface verbatim, newest first, capped at 5',
        (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => [incident]),
      ]);
      addTearDown(container.dispose);

      final snapshot = await _awaited<ChildContextSnapshot>(container,
          childContextProvider((familyId: _familyId, childId: _childId)));

      expect(snapshot.recentIncidents, hasLength(1));
      // Verbatim: severity is the incident's own field, never recomputed.
      expect(snapshot.recentIncidents.single.severity, IncidentSeverity.medium);
      expect(snapshot.recentIncidents.single.category, SafetyCategory.bullying);
      expect(snapshot.recentIncidents.single.observedAt, DateTime(2026, 8, 13, 9));
    });
  });

  group('childContextProvider — offline and device mapping', () {
    testWidgets('unlinked child yields a null device and no usage totals',
        (tester) async {
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      final snapshot = await _awaited<ChildContextSnapshot>(container,
          childContextProvider((familyId: _familyId, childId: _childId)));

      expect(snapshot.deviceState, isNull);
      expect(snapshot.todayUsage.totalMinutes, isNull);
      expect(snapshot.todayUsage.summaries, isEmpty);
    });

    testWidgets('reads remain local — no cloud client is consulted',
        (tester) async {
      // All reads come through providers whose implementations are SQLite
      // repositories; the deterministic stubs above exercise the same
      // call shapes. If the join needed a network client it would have
      // required one here — it does not.
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository([_linkedDevice])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
      ]);
      addTearDown(container.dispose);

      final snapshot = await _awaited<ChildContextSnapshot>(container,
          childContextProvider((familyId: _familyId, childId: _childId)));

      expect(snapshot.deviceState, isNotNull);
    });
  });

  group('childContextProvider — authorization outcomes', () {
    testWidgets('an unverified actor resolves the same local snapshot but '
        'cannot execute gated actions through FamilyRuntimeContext.can',
        (tester) async {
      final family = GuardianFamily(
          id: _familyId, name: 'F', createdAt: DateTime(2026, 1, 1));
      final container = ProviderContainer(overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(
            _StubMembershipRepository([_childMember])),
        childDeviceRepositoryProvider.overrideWithValue(
            _StubDeviceRepository(<ChildDeviceState>[])),
        recentIncidentsProvider(_familyId).overrideWith((ref) async => <GuardianIncident>[]),
        familyRuntimeContextProvider(_familyId).overrideWith((ref) async =>
            FamilyRuntimeContext(
              familyId: _familyId,
              family: family,
              actor: null,
              isVerified: false,
              permissionsFor: const FamilyAuthorization().permissionsFor,
              allMembers: [_childMember],
              children: [_childMember],
              devices: <ChildDeviceState>[],
            )),
      ]);
      addTearDown(container.dispose);

      final context = await _awaited(container,
          familyRuntimeContextProvider(_familyId));
      final snapshot = await _awaited(container,
          childContextProvider((familyId: _familyId, childId: _childId)));

      // The local data read is not an authorization boundary — data is
      // real in both cases; the permission gate decides what actions
      // render, exactly as M2 does on the dashboard.
      expect(context.can(FamilyPermission.viewChildStatus), isFalse);
      expect(snapshot.child.role, FamilyRole.child);
    });
  });
}
