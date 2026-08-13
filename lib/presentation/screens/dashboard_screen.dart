import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/guardian_models.dart';
import '../../application/family_context_provider.dart';

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
              ? _FamilySetup(onCreated: () => ref.invalidate(dashboardProvider))
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
    setState(() => _saving = true);
    try {
      await ref.read(familyRepositoryProvider).createFamily(
            familyName: _familyController.text,
            parentName: _parentController.text,
          );
      widget.onCreated();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('error'))),
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
          Icon(Icons.shield_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
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
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(familyActorBindingProvider(familyId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(data.family!.name,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(l10n.t('offlineFirst'),
              style: Theme.of(context).textTheme.bodyMedium),
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
                  child: _Metric(
                      icon: Icons.people_outline,
                      label: l10n.t('children'),
                      value: '${data.children.length}')),
              const SizedBox(width: 12),
              Expanded(
                  child: _Metric(
                      icon: Icons.warning_amber_rounded,
                      label: l10n.t('incidentsToday'),
                      value: '${data.incidentsToday}')),
            ],
          ),
          const SizedBox(height: 12),
          _Metric(
              icon: Icons.sync_problem_outlined,
              label: l10n.t('syncQueue'),
              value: '${data.queuedOperations}'),
          const SizedBox(height: 20),
          _NavGroup(
            label: l10n.t('familyMembers'),
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/family/$familyId',
                    extra: actor?.id),
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
            label: l10n.t('permissionsTitle'),
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/safety/permissions'),
                icon: const Icon(Icons.tune),
                label: Text(l10n.t('permissions')),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.t('children'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (data.children.isEmpty)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(l10n.t('noChildren'))))
          else
            ...data.children.map(
              (child) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(child.displayName.characters.first)),
                  title: Text(child.displayName),
                  subtitle: Text(l10n.t('setupRequired')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addChild(
      BuildContext context, WidgetRef ref, String familyId) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.t('addChild'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.t('childName'))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(familyRepositoryProvider)
                    .addChild(familyId: familyId, childName: controller.text);
                ref.invalidate(dashboardProvider);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              child: Text(l10n.t('continue')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    Text(value,
                        style: Theme.of(context).textTheme.headlineSmall)
                  ],
                ),
              ),
            ],
          ),
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
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: children),
        ],
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
      child:
          FilledButton(onPressed: onRetry, child: const Icon(Icons.refresh)));
}
