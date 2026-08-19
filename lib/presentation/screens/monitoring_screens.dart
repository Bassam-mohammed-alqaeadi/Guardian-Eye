import 'package:flutter/material.dart';
import '../../domain/child_device_enforcement.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/monitoring_repository.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// FS-004 — Screenshot & Camera Control screens (SC-001 … SC-009).
///
/// Same visual grammar as every other subsystem: `GuardianHeroCard` header,
/// `GuardianSection` + `GuardianCard` rows, `GuardianStatTile` /
/// `GuardianStatusChip` / `GuardianStateView`, honest outbox evidence, and
/// `FamilyRuntimeContext.can()` as the only authorization gate. Everything
/// writes through `MonitoringRepository`, local-first like the rest of the
/// platform.
///
/// Honest-state note: shots and sessions only exist after a child device
/// agent ships them. Screens never fabricate "latest capture" rows — the
/// waiting / empty states are the truthful answer until the agent delivers.

/// Formats a date range for day-group headers like "2026-08-19".
String _dayKey(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';

String _timestamp(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// Human label for a request or session kind.
String _kindLabel(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'camera':
      return l10n.t('monitoringKindCamera');
    case 'live':
      return l10n.t('monitoringKindLive');
    default:
      return l10n.t('monitoringKindShot');
  }
}

/// Human label for a request / session state.
String _stateLabel(AppLocalizations l10n, String state) {
  switch (state) {
    case 'delivered':
      return l10n.t('requestStateDelivered');
    case 'started':
      return l10n.t('requestStateStarted');
    case 'ended':
      return l10n.t('requestStateEnded');
    case 'failed':
      return l10n.t('requestStateFailed');
    case 'timeout':
      return l10n.t('requestStateTimeout');
    case 'cancelled':
      return l10n.t('requestStateCancelled');
    case 'started_live':
    case 'pending':
      return l10n.t('requestStatePending');
    default:
      return l10n.t('requestStateQueued');
  }
}

GuardianStatusKind _stateKind(String state) {
  switch (state) {
    case 'delivered':
    case 'started':
    case 'ended':
      return GuardianStatusKind.safe;
    case 'failed':
    case 'timeout':
    case 'cancelled':
      return GuardianStatusKind.alert;
    default:
      return GuardianStatusKind.watch;
  }
}

// ───────────────────────── SC-001 Monitoring Dashboard ────────────────────

/// `/monitoring/:familyId` — SC-001. Family monitoring summary: connected
/// devices, pending requests, evidence waiting for review, and the
/// administrative destinations.

  /// Tinted foreground for an icon badge based on a status kind,
  /// delegating color semantics to the design-system status palette.
  Color _badgeForeground(GuardianStatusKind k, BuildContext ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    switch (k) {
      case GuardianStatusKind.safe:
        return scheme.primary;
      case GuardianStatusKind.watch:
        return scheme.primary;
      case GuardianStatusKind.alert:
        return const Color(0xFFC85000);
      case GuardianStatusKind.offline:
      case GuardianStatusKind.sos:
        return scheme.error;
      case GuardianStatusKind.neutral:
      case GuardianStatusKind.pro:
        return scheme.onSurfaceVariant;
    }
  }

class MonitoringDashboardScreen extends ConsumerWidget {
  const MonitoringDashboardScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final shots = ref.watch(monitoringShotsProvider(familyId));
    final requests = ref.watch(monitoringRequestsProvider(familyId));
    final evidence = ref.watch(monitoringEvidenceProvider(familyId));

    if (runtime.hasError || shots.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(monitoringShotsProvider(familyId));
              ref.invalidate(monitoringRequestsProvider(familyId));
              ref.invalidate(monitoringEvidenceProvider(familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        shots.isLoading ||
        requests.isLoading ||
        evidence.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    final children = contextValue.children;
    final devices = contextValue.devices;
    final shotList = shots.valueOrNull ?? const [];
    final requestList = requests.valueOrNull ?? const [];
    final evidenceList = evidence.valueOrNull ?? const [];
    final pendingRequests =
        requestList.where((r) => r.state == 'queued' || r.state == 'pending').length;
    final waitingForEvidence =
        shotList.isEmpty && requestList.any((r) => r.state == 'queued');
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(monitoringPullProvider(familyId).future);
        ref.invalidate(monitoringShotsProvider(familyId));
        ref.invalidate(monitoringRequestsProvider(familyId));
        ref.invalidate(monitoringEvidenceProvider(familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.remove_red_eye_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('monitoringDashboard'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.devices_outlined,
                          value: '${devices.length}',
                          label: l10n.t('connectedDevices'),
                          kind: devices.isEmpty
                              ? GuardianStatusKind.offline
                              : GuardianStatusKind.safe),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.photo_outlined,
                          value: '${shotList.length}',
                          label: l10n.t('capturedShots'),
                          kind: shotList.isEmpty
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.schedule_outlined,
                          value: '$pendingRequests',
                          label: l10n.t('pendingRequests'),
                          kind: pendingRequests > 0
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.flag_outlined,
                          value: '${evidenceList.length}',
                          label: l10n.t('evidenceReview'),
                          kind: evidenceList.isEmpty
                              ? GuardianStatusKind.safe
                              : GuardianStatusKind.watch),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GuardianStatusChip(
                      kind: waitingForEvidence
                          ? GuardianStatusKind.watch
                          : GuardianStatusKind.safe,
                      label: l10n.t('monitoringSummary')),
                  const SizedBox(height: 6),
                  Text(
                      shotList.isEmpty
                          ? l10n.t('monitoringWaitingForAgent')
                          : l10n.t('monitoringActive'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('children'), children: [
              for (final child in children)
                GuardianCard(
                  onTap: canManage
                      ? () => context.push(
                          '/monitoring/$familyId/${child.id}/session')
                      : null,
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.person_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(child.displayName,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('childMonitoringDescription'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(
              title: l10n.t('monitoring'),
              trailing: canManage
                  ? GestureDetector(
                      onTap: () =>
                          context.push('/monitoring/$familyId/screenshots'),
                      child: Text(l10n.t('screenshotsNav'),
                          style: const TextStyle(
                              color: GuardianTokens.guardianTeal,
                              fontWeight: FontWeight.w600)),
                    )
                  : null,
              children: [
                GuardianCard(
                  onTap: () =>
                      context.push('/monitoring/$familyId/screenshots'),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.photo_library_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('screenshotsTimeline'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('screenshotsTimelineDescription'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: canManage
                      ? () => context.push('/monitoring/$familyId/live')
                      : null,
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.videocam_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('liveSession'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('liveSessionDescription'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: canManage
                      ? () => context.push('/monitoring/$familyId/camera')
                      : null,
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.photo_camera_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('cameraControl'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('cameraControlDescription'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('administration'), children: [
              GuardianCard(
                onTap: canManage
                    ? () => context.push('/monitoring/$familyId/requests')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.list_alt_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('captureRequestsHistory'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('captureRequestsHistoryDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context.push('/monitoring/$familyId/schedule')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.calendar_month_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('captureSchedules'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('captureSchedulesDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
              GuardianCard(
                onTap: () => context.push('/monitoring/$familyId/evidence'),
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.flag_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('evidenceReviewQueue'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('evidenceReviewQueueDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── SC-002 Screenshots Timeline ────────────────────────

/// `/monitoring/:familyId/screenshots` — SC-002. Honest day-grouped timeline
/// of shots the child device agent actually shipped.
class MonitoringScreenshotsTimelineScreen extends ConsumerWidget {
  const MonitoringScreenshotsTimelineScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final shots = ref.watch(monitoringShotsProvider(familyId));

    if (runtime.hasError || shots.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(monitoringShotsProvider(familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        shots.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    final shotList = shots.valueOrNull ?? const [];
    final grouped = <String, List<MonitoringShot>>{};
    for (final shot in shotList) {
      grouped.putIfAbsent(_dayKey(shot.capturedAt), () => []).add(shot);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(monitoringPullProvider(familyId).future);
        ref.invalidate(monitoringShotsProvider(familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.photo_library_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('screenshotsTimeline'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(shotList.isEmpty
                      ? l10n.t('shotsTimelineEmpty')
                      : l10n.t('shotsTimelineDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (days.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/monitoring_guard.png',
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            if (days.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noShotsYet'),
                message: l10n.t('shotsWaitingForAgent'),
              )
            else
              for (final day in days)
                GuardianSection(title: day, children: [
                  for (final shot in grouped[day]!)
                    GuardianCard(
                      onTap: () => context.push(
                          '/monitoring/$familyId/screenshots/${shot.shotId}'),
                      child: Row(children: [
                        GuardianIconBadge(
                            icon: shot.isEvidence
                                ? Icons.flag_outlined
                                : Icons.photo_outlined,
                            foreground: _badgeForeground(
                                shot.isEvidence
                                    ? GuardianStatusKind.alert
                                    : GuardianStatusKind.neutral,
                                context)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_timestamp(shot.capturedAt),
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                    '${_targetShort(shot.deviceId)} · '
                                    '${l10n.t('size')}: '
                                    '${_bytes(shot.bytesLength)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                ]),
          ],
        ),
      ),
    );
  }
}

String _targetShort(String deviceId) =>
    deviceId.length > 14 ? deviceId.substring(0, 14) : deviceId;

String _bytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  return '${(n / (1024 * 1024)).toStringAsFixed(2)} MB';
}

// ───────────────────── SC-003 Shot Viewer ──────────────────────────────────

/// `/monitoring/:familyId/screenshots/:shotId` — SC-003. Honest shot detail:
/// the platform stores delivery evidence (device, time, size, originating
/// request) — the raw pixels live on the device until an agent upload
/// lands in a future release. Nothing is guessed or rendered as fake.
class MonitoringShotViewerScreen extends ConsumerStatefulWidget {
  const MonitoringShotViewerScreen(
      {required this.familyId, required this.shotId, super.key});
  final String familyId;
  final String shotId;

  @override
  ConsumerState<MonitoringShotViewerScreen> createState() =>
      _MonitoringShotViewerState();
}

class _MonitoringShotViewerState
    extends ConsumerState<MonitoringShotViewerScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final shots = ref.watch(monitoringShotsProvider(widget.familyId));

    if (runtime.hasError || shots.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(monitoringShotsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        shots.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    final shotList = shots.valueOrNull ?? const [];
    final shot =
        shotList.where((s) => s.shotId == widget.shotId).toList();
    if (shot.isEmpty) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('shotMissing'),
            message: l10n.t('shotMissingDescription'),
            onRetry: () => context.go('/monitoring/${widget.familyId}/screenshots'),
          ),
        ),
      );
    }
    final found = shot.first;
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('shotDetails')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: found.isEvidence
                              ? Icons.flag_outlined
                              : Icons.photo_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('shotDetails'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                      '${_targetShort(found.deviceId)} · ${found.mimeType} · '
                      '${_bytes(found.bytesLength)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('shotDeliveryEvidence'), children: [
              _EvidenceRow(l10n.t('capturedAt'), _timestamp(found.capturedAt)),
              _EvidenceRow(l10n.t('deviceId'), found.deviceId),
              _EvidenceRow(l10n.t('shotId'), found.shotId),
              _EvidenceRow(
                  l10n.t('originatingRequest'),
                  found.requestId == null
                      ? l10n.t('automaticCapture')
                      : found.requestId!),
              _EvidenceRow(l10n.t('schedule'),
                  found.scheduleId == null
                      ? l10n.t('onDemand')
                      : '${l10n.t('scheduled')} (${found.scheduleId})'),
            ]),
            const SizedBox(height: 16),
            GuardianCard(
              onTap: canManage
                  ? () => _flagForReview(found)
                  : null,
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.flag_outlined,
                    foreground:
                        _badgeForeground(GuardianStatusKind.alert, context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.t('flagForEvidenceReview'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _flagForReview(MonitoringShot shot) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(monitoringRepositoryProvider);
    await repo.flagShotAsEvidence(
      widget.familyId,
      shotId: shot.shotId,
      deviceId: shot.deviceId,
      childId: shot.childId,
    );
    ref.invalidate(monitoringEvidenceProvider(widget.familyId));
    ref.invalidate(monitoringShotsProvider(widget.familyId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('flaggedForReview')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────── SC-004 Live Session ─────────────────────────────────

/// `/monitoring/:familyId/live` — SC-004. Requests a live screen session on a
/// child device. The request is stored locally as queued and only becomes
/// "started" when the device agent reports real evidence — honest waiting
/// states all the way.
class MonitoringLiveSessionScreen extends ConsumerStatefulWidget {
  const MonitoringLiveSessionScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<MonitoringLiveSessionScreen> createState() =>
      _MonitoringLiveSessionState();
}

class _MonitoringLiveSessionState
    extends ConsumerState<MonitoringLiveSessionScreen> {
  bool _requesting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final sessions = ref.watch(monitoringSessionsProvider(widget.familyId));
    final requests = ref.watch(monitoringRequestsProvider(widget.familyId));

    if (runtime.hasError || sessions.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(monitoringSessionsProvider(widget.familyId));
              ref.invalidate(monitoringRequestsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        sessions.isLoading ||
        requests.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
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
    final devices = contextValue.devices;
    final devicesEnabled =
        devices.where((d) => d.lifecycle == ChildDeviceLifecycle.active || d.lifecycle == ChildDeviceLifecycle.enrolled).toList();
    final sessionList = sessions.valueOrNull ?? const [];
    final liveSessions =
        sessionList.where((s) => s.kind == 'live' && s.state != 'ended').toList();
    final isWaiting = liveSessions.isEmpty &&
        requests.valueOrNull!.any((r) => r.kind == 'live' && r.state != 'failed');

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('liveSession')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.videocam_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('liveSession'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                      devicesEnabled.isEmpty
                          ? l10n.t('liveNoDevices')
                          : l10n.t('liveSessionDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (devicesEnabled.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noDevicesPaired'),
                message: l10n.t('pairDeviceFirst'),
              )
            else
              GuardianSection(title: l10n.t('requestLiveSession'), children: [
                for (final device in devicesEnabled)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.phone_android_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_targetShort(device.deviceId),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(l10n.t('tapToRequestLive'),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                      _requesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton(
                              onPressed: () => _requestLive(device.deviceId),
                              child: Text(l10n.t('start'),
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                            ),
                    ]),
                  ),
              ]),
            const SizedBox(height: 16),
            if (isWaiting)
              GuardianStatusChip(
                  kind: GuardianStatusKind.watch,
                  label: l10n.t('liveWaitingForAgent'))
            else if (liveSessions.isNotEmpty)
              GuardianSection(title: l10n.t('activeLiveSessions'), children: [
                for (final session in liveSessions)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: Icons.videocam_outlined,
                          foreground:
                              _badgeForeground(GuardianStatusKind.safe, context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_targetShort(session.deviceId)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${_stateLabel(l10n, session.state)} · '
                                  '${_timestamp(session.createdAt)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _requestLive(String deviceId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _requesting = true);
    try {
      final repo = ref.read(monitoringRepositoryProvider);
      await repo.createRequest(
        familyId: widget.familyId,
        deviceId: deviceId,
        requestId:
            'req-${widget.familyId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        kind: 'live',
        reason: l10n.t('parentLiveRequest'),
      );
      ref.invalidate(monitoringRequestsProvider(widget.familyId));
      ref.invalidate(monitoringSessionsProvider(widget.familyId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('liveRequestQueued')),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}

// ───────────────────── SC-005 Camera Control ───────────────────────────────

/// `/monitoring/:familyId/camera` — SC-005. Camera capture requests with an
/// honest request history. Success is only claimed when delivery evidence
/// arrives.
class MonitoringCameraControlScreen extends ConsumerStatefulWidget {
  const MonitoringCameraControlScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<MonitoringCameraControlScreen> createState() =>
      _MonitoringCameraControlState();
}

class _MonitoringCameraControlState
    extends ConsumerState<MonitoringCameraControlScreen> {
  bool _requesting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final requests = ref.watch(monitoringRequestsProvider(widget.familyId));

    if (runtime.hasError || requests.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(monitoringRequestsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        requests.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
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
    final devices = contextValue.devices;
    final devicesEnabled =
        devices.where((d) => d.lifecycle == ChildDeviceLifecycle.active || d.lifecycle == ChildDeviceLifecycle.enrolled).toList();
    final requestList = requests.valueOrNull ?? const [];
    final cameraRequests = requestList.where((r) => r.kind == 'camera').toList();

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('cameraControl')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.photo_camera_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('cameraControl'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('cameraControlDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (devicesEnabled.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noDevicesPaired'),
                message: l10n.t('pairDeviceFirst'),
              )
            else
              GuardianSection(title: l10n.t('captureNow'), children: [
                for (final device in devicesEnabled)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.photo_camera_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_targetShort(device.deviceId),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(l10n.t('frontCameraOneShot'),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                      _requesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton(
                              onPressed: () => _requestCapture(device.deviceId),
                              child: Text(l10n.t('capture'),
                                  style:
                                      Theme.of(context).textTheme.labelMedium),
                            ),
                    ]),
                  ),
              ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('cameraRequestHistory'), children: [
              if (cameraRequests.isEmpty)
                GuardianCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.t('noCameraRequestsYet'),
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                )
              else
                for (final request in cameraRequests)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: Icons.photo_camera_outlined,
                          foreground: _badgeForeground(
                              _stateKind(request.state), context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${_kindLabel(l10n, request.kind)} · '
                                  '${_targetShort(request.deviceId)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${_stateLabel(l10n, request.state)} · '
                                  '${_timestamp(request.createdAt)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _requestCapture(String deviceId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _requesting = true);
    try {
      final repo = ref.read(monitoringRepositoryProvider);
      await repo.createRequest(
        familyId: widget.familyId,
        deviceId: deviceId,
        requestId:
            'req-${widget.familyId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
        kind: 'camera',
        reason: l10n.t('parentCameraRequest'),
      );
      ref.invalidate(monitoringRequestsProvider(widget.familyId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('cameraRequestQueued')),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}

// ───────────────────── SC-006 Child Active Session ─────────────────────────

/// `/monitoring/:familyId/:childId/session` — SC-006. What is happening right
/// now on this specific child's device: recent usage summaries and active
/// app activity. Fail-closed: the screen verifies the child belongs to the
/// family before rendering anything.
class MonitoringChildSessionScreen extends ConsumerWidget {
  const MonitoringChildSessionScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final activity = ref.watch(appUsageForFamilyProvider(familyId));

    if (runtime.hasError || activity.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(appUsageForFamilyProvider(familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || activity.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    // Fail-closed: the child id from the route must actually belong to this
    // family. We never render another family's child data.
    final child = contextValue.children
        .where((c) => c.id == childId)
        .toList();
    if (child.isEmpty) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('childNotFound'),
            message: l10n.t('childNotFoundDescription'),
            onRetry: () => context.go('/monitoring/$familyId'),
          ),
        ),
      );
    }
    final member = child.first;
    final summaryList = (activity.valueOrNull ?? const [])
        .where((s) => s.deviceId == childId)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(appUsageForFamilyProvider(familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.person_outline,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            '${member.displayName} — ${l10n.t('deviceSession')}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('childSessionDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('recentActivity'), children: [
              if (summaryList.isEmpty)
                GuardianCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        GuardianIconBadge(
                            icon: Icons.hourglass_empty_outlined,
                            foreground: _badgeForeground(
                                GuardianStatusKind.neutral, context)),
                        const SizedBox(height: 8),
                        Text(l10n.t('noRecentActivity'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                )
              else
                for (final summary in summaryList)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.schedule_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(summary.target,
                                  style: Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${l10n.t('duration')}: '
                                  '${_formatDurationText(summary.totalDuration)} · '
                                  '${l10n.t('capturedAt')}: '
                                  '${_timestamp(summary.capturedAt)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Renders a usage duration honestly from the registry value — never a
/// guessed label.
String _formatDurationText(Duration d) => _formatDuration(d);

/// Formats a duration like "1h 20m" — the same formatter the rest of the
/// platform uses.
String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours <= 0) return minutes > 0 ? '${minutes}m' : '0m';
  return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
}

// ───────────────────── SC-007 Capture Requests History ─────────────────────

/// `/monitoring/:familyId/requests` — SC-007. Honest ledger of every capture,
/// camera and live request with its real state — queued until delivery
/// evidence arrives.
class MonitoringRequestsHistoryScreen extends ConsumerWidget {
  const MonitoringRequestsHistoryScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final requests = ref.watch(monitoringRequestsProvider(familyId));

    if (runtime.hasError || requests.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(monitoringRequestsProvider(familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        requests.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    final requestList = requests.valueOrNull ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(monitoringPullProvider(familyId).future);
        ref.invalidate(monitoringRequestsProvider(familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.list_alt_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('captureRequestsHistory'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(requestList.isEmpty
                      ? l10n.t('noRequestsYet')
                      : l10n.t('captureRequestsHistoryDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (requestList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noRequestsYet'),
                message: l10n.t('requestsEmptyDescription'),
              )
            else
              GuardianSection(title: l10n.t('allRequests'), children: [
                for (final request in requestList)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: request.kind == 'camera'
                              ? Icons.photo_camera_outlined
                              : request.kind == 'live'
                                  ? Icons.videocam_outlined
                                  : Icons.photo_outlined,
                          foreground: _badgeForeground(
                              _stateKind(request.state), context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_kindLabel(l10n, request.kind),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${_targetShort(request.deviceId)} · '
                                  '${_stateLabel(l10n, request.state)} · '
                                  '${_timestamp(request.createdAt)}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ───────────────────── SC-008 Capture Schedules ────────────────────────────

/// `/monitoring/:familyId/schedule` — SC-008. Automatic capture windows the
/// child agent honours. Writes stay local-first with queued sync state.
class MonitoringSchedulesScreen extends ConsumerStatefulWidget {
  const MonitoringSchedulesScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<MonitoringSchedulesScreen> createState() =>
      _MonitoringSchedulesState();
}

class _MonitoringSchedulesState
    extends ConsumerState<MonitoringSchedulesScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final schedules = ref.watch(monitoringSchedulesProvider(widget.familyId));

    if (runtime.hasError || schedules.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(monitoringSchedulesProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        schedules.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
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
    final scheduleList = schedules.valueOrNull ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(monitoringSchedulesProvider(widget.familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.calendar_month_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('captureSchedules'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('captureSchedulesDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianCard(
              onTap: () => _showAddScheduleDialog(context),
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.add_outlined,
                    foreground: _badgeForeground(
                        GuardianStatusKind.safe, context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.t('addCaptureSchedule'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            const SizedBox(height: 16),
            if (scheduleList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noSchedulesYet'),
                message: l10n.t('schedulesEmptyDescription'),
              )
            else
              GuardianSection(title: l10n.t('activeSchedules'), children: [
                for (final schedule in scheduleList)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: schedule.enabled
                              ? Icons.calendar_month_outlined
                              : Icons.calendar_month_outlined,
                          foreground: _badgeForeground(
                              schedule.enabled
                                  ? GuardianStatusKind.safe
                                  : GuardianStatusKind.neutral,
                              context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${schedule.startHour.toString().padLeft(2, '0')}:00 — '
                                  '${schedule.endHour.toString().padLeft(2, '0')}:00',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${l10n.t('every')} '
                                  '${l10n.t('everyIntervalMinutes')}'
                                      .replaceAll('{n}',
                                          '${schedule.intervalMinutes}'),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                      GestureDetector(
                        onTap: () => _toggleSchedule(schedule),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4, left: 4),
                          child: Switch(
                            value: schedule.enabled,
                            onChanged: (_) => _toggleSchedule(schedule),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSchedule(MonitoringSchedule schedule) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(monitoringRepositoryProvider);
    await repo.saveSchedule(
      familyId: widget.familyId,
      scheduleId: schedule.scheduleId,
      deviceId: schedule.deviceId,
      childId: schedule.childId,
      startHour: schedule.startHour,
      endHour: schedule.endHour,
      intervalMinutes: schedule.intervalMinutes,
      enabled: !schedule.enabled,
    );
    ref.invalidate(monitoringSchedulesProvider(widget.familyId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(schedule.enabled
          ? l10n.t('scheduleDisabled')
          : l10n.t('scheduleEnabled')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showAddScheduleDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    var startHour = 8;
    var endHour = 22;
    var intervalMinutes = 30;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.t('addCaptureSchedule'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScheduleSlider(
                label: l10n.t('startHour'),
                value: startHour,
                onChanged: (v) => setDialogState(() => startHour = v),
              ),
              _ScheduleSlider(
                label: l10n.t('endHour'),
                value: endHour,
                onChanged: (v) => setDialogState(() => endHour = v),
              ),
              _ScheduleSlider(
                label: l10n.t('intervalMinutes'),
                value: intervalMinutes ~/ 5,
                max: 24,
                display: '${intervalMinutes}${l10n.t('minutesUnit')}',
                onChanged: (v) => setDialogState(() => intervalMinutes = v * 5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: Text(l10n.t('add')),
            ),
          ],
        ),
      ),
    );
    if (result != 'save') return;
    await repoSaveSchedule(
      intervalMinutes: intervalMinutes,
      startHour: startHour,
      endHour: endHour,
    );
  }

  Future<void> repoSaveSchedule({
    required int intervalMinutes,
    required int startHour,
    required int endHour,
  }) async {
    final repo = ref.read(monitoringRepositoryProvider);
    await repo.saveSchedule(
      familyId: widget.familyId,
      scheduleId:
          'sch-${widget.familyId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      intervalMinutes: intervalMinutes,
      startHour: startHour,
      endHour: endHour,
      enabled: true,
    );
    ref.invalidate(monitoringSchedulesProvider(widget.familyId));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('scheduleCreated')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _ScheduleSlider extends StatelessWidget {
  const _ScheduleSlider({
    required this.label,
    required this.value,
    this.max = 23,
    this.display,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int max;
  final String? display;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: max.toDouble(),
              divisions: max,
              label: display ?? value.toString(),
              onChanged: (v) => onChanged(v.toInt()),
              activeColor: GuardianTokens.guardianTeal,
            ),
          ),
          Text(display ?? '${value.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

// ───────────────────── SC-009 Evidence Review Queue ────────────────────────

/// `/monitoring/:familyId/evidence` — SC-009. Items the agent flagged for
/// parental review. The parent closes each item with a real decision
/// (reviewed / dismissed) — nothing is auto-cleared.
class MonitoringEvidenceQueueScreen extends ConsumerWidget {
  const MonitoringEvidenceQueueScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final evidence = ref.watch(monitoringEvidenceProvider(familyId));

    if (runtime.hasError || evidence.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(monitoringEvidenceProvider(familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        evidence.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewChildStatus)) {
      return Scaffold(
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
    final evidenceList = evidence.valueOrNull ?? const [];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(monitoringPullProvider(familyId).future);
        ref.invalidate(monitoringEvidenceProvider(familyId));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GuardianIconBadge(
                          icon: Icons.flag_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('evidenceReviewQueue'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(evidenceList.isEmpty
                      ? l10n.t('evidenceQueueEmpty')
                      : l10n.t('evidenceReviewQueueDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (evidenceList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('evidenceQueueEmpty'),
                message: l10n.t('evidenceQueueEmptyDescription'),
              )
            else
              GuardianSection(title: l10n.t('awaitingReview'), children: [
                for (final item in evidenceList)
                  GuardianCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GuardianIconBadge(
                              icon: Icons.flag_outlined,
                              foreground: _badgeForeground(
                                  GuardianStatusKind.alert, context)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_targetShort(item.deviceId),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${_timestamp(item.createdAt)} · '
                                      '${item.flagReason}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall),
                                ]),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  _decide(item, 'dismissed', l10n, ref),
                              child: Text(l10n.t('dismiss')),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () =>
                                  _decide(item, 'reviewed', l10n, ref),
                              child: Text(l10n.t('markReviewed')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ]),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(MonitoringEvidence item, String state,
      AppLocalizations l10n, WidgetRef ref) async {
    final repo = ref.read(monitoringRepositoryProvider);
    await repo.reviewEvidence(familyId, item.evidenceId, state: state);
    ref.invalidate(monitoringEvidenceProvider(familyId));
  }
}
