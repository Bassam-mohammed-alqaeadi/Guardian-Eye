import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// The single settings surface for Guardian Eye Pro.
///
/// Account/session, language and app preferences live here — never
/// inside the family-home app bar. Product voice only: no Firebase,
/// sync-queue or module terminology in primary navigation.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader(title: l10n.t('accountSession')),
            Card.filled(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/firebase-session'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.account_circle_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('notSignedIn'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right,
                        semanticLabel: l10n.t('settings')),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.t('dataSync')),
            const _SyncNowCard(),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.t('appPreferences')),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.t('languagePreference')),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                            value: 'ar',
                            label: Text(l10n.t('settingsLanguageAr')),
                            icon: const Icon(Icons.language)),
                        ButtonSegment(
                            value: 'en',
                            label: Text(l10n.t('settingsLanguageEn')),
                            icon: const Icon(Icons.language)),
                      ],
                      selected: {languageCode},
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        ref.read(localeProvider.notifier).state = next;
                        // Resolve copy in the language just chosen — the
                        // captured [l10n] is still the previous locale.
                        final nextCopy =
                            AppLocalizations(Locale(next)).t('settingsSaved');
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(nextCopy)));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.t('permissionsTitle')),
            Card.filled(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/safety/permissions'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.verified_user_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('permissionsTitle'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: l10n.t('privacyTitle')),
            Card.filled(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/privacy-controls'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.privacy_tip_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('privacyControls'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card.filled(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push('/export-controls'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.download_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('exportControls'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M9 Trigger C — canonical manual "sync now" surface.
///
/// Reflects the honest pipeline state: queued (operations waiting), syncing
/// (execution in flight), synced (nothing pending / last delivery confirmed),
/// failed (a pipeline failure was recorded). The label is derived from real
/// outbox state, never from optimistic assumptions.
class _SyncNowCard extends ConsumerStatefulWidget {
  const _SyncNowCard();

  @override
  ConsumerState<_SyncNowCard> createState() => _SyncNowCardState();
}

class _SyncNowCardState extends ConsumerState<_SyncNowCard> {
  bool _running = false;

  Future<void> _syncNow() async {
    setState(() => _running = true);
    await ref.read(syncCoordinatorProvider.notifier).executeNow();
    ref.invalidate(pendingOutboxCountProvider);
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final syncState = ref.watch(syncCoordinatorProvider);
    // Honesty: whenever a run finishes while this card is visible (startup or
    // connectivity trigger), re-read the real outbox instead of trusting a
    // count computed before the mutation was enqueued.
    ref.listen(syncCoordinatorProvider, (previous, next) {
      if ((previous?.isSyncing ?? false) && !next.isSyncing) {
        ref.invalidate(pendingOutboxCountProvider);
      }
    });
    final pending = ref.watch(pendingOutboxCountProvider);
    final pendingCount = pending.valueOrNull ?? 0;
    final syncing = syncState.isSyncing || _running;

    final String statusKey;
    if (syncing) {
      statusKey = 'syncInProgress';
    } else if (pending.hasError) {
      statusKey = 'syncUnavailable';
    } else if (syncState.lastError != null) {
      statusKey = 'syncFailed';
    } else if (pendingCount > 0) {
      statusKey = 'syncQueued';
    } else {
      statusKey = 'syncSynced';
    }

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(syncing ? Icons.sync : Icons.cloud_sync_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              syncing
                  ? l10n.t('syncInProgress')
                  : '${l10n.t(statusKey)}'
                      '${pendingCount > 0 && !pending.hasError && syncState.lastError == null ? ' ($pendingCount)' : ''}',
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: syncing ? null : _syncNow,
            child: Text(l10n.t('syncNow')),
          ),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant)));
}
