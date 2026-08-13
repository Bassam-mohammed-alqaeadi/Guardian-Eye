/// M3 — Child Context Vertical: canonical data composition.
///
/// [childContextProvider] joins the four honest local reads a parent may
/// need for a single child: membership (is the child real and active in
/// this family?), device state (what does the local enforcement layer
/// know about this child's device?), recent unacknowledged incidents
/// (family-level safety context), and today's screen-time totals (only
/// when a device is linked).
///
/// Every read is SQLite-backed and family-scoped; nothing here queries
/// Firestore directly, mutates data, or fabricates values. Authorization
/// is CONSULTED, never re-implemented: callers are expected to gate
/// actions with [FamilyRuntimeContext.can], which remains the sole
/// authorization surface.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/child_device_enforcement.dart';
import '../domain/guardian_models.dart';
import '../domain/screen_time.dart';
import 'family_context_provider.dart';
import 'guardian_providers.dart';

/// Aggregate identifier for the child-context provider family. The child
/// is addressed by its stable membership id, not by a mutable object.
typedef ChildContextKey = ({String familyId, String childId});

/// Total minutes of screen time recorded for today — [null] means the
/// device is not linked or no summaries were recorded yet. Never a
/// fabricated zero.
typedef ChildDailyUsage = ({int? totalMinutes, List<DailyUsageSummary> summaries});

/// One honest snapshot of the child context: who the child is, what the
/// local enforcement layer knows about their device, the family's recent
/// unacknowledged incidents, and today's screen-time totals where a
/// device is linked.
class ChildContextSnapshot {
  const ChildContextSnapshot({
    required this.familyId,
    required this.childId,
    required this.child,
    required this.deviceState,
    required this.recentIncidents,
    required this.todayUsage,
  });

  final String familyId;
  final String childId;

  /// The active child member. Presence alone does not imply authorization
  /// to view — callers must check the runtime context permission.
  final FamilyMember child;

  /// The child's device state per the local enforcement layer, or null
  /// when no device is linked to this member.
  final ChildDeviceState? deviceState;

  /// Family-level unacknowledged incidents (newest first, up to 5).
  /// Labeled family-level in the UI — never presented as per-child verdicts.
  final List<GuardianIncident> recentIncidents;

  final ChildDailyUsage todayUsage;
}

final childContextProvider =
    FutureProvider.family<ChildContextSnapshot, ChildContextKey>(
        (ref, ChildContextKey key) async {
  final normalizedFamilyId = key.familyId.trim();
  final normalizedChildId = key.childId.trim();

  // The membership read is canonical and local. A missing or non-active
  // member surfaces as a genuine failure — the UI maps it to the
  // not-found page rather than fabricating a child.
  final membership = await ref
      .watch(familyMembershipRepositoryProvider)
      .memberForFamily(familyId: normalizedFamilyId, memberId: normalizedChildId);
  if (membership == null || !membership.isActive ||
      membership.role != FamilyRole.child) {
    throw StateError('child_context_child_not_found');
  }

  final devices = await ref.watch(
      childDeviceStatesProvider(normalizedFamilyId).future);
  ChildDeviceState? deviceState;
  for (final candidate in devices) {
    if (candidate.memberId == normalizedChildId) {
      deviceState = candidate;
      break;
    }
  }

  final incidents = await ref.watch(
      recentIncidentsProvider(normalizedFamilyId).future);

  ChildDailyUsage? todayUsage;
  if (deviceState != null) {
    final summaries = await ref.watch(
        childUsageForTodayProvider(deviceState.deviceId).future);
    int? totalMinutes;
    if (summaries.isNotEmpty) {
      totalMinutes = (summaries
              .map((s) => s.totalMilliseconds)
              .reduce((a, b) => a + b)) ~/
          Duration.millisecondsPerMinute;
    }
    todayUsage = (totalMinutes: totalMinutes, summaries: summaries);
  }

  return ChildContextSnapshot(
    familyId: normalizedFamilyId,
    childId: normalizedChildId,
    child: membership,
    deviceState: deviceState,
    recentIncidents: incidents.take(5).toList(),
    todayUsage: todayUsage ??
        (totalMinutes: null, summaries: const <DailyUsageSummary>[]),
  );
});
