import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/database/guardian_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';

/// Deep-link entry point for a push notification. Honest by construction:
/// it never renders fabricated content. The screen verifies the referenced
/// event exists in the local SQLite store, belongs to the active family,
/// and matches the declared kind. Any failure resolves to an honest state
/// instead of the content view.
class NotificationOpenScreen extends ConsumerStatefulWidget {
  const NotificationOpenScreen(
      {super.key,
      required this.familyId,
      required this.kind,
      required this.eventId});

  final String familyId;
  final String kind;
  final String eventId;

  @override
  ConsumerState<NotificationOpenScreen> createState() =>
      _NotificationOpenScreenState();
}

class _NotificationOpenScreenState
    extends ConsumerState<NotificationOpenScreen> {
  StreamSubscription<Object?>? _eventsSub;
  _OpenState _state = _OpenState.loading;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _eventsSub = null;
    super.dispose();
  }

  Future<void> _validate() async {
    try {
      final database = await GuardianDatabase.instance.database;
      final rows = await database.query('notification_events',
          where: 'id = ? AND family_id = ? AND kind = ?',
          whereArgs: [widget.eventId, widget.familyId, widget.kind],
          limit: 1);
      if (rows.isEmpty) {
        // The event was never persisted locally — either this device did
        // not create it, or the sync has not arrived yet. Honest empty
        // resolution: the timeline shows the authoritative history.
        _state = _OpenState.notFound;
        if (mounted) setState(() {});
        return;
      }
      final session = ref.read(firebaseAuthSessionProvider);
      final isSignedIn = session.valueOrNull?.isAuthenticated ?? false;
      _state = isSignedIn ? _OpenState.ready : _OpenState.signedOut;
      if (mounted) setState(() {});
    } catch (error) {
      _detailError = error.toString();
      _state = _OpenState.error;
      if (mounted) setState(() {});
    }
  }

  void _markAcknowledged() async {
    try {
      final database = await GuardianDatabase.instance.database;
      await database.update(
          'notification_events',
          {
            'status': 'acknowledged',
            'acknowledged_at': DateTime.now().toUtc().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [widget.eventId]);
      if (mounted) {
        setState(() => _state = _OpenState.acknowledged);
      }
    } catch (error) {
      _detailError = error.toString();
      _state = _OpenState.error;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bool isSos = widget.kind == 'sos';
    final Color accent =
        isSos ? GuardianTokens.guardianTeal : GuardianTokens.guardianNavy;
    return Scaffold(
        appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('notifOpenTitle'))),
        body: _state.buildBody(
            context: context,
            accent: accent,
            l10n: l10n,
            isSos: isSos,
            onOpen: _markAcknowledged,
            error: _detailError));
  }
}

enum _OpenState { loading, notFound, signedOut, ready, acknowledged, error }

extension on _OpenState {
  Widget buildBody({
    required BuildContext context,
    required Color accent,
    required AppLocalizations l10n,
    required bool isSos,
    required VoidCallback onOpen,
    String? error,
  }) {
    final cardStyle = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)));
    switch (this) {
      case _OpenState.loading:
        return const Center(child: CircularProgressIndicator());
      case _OpenState.notFound:
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: accent),
            const SizedBox(height: 16),
            Text(l10n.t('notifNotFound'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.t('notifNotFoundHint'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ]),
        ));
      case _OpenState.signedOut:
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 48, color: accent),
            const SizedBox(height: 16),
            Text(l10n.t('notifSignedOut'),
                style: Theme.of(context).textTheme.titleMedium),
          ]),
        ));
      case _OpenState.ready:
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(isSos ? Icons.sos_rounded : Icons.shield_outlined,
                size: 48, color: accent),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: cardStyle,
                child: Column(children: [
                  Text(
                      isSos
                          ? l10n.t('notifSosKind')
                          : l10n.t('notifIncidentKind'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(l10n.t('notifReadyHint'),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center),
                ])),
            const SizedBox(height: 16),
            FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: GuardianTokens.guardianNavy),
                onPressed: onOpen,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(l10n.t('notifConfirmOpened'))),
          ]),
        ));
      case _OpenState.acknowledged:
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, size: 48, color: accent),
            const SizedBox(height: 16),
            Text(l10n.t('notifAcknowledged'),
                style: Theme.of(context).textTheme.titleMedium),
          ]),
        ));
      case _OpenState.error:
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: accent),
            const SizedBox(height: 16),
            Text(l10n.t('notifOpenError'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ]),
        ));
    }
  }
}
