import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';
import '../../domain/guardian_models.dart';
import '../../domain/policy_engine.dart';

class SafetyPoliciesScreen extends ConsumerStatefulWidget {
  const SafetyPoliciesScreen({required this.familyId, super.key});
  final String familyId;

  @override
  ConsumerState<SafetyPoliciesScreen> createState() =>
      _SafetyPoliciesScreenState();
}

class _SafetyPoliciesScreenState extends ConsumerState<SafetyPoliciesScreen> {
  static const _targets = ['video', 'social', 'games', 'browser'];
  List<DigitalPolicy> _policies = const [];
  List<StoredPolicyOverride> _overrides = const [];
  String _decisionTarget = 'video';
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
      final repository = ref.read(policyRepositoryProvider);
      final results = await Future.wait([
        repository.forFamily(widget.familyId),
        repository.overridesForFamily(widget.familyId),
      ]);
      if (!mounted) return;
      setState(() {
        _policies = results[0] as List<DigitalPolicy>;
        _overrides = results[1] as List<StoredPolicyOverride>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TemporaryOverride? _overrideFor(String target) {
    final now = DateTime.now().toUtc();
    for (final override in _overrides) {
      if (override.target == target && override.isActiveAt(now)) {
        return override;
      }
    }
    return null;
  }

  PolicyDecision _decisionFor(String target) => const PolicyEngine().resolve(
      target: target,
      moment: DateTime.now(),
      policies: _policies,
      override: _overrideFor(target));

  String _targetLabel(AppLocalizations l10n, String target) => l10n.t(target);

  String _syncLabel(AppLocalizations l10n, SyncState state) => switch (state) {
        SyncState.localOnly => l10n.t('syncLocalOnly'),
        SyncState.queued => l10n.t('syncQueued'),
        SyncState.synced => l10n.t('syncSynced'),
        SyncState.blocked => l10n.t('syncBlocked'),
        SyncState.failed => l10n.t('syncFailed'),
      };

  String _timeLabel(BuildContext context, int minute) {
    final time = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _openEditor([DigitalPolicy? existing]) async {
    final l10n = AppLocalizations.of(context);
    final name = TextEditingController(text: existing?.name ?? '');
    final priority = TextEditingController(text: '${existing?.priority ?? 50}');
    final dailyLimit = TextEditingController(
        text: existing?.dailyLimitMinutes?.toString() ?? '');
    final packageTarget = TextEditingController();
    var start = TimeOfDay(
        hour: (existing?.startMinute ?? 1260) ~/ 60,
        minute: (existing?.startMinute ?? 1260) % 60);
    var end = TimeOfDay(
        hour: (existing?.endMinute ?? 420) ~/ 60,
        minute: (existing?.endMinute ?? 420) % 60);
    var enabled = existing?.enabled ?? true;
    final selected = <String>{...?existing?.restrictedTargets};
    var saving = false;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(sheetContext).viewInsets.bottom + 24),
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          existing == null
                              ? l10n.t('createPolicy')
                              : l10n.t('editPolicy'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration:
                              InputDecoration(labelText: l10n.t('policyName'))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: priority,
                          keyboardType: TextInputType.number,
                          decoration:
                              InputDecoration(labelText: l10n.t('priority'))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: dailyLimit,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: l10n.t('dailyLimitMinutes'))),
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
                                    '${l10n.t('startTime')}: ${MaterialLocalizations.of(sheetContext).formatTimeOfDay(start)}'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () async {
                                  final picked = await showTimePicker(
                                      context: sheetContext, initialTime: end);
                                  if (picked != null) {
                                    setSheetState(() => end = picked);
                                  }
                                },
                                child: Text(
                                    '${l10n.t('endTime')}: ${MaterialLocalizations.of(sheetContext).formatTimeOfDay(end)}'))),
                      ]),
                      const SizedBox(height: 12),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(l10n.t('policyTargets'))),
                      Wrap(
                          spacing: 8,
                          children: _targets
                              .map((target) => FilterChip(
                                  label: Text(_targetLabel(l10n, target)),
                                  selected: selected.contains(target),
                                  onSelected: (isSelected) => setSheetState(() {
                                        isSelected
                                            ? selected.add(target)
                                            : selected.remove(target);
                                      })))
                              .toList()),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: packageTarget,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                    labelText: l10n.t('policyPackageId')))),
                        const SizedBox(width: 8),
                        IconButton(
                            tooltip: l10n.t('addPolicyTarget'),
                            onPressed: () {
                              final target = packageTarget.text.trim();
                              if (target.contains('.')) {
                                setSheetState(() {
                                  selected.add(target);
                                  packageTarget.clear();
                                });
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline))
                      ]),
                      if (selected.any((target) => target.contains('.')))
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(selected
                                .where((target) => target.contains('.'))
                                .join(', '))),
                      SwitchListTile(
                          value: enabled,
                          onChanged: (value) =>
                              setSheetState(() => enabled = value),
                          title: Text(l10n.t('policyEnabled'))),
                      const SizedBox(height: 8),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final parsedPriority =
                                      int.tryParse(priority.text);
                                  final parsedDailyLimit =
                                      dailyLimit.text.trim().isEmpty
                                          ? null
                                          : int.tryParse(
                                              dailyLimit.text.trim());
                                  if (name.text.trim().isEmpty ||
                                      parsedPriority == null ||
                                      selected.isEmpty ||
                                      (dailyLimit.text.trim().isNotEmpty &&
                                          (parsedDailyLimit == null ||
                                              !selected.any((target) =>
                                                  target.contains('.'))))) {
                                    _message(l10n.t('validationRequired'));
                                    return;
                                  }
                                  setSheetState(() => saving = true);
                                  try {
                                    final repository =
                                        ref.read(policyRepositoryProvider);
                                    if (existing == null) {
                                      await repository.save(
                                          familyId: widget.familyId,
                                          name: name.text,
                                          priority: parsedPriority,
                                          enabled: enabled,
                                          startMinute:
                                              start.hour * 60 + start.minute,
                                          endMinute: end.hour * 60 + end.minute,
                                          restrictedTargets: selected,
                                          dailyLimitMinutes: parsedDailyLimit);
                                    } else {
                                      await repository.update(
                                          existing: existing,
                                          name: name.text,
                                          priority: parsedPriority,
                                          enabled: enabled,
                                          startMinute:
                                              start.hour * 60 + start.minute,
                                          endMinute: end.hour * 60 + end.minute,
                                          restrictedTargets: selected,
                                          dailyLimitMinutes: parsedDailyLimit);
                                    }
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    if (mounted) {
                                      _message(l10n.t('policySavedLocal'));
                                      await _load();
                                    }
                                  } catch (_) {
                                    if (mounted) _message(l10n.t('error'));
                                  } finally {
                                    if (sheetContext.mounted) {
                                      setSheetState(() => saving = false);
                                    }
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator())
                              : Text(l10n.t('savePolicy')))
                    ]),
                  ),
                )));
    name.dispose();
    priority.dispose();
    dailyLimit.dispose();
    packageTarget.dispose();
  }

  Future<void> _createOneHourOverride() async {
    final l10n = AppLocalizations.of(context);
    final target = _decisionTarget;
    try {
      final repository = ref.read(policyRepositoryProvider);
      final parentId = await repository.primaryParentMemberId(widget.familyId);
      await repository.createOverride(
          familyId: widget.familyId,
          createdByMemberId: parentId,
          target: target,
          allowed: true,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)));
      _message(l10n.t('overrideCreated'));
      await _load();
    } catch (_) {
      _message(l10n.t('error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decision = _decisionFor(_decisionTarget);
    final override = _overrideFor(_decisionTarget);
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.t('safetyPolicies'))),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: Text(l10n.t('createPolicy'))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? GuardianStateView(
                    state: GuardianViewState.error,
                    onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      GuardianCard(
                          color: GuardianTokens.statusWatchSoft,
                          child: Row(children: [
                            GuardianIconBadge(
                                icon: Icons.info_outline,
                                background: GuardianTokens.statusWatch,
                                size: 36),
                            const SizedBox(width: 12),
                            Expanded(child: Text(l10n.t('policyNotDeviceEnforced'))),
                          ])),
                      const SizedBox(height: 16),
                      Text(l10n.t('policyExplanation'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                          initialValue: _decisionTarget,
                          items: _targets
                              .map((target) => DropdownMenuItem(
                                  value: target,
                                  child: Text(_targetLabel(l10n, target))))
                              .toList(),
                          onChanged: (value) => setState(() =>
                              _decisionTarget = value ?? _decisionTarget)),
                      const SizedBox(height: 8),
                      GuardianCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  GuardianIconBadge(
                                      icon: decision.restricted
                                          ? Icons.block
                                          : Icons.verified_outlined,
                                      background: decision.restricted
                                          ? GuardianTokens.statusAlert
                                          : GuardianTokens.statusSafe,
                                      size: 36),
                                  const SizedBox(width: 10),
                                  GuardianStatusChip(
                                      label: decision.reason ==
                                              'temporary_override'
                                          ? l10n.t('allowedByOverride')
                                          : decision.restricted
                                              ? l10n.t('restrictedByPolicy')
                                              : l10n.t('noActivePolicy'),
                                      kind: decision.restricted
                                          ? GuardianStatusKind.alert
                                          : GuardianStatusKind.safe),
                                ]),
                                if (override != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      '${l10n.t('overrideUntil')}: ${override.expiresAt.toLocal()}',
                                      style: l10n.isRtl
                                          ? null
                                          : null),
                                ],
                              ])),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: _createOneHourOverride,
                          icon: const Icon(Icons.timer_outlined),
                          label: Text('${l10n.t('createOverride')} (+1h)')),
                      const SizedBox(height: 24),
                      Text(l10n.t('safetyPolicies'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (_policies.isEmpty)
                        GuardianStateView(
                            state: GuardianViewState.empty,
                            message: l10n.t('noPolicies'))
                      else
                        ..._policies.map((policy) => GuardianCard(
                            child: ListTile(
                                onTap: () => _openEditor(policy),
                                leading: GuardianIconBadge(
                                    icon: Icons.shield_outlined,
                                    background: policy.enabled
                                        ? GuardianTokens.guardianNavy
                                        : GuardianTokens.statusOffline),
                                title: Text(policy.name),
                                subtitle: Text(
                                    '${_timeLabel(context, policy.startMinute)} – ${_timeLabel(context, policy.endMinute)} · ${l10n.t('priority')}: ${policy.priority}${policy.dailyLimitMinutes == null ? '' : ' · ${l10n.t('dailyLimitMinutes')}: ${policy.dailyLimitMinutes}'}\n${policy.restrictedTargets.map((target) => _targetLabel(l10n, target)).join(', ')} · ${_syncLabel(l10n, policy.syncState)}'),
                                isThreeLine: true,
                                trailing: Switch(
                                    value: policy.enabled,
                                    onChanged: (enabled) async {
                                      try {
                                        await ref
                                            .read(policyRepositoryProvider)
                                            .setEnabled(
                                                existing: policy,
                                                enabled: enabled);
                                        await _load();
                                      } catch (_) {
                                        if (mounted) {
                                          _message(l10n.t('error'));
                                        }
                                      }
                                    }))))
                    ])),
      ),
    );
  }
}
