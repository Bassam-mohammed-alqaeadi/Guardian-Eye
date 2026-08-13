import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/platform/capability_gateway.dart';
import '../../domain/child_device_enforcement.dart';
import '../../domain/guardian_models.dart';
import '../../application/family_context_provider.dart';
import 'permissions_screen.dart';

class ChildDeviceStatusScreen extends ConsumerWidget {
  const ChildDeviceStatusScreen({required this.familyId, super.key});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final states = ref.watch(childDeviceStatesProvider(familyId));
    final capabilities = ref.watch(capabilityStatusProvider);
    return Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
            appBar: AppBar(title: Text(l10n.t('childDeviceStatus'))),
            body: states.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                    child: FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(childDeviceStatesProvider(familyId)),
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.t('retry')))),
                data: (devices) => RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(childDeviceStatesProvider(familyId)),
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      Card(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(l10n.t('childEnforcementNotice')))),
                      const SizedBox(height: 16),
                      _CapabilitySummary(capabilities: capabilities),
                      const SizedBox(height: 16),
                      if (devices.isEmpty)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(l10n.t('noChildDevices'))))
                      else
                        ...devices.map((state) =>
                            _DeviceCard(state: state, familyId: familyId)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const PermissionsScreen())),
                          icon: const Icon(Icons.tune),
                          label: Text(l10n.t('permissions')))
                    ])))));
  }
}

class _CapabilitySummary extends StatelessWidget {
  const _CapabilitySummary({required this.capabilities});
  final AsyncValue<List<CapabilityStatus>> capabilities;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return capabilities.when(
        loading: () => const Card(
            child: Padding(
                padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
        error: (_, __) => Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.t('capabilityNotReady')))),
        data: (items) {
          final usage = items.where(
              (item) => item.capability == GuardianCapability.usageStats);
          final ready = usage.isNotEmpty &&
              usage.single.granted &&
              usage.single.supported;
          return Card(
              child: ListTile(
                  leading: Icon(
                      ready ? Icons.verified_outlined : Icons.info_outline,
                      color: ready
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.tertiary),
                  title: Text(l10n.t('usageStats')),
                  subtitle: Text(ready
                      ? l10n.t('usageStatsReady')
                      : l10n.t('usageStatsConsentRequired'))));
        });
  }
}

class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.state, required this.familyId});
  final ChildDeviceState state;
  final String familyId;

  String _lifecycle(AppLocalizations l10n) => switch (state.lifecycle) {
        ChildDeviceLifecycle.unlinked => l10n.t('deviceUnlinked'),
        ChildDeviceLifecycle.pairingPending => l10n.t('devicePairingPending'),
        ChildDeviceLifecycle.enrolled => l10n.t('deviceEnrolled'),
        ChildDeviceLifecycle.active => l10n.t('deviceActive'),
        ChildDeviceLifecycle.offline => l10n.t('deviceOffline'),
        ChildDeviceLifecycle.restricted => l10n.t('deviceRestricted'),
        ChildDeviceLifecycle.suspended => l10n.t('deviceSuspended'),
        ChildDeviceLifecycle.revoked => l10n.t('deviceRevoked'),
        ChildDeviceLifecycle.recovering => l10n.t('deviceRecovering'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final usage = ref.watch(childUsageForTodayProvider(state.deviceId));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.phonelink_lock_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_lifecycle(l10n),
                        style: theme.textTheme.titleMedium)),
              ]),
              const SizedBox(height: 12),
              _StatusLine(
                  label: l10n.t('policyVersion'),
                  value: '${state.requiredPolicyVersion}'),
              _StatusLine(
                  label: l10n.t('lastValidPolicy'),
                  value: state.lastValidPolicyAt?.toLocal().toString() ??
                      l10n.t('noData')),
              _StatusLine(
                  label: l10n.t('lastEvaluation'),
                  value: state.lastEvaluationAt?.toLocal().toString() ??
                      l10n.t('noEvaluation')),
              _StatusLine(
                  label: l10n.t('enforcementDecision'),
                  value: state.lastDecision?.name ?? l10n.t('noData')),
              const SizedBox(height: 10),
              Text(l10n.t('screenTimeToday'),
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              usage.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => Text(l10n.t('error')),
                  data: (summaries) => summaries.isEmpty
                      ? Text(l10n.t('screenTimeNoUsage'))
                      : Column(
                          children: summaries
                              .take(4)
                              .map((summary) => _StatusLine(
                                  label: summary.target,
                                  value:
                                      '${summary.totalDuration.inMinutes} min'))
                              .toList())),
              const SizedBox(height: 8),
              if (state.lifecycle == ChildDeviceLifecycle.active ||
                  state.lifecycle == ChildDeviceLifecycle.enrolled)
                _UnlinkAction(
                    familyId: familyId,
                    deviceId: state.deviceId,
                    ownerMemberId: state.memberId),
              OutlinedButton.icon(
                  onPressed: state.lifecycle == ChildDeviceLifecycle.revoked
                      ? null
                      : () async {
                          final report = await ref
                              .read(childScreenTimeCoordinatorProvider)
                              .evaluateNow(state.deviceId);
                          ref.invalidate(
                              childUsageForTodayProvider(state.deviceId));
                          if (!context.mounted) return;
                          final requested = report.targets.any((target) =>
                              target.evaluation.status.name ==
                              'enforcementRequested');
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(requested
                                  ? l10n.t('enforcementUnsupported')
                                  : l10n.t('screenTimeMeasured'))));
                        },
                  icon: const Icon(Icons.query_stats_outlined),
                  label: Text(l10n.t('screenTimeEvaluate'))),
              if (state.failureCode != null)
                _StatusLine(
                    label: l10n.t('statusReason'), value: state.failureCode!)
            ])));
  }
}

class _UnlinkAction extends ConsumerWidget {
  const _UnlinkAction(
      {required this.familyId, required this.deviceId, required this.ownerMemberId});

  final String familyId;
  final String deviceId;
  final String ownerMemberId;

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ctx =
        ref.read(familyRuntimeContextProvider(familyId)).asData?.value;
    final authorized =
        ctx != null && ctx.can(FamilyPermission.manageDevices);
    if (!authorized) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('unauthorizedActorBody'))));
      return;
    }
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(l10n.t('unlinkConfirmTitle')),
              content: Text(l10n.t('unlinkConfirmBody')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.t('unlinkCancel'))),
                FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(l10n.t('unlinkDevice'))),
              ],
            ));
    if (confirmed != true) return;
    final removed = await ref
        .read(pairingRepositoryProvider)
        .revokeDevice(deviceId: deviceId, ownerMemberId: ownerMemberId);
    if (!context.mounted) return;
    ref.invalidate(childDeviceStatesProvider(familyId));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(removed
            ? l10n.t('unlinkConfirmed')
            : l10n.t('unknownRedeemErrorBody'))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
            onPressed: () => _unlink(context, ref),
            icon: const Icon(Icons.phonelink_erase_outlined),
            label: Text(l10n.t('unlinkDevice'))));
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.end))
      ]));
}
