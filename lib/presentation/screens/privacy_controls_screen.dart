import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/privacy_purge_providers.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/privacy_purge_repository.dart';

/// The single honest Privacy Controls surface for Guardian Eye Pro.
///
/// Covers exactly what the Phase 4B contract approved for local scope:
/// a transparent purge of this device's local family data, shown with
/// every real state (loading, blocked, in progress, completed, partial,
/// failed). Remote and cross-family boundaries are stated out loud —
/// the screen never pretends to control data it does not hold.
class PrivacyControlsScreen extends ConsumerWidget {
  const PrivacyControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final precondition = ref.watch(localPurgePreconditionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('privacyControls'))),
      body: SafeArea(
        child: precondition.when(
          data: (member) => _buildBody(context, ref, l10n, member),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              Center(child: Text(l10n.t('purgeStateUnavailable'))),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, AppLocalizations l10n,
      dynamic member) {
    final dashboard = ref.read(dashboardProvider);

    final dashboardValue = dashboard.valueOrNull;
    final family = dashboardValue?.family;
    final familyId = family?.id ?? '';

    // No signed-in membership in the canonical family → the feature is
    // honestly blocked rather than letting a child or stranger in.
    if (member == null || familyId.isEmpty) {
      return _BlockedBody(message: l10n.t('purgePermissionDenied'));
    }

    final contextProvider = familyRuntimeContextProvider(familyId);
    final runtime = ref.watch(contextProvider);

    final notifier = ref.watch(localPurgeNotifierForFamilyProvider(familyId));

    // Unverified device context (no auth binding) → blocked.
    final runtimeValue = runtime.valueOrNull;
    if (runtimeValue == null || !runtimeValue.isVerified) {
      return _BlockedBody(message: l10n.t('purgePermissionDenied'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _RetentionSummaryCard(),
        const SizedBox(height: 20),
        _PurgeActionCard(
          notifier: notifier,
          familyId: familyId,
        ),
        const SizedBox(height: 20),
        const _RemoteBoundaryCard(),
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

/// States what is retained during a purge — the honesty panel that stops
/// the screen from implying total erasure.
class _RetentionSummaryCard extends StatelessWidget {
  const _RetentionSummaryCard();

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
                  child: Text(l10n.t('purgeRetentionTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Text(l10n.t('purgeSafetyRecordsRetained')),
            const SizedBox(height: 8),
            Text(l10n.t('purgeBillingRetention90Days')),
            const SizedBox(height: 8),
            Text(l10n.t('purgeOutboxAbandoned')),
          ],
        ),
      ),
    );
  }
}

/// The destructive action with a double-confirmation dialog and every
/// honest state rendered from the real state machine.
class _PurgeActionCard extends ConsumerWidget {
  const _PurgeActionCard({
    required this.notifier,
    required this.familyId,
  });
  final LocalPurgeOutcome? notifier;
  final String familyId;

  Future<void> _confirmAndRun(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('purgeConfirmationTitle')),
        content: Text(l10n.t('purgeConfirmationBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('purgeCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('purgeConfirm')),
          ),
        ],
      ),
    );
    if (answer != true) {
      ref.read(localPurgeNotifierForFamilyProvider(familyId).notifier).cancel();
      return;
    }
    await ref
        .read(localPurgeNotifierForFamilyProvider(familyId).notifier)
        .confirmAndRun();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _PurgeActionCardStateful(
      notifier: notifier,
      familyId: familyId,
      onRun: () => _confirmAndRun(context, ref, AppLocalizations.of(context)));
}

class _PurgeActionCardStateful extends ConsumerStatefulWidget {
  const _PurgeActionCardStateful({
    required this.notifier,
    required this.familyId,
    required this.onRun,
  });
  final LocalPurgeOutcome? notifier;
  final String familyId;
  final VoidCallback onRun;

  @override
  ConsumerState<_PurgeActionCardStateful> createState() =>
      _PurgeActionCardStatefulState();
}

class _PurgeActionCardStatefulState
    extends ConsumerState<_PurgeActionCardStateful> {
  void _requestConfirmation() {
    widget.onRun();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.notifier?.state;

    String title;
    IconData icon;
    String? detail;
    bool running = false;

    switch (state) {
      case LocalPurgeState.inProgress:
        title = l10n.t('purgeStateInProgress');
        icon = Icons.hourglass_bottom;
        running = true;
        break;
      case LocalPurgeState.completed:
        title = l10n.t('purgeStateCompleted');
        icon = Icons.check_circle_outline;
        detail = l10n.t('purgeCompletedDetail');
        break;
      case LocalPurgeState.partiallyCompleted:
        title = l10n.t('purgeStatePartiallyCompleted');
        icon = Icons.error_outline;
        detail = l10n.t('purgePartiallyCompletedDetail');
        break;
      case LocalPurgeState.failed:
        title = l10n.t('purgeStateFailed');
        icon = Icons.error_outline;
        detail = l10n.t('purgeFailedDetail');
        break;
      case LocalPurgeState.blockedMigration:
        title = l10n.t('purgeStateBlockedMigration');
        icon = Icons.build_outlined;
        detail = l10n.t('purgeMigrationBlockedDetail');
        break;
      case LocalPurgeState.blockedPermission:
        title = l10n.t('purgeStateBlockedPermission');
        icon = Icons.lock_outline;
        detail = l10n.t('purgePermissionDeniedDetail');
        break;
      case LocalPurgeState.cancelled:
        title = l10n.t('purgeStateCancelled');
        icon = Icons.cancel_outlined;
        break;
      case LocalPurgeState.confirmationRequired:
      default:
        title = l10n.t('purgeLocalDataPurge');
        icon = Icons.delete_outline;
        break;
    }

    return Card.filled(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: running ? null : _requestConfirmation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon,
                    color: state == LocalPurgeState.completed
                        ? null
                        : Theme.of(context).colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                if (!running) const Icon(Icons.chevron_right),
              ]),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
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

/// The honest boundary card: this surface only touches local data. Remote
/// deletion has no implemented endpoint, and that is stated plainly.
class _RemoteBoundaryCard extends StatelessWidget {
  const _RemoteBoundaryCard();

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
            child: Text('${l10n.t('purgeRemoteDataRemains')} '
                '${l10n.t('purgeRemoteDataRemainsDetail')}'),
          ),
        ]),
      ),
    );
  }
}
