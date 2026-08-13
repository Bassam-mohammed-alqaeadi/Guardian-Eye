import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/platform/capability_gateway.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statuses = ref.watch(capabilityStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('permissionsTitle')),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(capabilityStatusProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: statuses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.t('error'))),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final status = items[index];
            final detail = !status.supported
                ? l10n.t('unsupported')
                : status.granted
                    ? l10n.t('granted')
                    : status.requiresSettings
                        ? l10n.t('settingsRequired')
                        : l10n.t('notGranted');
            return Card(
              child: ListTile(
                title: Text(_label(l10n, status.capability)),
                subtitle: Text(detail),
                trailing: status.granted
                    ? const Icon(Icons.check_circle_outline)
                    : TextButton(
                        onPressed: () async {
                          await ref
                              .read(capabilityGatewayProvider)
                              .request(status.capability);
                          ref.invalidate(capabilityStatusProvider);
                        },
                        child: Text(l10n.t('request')),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, GuardianCapability capability) =>
      switch (capability) {
        GuardianCapability.notifications => l10n.t('notification'),
        GuardianCapability.location => l10n.t('location'),
        GuardianCapability.microphone => l10n.t('microphone'),
        GuardianCapability.usageStats => l10n.t('usageStats'),
        GuardianCapability.accessibility => l10n.t('accessibility'),
        GuardianCapability.overlay => l10n.t('overlay'),
        GuardianCapability.screenCapture => l10n.t('screenCapture'),
      };
}
