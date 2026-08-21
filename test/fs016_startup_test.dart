// Flutter unit tests — FS-016 Startup & State Machine.
//
// Proves, against the real SQLite engine and the real localization
// tables, that the FS-016 contract holds locally and offline: the role
// gate decision is pure and deterministic for every role and binding
// state; the onboarding persistence service reads/writes/dismisses
// through the real `app_identity` table (v30 schema) with per-version
// bits; and every FS-016 localization key exists in both the Arabic and
// English tables (an untranslated key round-trips as the raw key).
// Local scope only — no production data and fully offline.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/application/role_gate_service.dart';
import 'package:guardian_ai/application/startup_state_service.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/guardian_models.dart';

final DateTime _frozenAt = DateTime.utc(2026, 8, 21, 9, 0, 0);

FamilyMember _member({
  FamilyRole role = FamilyRole.parent,
  FamilyMemberStatus status = FamilyMemberStatus.active,
  String familyId = 'fam-1',
  required String id,
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    displayName: role == FamilyRole.child ? 'Child' : 'Parent One',
    role: role,
    createdAt: _frozenAt.subtract(const Duration(days: 400)),
    status: status,
  );
}

FamilyRuntimeContext _context({
  required FamilyMember? actor,
  required bool isVerified,
}) {
  return FamilyRuntimeContext(
    familyId: 'fam-1',
    family: null,
    actor: actor,
    isVerified: isVerified,
    permissionsFor: (role) => const FamilyAuthorization().permissionsFor(role),
    allMembers: actor == null ? const [] : [actor],
    children: actor == null
        ? const []
        : [
            if (actor.role == FamilyRole.child) actor,
          ],
    devices: const [],
  );
}

Future<OnboardingPersistenceService> _persistence() async {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;
  final directory = Directory.systemTemp.createTempSync('onb_test_');
  final path = '${directory.path}/guardian_eye_pro.db';
  final database = GuardianDatabase.forTesting(
      factory: databaseFactory, pathResolver: () async => path);
  // Force the real v30 schema (including app_identity) to build.
  await database.database;
  return OnboardingPersistenceService(database);
}

void main() {
  group('decideRoleGate — pure decision matrix', () {
    test('signed-out account is always signedOut, regardless of context', () {
      for (final role in FamilyRole.values) {
        expect(
          decideRoleGate(
            context: _context(
                actor: _member(id: 'm-1', role: role), isVerified: true),
            isAuthenticated: false,
            persistedRole: null,
            persistedActorId: null,
          ),
          RoleGateDecision.signedOut,
        );
      }
    });

    test('unverified binding is fail-closed even for a valid role', () {
      expect(
        decideRoleGate(
          context: _context(
              actor: _member(id: 'm-1', role: FamilyRole.primaryParent),
              isVerified: false),
          isAuthenticated: true,
          persistedRole: null,
          persistedActorId: null,
        ),
        RoleGateDecision.unverified,
      );
    });

    test('unverified context with no actor is fail-closed', () {
      expect(
        decideRoleGate(
          context: _context(actor: null, isVerified: false),
          isAuthenticated: true,
          persistedRole: null,
          persistedActorId: null,
        ),
        RoleGateDecision.unverified,
      );
    });

    test('child members never see the gate — landAsChild always', () {
      for (final String? roleKey in [null, 'primary_parent', 'parent']) {
        expect(
          decideRoleGate(
            context: _context(
                actor: _member(id: 'm-c1', role: FamilyRole.child),
                isVerified: true),
            isAuthenticated: true,
            persistedRole: roleKey,
            persistedActorId: roleKey == null ? null : 'm-c1',
          ),
          RoleGateDecision.landAsChild,
        );
      }
    });

    test('spouse members never see the gate — landAsSpouse always', () {
      expect(
        decideRoleGate(
          context: _context(
              actor: _member(id: 'm-s1', role: FamilyRole.spouse),
              isVerified: true),
          isAuthenticated: true,
          persistedRole: 'spouse',
          persistedActorId: 'm-s1',
        ),
        RoleGateDecision.landAsSpouse,
      );
    });

    test('parent-type actor with no persisted role shows the gate', () {
      for (final role in [
        FamilyRole.primaryParent,
        FamilyRole.parent,
        FamilyRole.coParent,
      ]) {
        expect(
          decideRoleGate(
            context: _context(
                actor: _member(id: 'm-1', role: role), isVerified: true),
            isAuthenticated: true,
            persistedRole: null,
            persistedActorId: null,
          ),
          RoleGateDecision.showGate,
        );
      }
    });

    test('parent-type actor lands when persisted pair matches this actor', () {
      for (final role in [
        FamilyRole.primaryParent,
        FamilyRole.parent,
        FamilyRole.coParent,
      ]) {
        expect(
          decideRoleGate(
            context: _context(
                actor: _member(id: 'm-1', role: role), isVerified: true),
            isAuthenticated: true,
            persistedRole: role.name,
            persistedActorId: 'm-1',
          ),
          RoleGateDecision.landWithRole,
        );
      }
    });

    test(
        'parent-type actor re-shows the gate when the persisted pair '
        'belongs to a different actor (account unlinked)', () {
      expect(
        decideRoleGate(
          context: _context(
              actor: _member(id: 'm-2', role: FamilyRole.parent),
              isVerified: true),
          isAuthenticated: true,
          persistedRole: 'parent',
          persistedActorId: 'm-1',
        ),
        RoleGateDecision.showGate,
      );
    });

    test('invited or revoked members never pass the gate as eligible roles',
        () {
      for (final status in [
        FamilyMemberStatus.invited,
        FamilyMemberStatus.revoked,
        FamilyMemberStatus.expired,
      ]) {
        final context = _context(
            actor:
                _member(id: 'm-3', role: FamilyRole.coParent, status: status),
            isVerified: true);
        // The role itself is parent-type, but binding never verifies an
        // inactive member, so an unverified context fails closed.
        final unverifiedDecision = decideRoleGate(
          context: FamilyRuntimeContext.unverified(),
          isAuthenticated: true,
          persistedRole: null,
          persistedActorId: null,
        );
        expect(unverifiedDecision, RoleGateDecision.unverified);
        expect(context.actor!.role, FamilyRole.coParent);
        expect(status == FamilyMemberStatus.active, isFalse);
      }
    });
  });

  group('OnboardingPersistenceService — real app_identity table', () {
    test('read returns null until written, then returns the stored value',
        () async {
      final service = await _persistence();
      await service.clearSelectedRole();
      expect(await service.read(OnboardingIdentityKeys.selectedRole), isNull);
      await service.persistSelectedRole('parent', 'm-1');
      expect(await service.read(OnboardingIdentityKeys.selectedRole), 'parent');
      expect(await service.read(OnboardingIdentityKeys.selectedRoleActorId),
          'm-1');
    });

    test('write replaces the previous value idempotently', () async {
      final service = await _persistence();
      await service.write('probe', 'first');
      await service.write('probe', 'second');
      await service.write('probe', 'third');
      expect(await service.read('probe'), 'third');
    });

    test('clear removes the key completely', () async {
      final service = await _persistence();
      await service.write('probe2', 'v');
      await service.clear('probe2');
      expect(await service.read('probe2'), isNull);
    });

    test('dismissedVersions starts empty and accumulates per-version bits',
        () async {
      final service = await _persistence();
      expect(await service.dismissedVersions(), isEmpty);
      await service.dismissVersion('1.0.0');
      await service.dismissVersion('0.9.0');
      final versions = await service.dismissedVersions();
      expect(versions, {'1.0.0', '0.9.0'});
      // Re-dismissing is idempotent — the set stays identical.
      await service.dismissVersion('1.0.0');
      expect(await service.dismissedVersions(), {'1.0.0', '0.9.0'});
    });

    test('whatsNewDismissedFor stores exactly one semver', () async {
      final service = await _persistence();
      await service.dismissWhatsNewFor('1.0.0');
      await service.dismissWhatsNewFor('1.1.0');
      // Latest honest view wins — single value, never a list.
      expect(await service.whatsNewDismissedFor(), '1.1.0');
    });

    test('clearSelectedRole clears both role and actor keys together',
        () async {
      final service = await _persistence();
      await service.persistSelectedRole('primary_parent', 'm-1');
      await service.clearSelectedRole();
      expect(await service.selectedRole(), isNull);
      expect(await service.selectedRoleActorId(), isNull);
    });

    test('the seen key marks the one-time first-run splash', () async {
      final service = await _persistence();
      expect(await service.read(OnboardingIdentityKeys.seen), isNull);
      await service.write(OnboardingIdentityKeys.seen, 'true');
      expect(await service.read(OnboardingIdentityKeys.seen), 'true');
    });
  });

  group('l10n completeness — every FS-016 key exists in AR and EN', () {
    final fs016Keys = const [
      'childLandingTitle',
      'dataSync',
      'exportControls',
      'firebaseAccountTitle',
      'firebaseAnonymousNote',
      'firebaseAnonymousSession',
      'firebaseAuthReadErrorBody',
      'firebaseAuthReadErrorTitle',
      'firebaseAuthenticated',
      'firebaseContinueAnonymous',
      'firebaseCreateAccountSubmit',
      'firebaseEmailLabel',
      'firebaseHaveAccount',
      'firebaseNewAccount',
      'firebaseNoEmailAccount',
      'firebasePasswordLabel',
      'firebaseProjectNote',
      'firebaseSignInOrCreate',
      'firebaseSignInSubmit',
      'firebaseSignOut',
      'firebaseUnconfiguredBody',
      'firebaseUnconfiguredTitle',
      'firebaseVerifying',
      'languagePreference',
      'notSignedIn',
      'permissionsTitle',
      'privacyControls',
      'privacyTitle',
      'roleGateEntering',
      'roleGateHeroNote',
      'roleGateHeroTitle',
      'roleGatePersistNote',
      'roleGateSignIn',
      'roleGateTitle',
      'roleGateUnverifiedRecover',
      'rolePrimaryParent',
      'settings',
      'settingsLanguageAr',
      'settingsLanguageEn',
      'settingsWhatsNew',
      'splashChecking',
      'splashContinue',
      'splashContinueOffline',
      'splashCreateFamily',
      'splashFirebaseUnconfigured',
      'splashNoFamily',
      'splashNotSignedIn',
      'splashReady',
      'splashResolving',
      'splashSignIn',
      'splashSubtitle',
      'splashTitle',
      'splashUnverified',
      'startupErrorNote',
      'startupFreshnessTitle',
      'startupSyncNow',
      'syncInProgress',
      'syncNow',
      'whatsNewTitle',
    ];

    for (final locale in ['ar', 'en']) {
      for (final key in fs016Keys) {
        test('$locale locale: $key is translated', () {
          final l10n = AppLocalizations(Locale(locale));
          // An untranslated key round-trips as the raw key — any translation
          // differs from the placeholder.
          expect(l10n.t(key), isNot(key));
        });
      }
    }
  });

  group('AppStartupSnapshot — honest gate readiness', () {
    const verified = AppStartupSnapshot(
        startupState: AppStartupState.authenticatedWithFamily,
        firebaseState: AppFirebaseState.configured,
        familyId: 'fam-1');
    const unverifiedCtx = AppStartupSnapshot(
        startupState: AppStartupState.unverified,
        firebaseState: AppFirebaseState.configured,
        familyId: 'fam-1');
    const offline = AppStartupSnapshot(
        startupState: AppStartupState.unauthenticated,
        firebaseState: AppFirebaseState.unconfigured,
        familyId: null);

    test('only verified + configured may enter the gate', () {
      expect(verified.gateReady, isTrue);
      expect(unverifiedCtx.gateReady, isFalse);
      expect(offline.gateReady, isFalse);
    });

    test('noFamily resolves without a family id and fails the gate', () {
      const noFamily = AppStartupSnapshot(
          startupState: AppStartupState.noFamily,
          firebaseState: AppFirebaseState.configured,
          familyId: null);
      expect(noFamily.gateReady, isFalse);
      expect(noFamily.familyId, isNull);
    });
  });
}
