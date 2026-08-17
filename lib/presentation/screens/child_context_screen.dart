import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../application/child_context_provider.dart';
import '../../application/family_context_provider.dart';
import '../../data/family_actor_binding_service.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/child_device_enforcement.dart';
import '../../domain/child_exception_request.dart';
import '../../application/child_usage_measurement.dart';
import '../../domain/guardian_models.dart';
import '../../domain/screen_time.dart';
import '../../domain/policy_engine.dart';

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
            // SOS is a child emergency action: any verified active member of
            // the family may raise it (Firestore rules authorize `activeMember`
            // and `activeOwnedDevice` writes). Unlike parent-only management
            // permissions, the child itself must be able to trigger SOS.
            final memberVerified =
                contextRef.valueOrNull?.isVerified ?? false;
            // SOS is a child emergency action. The Trusted Actor Binding
            // deliberately refuses child roles (children are trusted through
            // their owned device), so a verified parent OR the child member
            // themselves (binding failure `remoteChildIdentity`) may raise it;
            // the Firestore rules enforce `activeMember`/`activeOwnedDevice`
            // on the actual write either way.
            final actorIsChildMember =
                contextRef.valueOrNull?.bindingFailure ==
                FamilyActorBindingFailure.remoteChildIdentity;
            return _ChildContextBody(
                familyId: familyId,
                childId: childId,
                snapshot: data,
                canAct: canAct,
                memberVerified: memberVerified,
                actorIsChildMember: actorIsChildMember);
          },
        ),
      ),
    );
  }
}

class _ChildContextBody extends ConsumerWidget {
  const _ChildContextBody(
      {required this.familyId,
      required this.childId,
      required this.snapshot,
      required this.canAct,
      required this.memberVerified,
      required this.actorIsChildMember});
  final String familyId;
  final String childId;
  final ChildContextSnapshot snapshot;
  final bool canAct;

  /// Verified active member of the family (any role) — SOS gate.
  final bool memberVerified;

  /// Authenticated actor is a child member of this family (the child on
  /// their own device) — the binding reports `remoteChildIdentity` for
  /// child roles by design, so this is the child-side SOS gate.
  final bool actorIsChildMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        if (snapshot.deviceState != null)
          _SosCard(
              familyId: familyId,
              deviceId: snapshot.deviceState!.deviceId,
              canSend: memberVerified || actorIsChildMember),
        const SizedBox(height: 12),
        if (snapshot.deviceState != null)
          _UsageMeasurementSection(
              deviceId: snapshot.deviceState!.deviceId,
              canAct: canAct)
        else
          _ActivityCard(
              totalMinutes: snapshot.todayUsage.totalMinutes,
              hasDevice: snapshot.deviceState != null,
              canAct: canAct),
        const SizedBox(height: 12),
        if (snapshot.deviceState != null)
          _EnforcementSection(
              deviceId: snapshot.deviceState!.deviceId,
              canAct: canAct),
        const SizedBox(height: 20),
        _ScreenTimeSection(
            familyId: familyId,
            childId: childId,
            hasDevice: snapshot.deviceState != null),
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

/// SOS — genuine emergency entry point for the child device.
///
/// Opens the safety-actions surface, which persists the SOS locally and
/// queues it through the outbox (`sos.created`); sync and delivery are the
/// same honest pipeline as every other mutation. The deviceId + authenticated
/// actorUid are carried into the payload so the Firestore document belongs to
/// the correct family/device and passes the deployed rules.
class _SosCard extends ConsumerWidget {
  const _SosCard(
      {required this.familyId, required this.deviceId, required this.canSend});
  final String familyId;
  final String deviceId;
  final bool canSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(firebaseAuthSessionProvider);
    final actorUid = session.valueOrNull?.identity?.uid;
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sos, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.t('sosAlerts'),
                      style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l10n.t('sosDescription'),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: !canSend
                  ? null
                  : () => context.push('/safety/actions/$familyId',
                      extra: {'deviceId': deviceId, 'actorUid': actorUid}),
              icon: const Icon(Icons.sos),
              label: Text(l10n.t('sendSos')),
            ),
            if (!canSend)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.t('actorVerificationRequired'),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error)),
              ),
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

/// M6 — Screen-Time Administration entry point on the child context.
///
/// An honest, live summary replaces the old coming-soon placeholder:
/// active policy count, the effective decision for a sample target
/// right now (PolicyEngine arithmetic, never a device report), a
/// pending exception badge, and a manage button that opens the
/// child-centric policy surface. Members without `managePolicies`
/// (spouse under Option A, child) see the read-only summary only.
class _ScreenTimeSection extends ConsumerWidget {
  const _ScreenTimeSection(
      {required this.familyId,
      required this.childId,
      required this.hasDevice});
  final String familyId;
  final String childId;
  final bool hasDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(familyRuntimeContextProvider(familyId));
    final canManage =
        auth.valueOrNull?.can(FamilyPermission.managePolicies) ?? false;
    final policies = ref.watch(childPoliciesProvider(familyId));
    final overrides = ref.watch(childOverridesProvider(familyId));
    final requests =
        ref.watch(familyExceptionRequestsProvider(familyId));
    final pendingRequests = requests.valueOrNull
            ?.where((request) =>
                request.status == ChildExceptionRequestStatus.pending)
            .length ??
        0;
    final activePolicies = policies.valueOrNull
            ?.where((policy) => policy.enabled)
            .length ??
        0;
    final activeOverride = (overrides.valueOrNull ?? const [])
        .where((o) =>
            o.target == 'video' && o.isActiveAt(DateTime.now()))
        .firstOrNull;
    final decision = const PolicyEngine().resolve(
        policies: policies.valueOrNull ?? const [],
        override: activeOverride,
        target: 'video',
        moment: DateTime.now());
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
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.t('screenTimeManage'),
                        style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!hasDevice)
                Text(l10n.t('childUnlinkedPolicyNotice'),
                    style: theme.textTheme.bodyMedium)
              else ...[
                Text(
                    '${l10n.t('policiesActiveCountPlural').replaceAll('{count}', '$activePolicies')}',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(
                    '${l10n.t('effectiveDecisionNow')}: '
                    '${decision.restricted ? l10n.t('effectiveDecisionRestricted') : l10n.t('effectiveDecisionAllowed')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                if (pendingRequests > 0)
                  Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                          '$pendingRequests ${pendingRequests == 1 ? l10n.t('pendingExceptionBadge') : l10n.t('pendingExceptionBadgePlural')}')),
                Text(l10n.t('policyNotDeviceEnforced'),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10),
              ],
              if (canManage)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                        '/child/$familyId/$childId/policies'),
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(l10n.t('managePolicies')),
                  ),
                )
              else
                Text(l10n.t('screenTimeAdminUnavailableBody'),
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ));
  }
}

/// M7 — Screen-Time Measurement on the child context.
///
/// An honest, on-demand measurement card: total usage for the local day
/// (zero minutes is a measurement, absence of data is not), freshness,
/// the capability-ladder banner when usage access is required or denied,
/// a per-target breakdown, the best-effort policy comparison label
/// (a measurement statement only — never an enforcement claim), and a
/// sync badge derived from actual outbox rows.
///
/// The refresh action invalidates the provider rather than fabricating
/// data; every value below is a derivation, never an assumption.
class _UsageMeasurementSection extends ConsumerWidget {
  const _UsageMeasurementSection(
      {required this.deviceId, required this.canAct});
  final String deviceId;
  final bool canAct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final measurement = ref.watch(childUsageMeasurementProvider(deviceId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timelapse_outlined),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(l10n.t('m7UsageToday'),
                        style: theme.textTheme.titleMedium)),
                if (!canAct)
                  const Icon(Icons.lock_outline,
                      size: 18, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            measurement.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(l10n.t('m7UsageUnavailable'),
                  style: theme.textTheme.bodyMedium),
              data: (snapshot) =>
                  _UsageMeasurementCard(snapshot: snapshot),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () =>
                    ref.invalidate(childUsageMeasurementProvider(deviceId)),
                icon: const Icon(Icons.refresh_outlined, size: 18),
                label: Text(l10n.t('m7RefreshMeasurement'),
                    style: theme.textTheme.labelMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M8 — honest screen-time enforcement status on the child device.
///
/// The states below are derived from the verified enforcement chain
/// (resolver → engine → adapter), never asserted without platform
/// confirmation. No label ever claims an app was 'blocked' — the UI
/// describes the policy condition and what the device confirmed.
class _EnforcementSection extends ConsumerWidget {
  const _EnforcementSection({required this.deviceId, required this.canAct});
  final String deviceId;
  final bool canAct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final enforcement = ref.watch(enforcementStateProvider(deviceId));
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
                    child: Text(l10n.t('m8EnforcementTitle'),
                        style: theme.textTheme.titleMedium)),
                if (!canAct)
                  const Icon(Icons.lock_outline,
                      size: 18, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            enforcement.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text(l10n.t('m8EnforcementUnavailable'),
                  style: theme.textTheme.bodyMedium),
              data: (snapshot) =>
                  _EnforcementCard(snapshot: snapshot),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () =>
                    ref.invalidate(enforcementStateProvider(deviceId)),
                icon: const Icon(Icons.refresh_outlined, size: 18),
                label: Text(l10n.t('m8RefreshEnforcement'),
                    style: theme.textTheme.labelMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnforcementCard extends StatelessWidget {
  const _EnforcementCard({required this.snapshot});
  final EnforcementApplicationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = snapshot.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.t('m8EnforcementSubtitle')}:',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(_stateText(state, l10n), style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(_stateDetail(state, l10n),
            style: theme.textTheme.bodyMedium),
        if (snapshot.application == EnforcementApplication.applied &&
            snapshot.appliedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16,
                    color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      '${l10n.t('m8StateEnforcementApplied')}: '
                      '${_shortStamp(snapshot.appliedAt!, l10n)}',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        if (snapshot.application == EnforcementApplication.failed &&
            state == EnforcementState.enforcementFailed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.t('m8VerificationNote'),
                style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            _syncBadge(snapshot.syncState, l10n),
            const SizedBox(width: 8),
            _freshnessBadge(snapshot.freshness, l10n),
            if (snapshot.policyVersion != null) const SizedBox(width: 8),
            if (snapshot.policyVersion != null)
              Text('${l10n.t('policyVersion')}: ${snapshot.policyVersion}',
                  style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  static String _stateText(EnforcementState state, AppLocalizations l10n) =>
      switch (state) {
        EnforcementState.notRequested => l10n.t('m8StateNotRequested'),
        EnforcementState.permissionRequired =>
          l10n.t('m8StatePermissionRequired'),
        EnforcementState.evaluationReady => l10n.t('m8StateEvaluationReady'),
        EnforcementState.enforcementRequested =>
          l10n.t('m8StateEvaluationReady'),
        EnforcementState.enforcementApplied =>
          l10n.t('m8StateEnforcementApplied'),
        EnforcementState.enforcementFailed => l10n.t('m8StateEnforcementFailed'),
        EnforcementState.policyStale => l10n.t('m8StatePolicyStale'),
        EnforcementState.deviceOffline => l10n.t('m8StateDeviceOffline'),
        EnforcementState.unsupported => l10n.t('m8StateUnsupported'),
        EnforcementState.recoveryPending => l10n.t('m8StateDeviceOffline'),
        EnforcementState.permissionDenied => l10n.t('m8StatePermissionDenied'),
      };

  static String _stateDetail(
          EnforcementState state, AppLocalizations l10n) =>
      switch (state) {
        EnforcementState.notRequested => l10n.t('m8StateNotRequestedDetail'),
        EnforcementState.permissionRequired =>
          l10n.t('m8StatePermissionRequiredDetail'),
        EnforcementState.evaluationReady =>
          l10n.t('m8StateEvaluationReadyDetail'),
        EnforcementState.enforcementRequested =>
          l10n.t('m8StateEvaluationReadyDetail'),
        EnforcementState.enforcementApplied =>
          l10n.t('m8StateEnforcementAppliedDetail'),
        EnforcementState.enforcementFailed =>
          l10n.t('m8StateEnforcementFailedDetail'),
        EnforcementState.policyStale => l10n.t('m8StatePolicyStaleDetail'),
        EnforcementState.deviceOffline => l10n.t('m8StateDeviceOfflineDetail'),
        EnforcementState.unsupported => l10n.t('m8StateUnsupportedDetail'),
        EnforcementState.recoveryPending =>
          l10n.t('m8StateDeviceOfflineDetail'),
        EnforcementState.permissionDenied =>
          l10n.t('m8StatePermissionDeniedDetail'),
      };

  static Widget _syncBadge(
      EnforcementSyncState sync, AppLocalizations l10n) {
    final String text = switch (sync) {
      EnforcementSyncState.synced => l10n.t('m8SyncedNow'),
      EnforcementSyncState.syncPending => l10n.t('m8SyncPending'),
      EnforcementSyncState.syncFailed => l10n.t('m8SyncFailed'),
      EnforcementSyncState.neverSynced => l10n.t('m8SyncPending'),
      EnforcementSyncState.offlineCached => l10n.t('m8SyncPending'),
    };
    return Chip(label: Text(text, style: const TextStyle(fontSize: 11)));
  }

  static Widget _freshnessBadge(bool fresh, AppLocalizations l10n) {
    final String text = fresh
        ? l10n.t('dataFresh')
        : l10n.t('m7StaleData');
    return Chip(label: Text(text, style: const TextStyle(fontSize: 11)));
  }

  static String _shortStamp(DateTime at, AppLocalizations l10n) {
    final local = at.toLocal();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${pad(local.month)}-${pad(local.day)} '
        '${pad(local.hour)}:${pad(local.minute)}';
  }
}

class _UsageMeasurementCard extends StatelessWidget {
  const _UsageMeasurementCard({required this.snapshot});
  final UsageMeasurementSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = snapshot.observationState;
    final isMeasured =
        state == UsageObservationState.observed ||
        state == UsageObservationState.offlineCached ||
        state == UsageObservationState.stale;
    final totalMinutes =
        (snapshot.totalMilliseconds / 60000).floor();
    final totalText =
        snapshot.hasObservedUsage || isMeasured
            ? l10n.t('m7UsageMinutes')
                .replaceAll('{count}', '$totalMinutes')
            : (state == UsageObservationState.noObservation
                ? l10n.t('m7NoObservation')
                : l10n.t('m7UsageUnavailable'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.t('m7TotalScreenTime')}: $totalText',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        _stateChips(state: state, snapshot: snapshot, l10n: l10n,
            theme: theme),
        if (snapshot.hasObservedUsage)
          Text(
              '${l10n.t('m7LastObserved')}: '
              '${_compactDateTime(snapshot.lastObservedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
        if (snapshot.targets.isNotEmpty)
          _breakdownAndComparison(
              snapshot: snapshot, l10n: l10n, theme: theme),
      ],
    );
  }
}

Widget _stateChips({
  required UsageObservationState state,
  required UsageMeasurementSnapshot snapshot,
  required AppLocalizations l10n,
  required ThemeData theme,
}) {
  final chips = <Widget>[];
  if (state == UsageObservationState.permissionRequired) {
    chips.add(Chip(
        avatar: const Icon(Icons.lock_person_outlined),
        label: Text(l10n.t('m7PermissionRequired'))));
    chips.add(const SizedBox(width: 8));
    chips.add(ElevatedButton.icon(
      onPressed: () => _openUsageSettings(),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(l10n.t('m7GrantUsageAccess')),
    ));
  } else if (state == UsageObservationState.permissionDenied) {
    chips.add(Chip(
        avatar: const Icon(Icons.block_outlined),
        label: Text(l10n.t('m7PermissionDenied'))));
  } else if (state == UsageObservationState.unsupported) {
    chips.add(Chip(
        avatar: const Icon(Icons.do_not_disturb_on_outlined),
        label: Text(l10n.t('m7Unsupported'))));
  } else if (state == UsageObservationState.unavailable) {
    chips.add(Chip(
        avatar: const Icon(Icons.cloud_off_outlined),
        label: Text(l10n.t('m7UsageUnavailable'))));
  } else if (state == UsageObservationState.noObservation) {
    chips.add(Chip(
        avatar: const Icon(Icons.hourglass_empty_outlined),
        label: Text(l10n.t('m7NoObservation'))));
  } else if (state == UsageObservationState.observing) {
    chips.add(Chip(
        avatar: const Icon(Icons.play_circle_outline),
        label: Text(l10n.t('m7Observing'))));
  } else if (state == UsageObservationState.observed) {
    chips.add(Chip(
        avatar: const Icon(Icons.check_circle_outline),
        label: Text(l10n.t('m7MeasuredZero'))));
  } else if (state == UsageObservationState.stale) {
    chips.add(Chip(
        avatar: const Icon(Icons.schedule_outlined),
        label: Text(l10n.t('m7StaleData'))));
  } else if (state == UsageObservationState.offlineCached) {
    chips.add(Chip(
        avatar: const Icon(Icons.cloud_off_outlined),
        label: Text(l10n.t('m7OfflineCached'))));
  }
  final sync = snapshot.syncState;
  if (sync == UsageSyncState.queued) {
    chips.add(const SizedBox(width: 8));
    chips.add(Chip(
        avatar: const Icon(Icons.cloud_upload_outlined),
        label: Text(l10n.t('m7SyncPending'))));
  } else if (sync == UsageSyncState.failed) {
    chips.add(const SizedBox(width: 8));
    chips.add(Chip(
        avatar: const Icon(Icons.error_outline),
        label: Text(l10n.t('m7SyncFailed'))));
  }
  return Wrap(
      spacing: 6, runSpacing: 6, children: chips);
}

void _openUsageSettings() {
  // Opens the system Usage Access settings page on Android through the
  // existing capability channel (MainActivity already implements
  // openSettings(usageStats)). A no-op on platforms without the channel.
  try {
    const MethodChannel('com.guardianeye.app/capabilities')
        .invokeMethod('openSettings', {'kind': 'usageStats'});
  } catch (_) {
    // Channel unavailable — the UI still told the user what is needed.
  }
}

/// Per-target breakdown with the honest policy comparison label.
/// Comparison labels are measurement statements: "Policy condition
/// detected" framing is used — never a "blocked" claim.
class _breakdownAndComparison extends StatelessWidget {
  const _breakdownAndComparison(
      {required this.snapshot,
      required this.l10n,
      required this.theme});
  final UsageMeasurementSnapshot snapshot;
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final condition = snapshot.evaluation.state;
    final conditionLabel = switch (condition) {
      EvaluationCondition.withinLimit => l10n.t('m7WithinLimit'),
      EvaluationCondition.nearLimit => l10n.t('m7NearLimit'),
      EvaluationCondition.overLimit => l10n.t('m7OverLimit'),
      EvaluationCondition.noActivePolicy => l10n.t('m7NoActivePolicy'),
      EvaluationCondition.unableToEvaluate =>
        l10n.t('m7UnableToEvaluate'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(l10n.t('m7BreakdownTitle'),
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        ...snapshot.targets.map((target) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(child: Text(target.target,
                      style: theme.textTheme.bodyMedium)),
                  Text(
                      '${(target.totalMilliseconds / 60000).floor()} min',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            )),
        const SizedBox(height: 6),
        Text(
            '${l10n.t('m7ConditionDetected')}: $conditionLabel',
            style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
      ],
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
