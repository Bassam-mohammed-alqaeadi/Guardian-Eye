import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/guardian_models.dart';
import '../../domain/mode_config.dart';
import '../widgets/guardian_primitives.dart';

/// FS-005 — Special & Custom Modes screens (MD-001 … MD-010).
///
/// Same visual grammar as every other subsystem: `GuardianHeroCard` header,
/// `GuardianSection` + `GuardianCard` rows, `GuardianStatTile` /
/// `GuardianStatusChip` / `GuardianStateView`, and `FamilyRuntimeContext.can()`
/// as the only authorization gate. Parents create situational modes
/// (homework, bedtime, travel, custom), assign children, and flip them on
/// and off. The conflict resolver surfaces overlaps honestly — a losing mode
/// is recorded, never silently overridden.
///
/// Honest-state note: activations only record what the parent actually did.
/// Delivery to the child device agent becomes "applied" only when the agent
/// confirms; until then the honest state is "queued/requested".

/// Human label for a mode kind.
String _kindLabel(AppLocalizations l10n, ModeKind kind) {
  switch (kind) {
    case ModeKind.homework:
      return l10n.t('modesHomeworkMode');
    case ModeKind.bedtime:
      return l10n.t('modesBedtimeMode');
    case ModeKind.travel:
      return l10n.t('modesTravelMode');
    case ModeKind.custom:
      return l10n.t('modesCustomMode');
  }
}

/// Human label for a mode action.
String _actionLabel(AppLocalizations l10n, ModeAction action) {
  switch (action) {
    case ModeAction.block:
      return l10n.t('modesActionBlock');
    case ModeAction.slowDown:
      return l10n.t('modesActionSlowDown');
    case ModeAction.allowlistOnly:
      return l10n.t('modesActionAllowlistOnly');
  }
}

/// Human label for a schedule kind.
String _scheduleLabel(AppLocalizations l10n, ModeScheduleKind kind) {
  switch (kind) {
    case ModeScheduleKind.daily:
      return l10n.t('modesScheduleDaily');
    case ModeScheduleKind.weekly:
      return l10n.t('modesScheduleWeekly');
    case ModeScheduleKind.oneTime:
      return l10n.t('modesScheduleOneTime');
  }
}

/// Human label for an activation state — never fabricates "applied".
String _activationStateLabel(AppLocalizations l10n, String state) {
  switch (state) {
    case 'active':
      return l10n.t('modesStateActive');
    case 'applied':
      return l10n.t('modesStateApplied');
    case 'requested':
      return l10n.t('modesStateRequested');
    case 'failed':
      return l10n.t('modesStateFailed');
    case 'expired':
      return l10n.t('modesStateExpired');
    default:
      return l10n.t('modesStateRequested');
  }
}

GuardianStatusKind _activationKind(String state) {
  switch (state) {
    case 'active':
      return GuardianStatusKind.safe;
    case 'applied':
      return GuardianStatusKind.safe;
    case 'requested':
      return GuardianStatusKind.watch;
    case 'failed':
      return GuardianStatusKind.alert;
    case 'expired':
      return GuardianStatusKind.neutral;
    default:
      return GuardianStatusKind.watch;
  }
}

/// Minute-of-day → "HH:MM".
String _timeOfDay(int minute) {
  final clamped = ((minute % 1440) + 1440) % 1440;
  return '${(clamped ~/ 60).toString().padLeft(2, '0')}:${(clamped % 60).toString().padLeft(2, '0')}';
}

/// ISO weekday → Arabic/English label.
String _weekdayLabel(AppLocalizations l10n, int iso) {
  switch (iso) {
    case 1:
      return l10n.t('modesWeekdayMon');
    case 2:
      return l10n.t('modesWeekdayTue');
    case 3:
      return l10n.t('modesWeekdayWed');
    case 4:
      return l10n.t('modesWeekdayThu');
    case 5:
      return l10n.t('modesWeekdayFri');
    case 6:
      return l10n.t('modesWeekdaySat');
    case 7:
      return l10n.t('modesWeekdaySun');
    default:
      return '?';
  }
}

String _assignedChildListLabel(
    AppLocalizations l10n, List<FamilyMember> children, Set<String> ids) {
  if (ids.isEmpty) return l10n.t('modesAssignedNone');
  final names = children
      .where((c) => ids.contains(c.id))
      .map((c) => c.displayName)
      .toList();
  if (names.isEmpty) return l10n.t('modesAssignedNone');
  return names.join('، ');
}

/// Shared authorization/loading/error body used by every modes screen.
Widget _modesGuard(
  BuildContext context,
  WidgetRef ref,
  String familyId,
  AsyncValue<Object?> runtime,
  AsyncValue<Object?> data,
  FamilyPermission permission,
) {
  final l10n = AppLocalizations.of(context);
  if (runtime.hasError || data.hasError) {
    return Scaffold(
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('monitoringSyncFailed'),
          message: l10n.t('somethingWentWrong'),
          onRetry: () => ref.invalidate(modeConfigsProvider(familyId)),
        ),
      ),
    );
  }
  final contextValue = runtime.valueOrNull is FamilyRuntimeContext
      ? runtime.valueOrNull as FamilyRuntimeContext
      : null;
  if (contextValue == null || runtime.isLoading || data.isLoading) {
    return Scaffold(
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const GuardianStateView(state: GuardianViewState.loading),
      ),
    );
  }
  if (!contextValue.can(permission)) {
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
  return const SizedBox.shrink();
}

Future<void> _invalidateModes(
    WidgetRef ref, String familyId, Future<void> Function() mutation) async {
  await mutation();
  ref.invalidate(modeConfigsProvider(familyId));
  ref.invalidate(modeActivationsProvider(familyId));
}

// ───────────────────────── MD-001 Modes Dashboard ─────────────────────────

/// `/modes/:familyId` — MD-001. Family modes overview: active modes,
/// templates, and management destinations.
class ModesDashboardScreen extends ConsumerWidget {
  const ModesDashboardScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final modes = ref.watch(modeConfigsProvider(familyId));

    final guard =
        _modesGuard(context, ref, familyId, runtime, modes, FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final contextValue = runtime.valueOrNull!;
    final modeList = modes.valueOrNull ?? const [];
    final active = modeList.where((m) => m.enabled).toList();
    final children = contextValue.children;
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(modeConfigsProvider(familyId)),
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
                          icon: Icons.tune_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('modesDashboardTitle'),
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
                          icon: Icons.tune_outlined,
                          value: '${modeList.length}',
                          label: l10n.t('modesTotal'),
                          kind: modeList.isEmpty
                              ? GuardianStatusKind.offline
                              : GuardianStatusKind.safe),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.play_circle_outline,
                          value: '${active.length}',
                          label: l10n.t('modesActive'),
                          kind: active.isEmpty
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GuardianStatusChip(
                      kind: modeList.isEmpty
                          ? GuardianStatusKind.neutral
                          : GuardianStatusKind.safe,
                      label: l10n.t('modesSummary')),
                  const SizedBox(height: 6),
                  Text(
                      modeList.isEmpty
                          ? l10n.t('modesEmptyDescription')
                          : l10n.t('modesSummaryDescription'),
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
            if (canManage)
              GuardianCard(
                onTap: () => context.push('/modes/$familyId/templates'),
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.auto_fix_high_outlined,
                      foreground: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('modesTemplates'),
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(l10n.t('modesTemplatesDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            if (canManage) const SizedBox(height: 12),
            if (canManage)
              GuardianCard(
                onTap: () => context.push('/modes/$familyId/new'),
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.add_outlined,
                      foreground: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('modesAddMode'),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('modesModesSection'), children: [
              for (final mode in modeList)
                _ModeRowCard(
                  l10n: l10n,
                  context: context,
                  familyId: familyId,
                  mode: mode,
                  children: children,
                  onToggle: () => _toggleMode(context, ref, familyId, mode),
                ),
              if (modeList.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('modesNoModesYet'),
                  message: l10n.t('modesCreateFirst'),
                ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('modesAdministration'), children: [
              GuardianCard(
                onTap: canManage
                    ? () => context.push('/modes/$familyId/history')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.history_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('modesActivationHistory'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('modesActivationHistoryDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context.push('/modes/$familyId/conflict')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.compare_arrows_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('modesConflictResolver'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('modesConflictDescription'),
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

  Future<void> _toggleMode(
      BuildContext context, WidgetRef ref, String familyId, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(modeConfigRepositoryProvider);
    if (mode.enabled) {
      await _invalidateModes(ref, familyId,
          () => repo.deactivateMode(familyId: familyId, modeId: mode.modeId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('modesModeDeactivated')),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      await _invalidateModes(ref, familyId,
          () => repo.activateMode(familyId: familyId, modeId: mode.modeId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.t('modesModeActivated')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

class _ModeRowCard extends StatelessWidget {
  const _ModeRowCard({
    required this.l10n,
    required this.context,
    required this.familyId,
    required this.mode,
    required this.children,
    required this.onToggle,
  });
  final AppLocalizations l10n;
  final BuildContext context;
  final String familyId;
  final ModeConfig mode;
  final List<FamilyMember> children;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      onTap: () => context.push('/modes/$familyId/${mode.modeId}'),
      child: Row(children: [
        GuardianIconBadge(
            icon: mode.kind == ModeKind.bedtime
                ? Icons.nightlight_outlined
                : mode.kind == ModeKind.homework
                    ? Icons.menu_book_outlined
                    : mode.kind == ModeKind.travel
                        ? Icons.luggage_outlined
                        : Icons.tune_outlined,
            foreground: mode.enabled
                ? GuardianTokens.guardianTeal
                : Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.name,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                    '${_kindLabel(l10n, mode.kind)} • '
                    '${_actionLabel(l10n, mode.action)} • '
                    '${_scheduleLabel(l10n, mode.scheduleKind)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                    _assignedChildListLabel(
                        l10n, children, mode.assignedChildIds),
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
        ),
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Switch(
              value: mode.enabled,
              onChanged: (_) => onToggle(),
            ),
          ),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

// ───────────────────────── MD-002 Mode Detail ─────────────────────────────

/// `/modes/:familyId/:modeId` — MD-002. Full mode configuration with
/// activate/deactivate and edit/delete management.
class ModeDetailScreen extends ConsumerStatefulWidget {
  const ModeDetailScreen(
      {required this.familyId, required this.modeId, super.key});
  final String familyId;
  final String modeId;

  @override
  ConsumerState<ModeDetailScreen> createState() => _ModeDetailState();
}

class _ModeDetailState extends ConsumerState<ModeDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final modes = ref.watch(modeConfigsProvider(widget.familyId));
    final guard = _modesGuard(context, ref, widget.familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final modeList = modes.valueOrNull ?? const [];
    final mode = modeList.where((m) => m.modeId == widget.modeId).firstOrNull;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(modeConfigsProvider(widget.familyId)),
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
                          icon: Icons.tune_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(mode?.name ?? l10n.t('modesNotFound'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                      GuardianStatusChip(
                          kind: mode?.enabled == true
                              ? GuardianStatusKind.safe
                              : GuardianStatusKind.neutral,
                          label: mode?.enabled == true
                              ? l10n.t('modesModeOn')
                              : l10n.t('modesModeOff')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (mode == null)
                    Text(l10n.t('modesNotFoundDescription'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70))
                  else
                    Text(
                        '${_kindLabel(l10n, mode.kind)} • '
                        '${_actionLabel(l10n, mode.action)} • '
                        '${_scheduleLabel(l10n, mode.scheduleKind)}',
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
            if (mode == null)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('modesNotFound'),
                message: l10n.t('modesNotFoundDescription'),
              )
            else ...[
              GuardianSection(title: l10n.t('modesConfiguration'), children: [
                GuardianCard(
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.schedule_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('modesActiveWindow'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall),
                            const SizedBox(height: 2),
                            Text(
                                mode.scheduleKind == ModeScheduleKind.oneTime
                                    ? '${_timeOfDay(mode.startMinute)} — '
                                        '${mode.assignedChildIds.isEmpty ? l10n.t('modesAssignedNone') : _timeOfDay(mode.endMinute)}'
                                    : '${_timeOfDay(mode.startMinute)} — '
                                        '${_timeOfDay(mode.endMinute)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                  ]),
                ),
                if (mode.scheduleKind == ModeScheduleKind.weekly)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.date_range_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('modesWeekdays'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  mode.weekdays
                                      .map((d) => _weekdayLabel(l10n, d))
                                      .join(' • '),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
                GuardianCard(
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.priority_high_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('modesPriority'),
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text('${mode.priority}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                    ),
                  ]),
                ),
                if (mode.categoryRestrictions.isNotEmpty)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.category_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('modesCategoryRestrictions'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(mode.categoryRestrictions.join(' • '),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
                if (mode.assignedChildIds.isNotEmpty)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.child_care_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('modesAssignedChildren'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  _assignedChildListLabel(l10n,
                                      (runtime.valueOrNull?.children ??
                                          const []),
                                      mode.assignedChildIds),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
                if (mode.note != null && mode.note!.isNotEmpty)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.notes_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('modesNote'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(mode.note!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ]),
                      ),
                    ]),
                  ),
              ]),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('modesActions'), children: [
                GuardianCard(
                  onTap: () async {
                    final repo = ref.read(modeConfigRepositoryProvider);
                    if (mode.enabled) {
                      await _invalidateModes(ref, widget.familyId,
                          () => repo.deactivateMode(
                              familyId: widget.familyId,
                              modeId: widget.modeId));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.t('modesModeDeactivated')),
                        behavior: SnackBarBehavior.floating,
                      ));
                    } else {
                      await _invalidateModes(ref, widget.familyId,
                          () => repo.activateMode(
                              familyId: widget.familyId,
                              modeId: widget.modeId));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.t('modesModeActivated')),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: mode.enabled
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outlined,
                        foreground: mode.enabled
                            ? const Color(0xFFC85000)
                            : GuardianTokens.guardianTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(mode.enabled
                          ? l10n.t('modesDeactivateMode')
                          : l10n.t('modesActivateMode')),
                    ),
                  ]),
                ),
                GuardianCard(
                  onTap: () =>
                      context.push('/modes/${widget.familyId}/${widget.modeId}/edit'),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.edit_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('modesEditMode'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: () =>
                      context.push('/modes/${widget.familyId}/${widget.modeId}/schedule'),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.schedule_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('modesScheduleMode'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: () =>
                      context.push('/modes/${widget.familyId}/${widget.modeId}/children'),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.child_care_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('modesAssignChildren'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: () =>
                      context.push('/modes/${widget.familyId}/${widget.modeId}/history'),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.history_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.t('modesActivationHistory'))),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
                GuardianCard(
                  onTap: () => _confirmDelete(context),
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: Icons.delete_outline,
                        foreground: const Color(0xFFC85000)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('modesDeleteMode'),
                          style: const TextStyle(
                              color: Color(0xFFC85000))),
                    ),
                  ]),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('modesDeleteMode'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: Text(l10n.t('modesDeleteConfirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(modeConfigRepositoryProvider);
    await _invalidateModes(ref, widget.familyId,
        () => repo.deleteMode(widget.familyId, widget.modeId));
    context.pushReplacement('/modes/${widget.familyId}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeDeleted')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ───────────────────────── MD-003 Mode Create ─────────────────────────────

/// `/modes/:familyId/new` — MD-003. Create a mode from a template or from
/// scratch.
class ModeCreateScreen extends ConsumerStatefulWidget {
  const ModeCreateScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<ModeCreateScreen> createState() => _ModeCreateState();
}

class _ModeCreateState extends ConsumerState<ModeCreateScreen> {
  final _nameController = TextEditingController();
  ModeKind _kind = ModeKind.custom;
  ModeAction _action = ModeAction.slowDown;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createFromTemplate(ModeTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(modeConfigRepositoryProvider);
    final contextValue = ref.read(familyRuntimeContextProvider(widget.familyId)).valueOrNull;
    final children = contextValue?.children ?? const <FamilyMember>[];
    final mode = template.mode.copyWith(
      modeId: 'mode-${widget.familyId.substring(0, 6)}-'
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      familyId: widget.familyId,
      assignedChildIds: children.map((c) => c.id).toSet(),
      createdAt: DateTime.now(),
    );
    await repo.saveMode(mode);
    await _invalidateModes(ref, widget.familyId, () async {});
    context.pushReplacement('/modes/${widget.familyId}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeCreated')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final modes = ref.watch(modeConfigsProvider(widget.familyId));
    final guard = _modesGuard(context, ref, widget.familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }

    return Directionality(
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
                        icon: Icons.add_circle_outline,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('modesCreateMode'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(l10n.t('modesCreateDescription'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('modesStartFromTemplate'), children: [
            for (final template in ModeTemplate.builtIns)
              GuardianCard(
                onTap: () => _createFromTemplate(template),
                child: Row(children: [
                  GuardianIconBadge(
                      icon: template.key == 'homework'
                          ? Icons.menu_book_outlined
                          : template.key == 'bedtime'
                              ? Icons.nightlight_outlined
                              : Icons.luggage_outlined,
                      foreground: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(template.name,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(template.description,
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('modesStartCustom'), children: [
            GuardianCard(
              onTap: () => _showCustomDialog(context),
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.tune_outlined,
                    foreground: GuardianTokens.guardianTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesCustomMode'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(l10n.t('modesCustomDescription'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _showCustomDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    _nameController.clear();
    _kind = ModeKind.custom;
    _action = ModeAction.slowDown;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('modesCreateCustom'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: l10n.t('modesModeName'),
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModeKind>(
                value: _kind,
                decoration: InputDecoration(labelText: l10n.t('modesKind')),
                items: [
                  DropdownMenuItem(
                      value: ModeKind.homework, child: Text(l10n.t('modeKindHomework'))),
                  DropdownMenuItem(
                      value: ModeKind.bedtime, child: Text(l10n.t('modeKindBedtime'))),
                  DropdownMenuItem(
                      value: ModeKind.travel, child: Text(l10n.t('modeKindTravel'))),
                  DropdownMenuItem(
                      value: ModeKind.custom, child: Text(l10n.t('modeKindCustom'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
              ),
              DropdownButtonFormField<ModeAction>(
                value: _action,
                decoration: InputDecoration(labelText: l10n.t('modesAction')),
                items: [
                  DropdownMenuItem(
                      value: ModeAction.block, child: Text(l10n.t('modeActionBlock'))),
                  DropdownMenuItem(
                      value: ModeAction.slowDown, child: Text(l10n.t('modeActionSlowDown'))),
                  DropdownMenuItem(
                      value: ModeAction.allowlistOnly,
                      child: Text(l10n.t('modeActionAllowlistOnly'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _action = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('create')),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(modeConfigRepositoryProvider);
    final contextValue =
        ref.read(familyRuntimeContextProvider(widget.familyId)).valueOrNull;
    final children = contextValue?.children ?? const <FamilyMember>[];
    final mode = ModeConfig(
      modeId: 'mode-${widget.familyId.substring(0, 6)}-'
          '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      familyId: widget.familyId,
      name: name,
      kind: _kind,
      action: _action,
      assignedChildIds: children.map((c) => c.id).toSet(),
      createdAt: DateTime.now(),
    );
    await repo.saveMode(mode);
    await _invalidateModes(ref, widget.familyId, () async {});
    context.pushReplacement('/modes/${widget.familyId}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeCreated')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ───────────────────────── MD-004 Mode Edit ───────────────────────────────

/// `/modes/:familyId/:modeId/edit` — MD-004. Edit an existing mode.
class ModeEditScreen extends ConsumerStatefulWidget {
  const ModeEditScreen(
      {required this.familyId, required this.modeId, super.key});
  final String familyId;
  final String modeId;

  @override
  ConsumerState<ModeEditScreen> createState() => _ModeEditState();
}

class _ModeEditState extends ConsumerState<ModeEditScreen> {
  final _nameController = TextEditingController();
  ModeKind _kind = ModeKind.custom;
  ModeAction _action = ModeAction.slowDown;
  ModeConfig? _original;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final modes = ref.watch(modeConfigsProvider(widget.familyId));
    final guard = _modesGuard(context, ref, widget.familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final modeList = modes.valueOrNull ?? const [];
    _original ??=
        modeList.where((m) => m.modeId == widget.modeId).firstOrNull;
    final mode = _original;

    if (mode == null) {
      return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.empty,
          title: l10n.t('modesNotFound'),
          message: l10n.t('modesNotFoundDescription'),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(
              children: [
                GuardianIconBadge(
                    icon: Icons.edit_outlined,
                    background: Colors.white24,
                    foreground: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.t('modesEditMode'),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('modesConfiguration'), children: [
            GuardianCard(
              onTap: () => _showEditDialog(context, mode),
              child: Row(children: [
                GuardianIconBadge(icon: Icons.settings_outlined,
                    foreground: GuardianTokens.guardianTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesNameAction'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('${mode.name} • ${_actionLabel(l10n, mode.action)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            GuardianCard(
              onTap: () =>
                  context.push('/modes/${widget.familyId}/${widget.modeId}/schedule'),
              child: Row(children: [
                GuardianIconBadge(icon: Icons.schedule_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesScheduleMode'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                            '${_scheduleLabel(l10n, mode.scheduleKind)} '
                            '${_timeOfDay(mode.startMinute)} — '
                            '${_timeOfDay(mode.endMinute)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            GuardianCard(
              onTap: () =>
                  context.push('/modes/${widget.familyId}/${widget.modeId}/children'),
              child: Row(children: [
                GuardianIconBadge(icon: Icons.child_care_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesAssignChildren'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                            mode.assignedChildIds.isEmpty
                                ? l10n.t('modesAssignedNone')
                                : '${mode.assignedChildIds.length}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            GuardianCard(
              onTap: () => _showPriorityDialog(context, mode),
              child: Row(children: [
                GuardianIconBadge(icon: Icons.priority_high_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesPriority'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text('${mode.priority}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _showPriorityDialog(BuildContext context, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    var priority = mode.priority;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('modesPriority'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Slider(
            value: priority.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '$priority',
            activeColor: GuardianTokens.guardianTeal,
            onChanged: (v) => setState(() => priority = v.toInt()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final repo = ref.read(modeConfigRepositoryProvider);
    await _invalidateModes(ref, widget.familyId,
        () => repo.saveMode(mode.copyWith(priority: priority)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeUpdated')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showEditDialog(BuildContext context, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    _nameController.text = mode.name;
    _kind = mode.kind;
    _action = mode.action;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('modesEditMode'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: l10n.t('modesModeName'),
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModeKind>(
                value: _kind,
                decoration: InputDecoration(labelText: l10n.t('modesKind')),
                items: [
                  DropdownMenuItem(
                      value: ModeKind.homework, child: Text(l10n.t('modeKindHomework'))),
                  DropdownMenuItem(
                      value: ModeKind.bedtime, child: Text(l10n.t('modeKindBedtime'))),
                  DropdownMenuItem(
                      value: ModeKind.travel, child: Text(l10n.t('modeKindTravel'))),
                  DropdownMenuItem(
                      value: ModeKind.custom, child: Text(l10n.t('modeKindCustom'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
              ),
              DropdownButtonFormField<ModeAction>(
                value: _action,
                decoration: InputDecoration(labelText: l10n.t('modesAction')),
                items: [
                  DropdownMenuItem(
                      value: ModeAction.block, child: Text(l10n.t('modeActionBlock'))),
                  DropdownMenuItem(
                      value: ModeAction.slowDown, child: Text(l10n.t('modeActionSlowDown'))),
                  DropdownMenuItem(
                      value: ModeAction.allowlistOnly,
                      child: Text(l10n.t('modeActionAllowlistOnly'))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _action = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(modeConfigRepositoryProvider);
    await _invalidateModes(ref, widget.familyId,
        () => repo.saveMode(mode.copyWith(name: name, kind: _kind, action: _action)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeUpdated')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ───────────────────────── MD-005 Mode Schedule ───────────────────────────

/// `/modes/:familyId/:modeId/schedule` — MD-005. Active window and weekday
/// configuration.
class ModeScheduleScreen extends ConsumerStatefulWidget {
  const ModeScheduleScreen(
      {required this.familyId, required this.modeId, super.key});
  final String familyId;
  final String modeId;

  @override
  ConsumerState<ModeScheduleScreen> createState() => _ModeScheduleState();
}

class _ModeScheduleState extends ConsumerState<ModeScheduleScreen> {
  ModeConfig? _mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final modes = ref.watch(modeConfigsProvider(widget.familyId));
    final guard = _modesGuard(context, ref, widget.familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final modeList = modes.valueOrNull ?? const [];
    _mode ??= modeList.where((m) => m.modeId == widget.modeId).firstOrNull;
    final mode = _mode;
    if (mode == null) {
      return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.empty,
          title: l10n.t('modesNotFound'),
          message: l10n.t('modesNotFoundDescription'),
        ),
      );
    }

    return Directionality(
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
                        icon: Icons.schedule_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('modesScheduleMode'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(mode.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('modesScheduleSection'), children: [
            GuardianCard(
              onTap: () => _showScheduleDialog(context, mode),
              child: Row(children: [
                GuardianIconBadge(icon: Icons.event_outlined,
                    foreground: GuardianTokens.guardianTeal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('modesScheduleType'),
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(_scheduleLabel(l10n, mode.scheduleKind),
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            if (mode.scheduleKind != ModeScheduleKind.oneTime)
              GuardianCard(
                onTap: () => _showWindowDialog(context, mode),
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.access_time_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('modesActiveWindow'),
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                              '${_timeOfDay(mode.startMinute)} — '
                              '${_timeOfDay(mode.endMinute)}',
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            if (mode.scheduleKind == ModeScheduleKind.weekly)
              GuardianCard(
                onTap: () => _showWeekdaysDialog(context, mode),
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.date_range_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('modesWeekdays'),
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                              mode.weekdays
                                  .map((d) => _weekdayLabel(l10n, d))
                                  .join(' • '),
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
    );
  }

  Future<void> _saveSchedule(ModeConfig mode,
      {ModeScheduleKind? scheduleKind,
      int? startMinute,
      int? endMinute,
      Set<int>? weekdays}) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(modeConfigRepositoryProvider);
    await _invalidateModes(ref, widget.familyId,
        () => repo.saveMode(mode.copyWith(
              scheduleKind: scheduleKind,
              startMinute: startMinute,
              endMinute: endMinute,
              weekdays: weekdays,
            )));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesScheduleUpdated')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _showScheduleDialog(BuildContext context, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<ModeScheduleKind>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.t('modesScheduleType'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        children: [
          for (final kind in ModeScheduleKind.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(kind),
              child: Text(_scheduleLabel(l10n, kind)),
            ),
        ],
      ),
    );
    if (result == null) return;
    await _saveSchedule(mode, scheduleKind: result);
  }

  Future<void> _showWindowDialog(BuildContext context, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    var startMinute = mode.startMinute;
    var endMinute = mode.endMinute;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('modesActiveWindow'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${l10n.t('modesStartTime')}: ${_timeOfDay(startMinute)}',
                  style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: startMinute.toDouble(),
                min: 0,
                max: 1439,
                divisions: 48,
                label: _timeOfDay(startMinute),
                activeColor: GuardianTokens.guardianTeal,
                onChanged: (v) =>
                    setState(() => startMinute = v.round() ~/ 30 * 30),
              ),
              const SizedBox(height: 8),
              Text(
                  '${l10n.t('modesEndTime')}: ${_timeOfDay(endMinute)}',
                  style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: endMinute.toDouble(),
                min: 0,
                max: 1440,
                divisions: 48,
                label: _timeOfDay(endMinute),
                activeColor: GuardianTokens.guardianTeal,
                onChanged: (v) =>
                    setState(() => endMinute = v.round() ~/ 30 * 30),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    await _saveSchedule(mode,
        startMinute: startMinute, endMinute: endMinute);
  }

  Future<void> _showWeekdaysDialog(BuildContext context, ModeConfig mode) async {
    final l10n = AppLocalizations.of(context);
    final selected = Set<int>.from(mode.weekdays);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('modesWeekdays'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in [1, 2, 3, 4, 5, 6, 7])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_weekdayLabel(l10n, day)),
                  value: selected.contains(day),
                  activeColor: GuardianTokens.guardianTeal,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(day);
                      } else {
                        selected.remove(day);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('save')),
            ),
          ],
        ),
      ),
    );
    if (result != true || selected.isEmpty) return;
    await _saveSchedule(mode, weekdays: selected);
  }
}

// ───────────────────────── MD-006 Assign Children ─────────────────────────

/// `/modes/:familyId/:modeId/children` — MD-006. Assign / unassign children.
class ModeChildrenScreen extends ConsumerStatefulWidget {
  const ModeChildrenScreen(
      {required this.familyId, required this.modeId, super.key});
  final String familyId;
  final String modeId;

  @override
  ConsumerState<ModeChildrenScreen> createState() => _ModeChildrenState();
}

class _ModeChildrenState extends ConsumerState<ModeChildrenScreen> {
  ModeConfig? _mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final modes = ref.watch(modeConfigsProvider(widget.familyId));
    final guard = _modesGuard(context, ref, widget.familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final modeList = modes.valueOrNull ?? const [];
    _mode ??= modeList.where((m) => m.modeId == widget.modeId).firstOrNull;
    final mode = _mode;
    final contextValue = runtime.valueOrNull!;
    final children = contextValue.children;

    if (mode == null) {
      return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: GuardianStateView(
          state: GuardianViewState.empty,
          title: l10n.t('modesNotFound'),
          message: l10n.t('modesNotFoundDescription'),
        ),
      );
    }

    return Directionality(
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
                        icon: Icons.child_care_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('modesAssignChildren'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${mode.name} — ${children.length}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (children.isEmpty)
            GuardianStateView(
              state: GuardianViewState.empty,
              title: l10n.t('modesNoChildren'),
              message: l10n.t('modesNoChildrenDescription'),
            )
          else
            GuardianSection(
                title: l10n.t('modesChildrenSection'),
                children: [
                  for (final child in children)
                    GuardianCard(
                      child: Row(children: [
                        GuardianIconBadge(icon: Icons.person_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(child.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall),
                                const SizedBox(height: 2),
                                Text(child.role.name,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]),
                        ),
                        Switch(
                          value: mode.assignedChildIds.contains(child.id),
                          activeColor: GuardianTokens.guardianTeal,
                          onChanged: (checked) =>
                              _toggleChild(mode, child.id, checked),
                        ),
                      ]),
                    ),
                ]),
        ],
      ),
    );
  }

  Future<void> _toggleChild(ModeConfig mode, String childId, bool checked) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(modeConfigRepositoryProvider);
    final assigned = Set<String>.from(mode.assignedChildIds);
    if (checked) {
      assigned.add(childId);
    } else {
      assigned.remove(childId);
    }
    await _invalidateModes(
        ref, widget.familyId, () => repo.saveMode(mode.copyWith(assignedChildIds: assigned)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesChildrenUpdated')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ───────────────────────── MD-007 Activation History ──────────────────────

/// `/modes/:familyId/:modeId/history` — MD-007. Honest activation log.
class ModeActivationHistoryScreen extends ConsumerWidget {
  const ModeActivationHistoryScreen(
      {required this.familyId, required this.modeId, super.key});
  final String familyId;
  final String modeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final activations = ref.watch(modeActivationsProvider(familyId));
    final guard = _modesGuard(context, ref, familyId, runtime, activations,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final activationList = activations.valueOrNull ?? const [];
    final scoped =
        activationList.where((a) => a.modeId == modeId).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final modes = ref.read(modeConfigsProvider(familyId)).valueOrNull ?? const [];
    final mode = modes.where((m) => m.modeId == modeId).firstOrNull;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(modeActivationsProvider(familyId)),
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
                          icon: Icons.history_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('modesActivationHistory'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('${mode?.name ?? modeId} — ${scoped.length}',
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
            if (scoped.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('modesNoActivationsYet'),
                message: l10n.t('modesActivationsEmptyDescription'),
              )
            else
              GuardianSection(
                  title: l10n.t('modesActivations'),
                  children: [
                    for (final activation in scoped)
                      GuardianCard(
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: _activationKind(activation.state) ==
                                      GuardianStatusKind.safe
                                  ? Icons.check_circle_outline
                                  : activation.state == 'requested'
                                      ? Icons.hourglass_empty
                                      : activation.state == 'failed'
                                          ? Icons.error_outline
                                          : Icons.timelapse_outlined,
                              foreground: _activationKind(activation.state) ==
                                      GuardianStatusKind.alert
                                  ? const Color(0xFFC85000)
                                  : GuardianTokens.guardianTeal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _activationStateLabel(
                                          l10n, activation.state),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${_timestamp(activation.startedAt)}'
                                      '${activation.decidedBy != null ? " • ${activation.decidedBy}" : ""}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ]),
                          ),
                          GuardianStatusChip(
                              kind: _activationKind(activation.state),
                              label: l10n.t('modesHonestState')),
                        ]),
                      ),
                  ]),
          ],
        ),
      ),
    );
  }
}

String _timestamp(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

// ───────────────────────── MD-008 Child Active Modes ──────────────────────

/// `/child/:familyId/:childId/mode` — MD-008. The child's own view of
/// currently active modes affecting them. Read-only, honest state.
class ChildActiveModeScreen extends ConsumerWidget {
  const ChildActiveModeScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final modes = ref.watch(modeChildConfigsProvider((familyId: familyId, childId: childId)));

    if (runtime.hasError || modes.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(familyId));
              ref.invalidate(modeChildConfigsProvider(
                  (familyId: familyId, childId: childId)));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || modes.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewOwnPolicy)) {
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
    final modeList = modes.valueOrNull ?? const [];
    final actor = contextValue.actor;
    final isOwn = actor != null && actor.id == childId;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(
          modeChildConfigsProvider((familyId: familyId, childId: childId))),
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
                          icon: Icons.tune_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('modesMyModes'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('modesMyModesDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 10),
                  if (!isOwn)
                    GuardianStatusChip(
                        kind: GuardianStatusKind.watch,
                        label: l10n.t('modesNotYourProfile')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            if (modeList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('modesNoActiveModes'),
                message: l10n.t('modesNoActiveModesDescription'),
              )
            else
              GuardianSection(
                  title: l10n.t('modesActiveModes'),
                  children: [
                    for (final mode in modeList)
                      GuardianCard(
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: mode.kind == ModeKind.bedtime
                                  ? Icons.nightlight_outlined
                                  : mode.kind == ModeKind.homework
                                      ? Icons.menu_book_outlined
                                      : mode.kind == ModeKind.travel
                                          ? Icons.luggage_outlined
                                          : Icons.tune_outlined,
                              foreground: GuardianTokens.guardianTeal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(mode.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${_actionLabel(l10n, mode.action)} • '
                                      '${_timeOfDay(mode.startMinute)} — '
                                      '${_timeOfDay(mode.endMinute)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ]),
                          ),
                          GuardianStatusChip(
                              kind: GuardianStatusKind.safe,
                              label: l10n.t('modesActiveNow')),
                        ]),
                      ),
                  ]),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── MD-009 Conflict Resolver ───────────────────────

/// `/modes/:familyId/conflict` — MD-009. Deterministic conflict ordering
/// across all family modes. Every overlap is recorded, nothing is
/// silently overridden.
class ModeConflictScreen extends ConsumerWidget {
  const ModeConflictScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final modes = ref.watch(modeConfigsProvider(familyId));
    final guard = _modesGuard(context, ref, familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final modeList = modes.valueOrNull ?? const [];
    final contextValue = runtime.valueOrNull!;
    final children = contextValue.children;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(modeConfigsProvider(familyId)),
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
                          icon: Icons.compare_arrows_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('modesConflictResolver'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.t('modesConflictDescription'),
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
            if (modeList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('modesNoModesYet'),
                message: l10n.t('modesCreateFirst'),
              )
            else
              GuardianSection(
                  title: l10n.t('modesConflictOrder'),
                  children: [
                    for (final child in children) ...[
                      GuardianCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                GuardianIconBadge(icon: Icons.person_outline),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(child.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              ..._conflictRows(
                                  context, l10n, modeList, child.id),
                              if (_conflictRows(context, l10n, modeList, child.id)
                                  .isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 48),
                                  child: Text(l10n.t('modesNoOverlap'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                ),
                            ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _conflictRows(BuildContext context, AppLocalizations l10n,
      List<ModeConfig> modeList, String childId) {
    final resolver = const ModeConflictResolver();
    final ordered = resolver.effectiveOrder(
        modes: modeList, childId: childId, moment: DateTime.now());
    if (ordered.length < 2) return const [];
    final conflicts = resolver.conflicts(ordered: ordered, childId: childId);
    return [
      Padding(
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: Text(
            '${l10n.t('modesConflictWinner')}: ${ordered.first.name} '
            '(${l10n.t('modesPriority')}: ${ordered.first.priority})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: GuardianTokens.guardianTeal, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 4),
      for (final conflict in conflicts)
        Row(children: [
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                '${conflict.loser.name} — ${l10n.t('modesConflictLoser')} '
                '(${conflict.reason == 'higher_priority' ? l10n.t('modesLoserHigherPriority') : l10n.t('modesLoserEarlierCreation')})',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ]),
    ];
  }
}

// ───────────────────────── MD-010 Mode Templates ──────────────────────────

/// `/modes/:familyId/templates` — MD-010. Browse built-in mode presets
/// before creating one.
class ModeTemplatesScreen extends ConsumerWidget {
  const ModeTemplatesScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final modes = ref.watch(modeConfigsProvider(familyId));
    final guard = _modesGuard(context, ref, familyId, runtime, modes,
        FamilyPermission.managePolicies);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }

    return Directionality(
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
                        icon: Icons.auto_fix_high_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('modesTemplates'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(l10n.t('modesTemplatesDescription'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(
              title: l10n.t('modesBuiltInTemplates'),
              children: [
                for (final template in ModeTemplate.builtIns)
                  GuardianCard(
                    onTap: () => _createFromTemplate(context, ref, template),
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: template.key == 'homework'
                              ? Icons.menu_book_outlined
                              : template.key == 'bedtime'
                                  ? Icons.nightlight_outlined
                                  : Icons.luggage_outlined,
                          foreground: GuardianTokens.guardianTeal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_kindLabel(l10n, template.mode.kind),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(template.description,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${_actionLabel(l10n, template.mode.action)} • '
                                  '${_scheduleLabel(l10n, template.mode.scheduleKind)} • '
                                  '${l10n.t('modesPriority')}: ${template.mode.priority}',
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
    );
  }

  Future<void> _createFromTemplate(
      BuildContext context, WidgetRef ref, ModeTemplate template) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(modeConfigRepositoryProvider);
    final contextValue =
        ref.read(familyRuntimeContextProvider(familyId)).valueOrNull;
    final children = contextValue?.children ?? const <FamilyMember>[];
    final mode = template.mode.copyWith(
      modeId: 'mode-$familyId-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      familyId: familyId,
      assignedChildIds: children.map((c) => c.id).toSet(),
      createdAt: DateTime.now(),
    );
    await repo.saveMode(mode);
    await _invalidateModes(ref, familyId, () async {});
    context.pushReplacement('/modes/$familyId');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('modesModeCreated')),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
