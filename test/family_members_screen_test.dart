import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/application/family_membership_providers.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/presentation/screens/family_members_screen.dart';

void main() {
  testWidgets('family members screen renders local data and exposes the owner invitation form',
      (tester) async {
    final createdAt = DateTime.utc(2026, 8, 12, 12);
    const familyId = 'family-ui-a';
    final members = [
      FamilyMember(
          id: 'owner-local-a',
          familyId: familyId,
          displayName: 'Owner',
          role: FamilyRole.primaryParent,
          createdAt: createdAt),
      FamilyMember(
          id: 'co-local-a',
          familyId: familyId,
          displayName: 'Co Parent',
          role: FamilyRole.coParent,
          accountUid: 'co-parent-uid',
          invitationId: 'invite-accepted-a',
          joinedAt: createdAt,
          createdAt: createdAt),
    ];
    final invitations = [
      FamilyInvitation(
          id: 'invite-pending-a',
          familyId: familyId,
          inviterMemberId: 'owner-local-a',
          targetEmail: 'pending@example.test',
          proposedRole: FamilyRole.coParent,
          status: FamilyInvitationStatus.pending,
          createdAt: createdAt,
          expiresAt: createdAt.add(const Duration(days: 7))),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: [
        familyMembersProvider(familyId).overrideWith((ref) async => members),
        familyInvitationsProvider(familyId)
            .overrideWith((ref) async => invitations),
        familyMemberDeviceCountsProvider(familyId)
            .overrideWith((ref) async => {'co-local-a': 1}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: [Locale('en'), Locale('ar')],
        home: FamilyMembersScreen(
            familyId: familyId, actorMemberId: 'owner-local-a'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Family members'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Co Parent'), findsOneWidget);
    expect(find.textContaining('Not connected'), findsOneWidget);
    expect(find.textContaining('1 Linked devices'), findsOneWidget);
    expect(find.text('pending@example.test'), findsOneWidget);

    tester.widget<FloatingActionButton>(find.byType(FloatingActionButton))
        .onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Invite an adult'), findsOneWidget);
    expect(find.text('Recipient email'), findsOneWidget);
    expect(find.text('Proposed role'), findsOneWidget);
    expect(find.text('Save invitation'), findsOneWidget);
  });
}
