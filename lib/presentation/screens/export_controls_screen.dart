import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/family_export_providers.dart';
import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/family_data_export_service.dart';

/// The single honest Export Controls surface for Guardian Eye Pro.
///
/// Covers exactly what the Phase 4B contract approved for local scope:
/// an authorized, versioned JSON bundle of this device's local family
/// data, shown with every real state (blocked, checking, preparing,
/// ready, shared, failed, cancelled). The screen never pretends the
/// export reaches the cloud — it is local JSON, written and validated
/// before anything is shared.
class ExportControlsScreen extends ConsumerWidget {
  const ExportControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final precondition = ref.watch(localExportPreconditionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('exportControls'))),
      body: SafeArea(
        child: precondition.when(
          data: (member) => _buildBody(context, ref, l10n, member),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: Text(l10n.t('exportUnavailable'))),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, dynamic member) {
    final dashboard = ref.read(dashboardProvider);
    final dashboardValue = dashboard.valueOrNull;
    final family = dashboardValue?.family;
    final familyId = family?.id ?? '';

    // No signed-in membership in the canonical family → honestly blocked.
    if (member == null || familyId.isEmpty) {
      return _BlockedBody(message: l10n.t('exportPermissionDenied'));
    }

    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));
    final runtimeValue = runtime.valueOrNull;
    if (runtimeValue == null || !runtimeValue.isVerified) {
      return _BlockedBody(message: l10n.t('exportPermissionDenied'));
    }

    final notifier =
        ref.watch(localExportNotifierForFamilyProvider(familyId));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _ScopeSummaryCard(),
        const SizedBox(height: 20),
        _ExportActionCard(
          notifier: notifier,
          familyId: familyId,
        ),
        const SizedBox(height: 20),
        const _LocalBoundaryCard(),
      ],
    );
  }
}

class _BlockedBody extends StatelessWidget {
  const _BlockedBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.lock_outline),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ]),
            ),
          ),
        ),
      );
}

/// The honesty panel: states plainly what goes into the bundle and what
/// is excluded by construction — the screen never implies total
/// extraction of data it is forbidden to read.
class _ScopeSummaryCard extends StatelessWidget {
  const _ScopeSummaryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(l10n.t('exportScopeTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Text(l10n.t('exportScopeIncluded')),
            const SizedBox(height: 8),
            Text(l10n.t('exportScopeExcluded')),
          ],
        ),
      ),
    );
  }
}

/// The primary action with every honest state rendered from the real
/// state machine. No "exported" claim exists until the validated file
/// is actually written and re-verified.
class _ExportActionCard extends ConsumerWidget {
  const _ExportActionCard({
    required this.notifier,
    required this.familyId,
  });
  final FamilyExportOutcome? notifier;
  final String familyId;

  Future<void> _build(WidgetRef ref) async {
    await ref
        .read(localExportNotifierForFamilyProvider(familyId).notifier)
        .buildExport();
  }

  Future<void> _share(BuildContext context, File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Guardian Eye Pro — family export',
    );
    // The originating context may be gone by the time the share sheet
    // closes; marking shared requires a living context, so the bundle
    // stays `readyToShare` on disk for the next open rather than being
    // silently claimed.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _ExportActionCardStateful(
          notifier: notifier,
          familyId: familyId,
          onBuild: () => _build(ref),
          onShare: (file) => _share(context, file));
}

class _ExportActionCardStateful extends ConsumerStatefulWidget {
  const _ExportActionCardStateful({
    required this.notifier,
    required this.familyId,
    required this.onBuild,
    required this.onShare,
  });
  final FamilyExportOutcome? notifier;
  final String familyId;
  final VoidCallback onBuild;
  final Future<void> Function(File) onShare;

  @override
  ConsumerState<_ExportActionCardStateful> createState() =>
      _ExportActionCardStatefulState();
}

class _ExportActionCardStatefulState
    extends ConsumerState<_ExportActionCardStateful> {
  void _requestBuild() {
    widget.onBuild();
  }

  Future<void> _requestShare() async {
    final file = widget.notifier?.file;
    if (file == null) return;
    await widget.onShare(file);
    if (!mounted) return;
    await ref
        .read(localExportNotifierForFamilyProvider(widget.familyId).notifier)
        .markShared();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.notifier?.state;

    String title;
    IconData icon;
    String? detail;
    bool running = false;
    bool hasFile = widget.notifier?.hasFile ?? false;

    switch (state) {
      case FamilyExportState.preparing:
        title = l10n.t('exportStatePreparing');
        icon = Icons.hourglass_bottom;
        running = true;
        break;
      case FamilyExportState.readyToShare:
        title = l10n.t('exportStateReady');
        icon = Icons.check_circle_outline;
        detail = l10n.t('exportReadyDetail');
        hasFile = true;
        break;
      case FamilyExportState.sharedOrSaved:
        title = l10n.t('exportStateShared');
        icon = Icons.file_present;
        detail = l10n.t('exportSharedDetail');
        break;
      case FamilyExportState.failed:
        title = l10n.t('exportStateFailed');
        icon = Icons.error_outline;
        detail = widget.notifier?.reason ??
            l10n.t('exportFailedDetail');
        break;
      case FamilyExportState.blockedPermission:
        title = l10n.t('exportStateBlocked');
        icon = Icons.lock_outline;
        detail = widget.notifier?.reason ??
            l10n.t('exportBlockedDetail');
        break;
      case FamilyExportState.cancelled:
        title = l10n.t('exportStateCancelled');
        icon = Icons.cancel_outlined;
        break;
      case FamilyExportState.permissionCheck:
      default:
        title = l10n.t('exportData');
        icon = Icons.download_outlined;
        break;
    }

    return Card.filled(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: running ? null : (hasFile ? null : _requestBuild),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon,
                    color: state == FamilyExportState.readyToShare ||
                            state == FamilyExportState.sharedOrSaved
                        ? null
                        : Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600))),
                if (!running && !hasFile) const Icon(Icons.chevron_right),
              ]),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              if (hasFile && state == FamilyExportState.readyToShare) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _requestShare,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.t('exportShare')),
                  ),
                ),
              ],
              if (running) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The honest boundary card: the export is local JSON on this device.
/// Nothing is written to the cloud from this surface — stated plainly.
class _LocalBoundaryCard extends StatelessWidget {
  const _LocalBoundaryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.cloud_off_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${l10n.t('exportLocalOnly')} '
                '${l10n.t('exportLocalOnlyDetail')}'),
          ),
        ]),
      ),
    );
  }
}
