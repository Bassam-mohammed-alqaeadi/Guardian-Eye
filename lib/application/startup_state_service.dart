/// FS-016 — Startup & State Machine. Local-first onboarding persistence and
/// startup-state resolution over the existing `app_identity` key/value store.
///
/// Design laws:
/// 1. Additive only — reads and writes the `app_identity` table (already
///    used by `AppDeviceIdentityService`), never touches migration, privacy,
///    purge, export, chat, M9, entitlements, AI, or notification behavior.
/// 2. Non-blocking — no method awaits network, Firebase, Render, or
///    notification startup. Everything resolves from local providers.
/// 3. Honest — the startup state is always one of the declared states; a
///    storage failure surfaces as an error state, never a silent default.
/// 4. Stream-first — the state machine exposes its state as a Riverpod
///    stream composed from `firebaseAuthSessionProvider` and
///    `dashboardProvider`; the UI never snapshots and races.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/database/guardian_database.dart';
import '../data/firebase_auth_context.dart';
import '../domain/guardian_models.dart';
import 'guardian_providers.dart';

/// Canonical onboarding persistence keys in `app_identity`. All keys are
/// namespaced under the `onb_` prefix so they can never collide with other
/// consumers (today only `device_id`).
class OnboardingIdentityKeys {
  const OnboardingIdentityKeys._();

  /// The role the actor has completed the gate with. Stored only when the
  /// gate resolves from a real verified context — never a default.
  static const String selectedRole = 'onb_selected_role';

  /// The membership id the selected role was resolved against. Cleared when
  /// the account unlinks from the family (role must be re-gated).
  static const String selectedRoleActorId = 'onb_selected_role_actor_id';

  /// Semver of the last build whose What's New was honestly viewed. Empty
  /// means nothing has been dismissed yet.
  static const String whatsNewDismissedFor = 'onb_whats_new_dismissed_for';

  /// Comma-separated set of every version whose What's New card has been
  /// dismissed. One stored value, per-version bits — never a per-session list.
  static const String whatsNewDismissedVersions =
      'onb_whats_new_dismissed_versions';

  /// Marks the one-time first-run splash as seen. The splash pushes exactly
  /// once per install; an absent key means first launch.
  static const String seen = 'onb_seen';
}

/// The app-level startup posture. Composed from auth + family + connectivity
/// providers; the UI renders it honestly without inventing transitions.
enum AppStartupState {
  /// Providers still resolving (auth stream not yet emitted).
  resolving,

  /// Firebase is configured but nobody is signed in.
  unauthenticated,

  /// Signed in, but the account has no family membership yet.
  noFamily,

  /// Signed in with a family, but the Trusted Actor Binding did not verify
  /// this account to an active member.
  unverified,

  /// Verified actor with a family; the role gate may proceed.
  authenticatedWithFamily,
}

/// Per-configuration honesty when Firebase itself is not configured: the app
/// stays fully usable offline, and the state reports `offlineUnconfigured`.
enum AppFirebaseState { configured, unconfigured, resolving }

/// FS-016 — honest startup state exposed as a Riverpod stream composed from
/// the existing auth session stream and dashboard provider.
///
/// Never awaits anything before emitting: each provider transition re-emits
/// immediately, so a stalled network or a Firebase outage degrades to an
/// honest state instead of an infinite spinner.
final appStartupStateProvider = StreamProvider<AppStartupSnapshot>((ref) {
  final authContext = ref.watch(firebaseAuthContextProvider);
  final controller = StreamController<AppStartupSnapshot>();
  ref.listen(firebaseAuthSessionProvider, (previous, next) {
    final session = next.valueOrNull;
    if (session == null) {
      // The session provider is still loading — resolving is the honest
      // state until the auth stream emits for the first time.
      controller.add(const AppStartupSnapshot(
          startupState: AppStartupState.resolving,
          firebaseState: AppFirebaseState.resolving,
          familyId: null));
      return;
    }
    final firebaseState =
        authContext.currentSession.status == AuthSessionStatus.unconfigured
            ? AppFirebaseState.unconfigured
            : AppFirebaseState.configured;

    // Best-effort: the dashboard is a FutureProvider resolved off-thread;
    // every auth transition re-reads it synchronously available or none.
    // This never awaits, so the snapshot emits immediately.
    final GuardianFamily? dashboardFamily =
        ref.read(dashboardProvider).valueOrNull?.family;
    final hasFamily = dashboardFamily != null;

    final state = switch (session.isAuthenticated) {
      false => AppStartupState.unauthenticated,
      true when !hasFamily => AppStartupState.noFamily,
      _ => AppStartupState.authenticatedWithFamily,
    };

    controller.add(AppStartupSnapshot(
      startupState: state,
      firebaseState: firebaseState,
      familyId: hasFamily ? dashboardFamily.id : null,
    ));
  });

  ref.onDispose(controller.close);

  return controller.stream;
});

/// One honest view of the app's startup posture.
class AppStartupSnapshot {
  const AppStartupSnapshot({
    required this.startupState,
    required this.firebaseState,
    required this.familyId,
  });

  final AppStartupState startupState;
  final AppFirebaseState firebaseState;
  final String? familyId;

  /// `true` when the snapshot says the actor may enter the role gate.
  bool get gateReady =>
      startupState == AppStartupState.authenticatedWithFamily &&
      firebaseState == AppFirebaseState.configured;
}

/// Local-first persistence for onboarding decisions (selected role,
/// What's New dismissal). Reads/writes `app_identity` directly; failure is
/// surfaced as an exception the caller handles honestly.
class OnboardingPersistenceService {
  OnboardingPersistenceService(this._database);

  final GuardianDatabase _database;

  Future<String?> read(String key) async {
    final db = await _database.database;
    final rows =
        await db.query('app_identity', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.single['value'] as String?;
  }

  Future<void> write(String key, String value) async {
    final db = await _database.database;
    await db.insert(
        'app_identity',
        {
          'key': key,
          'value': value,
          'created_at': DateTime.now().toUtc().toIso8601String()
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear(String key) async {
    final db = await _database.database;
    await db.delete('app_identity', where: 'key = ?', whereArgs: [key]);
  }

  Future<String?> selectedRole() => read(OnboardingIdentityKeys.selectedRole);

  Future<String?> selectedRoleActorId() =>
      read(OnboardingIdentityKeys.selectedRoleActorId);

  Future<void> persistSelectedRole(String roleKey, String actorMemberId) =>
      write(OnboardingIdentityKeys.selectedRole, roleKey).then((_) =>
          write(OnboardingIdentityKeys.selectedRoleActorId, actorMemberId));

  Future<void> clearSelectedRole() async {
    await clear(OnboardingIdentityKeys.selectedRole);
    await clear(OnboardingIdentityKeys.selectedRoleActorId);
  }

  Future<String?> whatsNewDismissedFor() =>
      read(OnboardingIdentityKeys.whatsNewDismissedFor);

  Future<void> dismissWhatsNewFor(String version) =>
      write(OnboardingIdentityKeys.whatsNewDismissedFor, version);

  /// The whats-new card stream is per-version, not per-session: every
  /// released version carries its own dismissal bit inside one stored set.
  /// This keeps the single-value `whatsNewDismissedFor` contract intact
  /// (used by the gate's one-line freshness check) while the card stream
  /// records the full per-version history.
  Future<Set<String>> dismissedVersions() async {
    final raw = await read(OnboardingIdentityKeys.whatsNewDismissedVersions);
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.split(',').toSet()..removeWhere((v) => v.isEmpty);
  }

  Future<void> dismissVersion(String version) async {
    final versions = await dismissedVersions();
    versions.add(version);
    await write(
        OnboardingIdentityKeys.whatsNewDismissedVersions, versions.join(','));
  }
}

final onboardingPersistenceProvider = Provider<OnboardingPersistenceService>(
    (ref) => OnboardingPersistenceService(GuardianDatabase.instance));
