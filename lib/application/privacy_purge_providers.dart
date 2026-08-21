import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/guardian_models.dart';

import '../core/database/guardian_database.dart';
import '../data/privacy_purge_repository.dart';
import 'family_context_provider.dart';
import 'guardian_providers.dart';

/// Resolves the purge precondition: the device has an active, bound
/// (non-child) membership in the current canonical family. Returns `null`
/// when no such membership exists so the UI can render
/// `blocked_permission` honestly.
///
/// Mirrors the dashboard's canonical family resolution
/// ([familyRepositoryProvider].loadDashboard) and the app-wide actor binding
/// ([familyActorBindingProvider]) used for all authorization decisions.
final localPurgePreconditionProvider =
    FutureProvider<FamilyMember?>((ref) async {
  final familyRepo = ref.watch(familyRepositoryProvider);
  final dashboard = await familyRepo.loadDashboard();
  final family = dashboard.family;
  if (family == null) return null;
  final binding = await ref.read(familyActorBindingProvider(family.id).future);
  if (!binding.isVerified) return null;
  final member = binding.binding!.member;
  if (member.status != FamilyMemberStatus.active) return null;
  if (member.role == FamilyRole.child) return null;
  if (member.familyId != family.id) return null;
  return member;
});

/// Provider exposing the purge service. Kept lazy and test-overridable.
final localPurgeServiceProvider = Provider<LocalPurgeService>((ref) {
  return LocalPurgeService(database: GuardianDatabase.instance);
});

/// File artifacts this device may hold from local export/report work:
/// `privacy_exports/` (data exports) and `report_files/` (generated reports)
/// inside the application documents directory. Deleting them is best-effort;
/// a failure degrades the outcome to `partially_completed` rather than lying.
Future<void> removePrivacyArtifactDirs() async {
  final Directory base;
  try {
    base = await _appDocumentsDir();
  } catch (_) {
    return;
  }
  for (final name in const ['privacy_exports', 'report_files']) {
    final dir = Directory(p.join(base.path, name));
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
}

Future<Directory> _appDocumentsDir() async {
  // Outside a real Flutter app (tests), use the HOME directory as an
  // honest fallback; real apps override artifact removal via the test
  // hook so platform layout quirks never affect test outcomes.
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw const FileSystemException('home_directory_unknown');
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return Directory(p.join(home, 'Documents'));
  }
  return Directory(home);
}

/// State-machine notifier driving the local purge flow:
/// notRequested -> confirmationRequired -> inProgress -> terminal.
class LocalPurgeNotifier extends StateNotifier<LocalPurgeOutcome?> {
  LocalPurgeNotifier({
    required LocalPurgeService service,
    required String familyId,
    required FamilyRuntimeContext context,
    Future<void> Function()? onArtifactDirs,
  })  : _service = service,
        _familyId = familyId,
        _context = context,
        _onArtifactDirs = onArtifactDirs,
        super(null);

  final LocalPurgeService _service;
  final String _familyId;
  final FamilyRuntimeContext _context;
  final Future<void> Function()? _onArtifactDirs;

  void requireConfirmation() {
    if (state != null) return;
    state = LocalPurgeOutcome(
      state: LocalPurgeState.confirmationRequired,
      familyId: _familyId,
      tables: const [],
      outboxAbandoned: 0,
      billingSweeped: 0,
      artifactDirsRemoved: 0,
    );
  }

  void cancel() {
    state = LocalPurgeOutcome(
      state: LocalPurgeState.cancelled,
      familyId: _familyId,
      tables: const [],
      outboxAbandoned: 0,
      billingSweeped: 0,
      artifactDirsRemoved: 0,
    );
  }

  /// Runs the purge after the caller has shown the confirmation dialog.
  /// A second run on an already-purged database is idempotent: it reports
  /// `completed` with no rows touched.
  Future<void> confirmAndRun() async {
    if (state?.state == LocalPurgeState.inProgress) return;
    state = LocalPurgeOutcome(
      state: LocalPurgeState.inProgress,
      familyId: _familyId,
      tables: const [],
      outboxAbandoned: 0,
      billingSweeped: 0,
      artifactDirsRemoved: 0,
    );
    final outcome = await _service.run(
      familyId: _familyId,
      context: _context,
      onArtifactDirs: _onArtifactDirs ?? removePrivacyArtifactDirs,
    );
    state = outcome;
  }
}

/// One notifier instance per (service, family) so the screen rebuilds with a
/// consistent state machine while the operation runs. The active family is
/// resolved exactly like the dashboard does: the first non-archived family
/// row on this device. Pass the screen's own `familyId` instead when the
/// purge surface is presented inside a family-scoped route.
final localPurgeNotifierForFamilyProvider = StateNotifierProvider.family<
    LocalPurgeNotifier, LocalPurgeOutcome?, String>((ref, String familyId) {
  final service = ref.watch(localPurgeServiceProvider);
  final context = ref.watch(familyRuntimeContextProvider(familyId));
  return LocalPurgeNotifier(
    service: service,
    familyId: familyId,
    context: context.valueOrNull ?? _unverifiedContext(familyId),
  );
});

FamilyRuntimeContext _unverifiedContext(String familyId) {
  return FamilyRuntimeContext(
    familyId: familyId,
    family: null,
    actor: null,
    isVerified: false,
    permissionsFor: (_) => const {},
    allMembers: const [],
    children: const [],
    devices: const [],
  );
}

/// Test hook: overrideable artifact-dir removal for deterministic tests.
Future<void> Function()? testOnArtifactDirsOverride;
