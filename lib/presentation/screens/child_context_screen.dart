import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../application/child_context_provider.dart';
import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/child_device_enforcement.dart';
import '../../domain/guardian_models.dart';

/// The child-context vertical (M3).
///
/// One honest surface per child: who the child is, what the local
/// enforcement layer knows about their device, family-level incident
/// context, and today's screen-time totals. Everything is a read; all
/// mutating actions are deferred (Coming soon — honest placeholders) so
/// no screen ever pretends to enforce anything it does not.
///
/// Authorization is consulted, never re-implemented: gated actions read
/// [FamilyRuntimeContext.can] and render disabled when the actor is not
/// verified, exactly as M2 does on the dashboard.
class ChildContextScreen extends ConsumerWidget {
  const ChildContextScreen(
      {super.key, required this.familyId, required this.childId});

  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final direction = l10n.isRtl ? TextDirection.rtl : TextDirection.ltr;

    final snapshot = ref.watch(
        childContextProvider((familyId: familyId, childId: childId)));

    return Directionality(
      textDirection: direction,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('childContext')),
          leading: BackButton(onPressed: () => context.pop()),
        ),
        body: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.t('pageNotFoundBody'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(childContextProvider(
                          (familyId: familyId, childId: childId)));
                    },
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(l10n.t('retry')),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final contextRef = ref.watch(
                familyRuntimeContextProvider(familyId));
            final canAct = contextRef.valueOrNull
                    ?.can(FamilyPermission.viewChildStatus) ??
                false;
            return _ChildContextBody(
                snapshot: data, canAct: canAct);
          },
        ),
      ),
    );
  }
}

class _ChildContextBody extends StatelessWidget {
  const _ChildContextBody({required this.snapshot, required this.canAct});
  final ChildContextSnapshot snapshot;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _IdentityCard(child: snapshot.child),
        const SizedBox(height: 12),
        if (snapshot.deviceState == null)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(l10n.t('noDevicesLinked'),
                              style: theme.textTheme.bodyLarge)),
                    ],
                  )))
        else
          _DeviceCard(state: snapshot.deviceState!, canAct: canAct),
        const SizedBox(height: 12),
        _SafetyCard(
            incidents: snapshot.recentIncidents, canAct: canAct),
        const SizedBox(height: 12),
        _ActivityCard(
            totalMinutes: snapshot.todayUsage.totalMinutes,
            hasDevice: snapshot.deviceState != null,
            canAct: canAct),
        const SizedBox(height: 20),
        const _ComingSoonSection(),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_outlined),
            label: Text(l10n.t('backToDashboard')),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.child});
  final FamilyMember child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
                radius: 24,
                child: Text(child.displayName.characters.first)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child.displayName,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(l10n.t('roleChild'),
                      style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.state, required this.canAct});
  final ChildDeviceState state;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lifecycleName = state.lifecycle.name;
    final syncText = state.lastSyncAt == null
        ? l10n.t('lastSyncNever')
        : '${l10n.t('lastSyncAt')} '
            '· ${_compactTime(state.lastSyncAt!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      l10n.t(
                          'device${lifecycleName[0].toUpperCase() + lifecycleName.substring(1)}'),
                      style: theme.textTheme.titleMedium),
                ),
                if (!canAct)
                  const Icon(Icons.lock_outline,
                      size: 18, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            if (!canAct)
              Text(l10n.t('actorVerificationRequired'),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error))
            else
              const SizedBox.shrink(),
            const SizedBox(height: 8),
            Text(syncText, style: theme.textTheme.bodySmall),
            if (state.lastValidPolicyAt != null)
              Text(
                  '${l10n.t('lastValidPolicy')} '
                  '· ${_compactDate(state.lastValidPolicyAt!)}',
                  style: theme.textTheme.bodySmall),
            if (state.lastEvaluationAt != null)
              Text(
                  '${l10n.t('lastEvaluation')} '
                  '· ${_compactDate(state.lastEvaluationAt!)}',
                  style: theme.textTheme.bodySmall),
            Text(
                '${l10n.t('policyVersion')} ${state.requiredPolicyVersion}',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.incidents, required this.canAct});
  final List<GuardianIncident> incidents;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.t('safetySignal'),
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.t('familyLevelIncidents'),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (incidents.isEmpty)
              Text(l10n.t('noRecentIncidents'),
                  style: theme.textTheme.bodyMedium)
            else
              ...incidents.map((incident) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                              '${l10n.t('severity${_cap(incident.severity)}')} · '
                              '${l10n.t('category${_cap(incident.category)}')}'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              _compactDateTime(incident.observedAt),
                              style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  )),
            if (!canAct)
              Text(l10n.t('actorVerificationRequired'),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error)),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard(
      {required this.totalMinutes,
      required this.hasDevice,
      required this.canAct});
  final int? totalMinutes;
  final bool hasDevice;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final valueText = !hasDevice
        ? l10n.t('noDevicesLinked')
        : (totalMinutes == null
            ? l10n.t('screenTimeUnavailable')
            : '$totalMinutes min');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.t('activitySummary'),
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${l10n.t('todayScreenTime')} $valueText',
                style: theme.textTheme.bodyLarge),
            Text(l10n.t('screenTimeMeasured'),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonSection extends StatelessWidget {
  const _ComingSoonSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
        color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.t('comingSoonSection'),
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
              ...[
              ('bedtime', Icons.bedtime_outlined),
              ('webFiltering', Icons.filter_list_outlined),
              ('locationTracking', Icons.place_outlined),
              ('deviceControls', Icons.settings_cell_outlined),
              ('weeklyReports', Icons.insights_outlined),
              ('sosAlerts', Icons.emergency_outlined),
              ('aiMonitoring', Icons.psychology_outlined),
            ].map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(row.$2),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.t(row.$1),
                            style: theme.textTheme.bodyMedium),
                      ),
                      Text(l10n.t('comingSoon'),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

String _cap(Enum value) =>
    value.name[0].toUpperCase() + value.name.substring(1);

String _compactTime(DateTime at) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')}';

String _compactDate(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';

String _compactDateTime(DateTime at) =>
    '${_compactDate(at)} ${_compactTime(at)}';
