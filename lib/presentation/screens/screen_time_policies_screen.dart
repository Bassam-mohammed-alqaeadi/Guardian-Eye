import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/child_exception_request.dart';
import '../../domain/guardian_models.dart';
import '../../domain/policy_engine.dart';
import '../../domain/family_authorization.dart';

/// M6 — Screen-Time Administration.
///
/// The child-centric policy surface reached from the child context:
/// the parent sees their policies, previews the effective decision for
/// a target right now, grants bounded temporary allowances, and reviews
/// the child's exception requests with an atomic approve/deny pipeline.
///
/// Three honesty rules, never broken:
/// 1. Authorization is read through `FamilyRuntimeContext.can` only —
///    this screen never re-implements roles.
/// 2. Nothing here claims device enforcement; every card says what the
///    policy configuration *requests*, not what Android does.
/// 3. SyncState is displayed per item. `synced` only appears when the
///    repository's outbox view says it is synced; save/edit/disable
///    show `queued`.
class ScreenTimePoliciesScreen extends ConsumerWidget {
  const ScreenTimePoliciesScreen(
      {super.key, required this.familyId, required this.childId});

  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;
    final auth = ref.watch(familyRuntimeContextProvider(familyId));
    final policies = ref.watch(childPoliciesProvider(familyId));
    final overrides = ref.watch(childOverridesProvider(familyId));
    final requests =
        ref.watch(familyExceptionRequestsProvider(familyId));
    return Directionality(
      textDirection: direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('screenTimeAdmin')),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(childPoliciesProvider(familyId));
            ref.invalidate(childOverridesProvider(familyId));
            ref.invalidate(familyExceptionRequestsProvider(familyId));
            await Future.wait([
              policies.whenOrNull(data: (_) => Future<void>.value()) ??
                  Future<void>.value(),
              overrides.whenOrNull(data: (_) => Future<void>.value()) ??
                  Future<void>.value(),
              requests.whenOrNull(data: (_) => Future<void>.value()) ??
                  Future<void>.value(),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const SizedBox(height: 8),
              if (auth.valueOrNull == null)
                Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  l10n.t('screenTimeAdminUnavailable'),
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          color: theme.colorScheme
                                              .onErrorContainer),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  l10n.t('screenTimeAdminUnavailableBody'),
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                          color: theme.colorScheme
                                              .onErrorContainer)),
                            ]))),
              if (auth.valueOrNull != null &&
                  !auth.value!.can(FamilyPermission.managePolicies))
                const _ReadOnlyParentBanner(),
              if (auth.valueOrNull != null &&
                  auth.value!.can(FamilyPermission.managePolicies))
                _ManageBar(familyId: familyId, childId: childId),
              const SizedBox(height: 12),
              _EffectiveDecisionCard(
                  familyId: familyId,
                  policies: policies,
                  overrides: overrides),
              const SizedBox(height: 12),
              _PoliciesCard(
                  familyId: familyId, childId: childId),
              const SizedBox(height: 12),
              _ExceptionsCard(
                  familyId: familyId, childId: childId),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner shown when the actor is verified but lacks
/// `managePolicies` (spouse under Option A). Read-only visibility is
/// preserved — policies are observed, never controlled.
class _ReadOnlyParentBanner extends StatelessWidget {
  const _ReadOnlyParentBanner();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const Icon(Icons.visibility_outlined),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('screenTimeAdminUnavailable'),
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(l10n.t('screenTimeAdminUnavailableBody'),
                            style: theme.textTheme.bodyMedium),
                      ]))
            ])));
  }
}

/// Manage bar: create a policy and grant a temporary allowance. Both
/// require the verified parent permission, which the router-level
/// context already gates; the sheet/dialogs refuse to proceed without
/// a `primaryParentMemberId`, so the permission re-check is belt-and-
/// suspenders, never the decision point.
class _ManageBar extends ConsumerWidget {
  const _ManageBar({required this.familyId, required this.childId});
  final String familyId;
  final String childId;

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    await _openPolicyEditor(
        context: context,
        ref: ref,
        familyId: familyId,
        existing: null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Row(children: [
      Expanded(
          child: FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add_outlined),
              label: Text(l10n.t('addFirstPolicy')))),
      const SizedBox(width: 8),
      Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _openOverrideDialog(
                  context: context, ref: ref, familyId: familyId),
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.t('overrideGrant')))),
    ]);
  }
}

// — Effective decision preview ————————————————————————————————

/// Honest preview of what the engine decides for a chosen target
/// right now. This is configuration arithmetic (PolicyEngine), not a
/// report from the child device.
class _EffectiveDecisionCard extends ConsumerStatefulWidget {
  const _EffectiveDecisionCard(
      {required this.familyId,
      required this.policies,
      required this.overrides});
  final String familyId;
  final AsyncValue<List<DigitalPolicy>> policies;
  final AsyncValue<List<StoredPolicyOverride>> overrides;

  @override
  ConsumerState<_EffectiveDecisionCard> createState() =>
      _EffectiveDecisionCardState();
}

class _EffectiveDecisionCardState
    extends ConsumerState<_EffectiveDecisionCard> {
  static const List<String> _previewTargets = [
    'video',
    'social',
    'games',
    'browser'
  ];
  String _target = _previewTargets.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final policies = widget.policies.valueOrNull ?? const [];
    final overrides = widget.overrides.valueOrNull ?? const [];
    final activeOverride =
        overrides.where((o) => o.isActiveAt(DateTime.now())).toList();
    final decision = const PolicyEngine().resolve(
        target: _target,
        moment: DateTime.now(),
        policies: policies,
        override: activeOverride.isEmpty
            ? null
            : activeOverride.firstWhere(
                (o) => o.target == _target,
                orElse: () => activeOverride.first));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l10n.t('effectiveDecisionNow'),
                      style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _previewTargets
                  .map((target) => ChoiceChip(
                      label: Text(_targetLabel(l10n, target)),
                      selected: _target == target,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _target = target);
                        }
                      }))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(
                  decision.restricted
                      ? Icons.block_outlined
                      : Icons.check_outlined,
                  color: decision.restricted
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            decision.restricted
                                ? l10n.t('effectiveDecisionRestricted')
                                : l10n.t('effectiveDecisionAllowed'),
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                            '${_decisionReasonLabel(l10n, decision.reason)}'
                            ' — ${_decisionPolicyName(l10n, decision, policies)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant)),
                      ]))
            ]),
            const SizedBox(height: 10),
            Text(l10n.t('decisionSampleNote'),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  static String _targetLabel(AppLocalizations l10n, String target) =>
      switch (target) {
        'video' => l10n.t('video'),
        'social' => l10n.t('social'),
        'games' => l10n.t('games'),
        'browser' => l10n.t('browser'),
        String() => target
      };

  String _decisionReasonLabel(AppLocalizations l10n, String reason) =>
      switch (reason) {
        'temporary_override' => l10n.t('effectiveDecisionOverride'),
        'no_active_policy' => l10n.t('effectiveDecisionNoPolicy'),
        String() => l10n.t('effectiveDecisionRestricted')
      };

  String _decisionPolicyName(AppLocalizations l10n, PolicyDecision decision,
          List<DigitalPolicy> policies) =>
      decision.policyId == null
          ? l10n.t('effectiveDecisionNoPolicy')
          : (policies.firstWhere(
                  (policy) => policy.id == decision.policyId,
                  orElse: () => DigitalPolicy(
                      id: decision.policyId!,
                      priority: 0,
                      enabled: true,
                      startMinute: 0,
                      endMinute: 0,
                      restrictedTargets: const {}))
              .name
              .isEmpty
              ? decision.policyId!
              : policies.firstWhere(
                      (policy) => policy.id == decision.policyId,
                      orElse: () => DigitalPolicy(
                          id: decision.policyId!,
                          priority: 0,
                          enabled: true,
                          startMinute: 0,
                          endMinute: 0,
                          restrictedTargets: const {}))
                  .name);
}

// — Policies list ———————————————————————————————————————————————

class _PoliciesCard extends ConsumerWidget {
  const _PoliciesCard({required this.familyId, required this.childId});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final policies = ref.watch(childPoliciesProvider(familyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.rule_outlined),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l10n.t('policiesSummary'),
                      style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            policies.when(
              loading: () => const Center(
                  child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator())),
              error: (error, _) =>
                  _SectionError(retry: () =>
                      ref.invalidate(childPoliciesProvider(familyId))),
              data: (items) {
                final active =
                    items.where((policy) => policy.enabled).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$active ${active == 1 ? l10n.t('policiesActiveCount') : l10n.t('policiesActiveCountPlural')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      Text(l10n.t('noPoliciesForChild'),
                          style: theme.textTheme.bodyMedium)
                    else
                      ...items.map((policy) => _PolicyTile(
                          policy: policy,
                          familyId: familyId,
                          childId: childId)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyTile extends ConsumerWidget {
  const _PolicyTile(
      {required this.policy,
      required this.familyId,
      required this.childId});
  final DigitalPolicy policy;
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(policy.name.isEmpty
                                ? policy.id
                                : policy.name,
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                                policy.restrictedTargets
                                    .map((target) =>
                                        _targetLabel(l10n, target))
                                    .join(' · '),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant)),
                          ])),
                  Switch(
                      value: policy.enabled,
                      onChanged: policy.enabled
                          ? null
                          : (enabled) => _setEnabled(
                              context, ref, policy, enabled),
                      activeThumbColor: theme.colorScheme.primary)
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: Text(
                          '${l10n.t('policySchedule')} '
                          '${_compactTime(policy.startMinute)} — '
                          '${_compactTime(policy.endMinute)}',
                          style: theme.textTheme.bodySmall)),
                  Expanded(
                      child: Text(
                          policy.dailyLimitMinutes == null
                              ? l10n.t('noLimit')
                              : '${policy.dailyLimitMinutes} '
                                  '${l10n.t('minutesShort')}',
                          style: theme.textTheme.bodySmall)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                      child: Text(policy.enabled
                          ? l10n.t('policyActiveStatus')
                          : l10n.t('policyInactiveStatus'),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: policy.enabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant))),
                  Expanded(
                      child: Text(_syncLabel(l10n, policy.syncState),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant))),
                ]),
                if (_canManage(ref))
                  const SizedBox(height: 8),
                if (_canManage(ref))
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () => _openEditor(context, ref),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(l10n.t('editPolicy')))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: () => _setEnabled(
                                context, ref, policy, !policy.enabled),
                            icon: Icon(policy.enabled
                                ? Icons.pause_outlined
                                : Icons.play_arrow_outlined),
                            label: Text(policy.enabled
                                ? l10n.t('disablePolicy')
                                : l10n.t('enablePolicy')))),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

    bool _canManage(WidgetRef ref) {
    final auth = ref.read(familyRuntimeContextProvider(familyId));
    final actor = auth.valueOrNull?.actor;
    if (actor == null) return false;
    return const FamilyAuthorization().hasPermission(
        actor, FamilyPermission.managePolicies);
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    await _openPolicyEditor(
        context: context,
        ref: ref,
        familyId: familyId,
        existing: policy);
  }

  static String _targetLabel(AppLocalizations l10n, String target) =>
      switch (target) {
        'video' => l10n.t('video'),
        'social' => l10n.t('social'),
        'games' => l10n.t('games'),
        'browser' => l10n.t('browser'),
        String() => target
      };
  static String _compactTime(int minute) {
    final hour = minute ~/ 60;
    final rest = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  static String _syncLabel(AppLocalizations l10n, SyncState state) =>
      switch (state) {
        SyncState.localOnly => l10n.t('syncLocalOnly'),
        SyncState.queued => l10n.t('syncQueued'),
        SyncState.synced => l10n.t('syncSynced'),
        SyncState.blocked => l10n.t('syncBlocked'),
        SyncState.failed => l10n.t('syncFailed')
      };

  Future<void> _setEnabled(BuildContext context, WidgetRef ref,
      DigitalPolicy policy, bool enabled) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(policyRepositoryProvider).setEnabled(
          existing: policy, enabled: enabled);
      ref.invalidate(childPoliciesProvider(policy.familyId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(enabled
                ? l10n.t('policyEnabledNotice')
                : l10n.t('policyDisabledNotice'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
      }
    }
  }
}

// — Policy editor bottom sheet ———————————————————————————————

Future<void> _openPolicyEditor({
  required BuildContext context,
  required WidgetRef ref,
  required String familyId,
  required DigitalPolicy? existing,
}) async {
  final l10n = AppLocalizations.of(context);
  final name = TextEditingController(text: existing?.name ?? '');
  final priority =
      TextEditingController(text: '${existing?.priority ?? 0}');
  final dailyLimit = TextEditingController(
      text: existing?.dailyLimitMinutes == null
          ? ''
          : '${existing!.dailyLimitMinutes}');
  var start = TimeOfDay(
      hour: (existing?.startMinute ?? 330) ~/ 60,
      minute: (existing?.startMinute ?? 330) % 60);
  var end = TimeOfDay(
      hour: (existing?.endMinute ?? 1320) ~/ 60,
      minute: (existing?.endMinute ?? 1320) % 60);
  var enabled = existing?.enabled ?? true;
  final selected = <String>{...?existing?.restrictedTargets};
  var saving = false;
  await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) =>
                DraggableScrollableSheet(
                    minChildSize: 0.5,
                    initialChildSize: 0.9,
                    builder: (scrollContext, scrollController) => Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20,
                              MediaQuery.of(scrollContext).viewInsets.bottom +
                                  24),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      Text(
                          existing == null
                              ? l10n.t('addFirstPolicy')
                              : l10n.t('editPolicy'),
                          style:
                              Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                              labelText: l10n.t('policyName'))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: priority,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                              labelText: l10n.t('priority'))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: dailyLimit,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                              labelText: l10n.t('dailyLimitMinutes'),
                              hintText: l10n.t('noLimit'))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                      context: sheetContext,
                                      initialTime: start);
                                  if (picked != null) {
                                    setSheetState(() => start = picked);
                                  }
                                },
                                child: Text(
                                    '${l10n.t('startTime')}: '
                                    '${MaterialLocalizations.of(sheetContext).formatTimeOfDay(start)}'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                      context: sheetContext,
                                      initialTime: end);
                                  if (picked != null) {
                                    setSheetState(() => end = picked);
                                  }
                                },
                                child: Text(
                                    '${l10n.t('endTime')}: '
                                    '${MaterialLocalizations.of(sheetContext).formatTimeOfDay(end)}'))),
                      ]),
                      const SizedBox(height: 12),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(l10n.t('policyTargets'))),
                      const SizedBox(height: 8),
                      ..._editorChipSet(
                          l10n: l10n,
                          selected: selected,
                          toggle: (target, isSelected) =>
                              setSheetState(() {
                                isSelected
                                    ? selected.add(target)
                                    : selected.remove(target);
                              })),
                      const SizedBox(height: 8),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.t('policyEnabled')),
                          value: enabled,
                          onChanged: (value) =>
                              setSheetState(() => enabled = value)),
                      const SizedBox(height: 12),
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final parsedPriority =
                                          int.tryParse(
                                              priority.text.trim());
                                      final parsedDaily =
                                          dailyLimit.text.trim().isEmpty
                                              ? null
                                              : int.tryParse(
                                                  dailyLimit.text.trim());
                                      if (name.text.trim().isEmpty ||
                                          parsedPriority == null ||
                                          selected.isEmpty) {
                                        ScaffoldMessenger.of(
                                                sheetContext)
                                            .showSnackBar(SnackBar(
                                                content: Text(l10n.t(
                                                    'policyValidationFailed'))));
                                        return;
                                      }
                                      if (parsedDaily != null &&
                                          (parsedDaily < 1 ||
                                              parsedDaily > 1440)) {
                                        ScaffoldMessenger.of(
                                                sheetContext)
                                            .showSnackBar(SnackBar(
                                                content: Text(l10n.t(
                                                    'policyValidationFailed'))));
                                        return;
                                      }
                                      setSheetState(() => saving = true);
                                      try {
                                        final repository =
                                            ref.read(
                                                policyRepositoryProvider);
                if (existing == null) {
                  await repository.save(
                                              familyId: familyId,
                                              name: name.text,
                                              priority: parsedPriority,
                                              enabled: enabled,
                                              startMinute:
                                                  start.hour * 60 +
                                                  start.minute,
                                              endMinute:
                                                  end.hour * 60 +
                                                  end.minute,
                                              restrictedTargets:
                                                  selected,
                                              dailyLimitMinutes:
                                                  parsedDaily);
                                        } else {
                                          await repository.update(
                                              existing: existing,
                                              name: name.text,
                                              priority: parsedPriority,
                                              enabled: enabled,
                                              startMinute:
                                                  start.hour * 60 +
                                                  start.minute,
                                              endMinute:
                                                  end.hour * 60 +
                                                  end.minute,
                                              restrictedTargets:
                                                  selected,
                                              dailyLimitMinutes:
                                                  parsedDaily);
                                        }
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                        if (context.mounted) {
                                          ref.invalidate(
                                              childPoliciesProvider(
                                                  familyId));
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(l10n.t(
                                                      existing == null
                                                          ? 'policySavedSuccessfully'
                                                          : 'policyEditedSuccessfully'))));
                                        }
                                      } on ArgumentError {
                                        if (sheetContext.mounted) {
                                          ScaffoldMessenger.of(
                                                  sheetContext)
                                              .showSnackBar(SnackBar(
                                                  content: Text(l10n.t(
                                                      'policyScheduleInvalid'))));
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(l10n.t(
                                                      'error'))));
                                        }
                                      } finally {
                                        if (sheetContext.mounted) {
                                          setSheetState(
                                              () => saving = false);
                                        }
                                      }
                                    },
                              child: saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child:
                                          CircularProgressIndicator(
                                              strokeWidth: 2))
                                  : Text(l10n.t('savePolicy')))),
                      const SizedBox(height: 12),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton(
                              onPressed: () {
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                              child: Text(l10n.t('cancel')))),
                    ]),
                          ),
                        ),
                    )));
}

String _targetLabel(AppLocalizations l10n, String target) =>
    switch (target) {
      'video' => l10n.t('video'),
      'social' => l10n.t('social'),
      'games' => l10n.t('games'),
      'browser' => l10n.t('browser'),
      String() => target
    };

/// Target chips used by the policy editor. `selected` is the caller's
/// mutable set; `toggle` re-renders the enclosing StatefulBuilder.
List<Widget> _editorChipSet({
  required AppLocalizations l10n,
  required Set<String> selected,
  required void Function(String target, bool isSelected) toggle,
}) =>
    const ['video', 'social', 'games', 'browser']
        .map((target) => FilterChip(
            label: Text(_targetLabel(l10n, target)),
            selected: selected.contains(target),
            onSelected: (isSelected) => toggle(target, isSelected)))
        .toList(growable: false);

// — Temporary override dialog ————————————————————————————————

Future<void> _openOverrideDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String familyId,
}) async {
  final l10n = AppLocalizations.of(context);
  const durations = <Duration>[
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4)
  ];
  String? selectedTarget;
  Duration? selectedDuration;
  await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) =>
              AlertDialog(
                title: Text(l10n.t('overrideGrant')),
                content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('policyTargets'),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium),
                        const SizedBox(height: 8),
                        ..._editorChipSet(
                            l10n: l10n,
                            selected: selectedTarget == null
                                ? const {}
                                : {selectedTarget!},
                            toggle: (target, isSelected) =>
                                setDialogState(() =>
                                    selectedTarget =
                                        isSelected ? target : null)),
                        const SizedBox(height: 16),
                        Text(l10n.t('overrideDuration'),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium),
                        const SizedBox(height: 8),
                        RadioGroup<Duration>(
                          groupValue: selectedDuration,
                          onChanged: (value) => setDialogState(
                              () => selectedDuration = value),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: durations
                                .map((duration) => RadioListTile<Duration>(
                                    key: ValueKey(
                                        'duration_${duration.inMinutes}'),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        _durationLabel(l10n, duration)),
                                    value: duration))
                                .toList(),
                          ),
                        ),
                      ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(l10n.t('cancel'))),
                  FilledButton(
                      onPressed: selectedTarget == null ||
                              selectedDuration == null
                          ? null
                          : () async {
                              Navigator.pop(dialogContext);
                              await _grantOverride(
                                  context: context,
                                  ref: ref,
                                  familyId: familyId,
                                  target: selectedTarget!,
                                  duration: selectedDuration!);
                            },
                      child: Text(l10n.t('confirm')))
                ],
              )));
}

String _durationLabel(AppLocalizations l10n, Duration duration) =>
    switch (duration.inMinutes) {
      15 => l10n.t('overrideMinutes15'),
      30 => l10n.t('overrideMinutes30'),
      60 => l10n.t('overrideMinutes60'),
      120 => l10n.t('overrideMinutes120'),
      240 => l10n.t('overrideMinutes240'),
      int() =>
        '${duration.inMinutes} ${l10n.t('minutesShort')}'
    };

Future<void> _grantOverride({
  required BuildContext context,
  required WidgetRef ref,
  required String familyId,
  required String target,
  required Duration duration,
}) async {
  final l10n = AppLocalizations.of(context);
  final repository = ref.read(policyRepositoryProvider);
  try {
    final parentId = await repository.primaryParentMemberId(familyId);
    final expiresAt = DateTime.now().toUtc().add(duration);
    await repository.createOverride(
        familyId: familyId,
        createdByMemberId: parentId,
        target: target,
        allowed: true,
        expiresAt: expiresAt);
    ref.invalidate(childOverridesProvider(familyId));
    ref.invalidate(childPoliciesProvider(familyId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('overrideSavedLocally'))));
    }
  } on StateError {
    // Cross-family or unauthenticated actors surface here; the rules
    // reject them and the repo re-throws. Never fabricate allowance.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
    }
  }
}

// — Exception requests review ———————————————————————————————

class _ExceptionsCard extends ConsumerWidget {
  const _ExceptionsCard({required this.familyId, required this.childId});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final requests =
        ref.watch(familyExceptionRequestsProvider(familyId));
    final contextRef =
        ref.watch(familyRuntimeContextProvider(familyId));
    final canReview =
        contextRef.valueOrNull?.can(FamilyPermission.reviewExceptionRequests) ??
            false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(l10n.t('exceptionRequestsTitle'),
                      style: theme.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            requests.when(
              loading: () => const Center(
                  child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator())),
              error: (error, _) => _SectionError(retry: () =>
                  ref.invalidate(
                      familyExceptionRequestsProvider(familyId))),
              data: (items) {
                final pending = items
                    .where((request) =>
                        request.status ==
                        ChildExceptionRequestStatus.pending)
                    .toList();
                if (pending.isEmpty) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('noPendingExceptions'),
                            style: theme.textTheme.bodyMedium),
                      ]);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${pending.length} '
                        '${pending.length == 1 ? l10n.t('pendingExceptionBadge') : l10n.t('pendingExceptionBadgePlural')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ...pending.map((request) => _ExceptionRequestTile(
                        request: request, canReview: canReview)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExceptionRequestTile extends ConsumerStatefulWidget {
  const _ExceptionRequestTile(
      {required this.request, required this.canReview});
  final ChildExceptionRequest request;
  final bool canReview;

  @override
  ConsumerState<_ExceptionRequestTile> createState() =>
      _ExceptionRequestTileState();
}

class _ExceptionRequestTileState
    extends ConsumerState<_ExceptionRequestTile> {
  bool _reviewing = false;

  Future<void> _review(bool approve) async {
    setState(() => _reviewing = true);
    final l10n = AppLocalizations.of(context);
    try {
      final parentId = await ref
          .read(policyRepositoryProvider)
          .primaryParentMemberId(widget.request.familyId);
      if (approve) {
        await ref
            .read(childExceptionRequestRepositoryProvider)
            .approve(
                requestId: widget.request.id,
                parentMemberId: parentId);
      } else {
        await ref
            .read(childExceptionRequestRepositoryProvider)
            .deny(
                requestId: widget.request.id,
                parentMemberId: parentId);
      }
      ref.invalidate(
          familyExceptionRequestsProvider(widget.request.familyId));
      ref.invalidate(
          childOverridesProvider(widget.request.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? l10n.t('exceptionApproved')
                : l10n.t('exceptionDenied'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.t('exceptionReviewFailed'))));
      }
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final request = widget.request;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${l10n.t('overrideGrantFor').replaceAll('{target}', _targetLabel(l10n, request.target))}'
                  ' — ${request.requestedDuration.inMinutes} ${l10n.t('minutesShort')}',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                  '${_reasonLabel(l10n, request.reason)}'
                  '${request.reasonDetail?.isNotEmpty == true ? ' — ${request.reasonDetail}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Text(
                  '${_statusLabel(l10n, request.status)} · ${_syncLabel(l10n, request.syncState)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              if (widget.canReview) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _reviewing ? null : () => _review(false),
                          child: Text(l10n.t('exceptionDeny')))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: FilledButton(
                          onPressed: _reviewing
                              ? null
                              : () => _review(true),
                          child: _reviewing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(
                                          strokeWidth: 2))
                              : Text(l10n.t('exceptionApprove')))),
                ])
              ] else
                Text(l10n.t('screenTimeAdminUnavailable'),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
    );
  }

  static String _reasonLabel(
          AppLocalizations l10n, ChildExceptionReason reason) =>
      switch (reason) {
        ChildExceptionReason.homework => l10n.t('reasonHomework'),
        ChildExceptionReason.schoolAssignment =>
          l10n.t('reasonSchoolAssignment'),
        ChildExceptionReason.familyActivity =>
          l10n.t('reasonFamilyActivity'),
        ChildExceptionReason.importantCommunication =>
          l10n.t('reasonImportantCommunication'),
        ChildExceptionReason.other => l10n.t('reasonOther')
      };

  static String _statusLabel(AppLocalizations l10n,
          ChildExceptionRequestStatus status) =>
      switch (status) {
        ChildExceptionRequestStatus.pending => l10n.t('requestPending'),
        ChildExceptionRequestStatus.approved =>
          l10n.t('requestApproved'),
        ChildExceptionRequestStatus.denied => l10n.t('requestDenied'),
        ChildExceptionRequestStatus.expired =>
          l10n.t('requestExpired'),
        ChildExceptionRequestStatus.cancelled =>
          l10n.t('requestCancelled')
      };

  static String _syncLabel(AppLocalizations l10n, SyncState state) =>
      switch (state) {
        SyncState.localOnly => l10n.t('syncLocalOnly'),
        SyncState.queued => l10n.t('syncQueued'),
        SyncState.synced => l10n.t('syncSynced'),
        SyncState.blocked => l10n.t('syncBlocked'),
        SyncState.failed => l10n.t('syncFailed')
      };
}

// — Shared error state for async sections ————————————————————

class _SectionError extends StatelessWidget {
  const _SectionError({required this.retry});
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(children: [
      const Icon(Icons.error_outline, size: 24),
      const SizedBox(height: 6),
      Text(l10n.t('error'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      OutlinedButton(
          onPressed: retry,
          child: Text(l10n.t('retry')))
    ]);
  }
}
