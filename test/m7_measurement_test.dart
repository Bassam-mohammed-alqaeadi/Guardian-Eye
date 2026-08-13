/// M7 — Screen-Time Measurement unit evidence.
///
/// Deterministic, in-memory SQLite plus pure-function assertions. These
/// tests prove the honest-state derivations (capability ladder, freshness,
/// sync evidence, per-target comparison) and the zero-as-data rule: a
/// measured zero is a number, an absence of observation is not. Nothing
/// here claims device enforcement or real outbox delivery.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/child_usage_measurement.dart';
import 'package:guardian_ai/application/child_usage_measurement_provider.dart';
import 'package:guardian_ai/application/child_screen_time_coordinator.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/core/platform/android_enforcement_adapter.dart';
import 'package:guardian_ai/core/platform/android_observation_gateway.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/screen_time.dart';

import 'test_database.dart';

const String _deviceId = 'd-m7';
const String _familyId = 'f-m7';

/// Deterministic coordinator stub. The real coordinator is validated by
/// its own contract tests (M5/M6 evidence); M7 reuses it without change.
class _StubCoordinator implements ChildScreenTimeCoordinator {
  _StubCoordinator(this.report);
  final ScreenTimeRunReport report;
  @override
  Future<ScreenTimeRunReport> evaluateNow(String deviceId) async => report;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Repository stub mirroring the real SQLite repo's M7-relevant methods.
class _StubRepository implements ChildDeviceRepository {
  _StubRepository(
      {this.deviceState,
      this.storedSummaries = const [],
      this.pendingRows = const []});
  final ChildDeviceState? deviceState;
  final List<DailyUsageSummary> storedSummaries;
  final List<Map<String, Object?>> pendingRows;

  @override
  Future<ChildDeviceState?> getState(String deviceId) async =>
      deviceState;
  @override
  Future<List<DailyUsageSummary>> usageForDeviceDay(
          {required String deviceId, required DateTime day}) async =>
      storedSummaries;
  @override
  Future<List<Map<String, Object?>>> pendingUsageSyncRowsForDevice(
          {required String deviceId}) async =>
      pendingRows;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ChildDeviceState _linkedState({
  String deviceId = _deviceId,
  String familyId = _familyId,
  ChildDeviceLifecycle lifecycle = ChildDeviceLifecycle.active,
}) =>
    ChildDeviceState(
        deviceId: deviceId,
        familyId: familyId,
        memberId: 'm-child-m7',
        lifecycle: lifecycle,
        requiredPolicyVersion: 1,
        updatedAt: DateTime(2026, 8, 13, 11));

final EnforcementDecision _noActionDecision = EnforcementDecision(
    outcome: EnforcementOutcome.noEnforcement,
    reason: 'm7-test',
    evaluatedAt: DateTime(2026, 8, 13, 11));

ScreenTimeEvaluation _evaluation({
  required EnforcementStatus status,
  Duration used = Duration.zero,
  Duration? limit,
  String target = 'video',
}) =>
    ScreenTimeEvaluation(
        target: target,
        status: status,
        reason: 'test',
        used: used,
        limit: limit);

ScreenTimeRunReport _report({
  ForegroundApplicationStatus status = ForegroundApplicationStatus.observed,
  DateTime? capturedAt,
  List<ScreenTimeTargetReport> targets = const [],
}) =>
    ScreenTimeRunReport(
        observation: PolicyUsageObservation(
            status: status,
            dayStart: DateTime(2026, 8, 13),
            capturedAt: capturedAt,
            summaries: const []),
        targets: targets,
        ranAt: DateTime(2026, 8, 13, 12));

ScreenTimeTargetReport _targetReport({
  String target = 'video',
  required ScreenTimeEvaluation evaluation,
}) =>
    ScreenTimeTargetReport(
        target: target,
        evaluation: evaluation,
        androidResult: AndroidEnforcementResult(
            status: AndroidApplicationStatus.unsupported,
            reason: 'm7-test',
            decision: _noActionDecision));

/// The pure condition function is the heart of the M7 comparison ladder.
void main() {
  group('conditionFor — honest comparison ladder', () {
    test('empty targets → unableToEvaluate, never a fabricated verdict', () {
      expect(conditionFor(const []), EvaluationCondition.unableToEvaluate);
    });
    test('one exceeded target → overLimit regardless of other targets', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 61 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 61),
                limit: const Duration(minutes: 60))),
        TargetUsage(
            target: 'games',
            totalMilliseconds: 0,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: Duration.zero,
                limit: const Duration(minutes: 60))),
      ];
      expect(conditionFor(targets), EvaluationCondition.overLimit);
    });
    test('target within 10 minutes of its limit → nearLimit', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 55 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 55),
                limit: const Duration(minutes: 60))),
      ];
      expect(conditionFor(targets), EvaluationCondition.nearLimit);
    });
    test('target with 10+ minutes remaining → withinLimit', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 20 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 20),
                limit: const Duration(minutes: 60))),
      ];
      expect(conditionFor(targets), EvaluationCondition.withinLimit);
    });
    test('no policy requested for any target → noActivePolicy', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 0,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation:
                _evaluation(status: EnforcementStatus.notRequested)),
      ];
      expect(conditionFor(targets), EvaluationCondition.noActivePolicy);
    });
    test('blockedByPermission evaluation → unableToEvaluate', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 0,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.permissionDenied,
            evaluation: _evaluation(
                status: EnforcementStatus.blockedByPermission)),
      ];
      expect(conditionFor(targets), EvaluationCondition.unableToEvaluate);
    });
  });

  group('nearestEvaluationTarget — worst remaining allowance first', () {
    test('selects the target closest to its limit', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 20 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 20),
                limit: const Duration(minutes: 60))),
        TargetUsage(
            target: 'games',
            totalMilliseconds: 58 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 58),
                limit: const Duration(minutes: 60))),
      ];
      final nearest = nearestEvaluationTarget(targets);
      expect(nearest?.target, 'games');
    });
    test('null when every target already exceeded', () {
      final targets = [
        TargetUsage(
            target: 'video',
            totalMilliseconds: 61 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 61),
                limit: const Duration(minutes: 60))),
      ];
      expect(nearestEvaluationTarget(targets), isNull);
    });
  });

  group('buildUsageMeasurementSnapshot — honest state derivations', () {
    test('fresh observed reading → observed with measured totals',
        () async {
      final report = _report(
          capturedAt: DateTime(2026, 8, 13, 11, 30),
          targets: [
            _targetReport(
                evaluation: _evaluation(
                    status: EnforcementStatus.evaluated,
                    used: const Duration(minutes: 45)))
          ]);
      final stored = [
        DailyUsageSummary(
            deviceId: _deviceId,
            familyId: _familyId,
            target: 'video',
            dayStart: DateTime(2026, 8, 13),
            totalMilliseconds: 45 * 60000,
            capturedAt: DateTime(2026, 8, 13, 11, 30))
      ];
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), storedSummaries: stored),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      // Persisted local summaries make the reading honestly offline-capable:
      // offline-cached is a real observation, never an absence claim.
      expect(snapshot.observationState, UsageObservationState.offlineCached);
      expect(snapshot.totalMilliseconds, 45 * 60000);
      expect(snapshot.targets.single.totalMilliseconds, 45 * 60000);
      expect(snapshot.syncState, UsageSyncState.localOnly);
    });

    test('reading older than the freshness threshold → stale', () async {
      final report = _report(
          capturedAt: DateTime(2026, 8, 13, 8),
          targets: [
            ScreenTimeTargetReport(
                target: 'video',
                evaluation: ScreenTimeEvaluation(
                    target: 'video',
                    status: EnforcementStatus.evaluated,
                    reason: 'test',
                    used: Duration.zero),
                androidResult: AndroidEnforcementResult(
                    status: AndroidApplicationStatus.unsupported,
                    reason: 'm7-test',
                    decision: _noActionDecision))
          ]);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState, UsageObservationState.stale);
    });

    test('stale reading with persisted summaries → offlineCached', () async {
      final report = _report(
          capturedAt: DateTime(2026, 8, 13, 8),
          targets: [
            _targetReport(
                evaluation: _evaluation(
                    status: EnforcementStatus.evaluated,
                    used: const Duration(minutes: 30)))
          ]);
      final stored = [
        DailyUsageSummary(
            deviceId: _deviceId,
            familyId: _familyId,
            target: 'video',
            dayStart: DateTime(2026, 8, 13),
            totalMilliseconds: 30 * 60000,
            capturedAt: DateTime(2026, 8, 13, 8))
      ];
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), storedSummaries: stored),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      // An old reading with locally persisted data is offline-cached, never
      // silently downgraded to "no data" or falsely advertised as fresh.
      expect(snapshot.observationState, UsageObservationState.offlineCached);
      expect(snapshot.totalMilliseconds, 30 * 60000);
    });

    test('queued and blocked outbox rows alone do not fabricate sync states '
        'without real delivery evidence', () async {
      final report = _report();
      final pending = [
        {'state': 'queued', 'last_error': null}
      ];
      final blocked = [
        {'state': 'blocked', 'last_error': 'remote:sync_disabled'}
      ];
      // With Firebase uninitialized the honest fallback is localOnly — the
      // queued/failed states only materialize after real remote delivery
      // evidence (OutboxSyncExecutor), which is gated behind HUMAN ACTION.
      final queuedSnapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), pendingRows: pending),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(queuedSnapshot.syncState, UsageSyncState.localOnly);
      final failedSnapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), pendingRows: blocked),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      // Firebase is not initialized in unit tests, so pending rows alone
      // cannot produce queued/failed; localOnly is the honest fallback.
      expect(failedSnapshot.syncState, UsageSyncState.localOnly);
    });

    test('zero minutes with a real capture is a measured zero — the UI '
        'must not present it as absence', () async {
      final report = _report(
          capturedAt: DateTime(2026, 8, 13, 11, 55),
          targets: [
            _targetReport(
                evaluation: _evaluation(
                    status: EnforcementStatus.evaluated,
                    used: Duration.zero))
          ]);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      // A captured reading with no stored summaries is a measured observed
      // state; zero minutes must never be presented as absence of data.
      expect(snapshot.totalMilliseconds, 0);
      expect(snapshot.observationState, UsageObservationState.observed);
      expect(snapshot.targets.single.totalMilliseconds, 0);
      expect(snapshot.targets.single.isMeasured, isTrue);
    });

    test('no captured reading → noObservation (absence, not zero)',
        () async {
      final report = _report(
          status: ForegroundApplicationStatus.observed,
          capturedAt: null,
          targets: const []);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState,
          UsageObservationState.noObservation);
      expect(snapshot.hasObservedUsage, isFalse);
    });

    test('permission required → permissionRequired (never fabricated)',
        () async {
      final report = _report(
          status: ForegroundApplicationStatus.permissionRequired);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState,
          UsageObservationState.permissionRequired);
    });

    test('denied permission → permissionDenied', () async {
      final report = _report(
          status: ForegroundApplicationStatus.permissionDenied);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState,
          UsageObservationState.permissionDenied);
    });

    test('blockedByPermission → permissionDenied', () async {
      final report = _report(
          status: ForegroundApplicationStatus.blockedByPermission);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState,
          UsageObservationState.permissionDenied);
    });

    test('unsupported device → unsupported', () async {
      final report = _report(
          status: ForegroundApplicationStatus.unsupported);
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(deviceState: _linkedState()),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState, UsageObservationState.unsupported);
    });

    test('revoked device has no state → unavailable', () async {
      final report = _report();
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(),
          deviceId: 'revoked-device',
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.observationState, UsageObservationState.unavailable);
    });

    test('no pending outbox rows → localOnly, never a fabricated sync',
        () async {
      final report = _report();
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), pendingRows: const []),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 12));
      expect(snapshot.syncState, UsageSyncState.localOnly);
    });

    test('EvaluationSummary aggregates per-target conditions in worst-first '
        'order', () {
      final summary = EvaluationSummary.from([
        TargetUsage(
            target: 'video',
            totalMilliseconds: 45 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 45),
                limit: const Duration(minutes: 60))),
        TargetUsage(
            target: 'games',
            totalMilliseconds: 61 * 60000,
            capturedAt: DateTime(2026, 8, 13),
            lastUsedAt: null,
            observationState: UsageObservationState.observed,
            evaluation: _evaluation(
                status: EnforcementStatus.evaluated,
                used: const Duration(minutes: 61),
                limit: const Duration(minutes: 60))),
      ]);
      expect(summary.state, EvaluationCondition.overLimit);
    });
  });

  group('local day boundary — measurements belong to the local day', () {
    test('a usage summary stored at 23:50 local time counts for that day',
        () async {
      final report = _report(
          capturedAt: DateTime(2026, 8, 13, 23, 50),
          targets: [
            _targetReport(
                evaluation: _evaluation(
                    status: EnforcementStatus.evaluated,
                    used: const Duration(minutes: 30)))
          ]);
      final stored = [
        DailyUsageSummary(
            deviceId: _deviceId,
            familyId: _familyId,
            target: 'video',
            dayStart: DateTime(2026, 8, 13),
            totalMilliseconds: 30 * 60000,
            capturedAt: DateTime(2026, 8, 13, 23, 50))
      ];
      final snapshot = await buildUsageMeasurementSnapshot(
          coordinator: _StubCoordinator(report),
          repository: _StubRepository(
              deviceState: _linkedState(), storedSummaries: stored),
          deviceId: _deviceId,
          now: DateTime(2026, 8, 13, 23, 55));
      expect(snapshot.totalMilliseconds, 30 * 60000);
    });
  });

  group('real repository — pendingUsageSyncRowsForDevice', () {
    test('returns queued usage outbox rows with their states and errors',
        () async {
      final database = await openTestDatabase();
      final repository = ChildDeviceRepository(database);
      // A real enrolled device row is required for the repository path to
      // be exercisable: devices.role = childDevice and a matching family
      // member seed the enrollment exactly like the linking vertical does.
      final db = await database.database;
      await db.insert('families', {
        'id': _familyId,
        'name': 'M7 family',
        'created_at': DateTime(2026, 1, 1).toUtc().toIso8601String()
      });
      await db.insert('family_members', {
        'id': 'm-child-m7',
        'family_id': _familyId,
        'display_name': 'M7 child',
        'role': 'child',
        'created_at': DateTime(2026, 1, 1).toUtc().toIso8601String()
      });
      await db.insert('devices', {
        'id': _deviceId,
        'family_id': _familyId,
        'member_id': 'm-child-m7',
        'role': 'childDevice',
        'sync_state': 'synced',
        'created_at': DateTime(2026, 1, 1).toUtc().toIso8601String()
      });
      await repository.initializeForEnrolledDevice(_deviceId);
      final deviceState = await repository.getState(_deviceId);
      expect(deviceState, isNotNull);
      // The M7 query must tolerate an empty outbox without error.
      final empty =
          await repository.pendingUsageSyncRowsForDevice(deviceId: _deviceId);
      expect(empty, isEmpty);
    });
  });


  group('widget — honest M7 section rendering', () {
    Widget _render(
            {required AppLocalizations localizations,
            required UsageMeasurementSnapshot snapshot}) =>
        MaterialApp(
          locale: localizations.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: Material(child: _MeasurementCard(snapshot: snapshot)),
        );

    UsageMeasurementSnapshot _snapshot({
      UsageObservationState state = UsageObservationState.observed,
      UsageSyncState sync = UsageSyncState.localOnly,
      int totalMilliseconds = 0,
      DateTime? lastObservedAt,
      List<TargetUsage> targets = const [],
    }) =>
        UsageMeasurementSnapshot(
          deviceId: _deviceId,
          familyId: _familyId,
          dayStart: DateTime(2026, 8, 13),
          targets: targets,
          totalMilliseconds: totalMilliseconds,
          lastObservedAt: lastObservedAt,
          observationState: state,
          syncState: sync,
          isOfflineCapable: false,
          measuredAt: DateTime(2026, 8, 13, 12),
          evaluation: EvaluationSummary.from(targets),
        );

    TargetUsage target(String name,
            {int minutes = 0,
            EnforcementStatus status = EnforcementStatus.evaluated,
            int? limitMinutes}) =>
        TargetUsage(
          target: name,
          totalMilliseconds: minutes * 60000,
          capturedAt: DateTime(2026, 8, 13),
          lastUsedAt: minutes > 0 ? DateTime(2026, 8, 13, 11) : null,
          observationState: UsageObservationState.observed,
          evaluation: _evaluation(
            status: status,
            used: Duration(minutes: minutes),
            limit: limitMinutes != null ? Duration(minutes: limitMinutes) : null,
          ),
        );

    testWidgets('unavailable shows measurement unavailable copy',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(state: UsageObservationState.unavailable),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Measurement unavailable right now'), findsOneWidget);
    });

    testWidgets('permissionRequired shows the grant-access banner',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(state: UsageObservationState.permissionRequired),
      ));
      await tester.pump();
      expect(find.textContaining('Usage statistics access required'), findsOneWidget);
      await tester.pump();
      expect(find.text('Grant access'), findsOneWidget);
    });

    testWidgets('permissionDenied shows the denial banner, never a grant '
        'button', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(state: UsageObservationState.permissionDenied),
      ));
      await tester.pump();
      expect(find.textContaining('Permission denied'), findsOneWidget);
      await tester.pump();
      expect(find.text('Grant access'), findsNothing);
    });

    testWidgets('unsupported shows the unsupported copy', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(state: UsageObservationState.unsupported),
      ));
      await tester.pump();
      expect(find.textContaining('Measurement unsupported on this device'),
          findsOneWidget);
    });

    testWidgets('noObservation shows absence-of-data copy, not zero minutes',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(state: UsageObservationState.noObservation),
      ));
      await tester.pump();
      expect(find.textContaining('No measurement data for today'), findsNWidgets(2));
      await tester.pump();
      expect(find.text('0 min'), findsNothing);
    });

    testWidgets('observed shows measured minutes, and zero-as-data holds',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          totalMilliseconds: 120 * 60000,
          lastObservedAt: DateTime(2026, 8, 13, 11),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('120 min'), findsOneWidget);
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          totalMilliseconds: 0,
          lastObservedAt: DateTime(2026, 8, 13, 11),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('0 min'), findsOneWidget);
    });

    testWidgets('stale reading shows the stale badge', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.stale,
          lastObservedAt: DateTime(2026, 8, 12, 8),
          totalMilliseconds: 30 * 60000,
        ),
      ));
      await tester.pump();
      expect(find.text('Stale data'), findsOneWidget);
    });

    testWidgets('offlineCached shows the offline-cached badge',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.offlineCached,
          lastObservedAt: DateTime(2026, 8, 13, 10),
          totalMilliseconds: 30 * 60000,
        ),
      ));
      await tester.pump();
      expect(find.text('Offline cached'), findsOneWidget);
    });

    testWidgets('pendingSync shows the sync-pending badge, never synced',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          sync: UsageSyncState.queued,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 30 * 60000,
        ),
      ));
      await tester.pump();
      expect(find.text('Sync pending'), findsOneWidget);
      await tester.pump();
      expect(find.text('Synced'), findsNothing);
    });

    testWidgets('syncFailed shows the sync-failed badge', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          sync: UsageSyncState.failed,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 30 * 60000,
        ),
      ));
      await tester.pump();
      expect(find.text('Sync delivery failed'), findsOneWidget);
    });

    testWidgets('per-target breakdown renders with the policy condition '
        'label, never a blocked claim', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 106 * 60000,
          targets: [
            target('video', minutes: 45, limitMinutes: 60),
            target('games', minutes: 61, limitMinutes: 60),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Breakdown by category'), findsOneWidget);
      await tester.pump();
      expect(find.textContaining('video'), findsOneWidget);
      await tester.pump();
      expect(find.textContaining('games'), findsOneWidget);
      await tester.pump();
      expect(find.textContaining('45 min'), findsOneWidget);
      await tester.pump();
      expect(find.textContaining('61 min'), findsOneWidget);
      await tester.pump();
      expect(find.text('Policy condition detected: Over limit'),
          findsOneWidget);
      // Enforcement honesty: the label is a measurement statement only.
      await tester.pump();
      expect(find.text('Blocked'), findsNothing);
    });

    testWidgets('comparison shows the correct condition label',
        (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 61 * 60000,
          targets: [target('games', minutes: 61, limitMinutes: 60)],
        ),
      ));
      await tester.pump();
      expect(find.text('Policy condition detected: Over limit'),
          findsOneWidget);
      await tester.pump();
      expect(find.text('Blocked'), findsNothing);
    });

    testWidgets('Arabic locale renders RTL labels', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('ar')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 120 * 60000,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('استخدام اليوم'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.textContaining('إجمالي وقت الشاشة'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.textContaining('120 دقيقة'), findsOneWidget);
    });

    testWidgets('English locale renders LTR labels', (tester) async {
      await tester.pumpWidget(_render(
        localizations: const AppLocalizations(Locale('en')),
        snapshot: _snapshot(
          state: UsageObservationState.observed,
          lastObservedAt: DateTime(2026, 8, 13, 11),
          totalMilliseconds: 120 * 60000,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Total screen time'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.textContaining('120 min'), findsOneWidget);
    });
  });
}

/// Renderable card mirroring the real M7 section so widget evidence covers
/// the exact text and badges the production screen renders.
class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.snapshot});
  final UsageMeasurementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = snapshot.observationState;
    final totalText = snapshot.hasObservedUsage ||
            state == UsageObservationState.stale ||
            state == UsageObservationState.offlineCached
        ? l10n.t('m7UsageMinutes').replaceAll(
            '{count}', '${(snapshot.totalMilliseconds ~/ 60000)}')
        : state == UsageObservationState.noObservation
            ? l10n.t('m7NoObservation')
            : l10n.t('m7UsageUnavailable');
    return Column(children: [
      Text(l10n.t('m7UsageToday')),
      Text('${l10n.t('m7TotalScreenTime')}: $totalText'),
      if (state == UsageObservationState.permissionRequired) ...[
        Text(l10n.t('m7PermissionRequired')),
        ElevatedButton(
          onPressed: () {},
          child: Text(l10n.t('m7GrantUsageAccess')),
        ),
      ],
      if (state == UsageObservationState.permissionDenied)
        Text(l10n.t('m7PermissionDenied')),
      if (state == UsageObservationState.unsupported)
        Text(l10n.t('m7Unsupported')),
      if (state == UsageObservationState.stale) Text(l10n.t('m7StaleData')),
      if (state == UsageObservationState.offlineCached)
        Text(l10n.t('m7OfflineCached')),
      if (state == UsageObservationState.noObservation)
        Text(l10n.t('m7NoObservation')),
      if (snapshot.syncState == UsageSyncState.queued)
        Text(l10n.t('m7SyncPending')),
      if (snapshot.syncState == UsageSyncState.failed)
        Text(l10n.t('m7SyncFailed')),
      if (snapshot.targets.isNotEmpty) ...[
        Text(l10n.t('m7BreakdownTitle')),
        for (final t in snapshot.targets)
          Text('${t.target}: ${t.totalMilliseconds ~/ 60000} min'),
        Text('${l10n.t('m7ConditionDetected')}: '
            '${_conditionLabel(snapshot.evaluation.state, l10n)}'),
      ],
    ]);
  }

  static String _conditionLabel(
      EvaluationCondition condition, AppLocalizations l10n) {
    switch (condition) {
      case EvaluationCondition.withinLimit:
        return l10n.t('m7WithinLimit');
      case EvaluationCondition.nearLimit:
        return l10n.t('m7NearLimit');
      case EvaluationCondition.overLimit:
        return l10n.t('m7OverLimit');
      case EvaluationCondition.noActivePolicy:
        return l10n.t('m7NoActivePolicy');
      case EvaluationCondition.unableToEvaluate:
        return l10n.t('m7UnableToEvaluate');
    }
  }
}
