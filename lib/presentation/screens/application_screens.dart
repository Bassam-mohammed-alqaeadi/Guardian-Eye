import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/application_policy_repository.dart';
import '../../domain/guardian_models.dart';
import '../../domain/screen_time.dart';
import '../widgets/guardian_primitives.dart';

/// FS-003 — Application Control screens (AC-001 … AC-008).
///
/// One file, eight screens, same visual grammar as every other subsystem:
/// `GuardianHeroCard` header, `GuardianSection` + `GuardianCard` rows,
/// `GuardianStatTile` / `GuardianStatusChip` / `GuardianIconBadge` /
/// `GuardianStateView`, honest outbox evidence, and
/// `FamilyRuntimeContext.can()` as the only authorization gate. Everything
/// writes through `ApplicationPolicyRepository`, which is local-first
/// like every other feature in the platform.

/// Formats a duration like "1 س 20 د" / "1h 20m" for allowance chips.
String _formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours <= 0) return minutes > 0 ? '${minutes}m' : '0m';
  return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
}

/// Reads a human-friendly display name for a target: the usage registry
/// (child_usage_summaries `target`) stores the package path; the repository
/// exposes it as-is so the UI stays honest — a raw target is never quietly
/// replaced with a guessed label.
String _targetLabel(String target) {
  final lastSlash = target.lastIndexOf('/');
  return lastSlash >= 0 ? target.substring(lastSlash + 1) : target;
}

// ───────────────────────── AC-001 App Control Dashboard ─────────────────

/// `/apps/:familyId` — AC-001. The parent opens app protection from here:
/// honest blocked-app count today, family restriction level, per-child
/// protection summary, and the administrative destinations.
class AppControlDashboardScreen extends ConsumerStatefulWidget {
  const AppControlDashboardScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<AppControlDashboardScreen> createState() =>
      _AppControlDashboardState();
}

class _AppControlDashboardState
    extends ConsumerState<AppControlDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final policies = ref.watch(appPoliciesProvider(widget.familyId));
    final events = ref.watch(appBlockEventsProvider(widget.familyId));

    if (runtime.hasError || policies.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appPoliciesProvider(widget.familyId));
              ref.invalidate(appBlockEventsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        policies.isLoading ||
        events.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewPolicies)) {
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
    final policyList = policies.valueOrNull ?? const [];
    final eventList = events.valueOrNull ?? const [];
    final blockedCount =
        policyList.where((p) => p.action == AppPolicyAction.block).length;
    final restrictedCount =
        policyList.where((p) => p.action != AppPolicyAction.allow).length;
    final blockedToday =
        eventList.where((e) => e.eventType == AppBlockEventType.block).length;
    final restrictionKind = blockedCount > 0
        ? GuardianStatusKind.alert
        : restrictedCount > 0
            ? GuardianStatusKind.watch
            : GuardianStatusKind.safe;
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(appPolicyPullProvider(widget.familyId).future);
        ref.invalidate(appPoliciesProvider(widget.familyId));
        ref.invalidate(appBlockEventsProvider(widget.familyId));
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
                          icon: Icons.apps_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('appControlDashboard'),
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
                          icon: Icons.block_outlined,
                          value: '$blockedCount',
                          label: l10n.t('blockedApps'),
                          kind: blockedCount > 0
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.event_busy_outlined,
                          value: '$blockedToday',
                          label: l10n.t('blockedTodayApps'),
                          kind: blockedToday > 0
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  GuardianStatusChip(
                      kind: restrictionKind,
                      label: l10n.t('appProtectionSummary')),
                  const SizedBox(height: 6),
                  Text(
                      blockedCount > 0
                          ? l10n.t('appProtectionActive')
                          : l10n.t('appProtectionRelaxed'),
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
            GuardianSection(
              title: l10n.t('children'),
              trailing: canManage
                  ? GestureDetector(
                      onTap: () => context
                          .push('/apps/${widget.familyId}/apps-list'),
                      child: Text(l10n.t('installedAppsNav'),
                          style: const TextStyle(
                              color: GuardianTokens.guardianTeal,
                              fontWeight: FontWeight.w600)),
                    )
                  : null,
              children: [
                for (final child in children)
                  _ChildAppProtectionTile(
                      familyId: widget.familyId,
                      child: child,
                      policies: policyList,
                      events: eventList,
                      onTap: () => context.push(
                          '/apps/${widget.familyId}/${child.id}')),
              ],
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('appProtection'), children: [
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/apps/${widget.familyId}/apps-list')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.apps_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('installedApps'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('installedAppsDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right,
                        color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/apps/${widget.familyId}/allowlist')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.verified_user_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('appAllowlist'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('appAllowlistDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right,
                        color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/apps/${widget.familyId}/alerts')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.notifications_active_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('usageAlerts'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('usageAlertsDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right,
                        color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/apps/${widget.familyId}/history')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.history_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('appBlockHistory'),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('appBlockHistoryDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right,
                        color: GuardianTokens.guardianTeal),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Per-child app protection tile inside the app dashboard (AC-001).
/// "Not protected" is shown honestly — never inferred as protected.
class _ChildAppProtectionTile extends StatelessWidget {
  const _ChildAppProtectionTile({
    required this.familyId,
    required this.child,
    required this.policies,
    required this.events,
    required this.onTap,
  });
  final String familyId;
  final FamilyMember child;
  final List<AppPolicyEntry> policies;
  final List<AppBlockEvent> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final childPolicies =
        policies.where((p) => p.childId == child.id || p.childId.isEmpty);
    final childBlocks = childPolicies
        .where((p) => p.action == AppPolicyAction.block)
        .length;
    final childChildEvents =
        events.where((e) => e.childId == child.id).length;
    final kind = childBlocks > 0
        ? GuardianStatusKind.watch
        : childPolicies.isEmpty
            ? GuardianStatusKind.offline
            : GuardianStatusKind.safe;
    return GuardianCard(
      onTap: onTap,
      child: Row(children: [
        GuardianIconBadge(icon: Icons.person_outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(child.displayName,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
                childBlocks > 0
                    ? l10n.t('appsBlocked').replaceAll('{count}', '$childBlocks')
                    : l10n.t('noAppsBlocked'),
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SizedBox(width: 8),
        if (childChildEvents > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('+$childChildEvents',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: GuardianTokens.guardianNavy)),
          ),
        GuardianStatusChip(kind: kind, label: kind == GuardianStatusKind.watch
            ? l10n.t('protected')
            : childPolicies.isEmpty
                ? l10n.t('notProtected')
                : l10n.t('limited')),
      ]),
    );
  }
}

// ────────────────────── AC-002 Installed Apps List ─────────────────────

/// `/apps/:familyId/apps-list` — AC-002. Filterable list of known apps
/// seen on the family's child devices, each with an honest policy chip
/// and quick block/allow toggle. Tapping a row opens the per-app policy.
class InstalledAppsListScreen extends ConsumerStatefulWidget {
  const InstalledAppsListScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<InstalledAppsListScreen> createState() =>
      _InstalledAppsListState();
}

class _InstalledAppsListState extends ConsumerState<InstalledAppsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final usage = ref.watch(appUsageForFamilyProvider(widget.familyId));
    final policies = ref.watch(appPoliciesProvider(widget.familyId));
    final allowlist = ref.watch(appAllowlistProvider(widget.familyId));

    if (runtime.hasError || usage.hasError || policies.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appUsageForFamilyProvider(widget.familyId));
              ref.invalidate(appPoliciesProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        usage.isLoading ||
        policies.isLoading ||
        allowlist.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewUsage)) {
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
    final usageList = usage.valueOrNull ?? const [];
    final policyList = policies.valueOrNull ?? const [];
    final allowlisted =
        (allowlist.valueOrNull ?? const []).map((a) => a.target).toSet();
    final canManage = contextValue.can(FamilyPermission.managePolicies);
    final policyOf = {
      for (final p in policyList) p.target: p,
    };
    final filtered = usageList
        .where((u) =>
            _query.isEmpty ||
            _targetLabel(u.target)
                .toLowerCase()
                .contains(_query.toLowerCase()))
        .toList();
    if (usageList.isEmpty) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('noAppsUsage'),
            message: l10n.t('noAppsUsageDescription'),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(children: [
              GuardianIconBadge(
                  icon: Icons.apps_outlined,
                  background: Colors.white24,
                  foreground: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.t('installedApps'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: l10n.t('searchApps'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 16),
          for (final u in filtered) ...[
            _InstalledAppRow(
              familyId: widget.familyId,
              target: u.target,
              usage: u,
              policy: policyOf[u.target],
              isAllowlisted: allowlisted.contains(u.target),
              canManage: canManage,
              onTap: () => context.push(
                  '/apps/${widget.familyId}/details/${Uri.encodeComponent(u.target)}'),
              onToggle: (blocked) => _applyPolicy(
                  context: context,
                  target: u.target,
                  blocked: blocked,
                  policy: policyOf[u.target]),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  void _applyPolicy({
    required BuildContext context,
    required String target,
    required bool blocked,
    AppPolicyEntry? policy,
  }) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(appPolicyRepositoryProvider);
    final now = DateTime.now().toUtc();
    repository.savePolicy(AppPolicyEntry(
      familyId: widget.familyId,
      childId: '',
      target: target,
      action: blocked ? AppPolicyAction.block : AppPolicyAction.allow,
      ratingMax: policy?.ratingMax ?? 'all',
      syncState: SyncState.queued,
      updatedAt: now,
    ));
    ref.invalidate(appPoliciesProvider(widget.familyId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(blocked
            ? l10n.t('appBlockedNotice')
            : l10n.t('appAllowedNotice'))));
  }
}

class _InstalledAppRow extends StatelessWidget {
  const _InstalledAppRow({
    required this.familyId,
    required this.target,
    required this.usage,
    required this.policy,
    required this.isAllowlisted,
    required this.canManage,
    required this.onTap,
    required this.onToggle,
  });
  final String familyId;
  final String target;
  final DailyUsageSummary usage;
  final AppPolicyEntry? policy;
  final bool isAllowlisted;
  final bool canManage;
  final VoidCallback onTap;
  final void Function(bool blocked) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocked = policy?.action == AppPolicyAction.block;
    final limited = policy?.action == AppPolicyAction.limit;
    final kind = blocked
        ? GuardianStatusKind.alert
        : limited
            ? GuardianStatusKind.watch
            : isAllowlisted
                ? GuardianStatusKind.safe
                : GuardianStatusKind.neutral;
    final label = blocked
        ? l10n.t('blocked')
        : limited
            ? l10n.t('timeLimited')
            : isAllowlisted
                ? l10n.t('trusted')
                : l10n.t('unrestricted');
    return GuardianCard(
      onTap: onTap,
      child: Row(children: [
        GuardianIconBadge(icon: blocked
            ? Icons.block
            : Icons.apps_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(_targetLabel(target),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
                l10n.t('appUsageChip')
                    .replaceAll('{usage}', _formatDuration(usage.totalDuration)),
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        const SizedBox(width: 8),
        GuardianStatusChip(kind: kind, label: label),
        if (canManage)
          IconButton(
            icon: Icon(blocked ? Icons.check_circle_outline : Icons.block),
            color: blocked
                ? GuardianTokens.guardianTeal
                : GuardianTokens.guardianNavy,
            tooltip: blocked ? l10n.t('allowApp') : l10n.t('blockApp'),
            onPressed: () => onToggle(!blocked),
          ),
      ]),
    );
  }
}

// ──────────────────────── AC-003 App Detail & Policy ────────────────────

/// `/apps/:familyId/details/:appId` — AC-003. Per-app policy surface:
/// block/allow/limit toggle, daily time allowance for limit mode, and an
/// honest usage history section built on real usage summaries.
class AppDetailScreen extends ConsumerStatefulWidget {
  const AppDetailScreen(
      {required this.familyId, required this.appTarget, super.key});
  final String familyId;
  final String appTarget;

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailState();
}

class _AppDetailState extends ConsumerState<AppDetailScreen> {
  AppPolicyAction? _pendingAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final policies = ref.watch(appPoliciesProvider(widget.familyId));
    final usage = ref.watch(appUsageForFamilyProvider(widget.familyId));

    if (runtime.hasError || policies.hasError || usage.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appPoliciesProvider(widget.familyId));
              ref.invalidate(appUsageForFamilyProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        policies.isLoading ||
        usage.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewUsage)) {
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
    final canManage = contextValue.can(FamilyPermission.managePolicies);
    final rawPolicy = (policies.valueOrNull ?? const [])
        .firstWhere((p) => p.target == widget.appTarget,
            orElse: NoAppPolicy.new);
    final policy = rawPolicy is NoAppPolicy ? null : rawPolicy;
    final usageEntry = (usage.valueOrNull ?? const [])
        .firstWhere((u) => u.target == widget.appTarget);
    final action = _pendingAction ?? policy?.action ?? AppPolicyAction.allow;
    final timeAllowance = policy?.timeAllowance ??
        const Duration(minutes: 60);
    final syncState = policy?.syncState ?? SyncState.localOnly;

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GuardianIconBadge(
                      icon: Icons.apps_outlined,
                      background: Colors.white24,
                      foreground: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_targetLabel(widget.appTarget),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 10),
                GuardianStatTile(
                    icon: Icons.timer_outlined,
                    value: _formatDuration(usageEntry.totalDuration),
                    label: l10n.t('usageToday'),
                    kind: usageEntry.totalDuration.inMinutes > 0
                        ? GuardianStatusKind.watch
                        : GuardianStatusKind.neutral),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('policyAction'), children: [
            GuardianCard(
              child: Row(children: [
                Expanded(
                  child: Text(l10n.t('currentAction'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _ActionChip(
                    action: action,
                    onTap: canManage
                        ? () => _chooseAction(context, policy)
                        : null),
              ]),
            ),
          ]),
          if (action == AppPolicyAction.limit) ...[
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('dailyAllowance'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(l10n.t('dailyTimeLimit'),
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        padding: EdgeInsets.zero,
                        onPressed: canManage
                            ? () => _adjustAllowance(context, -15)
                            : null,
                      ),
                      Text(_formatDuration(timeAllowance),
                          style:
                              Theme.of(context).textTheme.titleSmall),
                      IconButton(
                        icon: const Icon(Icons.add),
                        padding: EdgeInsets.zero,
                        onPressed: canManage
                            ? () => _adjustAllowance(context, 15)
                            : null,
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ],
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('syncEvidence'), children: [
            GuardianCard(
              child: Row(children: [
                Expanded(
                  child: Text(l10n.t('policySyncState'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                GuardianStatusChip(
                    kind: syncState == SyncState.synced
                        ? GuardianStatusKind.safe
                        : syncState == SyncState.failed
                            ? GuardianStatusKind.alert
                            : GuardianStatusKind.offline,
                    label: l10n.t('syncStateLabel')
                        .replaceAll('{state}', syncState.name)),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  void _chooseAction(BuildContext context, AppPolicyEntry? policy) {
    final l10n = AppLocalizations.of(context);
    final active =
        _pendingAction ?? policy?.action ?? AppPolicyAction.allow;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(l10n.t('choosePolicyAction')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogOption(
                  icon: Icons.block,
                  label: l10n.t('blockApp'),
                  selected: active == AppPolicyAction.block,
                  onTap: () =>
                      _commitAction(AppPolicyAction.block, dialogContext)),
              _DialogOption(
                  icon: Icons.timer_outlined,
                  label: l10n.t('timeLimited'),
                  selected: active == AppPolicyAction.limit,
                  onTap: () =>
                      _commitAction(AppPolicyAction.limit, dialogContext)),
              _DialogOption(
                  icon: Icons.check_circle_outline,
                  label: l10n.t('allowApp'),
                  selected: active == AppPolicyAction.allow,
                  onTap: () =>
                      _commitAction(AppPolicyAction.allow, dialogContext)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel')),
            ),
          ],
        ),
      ),
    );
  }

  void _commitAction(AppPolicyAction action, BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    setState(() => _pendingAction = action);
    final repository = ref.read(appPolicyRepositoryProvider);
    repository.savePolicy(AppPolicyEntry(
      familyId: widget.familyId,
      childId: '',
      target: widget.appTarget,
      action: action,
      timeAllowance: action == AppPolicyAction.limit
          ? (const Duration(minutes: 60))
          : null,
      ratingMax: 'all',
      syncState: SyncState.queued,
      updatedAt: DateTime.now().toUtc(),
    ));
    ref.invalidate(appPoliciesProvider(widget.familyId));
  }

  void _adjustAllowance(BuildContext context, int deltaMinutes) {
    final repository = ref.read(appPolicyRepositoryProvider);
    final policies = ref.read(appPoliciesProvider(widget.familyId));
    final policy = (policies.valueOrNull ?? const [])
        .firstWhere((p) => p.target == widget.appTarget);
    final base = policy.timeAllowance ?? const Duration(minutes: 60);
    final next = base + Duration(minutes: deltaMinutes);
    if (next.inMinutes < 5 || next.inHours > 12) return;
    repository.savePolicy(AppPolicyEntry(
      familyId: widget.familyId,
      childId: '',
      target: widget.appTarget,
      action: AppPolicyAction.limit,
      timeAllowance: next,
      ratingMax: 'all',
      syncState: SyncState.queued,
      updatedAt: DateTime.now().toUtc(),
    ));
    ref.invalidate(appPoliciesProvider(widget.familyId));
  }
}

/// Sentinel entry used when no policy exists yet; a real "no policy"
/// empty state renders instead of fabricating a default policy.
/// Non-const: Dart has no const `DateTime`, so this is a plain runtime
/// object — callers must not use it in const contexts.
class NoAppPolicy extends AppPolicyEntry {
  NoAppPolicy()
      : super(
            familyId: '',
            childId: '',
            target: '',
            action: AppPolicyAction.allow,
            ratingMax: 'all',
            syncState: SyncState.localOnly,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0));
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action, this.onTap});
  final AppPolicyAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final IconData icon;
    final String label;
    final Color color;
    if (action == AppPolicyAction.block) {
      icon = Icons.block;
      label = l10n.t('blocked');
      color = GuardianTokens.guardianNavy;
    } else if (action == AppPolicyAction.limit) {
      icon = Icons.timer_outlined;
      label = l10n.t('timeLimited');
      color = GuardianTokens.guardianTeal;
    } else {
      icon = Icons.check_circle_outline;
      label = l10n.t('allowed');
      color = Colors.grey;
    }
    return ActionChip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      backgroundColor: color,
      label: Text(label, style: const TextStyle(color: Colors.white)),
      onPressed: onTap,
    );
  }
}

class _DialogOption extends StatelessWidget {
  const _DialogOption(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon,
            color: selected
                ? GuardianTokens.guardianTeal
                : GuardianTokens.guardianNavy),
        title: Text(label),
        trailing:
            selected ? const Icon(Icons.check, color: GuardianTokens.guardianTeal) : null,
        onTap: onTap,
      );
}

// ───────────────────────── AC-004 App Allowlist ────────────────────────

/// `/apps/:familyId/allowlist` — AC-004. Trusted apps that are never
/// blocked regardless of family mode. Add with a reason (honest audit),
/// remove with a recorded history event.
class AppAllowlistScreen extends ConsumerStatefulWidget {
  const AppAllowlistScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<AppAllowlistScreen> createState() =>
      _AppAllowlistScreenState();
}

class _AppAllowlistScreenState extends ConsumerState<AppAllowlistScreen> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final allowlist = ref.watch(appAllowlistProvider(widget.familyId));

    if (runtime.hasError || allowlist.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appAllowlistProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        allowlist.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewPolicies)) {
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
    final entries = allowlist.valueOrNull ?? const [];
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(children: [
              GuardianIconBadge(
                  icon: Icons.verified_user_outlined,
                  background: Colors.white24,
                  foreground: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('appAllowlist'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(l10n.t('appAllowlistSummary'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            GuardianCard(
              child: Column(children: [
                GuardianIconBadge(icon: Icons.folder_off_outlined,
                    size: 40),
                const SizedBox(height: 12),
                Text(l10n.t('noTrustedApps'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(l10n.t('noTrustedAppsDescription'),
                    style: Theme.of(context).textTheme.bodySmall),
                if (canManage) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.t('addTrustedApp')),
                  ),
                ],
              ]),
            ),
          for (final entry in entries) ...[
            GuardianCard(
              child: Row(children: [
                GuardianIconBadge(icon: Icons.verified_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_targetLabel(entry.target),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(entry.reason.isEmpty
                        ? l10n.t('noReasonGiven')
                        : entry.reason,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                if (canManage)
                  IconButton(
                  icon: const Icon(Icons.close,
                      color: GuardianTokens.guardianNavy),
                  padding: EdgeInsets.zero,
                  tooltip: l10n.t('removeFromAllowlist'),
                    onPressed: () {
                      ref
                          .read(appPolicyRepositoryProvider)
                          .removeFromAllowlist(
                              widget.familyId, entry.target);
                      ref.invalidate(
                          appAllowlistProvider(widget.familyId));
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          if (entries.isNotEmpty && canManage) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.t('addTrustedApp')),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _targetController.clear();
    _reasonController.clear();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(l10n.t('addTrustedApp')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _targetController,
              decoration: InputDecoration(
                hintText: l10n.t('appTargetHint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: l10n.t('trustReasonHint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                final target = _targetController.text.trim();
                if (target.isEmpty) return;
                Navigator.of(dialogContext).pop();
                final repository =
                    ref.read(appPolicyRepositoryProvider);
                final binding = ref
                    .read(familyActorBindingProvider(widget.familyId))
                    .valueOrNull
                    ?.binding;
                repository.addToAllowlist(AppAllowlistEntry(
                  familyId: widget.familyId,
                  target: target,
                  reason: _reasonController.text.trim(),
                  addedBy: binding?.member.id ?? 'parent',
                  createdAt: DateTime.now().toUtc(),
                ));
                ref.invalidate(appAllowlistProvider(widget.familyId));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.t('trustAddedNotice'))));
              },
              child: Text(l10n.t('addTrustedAppAction')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── AC-005 Per-Child App Rules ────────────────────────

/// `/apps/:familyId/:childId/rules` — AC-005. Child-scoped usage allowances
/// and app rules. Written to the same policy store with the child id set,
/// so enforcement agents match the most specific rule first.
class PerChildAppRulesScreen extends ConsumerStatefulWidget {
  const PerChildAppRulesScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  ConsumerState<PerChildAppRulesScreen> createState() =>
      _PerChildAppRulesState();
}

class _PerChildAppRulesState extends ConsumerState<PerChildAppRulesScreen> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final policies = ref.watch(appPoliciesProvider(widget.familyId));
    final alerts = ref.watch(usageAlertSettingsProvider(widget.familyId));

    if (runtime.hasError || policies.hasError || alerts.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appPoliciesProvider(widget.familyId));
              ref.invalidate(
                  usageAlertSettingsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        policies.isLoading ||
        alerts.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewUsage)) {
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
    final canManage = contextValue.can(FamilyPermission.managePolicies);
    final policyList =
        (policies.valueOrNull ?? const []).where(
            (p) => p.childId == widget.childId).toList();
    final alertList = (alerts.valueOrNull ?? const [])
        .where((a) => a.childId == widget.childId)
        .toList();
    final child = contextValue.children
        .firstWhere((m) => m.id == widget.childId,
            orElse: () => contextValue.children.first);

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(children: [
              GuardianIconBadge(
                  icon: Icons.child_care_outlined,
                  background: Colors.white24,
                  foreground: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('perChildRules'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(child.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('childAppPolicies'), children: [
            if (policyList.isEmpty)
              GuardianCard(
                child: Column(children: [
                  GuardianIconBadge(icon: Icons.info_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.t('noChildRules'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l10n.t('noChildRulesDescription'),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            for (final policy in policyList)
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: policy.action ==
                          AppPolicyAction.block
                      ? Icons.block
                      : Icons.timer_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_targetLabel(policy.target),
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                          policy.timeAllowance != null
                              ? l10n.t('limitChip').replaceAll('{limit}',
                                  _formatDuration(policy.timeAllowance!))
                              : l10n.t('actionChip')
                                  .replaceAll('{action}',
                                      _actionLabel(l10n, policy.action)),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  GuardianStatusChip(
                      kind: policy.syncState == SyncState.synced
                          ? GuardianStatusKind.safe
                          : GuardianStatusKind.offline,
                      label: policy.syncState.name),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('usageAlerts'), children: [
            if (alertList.isEmpty)
              GuardianCard(
                child: Column(children: [
                  GuardianIconBadge(
                      icon: Icons.notifications_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.t('noAlertsConfigured'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l10n.t('noAlertsConfiguredDescription'),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            for (final setting in alertList)
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(
                      icon: setting.enabled
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_paused_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_targetLabel(setting.target),
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                          l10n.t('alertThresholdChip').replaceAll(
                              '{threshold}',
                              _formatDuration(setting.threshold)),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  Switch(
                    value: setting.enabled,
                    activeTrackColor: GuardianTokens.guardianTeal,
                    onChanged: canManage
                        ? (enabled) {
                            ref
                                .read(appPolicyRepositoryProvider)
                                .saveAlertSetting(UsageAlertSetting(
                                  familyId: widget.familyId,
                                  childId: widget.childId,
                                  target: setting.target,
                                  threshold: setting.threshold,
                                  enabled: enabled,
                                  updatedAt: DateTime.now().toUtc(),
                                ));
                            ref.invalidate(
                                usageAlertSettingsProvider(
                                    widget.familyId));
                          }
                        : null,
                  ),
                ]),
              ),
          ]),
        ],
      ),
    );
  }

  String _actionLabel(AppLocalizations l10n, AppPolicyAction action) =>
      switch (action) {
        AppPolicyAction.block => l10n.t('blocked'),
        AppPolicyAction.limit => l10n.t('timeLimited'),
        AppPolicyAction.allow => l10n.t('allowed'),
      };
}

// ────────────────────── AC-006 Usage Alerts Settings ───────────────────

/// `/apps/:familyId/alerts` — AC-006. Family-wide per-app usage alert
/// thresholds. Honest evidence: only apps with real usage data can be
/// configured, and each save is a local-first write queued for sync.
class UsageAlertsScreen extends ConsumerStatefulWidget {
  const UsageAlertsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<UsageAlertsScreen> createState() =>
      _UsageAlertsScreenState();
}

class _UsageAlertsScreenState extends ConsumerState<UsageAlertsScreen> {

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final usage = ref.watch(appUsageForFamilyProvider(widget.familyId));
    final alerts = ref.watch(usageAlertSettingsProvider(widget.familyId));

    if (runtime.hasError || usage.hasError || alerts.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appUsageForFamilyProvider(widget.familyId));
              ref.invalidate(
                  usageAlertSettingsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        usage.isLoading ||
        alerts.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewUsage)) {
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
    final canManage = contextValue.can(FamilyPermission.managePolicies);
    final usageList = usage.valueOrNull ?? const [];
    final alertList = alerts.valueOrNull ?? const [];
    final settingsByTarget = {
      for (final a in alertList) a.target: a,
    };

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(children: [
              GuardianIconBadge(
                  icon: Icons.notifications_active_outlined,
                  background: Colors.white24,
                  foreground: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('usageAlerts'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(l10n.t('usageAlertsSummary'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (usageList.isEmpty)
            GuardianCard(
                child: Column(children: [
                  GuardianIconBadge(icon: Icons.cloud_off_outlined),
                  const SizedBox(height: 12),
                  Text(l10n.t('noUsageData'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(l10n.t('noUsageDataDescription'),
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          for (final u in usageList)
            GuardianCard(
              onTap: null,
              child: Row(children: [
                GuardianIconBadge(icon: Icons.apps_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_targetLabel(u.target),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(_formatDuration(u.totalDuration),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                if (settingsByTarget[u.target] != null)
                  GuardianStatusChip(
                      kind: GuardianStatusKind.safe,
                      label: l10n.t('alertSet')),
                if (canManage)
                  const Icon(Icons.chevron_right,
                      color: GuardianTokens.guardianTeal),
              ]),
            ),
        ],
      ),
    );
  }
}

// ────────────────────── AC-007 App Block History ───────────────────────

/// `/apps/:familyId/history` — AC-007. Honest audit log of every app
/// enforcement event the family recorded. Written alongside every policy
/// mutation, so the log can never be more generous than reality.
class AppBlockHistoryScreen extends ConsumerStatefulWidget {
  const AppBlockHistoryScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<AppBlockHistoryScreen> createState() =>
      _AppBlockHistoryState();
}

class _AppBlockHistoryState extends ConsumerState<AppBlockHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final events = ref.watch(appBlockEventsProvider(widget.familyId));

    if (runtime.hasError || events.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appBlockEventsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || events.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewPolicies)) {
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
    final eventList = events.valueOrNull ?? const [];
    if (eventList.isEmpty) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('noBlockEvents'),
            message: l10n.t('noBlockEventsDescription'),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Row(children: [
              GuardianIconBadge(
                  icon: Icons.history_outlined,
                  background: Colors.white24,
                  foreground: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.t('appBlockHistory'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          for (final event in eventList)
            GuardianCard(
              child: Row(children: [
                GuardianIconBadge(
                    icon: event.eventType == AppBlockEventType.block
                        ? Icons.block
                        : event.eventType == AppBlockEventType.unblock
                            ? Icons.check_circle_outline
                            : event.eventType == AppBlockEventType.override
                                ? Icons.flash_on_outlined
                                : event.eventType == AppBlockEventType.timeout
                                    ? Icons.timer_outlined
                                    : event.eventType ==
                                            AppBlockEventType
                                                .addedToAllowlist
                                        ? Icons.verified_user_outlined
                                        : Icons.verified_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_targetLabel(event.target),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                        l10n.t('eventTypeLabel').replaceAll(
                            '{event}', _eventTypeKey(event.eventType)),
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
                Text(
                    '${event.createdAt.day}/${event.createdAt.month}/${event.createdAt.year}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
        ],
      ),
    );
  }

  String _eventTypeKey(AppBlockEventType type) {
    switch (type) {
      case AppBlockEventType.block:
        return 'block';
      case AppBlockEventType.unblock:
        return 'unblock';
      case AppBlockEventType.override:
        return 'override';
      case AppBlockEventType.timeout:
        return 'timeout';
      case AppBlockEventType.addedToAllowlist:
        return 'addedToAllowlist';
      case AppBlockEventType.removedFromAllowlist:
        return 'removedFromAllowlist';
    }
  }
}

// ──────────────── AC-008 Child App Usage View (self-scope) ─────────────

/// `/child/:familyId/:childId/apps` — AC-008. What the child sees about
/// their own app rules: read-only applied rules plus a single exception
/// request CTA. The screen verifies `actor.id == childId` — a parent
/// opening this path receives an honest authorization failure instead of
/// leaked policy detail.
class ChildAppUsageScreen extends ConsumerStatefulWidget {
  const ChildAppUsageScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  ConsumerState<ChildAppUsageScreen> createState() =>
      _ChildAppUsageState();
}

class _ChildAppUsageState extends ConsumerState<ChildAppUsageScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final policies = ref.watch(appPoliciesProvider(widget.familyId));
    final usage = ref.watch(appUsageForFamilyProvider(widget.familyId));

    if (runtime.hasError || policies.hasError || usage.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('appControlSyncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(
                  familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(appPoliciesProvider(widget.familyId));
              ref.invalidate(appUsageForFamilyProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        policies.isLoading ||
        usage.isLoading) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    // Fail-closed: only the child themselves may open this view.
    final actorId = contextValue.actor?.id;
    if (actorId == null || actorId != widget.childId) {
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
    final policyList = (policies.valueOrNull ?? const [])
        .where((p) =>
            p.childId == widget.childId || p.childId.isEmpty)
        .where((p) => p.action != AppPolicyAction.allow)
        .toList();
    final usageList = usage.valueOrNull ?? const [];
    final usageByTarget = {for (final u in usageList) u.target: u};

    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GuardianIconBadge(
                      icon: Icons.phone_android_outlined,
                      background: Colors.white24,
                      foreground: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('myAppRules'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(l10n.t('myAppRulesDescription'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GuardianSection(title: l10n.t('appliedRules'), children: [
            if (policyList.isEmpty)
              GuardianCard(
                child: Column(children: [
                  GuardianIconBadge(
                      icon: Icons.sentiment_satisfied_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.t('noRulesApplied'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l10n.t('noRulesAppliedDescription'),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            for (final policy in policyList)
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: policy.action ==
                          AppPolicyAction.block
                      ? Icons.block
                      : Icons.timer_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_targetLabel(policy.target),
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                          policy.timeAllowance != null
                              ? l10n.t('limitChip').replaceAll('{limit}',
                                  _formatDuration(policy.timeAllowance!))
                              : _actionLabel(l10n, policy.action),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  ),
                  if (usageByTarget[policy.target] != null)
                    Text(
                        _formatDuration(
                            usageByTarget[policy.target]!.totalDuration),
                        style: Theme.of(context).textTheme.labelSmall),
                ]),
              ),
          ]),
          const SizedBox(height: 16),
          GuardianCard(
            child: Row(children: [
              GuardianIconBadge(icon: Icons.help_outline),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l10n.t('exceptionRequestCta'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(l10n.t('exceptionRequestDescription'),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _actionLabel(AppLocalizations l10n, AppPolicyAction action) =>
      switch (action) {
        AppPolicyAction.block => l10n.t('blocked'),
        AppPolicyAction.limit => l10n.t('timeLimited'),
        AppPolicyAction.allow => l10n.t('allowed'),
      };
}
