import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/family_rules.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

const Uuid _uuid = Uuid();

/// FS-011 — Family Rules & Policy Engine screens (FR-001 … FR-007).
///
/// Same visual grammar as every other subsystem: `GuardianHeroCard` header,
/// `GuardianSection` + `GuardianCard` rows, `GuardianStatTile` /
/// `GuardianStatusChip` / `GuardianStateView`, and `FamilyRuntimeContext.can()`
/// as the only authorization gate. The engine is coherent with FS-002
/// (content categories), FS-003 (app blocks), FS-005 (mode windows), FS-001
/// (geofences) and FS-006 (SOS): every previously scattered restriction can
/// now be authored as a single scheduled `FamilyRule`.
///
/// Honest-state contract: a rule shows its real `SyncState`; conflicts are
/// surfaced, never silently overridden; the execution log records only
/// verdicts the device actually produced.

String _timeOfDay(int minute) {
  final clamped = ((minute % 1440) + 1440) % 1440;
  return '${(clamped ~/ 60).toString().padLeft(2, '0')}:${(clamped % 60).toString().padLeft(2, '0')}';
}

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

IconData _kindIcon(RuleKind kind) {
  return switch (kind) {
    RuleKind.dailyScreenTime => Icons.timer_outlined,
    RuleKind.bedtime => Icons.bedtime_outlined,
    RuleKind.homework => Icons.school_outlined,
    RuleKind.appRule => Icons.apps_outlined,
    RuleKind.contentCategory => Icons.filter_list_outlined,
    RuleKind.geofenceRule => Icons.location_on_outlined,
    RuleKind.sosRule => Icons.emergency_outlined,
    RuleKind.taskGated => Icons.task_outlined,
    RuleKind.rewardUnlocked => Icons.card_giftcard_outlined,
    RuleKind.eventOverride => Icons.event_outlined,
  };
}

String _assignedChildrenLabel(
    AppLocalizations l10n, List<FamilyMember> children, Set<String> ids) {
  if (ids.isEmpty) return l10n.t('frAssignedAll');
  final names =
      children.where((c) => ids.contains(c.id)).map((c) => c.displayName);
  final joined = names.join('، ');
  if (joined.isEmpty) return l10n.t('frAssignedNone');
  return joined;
}

String _windowLabel(AppLocalizations l10n, FamilyRule rule) {
  if (rule.scheduleKind == RuleScheduleKind.oneTime) {
    final at = rule.oneshotAt;
    return at == null
        ? l10n.t('frScheduleNone')
        : '${_timeOfDay(at.hour * 60 + at.minute)} — ${_weekdayLabel(l10n, at.weekday)}';
  }
  final start = _timeOfDay(rule.startMinute);
  final end =
      rule.endMinute == 0 && rule.startMinute != 0 ? '24:00' : _timeOfDay(rule.endMinute);
  final days = rule.scheduleKind == RuleScheduleKind.weekly
      ? (rule.weekdays.toList()..sort())
      : const <int>[];
  final suffix = days.isEmpty
      ? l10n.t('frDailyAll')
      : days.map((d) => _weekdayLabel(l10n, d)).join('، ');
  return '$start – $end · $suffix';
}

// ── Shared guard ────────────────────────────────────────────────────────────
Widget _rulesGuard(
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
          onRetry: () {
            ref.invalidate(rulesListProvider(familyId));
            ref.invalidate(ruleConflictsProvider(familyId));
            ref.invalidate(ruleExecutionLogProvider(familyId));
          },
        ),
      ),
    );
  }
  final ctx = runtime.valueOrNull is FamilyRuntimeContext
      ? runtime.valueOrNull as FamilyRuntimeContext
      : null;
  if (ctx == null || runtime.isLoading || data.isLoading) {
    return Scaffold(
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const GuardianStateView(state: GuardianViewState.loading),
      ),
    );
  }
  if (!ctx.can(permission)) {
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

Future<void> _invalidateRules(
    WidgetRef ref, String familyId, Future<void> Function() mutation) async {
  await mutation();
  ref.invalidate(rulesListProvider(familyId));
  ref.invalidate(ruleConflictsProvider(familyId));
  ref.invalidate(ruleExecutionLogProvider(familyId));
}

// ═════════════════════════════ FR-001 — Dashboard ════════════════════════════
/// `/rules/:familyId` — FR-001. The unified rule book: every active family
/// rule in one place with its honest sync state, plus the management
/// destinations (builder, conflicts, execution log).
class FamilyRulesDashboardScreen extends ConsumerWidget {
  const FamilyRulesDashboardScreen({super.key});

  static const route = '/rules/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final rules = ref.watch(rulesListProvider(familyId));
    final conflicts = ref.watch(ruleConflictsProvider(familyId));
    final guard =
        _rulesGuard(context, ref, familyId, runtime, rules, FamilyPermission.viewFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final ruleList = rules.valueOrNull ?? const [];
    final enabled = ruleList.where((r) => r.enabled).length;
    final conflictCount = conflicts.valueOrNull?.length ?? 0;
    final canManage = ctx.can(FamilyPermission.manageFamilyRules);
    final children = ctx.children;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(rulesListProvider(familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('frDashboardTitle'),
                style: Theme.of(context).textTheme.titleLarge),
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
                            icon: Icons.policy_outlined,
                            background: Colors.white24,
                            foreground: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.t('frDashboardTitle'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.t('frDashboardSubtitle'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.rule_outlined,
                      value: '$enabled/${ruleList.length}',
                      label: l10n.t('frActiveRules'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.warning_amber_outlined,
                      value: '$conflictCount',
                      label: l10n.t('frConflicts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.child_care_outlined,
                      value: '${ruleList.where((r) => r.enabled).expand((r) => r.assignedChildIds.isEmpty ? children.map((c) => c.id) : r.assignedChildIds).toSet().length}',
                      label: l10n.t('frAffectedChildren'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('frManageSection'), children: [
                GuardianCard(
                  onTap: canManage
                      ? () => context.push('/rules/$familyId/new')
                      : null,
                  child: Row(children: [
                    const GuardianIconBadge(icon: Icons.add_circle_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('frCreateRule'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('frCreateRuleHint'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.black54)),
                          ]),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ]),
                ),
                GuardianCard(
                  onTap: () => context.push('/rules/$familyId/conflicts'),
                  child: Row(children: [
                    GuardianIconBadge(
                        icon: Icons.balance_outlined,
                        background: conflictCount > 0
                            ? GuardianStatusKind.alert.palette.text
                            : GuardianTokens.guardianTealSoft),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('frConflictsSection'),
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                                conflictCount > 0
                                    ? l10n.t('frConflictsOpenHint')
                                    : l10n.t('frNoConflictsHint'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.black54)),
                          ]),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ]),
                ),
                GuardianCard(
                  onTap: () => context.push('/rules/$familyId/log'),
                  child: Row(children: [
                    const GuardianIconBadge(icon: Icons.history_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('frLogTitle'),
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('frLogHint'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.black54)),
                          ]),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              GuardianSection(
                title: l10n.t('frRulesSection'),
                trailing: !canManage
                    ? null
                    : null,
                children: rules.when(
                  loading: () => [
                    const GuardianStateView(state: GuardianViewState.loading)
                  ],
                  error: (_, __) => [
                    GuardianStateView(
                      state: GuardianViewState.error,
                      title: l10n.t('monitoringSyncFailed'),
                      message: l10n.t('somethingWentWrong'),
                    )
                  ],
                  data: (list) => list.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/family_rules.png',
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          GuardianStateView(
                            state: GuardianViewState.empty,
                            title: l10n.t('frNoRules'),
                            message: l10n.t('frNoRulesDescription'),
                          ),
                        ]
                      : [
                          for (final rule in list)
                            GuardianCard(
                              onTap: canManage
                                  ? () => context.push(
                                      '/rules/$familyId/edit/${rule.ruleId}')
                                  : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    GuardianIconBadge(
                                        icon: _kindIcon(rule.kind),
                                        background: GuardianTokens
                                            .guardianTealSoft),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(rule.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium),
                                            Text(
                                                l10n.t(rule.kind.labelKey),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                        color:
                                                            Colors.black54)),
                                          ]),
                                    ),
                                    GuardianStatusChip(
                                      label: rule.enabled
                                          ? l10n.t('frRuleOn')
                                          : l10n.t('frRuleOff'),
                                      kind: rule.enabled
                                          ? GuardianStatusKind.safe
                                          : GuardianStatusKind.offline,
                                    ),
                                  ]),
                                  const SizedBox(height: 10),
                                  Text(_windowLabel(l10n, rule),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 6),
                                  Text(
                                      '${l10n.t('frAssignedTo')}: ${_assignedChildrenLabel(l10n, children, rule.assignedChildIds)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton.icon(
                                          onPressed: canManage
                                              ? () => _invalidateRules(
                                                  ref,
                                                  familyId,
                                                  () => ref
                                                      .read(
                                                          familyRulesRepositoryProvider)
                                                      .toggleEnabled(
                                                          familyId: familyId,
                                                          ruleId: rule.ruleId))
                                              : null,
                                          icon: Icon(
                                              rule.enabled
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              size: 18),
                                          label: Text(rule.enabled
                                              ? l10n.t('frPauseRule')
                                              : l10n.t('frResumeRule')),
                                        ),
                                      ),
                                      if (canManage)
                                        IconButton(
                                          tooltip: l10n.t('delete'),
                                          onPressed: () => _confirmDelete(
                                              context, ref, familyId, rule),
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String familyId, FamilyRule rule) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.t('frDeleteRule'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: Text('${l10n.t('frDeleteRuleConfirm')} “${rule.name}”'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('delete'))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _invalidateRules(
            ref, familyId, () => ref.read(familyRulesRepositoryProvider).delete(familyId, rule.ruleId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('frRuleDeleted')),
              behavior: SnackBarBehavior.floating));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('monitoringSyncFailed')),
              behavior: SnackBarBehavior.floating,
              backgroundColor: GuardianTokens.guardianNavy));
        }
      }
    }
  }
}

// ═════════════════════════════ FR-002 — Rule Builder ═════════════════════════
/// `/rules/:familyId/new` — FR-002. Compose one coherent rule: kind, window,
/// targets, children, priority. One screen replaces four scattered settings.
class RuleBuilderScreen extends ConsumerStatefulWidget {
  const RuleBuilderScreen({super.key});

  static const route = '/rules/:familyId/new';

  @override
  ConsumerState<RuleBuilderScreen> createState() => _RuleBuilderState();
}

class _RuleBuilderState extends ConsumerState<RuleBuilderScreen> {
  final _name = TextEditingController();
  RuleKind _kind = RuleKind.dailyScreenTime;
  RuleAction _action = RuleAction.restrict;
  int _startMinute = 330; // 05:30
  int _endMinute = 1320; // 22:00
  RuleScheduleKind _scheduleKind = RuleScheduleKind.daily;
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  Set<String> _children = const {};
  Set<String> _apps = const {};
  Set<String> _categories = const {};
  Set<String> _geofences = const {};
  GeofenceTrigger _geofenceTrigger = GeofenceTrigger.entering;
  String _linkedTaskId = '';
  DateTime? _oneshotAt;
  int _priority = 50;
  int? _limitMinutes;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final repo = ref.read(familyRulesRepositoryProvider);
      final familyId =
          GoRouterState.of(context).pathParameters['familyId'] ?? '';
      final rule = FamilyRule(
        ruleId: _uuid.v4(),
        familyId: familyId,
        name: _name.text.trim(),
        kind: _kind,
        action: _action,
        startMinute: _startMinute,
        endMinute: _endMinute,
        scheduleKind: _scheduleKind,
        weekdays: _weekdays,
        assignedChildIds: _children,
        appTargets: _apps,
        categoryTargets: _categories,
        geofenceIds: _geofences,
        geofenceTrigger: _geofenceTrigger,
        linkedTaskId: _linkedTaskId,
        oneshotAt: _oneshotAt,
        limitMinutes:
            _kind == RuleKind.dailyScreenTime ? _limitMinutes : null,
        priority: _priority,
        createdByMemberId: ref
                .read(familyRuntimeContextProvider(familyId))
                .valueOrNull
                ?.actor
                ?.id ??
            null,
      );
      await repo.create(rule, createdByMemberId: rule.createdByMemberId ?? '');
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('monitoringSyncFailed')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: GuardianTokens.guardianNavy));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(String field) async {
    final current = field == 'start' ? _startMinute : _endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      builder: (pickerContext, child) => MediaQuery(
        data: MediaQuery.of(pickerContext)
            .copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final minute = picked.hour * 60 + picked.minute;
    setState(() {
      if (field == 'start') {
        _startMinute = minute;
      } else {
        _endMinute = minute;
      }
    });
  }

  Future<void> _pickWeekdays() async {
    final l10n = AppLocalizations.of(context);
    final selected = Set<int>.from(_weekdays);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frWeekdays'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true && selected.isNotEmpty) {
      setState(() => _weekdays = selected);
    }
  }

  Future<void> _pickChildren() async {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.read(familyRuntimeContextProvider(familyId));
    final children = runtime.valueOrNull?.children ?? const <FamilyMember>[];
    final selected = Set<String>.from(_children);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frAssignChildren'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('frAssignedAll')),
              value: selected.isEmpty,
              activeColor: GuardianTokens.guardianTeal,
              onChanged: (checked) {
                setState(() => selected
                  ..clear());
              },
            ),
            for (final child in children)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(child.displayName),
                value: selected.contains(child.id),
                activeColor: GuardianTokens.guardianTeal,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selected.add(child.id);
                    } else {
                      selected.remove(child.id);
                    }
                  });
                },
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true) setState(() => _children = selected);
  }

  Future<void> _pickApps() async {
    final l10n = AppLocalizations.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.t('frAppTargets'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
                hintText: l10n.t('frAppTargetHint'),
                border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(controller.text.trim()),
                child: Text(l10n.t('save'))),
          ],
        );
      },
    );
    if (entered != null && entered.isNotEmpty) {
      setState(() => _apps = {..._apps, entered});
    }
  }

  Future<void> _pickCategories() async {
    final l10n = AppLocalizations.of(context);
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.t('frCategoryTargets'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
                hintText: l10n.t('frCategoryTargetHint'),
                border: const OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(controller.text.trim()),
                child: Text(l10n.t('save'))),
          ],
        );
      },
    );
    if (entered != null && entered.isNotEmpty) {
      setState(() => _categories = {..._categories, entered});
    }
  }

  Future<void> _pickOneshotDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneshotAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _oneshotAt = picked);
  }

  Future<void> _pickGeofences() async {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final geofencesAsync = ref.read(geofencesProvider(familyId));
    final geofences = geofencesAsync.valueOrNull ?? [];
    final selected = Set<String>.from(_geofences);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frCategoryTargets'), // Reusing for Geofences
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: geofences.isEmpty
              ? Text(l10n.t('noData'))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final g in geofences)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.name),
                      value: selected.contains(g.id),
                      activeColor: GuardianTokens.guardianTeal,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(g.id);
                          } else {
                            selected.remove(g.id);
                          }
                        });
                      },
                    ),
                ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true) setState(() => _geofences = selected);
  }

  Future<void> _pickLinkedTask() async {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final tasksAsync = ref.read(tasksListProvider(familyId));
    final tasks = tasksAsync.valueOrNull ?? [];

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('rwLinkedRule'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: tasks.isEmpty
            ? Text(l10n.t('noData'))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                for (final t in tasks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.title),
                    trailing: _linkedTaskId == t.taskId
                        ? const Icon(Icons.check, color: GuardianTokens.guardianTeal)
                        : null,
                    onTap: () => Navigator.of(dialogContext).pop(t.taskId),
                  ),
              ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel'))),
        ],
      ),
    );
    if (result != null) setState(() => _linkedTaskId = result);
  }

  void _kindChanged(RuleKind? kind) {
    if (kind == null) return;
    setState(() {
      _kind = kind;
      switch (kind) {
        case RuleKind.bedtime:
          _startMinute = 1320; // 22:00
          _endMinute = 420; // 07:00
          _action = RuleAction.block;
        case RuleKind.homework:
          _startMinute = 900; // 15:00
          _endMinute = 1080; // 18:00
          _action = RuleAction.allowlistOnly;
        case RuleKind.dailyScreenTime:
          _startMinute = 330; // 05:30
          _endMinute = 1320; // 22:00
          _action = RuleAction.restrict;
        case RuleKind.appRule:
          _action = RuleAction.block;
        case RuleKind.contentCategory:
          _action = RuleAction.block;
        case RuleKind.geofenceRule:
          _action = RuleAction.notifyOnly;
        case RuleKind.sosRule:
          _action = RuleAction.allowlistOnly;
        case RuleKind.taskGated:
          _action = RuleAction.restrict;
        case RuleKind.rewardUnlocked:
          _action = RuleAction.restrict;
        case RuleKind.eventOverride:
          _action = RuleAction.restrict;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, const AsyncData(null), FamilyPermission.manageFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final children = runtime.valueOrNull?.children ?? const <FamilyMember>[];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frCreateRuleTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianSection(title: l10n.t('frRuleIdentitySection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                          labelText: l10n.t('frRuleName'),
                          hintText: l10n.t('frRuleNameHint'),
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RuleKind>(
                      initialValue: _kind,
                      decoration:
                          InputDecoration(labelText: l10n.t('frRuleKind')),
                      items: RuleKind.values
                          .map((kind) => DropdownMenuItem(
                                value: kind,
                                child: Row(children: [
                                  Icon(_kindIcon(kind), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(l10n.t(kind.labelKey))),
                                ]),
                              ))
                          .toList(),
                      onChanged: _kindChanged,
                    ),
                    const SizedBox(height: 12),
                    if (_kind != RuleKind.sosRule)
                      DropdownButtonFormField<RuleAction>(
                        initialValue: _action,
                        decoration:
                            InputDecoration(labelText: l10n.t('frRuleAction')),
                        items: RuleAction.values
                            .map((action) => DropdownMenuItem(
                                  value: action,
                                  child: Text(l10n.t(_actionLabel(action))),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _action = value);
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: Text(l10n.t('frPriority'),
                              style: Theme.of(context).textTheme.bodyMedium)),
                      const SizedBox(width: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _priority,
                        decoration:
                            InputDecoration(labelText: l10n.t('frPriority')),
                        items: const [25, 50, 75, 100]
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text('$p')))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _priority = value);
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('frWindowSection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickTime('start'),
                          icon: const Icon(Icons.wb_twilight, size: 18),
                          label: Text('${l10n.t('frStart')}: ${_timeOfDay(_startMinute)}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickTime('end'),
                          icon: const Icon(Icons.nightlight, size: 18),
                          label: Text('${l10n.t('frEnd')}: ${_timeOfDay(_endMinute)}'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RuleScheduleKind>(
                      initialValue: _scheduleKind,
                      decoration:
                          InputDecoration(labelText: l10n.t('frScheduleKind')),
                      items: RuleScheduleKind.values
                          .map((kind) => DropdownMenuItem(
                                value: kind,
                                child: Text(l10n.t(_scheduleLabel(kind))),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _scheduleKind = value);
                        }
                      },
                    ),
                    if (_scheduleKind == RuleScheduleKind.weekly)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                          onPressed: _pickWeekdays,
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: Text(l10n.t('frChooseWeekdays')),
                        ),
                      ),
                    if (_scheduleKind == RuleScheduleKind.oneTime)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                          onPressed: _pickOneshotDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(_oneshotAt == null
                              ? l10n.t('frPick')
                              : _oneshotAt!.toIso8601String().split('T')[0]),
                        ),
                      ),
                    if (_kind == RuleKind.dailyScreenTime) ...[
                      const SizedBox(height: 12),
                      TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                            labelText: l10n.t('frLimitMinutes'),
                            hintText: l10n.t('frLimitMinutesHint'),
                            border: const OutlineInputBorder()),
                        onChanged: (raw) {
                          final minutes = int.tryParse(raw);
                          setState(() =>
                              _limitMinutes =
                                  minutes != null && minutes > 0 ? minutes : null);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('frTargetsSection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickChildren,
                      icon: const Icon(Icons.child_care_outlined, size: 18),
                      label: Text(
                          '${l10n.t('frAssignChildren')}: ${_assignedChildrenLabel(l10n, children, _children)}'),
                    ),
                    const SizedBox(height: 8),
                    if (_kind == RuleKind.appRule ||
                        _kind == RuleKind.homework ||
                        _kind == RuleKind.sosRule)
                      ElevatedButton.icon(
                        onPressed: _pickApps,
                        icon: const Icon(Icons.apps_outlined, size: 18),
                        label: Text('${l10n.t('frAppTargets')}: ${_apps.isEmpty ? l10n.t('frPick') : _apps.join(', ')}'),
                      ),
                    if (_kind == RuleKind.contentCategory)
                      ElevatedButton.icon(
                        onPressed: _pickCategories,
                        icon: const Icon(Icons.filter_list_outlined, size: 18),
                        label: Text('${l10n.t('frCategoryTargets')}: ${_categories.isEmpty ? l10n.t('frPick') : _categories.join(', ')}'),
                      ),
                    if (_kind == RuleKind.geofenceRule) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickGeofences,
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: Text('${l10n.t('frCategoryTargets')}: ${_geofences.isEmpty ? l10n.t('frPick') : _geofences.join(', ')}'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<GeofenceTrigger>(
                        initialValue: _geofenceTrigger,
                        decoration: InputDecoration(
                            labelText: l10n.t('frRuleAction')), // Reusing label for trigger
                        items: GeofenceTrigger.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _geofenceTrigger = v);
                        },
                      ),
                    ],
                    if (_kind == RuleKind.taskGated) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickLinkedTask,
                        icon: const Icon(Icons.task_outlined, size: 18),
                        label: Text('${l10n.t('rwLinkedRule')}: ${_linkedTaskId.isEmpty ? l10n.t('frPick') : _linkedTaskId}'),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: GuardianTokens.guardianTeal,
                    foregroundColor: Colors.white),
                child: _saving
                    ? const CircularProgressIndicator()
                    : Text(l10n.t('frSaveRule')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(RuleAction action) => switch (action) {
        RuleAction.block => 'frActionBlock',
        RuleAction.restrict => 'frActionRestrict',
        RuleAction.allowlistOnly => 'frActionAllowlist',
        RuleAction.notifyOnly => 'frActionNotify',
      };

  String _scheduleLabel(RuleScheduleKind kind) => switch (kind) {
        RuleScheduleKind.daily => 'frScheduleDaily',
        RuleScheduleKind.weekly => 'frScheduleWeekly',
        RuleScheduleKind.oneTime => 'frScheduleOneTime',
      };
}

// ═══════════════════════════ FR-003 — Rule Editor ════════════════════════════
/// `/rules/:familyId/edit/:ruleId` — FR-003. Edit any attribute of a saved
/// rule; the editor reuses the same grammar as the builder so parents never
/// learn a second form.
class RuleEditScreen extends ConsumerStatefulWidget {
  const RuleEditScreen({super.key});

  static const route = '/rules/:familyId/edit/:ruleId';

  @override
  ConsumerState<RuleEditScreen> createState() => _RuleEditState();
}

class _RuleEditState extends ConsumerState<RuleEditScreen> {
  late final TextEditingController _name;
  FamilyRule? _rule;
  RuleAction _action = RuleAction.restrict;
  Set<int> _weekdays = const {};
  Set<String> _apps = const {};
  Set<String> _categories = const {};
  Set<String> _geofences = const {};
  GeofenceTrigger _geofenceTrigger = GeofenceTrigger.entering;
  String _linkedTaskId = '';
  DateTime? _oneshotAt;
  int _priority = 50;
  int? _limitMinutes;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  FamilyRule? _materialize() {
    if (_rule == null) return null;
    final rule = _rule!;
    return rule.copyWith(
      name: _name.text.trim().isEmpty ? rule.name : _name.text.trim(),
      action: _action,
      weekdays: _weekdays.isEmpty ? rule.weekdays : _weekdays,
      appTargets: _apps,
      categoryTargets: _categories,
      geofenceIds: _geofences,
      geofenceTrigger: _geofenceTrigger,
      linkedTaskId: _linkedTaskId,
      oneshotAt: _oneshotAt,
      priority: _priority,
      limitMinutes: _limitMinutes,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final rule = _materialize();
    if (rule == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(familyRulesRepositoryProvider).update(rule);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('monitoringSyncFailed')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: GuardianTokens.guardianNavy));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final ruleId = GoRouterState.of(context).pathParameters['ruleId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final detail = ref.watch(ruleDetailProvider((familyId: familyId, ruleId: ruleId)));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, detail, FamilyPermission.manageFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final rule = detail.valueOrNull;
    final children =
        ref.read(familyRuntimeContextProvider(familyId)).valueOrNull?.children ??
            const <FamilyMember>[];
    if (!_loaded && rule != null) {
      _loaded = true;
      _rule = rule;
      _name.text = rule.name;
      _action = rule.action;
      _weekdays = rule.weekdays;
      _apps = rule.appTargets;
      _categories = rule.categoryTargets;
      _geofences = rule.geofenceIds;
      _geofenceTrigger = rule.geofenceTrigger;
      _linkedTaskId = rule.linkedTaskId;
      _oneshotAt = rule.oneshotAt;
      _priority = rule.priority;
      _limitMinutes = rule.limitMinutes;
    }
    if (rule == null) {
      return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: const Scaffold(
          body: GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frEditRuleTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Row(children: [
                GuardianIconBadge(icon: _kindIcon(rule.kind),
                    background: Colors.white24, foreground: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rule.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                        Text(l10n.t(rule.kind.labelKey),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70)),
                      ]),
                ),
                GuardianStatusChip(
                  label: rule.enabled ? l10n.t('frRuleOn') : l10n.t('frRuleOff'),
                  kind: rule.enabled
                      ? GuardianStatusKind.safe
                      : GuardianStatusKind.offline,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('frRuleIdentitySection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                          labelText: l10n.t('frRuleName'),
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RuleAction>(
                      initialValue: _action,
                      decoration:
                          InputDecoration(labelText: l10n.t('frRuleAction')),
                      items: RuleAction.values
                          .map((action) => DropdownMenuItem(
                                value: action,
                                child: Text(l10n.t(_actionLabel(action))),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _action = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: Text(l10n.t('frPriority'),
                              style: Theme.of(context).textTheme.bodyMedium)),
                      const SizedBox(width: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _priority,
                        decoration:
                            InputDecoration(labelText: l10n.t('frPriority')),
                        items: const [25, 50, 75, 100]
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text('$p')))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _priority = value);
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('frWindowSection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(_windowLabel(l10n, rule),
                          style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                    const SizedBox(height: 12),
                    if (rule.scheduleKind == RuleScheduleKind.weekly)
                      ElevatedButton.icon(
                        onPressed: _pickWeekdays,
                        icon: const Icon(Icons.calendar_month, size: 18),
                        label: Text(l10n.t('frChooseWeekdays')),
                      ),
                    if (rule.scheduleKind == RuleScheduleKind.oneTime)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ElevatedButton.icon(
                          onPressed: _pickOneshotDate,
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(_oneshotAt == null
                              ? l10n.t('frPick')
                              : _oneshotAt!.toIso8601String().split('T')[0]),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('frTargetsSection'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${l10n.t('frAssignedTo')}: ${_assignedChildrenLabel(l10n, children, rule.assignedChildIds)}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickChildren,
                      icon: const Icon(Icons.child_care_outlined, size: 18),
                      label: Text(l10n.t('frReassignChildren')),
                    ),
                    const SizedBox(height: 8),
                    if (_apps.isNotEmpty || _categories.isNotEmpty) ...[
                      Text(
                          '${l10n.t('frAppTargets')}: ${_apps.isEmpty ? '-' : _apps.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                          '${l10n.t('frCategoryTargets')}: ${_categories.isEmpty ? '-' : _categories.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (rule.kind == RuleKind.geofenceRule) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickGeofences,
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: Text('${l10n.t('frCategoryTargets')}: ${_geofences.isEmpty ? l10n.t('frPick') : _geofences.join(', ')}'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<GeofenceTrigger>(
                        initialValue: _geofenceTrigger,
                        decoration: InputDecoration(
                            labelText: l10n.t('frRuleAction')),
                        items: GeofenceTrigger.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _geofenceTrigger = v);
                        },
                      ),
                    ],
                    if (rule.kind == RuleKind.taskGated) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickLinkedTask,
                        icon: const Icon(Icons.task_outlined, size: 18),
                        label: Text('${l10n.t('rwLinkedRule')}: ${_linkedTaskId.isEmpty ? l10n.t('frPick') : _linkedTaskId}'),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: GuardianTokens.guardianTeal,
                    foregroundColor: Colors.white),
                child: _saving
                    ? const CircularProgressIndicator()
                    : Text(l10n.t('frSaveRule')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(RuleAction action) => switch (action) {
        RuleAction.block => 'frActionBlock',
        RuleAction.restrict => 'frActionRestrict',
        RuleAction.allowlistOnly => 'frActionAllowlist',
        RuleAction.notifyOnly => 'frActionNotify',
      };

  Future<void> _pickWeekdays() async {
    final l10n = AppLocalizations.of(context);
    final selected = Set<int>.from(_weekdays);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frWeekdays'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true && selected.isNotEmpty) {
      setState(() => _weekdays = selected);
    }
  }

  Future<void> _pickChildren() async {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.read(familyRuntimeContextProvider(familyId));
    final children = runtime.valueOrNull?.children ?? const <FamilyMember>[];
    final rule = _rule;
    if (rule == null) return;
    final selected = Set<String>.from(rule.assignedChildIds);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frAssignChildren'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final child in children)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(child.displayName),
                value: selected.contains(child.id),
                activeColor: GuardianTokens.guardianTeal,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      selected.add(child.id);
                    } else {
                      selected.remove(child.id);
                    }
                  });
                },
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true) setState(() => _rule = rule.copyWith(assignedChildIds: selected));
  }

  Future<void> _pickOneshotDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneshotAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _oneshotAt = picked);
  }

  Future<void> _pickGeofences() async {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final geofencesAsync = ref.read(geofencesProvider(familyId));
    final geofences = geofencesAsync.valueOrNull ?? [];
    final selected = Set<String>.from(_geofences);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.t('frCategoryTargets'),
              style: const TextStyle(color: GuardianTokens.guardianNavy)),
          content: geofences.isEmpty
              ? Text(l10n.t('noData'))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final g in geofences)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.name),
                      value: selected.contains(g.id),
                      activeColor: GuardianTokens.guardianTeal,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(g.id);
                          } else {
                            selected.remove(g.id);
                          }
                        });
                      },
                    ),
                ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('cancel'))),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('save'))),
          ],
        ),
      ),
    );
    if (result == true) setState(() => _geofences = selected);
  }

  Future<void> _pickLinkedTask() async {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final tasksAsync = ref.read(tasksListProvider(familyId));
    final tasks = tasksAsync.valueOrNull ?? [];

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.t('rwLinkedRule'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: tasks.isEmpty
            ? Text(l10n.t('noData'))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                for (final t in tasks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.title),
                    trailing: _linkedTaskId == t.taskId
                        ? const Icon(Icons.check, color: GuardianTokens.guardianTeal)
                        : null,
                    onTap: () => Navigator.of(dialogContext).pop(t.taskId),
                  ),
              ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel'))),
        ],
      ),
    );
    if (result != null) setState(() => _linkedTaskId = result);
  }
}

// ═════════════════════════ FR-004 — Schedule Detail ══════════════════════════
/// `/rules/:familyId/schedule/:ruleId` — FR-004. One rule's honest window:
/// window minutes, recurrence, weekdays, and its active-state answer at the
/// moment of reading.
class RuleScheduleScreen extends ConsumerWidget {
  const RuleScheduleScreen({super.key});

  static const route = '/rules/:familyId/schedule/:ruleId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final ruleId = GoRouterState.of(context).pathParameters['ruleId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final detail = ref.watch(ruleDetailProvider((familyId: familyId, ruleId: ruleId)));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, detail, FamilyPermission.viewFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frScheduleTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: detail.when(
          loading: () => const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(ruleDetailProvider(
                (familyId: familyId, ruleId: ruleId))),
          ),
          data: (rule) {
            if (rule == null) {
              return GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('frRuleNotFound'),
                message: l10n.t('frRuleNotFoundDescription'),
              );
            }
            final isActive = rule.isActiveAt(DateTime.now());
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GuardianHeroCard(
                  child: Row(children: [
                    GuardianIconBadge(icon: _kindIcon(rule.kind),
                        background: Colors.white24, foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rule.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                    GuardianStatusChip(
                      label: isActive
                          ? l10n.t('frRuleActiveNow')
                          : l10n.t('frRuleInactiveNow'),
                      kind: isActive
                          ? GuardianStatusKind.safe
                          : GuardianStatusKind.neutral,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                GuardianSection(
                    title: l10n.t('frScheduleSection'),
                    children: [
                      GuardianCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GuardianStatTile(
                              icon: Icons.wb_twilight_outlined,
                              value: _timeOfDay(rule.startMinute),
                              label: l10n.t('frStart'),
                            ),
                            const SizedBox(height: 8),
                            GuardianStatTile(
                              icon: Icons.nightlight_outlined,
                              value: rule.endMinute == 0 &&
                                      rule.startMinute != 0
                                  ? '24:00'
                                  : _timeOfDay(rule.endMinute),
                              label: l10n.t('frEnd'),
                            ),
                            const SizedBox(height: 8),
                            GuardianStatTile(
                              icon: Icons.event_repeat_outlined,
                              value: _scheduleKindLabel(l10n, rule),
                              label: l10n.t('frRecurrence'),
                            ),
                            if (rule.scheduleKind == RuleScheduleKind.weekly) ...[
                              const SizedBox(height: 8),
                              GuardianStatTile(
                                icon: Icons.calendar_month_outlined,
                                value: (rule.weekdays.toList()..sort())
                                    .map((d) => _weekdayLabel(l10n, d))
                                    .join(' · '),
                                label: l10n.t('frWeekdays'),
                              ),
                            ],
                            if (rule.scheduleKind == RuleScheduleKind.oneTime) ...[
                              const SizedBox(height: 8),
                              GuardianStatTile(
                                icon: Icons.schedule_outlined,
                                value: rule.oneshotAt == null
                                    ? '—'
                                    : rule.oneshotAt!
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                                label: l10n.t('frFireMoment'),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                                '${l10n.t('frDuration')}: '
                                '${rule.windowDuration.inHours}h ${rule.windowDuration.inMinutes % 60}m',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ]),
              ],
            );
          },
        ),
      ),
    );
  }

  String _scheduleKindLabel(AppLocalizations l10n, FamilyRule rule) =>
      switch (rule.scheduleKind) {
        RuleScheduleKind.daily => l10n.t('frScheduleDaily'),
        RuleScheduleKind.weekly => l10n.t('frScheduleWeekly'),
        RuleScheduleKind.oneTime => l10n.t('frScheduleOneTime'),
      };
}

// ══════════════════════════ FR-005 — Impact Preview ══════════════════════════
/// `/rules/:familyId/impact/:ruleId` — FR-005. What this rule actually does,
/// honestly: affected children, current verdict status, and the execution
/// verdicts that already exist for it. No invented numbers — only the log.
class RuleImpactScreen extends ConsumerWidget {
  const RuleImpactScreen({super.key});

  static const route = '/rules/:familyId/impact/:ruleId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final ruleId = GoRouterState.of(context).pathParameters['ruleId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final detail = ref.watch(ruleDetailProvider((familyId: familyId, ruleId: ruleId)));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, detail, FamilyPermission.viewFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frImpactTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: detail.when(
          loading: () => const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(ruleDetailProvider(
                (familyId: familyId, ruleId: ruleId))),
          ),
          data: (rule) {
            final children =
                runtime.valueOrNull?.children ?? const <FamilyMember>[];
            if (rule == null) {
              return GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('frRuleNotFound'),
                message: l10n.t('frRuleNotFoundDescription'),
              );
            }
            final affected = children
                .where((c) => rule.appliesToChild(c.id))
                .toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GuardianHeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        GuardianIconBadge(icon: _kindIcon(rule.kind),
                            background: Colors.white24,
                            foreground: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(rule.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(l10n.t(rule.kind.tooltipKey),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GuardianSection(
                    title: l10n.t('frImpactChildrenSection'),
                    children: affected.isEmpty
                        ? [
                            GuardianStateView(
                              state: GuardianViewState.empty,
                              title: l10n.t('frNoAffectedChildren'),
                              message: l10n.t('frNoAffectedChildrenDescription'),
                            )
                          ]
                        : [
                            for (final child in affected)
                              GuardianCard(
                                child: Row(children: [
                                  GuardianIconBadge(
                                      icon: Icons.child_care_outlined,
                                      background:
                                          GuardianTokens.guardianTealSoft),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(child.displayName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const SizedBox(height: 2),
                                          Text(
                                              rule.isActiveAt(DateTime.now())
                                                  ? l10n.t('frChildAffectedNow')
                                                  : l10n.t('frChildAffectedScheduled'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: Colors.black54)),
                                        ]),
                                  ),
                                  GuardianStatusChip(
                                    label: rule.enabled
                                        ? l10n.t('frRuleOn')
                                        : l10n.t('frRuleOff'),
                                    kind: rule.enabled
                                        ? GuardianStatusKind.safe
                                        : GuardianStatusKind.offline,
                                  ),
                                ]),
                              ),
                          ]),
                const SizedBox(height: 16),
                GuardianSection(title: l10n.t('frExecutionSection'), children: [
                  GuardianCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('frExecutionDescription'),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text(_impactSummary(l10n, rule),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                GuardianSection(title: l10n.t('frLogSection'), children: [
                  _RecentVerdicts(
                      familyId: familyId, ruleId: ruleId, rule: rule),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  String _impactSummary(AppLocalizations l10n, FamilyRule rule) {
    final actionLabel = switch (rule.action) {
      RuleAction.block => l10n.t('frActionBlock'),
      RuleAction.restrict => l10n.t('frActionRestrict'),
      RuleAction.allowlistOnly => l10n.t('frActionAllowlist'),
      RuleAction.notifyOnly => l10n.t('frActionNotify'),
    };
    final targets = <String>[
      if (rule.appTargets.isNotEmpty)
        '${l10n.t('frAppTargets')}: ${rule.appTargets.join('، ')}',
      if (rule.categoryTargets.isNotEmpty)
        '${l10n.t('frCategoryTargets')}: ${rule.categoryTargets.join('، ')}',
      if (rule.limitMinutes != null)
        '${l10n.t('frLimitMinutes')}: ${rule.limitMinutes}',
    ];
    return '${l10n.t('frImpactDoes')}: $actionLabel.\n'
        '${targets.isEmpty ? l10n.t('frImpactWindowOnly') : targets.join('\n')}';
  }
}

class _RecentVerdicts extends ConsumerWidget {
  const _RecentVerdicts({
    required this.familyId,
    required this.ruleId,
    required this.rule,
  });

  final String familyId;
  final String ruleId;
  final FamilyRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(ruleExecutionLogProvider(familyId));
    return entries.when(
      loading: () => const GuardianStateView(state: GuardianViewState.loading),
      error: (_, __) => GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('monitoringSyncFailed'),
        message: l10n.t('somethingWentWrong'),
      ),
      data: (list) {
        final verdicts = list.where((e) => e.ruleId == ruleId).toList();
        if (verdicts.isEmpty) {
          return GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('frNoVerdicts'),
            message: l10n.t('frNoVerdictsDescription'),
          );
        }
        return Column(children: [
          for (final entry in verdicts.take(10))
            GuardianCard(
              child: Row(children: [
                GuardianIconBadge(
                    icon: entry.outcome == 'applied'
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    background: entry.outcome == 'applied'
                        ? GuardianTokens.guardianTealSoft
                        : GuardianStatusKind.neutral.palette.soft),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GuardianStatusChip(
                            label: entry.outcome,
                            kind: entry.outcome == 'applied'
                                ? GuardianStatusKind.safe
                                : GuardianStatusKind.neutral,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(entry.evaluatedAt.toLocal().toString().split('.').first,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.end),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(entry.reason,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

// ═════════════════════════ FR-006 — Conflict Resolver ════════════════════════
/// `/rules/:familyId/conflicts` — FR-006. Every overlap the engine detects,
/// with its deterministic winner. Losers are recorded, never silently
/// overridden — the same discipline FS-005 uses for mode collisions.
class RuleConflictsScreen extends ConsumerWidget {
  const RuleConflictsScreen({super.key});

  static const route = '/rules/:familyId/conflicts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final conflicts = ref.watch(ruleConflictsProvider(familyId));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, conflicts, FamilyPermission.viewFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final children = runtime.valueOrNull?.children ?? const <FamilyMember>[];
    final conflictList = conflicts.valueOrNull ?? const [];
    final byChild = <String, List<RuleConflict>>{};
    for (final conflict in conflictList) {
      byChild.putIfAbsent(conflict.childId, () => []).add(conflict);
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frConflictsTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    GuardianIconBadge(
                        icon: Icons.balance_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('frConflictsTitle'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      conflictList.isEmpty
                          ? l10n.t('frNoConflicts')
                          : '${conflictList.length} ${l10n.t('frConflictsFound')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (conflictList.isEmpty)
              GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('frNoConflicts'),
                message: l10n.t('frNoConflictsDescription'),
              )
            else
              for (final entry in byChild.entries)
                GuardianSection(
                  title:
                      children.firstWhere((c) => c.id == entry.key,
                              orElse: () => FamilyMember(
                                  id: entry.key,
                                  familyId: familyId,
                                  displayName: entry.key,
                                  role: FamilyRole.child,
                                  createdAt: DateTime.fromMillisecondsSinceEpoch(0)))
                          .displayName,
                  children: [
                    for (final conflict in entry.value)
                      GuardianCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(conflict.first.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          '${_kindLabel(l10n, conflict.first.kind)} · ${l10n.t('frPriority')}: ${conflict.first.priority}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ]),
                              ),
                              const Text('⚖', style: TextStyle(fontSize: 20)),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(conflict.second.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          '${_kindLabel(l10n, conflict.second.kind)} · ${l10n.t('frPriority')}: ${conflict.second.priority}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ]),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: GuardianStatusChip(
                                  label: '${l10n.t('frWinner')}: ${conflict.winner.name}',
                                  kind: GuardianStatusKind.safe,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GuardianStatusChip(
                                  label: '${l10n.t('frLoser')}: ${conflict.loser.name}',
                                  kind: GuardianStatusKind.watch,
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, RuleKind kind) =>
      l10n.t(kind.labelKey);
}

// ═════════════════════════ FR-007 — Execution Log ════════════════════════════
/// `/rules/:familyId/log` — FR-007. The honest execution log: every verdict
/// the engine produced, with rule name, child, outcome and reason. The log
/// only grows from real device evidence — it never pretends.
class RuleExecutionLogScreen extends ConsumerWidget {
  const RuleExecutionLogScreen({super.key});

  static const route = '/rules/:familyId/log';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final log = ref.watch(ruleExecutionLogProvider(familyId));
    final guard = _rulesGuard(
        context, ref, familyId, runtime, log, FamilyPermission.viewFamilyRules);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final rules = ref.watch(rulesListProvider(familyId));
    final ruleList = rules.valueOrNull ?? const <FamilyRule>[];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('frLogTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: log.when(
          loading: () => const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('monitoringSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(ruleExecutionLogProvider(familyId)),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianHeroCard(
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.history_outlined,
                      background: Colors.white24, foreground: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('frLogTitle'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                  ),
                  GuardianStatTile(
                    icon: Icons.fact_check_outlined,
                    value: '${list.length}',
                    label: l10n.t('frLogEntries'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('frNoLogEntries'),
                  message: l10n.t('frNoLogEntriesDescription'),
                )
              else
                GuardianSection(title: l10n.t('frLogSection'), children: [
                  for (final entry in list)
                    GuardianCard(
                      child: Row(children: [
                        GuardianIconBadge(
                            icon: entry.outcome == 'applied'
                                ? Icons.check_circle_outline
                                : entry.outcome == 'skipped'
                                    ? Icons.do_not_disturb_on_outlined
                                    : Icons.info_outline,
                            background: entry.outcome == 'applied'
                                ? GuardianTokens.guardianTealSoft
                                : GuardianStatusKind.neutral.palette.soft),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                        ruleList
                                            .cast<FamilyRule?>()
                                            .firstWhere(
                                                (r) => r!.ruleId == entry.ruleId,
                                                orElse: () => null)
                                            ?.name ??
                                            entry.ruleId,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                  ),
                                  GuardianStatusChip(
                                    label: entry.outcome,
                                    kind: entry.outcome == 'applied'
                                        ? GuardianStatusKind.safe
                                        : GuardianStatusKind.neutral,
                                  ),
                                ]),
                                const SizedBox(height: 4),
                                Text(entry.reason,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                const SizedBox(height: 2),
                                Text(entry.evaluatedAt.toLocal().toString().split('.').first,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.black45)),
                              ]),
                        ),
                      ]),
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
