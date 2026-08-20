import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/family_tasks.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

const Uuid _uuid = Uuid();

/// FS-007 — Family Tasks & Daily Schedules screens (TK-001 … TK-008).
///
/// Same visual grammar as every other subsystem: `GuardianHeroCard` header,
/// `GuardianSection` + `GuardianCard` rows, `GuardianStatTile` /
/// `GuardianStatusChip` / `GuardianStateView`, and `FamilyRuntimeContext.can()`
/// as the only authorization gate. The task flow is honest by design: a task
/// is `completed` only through the append-only completion log — never a
/// quietly-toggled field.
///
/// Integration with FS-011: a `taskGated` family rule stays locked while its
/// linked task is not completed; task completions surface that verdict on the
/// child's own task list (TK-005) and on the parent gate view (TK-004).

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

String _recurrenceLabel(AppLocalizations l10n, TaskEntry task) {
  switch (task.recurrence) {
    case TaskRecurrence.none:
      return '${_weekdayLabel(l10n, task.dueDate.weekday)} '
          '${task.dueDate.month}/${task.dueDate.day}/${task.dueDate.year} '
          '${_timeOfDay(task.dueMinute)}';
    case TaskRecurrence.daily:
      return '${l10n.t('tkRecurrenceDaily')} · ${_timeOfDay(task.dueMinute)}';
    case TaskRecurrence.weekly:
      final days =
          (task.weekdays.toList()..sort()).map((d) => _weekdayLabel(l10n, d));
      return '${l10n.t('tkRecurrenceWeekly')} · ${days.join('، ')} · '
          '${_timeOfDay(task.dueMinute)}';
  }
}

GuardianStatusKind _statusKind(TaskStatus status) {
  return switch (status) {
    TaskStatus.completed => GuardianStatusKind.safe,
    TaskStatus.inProgress => GuardianStatusKind.watch,
    TaskStatus.late => GuardianStatusKind.alert,
    TaskStatus.cancelled => GuardianStatusKind.offline,
    TaskStatus.scheduled => GuardianStatusKind.neutral,
  };
}

String _statusLabel(AppLocalizations l10n, TaskStatus status) {
  return switch (status) {
    TaskStatus.completed => l10n.t('tkStatusDone'),
    TaskStatus.inProgress => l10n.t('tkStatusOpen'),
    TaskStatus.late => l10n.t('tkStatusLate'),
    TaskStatus.cancelled => l10n.t('tkStatusCancelled'),
    TaskStatus.scheduled => l10n.t('tkStatusScheduled'),
  };
}

// ── Shared guard ────────────────────────────────────────────────────────────
Widget _tasksGuard(
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
          onRetry: () => ref.invalidate(tasksListProvider(familyId)),
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

Future<void> _invalidateTasks(
    WidgetRef ref, String familyId, Future<void> Function() mutation) async {
  await mutation();
  ref.invalidate(tasksListProvider(familyId));
}

// ═════════════════════════════ TK-001 — Dashboard ════════════════════════════
/// `/tasks/:familyId` — TK-001. Every family task with its honest status,
/// pending verifications, and management destinations.
class FamilyTasksDashboardScreen extends ConsumerWidget {
  const FamilyTasksDashboardScreen({super.key});

  static const route = '/tasks/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final tasks = ref.watch(tasksListProvider(familyId));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, tasks, FamilyPermission.viewTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final taskList = tasks.valueOrNull ?? const [];
    final now = DateTime.now();
    final open = taskList
        .where((t) => t.honestStatus(now) == TaskStatus.inProgress)
        .length;
    final pendingVerifications = taskList
        .where(
            (t) => t.status == TaskStatus.completed && t.linkedRuleId == null)
        .length;
    final canManage = ctx.can(FamilyPermission.manageTasks);
    final children = ctx.children;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tasksListProvider(familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('tkDashboardTitle'),
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
                            icon: Icons.task_outlined,
                            background: Colors.white24,
                            foreground: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.t('tkDashboardTitle'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.t('tkDashboardSubtitle'),
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
                      icon: Icons.circle_outlined,
                      value: '$open/${taskList.length}',
                      label: l10n.t('tkOpenTasks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.check_circle_outline,
                      value:
                          '${taskList.where((t) => t.honestStatus(now) == TaskStatus.completed).length}',
                      label: l10n.t('tkDoneTasks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.history_outlined,
                      value: '$pendingVerifications',
                      label: l10n.t('tkPendingVerifications'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('tkManageSection'), children: [
                GuardianCard(
                  onTap: canManage
                      ? () => context.push('/tasks/$familyId/new')
                      : null,
                  child: Row(children: [
                    const GuardianIconBadge(icon: Icons.add_circle_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('tkNewTask'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('tkNewTaskHint'),
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
                  onTap: canManage
                      ? () => context.push('/tasks/$familyId/recurring')
                      : null,
                  child: Row(children: [
                    const GuardianIconBadge(icon: Icons.repeat_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('tkRecurringTasks'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('tkRecurringHint'),
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
                  onTap: () => context.push('/tasks/$familyId/timeline'),
                  child: Row(children: [
                    const GuardianIconBadge(icon: Icons.timeline_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('tkTimeline'),
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(l10n.t('tkTimelineHint'),
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
                  title: l10n.t('tkTodaySection'),
                  children: tasks.when(
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
                                  'assets/images/family_tasks.png',
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            GuardianStateView(
                              state: GuardianViewState.empty,
                              title: l10n.t('tkNoTasks'),
                              message: l10n.t('tkNoTasksDescription'),
                              onPrimaryAction: canManage
                                  ? () => context.push('/tasks/$familyId/new')
                                  : null,
                              primaryActionLabel: l10n.t('tkNewTask'),
                            ),
                          ]
                        : [
                            for (final task in list)
                              GuardianCard(
                                onTap: canManage
                                    ? () => context.push(
                                        '/tasks/$familyId/edit/${task.taskId}')
                                    : null,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      GuardianIconBadge(
                                          icon: task.isRecurring
                                              ? Icons.repeat
                                              : Icons.check_box_outlined,
                                          background:
                                              GuardianTokens.guardianTealSoft),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(task.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium),
                                              const SizedBox(height: 2),
                                              Text(_recurrenceLabel(l10n, task),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color:
                                                              Colors.black54)),
                                            ]),
                                      ),
                                      GuardianStatusChip(
                                        label: _statusLabel(
                                            l10n, task.honestStatus(now)),
                                        kind:
                                            _statusKind(task.honestStatus(now)),
                                      ),
                                    ]),
                                    if (task.description != null &&
                                        task.description!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(task.description!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                        '${l10n.t('tkAssignedTo')}: ${_assignedChildrenLabel(l10n, children, task.assignedChildIds)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    if (canManage) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton.icon(
                                              onPressed: task.status !=
                                                      TaskStatus.cancelled
                                                  ? () => _confirmCancel(
                                                      context,
                                                      ref,
                                                      familyId,
                                                      task)
                                                  : null,
                                              icon: const Icon(
                                                  Icons.cancel_outlined,
                                                  size: 18),
                                              label:
                                                  Text(l10n.t('tkCancelTask')),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: l10n.t('delete'),
                                            onPressed: () => _confirmDelete(
                                                context, ref, familyId, task),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                  )),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref,
      String familyId, TaskEntry task) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.t('tkCancelTask'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: Text('${l10n.t('tkCancelConfirm')} “${task.title}”'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.t('tkCancelTask'))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _invalidateTasks(
            ref,
            familyId,
            () => ref
                .read(familyTasksRepositoryProvider)
                .cancel(familyId, task.taskId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('tkTaskCancelled')),
              behavior: SnackBarBehavior.floating));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('somethingWentWrong')),
              behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String familyId, TaskEntry task) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(l10n.t('tkDeleteTask'),
            style: const TextStyle(color: GuardianTokens.guardianNavy)),
        content: Text('${l10n.t('tkDeleteConfirm')} “${task.title}”'),
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
        await ref
            .read(familyTasksRepositoryProvider)
            .cancel(familyId, task.taskId);
        ref.invalidate(tasksListProvider(familyId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('tkTaskDeleted')),
              behavior: SnackBarBehavior.floating));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.t('somethingWentWrong')),
              behavior: SnackBarBehavior.floating));
        }
      }
    }
  }
}

// ══════════════════════════════ TK-002 — Builder ═════════════════════════════
/// `/tasks/:familyId/new` — TK-002. Author a task with an honest form: every
/// field is required and validated before anything touches the database.
class TaskBuilderScreen extends ConsumerStatefulWidget {
  const TaskBuilderScreen({super.key});

  static const route = '/tasks/:familyId/new';

  @override
  ConsumerState<TaskBuilderScreen> createState() => _TaskBuilderScreenState();
}

class _TaskBuilderScreenState extends ConsumerState<TaskBuilderScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _minute = TextEditingController(text: '18:00');
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TaskRecurrence _recurrence = TaskRecurrence.none;
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  final Set<String> _children = {};
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _minute.dispose();
    super.dispose();
  }

  int _parseMinute(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h.clamp(0, 23) * 60 + m.clamp(0, 59));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('tkTitleRequired')),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final ctx = ref.read(familyRuntimeContextProvider(familyId)).valueOrNull;
    if (ctx == null || !ctx.can(FamilyPermission.manageTasks)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('authorizationFailure')),
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final task = TaskEntry(
        taskId: 'task-${_uuid.v4().substring(0, 8)}',
        familyId: familyId,
        title: _title.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        dueMinute: _parseMinute(_minute.text),
        dueDate: _dueDate,
        recurrence: _recurrence,
        weekdays: _recurrence == TaskRecurrence.weekly ? _weekdays : const {},
        assignedChildIds: _children,
        createdByMemberId: ctx.actor?.id,
        createdAt: DateTime.now(),
        status: _recurrence == TaskRecurrence.none
            ? TaskStatus.scheduled
            : TaskStatus.inProgress,
      );
      await ref
          .read(familyTasksRepositoryProvider)
          .create(task, createdByMemberId: ctx.actor!.id);
      ref.invalidate(tasksListProvider(familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('tkTaskCreated')),
            behavior: SnackBarBehavior.floating));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('somethingWentWrong')),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('tkNewTask'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: Consumer(builder: (context, ref, _) {
          final runtime = ref.watch(familyRuntimeContextProvider(familyId));
          final guard = _tasksGuard(context, ref, familyId, runtime,
              const AsyncValue.data(null), FamilyPermission.manageTasks);
          if (guard is! SizedBox ||
              !identical(guard, const SizedBox.shrink())) {
            return guard;
          }
          final ctx = runtime.valueOrNull!;
          final children = ctx.children;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianSection(title: l10n.t('tkTaskDetails'), children: [
                GuardianCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _title,
                        decoration: InputDecoration(
                          labelText: l10n.t('tkTaskTitle'),
                          hintText: l10n.t('tkTaskTitleHint'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _description,
                        decoration: InputDecoration(
                          labelText: l10n.t('tkDescription'),
                          hintText: l10n.t('tkDescriptionHint'),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('tkScheduleSection'), children: [
                GuardianCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _minute,
                        decoration: InputDecoration(
                          labelText: l10n.t('tkDueTime'),
                          hintText: 'HH:mm',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.t('tkRecurrenceLabel'),
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TaskRecurrence.values.map((r) {
                          final selected = _recurrence == r;
                          return FilterChip(
                            selected: selected,
                            label: Text(l10n.t(r.labelKey)),
                            onSelected: (value) =>
                                setState(() => _recurrence = r),
                          );
                        }).toList(growable: false),
                      ),
                      if (_recurrence == TaskRecurrence.none) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dueDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _dueDate = picked);
                            }
                          },
                          child: Text(l10n.t('tkPickDate')),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            '${l10n.t('tkSelectedDate')}: '
                            '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (_recurrence == TaskRecurrence.weekly) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [1, 2, 3, 4, 5, 6, 7].map((iso) {
                            final selected = _weekdays.contains(iso);
                            return FilterChip(
                              selected: selected,
                              label: Text(_weekdayLabel(l10n, iso)),
                              onSelected: (value) => setState(() {
                                if (value) {
                                  _weekdays.add(iso);
                                } else if (_weekdays.length > 1) {
                                  _weekdays.remove(iso);
                                }
                              }),
                            );
                          }).toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('tkAssignedSection'), children: [
                GuardianCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _children.isEmpty,
                        label: Text(l10n.t('frAssignedAll')),
                        onSelected: (value) {
                          if (value) setState(() => _children.clear());
                        },
                      ),
                      ...children.map((child) => FilterChip(
                            selected: _children.contains(child.id),
                            label: Text(child.displayName),
                            onSelected: (value) => setState(() {
                              if (value) {
                                _children.add(child.id);
                              } else {
                                _children.remove(child.id);
                              }
                            }),
                          )),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.t('tkCreateTask')),
              ),
              const SizedBox(height: 16),
            ],
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════ TK-003 — Edit / Detail ══════════════════════════
/// `/tasks/:familyId/edit/:taskId` — TK-003. Full task detail with the honest
/// completion log and gate linkage; parents verify/decline self-reports here.
class TaskEditScreen extends ConsumerWidget {
  const TaskEditScreen({super.key});

  static const route = '/tasks/:familyId/edit/:taskId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final taskId = GoRouterState.of(context).pathParameters['taskId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final task =
        ref.watch(taskDetailProvider((familyId: familyId, taskId: taskId)));
    final log = ref
        .watch(taskCompletionLogProvider((familyId: familyId, taskId: taskId)));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, task, FamilyPermission.manageTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
            taskDetailProvider((familyId: familyId, taskId: taskId)));
        ref.invalidate(
            taskCompletionLogProvider((familyId: familyId, taskId: taskId)));
      },
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('tkTaskDetailTitle'),
                style: Theme.of(context).textTheme.titleLarge),
          ),
          body: task.when(
            loading: () =>
                const GuardianStateView(state: GuardianViewState.loading),
            error: (_, __) => GuardianStateView(
              state: GuardianViewState.error,
              title: l10n.t('monitoringSyncFailed'),
              message: l10n.t('somethingWentWrong'),
            ),
            data: (entry) {
              if (entry == null) {
                return GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('tkTaskMissing'),
                  message: l10n.t('tkTaskMissingDescription'),
                );
              }
              final now = DateTime.now();
              final children = ctx.children;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GuardianHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          GuardianIconBadge(
                              icon: Icons.task_outlined,
                              background: Colors.white24,
                              foreground: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(entry.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: Colors.white)),
                          ),
                          GuardianStatusChip(
                            label: _statusLabel(l10n, entry.honestStatus(now)),
                            kind: _statusKind(entry.honestStatus(now)),
                            live: entry.honestStatus(now) ==
                                TaskStatus.inProgress,
                          ),
                        ]),
                        if (entry.description != null &&
                            entry.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(entry.description!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70)),
                        ],
                        const SizedBox(height: 8),
                        Text(_recurrenceLabel(l10n, entry),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70)),
                        Text(
                            '${l10n.t('tkAssignedTo')}: ${_assignedLabel(l10n, children, entry.assignedChildIds)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (entry.linkedRuleId != null) ...[
                    GuardianSection(title: l10n.t('tkGateSection'), children: [
                      GuardianCard(
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: Icons.lock_open_outlined,
                              background: GuardianTokens.guardianTealSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.t('tkGateTitle'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${l10n.t('tkGateRule')}: ${entry.linkedRuleId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54)),
                                ]),
                          ),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  GuardianSection(title: l10n.t('tkLogSection'), children: [
                    log.when<Widget>(
                      loading: () => const GuardianStateView(
                          state: GuardianViewState.loading),
                      error: (_, __) => GuardianStateView(
                        state: GuardianViewState.error,
                        message: l10n.t('somethingWentWrong'),
                      ),
                      data: (rows) => rows.isEmpty
                          ? GuardianStateView(
                              state: GuardianViewState.empty,
                              title: l10n.t('tkNoLogYet'),
                              message: l10n.t('tkNoLogYetDescription'),
                            )
                          : Column(
                              children: [
                                for (final row in rows)
                                  GuardianCard(
                                    child: Row(children: [
                                      GuardianIconBadge(
                                          icon: _actionIcon(row.action),
                                          background:
                                              _actionChipSoft(row.action),
                                          foreground:
                                              _actionChipText(row.action),
                                          size: 36),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${l10n.t(_actionLabelKey(row.action))} · ${l10n.t('tkBy')}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall),
                                              Text(
                                                  '${row.actedAt.month}/${row.actedAt.day}/${row.actedAt.year} ${_timeOfDay(row.actedAt.hour * 60 + row.actedAt.minute)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                          color:
                                                              Colors.black54)),
                                            ]),
                                      ),
                                      if (row.note != null &&
                                          row.note!.isNotEmpty)
                                        Text(row.note!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                    ]),
                                  ),
                              ],
                            ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (entry.status != TaskStatus.completed &&
                      entry.status != TaskStatus.cancelled)
                    FilledButton.icon(
                      onPressed: () => _requestDone(
                          context, ref, familyId, entry, ctx.actor?.id ?? ''),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(l10n.t('tkMarkDone')),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _assignedLabel(
      AppLocalizations l10n, List<FamilyMember> children, Set<String> ids) {
    if (ids.isEmpty) return l10n.t('frAssignedAll');
    final names =
        children.where((c) => ids.contains(c.id)).map((c) => c.displayName);
    final joined = names.join('، ');
    if (joined.isEmpty) return l10n.t('frAssignedNone');
    return joined;
  }

  static IconData _actionIcon(TaskCompletionAction action) {
    return switch (action) {
      TaskCompletionAction.requested => Icons.flag_outlined,
      TaskCompletionAction.completed => Icons.check_circle_outline,
      TaskCompletionAction.declined => Icons.cancel_outlined,
      TaskCompletionAction.cancelled => Icons.cancel_outlined,
    };
  }

  static Color _actionChipSoft(TaskCompletionAction action) {
    return switch (action) {
      TaskCompletionAction.completed => GuardianTokens.statusSafeSoft,
      TaskCompletionAction.declined => GuardianTokens.statusAlertSoft,
      _ => GuardianTokens.guardianTealSoft,
    };
  }

  static Color _actionChipText(TaskCompletionAction action) {
    return switch (action) {
      TaskCompletionAction.completed => GuardianTokens.statusSafe,
      TaskCompletionAction.declined => GuardianTokens.statusAlert,
      _ => GuardianTokens.guardianTeal,
    };
  }

  static String _actionLabelKey(TaskCompletionAction action) {
    return switch (action) {
      TaskCompletionAction.requested => 'tkActionRequested',
      TaskCompletionAction.completed => 'tkActionCompleted',
      TaskCompletionAction.declined => 'tkActionDeclined',
      TaskCompletionAction.cancelled => 'tkActionCancelled',
    };
  }

  Future<void> _requestDone(BuildContext context, WidgetRef ref,
      String familyId, TaskEntry task, String actorMemberId) async {
    final l10n = AppLocalizations.of(context);
    if (actorMemberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('authorizationFailure')),
          behavior: SnackBarBehavior.floating));
      return;
    }
    try {
      await ref.read(familyTasksRepositoryProvider).requestCompletion(
            familyId: familyId,
            taskId: task.taskId,
            childId: actorMemberId,
            actorMemberId: actorMemberId,
          );
      ref.invalidate(
          taskDetailProvider((familyId: familyId, taskId: task.taskId)));
      ref.invalidate(
          taskCompletionLogProvider((familyId: familyId, taskId: task.taskId)));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('tkMarkedDone')),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('somethingWentWrong')),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ════════════════════════════ TK-004 — Gate view ═════════════════════════════
/// `/tasks/:familyId/detail/:taskId` — TK-004. The FS-011 gate lens: shows
/// whether this task's completion currently unlocks the linked
/// `taskGated` rules for a given child.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key});

  static const route = '/tasks/:familyId/detail/:taskId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final taskId = GoRouterState.of(context).pathParameters['taskId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final lensChildId = runtime.valueOrNull?.children.firstOrNull?.id ?? '';
    final gate = ref.watch(
        taskGateVerdictsProvider((familyId: familyId, childId: lensChildId)));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, gate, FamilyPermission.viewTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('tkGateTitle'),
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
                        icon: Icons.lock_open_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('tkGateTitle'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.t('tkGateSubtitle'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('tkLinkedRulesSection'), children: [
              if (gate.valueOrNull == null || gate.valueOrNull!.isEmpty)
                GuardianCard(
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/family_tasks.png',
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    GuardianStateView(
                      state: GuardianViewState.empty,
                      title: l10n.t('tkNoLinkedRules'),
                      message: l10n.t('tkNoLinkedRulesDescription'),
                    ),
                  ]),
                )
              else
                ...gate.valueOrNull!.entries.map((entry) {
                  final verdicts = entry.value
                      .where((v) => v.linkedTaskId == taskId)
                      .toList(growable: false);
                  if (verdicts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuardianCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${l10n.t('tkChild')} ${_childName(ctx, entry.key)}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            for (final v in verdicts)
                              Row(children: [
                                GuardianStatusChip(
                                  label: v.open
                                      ? l10n.t('tkGateOpen')
                                      : l10n.t('tkGateLocked'),
                                  kind: v.open
                                      ? GuardianStatusKind.safe
                                      : GuardianStatusKind.alert,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      '${l10n.t('tkRule')}: ${v.ruleId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ),
                              ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
            ]),
          ],
        ),
      ),
    );
  }

  String _childName(FamilyRuntimeContext ctx, String memberId) {
    final match = ctx.children.where((c) => c.id == memberId).toList();
    if (match.isEmpty) return memberId;
    return match.first.displayName;
  }
}

// ═══════════════════════════ TK-005 — Child view ═════════════════════════════
/// `/tasks/:familyId/child/:childId` — TK-005. The child's own honest task
/// list: what is open, what awaits parent verification, and what is done.
class TaskChildViewScreen extends ConsumerWidget {
  const TaskChildViewScreen({super.key});

  static const route = '/tasks/:familyId/child/:childId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final childId = GoRouterState.of(context).pathParameters['childId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final tasks = ref.watch(tasksListProvider(familyId));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, tasks, FamilyPermission.viewTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final child = ctx.children.where((c) => c.id == childId).toList();
    if (child.isEmpty) {
      return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          body: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('roleNotAllowed'),
            message: l10n.t('authorizationFailure'),
          ),
        ),
      );
    }
    final now = DateTime.now();
    final mine =
        tasks.valueOrNull?.where((t) => t.appliesToChild(childId)).toList() ??
            const [];
    final open =
        mine.where((t) => t.honestStatus(now) == TaskStatus.inProgress).length;
    final done =
        mine.where((t) => t.honestStatus(now) == TaskStatus.completed).length;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tasksListProvider(familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text('${l10n.t('tkMyTasks')} · ${child.first.displayName}',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.circle_outlined,
                      value: '$open',
                      label: l10n.t('tkOpenTasks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuardianStatTile(
                      icon: Icons.check_circle_outline,
                      value: '$done',
                      label: l10n.t('tkDoneTasks'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('tkTodaySection'), children: [
                if (tasks.isLoading)
                  const GuardianStateView(state: GuardianViewState.loading)
                else if (mine.isEmpty)
                  GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('tkChildNoTasks'),
                    message: l10n.t('tkChildNoTasksDescription'),
                  )
                else
                  ...mine.map((task) => GuardianCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(task.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 2),
                                      Text(_recurrenceLabel(l10n, task),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: Colors.black54)),
                                    ]),
                              ),
                              GuardianStatusChip(
                                label:
                                    _statusLabel(l10n, task.honestStatus(now)),
                                kind: _statusKind(task.honestStatus(now)),
                              ),
                            ]),
                            if (task.description != null &&
                                task.description!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(task.description!,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            if (task.status != TaskStatus.completed &&
                                task.status != TaskStatus.cancelled) ...[
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () => _reportDone(
                                    context, ref, familyId, task, childId),
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: Text(l10n.t('tkReportDone')),
                              ),
                            ],
                          ],
                        ),
                      )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportDone(BuildContext context, WidgetRef ref, String familyId,
      TaskEntry task, String childId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(familyTasksRepositoryProvider).requestCompletion(
            familyId: familyId,
            taskId: task.taskId,
            childId: childId,
            actorMemberId: childId,
          );
      ref.invalidate(tasksListProvider(familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('tkReportedForVerification')),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('somethingWentWrong')),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ═══════════════════════════ TK-006 — Completion log ════════════════════════
/// `/tasks/:familyId/completion` — TK-006. Parent verification surface: every
/// self-report awaits an honest parent decision (verify / decline) — nothing
/// is completed silently.
class TaskCompletionScreen extends ConsumerWidget {
  const TaskCompletionScreen({super.key});

  static const route = '/tasks/:familyId/completion';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final tasks = ref.watch(tasksListProvider(familyId));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, tasks, FamilyPermission.manageTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final now = DateTime.now();
    final awaiting = tasks.valueOrNull
            ?.where((t) =>
                t.honestStatus(now) == TaskStatus.completed &&
                t.status == TaskStatus.completed &&
                t.linkedRuleId == null)
            .toList() ??
        const [];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('tkCompletionsTitle'),
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
                        icon: Icons.verified_outlined,
                        background: Colors.white24,
                        foreground: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('tkCompletionsTitle'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(l10n.t('tkCompletionsSubtitle'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('tkPendingSection'), children: [
              if (tasks.isLoading)
                const GuardianStateView(state: GuardianViewState.loading)
              else if (awaiting.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('tkNoPendingCompletions'),
                  message: l10n.t('tkNoPendingCompletionsDescription'),
                )
              else
                ...awaiting.map((task) => GuardianCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(task.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${l10n.t('tkAssignedTo')}: ${_childNames(l10n, ctx, task.assignedChildIds)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.black54)),
                                  ]),
                            ),
                            GuardianStatusChip(
                              label: l10n.t('tkStatusDone'),
                              kind: GuardianStatusKind.watch,
                              live: true,
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _verify(context, ref,
                                      familyId, task, ctx.actor?.id ?? ''),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(l10n.t('tkVerify')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _decline(context, ref,
                                      familyId, task, ctx.actor?.id ?? ''),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: Text(l10n.t('tkDecline')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
            ]),
          ],
        ),
      ),
    );
  }

  String _childNames(
      AppLocalizations l10n, FamilyRuntimeContext ctx, Set<String> ids) {
    if (ids.isEmpty) return l10n.t('frAssignedAll');
    final names =
        ctx.children.where((c) => ids.contains(c.id)).map((c) => c.displayName);
    final joined = names.join('، ');
    if (joined.isEmpty) return l10n.t('frAssignedNone');
    return joined;
  }

  Future<void> _verify(BuildContext context, WidgetRef ref, String familyId,
      TaskEntry task, String actorMemberId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(familyTasksRepositoryProvider).verifyCompletion(
            familyId: familyId,
            taskId: task.taskId,
            childId: actorMemberId,
            actorMemberId: actorMemberId,
          );
      ref.invalidate(tasksListProvider(familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('tkVerified')),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('somethingWentWrong')),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref, String familyId,
      TaskEntry task, String actorMemberId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(familyTasksRepositoryProvider).declineCompletion(
            familyId: familyId,
            taskId: task.taskId,
            childId: actorMemberId,
            actorMemberId: actorMemberId,
          );
      ref.invalidate(tasksListProvider(familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('tkDeclined')),
            behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('somethingWentWrong')),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ═════════════════════════════ TK-007 — Recurring ════════════════════════════
/// `/tasks/:familyId/recurring` — TK-007. The recurring-schedule lens: daily
/// and weekly tasks only, with their honest day windows.
class RecurringTasksScreen extends ConsumerWidget {
  const RecurringTasksScreen({super.key});

  static const route = '/tasks/:familyId/recurring';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final tasks = ref.watch(tasksListProvider(familyId));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, tasks, FamilyPermission.viewTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final now = DateTime.now();
    final recurring =
        tasks.valueOrNull?.where((t) => t.isRecurring).toList() ?? const [];
    final daily =
        recurring.where((t) => t.recurrence == TaskRecurrence.daily).toList();
    final weekly =
        recurring.where((t) => t.recurrence == TaskRecurrence.weekly).toList();
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(tasksListProvider(familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('tkRecurringTasks'),
                style: Theme.of(context).textTheme.titleLarge),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianSection(title: l10n.t('tkDailySchedule'), children: [
                if (tasks.isLoading)
                  const GuardianStateView(state: GuardianViewState.loading)
                else if (daily.isEmpty)
                  GuardianCard(
                    child: GuardianStateView(
                      state: GuardianViewState.empty,
                      title: l10n.t('tkNoDailyTasks'),
                      message: l10n.t('tkNoDailyTasksDescription'),
                    ),
                  )
                else
                  ...daily.map((task) => _TaskRow(
                        l10n: l10n,
                        context: context,
                        task: task,
                        now: now,
                        children: ctx.children,
                      )),
              ]),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('tkWeeklySchedule'), children: [
                if (weekly.isEmpty)
                  GuardianCard(
                    child: GuardianStateView(
                      state: GuardianViewState.empty,
                      title: l10n.t('tkNoWeeklyTasks'),
                      message: l10n.t('tkNoWeeklyTasksDescription'),
                    ),
                  )
                else
                  ...weekly.map((task) => _TaskRow(
                        l10n: l10n,
                        context: context,
                        task: task,
                        now: now,
                        children: ctx.children,
                      )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.l10n,
    required this.context,
    required this.task,
    required this.now,
    required this.children,
  });

  final AppLocalizations l10n;
  final BuildContext context;
  final TaskEntry task;
  final DateTime now;
  final List<FamilyMember> children;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      onTap: () => context.push('/tasks/${task.familyId}/edit/${task.taskId}'),
      child: Row(children: [
        GuardianIconBadge(
            icon: Icons.repeat, background: GuardianTokens.guardianTealSoft),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(_recurrenceLabel(l10n, task),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54)),
          ]),
        ),
        GuardianStatusChip(
          label: _statusLabel(l10n, task.honestStatus(now)),
          kind: _statusKind(task.honestStatus(now)),
        ),
      ]),
    );
  }
}

// ═════════════════════════════ TK-008 — Timeline ═════════════════════════════
/// `/tasks/:familyId/timeline` — TK-008. The append-only family task history —
/// the honest record of every completion action, kept by the log itself.
class TaskTimelineScreen extends ConsumerWidget {
  const TaskTimelineScreen({super.key});

  static const route = '/tasks/:familyId/timeline';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final log = ref.watch(taskFamilyLogProvider(familyId));
    final guard = _tasksGuard(
        context, ref, familyId, runtime, log, FamilyPermission.viewTasks);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(taskFamilyLogProvider(familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavyDeep,
          appBar: AppBar(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('tkTimeline'),
                style: Theme.of(context).textTheme.titleLarge),
          ),
          body: log.when(
            loading: () =>
                const GuardianStateView(state: GuardianViewState.loading),
            error: (_, __) => GuardianStateView(
              state: GuardianViewState.error,
              title: l10n.t('monitoringSyncFailed'),
              message: l10n.t('somethingWentWrong'),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('tkNoTimelineYet'),
                  message: l10n.t('tkNoTimelineYetDescription'),
                  primaryActionLabel: l10n.t('tkNewTask'),
                  onPrimaryAction: ctx.can(FamilyPermission.manageTasks)
                      ? () => context.push('/tasks/$familyId/new')
                      : null,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(
                          icon: TaskEditScreen._actionIcon(row.action),
                          background:
                              TaskEditScreen._actionChipSoft(row.action),
                          foreground:
                              TaskEditScreen._actionChipText(row.action),
                          size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('tkAction'),
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                  '${_childName(ctx, row.childId)} · ${row.actedAt.month}/${row.actedAt.day}/${row.actedAt.year} ${_timeOfDay(row.actedAt.hour * 60 + row.actedAt.minute)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.black54)),
                            ]),
                      ),
                      if (row.note != null && row.note!.isNotEmpty)
                        Text(row.note!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _childName(FamilyRuntimeContext ctx, String childId) {
    final match = ctx.children.where((c) => c.id == childId).toList();
    if (match.isEmpty) return childId;
    return match.first.displayName;
  }
}
