import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import 'firebase_session_screen.dart';
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
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FirebaseSessionScreen())),
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
                        ref.read(localeProvider.notifier).state =
                            selection.first;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text(l10n.t('settingsSaved'))));
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
          ],
        ),
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
