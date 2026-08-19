import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../application/family_context_provider.dart';
import '../../domain/guardian_models.dart';
import '../../data/reports_export_service.dart';
import '../../domain/reports_domain.dart';
import '../widgets/guardian_primitives.dart';

/// FS-009 — Reports & Export screens (RP-001 … RP-007).
///
/// Honesty contract: a report only ever displays data that the device
/// actually recorded inside the chosen window. Empty sections are shown as
/// honest empty states — never as zeroes borrowed from another period.
/// Export artefacts (PDF / CSV) contain the same labelled "no data captured
/// in this period" verdicts, so nothing in the file can be mistaken for
/// real activity.
///
/// Authorization: every screen requires FamilyPermission.viewReports for
/// adult actors; the child actor sees only its own row data via
/// FamilyPermission.viewOwnReport (enforced at the row level on the
/// dashboard, never by hiding the whole screen).

// ── Shared guard ─────────────────────────────────────────────────────────────

Widget _guardedScaffold({
  required BuildContext context,
  required AppLocalizations l10n,
  required AsyncValue<dynamic> runtime,
  required FamilyPermission requiredPermission,
  required Widget child,
}) {
  final ctx = runtime.valueOrNull;
  if (ctx == null || runtime.isLoading) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: const GuardianStateView(state: GuardianViewState.loading),
    );
  }
  if (ctx.isVerified != true || ctx.actor == null) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('roleNotAllowed'),
        message: l10n.t('authorizationFailure'),
      ),
    );
  }
  if (!ctx.can(requiredPermission)) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('roleNotAllowed'),
        message: l10n.t('reportChildForbidden'),
      ),
    );
  }
  return child;
}

// ── RP-001 Reports dashboard ─────────────────────────────────────────────────

/// The family reports dashboard. Selects the period (week / month / custom),
/// shows per-section cards with honest metrics, and routes into each
/// subsystem report detail.
class ReportsDashboardScreen extends ConsumerWidget {
  const ReportsDashboardScreen({super.key});

  static const route = '/reports/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: Consumer(
        builder: (context, ref, child) {
          final runtime =
              ref.watch(familyRuntimeContextProvider(familyId));
          final periodNotation =
              ref.watch(reportsPeriodNotifierProvider(familyId));
          final snapshot = ref.watch(reportsSnapshotProvider(
              (familyId: familyId, period: periodNotation)));

          return _Scaffold(
            l10n: l10n,
            title: l10n.t('rpDashboardTitle'),
            runtime: runtime,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeriodSelector(
                      l10n: l10n,
                      notation: periodNotation,
                      onChanged: (p) => ref
                          .read(reportsPeriodNotifierProvider(familyId)
                              .notifier)
                          .state = p),
                  const SizedBox(height: 16),
                  _FamilyBanner(l10n: l10n, snapshot: snapshot.valueOrNull),
                  const SizedBox(height: 16),
                  ..._buildSections(
                      context, ref, l10n, familyId, snapshot),
                  const SizedBox(height: 8),
                  GuardianCard(
                    color: GuardianTokens.guardianNavy.withOpacity(0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.t('rpExportLead'),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () =>
                              context.push('/reports/$familyId/export'),
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(l10n.t('rpExportButton')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, String familyId,
      AsyncValue<FamilyReportSnapshot> snapshot) {
    final s = snapshot.valueOrNull;
    if (snapshot.error != null) {
      return [
        GuardianStateView(
          state: GuardianViewState.error,
          title: l10n.t('rpLoadFailed'),
          message: l10n.t('rpLoadRetryHint'),
          primaryActionLabel: l10n.t('retry'),
          onRetry: () => ref.invalidate(reportsSnapshotProvider(
              (familyId: familyId, period: ref.read(
                  reportsPeriodNotifierProvider(familyId))))),
        )
      ];
    }
    if (s == null || snapshot.isLoading) {
      return const [GuardianStateView(state: GuardianViewState.loading)];
    }
    final sections = <_SectionSpec>[
      _SectionSpec('rpWebTitle', ReportSectionKind.web,
          Icons.block, Icons.arrow_forward_ios, '/reports/$familyId/web'),
      _SectionSpec('rpUsageTitle', ReportSectionKind.usage,
          Icons.timer, Icons.arrow_forward_ios, '/reports/$familyId/usage'),
      _SectionSpec('rpLocationTitle', ReportSectionKind.location,
          Icons.location_on, Icons.arrow_forward_ios,
          '/reports/$familyId/location'),
      _SectionSpec('rpSafetyTitle', ReportSectionKind.safety,
          Icons.shield, Icons.arrow_forward_ios, '/reports/$familyId/safety'),
      _SectionSpec('rpModesTitle', ReportSectionKind.modes,
          Icons.tune, Icons.arrow_forward_ios, '/reports/$familyId/modes'),
      _SectionSpec('rpSosTitle', ReportSectionKind.sos,
          Icons.emergency, Icons.arrow_forward_ios, '/reports/$familyId/sos'),
    ];
    return [
      for (final spec in sections)
        _SectionCard(
            l10n: l10n,
            spec: spec,
            section: s.sections.cast<ReportSection?>().firstWhere(
                (x) => x?.kind == spec.kind,
                orElse: () => null),
            onTap: () => context.push(spec.route)),
    ];
  }
}

class _SectionSpec {
  const _SectionSpec(this.titleKey, this.kind, this.icon, this.arrow,
      this.route);
  final String titleKey;
  final String kind;
  final IconData icon;
  final IconData arrow;
  final String route;
}

class _Scaffold extends StatelessWidget {
  const _Scaffold(
      {required this.l10n,
      required this.title,
      required this.runtime,
      required this.child});
  final AppLocalizations l10n;
  final String title;
    final AsyncValue<dynamic> runtime;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy.withOpacity(0.04),
      appBar: AppBar(
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
        title: Text(title),
        centerTitle: false,
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: child,
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.l10n,
    required this.notation,
    required this.onChanged,
  });
  final AppLocalizations l10n;
  final ReportPeriod notation;
  final void Function(ReportPeriod) onChanged;

  @override
  Widget build(BuildContext context) {
    final Map<ReportPeriod, String> labels = {
      ReportPeriod.week: l10n.t('rpWeek'),
      ReportPeriod.month: l10n.t('rpMonth'),
      ReportPeriod.custom: l10n.t('rpCustom'),
    };
    return GuardianCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in labels.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: notation == entry.key,
              selectedColor: GuardianTokens.guardianTeal,
              onSelected: (selected) {
                if (selected) onChanged(entry.key);
              },
            ),
        ],
      ),
    );
  }
}

class _FamilyBanner extends StatelessWidget {
  const _FamilyBanner({required this.l10n, required this.snapshot});
  final AppLocalizations l10n;
  final FamilyReportSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GuardianHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/family_reports.png',
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.insights, size: 22, color: Colors.white),
            const SizedBox(width: 8),
            Text(snapshot?.familyName ?? '—',
                style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            snapshot == null
                ? l10n.t('rpRangeUnknown')
                : '${l10n.t('rpRangeLabel')}: '
                    '${_short(snapshot!.start)} → ${_short(snapshot!.end)}',
            style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  String _short(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}

class _SectionCard extends StatelessWidget {
  const _SectionCard(
      {required this.l10n, required this.spec, required this.section,
      required this.onTap});

  final AppLocalizations l10n;
  final _SectionSpec spec;
  final ReportSection? section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = section?.isEmpty ?? true;
    final primaryMetric = section?.metrics.isEmpty == true
        ? '—'
        : (section?.metrics.first.value ?? '—');
    return GuardianCard(
      onTap: onTap,
      child: Row(
        children: [
          GuardianIconBadge(
            icon: spec.icon,
            background: isEmpty
                ? theme.colorScheme.outline.withOpacity(0.15)
                : GuardianTokens.guardianTeal.withOpacity(0.15),
            foreground: isEmpty
                ? theme.colorScheme.outline
                : GuardianTokens.guardianTeal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(l10n.t(spec.titleKey),
                          style: theme.textTheme.titleSmall),
                    ),
                    Icon(spec.arrow, size: 16,
                        color: theme.colorScheme.outline),
                  ],
                ),
                const SizedBox(height: 4),
                Text(isEmpty ? l10n.t('rpNoData') : primaryMetric,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: isEmpty
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── RP-002 Web report detail ─────────────────────────────────────────────────

class WebReportScreen extends ConsumerWidget {
  const WebReportScreen({super.key});
  static const route = '/reports/:familyId/web';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpWebTitle'),
        familyId: familyId,
        kind: ReportSectionKind.web,
        runtime: runtime,
        childBuilder: (section) => _WebSectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _WebSectionBody extends StatelessWidget {
  const _WebSectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpWebEmptyHint'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in section.metrics)
              GuardianStatTile(
                icon: Icons.analytics_outlined,
                value: metric.value,
                label: l10n.t(metric.labelKey),
                kind: metric.tone == ReportTone.warning
                    ? GuardianStatusKind.watch
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        GuardianSection(
          title: l10n.t('rpTopBlockedDomains'),
          children: [
            GuardianCard(
              child: Column(
                children: [
                  for (final row in section.rows) ...[
                    _RowItem(
                      leading: Icons.block,
                      title: row[0],
                      subtitle: row[1],
                      trailing: row[2],
                    ),
                    const Divider(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── RP-003 Usage report detail ───────────────────────────────────────────────

class UsageReportScreen extends ConsumerWidget {
  const UsageReportScreen({super.key});
  static const route = '/reports/:familyId/usage';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpUsageTitle'),
        familyId: familyId,
        kind: ReportSectionKind.usage,
        runtime: runtime,
        childBuilder: (section) => _UsageSectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _UsageSectionBody extends StatelessWidget {
  const _UsageSectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpUsageEmptyHint'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in section.metrics)
              GuardianStatTile(
                icon: Icons.timer,
                value: metric.value,
                label: l10n.t(metric.labelKey),
              ),
          ],
        ),
        const SizedBox(height: 14),
        GuardianSection(
          title: l10n.t('rpUsageByChild'),
          children: [
            GuardianCard(
              child: Column(
                children: [
                  for (final row in section.rows) ...[
                    _RowItem(
                      leading: Icons.child_care,
                      title: row[0],
                      trailing: row[1],
                    ),
                    const Divider(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── RP-004 Location report detail ────────────────────────────────────────────

class LocationReportScreen extends ConsumerWidget {
  const LocationReportScreen({super.key});
  static const route = '/reports/:familyId/location';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpLocationTitle'),
        familyId: familyId,
        kind: ReportSectionKind.location,
        runtime: runtime,
        childBuilder: (section) => _LocationSectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _LocationSectionBody extends StatelessWidget {
  const _LocationSectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpLocationEmptyHint'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metric in section.metrics)
          GuardianStatTile(
            icon: Icons.location_on,
            value: metric.value,
            label: l10n.t(metric.labelKey),
            kind: metric.tone == ReportTone.warning
                ? GuardianStatusKind.watch
                : null,
          ),
      ],
    );
  }
}

// ── RP-005 Safety report detail ──────────────────────────────────────────────

class SafetyReportScreen extends ConsumerWidget {
  const SafetyReportScreen({super.key});
  static const route = '/reports/:familyId/safety';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpSafetyTitle'),
        familyId: familyId,
        kind: ReportSectionKind.safety,
        runtime: runtime,
        childBuilder: (section) => _SafetySectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _SafetySectionBody extends StatelessWidget {
  const _SafetySectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpSafetyEmptyHint'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in section.metrics)
              GuardianStatTile(
                icon: Icons.shield,
                value: metric.value,
                label: l10n.t(metric.labelKey),
                kind: metric.tone == ReportTone.critical
                    ? GuardianStatusKind.alert
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

// ── RP-006 Modes report detail ───────────────────────────────────────────────

class ModesReportScreen extends ConsumerWidget {
  const ModesReportScreen({super.key});
  static const route = '/reports/:familyId/modes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpModesTitle'),
        familyId: familyId,
        kind: ReportSectionKind.modes,
        runtime: runtime,
        childBuilder: (section) => _ModesSectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _ModesSectionBody extends StatelessWidget {
  const _ModesSectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpModesEmptyHint'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metric in section.metrics)
          GuardianStatTile(
            icon: Icons.tune,
            value: metric.value,
            label: l10n.t(metric.labelKey),
          ),
      ],
    );
  }
}

// ── RP-007 SOS report detail ─────────────────────────────────────────────────

class SosReportScreen extends ConsumerWidget {
  const SosReportScreen({super.key});
  static const route = '/reports/:familyId/sos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: _SectionDetailScaffold(
        l10n: l10n,
        title: l10n.t('rpSosTitle'),
        familyId: familyId,
        kind: ReportSectionKind.sos,
        runtime: runtime,
        childBuilder: (section) => _SosSectionBody(
            l10n: l10n, section: section),
      ),
    );
  }
}

class _SosSectionBody extends StatelessWidget {
  const _SosSectionBody({required this.l10n, required this.section});
  final AppLocalizations l10n;
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    if (section.isEmpty) {
      return GuardianStateView(
        state: GuardianViewState.empty,
        title: l10n.t('rpNoData'),
        message: l10n.t('rpSosEmptyHint'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final metric in section.metrics)
          GuardianStatTile(
            icon: Icons.emergency,
            value: metric.value,
            label: l10n.t(metric.labelKey),
            kind: metric.tone == ReportTone.critical
                ? GuardianStatusKind.sos
                : null,
          ),
      ],
    );
  }
}

// ── RP-008 Export ────────────────────────────────────────────────────────────

class ReportExportScreen extends ConsumerStatefulWidget {
  const ReportExportScreen({super.key});
  static const route = '/reports/:familyId/export';

  @override
  ConsumerState<ReportExportScreen> createState() =>
      _ReportExportScreenState();
}

class _ReportExportScreenState extends ConsumerState<ReportExportScreen> {
  ReportFormat _format = ReportFormat.pdf;
  bool _exporting = false;
  String? _exportError;
  String? _exportPath;

  Future<void> _export() async {
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final period = ref.read(reportsPeriodNotifierProvider(familyId));
    setState(() {
      _exporting = true;
      _exportError = null;
      _exportPath = null;
    });
    try {
      final repo = ref.read(reportsRepositoryProvider);
      final snapshot = await repo.snapshotFor(
          familyId: familyId, period: period);
      final file = await ReportExportService()
          .export(snapshot: snapshot, format: _format);
      setState(() {
        _exporting = false;
        _exportPath = file.path;
      });
    } catch (e) {
      setState(() {
        _exporting = false;
        _exportError = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyId =
        GoRouterState.of(context).pathParameters['familyId'] ?? '';
    final runtime =
        ref.watch(familyRuntimeContextProvider(familyId));

    return _guardedScaffold(
      context: context,
      l10n: l10n,
      runtime: runtime,
      requiredPermission: FamilyPermission.viewReports,
      child: Scaffold(
        backgroundColor: GuardianTokens.guardianNavy.withOpacity(0.04),
        appBar: AppBar(
          backgroundColor: GuardianTokens.guardianNavy,
          foregroundColor: Colors.white,
          title: Text(l10n.t('rpExportTitle')),
        ),
        body: Directionality(
          textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuardianSection(
                  title: l10n.t('rpExportFormat'),
                  children: [
                    GuardianCard(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.t('rpFormatPdf')),
                            selected: _format == ReportFormat.pdf,
                            selectedColor: GuardianTokens.guardianTeal,
                            onSelected: (s) {
                              if (s) setState(() => _format = ReportFormat.pdf);
                            },
                          ),
                          ChoiceChip(
                            label: Text(l10n.t('rpFormatCsv')),
                            selected: _format == ReportFormat.csv,
                            selectedColor: GuardianTokens.guardianTeal,
                            onSelected: (s) {
                              if (s) setState(() => _format = ReportFormat.csv);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download_outlined),
                  label: Text(_exporting
                      ? l10n.t('rpExporting')
                      : l10n.t('rpExportButton')),
                ),
                const SizedBox(height: 14),
                if (_exportError != null)
                  GuardianStateView(
                    state: GuardianViewState.error,
                    title: l10n.t('rpExportFailed'),
                    message: l10n.t('rpExportRetryHint'),
                    primaryActionLabel: l10n.t('retry'),
                    onRetry: _export,
                  )
                else if (_exportPath != null)
                  GuardianCard(
                    color: GuardianTokens.guardianTeal.withOpacity(0.12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.check_circle,
                              color: GuardianTokens.guardianTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(l10n.t('rpExportSaved'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(_exportPath!,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () {
                            Share.shareXFiles([XFile(_exportPath!)],
                                subject: l10n.t('rpExportSubject'));
                          },
                          icon: const Icon(Icons.share),
                          label: Text(l10n.t('rpShareButton')),
                        ),
                      ],
                    ),
                  )
                else
                  Text(l10n.t('rpExportHint'),
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared detail scaffold ───────────────────────────────────────────────────

class _SectionDetailScaffold extends ConsumerWidget {
  const _SectionDetailScaffold({
    required this.l10n,
    required this.title,
    required this.familyId,
    required this.kind,
    required this.runtime,
    required this.childBuilder,
  });
  final AppLocalizations l10n;
  final String title;
  final String familyId;
  final String kind;
  final AsyncValue<dynamic> runtime;
  final Widget Function(ReportSection) childBuilder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period =
        ref.watch(reportsPeriodNotifierProvider(familyId));
    final snapshot =
        ref.watch(reportsSnapshotProvider((familyId: familyId, period: period)));
    final section = snapshot.valueOrNull?.sections
        .cast<ReportSection?>()
        .firstWhere((x) => x?.kind == kind, orElse: () => null);

    Widget body;
    if (snapshot.error != null) {
      body = GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('rpLoadFailed'),
        message: l10n.t('rpLoadRetryHint'),
      );
    } else if (section == null) {
      body = const GuardianStateView(state: GuardianViewState.loading);
    } else {
      body = Column(children: [
        // Period context strip: keeps the selected window visible so the
        // detail page never reads as period-less.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: l10n.isRtl ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              l10n.t(period == ReportPeriod.month ? 'rpPeriodMonth' : 'rpPeriodWeek'),
              style: TextStyle(
                  fontSize: 12,
                  color: GuardianTokens.guardianTeal,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: childBuilder(section),
          ),
        ),
      ]);
    }

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy.withOpacity(0.04),
      appBar: AppBar(
        backgroundColor: GuardianTokens.guardianNavy,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: body,
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem(
      {required this.leading,
      required this.title,
      this.subtitle,
      required this.trailing});
  final IconData leading;
  final String title;
  final String? subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(leading, size: 18, color: GuardianTokens.guardianNavy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(title, style: theme.textTheme.bodyMedium),
            if (subtitle != null)
              Text(subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
          ]),
        ),
        Text(trailing,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
