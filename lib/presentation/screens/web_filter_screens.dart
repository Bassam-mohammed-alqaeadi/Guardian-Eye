import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/web_filter_repository.dart';
import '../../domain/guardian_models.dart';
import '../../domain/web_filtering/web_filter_categories.dart';
import '../widgets/guardian_primitives.dart';
import '../../application/family_context_provider.dart';

/// FS-002 — Web Filtering screens (WF-001 … WF-010).
///
/// One file, ten screens, same visual grammar as every other subsystem:
/// `GuardianHeroCard` header, `GuardianSection` + `GuardianCard` rows,
/// `GuardianStatTile` / `GuardianStatusChip` / `GuardianIconBadge`,
/// honest `GuardianStateView` bodies, and `FamilyRuntimeContext.can()`
/// as the only authorization gate. Everything writes through
/// `WebFilterRepository`, which is local-first like every other feature
/// in the platform.

// ───────────────────────── WF-001 Web Filtering Dashboard ─────────────────

/// `/safety/web/:familyId` — WF-001. The parent opens web protection
/// from here: protection level hero, today's honest block count,
/// per-child status, and the three administrative destinations.
class WebFilterDashboardScreen extends ConsumerStatefulWidget {
  const WebFilterDashboardScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebFilterDashboardScreen> createState() =>
      _WebFilterDashboardState();
}

class _WebFilterDashboardState extends ConsumerState<WebFilterDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final hits = ref.watch(webHitsProvider(widget.familyId));
    final domains = ref.watch(webDomainsProvider(widget.familyId));

    if (runtime.hasError || hits.hasError) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(familyRuntimeContextProvider(widget.familyId));
              ref.invalidate(webHitsProvider(widget.familyId));
              ref.invalidate(webDomainsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null ||
        runtime.isLoading ||
        hits.isLoading ||
        domains.isLoading) {
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
    if (children.isEmpty) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('noChildren'),
            message: l10n.t('noChildrenForWeb'),
          ),
        ),
      );
    }

    final blockedToday = hits.valueOrNull
        ?.where((hit) => hit.decision == 'blocked')
        .length ?? 0;
    final blockedDomains = domains.valueOrNull
            ?.where((domain) => domain.kind == 'block' && domain.enabled)
            .length ??
        0;
    final protectionEnabled = blockedDomains > 0 || blockedToday > 0;
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(webHitsProvider(widget.familyId));
        ref.invalidate(webDomainsProvider(widget.familyId));
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
                          icon: Icons.lan_outlined,
                          background: Colors.white24,
                          foreground: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l10n.t('webFilteringDashboard'),
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
                          value: '$blockedToday',
                          label: l10n.t('blockedToday'),
                          kind: blockedToday > 0
                              ? GuardianStatusKind.watch
                              : GuardianStatusKind.safe),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GuardianStatTile(
                          icon: Icons.shield_outlined,
                          value: '$blockedDomains',
                          label: l10n.t('blockedSites'),
                          kind: protectionEnabled
                              ? GuardianStatusKind.safe
                              : GuardianStatusKind.offline),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(l10n.t('webProtectionSummary'),
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
                      onTap: () => GoRouter.of(context).push(
                          '/safety/web/${widget.familyId}/${children.first.id}'),
                      child: Text(l10n.t('perChildPolicy'),
                          style: TextStyle(
                              color: GuardianTokens.guardianTeal,
                              fontWeight: FontWeight.w600)),
                    )
                  : null,
              children: [
                for (final child in children)
                  _ChildProtectionTile(
                      familyId: widget.familyId,
                      child: child,
                      hits: hits.valueOrNull ?? const [],
                      onTap: () => GoRouter.of(context).push(
                          '/safety/web/${widget.familyId}/${child.id}')),
              ],
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('contentCategories'), children: [
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/safety/web/${widget.familyId}/categories')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.category_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('contentCategories'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('categoriesDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right, color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/safety/web/${widget.familyId}/blocklist')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.block_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('blockedSites'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('blockedSitesDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right, color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/safety/web/${widget.familyId}/history')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.history_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('blockHistory'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('blockHistoryDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right, color: GuardianTokens.guardianTeal),
                ]),
              ),
              GuardianCard(
                onTap: canManage
                    ? () => context
                        .push('/safety/web/${widget.familyId}/settings')
                    : null,
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.tune_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('webSettings'),
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(l10n.t('webSettingsDescription'),
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                  if (canManage)
                    const Icon(Icons.chevron_right, color: GuardianTokens.guardianTeal),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Per-child protection tile inside the web dashboard (WF-001).
/// Reads the child's block hits locally; "not protected" is shown
/// honestly — never inferred as protected.
class _ChildProtectionTile extends StatelessWidget {
  const _ChildProtectionTile({
    required this.familyId,
    required this.child,
    required this.hits,
    required this.onTap,
  });
  final String familyId;
  final FamilyMember child;
  final List<WebBlockHit> hits;
  final VoidCallback onTap;

  int _childBlocks(FamilyMember child) =>
      hits.where((hit) => hit.childId == child.id && hit.decision == 'blocked').length;

  String _status(AppLocalizations l10n) {
    final blocks = _childBlocks(child);
    if (blocks == 0) return l10n.t('childProtectionOn');
    if (blocks < 3) return l10n.t('childProtectionPartial');
    return l10n.t('childProtectionOff');
  }

  GuardianStatusKind _kind() {
    final blocks = _childBlocks(child);
    if (blocks == 0) return GuardianStatusKind.safe;
    if (blocks < 3) return GuardianStatusKind.watch;
    return GuardianStatusKind.alert;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      onTap: onTap,
      child: Row(children: [
        GuardianIconBadge(icon: Icons.child_care_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.displayName,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                  l10n.t('hitBlockedFor').replaceAll('%s', child.displayName),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        GuardianStatusChip(label: _status(l10n), kind: _kind()),
      ]),
    );
  }
}

// ────────────────────────── WF-002 Content Categories ──────────────────────

/// `/safety/web/:familyId/categories` — WF-002. Category groups
/// (sensitive / age / social) with a per-child rule matrix. Every
/// change enqueues through the honest outbox rhythm.
class WebFilterCategoriesScreen extends ConsumerStatefulWidget {
  const WebFilterCategoriesScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebFilterCategoriesScreen> createState() =>
      _WebFilterCategoriesState();
}

class _WebFilterCategoriesState
    extends ConsumerState<WebFilterCategoriesScreen> {
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(webDomainsProvider(widget.familyId).future);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String category, String childId,
      String childDisplayName, bool enabled) async {
    final repository = ref.read(webFilterRepositoryProvider);
    try {
      await repository.setCategoryRule(
          familyId: widget.familyId,
          childId: childId,
          childDisplayName: childDisplayName,
          category: category,
          enabled: enabled);
      if (!mounted) return;
      ref.invalidate(webFilterRepositoryProvider);
      _message(AppLocalizations.of(context).t('webPolicySaved'));
    } catch (error) {
      if (!mounted) return;
      _message(AppLocalizations.of(context).t('somethingWentWrong'));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));

    if (!runtime.isLoading &&
        (runtime.hasError || _error != null || _loading)) {
      return Scaffold(
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: _load,
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null) {
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
    final children = contextValue.children;
    final rules = ref.watch(_webRulesProvider(widget.familyId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('contentCategories'))),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_webRulesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GuardianHeroCard(
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.category_outlined,
                      background: Colors.white24,
                      foreground: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('categoriesDescription'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              for (final group in WebFilterCategories.groups) ...[
                GuardianSection(
                  title: WebFilterCategories.groupLabel(l10n, group),
                  children: [
                    for (final category
                        in WebFilterCategories.ofGroup(group))
                      _CategoryCard(
                          category: category,
                          children: children,
                          rules: rules.valueOrNull ?? const [],
                          onToggle: _toggle),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// FutureProvider keyed by (familyId, child ids) — keeps the category
/// screen reactive to runtime member changes without re-querying
/// providers per row.
final _webRulesProvider = FutureProvider.family<List<WebCategoryRule>, String>(
    (ref, String familyId) async {
  final runtime = await ref.watch(familyRuntimeContextProvider(familyId).future);
  final repository = ref.watch(webFilterRepositoryProvider);
  final children = runtime.children;
  return repository.rulesForFamily(familyId,
      children: children.map((child) => child.id),
      categories: WebFilterCategories.all.map((category) => category.key));
});

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.children,
    required this.rules,
    required this.onToggle,
  });
  final WebFilterCategory category;
  final List<FamilyMember> children;
  final List<WebCategoryRule> rules;
  final void Function(String category, String childId,
      String childDisplayName, bool enabled) onToggle;

  int _enabledCount(String category) => rules
      .where((rule) => rule.category == category && rule.enabled)
      .length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabledCount = _enabledCount(category.key);
    final totalChildren = children.length;
    return GuardianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GuardianIconBadge(icon: _iconOf(category.icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.label(l10n),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(category.description(l10n),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          for (final child in children)
            Row(children: [
              Expanded(
                child: Text(child.displayName,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Switch.adaptive(
                value: rules
                    .where((rule) =>
                        rule.category == category.key &&
                        rule.childId == child.id)
                    .fold(true, (enabled, rule) => rule.enabled),
                activeColor: GuardianTokens.guardianTeal,
                onChanged: (enabled) =>
                    onToggle(category.key, child.id, child.displayName, enabled),
              ),
            ]),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.t('categoryEnabledFor').replaceAll('%d', '$enabledCount').replaceAll('%s', '$totalChildren'),
                  style: Theme.of(context).textTheme.bodySmall),
              GuardianStatusChip(
                  label: enabledCount == 0
                      ? l10n.t('categoryDisabled')
                      : enabledCount == totalChildren
                          ? l10n.t('webProtectionStatus')
                          : l10n.t('childProtectionPartial'),
                  kind: enabledCount == 0
                      ? GuardianStatusKind.offline
                      : enabledCount == totalChildren
                          ? GuardianStatusKind.safe
                          : GuardianStatusKind.watch),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconOf(String iconName) {
    final known = <String, IconData>{
      '18_plus': Icons.abc,
      'casino_outlined': Icons.casino_outlined,
      'gpp_bad_outlined': Icons.gpp_bad_outlined,
      'vaccines_outlined': Icons.vaccines_outlined,
      'warning_amber_outlined': Icons.warning_amber_outlined,
      'record_voice_over_outlined': Icons.record_voice_over_outlined,
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'psychology_outlined': Icons.psychology_outlined,
      'favorite_border': Icons.favorite_border,
      'sports_esports_outlined': Icons.sports_esports_outlined,
      'movie_outlined': Icons.movie_outlined,
      'forum_outlined': Icons.forum_outlined,
    };
    return known[iconName] ?? Icons.category_outlined;
  }
}
