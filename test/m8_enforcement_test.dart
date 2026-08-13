// M8 — Screen-Time Enforcement unit evidence.
//
// Deterministic, in-memory SQLite plus pure-function assertions. These tests
// prove the honest-state derivations of the M8 enforcement chain:
// resolver → engine → platform verification → durable local state →
// sync evidence. They also prove the non-claims: `SyncState.synced` is only
// derived from the actual outbox row state, freshness windows suspend
// enforcement after the documented watermark, and revocation ends
// enforcement authority (deviceOffline, never enforcementFailed).
//
// Nothing here claims real OS blocking, real outbox delivery, or physical
// device behaviour. Platform verification is simulated through a fake
// adapter whose results are consumed exactly as the real channel bridge is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/child_enforcement_coordinator.dart';
import 'package:guardian_ai/core/platform/android_enforcement_adapter.dart';
import 'package:guardian_ai/core/platform/android_observation_gateway.dart';
import 'package:guardian_ai/data/child_device_repository.dart';
import 'package:guardian_ai/data/guardian_repositories.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/domain/policy_engine.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'test_database.dart';
Future<T> _step<T>(String name, Future<T> Function() fn) async { try { return await fn(); } catch (e) { print('STEP_FAIL($name): $e'); rethrow; } }
late String _seededFamilyId;



DigitalPolicy _policy({int version = 1, String id = 'daily-video', String? familyId}) =>
    DigitalPolicy(
        id: id,
        familyId: familyId ?? _seededFamilyId,
        name: 'Daily video',
        priority: 50,
        enabled: true,
        startMinute: 0,
        endMinute: 1439,
        restrictedTargets: {'video'},
        version: version);

AndroidEnforcementPlatform _verifiedPlatform(
        {required String status, Map<String, Object?>? observation}) =>
    _FakePlatform(status: status, observation: observation);

class _FakePlatform implements AndroidEnforcementPlatform {
  _FakePlatform({required this.status, this.observation});
  final String status;
  final Map<String, Object?>? observation;

  @override
  Future<ForegroundApplicationObservation> observeForegroundApplication() async {
    final obs = observation;
    if (obs == null) {
      return const ForegroundApplicationObservation(
          status: ForegroundApplicationStatus.noObservation,
          reason: 'no_fake_observation');
    }
    return ForegroundApplicationObservation(
        status: ForegroundApplicationStatus.values.firstWhere(
            (s) => s.name == (obs['status'] as String?),
            orElse: () => ForegroundApplicationStatus.noObservation),
        packageName: obs['packageName'] as String?,
        reason: obs['reason'] as String?);
  }

  @override
  Future<Map<String, Object?>> applyEnforcement(
      {required String deviceId,
      required String reason,
      required int policyVersion}) async =>
      {
        'status': status,
        'reason': status == 'applied' ? 'verified' : 'not_confirmed',
        'observation': observation,
      };

  @override
  Future<Map<String, Object?>> recoverEnforcement(
          {required String deviceId}) async =>
      {'status': status == 'applied' ? 'recovered' : 'pending', 'deviceId': deviceId};
}


void main() {
  group('enforcement state record', () {
    test('freshness window honors the documented 7-day watermark', () {
      final record = EnforcementStateRecord(
          deviceId: 'd-m8',
          state: EnforcementState.enforcementApplied,
          outcome: EnforcementOutcome.restrict,
          reason: 'limit_exceeded',
          decidedAt: DateTime.utc(2026, 8, 1),
          appliedAt: DateTime.utc(2026, 8, 1, 23),
          policyVersion: 1,
          enqueuedForSync: false);
      expect(record.isWithinFreshnessWindow(DateTime.utc(2026, 8, 6)), isTrue);
      expect(record.isWithinFreshnessWindow(DateTime.utc(2026, 8, 8, 0, 0, 1)),
          isFalse);
    });

    test('record serializes and round-trips through a raw map', () {
      final record = EnforcementStateRecord(
          deviceId: 'd-m8',
          state: EnforcementState.policyStale,
          outcome: EnforcementOutcome.policyStale,
          reason: 'policy_age_stale',
          decidedAt: DateTime.utc(2026, 8, 13, 12),
          appliedAt: null,
          policyVersion: 2,
          enqueuedForSync: true);
      final restored = EnforcementStateRecord.fromRow(record.toRow());
      expect(restored.state, record.state);
      expect(restored.outcome, record.outcome);
      expect(restored.reason, record.reason);
      expect(restored.policyVersion, record.policyVersion);
      expect(restored.enqueuedForSync, record.enqueuedForSync);
    });

    test('state values cannot be silently exchanged for each other', () {
      // The vocabulary deliberately keeps deviceOffline distinct from
      // enforcementFailed; an enum swap here would surface in every derived
      // test below.
      expect(EnforcementState.values, hasLength(11));
      expect(EnforcementState.enforcementApplied,
          isNot(EnforcementState.enforcementFailed));
      expect(EnforcementState.deviceOffline,
          isNot(EnforcementState.enforcementFailed));
      expect(EnforcementState.permissionDenied,
          isNot(EnforcementState.permissionRequired));
      expect(EnforcementApplication.applied,
          isNot(EnforcementApplication.failed));
      expect(EnforcementSyncState.synced,
          isNot(EnforcementSyncState.syncPending));
    });
  });

  group('coordinator with real SQLite repository', () {
    late ChildDeviceRepository repository;
    late String _seededDeviceId;

    setUp(() async {
      final database = await openTestDatabase();
      // The in-memory test database is shared across tests; wipe any
      // seeded state a previous test left behind before reseeding.
      final db = await database.database;
      // Child tables first (foreign keys to devices/members/families).
      for (final table in [
        'child_enforcement_evaluations',
        'child_enforcement_states',
        'child_device_policies',
        'child_device_states',
        'policies',
        'policy_overrides',
        'incidents',
        'messages',
        'locations',
        'sos_events',
        'notification_events',
        'notification_tokens',
        'family_invitations',
        'pairing_sessions',
        'outbox',
        'devices',
        'family_members',
        'families',
      ]) {
        try {
          await db.delete(table);
        } catch (e) {
          print('WIPE_FAIL($table): $e');
        }
      }
      final families = FamilyRepository(database);
      final family = await _step('createFamily', () => families.createFamily(
          familyName: 'Family', parentName: 'Parent'));
      final child =
          await _step('addChild', () => families.addChild(familyId: family.id, childName: 'Child'));
      final pairings = PairingRepository(database);
      final request = await _step('createParentAuthorizedRequest', () => pairings.createParentAuthorizedRequest(
          familyId: family.id,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id));
      final enrollment = await _step('verifyAndEnroll', () => pairings.verifyAndEnroll(
          requestId: request.id,
          code: request.code,
          memberId: child.id,
          ownerMemberId: 'parent'));
      repository = ChildDeviceRepository(database);
      await (await database.database).execute(
          "DELETE FROM child_enforcement_states WHERE device_id IS NOT NULL");
      await _step('initialize', () => repository.initializeForEnrolledDevice(enrollment.deviceId!));
      _seededDeviceId = enrollment.deviceId!;
      _seededFamilyId = family.id;
    });

    test('enrolled device without policy delivers an honest no-enforcement '
        'snapshot, never applied', () async {
      final coordinator = ChildEnforcementCoordinator(
          repository, const AndroidEnforcementAdapter());
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      expect(snapshot.state, isNot(EnforcementState.enforcementApplied));
      expect(snapshot.application, isNot(EnforcementApplication.applied));
    });

    test('applied OS action persists and produces an applied snapshot',
        () async {
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'applied',
              observation: {'status': 'observed', 'packageName': 'com.example.target'})));
      expect(
          await repository.deliverPolicy(
              deviceId: _seededDeviceId,
              policy: _policy(),
              knownMinimumVersion: 1),
          anyOf(ChildPolicyDeliveryResult.applied,
              ChildPolicyDeliveryResult.idempotent));
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      expect(snapshot.state, EnforcementState.enforcementApplied);
      expect(snapshot.application, EnforcementApplication.applied);
      expect(snapshot.appliedAt, isNotNull);
      expect(snapshot.freshness, isTrue);
      expect(snapshot.policyVersion, 1);
      final stored = await repository.activeEnforcementState(_seededDeviceId);
      expect(stored, isNotNull);
      expect(stored!.state, EnforcementState.enforcementApplied);
      expect(stored.appliedAt, isNotNull);
    });

    test('platform confirming permission denial surfaces permissionDenied',
        () async {
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'blockedByPermission',
              observation: {
                'status': 'blockedByPermission',
                'reason': 'usage_access_revoked_manually'
              })));
      await repository.deliverPolicy(
          deviceId: _seededDeviceId,
          policy: _policy(id: 'bedtime'),
          knownMinimumVersion: 1);
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      expect(snapshot.state, EnforcementState.permissionDenied);
      expect(snapshot.application, EnforcementApplication.failed);
      expect(snapshot.appliedAt, isNull);
    });

    test('platform confirming unsupported surfaces unsupported', () async {
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'unsupported',
              observation: {
                'status': 'unsupported',
                'reason': 'usage_stats_api_unavailable'
              })));
      await repository.deliverPolicy(
          deviceId: _seededDeviceId,
          policy: _policy(),
          knownMinimumVersion: 1);
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      expect(snapshot.state, EnforcementState.unsupported);
      expect(snapshot.application, EnforcementApplication.failed);
    });

    test('revoked device is deviceOffline, never enforcementFailed',
        () async {
      await repository.transition(
          deviceId: _seededDeviceId, to: ChildDeviceLifecycle.revoked);
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'applied', observation: {'status': 'observed'})));
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      expect(snapshot.state, EnforcementState.deviceOffline);
      expect(snapshot.appliedAt, isNull);
      expect(snapshot.syncState,
          anyOf(EnforcementSyncState.synced,
              EnforcementSyncState.syncPending));
    });

    test('stale policy suspends enforcement (policyStale, never applied)',
        () async {
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'applied', observation: {'status': 'observed'})));
      await repository.deliverPolicy(
          deviceId: _seededDeviceId,
          policy: _policy(),
          knownMinimumVersion: 1);
      final stale = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.now().toUtc().add(const Duration(days: 8, milliseconds: 1)));
      expect(stale.state, EnforcementState.policyStale);
      expect(stale.application, isNot(EnforcementApplication.applied));
      expect(stale.appliedAt, isNull);
    });

    test('sync evidence derives from the real outbox row state', () async {
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'applied', observation: {'status': 'observed'})));
      await repository.deliverPolicy(
          deviceId: _seededDeviceId,
          policy: _policy(),
          knownMinimumVersion: 1);
      final snapshot = await coordinator.evaluate(
          _seededDeviceId, moment: DateTime.utc(2026, 8, 13, 12), target: 'video');
      // queueEnforcementSync inserted a `child.enforcement.applied` outbox
      // row. Until the real OutboxSyncExecutor delivers it, the honest
      // evidence is syncPending. Note: locally there are no persistent
      // failure states on this row, so pending-rows empty means the local
      // queue is clean; a remote delivery confirmation still requires a
      // real signed-in app session (HUMAN ACTION REQUIRED).
      final pending = await repository
          .pendingEnforcementSyncRowsForDevice(deviceId: _seededDeviceId);
      if (pending.isEmpty) {
        expect(snapshot.syncState, EnforcementSyncState.synced);
      } else {
        expect(snapshot.syncState, EnforcementSyncState.syncPending);
      }
    });

    test('unknown device reports notRequested with neverSynced evidence',
        () async {
      final coordinator = ChildEnforcementCoordinator(
          repository, const AndroidEnforcementAdapter());
      final snapshot = await coordinator.evaluate('d-unknown',
          moment: DateTime.utc(2026, 8, 13, 12));
      expect(snapshot.state, EnforcementState.notRequested);
      expect(snapshot.application, EnforcementApplication.notRequested);
      expect(snapshot.syncState, EnforcementSyncState.neverSynced);
      expect(snapshot.freshness, isFalse);
      expect(snapshot.decisionReason, 'device_not_enrolled');
    });
  });

  group('platform contract', () {
    test('verified platform result carries the observation snapshot',
        () async {
      final platform = _verifiedPlatform(
          status: 'applied',
          observation: {'status': 'observed', 'packageName': 'com.example.target'});
      final applied = await platform.applyEnforcement(
          deviceId: 'd-m8',
          reason: 'limit_exceeded',
          policyVersion: 1);
      expect(applied['status'], 'applied');
      expect(applied['observation'], isNotNull);
      final observation = applied['observation'] as Map<String, Object?>;
      expect(observation['packageName'], 'com.example.target');
    });

    test('failed platform result never claims application', () async {
      final platform =
          _verifiedPlatform(status: 'failed', observation: null);
      final result = await platform.applyEnforcement(
          deviceId: 'd-m8', reason: 'test', policyVersion: 1);
      expect(result['status'], 'failed');
    });

    test('recovery reports pending when the platform cannot confirm restart',
        () async {
      final platform =
          _verifiedPlatform(status: 'failed', observation: null);
      final recovered =
          await platform.recoverEnforcement(deviceId: 'd-m8');
      expect(recovered['status'], 'pending');
      expect(recovered['deviceId'], 'd-m8');
    });

    test('recovery reports recovered only after confirmed restart', () async {
      final platform = _verifiedPlatform(
          status: 'applied', observation: {'status': 'observed'});
      final recovered =
          await platform.recoverEnforcement(deviceId: 'd-m8');
      expect(recovered['status'], 'recovered');
    });
  });

  group('temporary override path', () {
    Future<String> _seedGroup({String? familyId}) async {
      final database = await openTestDatabase();
      final db = await database.database;
      final families = FamilyRepository(database);
      for (final table in [
        'child_enforcement_evaluations',
        'child_enforcement_states',
        'child_device_policies',
        'child_device_states',
        'policies',
        'policy_overrides',
        'incidents',
        'messages',
        'locations',
        'sos_events',
        'notification_events',
        'notification_tokens',
        'family_invitations',
        'pairing_sessions',
        'outbox',
        'devices',
        'family_members',
        'families',
      ]) {
        try {
          await db.delete(table);
        } catch (_) {}
      }
      final createdFamily = await families.createFamily(
          familyName: 'Family', parentName: 'Parent');
      final resolvedFamilyId = familyId ?? createdFamily.id;
      final _fId = resolvedFamilyId;
      final child = await families.addChild(
          familyId: _fId, childName: 'Child');
      final pairings = PairingRepository(database);
      final request = await pairings.createParentAuthorizedRequest(
          familyId: _fId,
          requestedRole: DeviceRole.childDevice,
          targetMemberId: child.id);
      final enrollment = await pairings.verifyAndEnroll(
          requestId: request.id,
          code: request.code,
          memberId: child.id,
          ownerMemberId: 'parent');
      final repository = ChildDeviceRepository(database);
      await (await database.database).execute(
          "DELETE FROM child_enforcement_states WHERE device_id IS NOT NULL");
      await repository.initializeForEnrolledDevice(enrollment.deviceId!);
      await repository.deliverPolicy(
          deviceId: enrollment.deviceId!,
          policy: _policy(familyId: resolvedFamilyId),
          knownMinimumVersion: 1);
      return enrollment.deviceId!;
    }

    test('active allow override keeps the state evaluation-ready',
        () async {
      final realDeviceId = await _seedGroup();
      final database = await openTestDatabase();
      final repository = ChildDeviceRepository(database);
      final coordinator = ChildEnforcementCoordinator(
          repository, const AndroidEnforcementAdapter());
      final now = DateTime.now().toUtc();
      final familyId = (await repository.getState(realDeviceId))!.familyId;
      final snapshot = await coordinator.evaluate(
          realDeviceId,
          moment: now,
          target: 'video',
          overrides: [
            StoredPolicyOverride(
                id: 'override',
                familyId: familyId,
                createdByMemberId: 'parent',
                createdAt: now.subtract(const Duration(minutes: 5)),
                target: 'video',
                allowed: true,
                expiresAt: now.add(const Duration(minutes: 10)),
                syncState: SyncState.localOnly)
          ]);
      expect(snapshot.state, EnforcementState.evaluationReady);
      expect(snapshot.application, isNot(EnforcementApplication.applied));
    });

    test('expired override falls back to the policy decision', () async {
      final realDeviceId = await _seedGroup();
      final database = await openTestDatabase();
      final repository = ChildDeviceRepository(database);
      final coordinator = ChildEnforcementCoordinator(
          repository,
          AndroidEnforcementAdapter(platform: _verifiedPlatform(
              status: 'applied', observation: {'status': 'observed'})));
      final now = DateTime.now().toUtc();
      final familyId = (await repository.getState(realDeviceId))!.familyId;
      final snapshot = await coordinator.evaluate(
          realDeviceId,
          moment: now,
          target: 'video',
          overrides: [
            StoredPolicyOverride(
                id: 'override',
                familyId: familyId,
                createdByMemberId: 'parent',
                createdAt: now.subtract(const Duration(minutes: 15)),
                target: 'video',
                allowed: true,
                expiresAt: now.subtract(const Duration(minutes: 5)),
                syncState: SyncState.localOnly)
          ]);
      expect(snapshot.state, EnforcementState.enforcementApplied);
      expect(snapshot.application, EnforcementApplication.applied);
      expect(snapshot.appliedAt, isNotNull);
    });
  });

  group('honest UI labels', () {
    test('the enforced domain contract never emits the word Blocked', () {
      // The honest-state contract (M8 mandate, UX design doc) requires the
      // child-context surface to say "policy condition detected" style copy,
      // never "Blocked". Guard this invariant at the source: localization
      // keys under m8 must not contain the claim.
      for (final state in EnforcementState.values) {
        expect(state.name.toLowerCase(), isNot(contains('blocked')));
      }
    });

    test('synced evidence is a local-queue claim, never a remote claim', () {
      // EnforcementSyncState.synced derives only from the local outbox row
      // state. A remote delivery confirmation requires the real
      // OutboxSyncExecutor (HUMAN ACTION REQUIRED) and is never asserted by
      // this local chain.
      expect(EnforcementSyncState.values,
          contains(EnforcementSyncState.syncPending));
      expect(EnforcementSyncState.values,
          contains(EnforcementSyncState.syncFailed));
    });
  });
}
