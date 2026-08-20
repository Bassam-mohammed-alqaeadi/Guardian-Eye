// Copyright (c) 2026 Guardian Eye Pro. All rights reserved.
//
// ST-001..ST-005 — Subscription & Paywall module.
// Honest-state UX: no fake payments; the paywall presents the honest local
// entitlement state, explains what each tier unlocks, and records a local
// "upgrade request" that the family owner can act on out-of-band. No backend
// schema or billing integration is modified (user contract: zero backend
// changes).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/guardian_providers.dart';
import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';
import '../../domain/guardian_models.dart';
import '../../domain/subscription_entitlements.dart';

/// ST-001 — Subscription Home. Honest entitlement state for the whole family.
class SubscriptionHomeScreen extends ConsumerWidget {
  const SubscriptionHomeScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/subscription/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final entitlementsAsync =
        ref.watch(subscriptionEntitlementsProvider(familyId));
    final metersAsync = ref.watch(subscriptionUsageMetersProvider(familyId));

    if (runtime is AsyncError || entitlementsAsync is AsyncError) {
      return Scaffold(body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('subscriptionLoadFailed'),
        message: l10n.t('somethingWentWrong'),
        onRetry: () => ref.invalidate(subscriptionEntitlementsProvider(familyId)),
      ));
    }
    if (runtime is AsyncLoading || entitlementsAsync is AsyncLoading) {
      return const Scaffold(body: GuardianStateView(state: GuardianViewState.loading));
    }
    final ctx = runtime.valueOrNull;
    if (ctx == null) {
      return const Scaffold(body: GuardianStateView(state: GuardianViewState.loading));
    }
    if (!ctx.can(FamilyPermission.manageSubscription)) {
      return Scaffold(body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('subscriptionLocked'),
        message: l10n.t('subscriptionLockedMessage'),
      ));
    }
    final entitlements = entitlementsAsync.valueOrNull ?? const [];
    final meters = metersAsync.valueOrNull ?? const [];

    final grantedCount =
        entitlements.where((e) => e.granted).length;
    final expiredCount = entitlements.where(
        (e) => !e.granted && e.expiresAt != null).length;

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('subscriptionTitle')),
              pinned: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push('/subscription/$familyId/upgrade'),
                    child: Text(l10n.t('subscriptionUpgrade')),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianHeroCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('subscriptionStatus'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.t('subscriptionGrantedCount')}'
                            '$grantedCount ${l10n.t('subscriptionAnd')} '
                            '$expiredCount '
                            '${l10n.t('subscriptionExpiredCount')}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (meters.any((m) => m.isOverLimit))
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.t('subscriptionOverLimit'),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    GuardianSection(
                      title: l10n.t('subscriptionEntitlements'),
                      children: entitlements.isEmpty
                          ? [
                              GuardianStateView(
                                state: GuardianViewState.empty,
                                title: l10n.t('subscriptionEntitlements'),
                                message:
                                    l10n.t('subscriptionEntitlementsEmpty'),
                              ),
                            ]
                          : [
                              for (final e in entitlements)
                                GuardianCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          e.granted
                                              ? Icons.check_circle
                                              : Icons.cancel_outlined,
                                          color: e.granted
                                              ? GuardianTokens.guardianTeal
                                              : Colors.white38,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(e.feature,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                      fontWeight: FontWeight.bold)),
                                        ),
                                        Text(
                                          e.granted
                                              ? l10n.t('subscriptionGranted')
                                              : l10n.t('subscriptionNotGranted'),
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
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

/// ST-002 — Upgrade / Paywall. Honest feature comparison, no fake payments.
class SubscriptionUpgradeScreen extends ConsumerStatefulWidget {
  const SubscriptionUpgradeScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/subscription/:familyId/upgrade';

  @override
  ConsumerState<SubscriptionUpgradeScreen> createState() =>
      _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState
    extends ConsumerState<SubscriptionUpgradeScreen> {
  Future<void> _requestUpgrade(SubscriptionTier tier) async {
    final ref = this.ref;
    final runtime = ref.read(familyRuntimeContextProvider(widget.familyId));
    final actor = runtime.valueOrNull?.actor;
    if (actor == null) return;
    await ref.read(subscriptionRepositoryProvider).setEntitlement(Entitlement(
          familyId: widget.familyId,
          feature: tier.name,
          granted: true,
          policyKey: 'local:owner:${actor.id}',
          grantedAt: DateTime.now().toUtc(),
        ));
    ref.invalidate(subscriptionEntitlementsProvider(widget.familyId));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('subscriptionUpgrade')),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l10n.t('subscriptionPaywallNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GuardianSection(
                      title: l10n.t('subscriptionTiers'),
                      children: [
                        for (final tier in SubscriptionTier.values)
                          _TierCard(
                            tier: tier,
                            l10n: l10n,
                            onSelect: () => _requestUpgrade(tier),
                          ),
                      ],
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

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.l10n,
    required this.onSelect,
  });

  final SubscriptionTier tier;
  final AppLocalizations l10n;
  final VoidCallback onSelect;

  SubscriptionPlanCaps get _caps => SubscriptionPlanCaps.forTier(tier);

  @override
  Widget build(BuildContext context) {
    final isFree = tier == SubscriptionTier.free;
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tier.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (!isFree)
                  FilledButton(onPressed: onSelect, child: Text(
                      '${l10n.t('subscriptionChooseTier')} ${tier.name}')),
              ],
            ),
            const SizedBox(height: 10),
            _capLine(context, l10n.t('subscriptionMaxChildren'),
                _caps.maxChildren == null
                    ? l10n.t('subscriptionUnlimited')
                    : '${_caps.maxChildren}',
                l10n),
            _capLine(context, l10n.t('subscriptionAiLayer'),
                _caps.aiEnabled ? l10n.t('yes') : l10n.t('no'), l10n),
            _capLine(context, l10n.t('subscriptionCoupleHarmony'),
                _caps.coupleEnabled ? l10n.t('yes') : l10n.t('no'), l10n),
            _capLine(context, l10n.t('subscriptionPdfExport'),
                _caps.pdfExportEnabled ? l10n.t('yes') : l10n.t('no'), l10n),
            _capLine(context, l10n.t('subscriptionBackgroundTracking'),
                _caps.backgroundTrackingEnabled
                    ? l10n.t('yes')
                    : l10n.t('no'),
                l10n),
          ],
        ),
      ),
    );
  }

  Widget _capLine(BuildContext context, String label, String value, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// ST-003 — Entitlement details per feature policy.
class SubscriptionEntitlementsScreen extends ConsumerWidget {
  const SubscriptionEntitlementsScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/subscription/:familyId/entitlements';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final entitlementsAsync =
        ref.watch(subscriptionEntitlementsProvider(familyId));

    if (runtime is AsyncError || entitlementsAsync is AsyncError) {
      return Scaffold(body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('subscriptionLoadFailed'),
        message: l10n.t('somethingWentWrong'),
      ));
    }
    if (runtime is AsyncLoading || entitlementsAsync is AsyncLoading) {
      return const Scaffold(body: GuardianStateView(state: GuardianViewState.loading));
    }
    final entitlements = entitlementsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('subscriptionEntitlements')),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(l10n.t('subscriptionEntitlementsNote'),
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (entitlements.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('subscriptionEntitlements'),
                        message:
                            l10n.t('subscriptionEntitlementsEmpty'),
                      ),
                    for (final e in entitlements)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    e.granted
                                        ? Icons.check_circle
                                        : Icons.cancel_outlined,
                                    color: e.granted
                                        ? GuardianTokens.guardianTeal
                                        : Colors.white38,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(e.feature,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(l10n.t('subscriptionPolicyKey'),
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text(e.policyKey,
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (e.grantedAt != null)
                                Text(
                                    '${l10n.t('subscriptionGrantedAt')}: '
                                    '${e.grantedAt!.toLocal()}',
                                    style: Theme.of(context).textTheme.bodySmall),
                              if (e.expiresAt != null)
                                Text(
                                    '${l10n.t('subscriptionExpiresAt')}: '
                                    '${e.expiresAt!.toLocal()}',
                                    style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
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

/// ST-004 — Usage meters honesty view (free-tier limits).
class SubscriptionMetersScreen extends ConsumerWidget {
  const SubscriptionMetersScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/subscription/:familyId/meters';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final metersAsync =
        ref.watch(subscriptionUsageMetersProvider(familyId));

    if (metersAsync is AsyncError) {
      return Scaffold(body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('subscriptionLoadFailed'),
        message: l10n.t('somethingWentWrong'),
      ));
    }
    if (metersAsync is AsyncLoading) {
      return const Scaffold(body: GuardianStateView(state: GuardianViewState.loading));
    }
    final meters = metersAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('subscriptionMeters')),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  l10n.t('subscriptionMetersNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (meters.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('subscriptionMeters'),
                        message: l10n.t('subscriptionMetersEmpty'),
                      ),
                    for (final m in meters)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.feature,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                '${m.used}/${m.limit} ${l10n.t('subscriptionUsed')}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: LinearProgressIndicator(
                                  value: m.limit > 0
                                      ? (m.used / m.limit).clamp(0.0, 1.0)
                                      : 0,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    m.isOverLimit
                                        ? Colors.redAccent
                                        : GuardianTokens.guardianTeal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l10n.t('subscriptionRemaining')}: ${m.remaining}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
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

/// ST-005 — Billing history honesty view.
class SubscriptionBillingScreen extends ConsumerWidget {
  const SubscriptionBillingScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/subscription/:familyId/billing';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final billingAsync =
        ref.watch(subscriptionBillingProvider(familyId));

    if (billingAsync is AsyncError) {
      return Scaffold(body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('subscriptionLoadFailed'),
        message: l10n.t('somethingWentWrong'),
      ));
    }
    if (billingAsync is AsyncLoading) {
      return const Scaffold(body: GuardianStateView(state: GuardianViewState.loading));
    }
    final records = billingAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('subscriptionBilling')),
              pinned: true,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l10n.t('subscriptionBillingNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (records.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('subscriptionBilling'),
                        message: l10n.t('subscriptionBillingEmpty'),
                      ),
                    for (final r in records)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                r.isRefund
                                    ? Icons.keyboard_return
                                    : Icons.payments_outlined,
                                color: r.isRefund
                                    ? Colors.amber
                                    : GuardianTokens.guardianTeal,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.kind,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    Text(r.createdAt.toLocal().toString(),
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Text('${r.amountMinorUnits} ${r.currency}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
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
