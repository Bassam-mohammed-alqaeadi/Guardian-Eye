/// FS-016 — ST-005 what's-new surface.
///
/// Honest version history: each card is a real released change with a real
/// version identifier; the stream never fabricates "what's new" content, and
/// dismissing persists per-version in `app_identity` so a dismissal survives
/// restarts while a bump re-surfaces the stream.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/app_version.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';
import '../../application/startup_state_service.dart';
import '../widgets/whats_new_widgets.dart';

/// ST-003 — the offline startup card with the honest sync freshness stamp.
/// Reusable anywhere above fold: the card only reports states the sync
/// coordinator has actually measured (synced / outstanding / pipeline
/// failure), never an inferred "fresh" claim.
class StartupOfflineCard extends ConsumerWidget {
  const StartupOfflineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sync = ref.watch(syncCoordinatorProvider);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final fresh = sync.lastRunAt == null;

    return Directionality(
      textDirection: direction,
      child: GuardianCard(
        child: Row(children: [
          Icon(
            fresh ? Icons.update_outlined : Icons.cloud_done_outlined,
            size: 18,
            color: fresh
                ? GuardianTokens.statusOffline
                : GuardianTokens.guardianTeal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('startupFreshnessTitle'),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: GuardianTokens.fontFamily)),
                const SizedBox(height: 2),
                Text(
                    l10n.t(fresh
                        ? 'startupFreshnessPending'
                        : 'startupFreshnessStamp'),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: GuardianTokens.fontFamily)),
              ],
            ),
          ),
          if (sync.isSyncing) ...[
            const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ] else if (sync.hasOutstanding) ...[
            IconButton(
                tooltip: l10n.t('startupSyncNow'),
                icon: const Icon(Icons.sync_problem,
                    size: 16, color: GuardianTokens.statusOffline),
                onPressed: () =>
                    ref.read(syncCoordinatorProvider.notifier).executeNow()),
          ] else ...[
            IconButton(
                tooltip: l10n.t('startupSyncNow'),
                icon: const Icon(Icons.sync,
                    size: 16, color: GuardianTokens.guardianTeal),
                onPressed: () =>
                    ref.read(syncCoordinatorProvider.notifier).executeNow()),
          ],
        ]),
      ),
    );
  }
}

/// ST-005 — what's-new route. One card per released version; the current
/// version is always the first card, and dismissals are per-version, stored
/// in `app_identity` under the `onb_` onboarding namespace.
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  static const List<_VersionCard> _releases = [
    _VersionCard(
        version: appVersion,
        titleKey: 'whatsNewCurrentTitle',
        detailKey: 'whatsNewCurrentDetail'),
    _VersionCard(
        version: '0.9.0',
        titleKey: 'whatsNewZeroNineTitle',
        detailKey: 'whatsNewZeroNineDetail'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final dismissed = ref.watch(onboardingPersistenceProvider);

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('whatsNewTitle'),
              style: const TextStyle(fontFamily: GuardianTokens.fontFamily)),
        ),
        body: Semantics(
          label: l10n.t('whatsNewTitle'),
          child: FutureBuilder<Set<String>>(
            future: dismissed.dismissedVersions(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final dismissedVersions = snapshot.data!;
              final visible = _releases
                  .where((r) => !dismissedVersions.contains(r.version))
                  .toList();
              if (visible.isEmpty) {
                return const GuardianStateView(
                    state: GuardianViewState.empty,
                    title: 'whatsNewAllCaughtUpTitle',
                    message: 'whatsNewAllCaughtUpDetail');
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final release = visible[index];
                  return WhatsNewVersionCard(
                      version: release.version,
                      title: l10n.t(release.titleKey),
                      detail: l10n.t(release.detailKey),
                      onDismiss: () async {
                        await dismissed.dismissVersion(release.version);
                        if (context.mounted) {
                          ref.invalidate(onboardingPersistenceProvider);
                        }
                      });
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VersionCard {
  const _VersionCard(
      {required this.version, required this.titleKey, required this.detailKey});

  final String version;
  final String titleKey;
  final String detailKey;
}
