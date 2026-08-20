// FS-013 Couple Harmony — honest-state checks against the real v28 SQLite
// schema: model round-trips preserve every field, the proposal lifecycle
// moves only forward (pending -> approved/rejected), handover completion is
// stamped with a timestamp, and the repository CRUD surfaces reflect exactly
// what was persisted (nothing inferred, nothing fabricated).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/couple_repository.dart';
import 'package:guardian_ai/domain/couple_harmony.dart';

Future<GuardianDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('couple-db-');
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
    'id': 'family-couple',
    'name': 'Couple Family',
    'created_at': now.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-1',
    'family_id': 'family-couple',
    'display_name': 'Parent One',
    'role': 'primary_parent',
    'status': 'active',
    'created_at': now.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'parent-2',
    'family_id': 'family-couple',
    'display_name': 'Parent Two',
    'role': 'co_parent',
    'status': 'active',
    'created_at': now.toIso8601String(),
  });
  await db.insert('family_members', {
    'id': 'child-1',
    'family_id': 'family-couple',
    'display_name': 'Child One',
    'role': 'child',
    'status': 'active',
    'created_at': now.toIso8601String(),
  });
}

void main() {
  group('CoupleLinking model', () {
    test('JSON round-trip preserves every field', () {
      final now = DateTime.utc(2025, 7, 1);
      final linking = CoupleLinking(
        familyId: 'family-couple',
        partnerMemberId: 'parent-2',
        requestState: CoupleLinkingState.requested,
        requestedBy: 'parent-1',
        requestedAt: now,
      );
      final restored = CoupleLinking.fromJson(linking.toJson());
      expect(restored.familyId, 'family-couple');
      expect(restored.partnerMemberId, 'parent-2');
      expect(restored.requestState, CoupleLinkingState.requested);
      expect(restored.requestedBy, 'parent-1');
      expect(restored.requestedAt, now);
    });

    test('accepted/declined states encode a response timestamp', () {
      final now = DateTime.utc(2025, 7, 1);
      final accepted = CoupleLinking(
        familyId: 'family-couple',
        partnerMemberId: 'parent-2',
        requestState: CoupleLinkingState.accepted,
        requestedBy: 'parent-2',
        requestedAt: now,
        respondedAt: now,
      );
      final declined = CoupleLinking(
        familyId: 'family-couple',
        partnerMemberId: 'parent-2',
        requestState: CoupleLinkingState.declined,
        requestedBy: 'parent-2',
        requestedAt: now,
        respondedAt: now,
      );
      expect(accepted.requestState, CoupleLinkingState.accepted);
      expect(accepted.respondedAt, now);
      expect(declined.requestState, CoupleLinkingState.declined);
      expect(declined.toJson()['responded_at'], isNotNull);
    });
  });

  group('CoupleRepository round-trips', () {
    late GuardianDatabase database;
    late CoupleRepository repo;

    setUp(() async {
      database = await openTestDatabase();
      await seedFamily(database);
      repo = CoupleRepository(database: database);
    });

    test('linking records persist and are scoped per family', () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.recordLinking(CoupleLinking(
        familyId: 'family-couple',
        partnerMemberId: 'parent-2',
        requestState: CoupleLinkingState.requested,
        requestedBy: 'parent-1',
        requestedAt: now,
      ));
      expect((await repo.listLinking('family-couple')).length, 1);
      expect((await repo.listLinking('family-couple')).first.partnerMemberId,
          'parent-2');
      expect((await repo.listLinking('other-family')).length, 0);
    });

    test('proposal lifecycle moves pending to approved with reviewer stamp',
        () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.recordProposal(CoupleProposal(
        id: 'prop-1',
        familyId: 'family-couple',
        kind: CoupleProposalKind.routine,
        titleKey: 'coupleProposalMorningRoutine',
        proposedBy: 'parent-1',
        status: CoupleProposalStatus.pending,
        expiresAt: now.add(const Duration(days: 7)),
        createdAt: now,
      ));
      await repo.decideProposal('family-couple', 'prop-1',
          decision: CoupleProposalStatus.approved, reviewedBy: 'parent-2');
      final props = await repo.listProposals('family-couple');
      expect(props.first.status, CoupleProposalStatus.approved);
      expect(props.first.reviewedBy, 'parent-2');
    });

    test('routine CRUD is exact: update and delete reflect reality', () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.recordRoutine(SharedRoutine(
        id: 'routine-1',
        familyId: 'family-couple',
        titleKey: 'coupleRoutineSchoolRun',
        assignedChildIds: const ['child-1'],
        weekdays: const [1, 3, 5],
        startMinute: 420,
        endMinute: 480,
        enabled: true,
        createdBy: 'parent-1',
        createdAt: now,
        updatedAt: now,
      ));
      await repo.updateRoutine('family-couple', 'routine-1', enabled: false);
      expect((await repo.listRoutines('family-couple')).first.enabled, false);
      await repo.deleteRoutine('family-couple', 'routine-1');
      expect((await repo.listRoutines('family-couple')).length, 0);
    });

    test('responsibility delegation updates only the delegate field', () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.recordResponsibility(Responsibility(
        id: 'resp-1',
        familyId: 'family-couple',
        areaKey: 'area.morningRoutine',
        ownerMemberId: 'parent-1',
        effectiveFrom: now,
        createdAt: now,
      ));
      await repo.delegateResponsibility('family-couple', 'resp-1',
          delegateMemberId: 'parent-2');
      final resp = (await repo.listResponsibilities('family-couple')).first;
      expect(resp.delegateMemberId, 'parent-2');
      expect(resp.ownerMemberId, 'parent-1');
    });

    test('handover completion stamps status and timestamp', () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.requestHandover(HandoverRequest(
        id: 'ho-1',
        familyId: 'family-couple',
        fromMemberId: 'parent-1',
        toMemberId: 'parent-2',
        status: HandoverStatus.pending,
        requestedAt: now,
        createdAt: now,
      ));
      expect((await repo.listHandovers('family-couple')).first.status,
          HandoverStatus.pending);
      await repo.completeHandover('family-couple', 'ho-1', 'parent-2');
      final done = (await repo.listHandovers('family-couple')).first;
      expect(done.status, HandoverStatus.completed);
      expect(done.completedAt, isNotNull);
    });

    test('expired proposals resolve honestly from real expiry dates', () async {
      final now = DateTime.utc(2025, 7, 1);
      await repo.recordProposal(CoupleProposal(
        id: 'prop-expired',
        familyId: 'family-couple',
        kind: CoupleProposalKind.screenTimeRule,
        titleKey: 'coupleProposalDeviceFreeEvening',
        proposedBy: 'parent-2',
        status: CoupleProposalStatus.pending,
        expiresAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 8)),
      ));
      final props = await repo.listProposals('family-couple');
      expect(props.first.status, CoupleProposalStatus.expired);
    });
  });
}
