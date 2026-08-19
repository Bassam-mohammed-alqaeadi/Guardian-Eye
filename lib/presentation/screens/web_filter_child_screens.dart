import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../data/web_filter_repository.dart';
import '../../domain/guardian_models.dart';
import '../../domain/child_exception_request.dart';
import '../../domain/web_filtering/web_filter_categories.dart';
import '../widgets/guardian_primitives.dart';
import '../../application/family_context_provider.dart';

/// FS-002 — Web Filtering child-facing and policy screens (WF-007,
/// WF-008, WF-009, WF-010). Timed allowances, the trusted allowlist,
/// per-child category policies, and the honest blocked-page contract.

// ────────────────────── WF-007 Temporary Allow (timed) ─────────────────────

/// `/safety/web/:familyId/history/:hitId/allow` — WF-007. The parent
/// grants a bounded bypass: choose an expiry window and confirm. The
/// confirmation makes the bypass explicit and self-expiring — never a
/// silent hole in the policy.
class WebTemporaryAllowScreen extends ConsumerStatefulWidget {
  const WebTemporaryAllowScreen(
      {required this.familyId, required this.hitId, super.key});
  final String familyId;
  final String hitId;

  @override
  ConsumerState<WebTemporaryAllowScreen> createState() =>
      _WebTemporaryAllowState();
}

class _WebTemporaryAllowState
    extends ConsumerState<WebTemporaryAllowScreen> {
  Duration _chosen = const Duration(minutes: 15);
  bool _busy = false;

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hit = ref.watch(_webDetailProvider(widget.hitId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('temporaryAllow'))),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: hit.hasError
            ? GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('syncFailed'),
                message: l10n.t('somethingWentWrong'),
                onRetry: () => ref.invalidate(_webDetailProvider),
              )
            : hit.valueOrNull == null || hit.isLoading
                ? const GuardianStateView(state: GuardianViewState.loading)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GuardianHeroCard(
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: Icons.timer_outlined,
                              background: Colors.white24,
                              foreground: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(hit.valueOrNull!.domain,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      GuardianSection(title: l10n.t('expiry'), children: [
                        GuardianCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('allowDescription'),
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              _DurationOption(
                                label: l10n.t('fifteenMinutes'),
                                selected:
                                    _chosen == const Duration(minutes: 15),
                                onTap: () => setState(
                                    () => _chosen = const Duration(minutes: 15)),
                              ),
                              _DurationOption(
                                label: l10n.t('oneHour'),
                                selected:
                                    _chosen == const Duration(hours: 1),
                                onTap: () => setState(
                                    () => _chosen = const Duration(hours: 1)),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  final repository =
                                      ref.read(webFilterRepositoryProvider);
                                  final expiresAt =
                                      DateTime.now().toUtc().add(_chosen);
                                  try {
                                    await repository.setSetting(
                                        familyId: widget.familyId,
                                        key: 'allow.${hit.valueOrNull!.id}',
                                        value: expiresAt.toIso8601String());
                                    await repository.markOverridden(
                                        hit.valueOrNull!.id, 'temporal');
                                    if (!mounted) return;
                                    ref.invalidate(_webDetailProvider);
                                    ref.invalidate(
                                        webHitsProvider(widget.familyId));
                                    _message(l10n.t('allowedTemporarily')
                                        .replaceAll('%s',
                                            '${expiresAt.toLocal().hour.toString().padLeft(2, '0')}:${expiresAt.toLocal().minute.toString().padLeft(2, '0')}'));
                                    Navigator.of(context).pop();
                                  } catch (_) {
                                    _message(l10n.t('somethingWentWrong'));
                                  } finally {
                                    if (mounted) setState(() => _busy = false);
                                  }
                                },
                          style: FilledButton.styleFrom(
                              backgroundColor: GuardianTokens.guardianTeal),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(l10n.t('confirmAllow')),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(guardianTokensRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(guardianTokensRadius),
              border: Border.all(
                  color:
                      selected ? GuardianTokens.guardianTeal : Colors.grey.shade300),
              color: selected
                  ? GuardianTokens.guardianTeal.withOpacity(0.08)
                  : Colors.transparent,
            ),
            child: Row(children: [
              Expanded(child: Text(label)),
              Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? GuardianTokens.guardianTeal : Colors.grey.shade500),
            ]),
          ),
        ),
      );
}

const double guardianTokensRadius = 12;

final _webDetailProvider =
    FutureProvider.family<WebBlockHit?, String>((ref, String hitId) async {
  final repository = ref.watch(webFilterRepositoryProvider);
  return repository.hitById(hitId);
});

// ────────────────────────── WF-008 Site Allowlist ──────────────────────────

/// `/safety/web/:familyId/allowlist` — WF-008. Trusted domains that pass
/// every filter (school portals, bank sites). Empty state invites the
/// first entry rather than pretending there is nothing to see.
class WebAllowlistScreen extends ConsumerStatefulWidget {
  const WebAllowlistScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<WebAllowlistScreen> createState() =>
      _WebAllowlistScreenState();
}

class _WebAllowlistScreenState extends ConsumerState<WebAllowlistScreen> {
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
                            final normalized = domain.toLowerCase();
                            if (!_looksLikeDomain(normalized)) {
                              _message(l10n.t('domainMustBeValid'));
                              return;
                            }
                            final repository =
                                ref.read(webFilterRepositoryProvider);
                            try {
                              await repository.addDomain(
                                  familyId: widget.familyId,
                                  domain: normalized,
                                  kind: 'allow',
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

  bool _looksLikeDomain(String normalized) {
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
        appBar: AppBar(title: Text(l10n.t('trustedSites'))),
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
        appBar: AppBar(title: Text(l10n.t('trustedSites'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    if (!contextValue.can(FamilyPermission.managePolicies)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('trustedSites'))),
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

    final trusted = (domains.valueOrNull ?? const [])
        .where((entry) => entry.kind == 'allow')
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('trustedSites'))),
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
              GuardianHeroCard(
                child: Row(children: [
                  GuardianIconBadge(
                      icon: Icons.verified_outlined,
                      background: Colors.white24,
                      foreground: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.t('trustedSitesDescription'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              if (trusted.isEmpty)
                GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('noDomainsYet'),
                  message: l10n.t('addFirstDomain'),
                )
              else
                for (final entry in trusted)
                  GuardianCard(
                    child: Row(children: [
                      GuardianIconBadge(icon: Icons.verified_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.domain,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w600)),
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
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── WF-009 Per-Child Web Policy ───────────────────────

/// `/safety/web/:familyId/:childId` — WF-009. One child's web policy:
/// the category matrix for that child, anchored on the child's name.
class PerChildWebPolicyScreen extends ConsumerStatefulWidget {
  const PerChildWebPolicyScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  ConsumerState<PerChildWebPolicyScreen> createState() =>
      _PerChildWebPolicyState();
}

class _PerChildWebPolicyState extends ConsumerState<PerChildWebPolicyScreen> {
  FamilyMember? _child;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _resolveChild();
  }

  Future<void> _resolveChild() async {
    setState(() => _error = null);
    try {
      final runtime =
          await ref.read(familyRuntimeContextProvider(widget.familyId).future);
      final child = runtime.children
          .where((member) => member.id == widget.childId)
          .firstOrNull;
      if (child == null) {
        if (!mounted) return;
        setState(() => _error = 'child_not_found');
      } else if (mounted) {
        setState(() => _child = child);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _toggle(String category, bool enabled) async {
    final child = _child;
    if (child == null) return;
    final repository = ref.read(webFilterRepositoryProvider);
    try {
      await repository.setCategoryRule(
          familyId: widget.familyId,
          childId: child.id,
          childDisplayName: child.displayName,
          category: category,
          enabled: enabled);
      if (!mounted) return;
      ref.invalidate(_perChildRulesProvider);
      _message(AppLocalizations.of(context).t('webPolicySaved'));
    } catch (_) {
      if (!mounted) return;
      _message(AppLocalizations.of(context).t('somethingWentWrong'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('perChildPolicy'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.empty,
            title: l10n.t('webNotAllowedForChild'),
            onPrimaryAction: _resolveChild,
            primaryActionLabel: l10n.t('viewHistory'),
          ),
        ),
      );
    }
    final child = _child;
    final rules = child == null
        ? null
        : ref.watch(_perChildRulesProvider('${widget.familyId}|${child.id}'));
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    if (runtime.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('perChildPolicy'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('syncFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: _resolveChild,
          ),
        ),
      );
    }
    final contextValue = runtime.valueOrNull;
    if (child == null || rules == null || contextValue == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('perChildPolicy'))),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: const GuardianStateView(state: GuardianViewState.loading),
        ),
      );
    }
    final canManage = contextValue.can(FamilyPermission.managePolicies);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('perChildPolicy'))),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_perChildRulesProvider),
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
                    child: Text(
                        l10n
                            .t('webProtectionFor')
                            .replaceAll('%s', child.displayName),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              GuardianOfflineBanner(),
              const SizedBox(height: 16),
              if (!canManage) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.lock_person_outlined,
                          color: GuardianTokens.guardianNavy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.t('authorizationFailure'),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final group in WebFilterCategories.groups) ...[
                GuardianSection(
                  title: WebFilterCategories.groupLabel(l10n, group),
                  children: [
                    for (final category
                        in WebFilterCategories.ofGroup(group))
                      GuardianCard(
                        onTap: canManage ? () => _toggle(
                            category.key,
                            !(rules.valueOrNull ?? const [])
                                .where((rule) => rule.category == category.key)
                                .fold(true, (enabled, rule) => rule.enabled))
                            : null,
                        child: Row(children: [
                          GuardianIconBadge(icon: _iconOf(category.icon)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category.label(l10n),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(category.description(l10n),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ],
                            ),
                          ),
                          GuardianStatusChip(
                              label: !(rules.valueOrNull ?? const [])
                                      .where((rule) =>
                                          rule.category == category.key)
                                      .fold(true,
                                          (enabled, rule) => rule.enabled)
                                  ? l10n.t('categoryDisabled')
                                  : l10n.t('webProtectionStatus'),
                              kind: !(rules.valueOrNull ?? const [])
                                      .where((rule) =>
                                          rule.category == category.key)
                                      .fold(true,
                                          (enabled, rule) => rule.enabled)
                                  ? GuardianStatusKind.offline
                                  : GuardianStatusKind.safe),
                        ]),
                      ),
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

final _perChildRulesProvider =
    FutureProvider.family<List<WebCategoryRule>, String>((ref, String familyAndChild) async {
  final parts = familyAndChild.split('|');
  final familyId = parts.first;
  final runtime =
      await ref.watch(familyRuntimeContextProvider(familyId).future);
  final child =
      runtime.children.where((member) => member.id == parts.last).firstOrNull;
  if (child == null) return const [];
  final repository = ref.watch(webFilterRepositoryProvider);
  return repository.rulesForFamily(familyId,
      children: [child.id],
      categories: WebFilterCategories.all.map((category) => category.key));
});

// ──────────────────────── WF-010 Blocked Page (child) ──────────────────────

/// `/blocked/:familyId/:childId` — WF-010. The honest blocked-page
/// contract rendered on the parent app so the child device-side page
/// stays a one-to-one implementation of this surface. Explains *why*
/// in age-appropriate terms, offers the exception-request path only
/// when the family enabled it.
class BlockedPageScreen extends ConsumerStatefulWidget {
  const BlockedPageScreen(
      {required this.familyId, required this.childId, super.key});
  final String familyId;
  final String childId;

  @override
  ConsumerState<BlockedPageScreen> createState() =>
      _BlockedPageScreenState();
}

class _BlockedPageScreenState extends ConsumerState<BlockedPageScreen> {
  bool _requested = false;

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final settings = ref.watch(webSettingsProvider(widget.familyId));

    final silent = runtime.valueOrNull != null &&
        settings.valueOrNull != null &&
        ref.watch(webFilterRepositoryProvider).setting(
                settings.valueOrNull!, 'blocked_page_behavior', 'explain') ==
            'silent';
    final exceptionsOn = runtime.valueOrNull != null &&
        settings.valueOrNull != null &&
        ref.watch(webFilterRepositoryProvider).setting(
                settings.valueOrNull!,
                'exception_requests_allowed',
                'on') ==
            'on';

    if (silent) {
      return Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    final child = runtime.valueOrNull?.children
        .where((member) => member.id == widget.childId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: SafeArea(
        child: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GuardianIconBadge(
                      icon: Icons.block_outlined,
                      background: Colors.white12,
                      foreground: Colors.white,
                      size: 64),
                  const SizedBox(height: 20),
                  Text(l10n.t('blockedPage'),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 10),
                  Text(l10n.t('blockedPageExplanation'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70)),
                  if (child != null) ...[
                    const SizedBox(height: 16),
                    Text(
                        l10n
                            .t('webProtectionFor')
                            .replaceAll('%s', child.displayName),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white54)),
                  ],
                  if (exceptionsOn && !_requested) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () async {
                        setState(() => _requested = true);
                        try {
                          await ref
                              .read(childExceptionRequestRepositoryProvider)
                              .create(
                                  familyId: widget.familyId,
                                  childDeviceId: widget.childId,
                                  childUid: widget.childId,
                                  target: 'web',
                                  duration: const Duration(minutes: 15),
                                  reason: ChildExceptionReason.other,
                                  reasonDetail: l10n.t('blockedPage'));
                        } catch (_) {
                          // The request never left — honesty over comfort.
                          if (mounted) setState(() => _requested = false);
                          if (mounted) {
                            _message(l10n.t('somethingWentWrong'));
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: GuardianTokens.guardianTeal),
                      child: Text(l10n.t('requestException')),
                    ),
                  ],
                  if (_requested) ...[
                    const SizedBox(height: 24),
                    Text(l10n.t('requestSent'),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
