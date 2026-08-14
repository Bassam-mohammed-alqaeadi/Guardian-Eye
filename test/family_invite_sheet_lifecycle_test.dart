import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/family_membership_providers.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/presentation/screens/family_members_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeMembershipRepository extends FamilyMembershipRepository {
  FakeMembershipRepository()
      : super(GuardianDatabase.forTesting(
            factory: databaseFactoryFfi,
            pathResolver: () async => inMemoryDatabasePath));

  final List<FamilyInvitation> invitations = [];
  final List<FamilyMember> members = [];

  @override
  Future<List<FamilyMember>> membersForFamily(String familyId) async =>
      members;

  @override
  Future<List<FamilyInvitation>> invitationsForFamily(String familyId) async =>
      List.unmodifiable(invitations);

  @override
  Future<FamilyInvitation> inviteAdult({
    required String familyId,
    required String actorMemberId,
    required String targetEmail,
    required FamilyRole proposedRole,
    Duration validity = const Duration(days: 7),
  }) async {
    final now = DateTime.utc(2026, 8, 12, 12);
    final invitation = FamilyInvitation(
        id: 'invite-new',
        familyId: familyId,
        inviterMemberId: actorMemberId,
        targetEmail: targetEmail,
        proposedRole: proposedRole,
        status: FamilyInvitationStatus.pending,
        createdAt: now,
        expiresAt: now.add(validity));
    invitations.add(invitation);
    return invitation;
  }
}

void main() {
  testWidgets('invite save closes sheet without framework assertion',
      (tester) async {
    final repo = FakeMembershipRepository();
    const familyId = 'family-repro';
    const ownerId = 'owner-repro';
    final createdAt = DateTime.utc(2026, 8, 12, 12);
    repo.members.add(FamilyMember(
        id: ownerId,
        familyId: familyId,
        displayName: 'Owner',
        role: FamilyRole.primaryParent,
        createdAt: createdAt));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        familyMembershipRepositoryProvider.overrideWithValue(repo),
        familyMembersProvider(familyId)
            .overrideWith((ref) async => repo.members),
        familyInvitationsProvider(familyId)
            .overrideWith((ref) async => repo.invitations),
        familyMemberDeviceCountsProvider(familyId)
            .overrideWith((ref) async => const {}),
        familyMemberSyncStatesProvider(familyId)
            .overrideWith((ref) async => const {}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: const FamilyMembersScreen(
            familyId: familyId, actorMemberId: ownerId),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Family members'), findsOneWidget);

    // Open the invite sheet.
    tester
        .widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Invite an adult'), findsOneWidget);

    // Fill and save.
    await tester.enterText(find.byType(TextField), 'repro@example.test');
    await tester.pump();
    await tester.tap(find.text('Save invitation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // The sheet should be closed and the screen intact.
    expect(find.text('Invite an adult'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
