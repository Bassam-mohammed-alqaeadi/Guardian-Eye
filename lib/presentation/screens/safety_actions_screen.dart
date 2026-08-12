import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';

class SafetyActionsScreen extends ConsumerStatefulWidget {
  const SafetyActionsScreen({super.key, required this.familyId});
  final String familyId;

  @override
  ConsumerState<SafetyActionsScreen> createState() =>
      _SafetyActionsScreenState();
}

class _SafetyActionsScreenState extends ConsumerState<SafetyActionsScreen> {
  bool _working = false;
  String? _result;

  Future<void> _sendSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('sosTitle')),
        content: Text(AppLocalizations.of(context).t('sosConfirmation')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).t('sendSos'))),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _working = true);
    try {
      Position? position;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium));
      }
      await ref.read(sosRepositoryProvider).createOfflineEvent(
            familyId: widget.familyId,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracyMeters: position?.accuracy,
          );
      if (mounted) {
        setState(() => _result = AppLocalizations.of(context).t('sosStored'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = AppLocalizations.of(context).t('error'));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  Future<void> _sync() async {
    setState(() => _working = true);
    try {
      final result = await ref.read(outboxSyncExecutorProvider).executeDue();
      if (mounted) {
        setState(() => _result =
            '${AppLocalizations.of(context).t('syncResult')}: ${result.reason} '
                '(${result.synced}/${result.processed})');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = AppLocalizations.of(context).t('error'));
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('safetyActions'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.sos,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  Text(l10n.t('sosTitle'),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(l10n.t('sosDescription'), textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.tonalIcon(
                      onPressed: _working ? null : _sendSos,
                      icon: const Icon(Icons.sos),
                      label: Text(l10n.t('sendSos'))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: Text(l10n.t('syncNow')),
              subtitle: Text(l10n.t('offlineFirst')),
              trailing: FilledButton(
                  onPressed: _working ? null : _sync,
                  child: Text(l10n.t('syncNow'))),
            ),
          ),
          if (_working)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator())),
          if (_result != null)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_result!, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
