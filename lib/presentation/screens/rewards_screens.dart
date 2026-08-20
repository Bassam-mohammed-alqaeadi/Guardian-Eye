import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/family_rewards.dart';
import '../../domain/family_rules.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

// ═══════════════════════════ RW-001 — Rewards dashboard ═══════════════════════
/// `/rewards/:familyId` — the family points center. Shows the balance for each
/// child (honest state: loading/empty/error), the reward catalog preview and
/// navigation to the ledger, catalog editor and pending claims.
class RewardsDashboardScreen extends ConsumerWidget {
  const RewardsDashboardScreen({super.key});

  static const route = '/rewards/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final catalog = ref.watch(rewardCatalogProvider(familyId));
    final guard = _rewardsGuard(
        context, ref, familyId, runtime, catalog, FamilyPermission.viewRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final ctx = runtime.valueOrNull!;
    final children = ctx.children;
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwRewardsTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
                rewardsBalanceProvider((familyId: familyId, childId: '')));
            ref.invalidate(rewardCatalogProvider(familyId));
            ref.invalidate(pendingClaimsProvider(familyId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/family_rewards.png',
                    height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              GuardianSection(title: l10n.t('rwBalancesTitle'), children: [
                if (children.isEmpty)
                  GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('rwNoChildren'),
                    message: l10n.t('rwNoChildrenDescription'),
                  )
                else
                  for (final child in children)
                    _ChildBalanceRow(
                        familyId: familyId,
                        childId: child.id,
                        childName: child.displayName.isEmpty
                            ? child.id
                            : child.displayName),
              ]),
              const SizedBox(height: 16),
              if (ctx.can(FamilyPermission.manageRewards)) ...[
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/rewards/$familyId/catalog/new'),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.t('rwCatalogTitle')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/rewards/$familyId/pending'),
                  icon: const Icon(Icons.pending_actions_outlined),
                  label: Text(l10n.t('rwPendingClaimsTitle')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String childIdFallback(FamilyMember child) => child.id;
}

class _ChildBalanceRow extends ConsumerWidget {
  const _ChildBalanceRow(
      {required this.familyId, required this.childId, required this.childName});
  final String familyId;
  final String childId;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final balance = ref
        .watch(rewardsBalanceProvider((familyId: familyId, childId: childId)));
    return GuardianCard(
      child: InkWell(
        onTap: () => context.push('/rewards/$familyId/ledger/$childId'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            GuardianIconBadge(
                icon: Icons.account_balance_wallet_outlined,
                background: GuardianTokens.guardianTealSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(childName,
                        style: Theme.of(context).textTheme.titleMedium),
                    balance.when(
                      loading: () => Text(l10n.t('rwLoadingBalance'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54)),
                      error: (_, __) => Text(l10n.t('rwBalanceUnavailable'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.redAccent)),
                      data: (points) => Text(
                          '${l10n.t('rwBalanceLabel')}: $points ${l10n.t('rwPoints')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54)),
                    ),
                  ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════ RW-002 — Reward catalog ═════════════════════════
/// `/rewards/:familyId/catalog` — every catalog entry with its honest state.
class RewardCatalogScreen extends ConsumerWidget {
  const RewardCatalogScreen({super.key});

  static const route = '/rewards/:familyId/catalog';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final catalog = ref.watch(rewardCatalogProvider(familyId));
    final guard = _rewardsGuard(
        context, ref, familyId, runtime, catalog, FamilyPermission.viewRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final canManage =
        runtime.valueOrNull?.can(FamilyPermission.manageRewards) ?? false;
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwCatalogTitle'),
              style: Theme.of(context).textTheme.titleLarge),
          actions: [
            if (canManage)
              IconButton(
                  tooltip: l10n.t('rwCatalogTitle'),
                  onPressed: () =>
                      context.push('/rewards/$familyId/catalog/new'),
                  icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
        body: catalog.when(
          loading: () =>
              const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            title: l10n.t('rwCatalogLoadFailed'),
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(rewardCatalogProvider(familyId)),
          ),
          data: (rewards) => rewards.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/images/family_rewards.png',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 12),
                    GuardianStateView(
                      state: GuardianViewState.empty,
                      title: l10n.t('rwEmptyCatalog'),
                      message: l10n.t('rwEmptyCatalogDescription'),
                      onPrimaryAction: canManage
                          ? () => context.push('/rewards/$familyId/catalog/new')
                          : null,
                      primaryActionLabel: l10n.t('rwAddFirstReward'),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rewards.length,
                  itemBuilder: (_, i) {
                    final reward = rewards[i];
                    return GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: Icons.card_giftcard_outlined,
                              background: GuardianTokens.guardianTealSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(reward.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  if (reward.description != null &&
                                      reward.description!.isNotEmpty)
                                    Text(reward.description!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.black54)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${l10n.t('rwCostLabel')}: ${reward.costPoints} ${l10n.t('rwPoints')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54)),
                                ]),
                          ),
                          if (canManage)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.t('rwEditReward'),
                              onPressed: () => context.push(
                                  '/rewards/$familyId/catalog/edit/${reward.rewardId}'),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════ RW-003 — Catalog editor (new/edit) ═══════════════════
/// `/rewards/:familyId/catalog/new` & `/rewards/:familyId/catalog/edit/:rewardId`
class RewardCatalogEditorScreen extends ConsumerStatefulWidget {
  const RewardCatalogEditorScreen({super.key});

  static const newRoute = '/rewards/:familyId/catalog/new';
  static const editRoute = '/rewards/:familyId/catalog/edit/:rewardId';

  @override
  ConsumerState<RewardCatalogEditorScreen> createState() =>
      _RewardCatalogEditorState();
}

class _RewardCatalogEditorState
    extends ConsumerState<RewardCatalogEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _cost = TextEditingController();
  final _expiry = TextEditingController();
  bool _saving = false;
  FamilyReward? _existing;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _cost.dispose();
    _expiry.dispose();
    super.dispose();
  }

  String get _familyId =>
      GoRouterState.of(context).pathParameters['familyId'] ?? '';
  String? get _editId => GoRouterState.of(context).pathParameters['rewardId'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final editId = _editId;
    if (editId == null || editId.isEmpty) return;
    final runtime = ref.read(familyRuntimeContextProvider(_familyId));
    final ctx = runtime.valueOrNull;
    if (ctx == null) return;
    try {
      final repo = ref.read(familyRewardsRepositoryProvider);
      final found = await repo.find(_familyId, editId);
      if (found != null && mounted) {
        setState(() => _existing = found);
        _name.text = found.name;
        _description.text = found.description ?? '';
        _cost.text = '${found.costPoints}';
        _expiry.text = found.expiryDays != null ? '${found.expiryDays}' : '';
      }
    } catch (_) {
      // Leave fields empty; save will validate.
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final costText = _cost.text.trim();
    if (name.isEmpty || costText.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('rwRequiredFields'))));
      return;
    }
    final cost = int.tryParse(costText);
    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('rwInvalidCost'))));
      return;
    }
    final expiry = _expiry.text.trim();
    final expiryDays = expiry.isEmpty ? null : (int.tryParse(expiry) ?? 0);
    final ctx = ref.read(familyRuntimeContextProvider(_familyId)).valueOrNull;
    if (ctx == null) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(familyRewardsRepositoryProvider);
      if (_existing != null) {
        await repo.update(_existing!.copyWith(
          name: name,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          costPoints: cost,
          expiryDays: expiryDays,
        ));
      } else {
        await repo.create(
          FamilyReward(
            rewardId: '',
            familyId: _familyId,
            name: name,
            description: _description.text.trim().isEmpty
                ? null
                : _description.text.trim(),
            costPoints: cost,
            expiryDays: expiryDays,
            createdAt: DateTime.now(),
          ),
          createdByMemberId: ctx.actor?.id ?? ctx.familyId,
        );
      }
      ref.invalidate(rewardCatalogProvider(_familyId));
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('rwSaved'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('rwSaveFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = _existing != null;
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(isEdit ? l10n.t('rwEditReward') : l10n.t('rwNewReward'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _name,
                      decoration:
                          InputDecoration(labelText: l10n.t('rwRewardName')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      decoration: InputDecoration(
                          labelText: l10n.t('rwRewardDescription')),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cost,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: l10n.t('rwRewardCost'),
                          suffixText: l10n.t('rwPoints')),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _expiry,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: l10n.t('rwExpiryDays'),
                          hintText: l10n.t('rwExpiryHint')),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator()
                          : Text(l10n.t('rwSaveReward')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════ RW-004 — Redeem reward (child side) ═════════════════
/// `/rewards/:familyId/redeem/:rewardId` — a child requests a reward.
/// Deduction happens only after parent approval (pending claims, RW-005).
class RewardRedeemScreen extends ConsumerStatefulWidget {
  const RewardRedeemScreen({super.key});

  static const route = '/rewards/:familyId/redeem/:rewardId';

  @override
  ConsumerState<RewardRedeemScreen> createState() => _RewardRedeemState();
}

class _RewardRedeemState extends ConsumerState<RewardRedeemScreen> {
  bool _requesting = false;

  String get _familyId =>
      GoRouterState.of(context).pathParameters['familyId'] ?? '';
  String get _rewardId =>
      GoRouterState.of(context).pathParameters['rewardId'] ?? '';

  Future<void> _request() async {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.read(familyRuntimeContextProvider(_familyId)).valueOrNull;
    if (ctx == null) return;
    final childId = ctx.children.firstOrNull?.id;
    if (childId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('rwNoChildSelected'))));
      return;
    }
    final reward = await ref
        .read(familyRewardsRepositoryProvider)
        .find(_familyId, _rewardId);
    if (reward == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('rwRewardGone'))));
      return;
    }
    final balance = await ref
        .read(familyRewardsRepositoryProvider)
        .balanceFor(_familyId, childId);
    if (balance < reward.costPoints) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                '${l10n.t('rwInsufficientPoints')}: ${balance} ${l10n.t('rwPoints')}')));
      return;
    }
    setState(() => _requesting = true);
    try {
      await ref.read(familyRewardsRepositoryProvider).requestRedemption(
            familyId: _familyId,
            rewardId: _rewardId,
            childId: childId,
            actorMemberId: ctx.actor?.id ?? ctx.familyId,
          );
      ref.invalidate(pendingClaimsProvider(_familyId));
      ref.invalidate(
          rewardsBalanceProvider((familyId: _familyId, childId: childId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('rwRedeemRequested'))),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('rwRedeemFailed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rewardAsync = ref.watch(rewardCatalogProvider(_familyId)).whenData(
        (rewards) => rewards.where((r) => r.rewardId == _rewardId).firstOrNull);
    final guard = _rewardsGuard(
        context,
        ref,
        _familyId,
        ref.watch(familyRuntimeContextProvider(_familyId)),
        rewardAsync,
        FamilyPermission.viewRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwRedeemTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: rewardAsync.when(
          loading: () =>
              const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(rewardCatalogProvider(_familyId)),
          ),
          data: (reward) => reward == null
              ? GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('rwRewardGone'),
                  message: l10n.t('rwRewardGoneDescription'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GuardianHeroCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              GuardianIconBadge(
                                  icon: Icons.card_giftcard_outlined,
                                  background: Colors.white24,
                                  foreground: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(reward.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: Colors.white)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                                '${l10n.t('rwCostLabel')}: ${reward.costPoints} ${l10n.t('rwPoints')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white70)),
                            if (reward.description != null &&
                                reward.description!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(reward.description!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(l10n.t('rwRedeemNote'),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _requesting ? null : _request,
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: _requesting
                          ? const CircularProgressIndicator()
                          : Text(l10n.t('rwRequestRedeem')),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════ RW-005 — Pending claims (parent) ════════════════════
/// `/rewards/:familyId/pending` — parent reviews child redemption requests.
/// Approving writes the deduction ledger row; declining does not spend.
class PendingClaimsScreen extends ConsumerWidget {
  const PendingClaimsScreen({super.key});

  static const route = '/rewards/:familyId/pending';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final claims = ref.watch(pendingClaimsProvider(familyId));
    final guard = _rewardsGuard(context, ref, familyId, runtime, claims,
        FamilyPermission.manageRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwPendingClaimsTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: claims.when(
          loading: () =>
              const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(pendingClaimsProvider(familyId)),
          ),
          data: (allClaims) {
            final pending = allClaims.where((c) => c.isPending).toList();
            return pending.isEmpty
                ? GuardianStateView(
                    state: GuardianViewState.empty,
                    title: l10n.t('rwNoPendingClaims'),
                    message: l10n.t('rwNoPendingClaimsDescription'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pending.length,
                    itemBuilder: (_, i) {
                      final claim = pending[i];
                      return _ClaimRow(familyId: familyId, claim: claim);
                    },
                  );
          },
        ),
      ),
    );
  }
}

class _ClaimRow extends ConsumerStatefulWidget {
  const _ClaimRow({required this.familyId, required this.claim});
  final String familyId;
  final RewardClaim claim;

  @override
  ConsumerState<_ClaimRow> createState() => _ClaimRowState();
}

class _ClaimRowState extends ConsumerState<_ClaimRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(rewardCatalogProvider(widget.familyId));
    final rewardName = catalog.valueOrNull
            ?.where((r) => r.rewardId == widget.claim.rewardId)
            .firstOrNull
            ?.name ??
        l10n.t('rwUnknownReward');
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              GuardianIconBadge(
                  icon: Icons.pending_actions_outlined,
                  background: GuardianTokens.guardianTealSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rewardName,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                          '${l10n.t('rwRequestedAt')}: ${widget.claim.requestedAt.month}/${widget.claim.requestedAt.day}/${widget.claim.requestedAt.year}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54)),
                    ]),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  child: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.t('rwApproveClaim')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: Text(l10n.t('rwDeclineClaim')),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(bool approved) async {
    final l10n = AppLocalizations.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(familyRewardsRepositoryProvider);
      if (approved) {
        final reward =
            await repo.find(widget.claim.familyId, widget.claim.rewardId);
        if (reward == null) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.t('rwRewardGone'))));
          }
          return;
        }
        await repo.recordApprovedSpend(
          familyId: widget.claim.familyId,
          childId: widget.claim.childId,
          points: reward.costPoints,
          claimId: widget.claim.claimId,
          actedBy: 'parent',
        );
        await repo.approveClaim(
            familyId: widget.claim.familyId,
            claimId: widget.claim.claimId,
            decidedByMemberId: 'parent');
      } else {
        await repo.declineClaim(
            familyId: widget.claim.familyId,
            claimId: widget.claim.claimId,
            decidedByMemberId: 'parent');
      }
      ref.invalidate(pendingClaimsProvider(widget.familyId));
      ref.invalidate(rewardLedgerProvider(widget.familyId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('somethingWentWrong'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ═══════════════════ RW-006 — Reward automation rules ═══════════════════════
/// `/rewards/:familyId/automation` — FS-011 bridge: shows each
/// `rewardUnlocked` rule that has a linked automation handler and lets the
/// parent toggle it. (Automation evaluation itself runs server-side via the
/// family.rules.toggled outbox; this screen is the honest UI lens.)
class RewardAutomationScreen extends ConsumerWidget {
  const RewardAutomationScreen({super.key});

  static const route = '/rewards/:familyId/automation';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final rules = ref.watch(rulesListProvider(familyId));
    final guard = _rewardsGuard(
        context, ref, familyId, runtime, rules, FamilyPermission.manageRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final gated = rules.valueOrNull
            ?.where((r) => r.kind == RuleKind.rewardUnlocked && r.enabled)
            .toList() ??
        const [];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwAutomationTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: rules.when(
          loading: () =>
              const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(rulesListProvider(familyId)),
          ),
          data: (_) => gated.isEmpty
              ? GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('rwNoAutomation'),
                  message: l10n.t('rwNoAutomationDescription'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: gated.length,
                  itemBuilder: (_, i) {
                    final rule = gated[i];
                    return GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: Icons.auto_awesome_outlined,
                              background: GuardianTokens.guardianTealSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rule.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  Text(
                                      '${l10n.t('rwLinkedRule')}: ${rule.ruleId}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54)),
                                ]),
                          ),
                          Switch(
                            value: rule.enabled,
                            onChanged: (on) async {
                              final repo =
                                  ref.read(familyRulesRepositoryProvider);
                              await repo.toggleEnabled(
                                  familyId: familyId, ruleId: rule.ruleId);
                              ref.invalidate(rulesListProvider(familyId));
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════ RW-007 — Points ledger ═════════════════════════════
/// `/rewards/:familyId/ledger/:childId` — auditable points history for one
/// child. Balance is always derived from the ledger — never stored alone.
class RewardLedgerScreen extends ConsumerWidget {
  const RewardLedgerScreen({super.key});

  static const route = '/rewards/:familyId/ledger/:childId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final childId = GoRouterState.of(context).pathParameters['childId'] ?? '';
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final ledger = ref.watch(rewardLedgerProvider(familyId));
    final guard = _rewardsGuard(
        context, ref, familyId, runtime, ledger, FamilyPermission.viewRewards);
    if (guard is! SizedBox || !identical(guard, const SizedBox.shrink())) {
      return guard;
    }
    final rows =
        ledger.valueOrNull?.where((e) => e.childId == childId).toList() ??
            const [];
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavyDeep,
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rwLedgerTitle'),
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: ledger.when(
          loading: () =>
              const GuardianStateView(state: GuardianViewState.loading),
          error: (_, __) => GuardianStateView(
            state: GuardianViewState.error,
            message: l10n.t('somethingWentWrong'),
            onRetry: () => ref.invalidate(rewardLedgerProvider(familyId)),
          ),
          data: (_) => rows.isEmpty
              ? GuardianStateView(
                  state: GuardianViewState.empty,
                  title: l10n.t('rwEmptyLedger'),
                  message: l10n.t('rwEmptyLedgerDescription'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    final isEarn = row.delta > 0;
                    return GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          GuardianIconBadge(
                              icon: isEarn
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              background: isEarn
                                  ? GuardianTokens.guardianTealSoft
                                  : Colors.red.shade50,
                              foreground: isEarn
                                  ? GuardianTokens.guardianTeal
                                  : Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_reasonLabel(l10n, row.reason),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  Text(
                                      '${row.actedAt.month}/${row.actedAt.day}/${row.actedAt.year} · ${l10n.t('rwBalanceAfter')}: ${row.balanceAfter}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54)),
                                ]),
                          ),
                          Text('${isEarn ? '+' : ''}${row.delta}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: isEarn
                                          ? GuardianTokens.guardianTeal
                                          : Colors.red.shade700)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, LedgerReason reason) {
    switch (reason) {
      case LedgerReason.earnedFromTask:
        return l10n.t('rwReasonEarnedTask');
      case LedgerReason.manualGrant:
        return l10n.t('rwReasonManual');
      case LedgerReason.automation:
        return l10n.t('rwReasonAutomation');
      case LedgerReason.parentApprovedSpend:
        return l10n.t('rwReasonSpend');
      case LedgerReason.spendRefund:
        return l10n.t('rwReasonRefund');
    }
  }
}

// ══════════════════════════ Shared permission guard ═════════════════════════
Widget _rewardsGuard(
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
          onRetry: () => ref.invalidate(rewardCatalogProvider(familyId)),
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
