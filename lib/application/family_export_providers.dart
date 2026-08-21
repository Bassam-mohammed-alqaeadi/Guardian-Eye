import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'family_context_provider.dart';
import 'guardian_providers.dart';
import '../core/database/guardian_database.dart';
import '../data/family_data_export_service.dart';
import 'privacy_purge_providers.dart';

/// Builds the shared local export engine for the current device. The
/// assembly order matters: the export surface must never be constructed
/// without the verified [reportsRepositoryProvider] (FS-009 canonical
/// reader), and the database handle it wraps is fail-closed like every
/// other repository provider in this file.
final localFamilyExportServiceProvider =
    Provider<LocalFamilyExportService>((ref) {
  return LocalFamilyExportService(
    database: GuardianDatabase.instance,
    reports: ref.watch(reportsRepositoryProvider),
  );
});

/// The honest pre-flight context for the export surface, reusing the
/// exact same verified binding as the purge precondition: no screen
/// state until the membership binding is proven, then
/// `permissionCheck` — never a false "ready".
final localExportPreconditionProvider = localPurgePreconditionProvider;

/// One notifier instance per (service, family) so the screen rebuilds with
/// a consistent state machine while the export runs.
final localExportNotifierForFamilyProvider = StateNotifierProvider.family<
    LocalExportNotifier, FamilyExportOutcome?, String>(
  (ref, String familyId) {
    final service = ref.watch(localFamilyExportServiceProvider);
    final context = ref.watch(familyRuntimeContextProvider(familyId));
    return LocalExportNotifier(
      service: service,
      familyId: familyId,
      context: context.valueOrNull ?? _unverifiedContext(familyId),
    );
  },
);

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

/// Honest state machine for one export attempt:
/// `notRequested -> confirmationRequired -> preparing -> readyToShare ->
/// sharedOrSaved`. Any authorization or assembly failure lands on
/// `failed` / `blockedPermission` — never a promoted success.
class LocalExportNotifier extends StateNotifier<FamilyExportOutcome?> {
  LocalExportNotifier({
    required LocalFamilyExportService service,
    required String familyId,
    required FamilyRuntimeContext context,
    Future<void> Function(File)? onShare,
  })  : _service = service,
        _familyId = familyId,
        _context = context,
        _onShare = onShare,
        super(null);

  final LocalFamilyExportService _service;
  final String _familyId;
  final FamilyRuntimeContext _context;
  final Future<void> Function(File)? _onShare;

  void requireConfirmation() {
    if (state != null) return;
    state = FamilyExportOutcome(state: FamilyExportState.permissionCheck,
        familyId: _familyId);
  }

  void cancel() {
    state = FamilyExportOutcome(
      state: FamilyExportState.cancelled,
      familyId: _familyId,
    );
  }

  /// Builds the export bundle. A second build after the first succeeded
  /// regenerates a fresh file (honest timestamp), not a stale copy.
  Future<void> buildExport() async {
    if (state?.state == FamilyExportState.preparing) return;
    state = FamilyExportOutcome(
      state: FamilyExportState.preparing,
      familyId: _familyId,
    );
    final outcome = await _service.run(familyId: _familyId, context: _context);
    state = outcome;
  }

  /// Marks the bundle shared/saved after the caller's share flow completes.
  /// Rejected silently only if the file no longer exists — then the honest
  /// state stays `readyToShare` with the file gone (never `failed`).
  Future<void> markShared() async {
    final file = state?.file;
    if (file == null) return;
    if (!await file.exists()) return;
    state = FamilyExportOutcome(
      state: FamilyExportState.sharedOrSaved,
      familyId: _familyId,
      file: file,
      sections: state?.sections ?? const [],
    );
    if (_onShare != null) await _onShare!(file);
  }
}
