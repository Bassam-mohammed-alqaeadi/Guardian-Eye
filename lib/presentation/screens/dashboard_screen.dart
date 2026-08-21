import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/guardian_models.dart';
import '../../domain/child_device_enforcement.dart';
import '../../application/family_context_provider.dart';
import '../widgets/guardian_primitives.dart';
import 'family_setup_screens.dart';
import 'family_dashboard_screens.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dashboard = ref.watch(dashboardProvider);
    return Directionality(
      textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('appTitle')),
          actions: [
            IconButton(
                tooltip: l10n.t('settings'),
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined)),
          ],
        ),
        body: dashboard.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              _Failure(onRetry: () => ref.invalidate(dashboardProvider)),
          data: (data) => data.family == null
              ? const FamilySetupEntryScreen()
              : _Dashboard(data: data),
        ),
      ),
    );
  }
}

class _FamilySetup extends ConsumerStatefulWidget {
  const _FamilySetup({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_FamilySetup> createState() => _FamilySetupState();
}

class _FamilySetupState extends ConsumerState<_FamilySetup> {
  final _familyController = TextEditingController();
  final _parentController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _familyController.dispose();
    _parentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final familyName = _familyController.text.trim();
    final parentName = _parentController.text.trim();
    if (familyName.isEmpty || parentName.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.t('familySetupRequired'))),
        );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(familyRepositoryProvider).createFamily(
            familyName: familyName,
            parentName: parentName,
          );
      widget.onCreated();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 36),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/guardian_eye_icon.png',
                width: 88, height: 88, fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Text(l10n.t('welcome'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(l10n.t('noFamily'),
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 28),
          TextField(
            controller: _familyController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.t('familyName')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _parentController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.t('parentName')),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const CircularProgressIndicator()
                : Text(l10n.t('createFamily')),
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.data});
  final GuardianDashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = data.family!.id;
    // Phase 18: single canonical family runtime context.
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final FamilyMember? actor = runtime.valueOrNull?.actor;
    bool can(FamilyPermission permission) =>
        runtime.valueOrNull?.can(permission) ?? false;
    final verifiedActor = runtime.valueOrNull?.isVerified ?? false;
    final deviceStates = ref.watch(childDeviceStatesProvider(familyId));
    final recentIncidents = ref.watch(recentIncidentsProvider(familyId));

    // PD-005: Primary parent sees the aggregated dashboard.
    if (actor?.role == FamilyRole.primaryParent) {
      return PrimaryParentDashboard(data: data);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(familyActorBindingProvider(familyId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuardianHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/guardian_eye_icon.png',
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.t('familyDecisionCenter'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(data.family!.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text(l10n.t('offlineFirst'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          if (!verifiedActor) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l10n.t('actorVerificationRequired')),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GuardianStatTile(
                    icon: Icons.people_outline,
                    value: '${data.children.length}',
                    label: l10n.t('children')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GuardianStatTile(
                    icon: Icons.warning_amber_rounded,
                    value: '${data.incidentsToday}',
                    label: l10n.t('incidentsToday'),
                    kind: data.incidentsToday > 0
                        ? GuardianStatusKind.watch
                        : GuardianStatusKind.safe),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GuardianStatTile(
              icon: Icons.sync_problem_outlined,
              value: '${data.queuedOperations}',
              label: l10n.t('syncQueue'),
              kind: data.queuedOperations > 0
                  ? GuardianStatusKind.watch
                  : GuardianStatusKind.safe),
          const SizedBox(height: 12),
          _FamilyIdentityCard(
              family: data.family!,
              incidentsToday: data.incidentsToday,
              queuedOperations: data.queuedOperations),
          const SizedBox(height: 12),
          if (deviceStates.valueOrNull != null ||
              recentIncidents.valueOrNull != null)
            _SafetySignalCard(
                recentIncidents: recentIncidents,
                onOpenTimeline: () => context.push('/timeline/$familyId'),
                permission: can(FamilyPermission.viewSafetyTimeline))
          else if (deviceStates.hasError || recentIncidents.hasError)
            _SafetySignalError(onRetry: () {
              ref.invalidate(childDeviceStatesProvider(familyId));
              ref.invalidate(recentIncidentsProvider(familyId));
            }),
          const SizedBox(height: 12),
          _ChildOverview(
              familyId: familyId,
              children: data.children,
              deviceStates: deviceStates,
              onOpenChild: (child) =>
                  context.push('/child/$familyId/${child.id}')),
          const SizedBox(height: 20),
          _NavGroup(
            label: l10n.t('familyMembers'),
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.push('/family/$familyId', extra: actor?.id),
                icon: const Icon(Icons.groups_outlined),
                label: Text(l10n.t('familyMembers')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageChildren)
                    ? () => _addChild(context, ref, familyId)
                    : null,
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.t('addChild')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageDevices)
                    ? () => context.push('/safety/pairing/$familyId')
                    : null,
                icon: const Icon(Icons.qr_code_2),
                label: Text(l10n.t('pairDevice')),
              ),
              // M5: a child (or any family actor) redeems a pairing code issued
              // by the parent — available even before actor verification, since
              // redemption is exactly how an unverified child device becomes
              // trusted (Guardian Backend /api/redeem-child).
              OutlinedButton.icon(
                onPressed: () => context.push('/device-link/$familyId'),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.t('redeemPairingCode')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('safetyPolicies'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/safety/policies/$familyId')
                    : null,
                icon: const Icon(Icons.bedtime_outlined),
                label: Text(l10n.t('managePolicies')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/safety/device-status/$familyId')
                    : null,
                icon: const Icon(Icons.phonelink_lock_outlined),
                label: Text(l10n.t('childDeviceStatus')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewSafetyTimeline)
                    ? () => context.push('/safety/daily/$familyId')
                    : null,
                icon: const Icon(Icons.today_outlined),
                label: Text(l10n.t('dailySafety')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('familyMap'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/location/$familyId')
                    : null,
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.t('familyMap')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/location/$familyId/places')
                    : null,
                icon: const Icon(Icons.star_outline),
                label: Text(l10n.t('favoritePlacesNav')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/location/$familyId/alerts')
                    : null,
                icon: const Icon(Icons.notifications_outlined),
                label: Text(l10n.t('locationAlertsNav')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('webProtectionNav'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/safety/web/$familyId')
                    : null,
                icon: const Icon(Icons.public_off_outlined),
                label: Text(l10n.t('webProtectionNav')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/safety/web/$familyId/history')
                    : null,
                icon: const Icon(Icons.history_outlined),
                label: Text(l10n.t('webFilterHistoryNav')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('appControlDashboard'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/apps/$familyId')
                    : null,
                icon: const Icon(Icons.apps_outlined),
                label: Text(l10n.t('appControlDashboard')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/apps/$familyId/history')
                    : null,
                icon: const Icon(Icons.history_outlined),
                label: Text(l10n.t('appBlockHistory')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/apps/$familyId/alerts')
                    : null,
                icon: const Icon(Icons.notifications_outlined),
                label: Text(l10n.t('usageAlerts')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('monitoringDashboard'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/monitoring/$familyId')
                    : null,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(l10n.t('monitoringDashboard')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewChildStatus)
                    ? () => context.push('/monitoring/$familyId/screenshots')
                    : null,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.t('screenshotsTimeline')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/monitoring/$familyId/evidence')
                    : null,
                icon: const Icon(Icons.flag_outlined),
                label: Text(l10n.t('evidenceReviewQueue')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('modesGroup'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.managePolicies)
                    ? () => context.push('/modes/$familyId')
                    : null,
                icon: const Icon(Icons.tune_outlined),
                label: Text(l10n.t('modesDashboardTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('sosGroup'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewSafetyTimeline)
                    ? () => context.push('/sos/$familyId')
                    : null,
                icon: const Icon(Icons.emergency_outlined),
                label: Text(l10n.t('sosDashboardTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewSafetyTimeline)
                    ? () => context.push('/sos/$familyId/recipients')
                    : null,
                icon: const Icon(Icons.people_outline),
                label: Text(l10n.t('sosRecipientsTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewSafetyTimeline)
                    ? () => context.push('/sos/$familyId/drill')
                    : null,
                icon: const Icon(Icons.fact_check),
                label: Text(l10n.t('sosDrillTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('dlDevicesTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewDeviceLinking)
                    ? () => context.push('/settings/devices')
                    : null,
                icon: const Icon(Icons.devices_outlined),
                label: Text(l10n.t('dlDevicesTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageDevices)
                    ? () => context.push('/safety/pairing/$familyId')
                    : null,
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text(l10n.t('pairDevice')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('rpReportsTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewReports)
                    ? () => context.push('/reports/$familyId')
                    : null,
                icon: const Icon(Icons.insights_outlined),
                label: Text(l10n.t('rpReportsTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewReports)
                    ? () => context.push('/reports/$familyId/export')
                    : null,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(l10n.t('rpExportTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('frRulesTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewFamilyRules)
                    ? () => context.push('/rules/$familyId')
                    : null,
                icon: const Icon(Icons.rule_outlined),
                label: Text(l10n.t('frRulesTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageFamilyRules)
                    ? () => context.push('/rules/$familyId/new')
                    : null,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l10n.t('frNewRuleTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewFamilyRules)
                    ? () => context.push('/rules/$familyId/conflicts')
                    : null,
                icon: const Icon(Icons.balance_outlined),
                label: Text(l10n.t('frConflictsTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('tkTasksTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewTasks)
                    ? () => context.push('/tasks/$familyId')
                    : null,
                icon: const Icon(Icons.task_alt_outlined),
                label: Text(l10n.t('tkTasksTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageTasks)
                    ? () => context.push('/tasks/$familyId/new')
                    : null,
                icon: const Icon(Icons.add_task_outlined),
                label: Text(l10n.t('tkNewTaskTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewTasks)
                    ? () => context.push('/tasks/$familyId/log')
                    : null,
                icon: const Icon(Icons.history_outlined),
                label: Text(l10n.t('tkFamilyLogTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('rwRewardsTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.viewRewards)
                    ? () => context.push('/rewards/$familyId')
                    : null,
                icon: const Icon(Icons.card_giftcard_outlined),
                label: Text(l10n.t('rwRewardsTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageRewards)
                    ? () => context.push('/rewards/$familyId/catalog/new')
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(l10n.t('rwCatalogTitle')),
              ),
              OutlinedButton.icon(
                onPressed: can(FamilyPermission.manageRewards)
                    ? () => context.push('/rewards/$familyId/pending')
                    : null,
                icon: const Icon(Icons.pending_actions_outlined),
                label: Text(l10n.t('rwPendingClaimsTitle')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NavGroup(
            label: l10n.t('permissionsTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/safety/permissions'),
                icon: const Icon(Icons.tune),
                label: Text(l10n.t('permissions')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addChild(
      BuildContext context, WidgetRef ref, String familyId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddChildSheet(familyId: familyId),
    );
  }
}

class _AddChildSheet extends ConsumerStatefulWidget {
  const _AddChildSheet({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends ConsumerState<_AddChildSheet> {
  final TextEditingController _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(familyRepositoryProvider)
          .addChild(familyId: widget.familyId, childName: _name.text);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.t('error'))));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.t('addChild'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.t('childName'))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : Text(l10n.t('continue')),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element — FS-009/FS-014 aggregate metric tile kept for the reporting dashboard.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => GuardianCard(
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall)
                ],
              ),
            ),
          ],
        ),
      );
}

/// A small labeled group of navigation buttons inside the family home.
/// The label answers "what is this group for?" in product language;
/// the buttons inside are the only ways into that area — no duplicate
/// entry points live elsewhere in the shell.
class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GuardianSection(
        title: label,
        spacing: 10,
        children: [Wrap(spacing: 10, runSpacing: 10, children: children)],
      );
}

/// Family identity card — M2: presents the family's own reference data
/// (name, created date, today's honest counts) without inventing anything.
class _FamilyIdentityCard extends StatelessWidget {
  const _FamilyIdentityCard(
      {required this.family,
      required this.incidentsToday,
      required this.queuedOperations});
  final GuardianFamily family;
  final int incidentsToday;
  final int queuedOperations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return GuardianCard(
      child: Semantics(
        label: l10n.t('familyIdentity'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('familyIdentity'),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(family.name, style: theme.textTheme.titleMedium),
            Text(
                '${l10n.t('createdFamily')}: '
                '${_formatDate(family.createdAt)}',
                style: theme.textTheme.bodySmall,
                semanticsLabel:
                    '${l10n.t('createdFamily')}: ${_formatDate(family.createdAt)}'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.today_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(queuedOperations == 0
                        ? l10n.t('dataFresh')
                        : l10n.t('syncQueue'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

/// Safety signal — honest reflection of real unacknowledged incidents.
/// Zero active incidents: safe today. Any active incident: attention
/// required, with a canonical entry into the timeline for review.
class _SafetySignalCard extends StatelessWidget {
  const _SafetySignalCard(
      {required this.recentIncidents,
      required this.onOpenTimeline,
      required this.permission});
  final AsyncValue<List<GuardianIncident>> recentIncidents;
  final VoidCallback onOpenTimeline;
  final bool permission;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = recentIncidents.valueOrNull ?? [];
    final attention = active.isNotEmpty;
    return Card(
      child: Semantics(
        label: attention ? l10n.t('attentionRequired') : l10n.t('safeToday'),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(
              attention ? Icons.warning_amber_rounded : Icons.shield_outlined,
              color: attention
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary),
          title: Text(
              attention ? l10n.t('attentionRequired') : l10n.t('safeToday')),
          subtitle: Text('${l10n.t('safetySignal')} '
              '${attention ? active.length.toString() : ''}'),
          trailing: OutlinedButton(
            onPressed: permission && !attention ? null : onOpenTimeline,
            child: Text(l10n.t('childDetails')),
          ),
        ),
      ),
    );
  }
}

/// Local signal load failure — retry invalidates the read providers.
class _SafetySignalError extends StatelessWidget {
  const _SafetySignalError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GuardianStateView(
        state: GuardianViewState.error,
        onRetry: onRetry,
      );
}

/// Children overview — one card per child joined with its real device
/// state; an unlinked child is shown explicitly (no silent omission).
///
/// A plain [StatelessWidget]: every piece of data it needs arrives
/// through constructor parameters, so nothing about its render path
/// depends on provider keys resolving at test time.
class _ChildOverview extends StatelessWidget {
  const _ChildOverview(
      {required this.familyId,
      required this.children,
      required this.deviceStates,
      required this.onOpenChild});
  final String familyId;
  final List<FamilyMember> children;
  final AsyncValue<List<ChildDeviceState>> deviceStates;

  /// Opens the child-context surface for the tapped child.
  final void Function(FamilyMember child) onOpenChild;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final devices = deviceStates.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('childOverview'),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (children.isEmpty)
          GuardianStateView(
            state: GuardianViewState.empty,
            message: l10n.t('noChildren'),
          )
        else
          ...children.map((child) {
            ChildDeviceState? state;
            for (final candidate in devices ?? const <ChildDeviceState>[]) {
              if (candidate.memberId == child.id) {
                state = candidate;
                break;
              }
            }
            final devicePresent = state != null;
            final lifecycleName = state?.lifecycle.name ?? '';
            return GuardianCard(
              onTap: () => onOpenChild(child),
              child: Semantics(
                label: '${child.displayName} '
                    '${devicePresent ? lifecycleName : l10n.t('noDevicesLinked')}',
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                      child: Text(child.displayName.characters.first)),
                  title: Text(child.displayName),
                  subtitle: Text(devicePresent
                      ? l10n.t(
                          'device${lifecycleName[0].toUpperCase() + lifecycleName.substring(1)}')
                      : l10n.t('noDevicesLinked')),
                  trailing: OutlinedButton(
                    onPressed: () => onOpenChild(child),
                    child: Text(l10n.t('childDetails')),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GuardianStateView(
        state: GuardianViewState.error,
        onRetry: onRetry,
      );
}
