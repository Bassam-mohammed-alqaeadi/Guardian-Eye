import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/guardian_database.dart';
import '../data/family_membership_repository.dart';
import '../domain/guardian_models.dart';

final familyMembershipRepositoryProvider =
    Provider((ref) => FamilyMembershipRepository(GuardianDatabase.instance));
final familyMembersProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).membersForFamily(familyId));
final familyInvitationsProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).invitationsForFamily(familyId));
final familyMemberDeviceCountsProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).activeDeviceCountsForFamily(familyId));

/// Honest per-member synchronization state derived from the SQLite outbox.
///
/// Returns, for each member identifier in the family, the worst
/// `SyncState` of any queued outbox event that targets that member.
/// Members without pending outbox activity are mapped to
/// `SyncState.localOnly` here; callers combine this with remote evidence
/// to display queued / synced / failed without ever claiming remote
/// completion without proof.
final familyMemberSyncStatesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, String familyId) async {
  final db = await GuardianDatabase.instance.database;
  final rows = await db.rawQuery(
      'SELECT aggregate_id, state FROM outbox WHERE aggregate_type = ?',
      ['familyMembership']);
  final worst = <String, int>{};
  final stateRank = <String, int>{
    SyncState.localOnly.name: 0,
    SyncState.queued.name: 1,
    SyncState.blocked.name: 2,
    SyncState.failed.name: 3,
    SyncState.synced.name: 4,
  };
  for (final row in rows) {
    final memberKey = row['aggregate_id'] as String?;
    if (memberKey == null || memberKey.isEmpty) continue;
    final state = (row['state'] as String?) ?? SyncState.queued.name;
    final rank = stateRank[state] ?? stateRank[SyncState.queued.name]!;
    final current = worst[memberKey];
    if (current == null || rank > current) {
      worst[memberKey] = rank;
    }
  }
  return worst.map(
      (memberKey, rank) =>
          MapEntry(memberKey, stateRank.entries.firstWhere((e) => e.value == rank).key));
});
