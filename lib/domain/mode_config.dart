/// FS-005 — Special & Custom Modes.
///
/// Beyond daily screen-time limits, the parent defines situational modes —
/// homework mode, bedtime mode, travel mode — with schedules, child
/// assignment and temporary overrides. Mode records queue through the
/// outbox; the child device applies the last delivered mode until sync.
///
/// Conflict discipline (MD-010): when two modes overlap on the same child,
/// the deterministic rule is priority descending, then creation time
/// ascending. Nothing is silently overridden — the conflict is computed
/// and surfaced.

import 'guardian_models.dart';

/// Which levers a mode pulls on the child's device.
enum ModeAction {
  /// Full block during the mode window.
  block,

  /// Soft slowdown: limits remain, but restrictions tighten.
  slowDown,

  /// Only allowlisted content survives the window.
  allowlistOnly,
}

/// Which mode kinds ship as tested presets.
enum ModeKind {
  homework,
  bedtime,
  travel,
  custom,
}

/// Recurrence shape of a mode's active window.
enum ModeScheduleKind {
  /// Same window every day.
  daily,

  /// Explicit weekday selection.
  weekly,

  /// Fires once at a given moment and expires.
  oneTime,
}

/// A situational mode configured by the parent.
class ModeConfig {
  const ModeConfig(
      {required this.modeId,
      required this.familyId,
      required this.name,
      this.kind = ModeKind.custom,
      this.action = ModeAction.slowDown,
      this.enabled = true,
      this.startMinute = 0,
      this.endMinute = 0,
      this.scheduleKind = ModeScheduleKind.daily,
      this.weekdays = const {1, 2, 3, 4, 5},
      this.oneshotAt,
      required this.assignedChildIds,
      this.categoryRestrictions = const {},
      this.appRestrictions = const {},
      this.priority = 50,
      this.note,
      this.createdAt,
      this.updatedAt,
      this.syncState = SyncState.queued});

  final String modeId;
  final String familyId;
  final String name;
  final ModeKind kind;
  final ModeAction action;
  final bool enabled;

  /// Daily window start as minute-of-day (0..1439).
  final int startMinute;

  /// Daily window end as minute-of-day (0 == midnight rollover allowed).
  final int endMinute;
  final ModeScheduleKind scheduleKind;

  /// 1..7 ISO weekday set for weekly schedules.
  final Set<int> weekdays;

  /// Absolute fire moment for one-time modes.
  final DateTime? oneshotAt;
  final Set<String> assignedChildIds;
  final Set<String> categoryRestrictions;
  final Set<String> appRestrictions;

  /// Deterministic conflict ordering: higher wins; ties broken by creation.
  final int priority;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  Duration get windowDuration {
    final end = endMinute == 0 && startMinute != 0 ? 1440 : endMinute;
    return Duration(minutes: end - startMinute);
  }

  /// Whether this mode's window contains [moment], ignoring weekday/oneshot.
  bool isActiveAt(DateTime moment) {
    if (!enabled) return false;
    final minute = moment.hour * 60 + moment.minute;
    if (scheduleKind == ModeScheduleKind.oneTime) {
      final fire = oneshotAt;
      if (fire == null) return false;
      return moment.isAtSameMomentAs(fire) ||
          (moment.isAfter(fire) &&
              moment.difference(fire) < const Duration(minutes: 1));
    }
    if (scheduleKind == ModeScheduleKind.weekly &&
        !weekdays.contains(moment.weekday)) {
      return false;
    }
    if (startMinute == endMinute) return true;
    if (startMinute < endMinute) {
      return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
  }

  Map<String, Object?> toMap() => {
        'mode_id': modeId,
        'family_id': familyId,
        'name': name,
        'kind': kind.name,
        'action': action.name,
        'enabled': enabled ? 1 : 0,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'schedule_kind': scheduleKind.name,
        'weekdays': weekdays.join(','),
        'oneshot_at': oneshotAt?.toIso8601String(),
        'assigned_child_ids': assignedChildIds.join(','),
        'category_restrictions': categoryRestrictions.join(','),
        'app_restrictions': appRestrictions.join(','),
        'priority': priority,
        'note': note,
        'created_at': createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updated_at':
            updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'sync_state': syncState.name,
      };

  factory ModeConfig.fromMap(Map<String, Object?> row) {
    DateTime? parseIso(Object? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    Set<int> parseWeekdays(Object? raw) {
      if (raw == null || raw.toString().isEmpty) {
        return const {1, 2, 3, 4, 5};
      }
      return raw
          .toString()
          .split(',')
          .map((part) => int.tryParse(part.trim()) ?? 0)
          .where((value) => value >= 1 && value <= 7)
          .toSet();
    }

    Set<String> split(Object? raw) {
      if (raw == null || raw.toString().isEmpty) return const {};
      return raw
          .toString()
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet();
    }

    return ModeConfig(
      modeId: row['mode_id'].toString(),
      familyId: row['family_id'].toString(),
      name: row['name'].toString(),
      kind: _modeKindOf(row['kind']),
      action: _modeActionOf(row['action']),
      enabled: (row['enabled'] as int? ?? 1) != 0,
      startMinute: (row['start_minute'] as int? ?? 0),
      endMinute: (row['end_minute'] as int? ?? 0),
      scheduleKind: _scheduleKindOf(row['schedule_kind']),
      weekdays: parseWeekdays(row['weekdays']),
      oneshotAt: parseIso(row['oneshot_at']),
      assignedChildIds: split(row['assigned_child_ids']),
      categoryRestrictions: split(row['category_restrictions']),
      appRestrictions: split(row['app_restrictions']),
      priority: (row['priority'] as int? ?? 50),
      note: row['note']?.toString(),
      createdAt: parseIso(row['created_at']),
      updatedAt: parseIso(row['updated_at']),
      syncState: _syncStateOf(row['sync_state']),
    );
  }

  static ModeKind _modeKindOf(Object? raw) {
    switch (raw?.toString()) {
      case 'homework':
        return ModeKind.homework;
      case 'bedtime':
        return ModeKind.bedtime;
      case 'travel':
        return ModeKind.travel;
      default:
        return ModeKind.custom;
    }
  }

  static ModeAction _modeActionOf(Object? raw) {
    switch (raw?.toString()) {
      case 'block':
        return ModeAction.block;
      case 'allowlistOnly':
        return ModeAction.allowlistOnly;
      default:
        return ModeAction.slowDown;
    }
  }

  static ModeScheduleKind _scheduleKindOf(Object? raw) {
    switch (raw?.toString()) {
      case 'weekly':
        return ModeScheduleKind.weekly;
      case 'oneTime':
        return ModeScheduleKind.oneTime;
      default:
        return ModeScheduleKind.daily;
    }
  }

  static SyncState _syncStateOf(Object? raw) {
    switch (raw?.toString()) {
      case 'synced':
        return SyncState.synced;
      case 'failed':
        return SyncState.failed;
      case 'blocked':
        return SyncState.blocked;
      case 'localOnly':
        return SyncState.localOnly;
      default:
        return SyncState.queued;
    }
  }

  ModeConfig copyWith({
    String? modeId,
    String? familyId,
    String? name,
    ModeKind? kind,
    ModeAction? action,
    bool? enabled,
    int? startMinute,
    int? endMinute,
    ModeScheduleKind? scheduleKind,
    Set<int>? weekdays,
    DateTime? oneshotAt,
    Set<String>? assignedChildIds,
    Set<String>? categoryRestrictions,
    Set<String>? appRestrictions,
    int? priority,
    String? note,
    DateTime? createdAt,
    SyncState? syncState,
  }) {
    return ModeConfig(
      modeId: modeId ?? this.modeId,
      familyId: familyId ?? this.familyId,
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
      categoryRestrictions: categoryRestrictions ?? this.categoryRestrictions,
      appRestrictions: appRestrictions ?? this.appRestrictions,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      syncState: syncState ?? this.syncState,
    );
  }
}

/// A tested starting-point preset for mode creation (MD-009).
class ModeTemplate {
  const ModeTemplate(
      {required this.key,
      required this.name,
      required this.description,
      required this.mode});
  final String key;
  final String name;
  final String description;
  final ModeConfig mode;

  static const List<ModeTemplate> builtIns = [
    ModeTemplate(
      key: 'homework',
      name: 'Homework',
      description: 'Focus hours: games and entertainment blocked.',
      mode: ModeConfig(
        modeId: 'preset-homework',
        familyId: '',
        name: 'Homework',
        kind: ModeKind.homework,
        action: ModeAction.allowlistOnly,
        startMinute: 16 * 60,
        endMinute: 19 * 60,
        scheduleKind: ModeScheduleKind.weekly,
        weekdays: {1, 2, 3, 4, 5},
        assignedChildIds: const {},
        categoryRestrictions: {'games', 'social', 'video'},
        priority: 60,
      ),
    ),
    ModeTemplate(
      key: 'bedtime',
      name: 'Bedtime',
      description: 'Device winds down for a healthy night.',
      mode: ModeConfig(
        modeId: 'preset-bedtime',
        familyId: '',
        name: 'Bedtime',
        kind: ModeKind.bedtime,
        action: ModeAction.block,
        startMinute: 21 * 60,
        endMinute: 7 * 60,
        assignedChildIds: const {},
        categoryRestrictions: {'games', 'social', 'video'},
        priority: 70,
      ),
    ),
    ModeTemplate(
      key: 'travel',
      name: 'Travel',
      description: 'Gentle limits while the family is on the road.',
      mode: ModeConfig(
        modeId: 'preset-travel',
        familyId: '',
        name: 'Travel',
        kind: ModeKind.travel,
        action: ModeAction.slowDown,
        startMinute: 0,
        endMinute: 24 * 60 - 1,
        scheduleKind: ModeScheduleKind.oneTime,
        assignedChildIds: const {},
        categoryRestrictions: {'social'},
        priority: 40,
      ),
    ),
  ];
}

/// A recorded mode activation for one child (honest log — never fake
/// `applied`). States: active, applied, requested, failed, expired.
class ModeActivation {
  const ModeActivation(
      {required this.activationId,
      required this.modeId,
      required this.familyId,
      this.childId,
      required this.state,
      required this.startedAt,
      this.endsAt,
      this.decidedBy,
      this.syncState = SyncState.queued});

  final String activationId;
  final String modeId;
  final String familyId;
  final String? childId;
  final String state; // active | applied | requested | failed | expired
  final DateTime startedAt;
  final DateTime? endsAt;
  final String? decidedBy;
  final SyncState syncState;

  Map<String, Object?> toMap() => {
        'activation_id': activationId,
        'mode_id': modeId,
        'family_id': familyId,
        'child_id': childId,
        'state': state,
        'started_at': startedAt.toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt!.toIso8601String(),
        if (decidedBy != null) 'decided_by': decidedBy,
        'created_at': DateTime.now().toIso8601String(),
        'sync_state': syncState.name,
      };

  factory ModeActivation.fromMap(Map<String, Object?> row) {
    DateTime? parseIso(Object? raw) =>
        raw == null ? null : DateTime.tryParse(raw.toString());
    return ModeActivation(
      activationId: row['activation_id'].toString(),
      modeId: row['mode_id'].toString(),
      familyId: row['family_id'].toString(),
      childId: row['child_id']?.toString(),
      state: row['state'].toString(),
      startedAt: parseIso(row['started_at']) ?? DateTime.now(),
      endsAt: parseIso(row['ends_at']),
      decidedBy: row['decided_by']?.toString(),
      syncState: row['sync_state']?.toString() == 'synced'
          ? SyncState.synced
          : SyncState.queued,
    );
  }
}

/// Deterministic resolution of two simultaneously active modes on one
/// child (MD-010). The mode with the higher priority wins; equal priority
/// defers to the earlier creation. The losing mode is recorded, never
/// silently dropped.
class ModeConflictResolution {
  const ModeConflictResolution(
      {required this.childId,
      required this.winner,
      required this.loser,
      required this.reason});
  final String childId;
  final ModeConfig winner;
  final ModeConfig loser;
  final String reason;

  bool get hasConflict => true;
}

/// Resolves which of a set of modes wins for one child at a moment.
class ModeConflictResolver {
  const ModeConflictResolver();

  /// Modes the child is inside right now, ordered by the deterministic
  /// rule (priority desc, createdAt asc). The first entry is the effective
  /// mode; every following entry loses with an explicit recorded reason.
  List<ModeConfig> effectiveOrder(
      {required Iterable<ModeConfig> modes,
      required String childId,
      DateTime? moment}) {
    final active = modes
        .where((mode) =>
            mode.enabled &&
            mode.assignedChildIds.contains(childId) &&
            mode.isActiveAt(moment ?? DateTime.now()))
        .toList()
      ..sort((left, right) {
        final byPriority = right.priority.compareTo(left.priority);
        if (byPriority != 0) return byPriority;
        final leftCreated = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final rightCreated =
            right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return leftCreated.compareTo(rightCreated);
      });
    return active;
  }

  /// Pairwise conflict records between the winner and every loser.
  List<ModeConflictResolution> conflicts({
    required List<ModeConfig> ordered,
    required String childId,
  }) {
    if (ordered.length < 2) return const [];
    final winner = ordered.first;
    return ordered.skip(1).map((loser) {
      final reason = winner.priority > loser.priority
          ? 'higher_priority'
          : 'earlier_creation';
      return ModeConflictResolution(
          childId: childId, winner: winner, loser: loser, reason: reason);
    }).toList();
  }
}
