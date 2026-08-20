import 'guardian_models.dart';

/// FS-007 — Family Tasks & Daily Schedules.
///
/// A *task* is a concrete, scheduled thing a parent asks a child to do
/// (homework, tidy the room, daily prayers, reading...). Tasks carry an
/// honest status machine and an append-only completion log: a task is
/// never quietly marked done by the system — it moves to `completed`
/// only when a member (parent verifying, or child self-reporting for a
/// parent-approved verification model) records a `completed` action,
/// and every action lands in `task_completion_log` with its actor.
///
/// Integration with FS-011: a `taskGated` family rule (`lib/family_rules.dart`)
/// carries an optional `linkedTaskId` — while the linked task is not
/// completed, the rule stays locked for the assigned children. The gate
/// resolver here (`TaskGateResolver`) is the execution handler that binds
/// the reserved `taskGated` kind: screens render reserved kinds already,
/// they need no change.

/// Status a task may honestly be in.
enum TaskStatus {
  /// Authorised but the window hasn't started yet.
  scheduled,

  /// The window is open and the task isn't done or cancelled.
  inProgress,

  /// A completion action exists in the log.
  completed,

  /// The due moment passed without completion.
  late,

  /// Cancelled by a parent — history preserved in the log.
  cancelled,
}

/// How the task repeats.
enum TaskRecurrence {
  /// Once, on `dueDate` at `dueMinute`.
  none,

  /// Every day at `dueMinute` while the task is enabled.
  daily,

  /// Explicit weekday selection.
  weekly,
}

extension TaskRecurrenceDisplay on TaskRecurrence {
  String get labelKey => switch (this) {
        TaskRecurrence.none => 'tkRecurrenceOnce',
        TaskRecurrence.daily => 'tkRecurrenceDaily',
        TaskRecurrence.weekly => 'tkRecurrenceWeekly',
      };
}

/// One family task authored by a parent.
class TaskEntry {
  const TaskEntry({
    required this.taskId,
    required this.familyId,
    required this.title,
    this.description,
    this.dueMinute = 0,
    required this.dueDate,
    this.recurrence = TaskRecurrence.none,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.assignedChildIds = const {},
    this.linkedRuleId,
    this.status = TaskStatus.scheduled,
    this.createdByMemberId,
    required this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.queued,
  });

  final String taskId;
  final String familyId;
  final String title;
  final String? description;

  /// Minute-of-day for daily/weekly tasks (0..1439).
  final int dueMinute;

  /// Anchor date; recurring tasks resolve against the current date.
  final DateTime dueDate;
  final TaskRecurrence recurrence;

  /// 1..7 ISO weekday set for weekly recurrence.
  final Set<int> weekdays;
  final Set<String> assignedChildIds;

  /// `taskGated` FS-011 rule id that stays locked until this task is
  /// completed. Null means a plain task with no rule linkage.
  final String? linkedRuleId;
  final TaskStatus status;
  final String? createdByMemberId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  TaskEntry copyWith({
    String? title,
    String? description,
    int? dueMinute,
    DateTime? dueDate,
    TaskRecurrence? recurrence,
    Set<int>? weekdays,
    Set<String>? assignedChildIds,
    String? linkedRuleId,
    TaskStatus? status,
    SyncState? syncState,
  }) =>
      TaskEntry(
        taskId: taskId,
        familyId: familyId,
        title: title ?? this.title,
        description: description ?? this.description,
        dueMinute: dueMinute ?? this.dueMinute,
        dueDate: dueDate ?? this.dueDate,
        recurrence: recurrence ?? this.recurrence,
        weekdays: weekdays ?? this.weekdays,
        assignedChildIds: assignedChildIds ?? this.assignedChildIds,
        linkedRuleId: linkedRuleId ?? this.linkedRuleId,
        status: status ?? this.status,
        createdByMemberId: createdByMemberId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncState: syncState ?? this.syncState,
      );

  /// Whether this task concerns [childId] (empty set = whole family).
  bool appliesToChild(String childId) =>
      assignedChildIds.isEmpty || assignedChildIds.contains(childId);

  /// The effective due moment in local wall-clock terms.
  DateTime effectiveDueAt(DateTime referenceNow) {
    if (recurrence == TaskRecurrence.none) {
      return DateTime(dueDate.year, dueDate.month, dueDate.day, dueMinute ~/ 60,
          dueMinute % 60);
    }
    return DateTime(referenceNow.year, referenceNow.month, referenceNow.day,
        dueMinute ~/ 60, dueMinute % 60);
  }

  /// Honest classification against [referenceNow]: late beats everything
  /// except explicit completed/cancelled states, which are immutable.
  TaskStatus honestStatus(DateTime referenceNow) {
    if (status == TaskStatus.completed || status == TaskStatus.cancelled) {
      return status;
    }
    if (recurrence == TaskRecurrence.weekly &&
        !weekdays.contains(referenceNow.weekday)) {
      return TaskStatus.scheduled;
    }
    if (referenceNow.isAfter(effectiveDueAt(referenceNow))) {
      return TaskStatus.late;
    }
    return TaskStatus.inProgress;
  }

  bool get isRecurring => recurrence != TaskRecurrence.none;

  Map<String, Object?> toMap() => {
        'task_id': taskId,
        'family_id': familyId,
        'title': title,
        'description': description,
        'due_minute': dueMinute,
        'due_date': dueDate.toIso8601String(),
        'recurrence': recurrence.name,
        'weekdays': (weekdays.toList()..sort()).join(','),
        'assigned_child_ids': (assignedChildIds.toList()..sort()).join(','),
        'linked_rule_id': linkedRuleId,
        'status': status.name,
        'created_by_member_id': createdByMemberId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toIso8601String(),
        'sync_state': syncState.name,
      };

  factory TaskEntry.fromMap(Map<String, Object?> row) => TaskEntry(
        taskId: row['task_id'] as String,
        familyId: row['family_id'] as String,
        title: row['title'] as String,
        description: row['description'] as String?,
        dueMinute: row['due_minute'] as int,
        dueDate: _parseIso(row['due_date'] as String?) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        recurrence: TaskRecurrence.values.firstWhere(
            (r) => r.name == row['recurrence'],
            orElse: () => TaskRecurrence.none),
        weekdays: _splitIntSet(row['weekdays'] as String?),
        assignedChildIds: _splitStringSet(row['assigned_child_ids'] as String?),
        linkedRuleId: row['linked_rule_id'] as String?,
        status: TaskStatus.values.firstWhere((s) => s.name == row['status'],
            orElse: () => TaskStatus.scheduled),
        createdByMemberId: row['created_by_member_id'] as String?,
        createdAt: _parseIso(row['created_at'] as String?) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: _parseIso(row['updated_at'] as String?),
        syncState: SyncState.values.firstWhere(
            (s) => s.name == row['sync_state'],
            orElse: () => SyncState.queued),
      );

  static Set<int> _splitIntSet(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toSet();
  }

  static Set<String> _splitStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static DateTime? _parseIso(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// An append-only record that something happened to a task. The honest
/// source of `TaskStatus.completed` — status is derived, log is truth.
class TaskCompletionEntry {
  const TaskCompletionEntry({
    required this.id,
    required this.taskId,
    required this.familyId,
    required this.childId,
    required this.action,
    required this.actorMemberId,
    required this.actedAt,
    this.note,
  });

  final String id;
  final String taskId;
  final String familyId;
  final String childId;

  final TaskCompletionAction action;
  final String actorMemberId;
  final DateTime actedAt;
  final String? note;

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'family_id': familyId,
        'child_id': childId,
        'action': action.name,
        'actor_member_id': actorMemberId,
        'acted_at': actedAt.toIso8601String(),
        'note': note,
      };

  factory TaskCompletionEntry.fromMap(Map<String, Object?> row) =>
      TaskCompletionEntry(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        familyId: row['family_id'] as String,
        childId: row['child_id'] as String,
        action: TaskCompletionAction.values.firstWhere(
            (a) => a.name == row['action'],
            orElse: () => TaskCompletionAction.requested),
        actorMemberId: (row['actor_member_id'] ?? '') as String,
        actedAt: DateTime.tryParse(row['acted_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        note: row['note'] as String?,
      );
}

/// Actions that may land in the completion log.
enum TaskCompletionAction {
  /// Child self-reported completion; awaits parent verification.
  requested,

  /// Parent (or self-verify policy) confirmed the task done.
  completed,

  /// Task was cancelled before or after completion — history kept.
  cancelled,

  /// Parent rejected a self-report; task reopens.
  declined,
}

/// FS-011 bridge: whether a `taskGated` rule's linked task is done for a
/// child right now. One pure function over the honest log — no state is
/// mutated by the gate; it only reads.
class TaskGateResolver {
  const TaskGateResolver();

  /// True when [completedForChildren] is non-empty and covers every
  /// assigned child of the rule (empty assignment = whole family, so the
  /// gate demands at least one completion in that case).
  bool isGateOpen({
    required Set<String> assignedChildIds,
    required Set<String> completedForChildren,
  }) {
    if (assignedChildIds.isEmpty) return completedForChildren.isNotEmpty;
    return assignedChildIds.every(completedForChildren.contains);
  }

  /// Per-child gate verdicts for a list of `taskGated` rules, given each
  /// rule's link + the completion log for the family.
  Map<String, List<RuleGateVerdict>> resolveForRules({
    required String familyId,
    required List<Map<String, Object?>> rulesWithLinks,
    required Map<String, Set<String>> taskCompletions,
    required String childId,
  }) {
    final byChild = <String, List<RuleGateVerdict>>{};
    for (final rule in rulesWithLinks) {
      final linkedTaskId = rule['linked_task_id'] as String?;
      if (linkedTaskId == null) continue;
      final assigned = (rule['assigned_child_ids'] as String? ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (assigned.isNotEmpty && !assigned.contains(childId)) continue;
      final completed =
          (taskCompletions[linkedTaskId] ?? const {}).contains(childId);
      final ruleId = rule['rule_id'] as String;
      byChild.putIfAbsent(childId, () => []).add(RuleGateVerdict(
            ruleId: ruleId,
            familyId: familyId,
            linkedTaskId: linkedTaskId,
            open: completed,
          ));
    }
    return byChild;
  }
}

/// One gate verdict for a `taskGated` rule: open (task done) or locked.
class RuleGateVerdict {
  const RuleGateVerdict({
    required this.ruleId,
    required this.familyId,
    required this.linkedTaskId,
    required this.open,
  });

  final String ruleId;
  final String familyId;
  final String linkedTaskId;
  final bool open;
}

/// The honest state a tasks dashboard renders.
enum TasksListState { loading, empty, error }
