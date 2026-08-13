import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/guardian_database.dart';
import '../data/family_membership_repository.dart';

final familyMembershipRepositoryProvider =
    Provider((ref) => FamilyMembershipRepository(GuardianDatabase.instance));
final familyMembersProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).membersForFamily(familyId));
final familyInvitationsProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).invitationsForFamily(familyId));
final familyMemberDeviceCountsProvider = FutureProvider.family((ref, String familyId) =>
    ref.watch(familyMembershipRepositoryProvider).activeDeviceCountsForFamily(familyId));
