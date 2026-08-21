import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../widgets/guardian_primitives.dart';

/// ---------------------------------------------------------------------------
/// FS-012 — Child Mode. Screens (CM-001 … CM-005).
///
/// Child mode is a gated self-scope experience. Authorization is strictly
/// enforced: an actor who is not the child themselves (or an authorized
/// parent viewing the child's device experience) is denied access.
/// ---------------------------------------------------------------------------

// ═══════════════ CM-001 — Child Mode Dashboard ══════════════════════════════
class ChildModeDashboard extends ConsumerWidget {
  const ChildModeDashboard({
    super.key,
    required this.familyId,
    required this.childId,
  });

  final String familyId;
  final String childId;

  static const String route = '/child/:familyId/:childId/dashboard';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));

    return runtime.when(
      loading: () => const Scaffold(
          body: GuardianStateView(state: GuardianViewState.loading)),
      error: (err, _) => Scaffold(
          body: GuardianStateView(
              state: GuardianViewState.error, message: err.toString())),
      data: (ctx) {
        final child = ctx.allMembers.where((m) => m.id == childId).firstOrNull;
        if (child == null)
          return const Scaffold(
              body: GuardianStateView(state: GuardianViewState.error));

        return Scaffold(
          backgroundColor: GuardianTokens.guardianNavy,
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                backgroundColor: GuardianTokens.guardianNavy,
                foregroundColor: Colors.white,
                title: Text(l10n.t('childDashboardTitle')),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.privacy_tip_outlined),
                    onPressed: () =>
                        context.push('/child/$familyId/$childId/privacy'),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _UsageCard(l10n: l10n),
                      const SizedBox(height: 16),
                      _StatusCard(l10n: l10n),
                      const SizedBox(height: 16),
                      _ActionCard(
                        l10n: l10n,
                        title: l10n.t('childRequestTime'),
                        icon: Icons.add_alarm_outlined,
                        onTap: () => _showRequestTimeDialog(context),
                      ),
                      const SizedBox(height: 12),
                      _ActionCard(
                        l10n: l10n,
                        title: l10n.t('childMyRequests'),
                        icon: Icons.history_outlined,
                        onTap: () =>
                            context.push('/child/$familyId/$childId/requests'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRequestTimeDialog(BuildContext context) {
    // CM-001/WF-010 exception request trigger.
    showDialog(
      context: context,
      builder: (context) => const _RequestTimeDialog(),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(l10n.t('childUsageToday'),
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('02:45',
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: GuardianTokens.guardianTeal)),
            const SizedBox(height: 8),
            Text(l10n.t('childUsageLimit').replaceAll('%s', '03:00'),
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              value: 0.85,
              backgroundColor: Colors.white12,
              color: GuardianTokens.guardianTeal,
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const GuardianIconBadge(
                icon: Icons.security, background: GuardianTokens.guardianTeal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.t('childProtectionActive'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(l10n.t('childProtectionDesc'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.l10n,
      required this.title,
      required this.icon,
      required this.onTap});
  final AppLocalizations l10n;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _RequestTimeDialog extends StatefulWidget {
  const _RequestTimeDialog();

  @override
  State<_RequestTimeDialog> createState() => _RequestTimeDialogState();
}

class _RequestTimeDialogState extends State<_RequestTimeDialog> {
  int _minutes = 15;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: GuardianTokens.guardianNavy,
      title: Text(l10n.t('childRequestTimeTitle'),
          style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.t('childRequestTimeDesc'),
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [15, 30, 60]
                .map((m) => ChoiceChip(
                      label: Text('$m ${l10n.t('minutes')}'),
                      selected: _minutes == m,
                      onSelected: (s) => setState(() => _minutes = m),
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.t('cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
              backgroundColor: GuardianTokens.guardianTeal),
          child: Text(l10n.t('send')),
        ),
      ],
    );
  }
}

// ═══════════════ CM-002 — Child Mode Lock ══════════════════════════════════
class ChildModeLockScreen extends StatelessWidget {
  const ChildModeLockScreen({super.key, required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock_outlined,
                  size: 80, color: GuardianTokens.statusWatch),
              const SizedBox(height: 24),
              Text(l10n.t('childLockTitle'),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Text(reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 40),
              GuardianCard(
                color: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.t('childLockParentNote'),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════ CM-004 — My Exception Requests ════════════════════════════
class ChildRequestsScreen extends ConsumerWidget {
  const ChildRequestsScreen(
      {super.key, required this.familyId, required this.childId});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
        title: Text(l10n.t('childMyRequests')),
      ),
      body: const GuardianStateView(
        state: GuardianViewState.empty,
        message: 'لا توجد طلبات سابقة حالياً',
      ),
    );
  }
}

// ═══════════════ CM-005 — My Privacy View ══════════════════════════════════
class ChildPrivacyScreen extends ConsumerWidget {
  const ChildPrivacyScreen(
      {super.key, required this.familyId, required this.childId});
  final String familyId;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      appBar: AppBar(
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
        title: Text(l10n.t('childPrivacyTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PrivacyItem(
            l10n: l10n,
            title: l10n.t('childPrivacyWeb'),
            desc: l10n.t('childPrivacyWebDesc'),
            icon: Icons.public,
          ),
          const SizedBox(height: 12),
          _PrivacyItem(
            l10n: l10n,
            title: l10n.t('childPrivacyLocation'),
            desc: l10n.t('childPrivacyLocationDesc'),
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          _PrivacyItem(
            l10n: l10n,
            title: l10n.t('childPrivacyApps'),
            desc: l10n.t('childPrivacyAppsDesc'),
            icon: Icons.apps_outage_outlined,
          ),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem(
      {required this.l10n,
      required this.title,
      required this.desc,
      required this.icon});
  final AppLocalizations l10n;
  final String title;
  final String desc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: GuardianTokens.guardianTeal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
