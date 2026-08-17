import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/child_device_enforcement.dart';
import '../../domain/child_exception_request.dart';
import '../../domain/family_safety_experience.dart';
import '../../domain/guardian_models.dart';
import '../../domain/policy_engine.dart';
import '../../domain/screen_time.dart';

class FamilyDailySafetyScreen extends ConsumerWidget {
  const FamilyDailySafetyScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final snapshots = ref.watch(familyDailySafetyProvider(familyId));
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(
                title: Text(l10n.t('dailySafety')),
                actions: [
                  IconButton(
                      tooltip: l10n.t('safetyTimeline'),
                      onPressed: () => context.push('/timeline/$familyId'),
                      icon: const Icon(Icons.history_outlined))
                ]),
            body: snapshots.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Retry(onRetry: () =>
                    ref.invalidate(familyDailySafetyProvider(familyId))),
                data: (items) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(familyDailySafetyProvider(familyId));
                      ref.invalidate(familyExceptionRequestsProvider(familyId));
                    },
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      _Notice(text: l10n.t('exceptionUnsupportedNotice')),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                      onPressed: () => context.push('/requests/$familyId'),
                          icon: const Icon(Icons.inbox_outlined),
                          label: Text(l10n.t('reviewRequests'))),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        _Notice(text: l10n.t('noChildren'))
                      else
                        ...items.map((item) => _ParentChildDailyCard(snapshot: item))
                    ])))));
  }
}

class _ParentChildDailyCard extends ConsumerWidget {
  const _ParentChildDailyCard({required this.snapshot});
  final ChildDailySafetySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final overrides = snapshot.activeOverrides
        .where((override) => override.childDeviceId == null ||
            snapshot.devices.any((device) => device.deviceId == override.childDeviceId))
        .toList(growable: false);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(snapshot.child.displayName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _Line(label: l10n.t('currentPolicy'), value: snapshot.policies.isEmpty
                  ? l10n.t('noActivePolicy')
                  : snapshot.policies.where((item) => item.enabled).map((item) => item.name).join(', ')),
              _Line(label: l10n.t('pendingRequests'), value: '${snapshot.pendingRequests.length}'),
              _Line(label: l10n.t('syncQueue'), value: '${snapshot.queuedOperations}'),
              _Line(label: l10n.t('activeException'), value: overrides.isEmpty
                  ? l10n.t('noActiveException')
                  : overrides.map((item) => item.target).join(', ')),
              const Divider(height: 24),
              if (snapshot.devices.isEmpty)
                Text(l10n.t('noChildDevices'))
              else
                ...snapshot.devices.map((device) => _ParentDeviceSummary(device: device)),
            ])));
  }
}

class _ParentDeviceSummary extends StatelessWidget {
  const _ParentDeviceSummary({required this.device});
  final ChildDeviceDailySafety device;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Line(label: l10n.t('childDeviceStatus'), value: device.state == null
              ? l10n.t('noData')
              : _lifecycleText(l10n, device.state!.lifecycle)),
          _Line(label: l10n.t('policyVersion'), value:
              device.state == null ? l10n.t('noData') : '${device.state!.requiredPolicyVersion}'),
          _Line(label: l10n.t('lastEvaluation'), value: device.state?.lastEvaluationAt == null
              ? l10n.t('notMeasuredYet')
              : device.state!.lastEvaluationAt!.toLocal().toString()),
          Text(l10n.t('screenTimeToday'), style: Theme.of(context).textTheme.titleSmall),
          if (device.usage.isEmpty)
            Text(l10n.t('notMeasuredYet'))
          else
            ...device.usage.map((usage) => _Line(
                label: usage.target,
                value: '${usage.totalDuration.inMinutes} min')),
        ]));
  }
}

class ParentExceptionRequestsScreen extends ConsumerWidget {
  const ParentExceptionRequestsScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final requests = ref.watch(familyExceptionRequestsProvider(familyId));
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(title: Text(l10n.t('reviewRequests'))),
            body: requests.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Retry(onRetry: () =>
                    ref.invalidate(familyExceptionRequestsProvider(familyId))),
                data: (items) => SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                  _Notice(text: l10n.t('exceptionUnsupportedNotice')),
                  const SizedBox(height: 12),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(l10n.t('approvalNature'),
                          style: Theme.of(context).textTheme.bodySmall)),
                  if (items.isEmpty)
                    _Notice(text: l10n.t('noRequests'))
                  else
                    ...items.map((request) => _ParentRequestCard(request: request))
                ])))));
  }
}

class _ParentRequestCard extends ConsumerStatefulWidget {
  const _ParentRequestCard({required this.request});
  final ChildExceptionRequest request;

  @override
  ConsumerState<_ParentRequestCard> createState() => _ParentRequestCardState();
}

class _ParentRequestCardState extends ConsumerState<_ParentRequestCard> {
  bool _saving = false;

  Future<void> _review(bool approve) async {
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      final parent = await ref
          .read(policyRepositoryProvider)
          .primaryParentMemberId(widget.request.familyId);
      if (approve) {
        await ref.read(childExceptionRequestRepositoryProvider).approve(
            requestId: widget.request.id, parentMemberId: parent);
      } else {
        await ref.read(childExceptionRequestRepositoryProvider).deny(
            requestId: widget.request.id, parentMemberId: parent);
      }
      ref.invalidate(familyExceptionRequestsProvider(widget.request.familyId));
      ref.invalidate(familyDailySafetyProvider(widget.request.familyId));
      ref.invalidate(familySafetyTimelineProvider(widget.request.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('requestDecisionSaved'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final l10n = AppLocalizations.of(context);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.target, style: Theme.of(context).textTheme.titleMedium),
              _Line(label: l10n.t('requestDuration'), value: '${request.requestedDuration.inMinutes} min'),
              _Line(label: l10n.t('requestReason'), value: _reasonText(l10n, request.reason)),
              if (request.reasonDetail?.isNotEmpty == true)
                _Line(label: l10n.t('reasonDetail'), value: request.reasonDetail!),
              _Line(label: l10n.t('statusReason'), value: _requestStatusText(l10n, request.status)),
              _Line(label: l10n.t('syncQueue'), value: _syncText(l10n, request.syncState)),
              if (request.status == ChildExceptionRequestStatus.approved && request.expiresAt != null)
                _Line(label: l10n.t('temporaryExceptionUntil'), value: request.expiresAt!.toLocal().toString()),
              if (request.status == ChildExceptionRequestStatus.pending) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(
                      onPressed: _saving ? null : () => _review(false),
                      child: Text(l10n.t('denyRequest')))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(
                      onPressed: _saving ? null : () => _review(true),
                      child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.t('approveRequest'))))
                ])
              ]
            ])));
  }
}

class ChildPolicyExperienceScreen extends ConsumerStatefulWidget {
  const ChildPolicyExperienceScreen(
      {required this.familyId,
      required this.deviceId,
      required this.childUid,
      super.key});
  final String familyId;
  final String deviceId;
  final String childUid;

  @override
  ConsumerState<ChildPolicyExperienceScreen> createState() => _ChildPolicyExperienceScreenState();
}

class _ChildPolicyExperienceScreenState extends ConsumerState<ChildPolicyExperienceScreen> {
  final _duration = TextEditingController(text: '15');
  final _detail = TextEditingController();
  ChildExceptionReason _reason = ChildExceptionReason.homework;
  String? _target;
  bool _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final l10n = AppLocalizations.of(context);
    final minutes = int.tryParse(_duration.text.trim());
    if (_target == null || minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('validationRequired'))));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(childExceptionRequestRepositoryProvider).create(
          familyId: widget.familyId,
          childDeviceId: widget.deviceId,
          childUid: widget.childUid,
          target: _target!,
          duration: Duration(minutes: minutes),
          reason: _reason,
          reasonDetail: _reason == ChildExceptionReason.other ? _detail.text : null);
      ref.invalidate(childExceptionRequestsProvider(
          (familyId: widget.familyId, deviceId: widget.deviceId, childUid: widget.childUid)));
      ref.invalidate(familySafetyTimelineProvider(widget.familyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('requestSavedLocal'))));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('error'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = (familyId: widget.familyId, deviceId: widget.deviceId, childUid: widget.childUid);
    final stateAsync = ref.watch(childDeviceStatesProvider(widget.familyId));
    final policies = ref.watch(deliveredChildPoliciesProvider(widget.deviceId));
    final usage = ref.watch(childUsageForTodayProvider(widget.deviceId));
    final requests = ref.watch(childExceptionRequestsProvider(scope));
    final capabilities = ref.watch(capabilityStatusProvider);
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(title: Text(l10n.t('childPolicy'))),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              _Notice(text: l10n.t('childPolicyExplanation')),
              const SizedBox(height: 12),
              stateAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => _Notice(text: l10n.t('error')),
                  data: (states) {
                    final state = states.where((item) => item.deviceId == widget.deviceId).firstOrNull;
                    return _Notice(text: state == null ? l10n.t('noData') : _lifecycleText(l10n, state.lifecycle));
                  }),
              const SizedBox(height: 12),
              _UsageAccessCard(capabilities: capabilities),
              const SizedBox(height: 12),
              policies.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => _Notice(text: l10n.t('error')),
                  data: (deliveries) {
                    final targets = deliveries.expand((item) => item.policy.restrictedTargets).toSet().toList()..sort();
                    _target ??= targets.firstOrNull;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.t('currentPolicy'), style: Theme.of(context).textTheme.titleLarge),
                      if (deliveries.isEmpty) _Notice(text: l10n.t('noActivePolicy')) else ...deliveries.map((delivery) => _PolicyExplanationCard(policy: delivery.policy)),
                      const SizedBox(height: 12),
                      usage.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => _Notice(text: l10n.t('error')),
                          data: (items) => _UsageExplanationCard(usage: items, policies: deliveries.map((item) => item.policy).toList())),
                      const SizedBox(height: 12),
                      requests.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => _Notice(text: l10n.t('error')),
                          data: (items) => _RequestList(items: items)),
                      const SizedBox(height: 12),
                      if (targets.isNotEmpty) _RequestForm(
                          targets: targets,
                          target: _target,
                          onTargetChanged: (value) => setState(() => _target = value),
                          duration: _duration,
                          detail: _detail,
                          reason: _reason,
                          onReasonChanged: (value) => setState(() => _reason = value),
                          saving: _saving,
                          onSubmit: _request)
                    ]);
                  })
            ])));
  }
}

class _PolicyExplanationCard extends StatelessWidget {
  const _PolicyExplanationCard({required this.policy});
  final DigitalPolicy policy;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(policy.name, style: Theme.of(context).textTheme.titleMedium),
      _Line(label: l10n.t('policyVersion'), value: '${policy.version}'),
      _Line(label: l10n.t('dailyLimitMinutes'), value: policy.dailyLimitMinutes == null ? l10n.t('noData') : '${policy.dailyLimitMinutes} min'),
      _Line(label: l10n.t('policyTargets'), value: policy.restrictedTargets.join(', ')),
      _Line(label: l10n.t('policyConfigured'), value: policy.enabled ? l10n.t('policyDelivered') : l10n.t('noActivePolicy'))
    ])));
  }
}

class _UsageExplanationCard extends StatelessWidget {
  const _UsageExplanationCard({required this.usage, required this.policies});
  final List<DailyUsageSummary> usage;
  final List<DigitalPolicy> policies;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('screenTimeToday'), style: Theme.of(context).textTheme.titleMedium),
      if (usage.isEmpty) Text(l10n.t('notMeasuredYet')) else ...usage.map((item) {
        final limit = policies.where((policy) => policy.restrictedTargets.contains(item.target) && policy.dailyLimitMinutes != null).map((policy) => policy.dailyLimitMinutes!).fold<int?>(null, (current, value) => current == null || value < current ? value : current);
        final remaining = limit == null ? null : Duration(minutes: limit).inMinutes - item.totalDuration.inMinutes;
        return Column(children: [
          _Line(label: item.target, value: '${item.totalDuration.inMinutes} min'),
          _Line(label: l10n.t('remainingTime'), value: remaining == null ? l10n.t('noData') : '${remaining < 0 ? 0 : remaining} min')
        ]);
      })
    ])));
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({required this.targets, required this.target, required this.onTargetChanged, required this.duration, required this.detail, required this.reason, required this.onReasonChanged, required this.saving, required this.onSubmit});
  final List<String> targets;
  final String? target;
  final ValueChanged<String?> onTargetChanged;
  final TextEditingController duration;
  final TextEditingController detail;
  final ChildExceptionReason reason;
  final ValueChanged<ChildExceptionReason> onReasonChanged;
  final bool saving;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('requestAdditionalTime'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: target, decoration: InputDecoration(labelText: l10n.t('policyTargets')), items: targets.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: onTargetChanged),
      TextField(controller: duration, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.t('requestDuration'))),
      DropdownButtonFormField<ChildExceptionReason>(initialValue: reason, decoration: InputDecoration(labelText: l10n.t('requestReason')), items: ChildExceptionReason.values.map((item) => DropdownMenuItem(value: item, child: Text(_reasonText(l10n, item)))).toList(), onChanged: (value) { if (value != null) onReasonChanged(value); }),
      if (reason == ChildExceptionReason.other) TextField(controller: detail, decoration: InputDecoration(labelText: l10n.t('reasonDetail'))),
      const SizedBox(height: 12),
      FilledButton(onPressed: saving ? null : onSubmit, child: saving ? const CircularProgressIndicator() : Text(l10n.t('submitRequest')))
    ])));
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.items});
  final List<ChildExceptionRequest> items;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) return _Notice(text: l10n.t('noRequests'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.t('pendingRequests'), style: Theme.of(context).textTheme.titleMedium),
      ...items.map((item) => Card(child: ListTile(
          title: Text(item.target),
          subtitle: Text('${_requestStatusText(l10n, item.status)} · ${_syncText(l10n, item.syncState)}${item.expiresAt == null ? '' : ' · ${l10n.t('temporaryExceptionUntil')} ${item.expiresAt!.toLocal()}'}'))))
    ]);
  }
}

class FamilySafetyTimelineScreen extends ConsumerWidget {
  const FamilySafetyTimelineScreen({required this.familyId, super.key});
  final String familyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timeline = ref.watch(familySafetyTimelineProvider(familyId));
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(title: Text(l10n.t('safetyTimeline'))),
            body: timeline.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _Retry(
                    onRetry: () =>
                        ref.invalidate(familySafetyTimelineProvider(familyId))),
                data: (events) => events.isEmpty
                    ? Center(child: Text(l10n.t('noData')))
                    : ListView.builder(
                        itemCount: events.length,
                        itemBuilder: (_, index) {
                          final event = events[index];
                          return ListTile(
                              leading: const Icon(Icons.circle_outlined),
                              title: Text(l10n.t(event.titleKey)),
                              subtitle: Text(
                                  '${event.occurredAt.toLocal()} · ${_syncText(l10n, event.syncState)}${event.detail == null ? '' : ' · ${event.detail}'}'));
                        }))));
  }
}

class _UsageAccessCard extends StatelessWidget {
  const _UsageAccessCard({required this.capabilities});
  final AsyncValue<List<dynamic>> capabilities;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return capabilities.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => _Notice(text: l10n.t('capabilityNotReady')),
        data: (items) { final usage = items.where((item) => item.capability.name == 'usageStats'); final ready = usage.isNotEmpty && usage.single.granted && usage.single.supported; return _Notice(text: ready ? l10n.t('usageStatsReady') : l10n.t('usageStatsConsentRequired')); });
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Text(text)));
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)), const SizedBox(width: 8), Expanded(child: Text(value, textAlign: TextAlign.end))]));
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(AppLocalizations.of(context).t('retry'))));
}

String _syncText(AppLocalizations l10n, SyncState state) => switch (state) {
  SyncState.localOnly => l10n.t('syncLocalOnly'),
  SyncState.queued => l10n.t('syncQueued'),
  SyncState.synced => l10n.t('syncSynced'),
  SyncState.blocked => l10n.t('syncBlocked'),
  SyncState.failed => l10n.t('syncFailed')
};
String _requestStatusText(AppLocalizations l10n, ChildExceptionRequestStatus status) => switch (status) {
  ChildExceptionRequestStatus.pending => l10n.t('requestPending'),
  ChildExceptionRequestStatus.approved => l10n.t('requestApproved'),
  ChildExceptionRequestStatus.denied => l10n.t('requestDenied'),
  ChildExceptionRequestStatus.expired => l10n.t('requestExpired'),
  ChildExceptionRequestStatus.cancelled => l10n.t('requestCancelled')
};
String _reasonText(AppLocalizations l10n, ChildExceptionReason reason) => switch (reason) {
  ChildExceptionReason.homework => l10n.t('reasonHomework'),
  ChildExceptionReason.schoolAssignment => l10n.t('reasonSchoolAssignment'),
  ChildExceptionReason.familyActivity => l10n.t('reasonFamilyActivity'),
  ChildExceptionReason.importantCommunication => l10n.t('reasonImportantCommunication'),
  ChildExceptionReason.other => l10n.t('reasonOther')
};
String _lifecycleText(AppLocalizations l10n, ChildDeviceLifecycle lifecycle) => switch (lifecycle) {
  ChildDeviceLifecycle.unlinked => l10n.t('deviceUnlinked'),
  ChildDeviceLifecycle.pairingPending => l10n.t('devicePairingPending'),
  ChildDeviceLifecycle.enrolled => l10n.t('deviceEnrolled'),
  ChildDeviceLifecycle.active => l10n.t('deviceActive'),
  ChildDeviceLifecycle.offline => l10n.t('deviceOffline'),
  ChildDeviceLifecycle.restricted => l10n.t('deviceRestricted'),
  ChildDeviceLifecycle.suspended => l10n.t('deviceSuspended'),
  ChildDeviceLifecycle.revoked => l10n.t('deviceRevoked'),
  ChildDeviceLifecycle.recovering => l10n.t('deviceRecovering')
};
