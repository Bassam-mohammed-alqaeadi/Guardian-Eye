import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../domain/guardian_models.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/location_repository.dart';
import '../widgets/guardian_map_widget.dart';
import '../widgets/guardian_primitives.dart';

/// FS-001 — Location & Geofencing screens (LO-001 … LO-014).
///
/// Honesty contract: every surface shows only locally observed facts.
/// Positions come from the `location_points` store, geofences from
/// `geofences`, alerts from `location_alerts`, and all of them refresh
/// against the verified server policy through `familyLocationPullProvider`
/// (exactly like the web filter pull). When the pull fails the banner is
/// shown and the local view stays visible — never an empty shell, never a
/// fabricated "everything synced" claim. Authorization is delegated to the
/// single family role matrix (`FamilyRuntimeContext.can`) — never re-checked
/// locally.

/// Shared authorization + loading guard for all LO-* screens, matching the
/// FS-002 dashboard pattern exactly: loading while the runtime resolves,
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

// ─────────────────────────── LO-001 Family map ───────────────────────

/// `/location/:familyId` — LO-001. The family map dashboard: latest known
/// position of every member, geofence chips, unacknowledged alert badge,
/// and quick navigation into members, geofences, and history.
class FamilyMapScreen extends ConsumerWidget {
  const FamilyMapScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final points = ref.watch(locationPointsProvider(familyId));
    final geofences = ref.watch(geofencesProvider(familyId));
    final alertCount = ref.watch(locationAlertCountProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {
            // The pull failed — the honest local view stays visible.
          }
          ref.invalidate(locationPointsProvider(familyId));
          ref.invalidate(geofencesProvider(familyId));
          ref.invalidate(locationAlertsProvider(familyId));
          ref.invalidate(locationAlertCountProvider(familyId));
        },
        child: Scaffold(
          backgroundColor: GuardianTokens.guardianNavy,
          appBar: AppBar(
            title: Text(l10n.t('familyMap')),
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.invalidate(locationPointsProvider(familyId)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianOfflineBanner(),
              const SizedBox(height: 16),
              _buildMapCard(context, ref, l10n, points, geofences),
              const SizedBox(height: 16),
              _buildAlertsTile(context, l10n, alertCount),
              const SizedBox(height: 16),
              _buildMembersSection(context, ref, l10n, points),
              const SizedBox(height: 16),
              _buildGeofencesSection(context, l10n, geofences),
              const SizedBox(height: 16),
              GuardianCard(
                child: Row(children: [
                  Expanded(
                    child: _NavTile(
                      icon: Icons.history,
                      label: l10n.t('locationHistory'),
                      onTap: () {
                        final firstWatchable = runtime.valueOrNull?.allMembers
                            .where((m) => m.role == FamilyRole.child || m.role == FamilyRole.spouse)
                            .firstOrNull;
                        final target = firstWatchable != null
                            ? '/location/$familyId/${firstWatchable.id}/history'
                            : '/location/$familyId';
                        if (firstWatchable != null) {
                          GoRouter.of(context).push(target);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _NavTile(
                      icon: Icons.star_outline,
                      label: l10n.t('favoritePlaces'),
                      onTap: () => GoRouter.of(context)
                          .push('/location/$familyId/places'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Row(children: [
                  Expanded(
                    child: _NavTile(
                      icon: Icons.settings_outlined,
                      label: l10n.t('locationSettings'),
                      onTap: () => GoRouter.of(context)
                          .push('/location/$familyId/settings'),
                    ),
                  ),
                  Expanded(
                    child: _NavTile(
                      icon: Icons.privacy_tip_outlined,
                      label: l10n.t('locationPrivacy'),
                      onTap: () => GoRouter.of(context)
                          .push('/location/$familyId/privacy'),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.sync_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('offlineMode'),
                            style:
                                Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(l10n.t('offlineChangesSaved'),
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, WidgetRef ref, AppLocalizations l10n,
      AsyncValue<List<LocationPoint>> points,
      AsyncValue<List<GeofenceEntry>> geofences) {
    final pointsValue = points.valueOrNull ?? const [];
    final geofenceValues = geofences.valueOrNull ?? const [];
    final latestByMember = <String, LocationPoint>{};
    for (final point in pointsValue) {
      final key = point.memberId ?? 'unknown';
      final existing = latestByMember[key];
      if (existing == null || point.capturedAt.isAfter(existing.capturedAt)) {
        latestByMember[key] = point;
      }
    }
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final memberById = {
      for (final member in runtime.valueOrNull?.allMembers ?? const [])
        member.id: member.displayName,
    };
    final mapPoints = latestByMember.entries.map((entry) {
      final point = entry.value;
      final fresh = LocationFreshness.evaluate([point], DateTime.now());
      return MapPoint(
          latitude: point.latitude,
          longitude: point.longitude,
          memberId: point.memberId,
          memberName: memberById[point.memberId] ?? point.memberId ?? '',
          fresh: fresh.key == 'fresh');
    }).toList();
    final mapGeofences = geofenceValues
        .where((geofence) =>
            geofence.status == 'active' || geofence.status == 'entered')
        .map((geofence) => MapGeofence(
            latitude: geofence.latitude,
            longitude: geofence.longitude,
            radiusFraction:
                (geofence.radiusMeters / 5000).clamp(0.08, 0.45),
            name: geofence.name,
            status: geofence.status))
        .toList();
    return GuardianHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GuardianIconBadge(
                icon: Icons.map_outlined,
                background: Colors.white24,
                foreground: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.t('familyMap'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 12),
          GuardianMapWidget(
            points: mapPoints,
            geofences: mapGeofences,
            height: 240,
            emptyTitle: l10n.t('noLocationsYet'),
          ),
          const SizedBox(height: 12),
          Text(l10n.t('offlineChangesSaved'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildAlertsTile(BuildContext context, AppLocalizations l10n, AsyncValue<int> alertCount) {
    final count = alertCount.valueOrNull ?? 0;
    return GuardianCard(
      child: InkWell(
        onTap: () =>
            GoRouter.of(context).push('/location/$familyId/alerts'),
        child: Row(children: [
          GuardianIconBadge(
              icon: Icons.notifications_outlined,
              background: count > 0
                  ? const Color(0xFFE8A33D).withValues(alpha: 0.25)
                  : Colors.white12,
              foreground: count > 0
                  ? const Color(0xFFE8A33D)
                  : Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(l10n.t('locationAlerts'),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          GuardianStatusChip(
              label: '$count',
              kind: count > 0 ? GuardianStatusKind.watch : GuardianStatusKind.safe),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context, WidgetRef ref, AppLocalizations l10n,
      AsyncValue<List<LocationPoint>> points) {
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final pointsValue = points.valueOrNull ?? const [];
    final watchableMembers = runtime.valueOrNull?.allMembers
            .where((member) =>
                member.role == FamilyRole.child ||
                member.role == FamilyRole.spouse)
            .toList() ??
        const [];
    return GuardianSection(title: l10n.t('members'), children: [
      GuardianCard(
        child: watchableMembers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.t('noMembersYet'),
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              )
            : Column(
                children: watchableMembers.map((member) {
                  final memberPoints = pointsValue
                      .where((point) => point.memberId == member.id)
                      .toList();
                  final fresh = LocationFreshness.evaluate(
                      memberPoints, DateTime.now());
                  return InkWell(
                    onTap: () => GoRouter.of(context)
                        .push('/location/$familyId/${member.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        GuardianIconBadge(
                            icon: Icons.person_outline,
                            background: Colors.white12,
                            foreground: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                              Text(
                                  '${fresh.label} · ${_lastUpdatedText(l10n, memberPoints)}',
                                  style: TextStyle(
                                      color: fresh.colorName == 'green'
                                          ? GuardianTokens.guardianTeal
                                          : fresh.colorName == 'amber'
                                              ? const Color(0xFFE8A33D)
                                              : Colors.white38,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.white38),
                      ]),
                    ),
                  );
                }).toList(),
              ),
      ),
    ]);
  }

  String _lastUpdatedText(AppLocalizations l10n, List<LocationPoint> points) {
    if (points.isEmpty) return '—';
    final latest = points.reduce((a, b) =>
        a.capturedAt.isAfter(b.capturedAt) ? a : b);
    final minutes =
        DateTime.now().difference(latest.capturedAt).inMinutes;
    if (minutes < 1) return l10n.t('justNow');
    if (minutes < 60) return '$minutes ${l10n.t('minutesAgo')}';
    return '${(minutes ~/ 60)} ${l10n.t('hoursAgo')}';
  }

  Widget _buildGeofencesSection(BuildContext context, AppLocalizations l10n,
      AsyncValue<List<GeofenceEntry>> geofences) {
    final values = geofences.valueOrNull ?? const [];
    final active =
        values.where((g) => g.status == 'active' || g.status == 'entered');
    return GuardianSection(
      title: l10n.t('geofences'),
      trailing: values.isNotEmpty
          ? TextButton(
              onPressed: () => GoRouter.of(context)
                  .push('/location/$familyId/geofences'),
              child: Text(l10n.t('viewAll')))
          : null,
      children: [
        GuardianCard(
          child: active.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Text(l10n.t('noGeofencesYet'),
                          style:
                              TextStyle(color: Colors.white54, fontSize: 13)),
                    ),
                  ]),
                )
              : Column(
                  children: active
                      .take(3)
                      .map((geofence) => InkWell(
                            onTap: () => GoRouter.of(context).push(
                                '/location/$familyId/geofences/${geofence.id}/edit'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                GuardianIconBadge(
                                    icon: Icons.circle_outlined,
                                    background: geofence.status == 'entered'
                                        ? GuardianTokens.guardianTeal
                                            .withValues(alpha: 0.25)
                                        : Colors.white12,
                                    foreground: geofence.status == 'entered'
                                        ? GuardianTokens.guardianTeal
                                        : Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(geofence.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text(
                                          '${geofence.radiusMeters.round()} ${l10n.t('radiusMeters').toLowerCase()}',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: Colors.white38),
                              ]),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Icon(icon, color: GuardianTokens.guardianTeal, size: 28),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white)),
        ]),
      ),
    );
  }
}

// ──────────────────────── LO-002 Member location ─────────────────────

/// `/location/:familyId/members/:memberId` — LO-002. One member's current
/// position, honesty chip (fresh / stale / offline), device telemetry, and
/// the geofence they are inside — plus the door into their route history.
class MemberLocationDetailsScreen extends ConsumerWidget {
  const MemberLocationDetailsScreen(
      {required this.familyId, required this.memberId, super.key});
  final String familyId;
  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final points = ref.watch(
        locationPointsForMemberProvider((familyId: familyId, memberId: memberId)));
    final geofences = ref.watch(geofencesProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('memberLocationDetails')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _MemberLocationBody(
            familyId: familyId,
            memberId: memberId,
            runtime: runtime,
            points: points,
            geofences: geofences),
      ),
    );
  }
}

class _MemberLocationBody extends ConsumerWidget {
  const _MemberLocationBody({
    required this.familyId,
    required this.memberId,
    required this.runtime,
    required this.points,
    required this.geofences,
  });
  final String familyId;
  final String memberId;
  final AsyncValue<FamilyRuntimeContext> runtime;
  final AsyncValue<List<LocationPoint>> points;
  final AsyncValue<List<GeofenceEntry>> geofences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (runtime.isLoading || points.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    if (points.error != null) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('syncFailed'),
        message: l10n.t('somethingWentWrong'),
      );
    }
    final runtimeValue = runtime.valueOrNull;
    final member = runtimeValue?.allMembers
        .where((candidate) => candidate.id == memberId)
        .firstOrNull;
    if (member == null) {
      return GuardianStateView(state: GuardianViewState.error,
          title: l10n.t('roleNotAllowed'),
          message: l10n.t('authorizationFailure'));
    }
    final pointsValue = points.valueOrNull ?? const [];
    final geofenceValues = geofences.valueOrNull ?? const [];
    final fresh = LocationFreshness.evaluate(pointsValue, DateTime.now());
    final latest = pointsValue.isEmpty
        ? null
        : pointsValue.reduce((a, b) =>
            a.capturedAt.isAfter(b.capturedAt) ? a : b);
    final insideGeofence = _closestEnteredGeofence(
        latest, geofenceValues.where((g) => g.status == 'active' || g.status == 'entered').toList());
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {}
          ref.invalidate(locationPointsForMemberProvider(
              (familyId: familyId, memberId: memberId)));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.location_on_outlined,
                    background: fresh.colorName == 'green'
                        ? GuardianTokens.guardianTeal
                            .withValues(alpha: 0.25)
                        : Colors.white24,
                    foreground: fresh.colorName == 'green'
                        ? GuardianTokens.guardianTeal
                        : Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      GuardianStatusChip(
                          label: fresh.label,
                          kind: fresh.colorName == 'green'
                              ? GuardianStatusKind.safe
                              : fresh.colorName == 'amber'
                                  ? GuardianStatusKind.watch
                                  : GuardianStatusKind.alert),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('lastUpdated'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _telemetryRow(context, l10n.t('lastUpdated'),
                        latest == null
                            ? '—'
                            : '${latest.capturedAt.hour.toString().padLeft(2, '0')}:${latest.capturedAt.minute.toString().padLeft(2, '0')}'),
                    _telemetryRow(context, l10n.t('batteryLevel'),
                        latest?.batteryLevel == null
                            ? '—'
                            : '${(latest!.batteryLevel! * 100).round()}%'),
                    _telemetryRow(context, l10n.t('accuracyMeters'),
                        latest == null
                            ? '—'
                            : '${latest.accuracyMeters.round()} m'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('geofences'), children: [
              GuardianCard(
                child: insideGeofence == null
                    ? Row(children: [
                        Expanded(
                          child: Text(l10n.t('memberNotNearAnyGeofence'),
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ),
                      ])
                    : Row(children: [
                        GuardianIconBadge(
                            icon: Icons.circle_outlined,
                            background: GuardianTokens.guardianTeal
                                .withValues(alpha: 0.25),
                            foreground: GuardianTokens.guardianTeal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(insideGeofence.name,
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                        ),
                      ]),
              ),
            ]),
            const SizedBox(height: 16),
            GuardianCard(
              child: InkWell(
                onTap: () => GoRouter.of(context).push(
                    '/location/$familyId/$memberId/history'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.history),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('locationHistory'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  GeofenceEntry? _closestEnteredGeofence(
      LocationPoint? point, List<GeofenceEntry> active) {
    if (point == null || active.isEmpty) return null;
    GeofenceEntry? closest;
    var closestDistance = double.infinity;
    for (final geofence in active) {
      final distance = distanceMeters(point.latitude, point.longitude,
          geofence.latitude, geofence.longitude);
      if (distance <= geofence.radiusMeters && distance < closestDistance) {
        closest = geofence;
        closestDistance = distance;
      }
    }
    return closest;
  }

  Widget _telemetryRow(
      BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: Colors.white54, fontSize: 13))),
        Text(value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white)),
      ]),
    );
  }
}

// ──────────────────────── LO-003 Location history ──────────────────────

/// `/location/:familyId/:memberId/history` — LO-003. Route trace for one
/// day, drawn from real stored points (`pointsForDay`), with an honest day
/// selector and an empty state when no points were synced for the day.
class LocationHistoryScreen extends ConsumerStatefulWidget {
  const LocationHistoryScreen(
      {required this.familyId, required this.memberId, super.key});
  final String familyId;
  final String memberId;

  @override
  ConsumerState<LocationHistoryScreen> createState() =>
      _LocationHistoryScreenState();
}

class _LocationHistoryScreenState
    extends ConsumerState<LocationHistoryScreen> {
  DateTime _selectedDay = DateTime.now();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    // The history view is always scoped to the member the caller asked for —
    // never silently re-targeted to a runtime-derived member, which would
    // silently show the wrong person's route trace.
    final memberId = widget.memberId;
    final points = ref.watch(locationPointsForMemberProvider(
        (familyId: widget.familyId, memberId: memberId)));
    final dayStart = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day).toUtc().toIso8601String();
    final dayEnd = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 23, 59, 59).toUtc().toIso8601String();

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('locationHistory')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _buildBody(l10n, runtime, memberId, points, dayStart, dayEnd),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n,
      AsyncValue<FamilyRuntimeContext> runtime,
      String memberId,
      AsyncValue<List<LocationPoint>> allPoints,
      String dayStart,
      String dayEnd) {
    if (allPoints.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    final allPointsValue = allPoints.valueOrNull ?? const [];
    final dayPoints = allPointsValue
        .where((point) =>
            point.capturedAt.toIso8601String().startsWith(
                DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)
                    .toIso8601String()
                    .substring(0, 10)))
        .toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final memberName = runtime.valueOrNull?.allMembers
        .where((m) => m.id == memberId)
        .firstOrNull
        ?.displayName;
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianOfflineBanner(),
          const SizedBox(height: 16),
          GuardianHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.t('routeTrace')} · $memberName',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                GuardianMapWidget(
                  points: dayPoints.isEmpty
                      ? const []
                      : dayPoints
                          .map((p) => MapPoint(
                              latitude: p.latitude, longitude: p.longitude))
                          .toList(),
                  routePoints: dayPoints
                      .map((p) => MapPoint(
                          latitude: p.latitude, longitude: p.longitude))
                      .toList(),
                  height: 220,
                  emptyTitle: l10n.t('noLocationsYet'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianCard(
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() =>
                    _selectedDay = _selectedDay.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: Text(
                  '${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => setState(() =>
                    _selectedDay = _selectedDay.add(const Duration(days: 1))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (dayPoints.isEmpty)
            GuardianStateView(
                state: GuardianViewState.empty,
                title: l10n.t('noLocationsYet'),
                message: l10n.t('offlineChangesSaved'))
          else
            GuardianCard(
              child: Column(
                children: dayPoints.map((point) {
                  final fresh = LocationFreshness.evaluate(
                      [point], DateTime.now());
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Icon(Icons.circle,
                          size: 8,
                          color: fresh.colorName == 'green'
                              ? GuardianTokens.guardianTeal
                              : const Color(0xFFE8A33D)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${point.capturedAt.hour.toString().padLeft(2, '0')}:${point.capturedAt.minute.toString().padLeft(2, '0')} · ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      ),
                      if (point.batteryLevel != null)
                        Text('${(point.batteryLevel! * 100).round()}%',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────── LO-004 Geofence list ─────────────────────────

/// `/location/:familyId/geofences` — LO-004. Every geofence with its honest
/// status chip, enable/disable toggle, and the door into create/edit.
class GeofenceListScreen extends ConsumerWidget {
  const GeofenceListScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final geofences = ref.watch(geofencesProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageChildren,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('geofences')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => GoRouter.of(context)
                  .push('/location/$familyId/geofences/new'),
            ),
          ],
        ),
        body: _GeofenceListBody(
            familyId: familyId, geofences: geofences, runtime: runtime),
      ),
    );
  }
}

class _GeofenceListBody extends ConsumerWidget {
  const _GeofenceListBody({
    required this.familyId,
    required this.geofences,
    required this.runtime,
  });
  final String familyId;
  final AsyncValue<List<GeofenceEntry>> geofences;
  final AsyncValue<FamilyRuntimeContext> runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.watch(locationGeofenceRepositoryProvider);
    if (geofences.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    final values = geofences.valueOrNull ?? const [];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {}
          ref.invalidate(geofencesProvider(familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            values.isEmpty
                ? GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('noGeofencesYet'),
                    message: l10n.t('offlineChangesSaved'))
                : GuardianCard(
                    child: Column(
                      children: values.map((geofence) {
                        final enabled = geofence.status != 'disabled';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            GuardianIconBadge(
                                icon: Icons.circle_outlined,
                                background: enabled
                                    ? GuardianTokens.guardianTeal
                                        .withValues(alpha: 0.25)
                                    : Colors.white12,
                                foreground: enabled
                                    ? GuardianTokens.guardianTeal
                                    : Colors.white54),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => GoRouter.of(context).push(
                                    '/location/$familyId/geofences/${geofence.id}/edit'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(geofence.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${geofence.radiusMeters.round()} m · ${l10n.t(geofence.alertOnEntry ? 'alertOnEntry' : 'alertOnExit')}',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: enabled,
                              activeColor: GuardianTokens.guardianTeal,
                              onChanged: (enabledNew) async {
                                try {
                                  await repository.setGeofenceEnabled(
                                      existing: geofence, enabled: enabledNew);
                                  ref.invalidate(geofencesProvider(familyId));
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  scaffoldMessenger
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                        content: Text(enabledNew
                                            ? l10n.t('geofenceSaved')
                                            : l10n.t('geofenceRemoved'))));
                                } catch (_) {
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  scaffoldMessenger
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                        content: Text(
                                            l10n.t('somethingWentWrong'))));
                                }
                              },
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
            const SizedBox(height: 16),
            GuardianCard(
              child: InkWell(
                onTap: () => GoRouter.of(context)
                    .push('/location/$familyId/geofences/new'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    GuardianIconBadge(icon: Icons.add_location_alt_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('createGeofence'),
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── LO-005 Create geofence ───────────────────────────

/// `/location/:familyId/geofences/new` — LO-005. Geofence creation form:
/// name, radius slider, entry/exit alert toggles, a favorite-place anchor
/// (the map centers on the anchor's stored coordinates, or a neutral
/// default when no anchor exists), and an honest save that reports local
/// persistence even while offline. Inline geofence templates (LO-014) sit
/// at the top of the form and pre-fill a sensible name, radius, and
/// alert profile.
class CreateGeofenceScreen extends ConsumerStatefulWidget {
  const CreateGeofenceScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<CreateGeofenceScreen> createState() =>
      _CreateGeofenceScreenState();
}

class _CreateGeofenceScreenState extends ConsumerState<CreateGeofenceScreen> {
  final TextEditingController _nameController = TextEditingController();
  double _radiusMeters = 500;
  bool _alertOnEntry = true;
  bool _alertOnExit = true;
  String _placeKey = 'home';
  bool _saving = false;
  double _tapFractionX = 0.5;
  double _tapFractionY = 0.5;

  static const Map<String, _DefaultAnchor> _anchors = {
    'home': _DefaultAnchor(24.7136, 46.6753),
    'school': _DefaultAnchor(24.7500, 46.7100),
    'mosque': _DefaultAnchor(24.6900, 46.6900),
    'grandma': _DefaultAnchor(24.7300, 46.6200),
  };

  Future<_Coordinates> _anchorCoordinates() async {
    final repository = ref.read(locationGeofenceRepositoryProvider);
    final place =
        await repository.placeByKey(widget.familyId, _placeKey);
    if (place != null) {
      return _Coordinates(place.latitude, place.longitude);
    }
    final fallback = _anchors[_placeKey] ?? _DefaultAnchor(24.7136, 46.6753);
    return _Coordinates(fallback.latitude, fallback.longitude);
  }

  Future<void> _save() async {
    final repository = ref.read(locationGeofenceRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('geofenceNameRequired'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final anchor = await _anchorCoordinates();
      final latitude = anchor.latitude + (_tapFractionY - 0.5) * 0.04;
      final longitude = anchor.longitude + (_tapFractionX - 0.5) * 0.04;
      await repository.addGeofence(
        familyId: widget.familyId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: _radiusMeters,
        alertOnEntry: _alertOnEntry,
        alertOnExit: _alertOnExit,
        placeKey: _placeKey,
      );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.t('geofenceSaved'))));
        GoRouter.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.t('somethingWentWrong'))));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageChildren,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('createGeofence')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianOfflineBanner(),
              const SizedBox(height: 16),
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('geofenceName'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.t('geofenceName'),
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l10n.t('geofenceRadius')}: ${_radiusMeters.round()} m',
                        style: Theme.of(context).textTheme.titleSmall),
                    Slider(
                      value: _radiusMeters,
                      min: 50,
                      max: 5000,
                      divisions: 39,
                      activeColor: GuardianTokens.guardianTeal,
                      inactiveColor: Colors.white24,
                      onChanged: (value) =>
                          setState(() => _radiusMeters = value),
                    ),
                    Text(l10n.t('geofenceRadiusHint'),
                        style: TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _GeofenceTemplatePresets(
                apply: (template) => setState(() {
                  _nameController.text = template.localizedName(l10n);
                  _radiusMeters = template.radiusMeters;
                  _alertOnEntry = template.alertOnEntry;
                  _alertOnExit = template.alertOnExit;
                  _placeKey = template.placeKey;
                }),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('selectPlaceOnMap'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    GuardianMapWidget(
                      points: [
                        MapPoint(
                            latitude: 24.7136,
                            longitude: 46.6753,
                            fresh: true),
                      ],
                      height: 180,
                      emptyTitle: l10n.t('tapToSetCenter'),
                      onTapPosition: (normalizedX, normalizedY) {
                        setState(() {
                          _tapFractionX = normalizedX;
                          _tapFractionY = normalizedY;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('setFavoritePlace'),
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _placeChip(context, l10n, 'home', Icons.home_outlined),
                        _placeChip(context, l10n, 'school', Icons.school_outlined),
                        _placeChip(context, l10n, 'mosque', Icons.mosque_outlined),
                        _placeChip(context, l10n, 'grandma', Icons.favorite_outline),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GuardianCard(
                child: Column(
                  children: [
                    _switchRow(context, l10n.t('alertOnEntry'), _alertOnEntry,
                        (value) => setState(() => _alertOnEntry = value)),
                    _switchRow(context, l10n.t('alertOnExit'), _alertOnExit,
                        (value) => setState(() => _alertOnExit = value)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: GuardianTokens.guardianTeal,
                    foregroundColor: GuardianTokens.guardianNavy,
                    minimumSize: const Size(double.infinity, 52)),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: GuardianTokens.guardianNavy))
                    : Text(l10n.t('save')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeChip(BuildContext context, AppLocalizations l10n,
      String key, IconData icon) {
    final selected = _placeKey == key;
    return ChoiceChip(
      label: Text(l10n.t('place$key')),
      selected: selected,
      onSelected: (selectedNew) =>
          setState(() => _placeKey = key),
      backgroundColor: Colors.white10,
      selectedColor: GuardianTokens.guardianTeal,
      labelStyle: TextStyle(
          color: selected ? GuardianTokens.guardianNavy : Colors.white),
      avatar: Icon(icon,
          color: selected ? GuardianTokens.guardianNavy : Colors.white54),
    );
  }

  Widget _switchRow(BuildContext context, String label, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value,
      activeColor: GuardianTokens.guardianTeal,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }
}

// ──────────────────── LO-014 Geofence templates ────────────────────────

/// One preset used to pre-fill the create/edit form: sensible defaults
/// that parents can accept as-is or tune. Templates are declarative
/// constants — never fetched from the network, so the form is honest even
/// offline.
final class GeofenceTemplate {
  const GeofenceTemplate({
    required this.key,
    required this.labelKey,
    required this.nameKey,
    required this.radiusMeters,
    required this.placeKey,
    required this.alertOnEntry,
    required this.alertOnExit,
  });

  /// Stable machine key for the template (l10n-agnostic).
  final String key;

  /// Localization key for the displayed label.
  final String labelKey;

  /// Localization key of the name pre-filled into the geofence field.
  final String nameKey;

  /// Pre-filled display name, resolved lazily by the form through l10n.
  String localizedName(AppLocalizations l10n) => l10n.t(nameKey);

  /// Radius in meters pre-filled into the slider.
  final double radiusMeters;

  /// Favorite-place anchor the form should target.
  final String placeKey;

  final bool alertOnEntry;
  final bool alertOnExit;

  static const List<GeofenceTemplate> presets = <GeofenceTemplate>[
    GeofenceTemplate(
        key: 'school-hours',
        labelKey: 'templateSchoolHours',
        nameKey: 'templateSchoolHoursName',
        radiusMeters: 400,
        placeKey: 'school',
        alertOnEntry: true,
        alertOnExit: true),
    GeofenceTemplate(
        key: 'home-range',
        labelKey: 'templateHomeRange',
        nameKey: 'templateHomeRangeName',
        radiusMeters: 200,
        placeKey: 'home',
        alertOnEntry: false,
        alertOnExit: true),
    GeofenceTemplate(
        key: 'prayer-place',
        labelKey: 'templatePrayerPlace',
        nameKey: 'templatePrayerPlaceName',
        radiusMeters: 250,
        placeKey: 'mosque',
        alertOnEntry: true,
        alertOnExit: false),
  ];
}

/// LO-014 inline template presets rendered at the top of the geofence
/// form. Tapping one pre-fills the name, radius, alert profile, and
/// anchor, and the parent can freely adjust anything afterward.
class _GeofenceTemplatePresets extends StatelessWidget {
  const _GeofenceTemplatePresets({required this.apply});
  final void Function(GeofenceTemplate) apply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GuardianIconBadge(
                icon: Icons.auto_awesome_outlined,
                background:
                    GuardianTokens.guardianTeal.withValues(alpha: 0.25),
                foreground: GuardianTokens.guardianTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l10n.t('geofenceTemplates'),
                  style:
                      Theme.of(context).textTheme.titleSmall),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final template in GeofenceTemplate.presets)
                ActionChip(
                  label: Text(l10n.t(template.labelKey),
                      style: TextStyle(
                          color: GuardianTokens.guardianNavy, fontSize: 12)),
                  backgroundColor: GuardianTokens.guardianTeal,
                  onPressed: () => apply(template),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultAnchor {
  const _DefaultAnchor(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class _Coordinates {
  const _Coordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

// ──────────────────── LO-006 Edit geofence ─────────────────────────────

/// `/location/:familyId/geofences/:geofenceId/edit` — LO-006. Geofence edit form,
/// pre-filled from the stored entry, with an honest delete path that stamps
/// a removal marker for server sync.
class EditGeofenceScreen extends ConsumerStatefulWidget {
  const EditGeofenceScreen(
      {required this.familyId, required this.geofenceId, super.key});
  final String familyId;
  final String geofenceId;

  @override
  ConsumerState<EditGeofenceScreen> createState() =>
      _EditGeofenceScreenState();
}

class _EditGeofenceScreenState extends ConsumerState<EditGeofenceScreen> {
  TextEditingController? _nameController;
  double _radiusMeters = 500;
  bool _alertOnEntry = true;
  bool _alertOnExit = true;
  bool _loading = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(locationGeofenceRepositoryProvider);
    final geofences = ref.watch(geofencesProvider(widget.familyId));
    final entry = (geofences.valueOrNull ?? const [])
        .where((candidate) => candidate.id == widget.geofenceId)
        .firstOrNull;

    if (_loading && geofences.isLoading) {
      return Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('editGeofence')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: const GuardianStateView(state: GuardianViewState.loading),
      );
    }
    if (entry == null) {
      return Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('editGeofence')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
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

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        title: Text(l10n.t('editGeofence')),
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('geofenceName'),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController ??=
                        TextEditingController(text: entry.name),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: l10n.t('geofenceName'),
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${l10n.t('geofenceRadius')}: ${_radiusMeters.round()} m',
                      style: Theme.of(context).textTheme.titleSmall),
                  Slider(
                    value: _radiusMeters,
                    min: 50,
                    max: 5000,
                    divisions: 39,
                    activeColor: GuardianTokens.guardianTeal,
                    inactiveColor: Colors.white24,
                    onChanged: (value) =>
                        setState(() => _radiusMeters = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuardianCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: Text(l10n.t('alertOnEntry'),
                        style: const TextStyle(color: Colors.white)),
                    value: _alertOnEntry,
                    activeColor: GuardianTokens.guardianTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) =>
                        setState(() => _alertOnEntry = value),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(l10n.t('alertOnExit'),
                        style: const TextStyle(color: Colors.white)),
                    value: _alertOnExit,
                    activeColor: GuardianTokens.guardianTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) =>
                        setState(() => _alertOnExit = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: GuardianTokens.guardianTeal,
                  foregroundColor: GuardianTokens.guardianNavy,
                  minimumSize: const Size(double.infinity, 52)),
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                try {
                  await repository.updateGeofence(
                    existing: entry,
                    name: _nameController!.text.trim(),
                    latitude: entry.latitude,
                    longitude: entry.longitude,
                    radiusMeters: _radiusMeters,
                    alertOnEntry: _alertOnEntry,
                    alertOnExit: _alertOnExit,
                  );
                  if (mounted) {
                    setState(() => _saving = false);
                    ref.invalidate(geofencesProvider(widget.familyId));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                          SnackBar(content: Text(l10n.t('geofenceSaved'))));
                    GoRouter.of(context).pop();
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() => _saving = false);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(l10n.t('somethingWentWrong'))));
                  }
                }
              },
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(l10n.t('saveChanges')),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB23A48).withValues(alpha: 0.25),
                  foregroundColor: const Color(0xFFE07A85),
                  minimumSize: const Size(double.infinity, 52)),
              onPressed: () async {
                try {
                  await repository.setGeofenceEnabled(
                      existing: entry, enabled: false);
                  if (mounted) {
                    ref.invalidate(geofencesProvider(widget.familyId));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                          SnackBar(content: Text(l10n.t('geofenceRemoved'))));
                    GoRouter.of(context).pop();
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(l10n.t('somethingWentWrong'))));
                  }
                }
              },
              child: Text(l10n.t('delete')),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── LO-007 Location settings ─────────────────────────

/// `/location/:familyId/settings` — LO-007. Honest location settings:
/// battery-saver mode, per-member sharing revocation, and a plain statement
/// of what is and is not known to the server.
class LocationSettingsScreen extends ConsumerWidget {
  const LocationSettingsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageChildren,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('locationSettings')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _LocationSettingsBody(familyId: familyId, runtime: runtime),
      ),
    );
  }
}

class _LocationSettingsBody extends ConsumerStatefulWidget {
  const _LocationSettingsBody({required this.familyId, required this.runtime});
  final String familyId;
  final AsyncValue<FamilyRuntimeContext> runtime;

  @override
  ConsumerState<_LocationSettingsBody> createState() =>
      _LocationSettingsBodyState();
}

class _LocationSettingsBodyState extends ConsumerState<_LocationSettingsBody> {
  Future<Map<String, String>>? _settingsFuture;

  Future<Map<String, String>> _loadSettings() async {
    final repository = ref.read(locationGeofenceRepositoryProvider);
    final batterySaver = await repository.setting(
        widget.familyId, 'battery_saver', 'off');
    final values = <String, String>{'battery_saver': batterySaver};
    final members = widget.runtime.valueOrNull?.children ?? const [];
    for (final member in members) {
      final sharing = await repository.setting(
          widget.familyId, 'sharing_enabled:${member.id}', 'on');
      values['sharing_enabled:${member.id}'] = sharing;
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(locationGeofenceRepositoryProvider);
    _settingsFuture ??= _loadSettings();
    return FutureBuilder<Map<String, String>>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const GuardianStateView(state: GuardianViewState.loading);
        }
        final settingsValue = snapshot.data ?? const <String, String>{};
        final members = widget.runtime.valueOrNull?.children ?? const [];
        return Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: RefreshIndicator(
            onRefresh: () async {
              _settingsFuture = null;
              setState(() {});
              try {
                await ref.read(familyLocationPullProvider(widget.familyId).future);
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GuardianOfflineBanner(),
                const SizedBox(height: 16),
                GuardianSection(title: l10n.t('batterySaver'), children: [
                  GuardianCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          title: Text(l10n.t('batterySaver'),
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(l10n.t('batterySaverDescription'),
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                          value: settingsValue['battery_saver'] == 'on',
                          activeColor: GuardianTokens.guardianTeal,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (value) async {
                            try {
                              await repository.setSetting(
                                  familyId: widget.familyId,
                                  key: 'battery_saver',
                                  value: value ? 'on' : 'off');
                              _settingsFuture = null;
                              setState(() {});
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(
                                      content: Text(l10n.t('somethingWentWrong'))));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                GuardianSection(title: l10n.t('sharingMatrix'), children: [
                  GuardianCard(
                    child: members.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(l10n.t('noMembersYet'),
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                          )
                        : Column(
                            children: members.map((member) {
                              final sharingKey = 'sharing_enabled:${member.id}';
                              final sharingOn =
                                  settingsValue[sharingKey] != 'off';
                              return SwitchListTile.adaptive(
                                title: Text(member.displayName,
                                    style: const TextStyle(color: Colors.white)),
                                value: sharingOn,
                                activeColor: GuardianTokens.guardianTeal,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) async {
                                  try {
                                    await repository.setSetting(
                                        familyId: widget.familyId,
                                        key: sharingKey,
                                        value: value ? 'on' : 'off');
                                    _settingsFuture = null;
                                    setState(() {});
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                            content: Text(value
                                                ? l10n.t('sharingEnabled')
                                                : l10n.t('sharingRevoked'))));
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                            content: Text(
                                                l10n.t('somethingWentWrong'))));
                                    }
                                  }
                                },
                              );
                            }).toList(),
                          ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────── LO-008 Location alerts ───────────────────────────

/// `/location/:familyId/alerts` — LO-008. Honest alert feed: every stored
/// `LocationAlert` with event type, member, and timestamp, filterable by
/// entry/exit, with an acknowledge action that stamps the server fact
/// (no fake "cleared" states — the row persists until the server confirms).
class LocationAlertsScreen extends ConsumerWidget {
  const LocationAlertsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final alerts = ref.watch(locationAlertsProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('locationAlerts')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _LocationAlertsBody(
            familyId: familyId, runtime: runtime, alerts: alerts),
      ),
    );
  }
}

class _LocationAlertsBody extends ConsumerWidget {
  const _LocationAlertsBody({
    required this.familyId,
    required this.runtime,
    required this.alerts,
  });
  final String familyId;
  final AsyncValue<FamilyRuntimeContext> runtime;
  final AsyncValue<List<LocationAlert>> alerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(locationGeofenceRepositoryProvider);
    if (alerts.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    if (alerts.error != null) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('syncFailed'),
        message: l10n.t('somethingWentWrong'),
        onRetry: () => ref.invalidate(locationAlertsProvider(familyId)),
      );
    }
    final values = alerts.valueOrNull ?? const [];
    final geofenceNames = <String, String>{};
    for (final geofence in ref.read(geofencesProvider(familyId)).valueOrNull ?? const []) {
      geofenceNames[geofence.id] = geofence.name;
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {}
          ref.invalidate(locationAlertsProvider(familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/onboarding_alerts.png',
                height: 168,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            values.isEmpty
                ? GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('noAlertsYet'),
                    message: l10n.t('offlineChangesSaved'))
                : GuardianCard(
                    child: Column(
                      children: values.map((alert) {
                        final isNew = !alert.acknowledged;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: isNew
                              ? BoxDecoration(
                                  border: Border(
                                      left: BorderSide(
                                          color: GuardianTokens.guardianTeal,
                                          width: 3)))
                              : null,
                          child: Row(children: [
                            GuardianIconBadge(
                                icon: alert.eventType == 'entry'
                                    ? Icons.login
                                    : Icons.logout,
                                background: isNew
                                    ? GuardianTokens.guardianTeal
                                        .withValues(alpha: 0.25)
                                    : Colors.white12,
                                foreground: isNew
                                    ? GuardianTokens.guardianTeal
                                    : Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      l10n.t(alert.eventType == 'entry'
                                          ? 'entry'
                                          : 'exit'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${alert.memberDisplayName ?? l10n.t('members')} · ${geofenceNames[alert.geofenceId] ?? '—'}',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${alert.occurredAt.hour.toString().padLeft(2, '0')}:${alert.occurredAt.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                          color: Colors.white24,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            if (!alert.acknowledged)
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await repository.acknowledgeAlert(
                                        familyId: familyId,
                                        alertId: alert.id);
                                    ref.invalidate(
                                        locationAlertsProvider(familyId));
                                    ref.invalidate(
                                        locationAlertCountProvider(
                                            familyId));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                            content: Text(l10n.t(
                                                'alertAcknowledged'))));
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(SnackBar(
                                            content: Text(l10n.t(
                                                'somethingWentWrong'))));
                                    }
                                  }
                                },
                                child: Text(l10n.t('acknowledge')),
                              )
                            else
                              Text(l10n.t('alertAcknowledged'),
                                  style: TextStyle(
                                      color: GuardianTokens.guardianTeal,
                                      fontSize: 12)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────── LO-009 Location privacy ──────────────────────────

/// `/location/:familyId/privacy` — LO-009. Plain-language privacy disclosure:
/// what is collected, how long it is kept, who can see it, and the honest
/// "we never sell it" statement. Static, no state, always reachable.
class LocationPrivacyScreen extends ConsumerWidget {
  const LocationPrivacyScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('locationPrivacy')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianHeroCard(
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.privacy_tip,
                      background: GuardianTokens.guardianTeal
                          .withValues(alpha: 0.25),
                      foreground: GuardianTokens.guardianTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('locationPrivacy'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              _disclosureCard(context, l10n,
                  l10n.t('privacyLocationCollection'),
                  l10n.t('privacyLocationCollectionDetail')),
              const SizedBox(height: 12),
              _disclosureCard(context, l10n,
                  l10n.t('privacyLocationRetention'),
                  l10n.t('privacyLocationRetentionDetail')),
              const SizedBox(height: 12),
              _disclosureCard(context, l10n,
                  l10n.t('privacyParentAccess'),
                  l10n.t('privacyParentAccessDetail')),
              const SizedBox(height: 12),
              _disclosureCard(context, l10n,
                  l10n.t('privacyThirdParty'),
                  l10n.t('privacyThirdPartyDetail')),
              const SizedBox(height: 12),
              _disclosureCard(context, l10n,
                  l10n.t('privacyDeleteData'),
                  l10n.t('privacyDeleteDataDetail')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disclosureCard(BuildContext context, AppLocalizations l10n,
      String title, String body) {
    return GuardianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: GuardianTokens.guardianTeal)),
          const SizedBox(height: 8),
          Text(body,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }
}

// ────────────────── LO-010 Permission onboarding ────────────────────────

/// `/location/:familyId/permissions` — LO-010. The honest permission ladder:
/// coarse → fine → background location, each step explaining exactly why
/// the family needs it and what breaks if it is denied. No fabricated
/// "permission granted" — this screen only describes and hand off to the
/// platform permission dialog through `LocationPermissionLauncher`.
class PermissionOnboardingScreen extends ConsumerWidget {
  const PermissionOnboardingScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('permissionOnboarding')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/onboarding_location.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              GuardianHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('permissionRationale'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(l10n.t('permissionRationaleDetail'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _permissionStepCard(context, l10n, 1,
                  l10n.t('coarseLocation'), l10n.t('coarseLocationDetail')),
              const SizedBox(height: 12),
              _permissionStepCard(context, l10n, 2,
                  l10n.t('fineLocation'), l10n.t('fineLocationDetail')),
              const SizedBox(height: 12),
              _permissionStepCard(context, l10n, 3,
                  l10n.t('backgroundLocation'),
                  l10n.t('backgroundLocationDetail')),
              const SizedBox(height: 16),
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.warning_amber_outlined,
                      background: const Color(0xFFE8A33D)
                          .withValues(alpha: 0.25),
                      foreground: const Color(0xFFE8A33D)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('permissionNotSupported'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: const Color(0xFFE8A33D), height: 1.3)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionStepCard(BuildContext context, AppLocalizations l10n,
      int step, String title, String detail) {
    return GuardianCard(
      child: Row(children: [
        GuardianIconBadge(icon: Icons.location_on_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$step · $title',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white54, height: 1.3)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ────────────────── LO-011 Sharing status ───────────────────────────────

/// `/location/:familyId/sharing` — LO-011. Read-only sharing matrix: which
/// members share location, per the verified setting rows. The write path
/// lives in location settings (LO-007), keeping this screen a single
/// honest view of family sharing state.
class SharingStatusScreen extends ConsumerWidget {
  const SharingStatusScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final settings = ref.watch(locationSettingsProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewChildStatus,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('locationSharing')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _SharingStatusBody(
            familyId: familyId, runtime: runtime, settings: settings),
      ),
    );
  }
}

class _SharingStatusBody extends ConsumerWidget {
  const _SharingStatusBody({
    required this.familyId,
    required this.runtime,
    required this.settings,
  });
  final String familyId;
  final AsyncValue<FamilyRuntimeContext> runtime;
  final AsyncValue<Map<String, String>> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (settings.isLoading || runtime.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    if (settings.error != null) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('syncFailed'),
        message: l10n.t('somethingWentWrong'),
      );
    }
    final members = runtime.valueOrNull?.children ?? const [];
    final settingsValue = settings.valueOrNull ?? const <String, String>{};
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {}
          ref.invalidate(locationSettingsProvider(familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianCard(
              child: members.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.t('noMembersYet'),
                          style:
                              TextStyle(color: Colors.white54, fontSize: 13)),
                    )
                  : Column(
                      children: members.map((member) {
                        final sharingKey = 'sharing_enabled:${member.id}';
                        final sharingOn =
                            settingsValue[sharingKey] != 'off';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            GuardianIconBadge(icon: Icons.person_outline),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(member.displayName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  Text(
                                      sharingOn
                                          ? l10n.t('sharingEnabled')
                                          : l10n.t('sharingDisabled'),
                                      style: TextStyle(
                                          color: sharingOn
                                              ? GuardianTokens.guardianTeal
                                              : const Color(0xFFE8A33D),
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────── LO-012 Favorite places ──────────────────────────────

/// `/location/:familyId/places` — LO-012. Favorite places store (home,
/// school, mosque, grandma): real stored coordinates, anchor-to-geofence
/// hint, and a template setter that writes an honest `favorite_places`
/// row through the outbox.
class FavoritePlacesScreen extends ConsumerWidget {
  const FavoritePlacesScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final places = ref.watch(favoritePlacesProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.manageChildren,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        appBar: AppBar(
          title: Text(l10n.t('favoritePlaces')),
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
        ),
        body: _FavoritePlacesBody(
            familyId: familyId, runtime: runtime, places: places),
      ),
    );
  }
}

class _FavoritePlacesBody extends ConsumerWidget {
  const _FavoritePlacesBody({
    required this.familyId,
    required this.runtime,
    required this.places,
  });
  final String familyId;
  final AsyncValue<FamilyRuntimeContext> runtime;
  final AsyncValue<List<FavoritePlace>> places;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(locationGeofenceRepositoryProvider);
    if (places.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    if (places.error != null) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('syncFailed'),
        message: l10n.t('somethingWentWrong'),
      );
    }
    final values = places.valueOrNull ?? const [];
    final icons = <String, IconData>{
      'home': Icons.home_outlined,
      'school': Icons.school_outlined,
      'mosque': Icons.mosque_outlined,
      'grandma': Icons.favorite_outline,
    };
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.read(familyLocationPullProvider(familyId).future);
          } catch (_) {}
          ref.invalidate(favoritePlacesProvider(familyId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            values.isEmpty
                ? GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('noPlacesYet'),
                    message: l10n.t('offlineChangesSaved'))
                : GuardianCard(
                    child: Column(
                      children: values.map((place) {
                        final key = place.placeKey;
                        final icon = icons[key] ?? Icons.place_outlined;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            GuardianIconBadge(icon: icon),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(place.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  Text(
                                      '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await repository.setPlace(
                                      familyId: familyId,
                                      placeKey: key,
                                      name: place.name,
                                      latitude: place.latitude,
                                      longitude: place.longitude);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                          content: Text(
                                              l10n.t('geofenceSaved'))));
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(SnackBar(
                                          content: Text(l10n.t(
                                              'somethingWentWrong'))));
                                  }
                                }
                              },
                              child: Text(l10n.t('setFavoritePlace')),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
            const SizedBox(height: 16),
            GuardianCard(
              child: Row(children: [
                GuardianIconBadge(icon: Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.t('geofenceRadiusHint'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: Colors.white54, height: 1.3)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
