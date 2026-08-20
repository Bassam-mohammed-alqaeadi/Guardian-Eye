import 'guardian_models.dart';

/// FS-011 — Family Rules & Policy Engine.
///
/// A *family rule* is one coherent, versioned, scheduled policy that a
/// parent authorises for one or more children. Every kind of restriction
/// the platform already supports (web category blocks from FS-002, app
/// blocks from FS-003, situational mode windows from FS-005, geofence
/// reactions from FS-001, SOS behaviour from FS-006) is expressed here as
/// a single `FamilyRule`.
///
/// Conflict discipline (FR-006): when two rules overlap on the same child,
/// the deterministic rule is priority descending, then creation time
/// ascending. Conflicts are computed and surfaced — never silently
/// overridden. Three *reserved* kinds (`taskGated`, `rewardUnlocked`,
/// `eventOverride`) exist as empty extension points that future phases
/// (FS-007 Tasks, FS-008 Rewards, FS-014 Calendar) bind to by adding an
/// execution handler — the screens in this phase already render them.

/// The kinds of rules the engine understands today plus reserved
/// extension points. Future phases add a kind and an execution handler;
/// the screens need no change.
enum RuleKind {
  /// Daily screen-time cap in minutes per child (executes through
  /// `child_usage_summaries` limits).
  dailyScreenTime,

  /// Bedtime/device-curfew window (executes through FS-005 mode blocks).
  bedtime,

  /// Homework window: only education categories survive.
  homework,

  /// Per-app block/allow applied at specific times.
  appRule,

  /// Content-category web block per child.
  contentCategory,

  /// Geofence entry/exit reaction per child.
  geofenceRule,

  /// SOS behaviour: an active SOS lifts restrictions temporarily.
  sosRule,

  // ── Reserved extension points (execution bound by future phases) ──

  /// FS-007 Tasks: target unlocked only when a task is complete.
  taskGated,

  /// FS-008 Rewards: points purchase a temporary relaxation.
  rewardUnlocked,

  /// FS-014 Calendar: a family event temporarily suspends rules.
  eventOverride,
}

extension RuleKindDisplay on RuleKind {
  String get labelKey => switch (this) {
        RuleKind.dailyScreenTime => 'frKindScreenTime',
        RuleKind.bedtime => 'frKindBedtime',
        RuleKind.homework => 'frKindHomework',
        RuleKind.appRule => 'frKindApp',
        RuleKind.contentCategory => 'frKindContent',
        RuleKind.geofenceRule => 'frKindGeofence',
        RuleKind.sosRule => 'frKindSos',
        RuleKind.taskGated => 'frKindTaskGated',
        RuleKind.rewardUnlocked => 'frKindReward',
        RuleKind.eventOverride => 'frKindEvent',
      };
  String get tooltipKey => switch (this) {
        RuleKind.dailyScreenTime => 'frKindScreenTimeTip',
        RuleKind.bedtime => 'frKindBedtimeTip',
        RuleKind.homework => 'frKindHomeworkTip',
        RuleKind.appRule => 'frKindAppTip',
        RuleKind.contentCategory => 'frKindContentTip',
        RuleKind.geofenceRule => 'frKindGeofenceTip',
        RuleKind.sosRule => 'frKindSosTip',
        RuleKind.taskGated => 'frKindTaskGatedTip',
        RuleKind.rewardUnlocked => 'frKindRewardTip',
        RuleKind.eventOverride => 'frKindEventTip',
      };

  /// Kinds whose execution handler is already wired (FS-002/003/005/006
  /// data layers). Reserved kinds execute only after their phase binds.
  bool get isExecutable =>
      this != RuleKind.taskGated &&
      this != RuleKind.rewardUnlocked &&
      this != RuleKind.eventOverride;
}

/// Recurrence shape of a rule's active window.
enum RuleScheduleKind {
  /// Same window every day.
  daily,

  /// Explicit weekday selection.
  weekly,

  /// Fires once at a given moment and expires.
  oneTime,
}

/// What a rule does when it is active for a child.
enum RuleAction {
  /// Full block of the restricted targets during the window.
  block,

  /// Limits stay but the leash tightens.
  restrict,

  /// Allow list only: everything not listed is blocked.
  allowlistOnly,

  /// Notify parents without device-side enforcement.
  notifyOnly,
}

/// The target a `geofenceRule` reacts to — entering or leaving a fence.
enum GeofenceTrigger { entering, exiting }

/// An immutable family rule authored by a parent.

class FamilyRule {
  const FamilyRule({
    required this.ruleId,
    required this.familyId,
    required this.name,
    this.kind = RuleKind.dailyScreenTime,
    this.action = RuleAction.restrict,
    this.enabled = true,
    this.startMinute = 0,
    this.endMinute = 0,
    this.scheduleKind = RuleScheduleKind.daily,
    this.weekdays = const {1, 2, 3, 4, 5},
    this.oneshotAt,
    required this.assignedChildIds,
    this.appTargets = const {},
    this.categoryTargets = const {},
    this.geofenceIds = const {},
    this.geofenceTrigger = GeofenceTrigger.entering,
    this.limitMinutes,
    this.linkedTaskId = '',
    this.priority = 50,
    this.note,
    this.createdByMemberId,
    this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.queued,
  });

  final String ruleId;
  final String familyId;
  final String name;
  final RuleKind kind;
  final RuleAction action;
  final bool enabled;

  /// Daily window start as minute-of-day (0..1439).
  final int startMinute;

  /// Daily window end as minute-of-day (0..1439).
  final int endMinute;
  final RuleScheduleKind scheduleKind;

  /// 1..7 ISO weekday set for weekly schedules.
  final Set<int> weekdays;

  /// Absolute fire moment for one-time rules.
  final DateTime? oneshotAt;
  final Set<String> assignedChildIds;

  /// App package targets (`appRule`).
  final Set<String> appTargets;

  /// Web category targets (`contentCategory`).
  final Set<String> categoryTargets;

  /// Geofence ids (`geofenceRule`) — empty means all fences.
  final Set<String> geofenceIds;
  final GeofenceTrigger geofenceTrigger;

  /// Daily cap in minutes (`dailyScreenTime`). Null means unset.
  final int? limitMinutes;

  /// FS-007 bridge: `taskGated` rules link to a task — the gate reads the
  /// honest completion log; this id is the contract between subsystems.
  final String linkedTaskId;

  /// Deterministic conflict ordering: higher wins; ties broken by creation.
  final int priority;
  final String? note;
  final String? createdByMemberId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  FamilyRule copyWith({
    String? name,
    RuleKind? kind,
    RuleAction? action,
    bool? enabled,
    int? startMinute,
    int? endMinute,
    RuleScheduleKind? scheduleKind,
    Set<int>? weekdays,
    DateTime? oneshotAt,
    Set<String>? assignedChildIds,
    Set<String>? appTargets,
    Set<String>? categoryTargets,
    Set<String>? geofenceIds,
    GeofenceTrigger? geofenceTrigger,
    int? limitMinutes,
    String? linkedTaskId,
    int? priority,
    String? note,
    SyncState? syncState,
  }) =>
      FamilyRule(
        ruleId: ruleId,
        familyId: familyId,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        action: action ?? this.action,
        enabled: enabled ?? this.enabled,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
        scheduleKind: scheduleKind ?? this.scheduleKind,
        weekdays: weekdays ?? this.weekdays,
        oneshotAt: oneshotAt ?? this.oneshotAt,
        assignedChildIds: assignedChildIds ?? this.assignedChildIds,
        appTargets: appTargets ?? this.appTargets,
        categoryTargets: categoryTargets ?? this.categoryTargets,
        geofenceIds: geofenceIds ?? this.geofenceIds,
        geofenceTrigger: geofenceTrigger ?? this.geofenceTrigger,
        limitMinutes: limitMinutes ?? this.limitMinutes,
        linkedTaskId: linkedTaskId ?? this.linkedTaskId,
        priority: priority ?? this.priority,
        note: note ?? this.note,
        createdByMemberId: createdByMemberId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncState: syncState ?? this.syncState,
      );

  Duration get windowDuration {
    final end = endMinute == 0 && startMinute != 0 ? 1440 : endMinute;
    return Duration(minutes: end - startMinute);
  }

  /// Whether this rule's window contains [moment], ignoring weekday/
  /// one-shot membership (checked at evaluation time instead).
  bool isActiveAt(DateTime moment) {
    if (!enabled) return false;
    if (scheduleKind == RuleScheduleKind.oneTime) {
      final fire = oneshotAt;
      if (fire == null) return false;
      return moment.isAtSameMomentAs(fire) ||
          (moment.isAfter(fire) &&
              moment.difference(fire) < const Duration(minutes: 1));
    }
    if (scheduleKind == RuleScheduleKind.weekly &&
        !weekdays.contains(moment.weekday)) {
      return false;
    }
    if (startMinute == endMinute) return true;
    final minute = moment.hour * 60 + moment.minute;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }

  /// Whether this rule concerns [childId].
  bool appliesToChild(String childId) =>
      assignedChildIds.isEmpty || assignedChildIds.contains(childId);

  Map<String, Object?> toMap() => {
        'rule_id': ruleId,
        'family_id': familyId,
        'name': name,
        'kind': kind.name,
        'action': action.name,
        'enabled': enabled ? 1 : 0,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'schedule_kind': scheduleKind.name,
        'weekdays': (weekdays.toList()..sort()).join(','),
        'oneshot_at': oneshotAt?.toIso8601String(),
        'assigned_child_ids': (assignedChildIds.toList()..sort()).join(','),
        'app_targets': (appTargets.toList()..sort()).join(','),
        'category_targets': (categoryTargets.toList()..sort()).join(','),
        'geofence_ids': (geofenceIds.toList()..sort()).join(','),
        'geofence_trigger': geofenceTrigger.name,
        'limit_minutes': limitMinutes,
        'linked_task_id': linkedTaskId,
        'priority': priority,
        'note': note,
        'created_by_member_id': createdByMemberId,
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
        'sync_state': syncState.name,
      };

  factory FamilyRule.fromMap(Map<String, Object?> row) => FamilyRule(
        ruleId: row['rule_id'] as String,
        familyId: row['family_id'] as String,
        name: row['name'] as String,
        kind: RuleKind.values.firstWhere((k) => k.name == row['kind'],
            orElse: () => RuleKind.dailyScreenTime),
        action: RuleAction.values.firstWhere((a) => a.name == row['action'],
            orElse: () => RuleAction.restrict),
        enabled: (row['enabled'] as int) == 1,
        startMinute: row['start_minute'] as int,
        endMinute: row['end_minute'] as int,
        scheduleKind: RuleScheduleKind.values.firstWhere(
            (s) => s.name == row['schedule_kind'],
            orElse: () => RuleScheduleKind.daily),
        weekdays: _splitIntSet(row['weekdays'] as String?),
        oneshotAt: _parseIso(row['oneshot_at'] as String?),
        assignedChildIds: _splitStringSet(row['assigned_child_ids'] as String?),
        appTargets: _splitStringSet(row['app_targets'] as String?),
        categoryTargets: _splitStringSet(row['category_targets'] as String?),
        geofenceIds: _splitStringSet(row['geofence_ids'] as String?),
        geofenceTrigger: GeofenceTrigger.values.firstWhere(
            (t) => t.name == row['geofence_trigger'],
            orElse: () => GeofenceTrigger.entering),
        limitMinutes: row['limit_minutes'] as int?,
        linkedTaskId: (row['linked_task_id'] ?? '') as String,
        priority: row['priority'] as int,
        note: row['note'] as String?,
        createdByMemberId: row['created_by_member_id'] as String?,
        createdAt: _parseIso(row['created_at'] as String?),
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

/// A per-child verdict produced by the engine at evaluation time.

class RuleVerdict {
  const RuleVerdict({
    required this.childId,
    required this.blocked,
    required this.ruleIds,
    required this.reason,
  });

  final String childId;
  final bool blocked;
  final List<String> ruleIds;
  final String reason;
}

/// An overlap between two rules on the same child — surfaced in FR-006,
/// never silently suppressed.

class RuleConflict {
  const RuleConflict({
    required this.childId,
    required this.first,
    required this.second,
  });

  final String childId;
  final FamilyRule first;
  final FamilyRule second;

  /// Deterministic winner: priority descending, creation ascending.
  FamilyRule get winner {
    final cmp = second.priority.compareTo(first.priority);
    if (cmp != 0) return cmp < 0 ? first : second;
    final a = first.createdAt;
    final b = second.createdAt;
    if (a == null || b == null) return first;
    return a.isBefore(b) ? first : second;
  }

  FamilyRule get loser => winner == first ? second : first;
}

/// The honest state a rules list screen renders.
enum RulesListState { loading, empty, error }

/// An evaluation pass result over one family at one moment: verdicts per
/// child plus the computed (and never hidden) conflicts.

class PolicyEvaluation {
  const PolicyEvaluation({
    required this.familyId,
    required this.evaluatedAt,
    required this.verdicts,
    required this.conflicts,
  });

  final String familyId;
  final DateTime evaluatedAt;
  final List<RuleVerdict> verdicts;
  final List<RuleConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// A record that a rule executed (or was skipped) for a child — feeds the
/// future FS-009 rules report without extra instrumentation.

class RuleExecutionEntry {
  const RuleExecutionEntry({
    required this.id,
    required this.ruleId,
    required this.familyId,
    required this.childId,
    required this.outcome,
    required this.reason,
    required this.evaluatedAt,
  });

  final String id;
  final String ruleId;
  final String familyId;
  final String childId;
  final String outcome;
  final String reason;
  final DateTime evaluatedAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'rule_id': ruleId,
        'family_id': familyId,
        'child_id': childId,
        'outcome': outcome,
        'reason': reason,
        'evaluated_at': evaluatedAt.toIso8601String(),
      };

  factory RuleExecutionEntry.fromMap(Map<String, Object?> row) =>
      RuleExecutionEntry(
        id: row['id'] as String,
        ruleId: row['rule_id'] as String,
        familyId: row['family_id'] as String,
        childId: row['child_id'] as String,
        outcome: row['outcome'] as String,
        reason: row['reason'] as String,
        evaluatedAt: DateTime.parse(row['evaluated_at'] as String),
      );
}
