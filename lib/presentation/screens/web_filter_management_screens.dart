import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/web_filter_repository.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';
import '../../application/family_context_provider.dart';

/// FS-002 — Web Filtering management screens (WF-003, WF-004, WF-005,
/// WF-006). Blocklist + trusted allowlist, family web settings, the
/// honest block history, and per-hit detail. Every mutation flows
/// through `WebFilterRepository`'s local-first outbox rhythm.

// ────────────────────────── WF-003 Website Blocklist ──────────────────────

/// `/safety/web/:familyId/blocklist` — WF-003. Parent-managed blocked
/// domains with an add sheet and honest empty state.
class WebBlocklistScreen extends ConsumerStatefulWidget {
  const WebBlocklistScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebBlocklistScreen> createState() =>
      _WebBlocklistScreenState();
}

class _WebBlocklistScreenState extends ConsumerState<WebBlocklistScreen> {
  Object? _error;

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await ref.read(webDomainsProvider(widget.familyId).future);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _addDomain() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final reason = TextEditingController();
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 24),
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.t('addDomain'),
                          style:
                              Theme.of(sheetContext).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                          controller: controller,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: l10n.t('domain'),
                              hintText: l10n.t('domainHint'))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: reason,
                          decoration:
                              InputDecoration(labelText: l10n.t('reason'))),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final domain = controller.text.trim();
                            if (!_looksLikeDomain(domain)) {
                              _message(l10n.t('domainMustBeValid'));
                              return;
                            }
                            final repository =
                                ref.read(webFilterRepositoryProvider);
                            try {
                              await repository.addDomain(
                                  familyId: widget.familyId,
                                  domain: domain,
                                  kind: 'block',
                                  reason: reason.text.trim().isEmpty
                                      ? null
                                      : reason.text.trim());
                              if (!mounted) return;
                              ref.invalidate(
                                  webDomainsProvider(widget.familyId));
                              Navigator.of(sheetContext).pop();
                              _message(l10n.t('webPolicySaved'));
                            } catch (_) {
                              _message(l10n.t('somethingWentWrong'));
                            }
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: GuardianTokens.guardianNavy),
                          child: Text(l10n.t('addDomain')),
                        ),
                      ),
                    ]),
                  ),
                )));
  }

  bool _looksLikeDomain(String raw) {
    final normalized = raw.toLowerCase();
    if (normalized.contains(' ') || normalized.contains('/')) return false;
    return normalized.contains('.') && normalized.length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final domains = ref.watch(webDomainsProvider(widget.familyId));

    if (runtime.hasError || domains.hasError || _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockedSites'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(webDomainsProvider(widget.familyId));
              _load();
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || domains.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockedSites'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockedSites'))),
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

    final blocked = (domains.valueOrNull ?? const [])
        .where((entry) => entry.kind == 'block')
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('blockedSites'))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GuardianTokens.guardianTeal,
        foregroundColor: Colors.white,
        onPressed: _addDomain,
        icon: const Icon(Icons.add),
        label: Text(l10n.t('addDomain')),
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(webDomainsProvider(widget.familyId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (blocked.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('noDomainsYet'),
                  message: l10n.t('addFirstDomain'),
                )
              else ...[
                GuardianOfflineBanner(),
                const SizedBox(height: 12),
                for (final entry in blocked)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.block_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.domain,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (entry.reason != null) ...[
                              const SizedBox(height: 2),
                              Text(entry.reason!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () async {
                          final repository =
                              ref.read(webFilterRepositoryProvider);
                          await repository.removeDomain(entry.id);
                          if (!mounted) return;
                          ref.invalidate(
                              webDomainsProvider(widget.familyId));
                          _message(l10n.t('webPolicySaved'));
                        },
                        tooltip: l10n.t('removeDomain'),
                      ),
                    ]),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── WF-004 Web Settings ────────────────────────────

/// `/safety/web/:familyId/settings` — WF-004. Safe search, blocked-page
/// behavior, and child exception-request permission. Settings are
/// family-scoped key/value pairs; the device-side enforcement later
/// consumes the same keys, so the platform keeps one vocabulary.
class WebSettingsScreen extends ConsumerStatefulWidget {
  const WebSettingsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebSettingsScreen> createState() =>
      _WebSettingsScreenState();
}

class _WebSettingsScreenState extends ConsumerState<WebSettingsScreen> {
  Object? _error;

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await ref.read(webSettingsProvider(widget.familyId).future);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _setSetting(String key, String value) async {
    final repository = ref.read(webFilterRepositoryProvider);
    try {
      await repository.setSetting(
          familyId: widget.familyId, key: key, value: value);
      if (!mounted) return;
      ref.invalidate(webSettingsProvider(widget.familyId));
      _message(AppLocalizations.of(context).t('webPolicySaved'));
    } catch (_) {
      if (!mounted) return;
      _message(AppLocalizations.of(context).t('somethingWentWrong'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final settings = ref.watch(webSettingsProvider(widget.familyId));
    final repository = ref.watch(webFilterRepositoryProvider);

    if (runtime.hasError || settings.hasError || _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('webSettings'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(webSettingsProvider(widget.familyId));
              _load();
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || settings.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('webSettings'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('webSettings'))),
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

    final values = settings.valueOrNull ?? const [];
    final safeSearchOn =
        repository.setting(values, 'safe_search', 'on') == 'on';
    final explainBlocks = repository.setting(
            values, 'blocked_page_behavior', 'explain') ==
        'explain';
    final exceptionRequests =
        repository.setting(values, 'exception_requests_allowed', 'on') ==
            'on';

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(webSettingsProvider(widget.familyId)),
      child: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.tune_outlined,
                    background: Colors.white24,
                    foreground: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.t('webSettingsDescription'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GuardianOfflineBanner(),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('safeSearch'), children: [
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.search_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('safeSearch'),
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(l10n.t('safeSearchEnforced'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: safeSearchOn,
                    activeColor: GuardianTokens.guardianTeal,
                    onChanged: (enabled) =>
                        _setSetting('safe_search', enabled ? 'on' : 'off'),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            GuardianSection(title: l10n.t('blockedPageBehavior'), children: [
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('blockedPageBehavior'),
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: explainBlocks
                                  ? null
                                  : () => _setSetting(
                                      'blocked_page_behavior', 'explain'),
                              child: Text(l10n.t('blockedPageExplain')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: explainBlocks
                                  ? () => _setSetting(
                                      'blocked_page_behavior', 'silent')
                                  : null,
                              child: Text(l10n.t('blockedPageSilent')),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            GuardianSection(
                title: l10n.t('exceptionRequestsAllowed'), children: [
              GuardianCard(
                child: Row(children: [
                  GuardianIconBadge(icon: Icons.lock_person_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('exceptionRequestsAllowed'),
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(exceptionRequests
                            ? l10n.t('exceptionRequestsOn')
                            : l10n.t('exceptionRequestsOff'),
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: exceptionRequests,
                    activeColor: GuardianTokens.guardianTeal,
                    onChanged: (enabled) => _setSetting(
                        'exception_requests_allowed',
                        enabled ? 'on' : 'off'),
                  ),
                ]),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── WF-005 Block History ─────────────────────────

/// `/safety/web/:familyId/history` — WF-005. The honest block log:
/// each row is an observed child-device event. Empty means nothing was
/// blocked — a healthy day, shown truthfully.
class WebBlockHistoryScreen extends ConsumerStatefulWidget {
  const WebBlockHistoryScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebBlockHistoryScreen> createState() =>
      _WebBlockHistoryState();
}

class _WebBlockHistoryState extends ConsumerState<WebBlockHistoryScreen> {
  String? _filterChildId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final hits = ref.watch(webHitsProvider(widget.familyId));

    if (runtime.hasError || hits.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(webHitsProvider(widget.familyId));
            },
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (contextValue == null || runtime.isLoading || hits.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.viewPolicies)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
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

    final allHits = hits.valueOrNull ?? const [];
    final filtered = _filterChildId == null
        ? allHits
        : allHits.where((hit) => hit.childId == _filterChildId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('blockHistory'))),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(webHitsProvider(widget.familyId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (contextValue.children.length > 1) ...[
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: contextValue.children.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final child = index == 0
                          ? null
                          : contextValue.children[index - 1];
                      final selected =
                          child == null || child.id == _filterChildId;
                      return ChoiceChip(
                        label: Text(
                            child?.displayName ?? l10n.t('everyChild')),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _filterChildId = child?.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (filtered.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('blockHitsEmpty'),
                )
              else
                for (final hit in filtered)
                  GuardianCard(
                    onTap: () => GoRouter.of(context).push(
                        '/safety/web/${widget.familyId}/history/${hit.id}'),
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.block_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(hit.domain,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                                '${hit.childDisplayName} · '
                                '${_timeOf(l10n, hit.blockedAt)}',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      GuardianStatusChip(
                          label: hit.overriddenBy != null
                              ? l10n.t('hitOverridden')
                              : l10n.t('hitBlockedFor')
                                  .replaceAll('%s', hit.childDisplayName),
                          kind: hit.overriddenBy != null
                              ? GuardianStatusKind.pro
                              : GuardianStatusKind.alert),
                    ]),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeOf(AppLocalizations l10n, DateTime moment) {
    final local = moment.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ──────────────────────────── WF-006 Block Hit Detail ──────────────────────

/// `/safety/web/:familyId/history/:hitId` — WF-006. One observed block
/// event with the parent's honest options: keep it blocked, allow once
/// (with the override stamped on the hit, never hidden from history),
/// or continue to WF-007's timed allowance.
class WebBlockHitDetailScreen extends ConsumerStatefulWidget {
  const WebBlockHitDetailScreen(
      {required this.familyId, required this.hitId, super.key});
  final String familyId;
  final String hitId;

  @override
  ConsumerState<WebBlockHitDetailScreen> createState() =>
      _WebBlockHitDetailState();
}

class _WebBlockHitDetailState
    extends ConsumerState<WebBlockHitDetailScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await ref.read(webFilterRepositoryProvider).hitById(widget.hitId);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hit = ref.watch(_hitProvider('${widget.familyId}|${widget.hitId}'));

    if (hit.hasError || _error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () {
              ref.invalidate(_hitProvider);
              _load();
            },
          ),
        ),
      );
    }
    final hitValue = hit.valueOrNull;
    if (hit.isLoading || hitValue == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    if (runtime.valueOrNull != null &&
        !runtime.valueOrNull!.can(FamilyPermission.managePolicies)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('blockHistory'))),
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
      appBar: AppBar(title: Text(l10n.t('blockHistory'))),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianHeroCard(
              child: Row(children: [
                GuardianIconBadge(
                    icon: Icons.block_outlined,
                    background: Colors.white24,
                    foreground: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(hitValue.domain,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GuardianSection(title: l10n.t('blockedPageRule'), children: [
              GuardianCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(Icons.child_care_outlined,
                        hitValue.childDisplayName),
                    _DetailRow(Icons.category_outlined, hitValue.category),
                    _DetailRow(Icons.schedule_outlined,
                        hitValue.blockedAt.toLocal().toString()),
                    _DetailRow(Icons.sync_outlined,
                        hitValue.syncState.name),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (hitValue.overriddenBy == null) ...[
              FilledButton(
                onPressed: () async {
                  final repository = ref.read(webFilterRepositoryProvider);
                  final actor =
                      runtime.valueOrNull?.actor?.displayName ?? 'parent';
                  await repository.markOverridden(hitValue.id, actor);
                  if (!mounted) return;
                  ref.invalidate(
                      _hitProvider);
                  ref.invalidate(
                      webHitsProvider(widget.familyId));
                  _message(l10n.t('allowedTemporarily'));
                },
                style: FilledButton.styleFrom(backgroundColor: GuardianTokens.guardianTeal),
                child: Text(l10n.t('allowOnce')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => GoRouter.of(context).push(
                    '/safety/web/${widget.familyId}/history/${hitValue.id}/allow'),
                child: Text(l10n.t('temporaryAllow')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.t('keepBlocked')),
              ),
            ] else
              GuardianStatusChip(
                  label: l10n.t('hitOverridden'),
                  kind: GuardianStatusKind.pro),
          ],
        ),
      ),
    );
  }
}

final _hitProvider = FutureProvider.family<WebBlockHit?, String>(
    (ref, String familyIdAndHitId) async {
  final parts = familyIdAndHitId.split('|');
  final repository = ref.watch(webFilterRepositoryProvider);
  return repository.hitById(parts.last);
});

/// Simple labeled detail row reused inside WF-006.
class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: GuardianTokens.guardianTeal),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}
