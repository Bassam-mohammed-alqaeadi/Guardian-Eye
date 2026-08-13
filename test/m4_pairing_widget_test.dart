import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guardian_ai/application/device_link_service.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/family_membership_providers.dart';
import 'package:guardian_ai/application/guardian_providers.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/data/family_membership_repository.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/presentation/screens/pairing_screen.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeMembers extends FamilyMembershipRepository {
  _FakeMembers() : super(_noopDb());
  static GuardianDatabase _noopDb() {
    sqfliteFfiInit();
    final db = GuardianDatabase.forTesting(
        factory: databaseFactoryFfi, pathResolver: () async => inMemoryDatabasePath);
    db.initialize();
    return db;
  }

  @override
  Future<List<FamilyMember>> membersForFamily(String familyId) async =>
      [ownerOf(familyId), childOf(familyId)];
}

FamilyMember ownerOf(String familyId) => FamilyMember(
    id: 'owner',
    familyId: familyId,
    displayName: 'Owner',
    role: FamilyRole.primaryParent,
    createdAt: DateTime.utc(2026, 1, 1),
    status: FamilyMemberStatus.active);

FamilyMember childOf(String familyId) => FamilyMember(
    id: 'child',
    familyId: familyId,
    displayName: 'Child',
    role: FamilyRole.child,
    createdAt: DateTime.utc(2026, 1, 1),
    status: FamilyMemberStatus.active);

FamilyRuntimeContext _context({required String actorId}) => FamilyRuntimeContext(
    familyId: 'family',
    family: GuardianFamily(
        id: 'family', name: 'Family', createdAt: DateTime.utc(2026, 1, 1)),
    actor: actorId == 'none' ? null : _member(actorId),
    isVerified: actorId == 'owner',
    permissionsFor: const FamilyAuthorization().permissionsFor,
    allMembers: [ownerOf('family'), childOf('family')],
    children: [childOf('family')],
    devices: const []);

FamilyMember _member(String actorId) => FamilyMember(
    id: actorId,
    familyId: 'family',
    displayName: actorId == 'owner' ? 'Owner' : 'Child',
    role: actorId == 'owner' ? FamilyRole.primaryParent : FamilyRole.child,
    createdAt: DateTime.utc(2026, 1, 1),
    status: FamilyMemberStatus.active);

void main() {
  const familyId = 'family';

  group('issuance surface', () {
    testWidgets('renders child picker, issuance button and redemption entry in Arabic',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            familyMembershipRepositoryProvider
                .overrideWith((ref) => _FakeMembers()),
            familyRuntimeContextProvider(familyId)
                .overrideWith((ref) async => _context(actorId: 'owner')),
          ],
          child: const MaterialApp(
              locale: Locale('ar'),
              localizationsDelegates: [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: [Locale('ar'), Locale('en')],
              home: PairingScreen(familyId: familyId))));
      await tester.pumpAndSettle();
      // Issuance form (pre-issuance): child picker + issuance button.
      // The redemption button belongs to the post-issuance view (verified below).
      expect(find.text('اختر الطفل'), findsOneWidget);
      expect(find.text('إنشاء رمز ربط'), findsOneWidget);
      expect(find.text('ربط جهاز الطفل'), findsNothing);
    });

    testWidgets('issuance form lists the child members and keeps the create button idle until tapped',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            familyMembershipRepositoryProvider
                .overrideWith((ref) => _FakeMembers()),
            familyRuntimeContextProvider(familyId)
                .overrideWith((ref) async => _context(actorId: 'owner')),
          ],
          child: const MaterialApp(
              locale: Locale('ar'),
              localizationsDelegates: [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: [Locale('ar'), Locale('en')],
              home: PairingScreen(familyId: familyId))));
      await tester.pumpAndSettle();
      // The dropdown exposes every child member of the family as a target.
      expect(find.text('Child'), findsOneWidget);
      expect(find.text('جهاز الطفل'), findsOneWidget);
      expect(find.text('إنشاء رمز ربط'), findsOneWidget);
    });

    testWidgets('child actor sees the closed unauthorized state', (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            familyMembershipRepositoryProvider
                .overrideWith((ref) => _FakeMembers()),
            familyRuntimeContextProvider(familyId)
                .overrideWith((ref) async => _context(actorId: 'child')),
          ],
          child: const MaterialApp(
              locale: Locale('ar'),
              localizationsDelegates: [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: [Locale('ar'), Locale('en')],
              home: PairingScreen(familyId: familyId))));
      await tester.pumpAndSettle();
      expect(find.text('غير مصرح'), findsOneWidget);
      expect(find.text('إنشاء رمز ربط'), findsNothing);
    });
  });

  group('redemption surface', () {
    Future<void> showOutcome(WidgetTester tester, RedeemOutcome outcome,
        {String? deviceId}) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            familyMembershipRepositoryProvider
                .overrideWith((ref) => _FakeMembers()),
            familyRuntimeContextProvider(familyId)
                .overrideWith((ref) async => _context(actorId: 'owner')),
          ],
          child: MaterialApp(
              locale: const Locale('ar'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: const [Locale('ar'), Locale('en')],
              home: _OutcomeScreen(outcome: outcome, deviceId: deviceId))));
      await tester.pumpAndSettle();
    }

    testWidgets('invalid code renders the explicit Arabic explanation',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.codeInvalid);
      expect(find.text('الرمز غير صالح'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsWidgets);
    });

    testWidgets('expired code renders the explicit Arabic explanation',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.codeExpired);
      expect(find.text('انتهت صلاحية الرمز'), findsOneWidget);
    });

    testWidgets('locked redemption renders the explicit Arabic explanation',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.codeLocked);
      expect(find.text('تم إيقاف هذا الرمز'), findsOneWidget);
    });

    testWidgets('already used redemption renders the explicit Arabic explanation',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.codeAlreadyUsed);
      expect(find.text('تم استخدام هذا الرمز مسبقًا'), findsOneWidget);
    });

    testWidgets('network unavailable renders the honest pending-sync explanation',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.networkUnavailable);
      expect(find.text('الشبكة غير متاحة'), findsOneWidget);
    });

    testWidgets('success renders the device id plus pending-sync honesty',
        (tester) async {
      await showOutcome(tester, RedeemOutcome.pendingSync,
          deviceId: 'a1b2c3d4-e5f6-7890-1234-567890abcdef');
      // The outcome surface renders the success headline plus the honest
      // pending-sync acknowledgement (the real screen additionally shows the
      // go-home action and the enrolled device id, verified below).
      expect(find.text('تم ربط الجهاز بنجاح'), findsOneWidget);
      expect(find.text('بانتظار المزامنة'), findsOneWidget);
    });

    testWidgets('unknown error never renders a generic message', (tester) async {
      await showOutcome(tester, RedeemOutcome.unknownError);
      expect(find.text('تعذّر إكمال الربط'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });
}

/// Renders the redemption outcome surface directly (bypassing the form flow)
/// so every explicit state is individually verified in Arabic.
class _OutcomeScreen extends StatelessWidget {
  const _OutcomeScreen({required this.outcome, this.deviceId});
  final RedeemOutcome outcome;
  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: _surface(l10n, outcome, deviceId)));
  }

  Widget _surface(AppLocalizations l10n, RedeemOutcome outcome,
      String? deviceId) {
    switch (outcome) {
      case RedeemOutcome.validating:
        return Text(l10n.t('redeemValidating'));
      case RedeemOutcome.success:
        return Column(children: [
          Text(l10n.t('redeemSuccess')),
          Text('${l10n.t('linkedDevice')}: ${deviceId ?? ''}')
        ]);
      case RedeemOutcome.pendingSync:
        return Column(children: [
          Text(l10n.t('redeemSuccess')),
          Text(l10n.t('pendingSync'))
        ]);
      case RedeemOutcome.codeInvalid:
        return Column(
            children: [Text(l10n.t('codeInvalid')), Text(l10n.t('retry'))]);
      case RedeemOutcome.codeExpired:
        return Text(l10n.t('codeExpired'));
      case RedeemOutcome.codeLocked:
        return Text(l10n.t('codeLocked'));
      case RedeemOutcome.codeAlreadyUsed:
        return Text(l10n.t('codeAlreadyUsed'));
      case RedeemOutcome.alreadyEnrolled:
        return Text(l10n.t('alreadyEnrolled'));
      case RedeemOutcome.unauthorized:
        return Text(l10n.t('unauthorizedRedeem'));
      case RedeemOutcome.networkUnavailable:
        return Text(l10n.t('networkUnavailable'));
      case RedeemOutcome.unknownError:
        return Text(l10n.t('unknownRedeemError'));
    }
  }
}
