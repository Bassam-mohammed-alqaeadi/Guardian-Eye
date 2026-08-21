import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// PD-005 — Primary Parent Dashboard. Aggregated subsystem view.
class PrimaryParentDashboard extends ConsumerWidget {
  const PrimaryParentDashboard({super.key, required this.data});
  final GuardianDashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = data.family!.id;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
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
                    const Icon(Icons.dashboard_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Text(l10n.t('familyDashboardTitle'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(data.family!.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _DashboardGrid(data: data, familyId: familyId),
          const SizedBox(height: 24),
          _SetupChecklist(familyId: familyId),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.data, required this.familyId});
  final GuardianDashboard data;
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          icon: Icons.location_on_rounded,
          value: '${data.locationCount}',
          label: l10n.t('familyDashboardLocations'),
          onTap: () => context.push('/location/$familyId'),
        ),
        _StatCard(
          icon: Icons.notifications_active_rounded,
          value: '${data.activeSosCount}',
          label: l10n.t('familyDashboardSos'),
          kind: data.activeSosCount > 0
              ? GuardianStatusKind.alert
              : GuardianStatusKind.safe,
          onTap: () => context.push('/sos/$familyId'),
        ),
        _StatCard(
          icon: Icons.chat_bubble_rounded,
          value: '${data.unreadChatCount}',
          label: l10n.t('familyDashboardMessages'),
          kind: data.unreadChatCount > 0
              ? GuardianStatusKind.watch
              : GuardianStatusKind.safe,
          onTap: () => context.push('/chat/$familyId'),
        ),
        _StatCard(
          icon: Icons.fence_rounded,
          value: '${data.geofenceCount}',
          label: l10n.t('familyDashboardGeofences'),
          onTap: () => context.push('/geofencing/$familyId'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.kind = GuardianStatusKind.safe,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final GuardianStatusKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 20, color: _colorFor(context, kind)),
                  Text(value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFor(BuildContext context, GuardianStatusKind kind) {
    return switch (kind) {
      GuardianStatusKind.safe => Theme.of(context).colorScheme.primary,
      GuardianStatusKind.watch => Colors.orange,
      GuardianStatusKind.alert => Colors.red,
      _ => Theme.of(context).colorScheme.primary,
    };
  }
}

/// PD-007 — Setup Checklist.
class _SetupChecklist extends ConsumerWidget {
  const _SetupChecklist({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // In a real app, these would be derived from actual subsystem states.
    // For FS-014, we show the honest list of required setup steps.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('familyChecklistTitle'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.t('familyChecklistSubtitle'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        _ChecklistItem(label: l10n.t('familyChecklistLocation'), isDone: true),
        _ChecklistItem(
            label: l10n.t('familyChecklistGeofences'), isDone: false),
        _ChecklistItem(label: l10n.t('familyChecklistPolicies'), isDone: false),
        _ChecklistItem(label: l10n.t('familyChecklistDevices'), isDone: false),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, required this.isDone});
  final String label;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isDone ? Colors.green : Theme.of(context).disabledColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(
            isDone
                ? l10n.t('familyChecklistDone')
                : l10n.t('familyChecklistPending'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      isDone ? Colors.green : Theme.of(context).disabledColor,
                ),
          ),
        ],
      ),
    );
  }
}

/// PD-006 — Family Profile.
class FamilyProfileScreen extends ConsumerWidget {
  const FamilyProfileScreen({super.key, required this.family});
  final GuardianFamily family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('familyProfileTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ProfileItem(label: l10n.t('familyProfileName'), value: family.name),
          const Divider(height: 32),
          _ProfileItem(
              label: l10n.t('familyProfileCreated'),
              value: family.createdAt.toLocal().toString().split('.')[0]),
          const Divider(height: 32),
          // Members list would go here in a full implementation.
          Text(l10n.t('familyProfileMembers'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          const Center(child: Text('…')),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
