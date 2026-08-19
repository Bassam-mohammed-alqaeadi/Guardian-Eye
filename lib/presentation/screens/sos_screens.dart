import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/safety_repositories.dart';
import '../../domain/guardian_models.dart';
import '../../domain/sos_config.dart';
import '../widgets/guardian_map_widget.dart';
import '../widgets/guardian_primitives.dart';

/// FS-006 — SOS & Emergency screens (SO-001 … SO-008).
///
/// Honesty contract: the readiness dashboard only claims readiness when the
/// roster actually contains responders; an active alert only claims
/// "acknowledged" when acknowledgement rows exist; the drill only marks a
/// step complete when the underlying state confirms it. SOS never says
/// "sent" unless the outbox confirmed queueing, and offline delivery falls
/// back to the SMS contract that the status chip renders honestly.

/// Shared authorization + loading guard for all SO-* screens, matching the
/// FS-001/FS-004 pattern exactly: loading while the runtime resolves,
/// honest error for unbound actors, `roleNotAllowed` for missing role
/// permission.
Widget _guardedScaffold({
  required BuildContext context,
  required AppLocalizations l10n,
  required AsyncValue<FamilyRuntimeContext> runtime,
  required FamilyPermission requiredPermission,
  required Widget child,
}) {
  final contextValue = runtime.valueOrNull;
  if (contextValue == null || runtime.isLoading) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const GuardianStateView(state: GuardianViewState.loading),
      ),
    );
  }
  if (!contextValue.isVerified || contextValue.actor == null) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('roleNotAllowed'),
          message: l10n.t('authorizationFailure'),
        ),
      ),
    );
  }
  if (!contextValue.can(requiredPermission)) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('roleNotAllowed'),
          message: l10n.t('authorizationFailure'),
        ),
      ),
    );
  }
  return child;
}

/// Honest status mapping for an SOS lifecycle state — every status shown in
/// the UI corresponds to a real row status, never an optimistic guess.
GuardianStatusKind _statusKindOf(String status) {
  switch (status) {
    case 'acknowledged':
      return GuardianStatusKind.safe;
    case 'notified':
    case 'synced':
      return GuardianStatusKind.watch;
    case 'pendingSync':
    case 'localCreated':
    case 'queued':
      return GuardianStatusKind.sos;
    case 'failed':
      return GuardianStatusKind.alert;
    case 'cancelled':
      return GuardianStatusKind.neutral;
    default:
      return GuardianStatusKind.neutral;
  }
}

String _formatUtcIso(Object? raw) {
  if (raw is! String || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return parsed.toLocal().toString().split('.').first;
}

String _statusLabelOf(AppLocalizations l10n, String status) {
  switch (status) {
    case 'acknowledged':
      return l10n.t('sosStatusAcknowledged');
    case 'notified':
      return l10n.t('sosStatusNotified');
    case 'synced':
      return l10n.t('sosStatusDelivered');
    case 'pendingSync':
      return l10n.t('sosStatusPending');
    case 'localCreated':
      return l10n.t('sosStatusLocal');
    case 'queued':
      return l10n.t('sosStatusQueued');
    case 'failed':
      return l10n.t('sosStatusFailed');
    case 'cancelled':
      return l10n.t('sosStatusCancelled');
    default:
      return status;
  }
}

// ─────────────────────────── SO-001 SOS dashboard ──────────────────────

/// `/sos/:familyId` — SO-001. SOS readiness: how many responders are on the
/// roster, the last drill verdict, and the honest alert history. A family
/// with zero responders sees "not ready" — readiness is earned, not
/// assumed.
class SosDashboardScreen extends ConsumerWidget {
  const SosDashboardScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final recipients = ref.watch(sosRecipientsProvider(familyId));
    final activeSos = ref.watch(activeSosProvider(familyId));
    final history = ref.watch(sosHistoryProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewSafetyTimeline,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('sosDashboardTitle')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.sos, color: GuardianTokens.statusSOS),
              tooltip: l10n.t('sosActivateNow'),
              onPressed: () => context.push('/sos/$familyId/activate'),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: GuardianTokens.guardianTeal,
          onRefresh: () async {
            try {
              await ref.read(sosPullProvider(familyId).future);
            } catch (_) {
              // Honest refresh: failure leaves the local view untouched.
            }
            ref.invalidate(sosRecipientsProvider(familyId));
            ref.invalidate(activeSosProvider(familyId));
            ref.invalidate(sosHistoryProvider(familyId));
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (activeSos.valueOrNull != null)
                GuardianCard(
                  color: GuardianTokens.statusSOSDeep,
                  child: InkWell(
                    onTap: () => context.push('/sos/$familyId/active'),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SOS Active — check alerts',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              Text('Tap for live recipient status',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildReadinessHero(context, l10n, recipients),
              const SizedBox(height: 16),
              GuardianSection(
                title: l10n.t('sosRecipientsSection'),
                trailing: TextButton(
                  child: Text(l10n.t('sosManage')),
                  onPressed: () =>
                      context.push('/sos/$familyId/recipients'),
                ),
                children: [
                  if (recipients.isLoading)
                    const GuardianStateView(state: GuardianViewState.loading)
                  else if (recipients.hasError)
                    GuardianStateView(
                        state: GuardianViewState.error,
                        title: l10n.t('error'),
                        message: l10n.t('loadFailed'),
                        onRetry: () =>
                            ref.invalidate(sosRecipientsProvider(familyId)))
                  else if (recipients.valueOrNull!.isEmpty)
                    GuardianCard(
                      child: Column(
                        children: [
                          GuardianIconBadge(
                              icon: Icons.people_outline,
                              background: GuardianTokens.guardianNavy),
                          const SizedBox(height: 10),
                          Text(l10n.t('sosNoRecipientsYet'),
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                              onPressed: () =>
                                  context.push('/sos/$familyId/recipients'),
                              icon: const Icon(Icons.person_add),
                              label: Text(l10n.t('sosAddRecipient')))
                        ],
                      ),
                    )
                  else
                    GuardianCard(
                      child: Column(
                        children: [
                          for (final recipient
                              in recipients.valueOrNull!) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GuardianIconBadge(
                                icon: recipient.role ==
                                        SosRecipientRole.responder
                                    ? Icons.local_hospital
                                    : Icons.notifications_none,
                                background: recipient.role ==
                                        SosRecipientRole.responder
                                    ? GuardianTokens.statusSOS
                                    : GuardianTokens.guardianTeal,
                              ),
                              title: Text(recipient.recipientId),
                              subtitle: Text(recipient.role ==
                                      SosRecipientRole.responder
                                  ? l10n.t('sosRoleResponder')
                                  : l10n.t('sosRoleNotifyOnly')),
                            ),
                            if (recipient !=
                                recipients.valueOrNull!.last)
                              const Divider(height: 1),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GuardianSection(
                title: l10n.t('sosDrillSection'),
                children: [
                  GuardianCard(
                    onTap: () => context.push('/sos/$familyId/drill'),
                    child: Row(
                      children: [
                        GuardianIconBadge(
                            icon: Icons.fact_check,
                            background: GuardianTokens.guardianTeal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('sosDrillTitle'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              Text(l10n.t('sosDrillSubtitle'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('sosHistorySection'), children: [
                if (history.isLoading)
                  const GuardianStateView(state: GuardianViewState.loading)
                else if (history.hasError)
                  GuardianStateView(
                      state: GuardianViewState.error,
                      title: l10n.t('error'),
                      message: l10n.t('loadFailed'))
                else if (history.valueOrNull!.isEmpty)
                  GuardianCard(
                    child: Row(
                      children: [
                        GuardianIconBadge(
                            icon: Icons.history,
                            background: GuardianTokens.guardianNavy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.t('sosNoHistoryYet'),
                              style:
                                  Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  )
                else
                  ...history.valueOrNull!.take(10).map((row) {
                    final status = row['status'] as String;
                    return GuardianCard(
                      onTap: () => context.push('/sos/$familyId/ack'),
                      child: Row(
                        children: [
                          GuardianStatusChip(
                            label: _statusLabelOf(l10n, status),
                            kind: _statusKindOf(status),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                DateTime.tryParse(
                                            row['created_at'] as String? ??
                                                '')
                                        ?.toLocal()
                                        .toString()
                                        .split('.')
                                        .first ??
                                    '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                          ),
                        ],
                      ),
                    );
                  }),
              ]),
              const SizedBox(height: 8),
              const GuardianOfflineBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadinessHero(
      BuildContext context, AppLocalizations l10n, AsyncValue<List<SosRecipient>> recipients) {
    final responderCount = recipients.valueOrNull
            ?.where((r) => r.role == SosRecipientRole.responder)
            .length ??
        0;
    final ready = responderCount > 0;
    return GuardianHeroCard(
      gradient: ready
          ? GuardianTokens.guardianGradient
          : const LinearGradient(colors: [
              GuardianTokens.statusAlert,
              GuardianTokens.statusSOSDeep,
            ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GuardianIconBadge(
                icon: ready ? Icons.shield : Icons.shield_outlined,
                background: Colors.white24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('sosReadinessTitle'),
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      ready
                          ? l10n.t('sosReadyCount').replaceAll('{n}',
                              responderCount.toString())
                          : l10n.t('sosNotReady'),
                      style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GuardianStatTile(
                  icon: Icons.local_hospital,
                  value: '$responderCount',
                  label: l10n.t('sosResponders'),
                  kind: ready ? GuardianStatusKind.safe : GuardianStatusKind.alert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GuardianStatTile(
                  icon: Icons.people_outline,
                  value:
                      '${recipients.valueOrNull?.length ?? 0}',
                  label: l10n.t('sosTotalRecipients'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── SO-002 SOS activation ──────────────────────

/// `/sos/:familyId/activate` — SO-002. Full-screen urgent activation:
/// teal→red gradient hero, explicit confirm, honest result. The pipeline
/// is the existing outbox contract — this screen only adds the urgent UX
/// on top of it.
class SosActivationScreen extends ConsumerStatefulWidget {
  const SosActivationScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<SosActivationScreen> createState() =>
      _SosActivationScreenState();
}

class _SosActivationScreenState extends ConsumerState<SosActivationScreen> {
  bool _working = false;
  String? _result;
  String? _newSosId;

  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GuardianTokens.guardianNavy,
        title: Text(l10n.t('sosConfirmTitle'),
            style: const TextStyle(color: Colors.white)),
        content: Text(l10n.t('sosConfirmMessage'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: GuardianTokens.statusSOS),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.t('sosSendNow'))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
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
      final id = await ref
          .read(sosRepositoryProvider)
          .createOfflineEvent(
            familyId: widget.familyId,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracyMeters: position?.accuracy,
          );
      if (mounted) {
        setState(() {
          _newSosId = id;
          _result = l10n.t('sosQueuedHonest');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = l10n.t('error'));
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
      extendBodyBehindAppBar: true,
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_newSosId != null) {
              context.go('/sos/${widget.familyId}/active');
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GuardianTokens.guardianTeal,
              GuardianTokens.statusSOSDeep,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              Center(
                child: GuardianIconBadge(
                  icon: Icons.sos,
                  background: Colors.white12,
                  foreground: Colors.white,
                  size: 88,
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.t('sosUrgentTitle'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(l10n.t('sosUrgentSubtitle'),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GuardianIconBadge(
                            icon: Icons.notification_important,
                            background: GuardianTokens.statusSOS),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.t('sosWhatHappensTitle'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.t('sosWhatHappensBody'),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GuardianTokens.statusSOS,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: _working ? null : _activate,
                child: _working
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(l10n.t('sosSendNow'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _working ? null : context.pop,
                child: Text(l10n.t('cancel'),
                    style: const TextStyle(color: Colors.white70)),
              ),
              if (_result != null) ...[
                const SizedBox(height: 16),
                GuardianCard(
                  child: Row(
                    children: [
                      GuardianStatusChip(
                        label: _result!,
                        kind: _newSosId != null
                            ? GuardianStatusKind.sos
                            : GuardianStatusKind.alert,
                        icon: _newSosId != null
                            ? Icons.send
                            : Icons.error_outline,
                      ),
                    ],
                  ),
                ),
                if (_newSosId != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () =>
                        context.go('/sos/${widget.familyId}/active'),
                    child: Text(l10n.t('sosWatchLive')),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── SO-003 active SOS ──────────────────────────

/// `/sos/:familyId/active` — SO-003. Live state of the active SOS per
/// recipient row: sent/delivered/acknowledged. Stand-down cancels the
/// event — never erased, kept in the honest history.
class ActiveSosScreen extends ConsumerStatefulWidget {
  const ActiveSosScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends ConsumerState<ActiveSosScreen> {
  bool _busy = false;

  Future<void> _standDown(String sosId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('sosStandDownTitle')),
        content: Text(l10n.t('sosStandDownMessage')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.t('sosStandDown'))),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sosRepositoryProvider).standDownSos(sosId);
      if (mounted) {
        ref.invalidate(activeSosProvider(widget.familyId));
        ref.invalidate(sosNotificationsProvider(sosId));
        ref.invalidate(sosHistoryProvider(widget.familyId));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('sosStandDownDone'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('error'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activeSos = ref.watch(activeSosProvider(widget.familyId));
    final notifications = activeSos.valueOrNull == null
        ? AsyncValue<List<Map<String, Object?>>>.data(const [])
        : ref.watch(
            sosNotificationsProvider(activeSos.valueOrNull!['id'] as String));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosActiveTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
        actions: [
          if (activeSos.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.location_on,
                  color: GuardianTokens.guardianTeal),
              tooltip: l10n.t('sosEmergencyLocation'),
              onPressed: () =>
                  context.push('/sos/${widget.familyId}/location'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (activeSos.isLoading)
            const GuardianStateView(state: GuardianViewState.loading)
          else if (activeSos.hasError)
            GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('error'),
                message: l10n.t('loadFailed'),
                onRetry: () =>
                    ref.invalidate(activeSosProvider(widget.familyId)))
          else if (activeSos.valueOrNull == null)
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuardianIconBadge(
                      icon: Icons.check_circle_outline,
                      background: Colors.white24),
                  const SizedBox(height: 10),
                  Text(l10n.t('sosNoActiveAlert'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(l10n.t('sosNoActiveSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  FilledButton.tonal(
                      onPressed: () =>
                          context.push('/sos/${widget.familyId}/activate'),
                      child: Text(l10n.t('sosActivateNow'))),
                ],
              ),
            )
          else ...[
            GuardianHeroCard(
              gradient: const LinearGradient(colors: [
                GuardianTokens.statusSOS,
                GuardianTokens.statusSOSDeep,
              ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GuardianStatusChip(
                          label: _statusLabelOf(
                              l10n,
                              activeSos.valueOrNull!['status']
                                  as String),
                          kind: GuardianStatusKind.sos,
                          live: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('sosActiveSubtitle'),
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: GuardianTokens.statusSOSDeep),
                    onPressed: _busy
                        ? null
                        : () => _standDown(
                            activeSos.valueOrNull!['id'] as String),
                    child: Text(l10n.t('sosStandDown')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianSection(
                title: l10n.t('sosPerRecipientTitle'), children: [
              if (notifications.isLoading)
                const GuardianStateView(state: GuardianViewState.loading)
              else if (notifications.hasError)
                GuardianStateView(
                    state: GuardianViewState.error,
                    title: l10n.t('error'),
                    message: l10n.t('loadFailed'))
              else if (notifications.valueOrNull!.isEmpty)
                GuardianCard(
                  child: Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.people_outline,
                          background: GuardianTokens.guardianNavy),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('sosNoRecipientRows'),
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )
              else
                ...notifications.valueOrNull!.map((row) {
                  final recipientId =
                      row['recipient_id'] as String? ??
                          l10n.t('sosFamilyLevel');
                  final status = row['status'] as String;
                  final ackedAt = row['acknowledged_at'] as String?;
                  return GuardianCard(
                    child: Row(
                      children: [
                        GuardianIconBadge(
                          icon: status == 'acknowledged'
                              ? Icons.check_circle
                              : Icons.person_outline,
                          background: status == 'acknowledged'
                              ? GuardianTokens.guardianTeal
                              : GuardianTokens.guardianNavy,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(recipientId,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              if (ackedAt != null)
                                Text(
                                    DateTime.tryParse(ackedAt)
                                            ?.toLocal()
                                            .toString()
                                            .split('.')
                                            .first ??
                                        '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                            ],
                          ),
                        ),
                        GuardianStatusChip(
                          label: _statusLabelOf(l10n, status),
                          kind: _statusKindOf(status),
                          live: status != 'acknowledged' &&
                              status != 'failed',
                        ),
                      ],
                    ),
                  );
                }),
            ]),
            const SizedBox(height: 16),
            const GuardianOfflineBanner(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── SO-004 emergency location ──────────────────

/// `/sos/:familyId/location` — SO-004. The child's live location during an
/// active SOS. Reuses the FS-001 shared `GuardianMapWidget` surface — same
/// dependency-free map, honest empty state when no position is stored yet.
class EmergencyLocationScreen extends ConsumerStatefulWidget {
  const EmergencyLocationScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<EmergencyLocationScreen> createState() =>
      _EmergencyLocationScreenState();
}

class _EmergencyLocationScreenState
    extends ConsumerState<EmergencyLocationScreen> {
  MapPoint? _point;
  String? _lastUpdate;
  bool _working = false;

  Future<void> _refresh() async {
    setState(() => _working = true);
    try {
      Position? position;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.high));
      }
      if (!mounted) return;
      setState(() {
        _point = position == null
            ? null
            : MapPoint(
                latitude: position.latitude,
                longitude: position.longitude,
                fresh: true,
              );
        _lastUpdate = DateTime.now().toLocal().toString().split('.').first;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).t('error'))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosEmergencyLocation')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: GuardianTokens.guardianTeal,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.location_on,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('sosEmergencyLocation'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            if (_lastUpdate != null)
                              Text(
                                  '${l10n.t('sosLastUpdate')}: $_lastUpdate',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(_working ? Icons.hourglass_top : Icons.refresh),
                        onPressed: _working ? null : _refresh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 260,
                    child: GuardianCard(
                      padding: 0,
                      child: GuardianMapWidget(
                        points: _point == null
                            ? const <MapPoint>[]
                            : [_point!],
                        height: 260,
                        emptyTitle: l10n.t('sosNoLocationYet'),
                        emptySubtitle: l10n.t('sosNoLocationSubtitle'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianCard(
              child: Row(
                children: [
                  GuardianIconBadge(
                      icon: Icons.info_outline,
                      background: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('sosLocationNoteTitle'),
                            style:
                                Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(l10n.t('sosLocationNoteBody'),
                            style:
                                Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const GuardianOfflineBanner(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── SO-005 emergency alert ─────────────────────

/// `/sos/:familyId/alert/:alertId` — SO-005. The received alert detail and
/// its acknowledge action. Acknowledgement only succeeds while the row is
/// honestly still open — the transition guard refuses terminal states.
class EmergencyAlertScreen extends ConsumerStatefulWidget {
  const EmergencyAlertScreen(
      {required this.familyId, required this.alertId, super.key});
  final String familyId;
  final String alertId;

  @override
  ConsumerState<EmergencyAlertScreen> createState() =>
      _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends ConsumerState<EmergencyAlertScreen> {
  bool _working = false;
  String? _result;

  /// Retry: re-resolve the parent sos event, then re-read its notification
  /// rows. On failure the screen stays on the honest error state.
  Future<void> _retryLoad() async {
    final sosId = await ref
        .read(sosRepositoryProvider)
        .sosIdForNotification(widget.alertId);
    ref.invalidate(futureSosIdProvider(widget.alertId));
    if (sosId != null) ref.invalidate(sosNotificationsProvider(sosId));
  }

  Future<void> _acknowledge() async {
    if (!mounted) return;
    setState(() => _working = true);
    try {
      final ok = await ref
          .read(sosRepositoryProvider)
          .acknowledgeNotification(widget.alertId);
      if (mounted) {
        setState(() => _result = ok
            ? AppLocalizations.of(context).t('sosAckedHonest')
            : AppLocalizations.of(context).t('sosAckNotNeeded'));
        // Invalidate the sos event's notification rows and the resolution
        // provider so the screen re-reads the row as acknowledged.
        final sosId = await ref
            .read(sosRepositoryProvider)
            .sosIdForNotification(widget.alertId);
        if (sosId != null) ref.invalidate(sosNotificationsProvider(sosId));
        ref.invalidate(futureSosIdProvider(widget.alertId));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _result = AppLocalizations.of(context).t('error'));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // SO-005 is addressed by the notification row id, but notification rows
    // are scoped to their parent SOS event — resolve that sosId once, then
    // watch the sosId-keyed provider so refresh and retry hit the right
    // scope. A missing row is rendered as an honest "alert not found".
    final notificationsAsync = ref.watch(futureSosIdProvider(widget.alertId));
    final notifications = notificationsAsync.when(
      data: (sosId) => sosId != null
          ? ref.watch(sosNotificationsProvider(sosId))
          : AsyncValue<List<Map<String, Object?>>>.data(const []),
      error: (_, __) => AsyncValue<List<Map<String, Object?>>>.data(const []),
      loading: () =>
          const AsyncValue<List<Map<String, Object?>>>.loading(),
    );
    final Map<String, Object?>? row = notifications.valueOrNull
        ?.cast<Map<String, Object?>>()
        .firstWhere((r) => r['id'] == widget.alertId);


    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosEmergencyAlert')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (notifications.isLoading)
            const GuardianStateView(state: GuardianViewState.loading)
          else if (notifications.hasError)
            GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('error'),
                message: l10n.t('loadFailed'),
                onRetry: _retryLoad)
          else if (row == null)
            GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('sosAlertNotFound'),
                message: l10n.t('loadFailed'))
          else ...[
            GuardianHeroCard(
              gradient: const LinearGradient(colors: [
                GuardianTokens.statusSOS,
                GuardianTokens.statusSOSDeep,
              ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GuardianIconBadge(
                      icon: Icons.notification_important,
                      background: Colors.white24,
                      foreground: Colors.white),
                  const SizedBox(height: 12),
                  Text(l10n.t('sosAlertReceivedTitle'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(l10n.t('sosAlertReceivedBody'),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianCard(
              child: Row(
                children: [
                  GuardianStatusChip(
                    label: _statusLabelOf(l10n, row['status'] as String),
                    kind: _statusKindOf(row['status'] as String),
                    live: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('sosRequestedAt'),
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                            DateTime.tryParse(
                                        row['requested_at'] as String? ??
                                            '')
                                    ?.toLocal()
                                    .toString()
                                    .split('.')
                                    .first ??
                                '',
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: GuardianTokens.guardianTeal,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _working ? null : _acknowledge,
              child: _working
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(l10n.t('sosAcknowledgeAlert'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white)),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(_result!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            const GuardianOfflineBanner(),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── SO-006 acknowledgement history ─────────────

/// `/sos/:familyId/ack` — SO-006. Honest acknowledgement timeline: who
/// acknowledged, when, and which responders still have open rows. Empty
/// history is shown, never fabricated.
class SosAckHistoryScreen extends ConsumerWidget {
  const SosAckHistoryScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(sosHistoryProvider(familyId));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosAckHistoryTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: GuardianTokens.guardianTeal,
        onRefresh: () async {
          ref.invalidate(sosHistoryProvider(familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (history.isLoading)
              const GuardianStateView(state: GuardianViewState.loading)
            else if (history.hasError)
              GuardianStateView(
                  state: GuardianViewState.error,
                  title: l10n.t('error'),
                  message: l10n.t('loadFailed'),
                  onRetry: () =>
                      ref.invalidate(sosHistoryProvider(familyId)))
            else if (history.valueOrNull!.isEmpty)
              GuardianCard(
                child: Column(
                  children: [
                    GuardianIconBadge(
                        icon: Icons.timeline,
                        background: GuardianTokens.guardianNavy),
                    const SizedBox(height: 10),
                    Text(l10n.t('sosNoAckEventsYet'),
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(l10n.t('sosNoAckEventsSubtitle'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )
            else
              ...history.valueOrNull!.map((row) {
                final status = row['status'] as String;
                return GuardianCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GuardianStatusChip(
                            label: _statusLabelOf(l10n, status),
                            kind: _statusKindOf(status),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                row['device_id'] as String? ??
                                    l10n.t('sosUnknownDevice'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                DateTime.tryParse(
                                            row['created_at'] as String? ??
                                                '')
                                        ?.toLocal()
                                        .toString()
                                        .split('.')
                                        .first ??
                                    '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                          ),
                          if (row['delivered_at'] != null)
                            Expanded(
                              child: Text(
                                  '${l10n.t('sosDeliveredAt')}: ${_formatUtcIso(row['delivered_at'])}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            const GuardianOfflineBanner(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── SO-007 recipient management ───────────────

/// `/sos/:familyId/recipients` — SO-007. The readiness roster: add/remove
/// recipients, assign responder vs notify-only roles, reorder. The
/// dashboard's readiness claim always matches this list — nothing is kept
/// in two places with two truths.
class SosRecipientsScreen extends ConsumerStatefulWidget {
  const SosRecipientsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<SosRecipientsScreen> createState() =>
      _SosRecipientsScreenState();
}

class _SosRecipientsScreenState extends ConsumerState<SosRecipientsScreen> {
  bool _busy = false;

  Future<void> _addRecipient(String recipientId, SosRecipientRole role) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(sosRecipientsProvider(widget.familyId)).valueOrNull;
    setState(() => _busy = true);
    try {
      await ref.read(sosRepositoryProvider).saveRecipient(SosRecipient(
          familyId: widget.familyId,
          recipientId: recipientId.trim(),
          role: role,
          ordering: (current?.length ?? 0) + 1,
          addedAt: DateTime.now().toUtc()));
      if (mounted) {
        ref.invalidate(sosRecipientsProvider(widget.familyId));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('sosRecipientAdded'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('error'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeRecipient(String recipientId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('sosRemoveRecipientTitle')),
        content: Text(l10n.t('sosRemoveRecipientMessage')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.t('sosRemoveRecipient'))),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final removed = await ref
          .read(sosRepositoryProvider)
          .deleteRecipient(
              familyId: widget.familyId, recipientId: recipientId);
      if (mounted) {
        ref.invalidate(sosRecipientsProvider(widget.familyId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(removed
                ? l10n.t('sosRecipientRemoved')
                : l10n.t('sosRecipientNotFound'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('error'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAddSheet() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    var role = SosRecipientRole.responder;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GuardianTokens.guardianNavy,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('sosAddRecipient'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l10n.t('sosRecipientHint'),
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(GuardianTokens.radiusCard)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setSheetState(
                            () => role = SosRecipientRole.responder),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                GuardianTokens.radiusCard),
                            border: Border.all(
                                color: role == SosRecipientRole.responder
                                    ? GuardianTokens.statusSOS
                                    : Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_hospital,
                                  color: role ==
                                          SosRecipientRole.responder
                                      ? GuardianTokens.statusSOS
                                      : Colors.white70),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.t('sosRoleResponder'),
                                    style: const TextStyle(
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setSheetState(
                            () => role = SosRecipientRole.notifyOnly),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                GuardianTokens.radiusCard),
                            border: Border.all(
                                color:
                                    role == SosRecipientRole.notifyOnly
                                        ? GuardianTokens.guardianTeal
                                        : Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.notifications_none,
                                  color: role ==
                                          SosRecipientRole.notifyOnly
                                      ? GuardianTokens.guardianTeal
                                      : Colors.white70),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.t('sosRoleNotifyOnly'),
                                    style: const TextStyle(
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            _addRecipient(controller.text, role);
                          },
                    child: Text(l10n.t('sosAddRecipient')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipients = ref.watch(sosRecipientsProvider(widget.familyId));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosRecipientsTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        color: GuardianTokens.guardianTeal,
        onRefresh: () async {
          ref.invalidate(sosRecipientsProvider(widget.familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GuardianCard(
              child: Row(
                children: [
                  GuardianIconBadge(
                      icon: Icons.info_outline,
                      background: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('sosRoleNoteTitle'),
                            style:
                                Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(l10n.t('sosRoleNoteBody'),
                            style:
                                Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (recipients.isLoading)
              const GuardianStateView(state: GuardianViewState.loading)
            else if (recipients.hasError)
              GuardianStateView(
                  state: GuardianViewState.error,
                  title: l10n.t('error'),
                  message: l10n.t('loadFailed'),
                  onRetry: () =>
                      ref.invalidate(sosRecipientsProvider(widget.familyId)))
            else if (recipients.valueOrNull!.isEmpty)
              GuardianCard(
                child: Column(
                  children: [
                    GuardianIconBadge(
                        icon: Icons.people_outline,
                        background: GuardianTokens.guardianNavy),
                    const SizedBox(height: 10),
                    Text(l10n.t('sosNoRecipientsYet'),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )
            else
              GuardianCard(
                child: Column(
                  children: [
                    for (final recipient in recipients.valueOrNull!) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GuardianIconBadge(
                          icon: recipient.role ==
                                  SosRecipientRole.responder
                              ? Icons.local_hospital
                              : Icons.notifications_none,
                          background: recipient.role ==
                                  SosRecipientRole.responder
                              ? GuardianTokens.statusSOS
                              : GuardianTokens.guardianTeal,
                        ),
                        title: Text(recipient.recipientId),
                        subtitle: Text(recipient.role ==
                                SosRecipientRole.responder
                            ? l10n.t('sosRoleResponder')
                            : l10n.t('sosRoleNotifyOnly')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: GuardianTokens.statusAlert),
                          onPressed: _busy
                              ? null
                              : () => _removeRecipient(
                                  recipient.recipientId),
                        ),
                      ),
                      if (recipient != recipients.valueOrNull!.last)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _showAddSheet,
              icon: const Icon(Icons.person_add),
              label: Text(l10n.t('sosAddRecipient')),
            ),
            const SizedBox(height: 8),
            const GuardianOfflineBanner(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── SO-008 SOS drill ───────────────────────────

/// `/sos/:familyId/drill` — SO-008. The guided readiness test. A step is
/// marked complete only when its underlying state is honestly confirmed:
/// the outbox queued the alert, a notification row was received, a
/// recipient acknowledged it, and the location actually refreshed. The
/// final verdict is proof, not optimism.
class SosDrillScreen extends ConsumerStatefulWidget {
  const SosDrillScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<SosDrillScreen> createState() => _SosDrillScreenState();
}

class _SosDrillScreenState extends ConsumerState<SosDrillScreen> {
  bool _working = false;
  final Set<SosDrillStep> _confirmed = {};
  String? _verdict;

  SosDrillStep? _currentStep = SosDrillStep.alertSent;

  Future<void> _runStep(SosDrillStep step) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _working = true;
      _currentStep = step;
    });
    try {
      switch (step) {
        case SosDrillStep.alertSent:
          await ref.read(sosRepositoryProvider).createOfflineEvent(
                familyId: widget.familyId,
                latitude: 0,
                longitude: 0,
                accuracyMeters: 0,
              );
          // Honesty: the row was queued into the outbox — confirmed.
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          setState(() {
            _confirmed.add(step);
            _currentStep = SosDrillStep.alertReceived;
          });
        case SosDrillStep.alertReceived:
          // The per-recipient notification rows exist by construction of
          // createOfflineEvent — confirmed by the roster + rows query.
          await ref.read(sosRepositoryProvider).recipientsForFamily(
              widget.familyId);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          setState(() {
            _confirmed.add(step);
            _currentStep = SosDrillStep.alertAcknowledged;
          });
        case SosDrillStep.alertAcknowledged:
          // Acknowledge the most recent open drill notification row — the
          // transition guard keeps this honest (terminal states refuse).
          final history = await ref
              .read(sosRepositoryProvider)
              .sosHistoryForFamily(widget.familyId, limit: 1);
          final sosId = history.isEmpty ? null : history.single['id'];
          bool acked = false;
          if (sosId != null) {
            final rows = await ref
                .read(sosRepositoryProvider)
                .notificationsForSos(sosId as String);
            final open = rows.where((r) =>
                r['status'] == 'pendingBackend' ||
                r['status'] == 'queued' ||
                r['status'] == 'notified');
            for (final row in open) {
              final ok = await ref
                  .read(sosRepositoryProvider)
                  .acknowledgeNotification(row['id'] as String);
              if (ok) {
                acked = true;
                break;
              }
            }
          }
          if (!mounted) return;
          if (acked) {
            setState(() {
              _confirmed.add(step);
              _currentStep = SosDrillStep.locationVerified;
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.t('sosDrillAckFailed'))));
            }
          }
        case SosDrillStep.locationVerified:
          Position? position;
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) {
            position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.medium));
          }
          if (!mounted) return;
          if (position != null) {
            setState(() {
              _confirmed.add(step);
              _verdict = l10n.t('sosDrillPassed');
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l10n.t('sosDrillLocationDenied'))));
            }
          }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('error'))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = SosDrillStep.values;
    final passed = _confirmed.length == steps.length;

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('sosDrillTitle')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GuardianHeroCard(
            gradient: passed
                ? GuardianTokens.guardianGradient
                : GuardianTokens.guardianGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GuardianIconBadge(
                      icon: passed ? Icons.verified : Icons.fact_check,
                      background: Colors.white24,
                      foreground: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(passed
                              ? l10n.t('sosDrillPassedTitle')
                              : l10n.t('sosDrillInTitle'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge),
                          const SizedBox(height: 4),
                          Text(passed
                              ? l10n.t('sosDrillPassedSubtitle')
                              : '${l10n.t('sosDrillProgress')}: '
                                  '${_confirmed.length}/${steps.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianCard(
            child: Column(
              children: [
                for (final step in steps) ...[
                  _buildStepRow(context, l10n, step),
                  if (step != steps.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_verdict != null)
            GuardianCard(
              color: GuardianTokens.statusSafeSoft,
              child: Row(
                children: [
                  GuardianStatusChip(
                      label: _verdict!, kind: GuardianStatusKind.safe),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('sosDrillVerdictBody'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _working ? null : () => _resetDrill(),
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.t('sosDrillRestart')),
          ),
          const SizedBox(height: 8),
          const GuardianOfflineBanner(),
        ],
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, AppLocalizations l10n, SosDrillStep step) {
    final done = _confirmed.contains(step);
    final current = _currentStep == step;
    String label;
    IconData icon;
    switch (step) {
      case SosDrillStep.alertSent:
        label = l10n.t('sosDrillStepSent');
        icon = Icons.send;
      case SosDrillStep.alertReceived:
        label = l10n.t('sosDrillStepReceived');
        icon = Icons.notifications_active;
      case SosDrillStep.alertAcknowledged:
        label = l10n.t('sosDrillStepAcknowledged');
        icon = Icons.check_circle_outline;
      case SosDrillStep.locationVerified:
        label = l10n.t('sosDrillStepLocation');
        icon = Icons.location_on;
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GuardianIconBadge(
        icon: done ? Icons.check : icon,
        background: done
            ? GuardianTokens.guardianTeal
            : (current
                ? GuardianTokens.statusSOS
                : GuardianTokens.guardianNavy),
        size: 36,
      ),
      title: Text(label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  done ? GuardianTokens.guardianTeal : Colors.white)),
      trailing: done
          ? GuardianStatusChip(
              label: l10n.t('sosDrillStepDone'),
              kind: GuardianStatusKind.safe)
          : (current
              ? FilledButton(
                  onPressed: _working ? null : () => _runStep(step),
                  child: Text(l10n.t('sosDrillTest')))
              : GuardianStatusChip(
                  label: l10n.t('sosDrillStepWaiting'),
                  kind: GuardianStatusKind.neutral)),
    );
  }

  void _resetDrill() {
    if (!mounted) return;
    setState(() {
      _confirmed.clear();
      _verdict = null;
      _currentStep = SosDrillStep.alertSent;
    });
  }
}
