import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/guardian_ai_models.dart';
import '../../data/family_event_registry_repository.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// Guardian AI screens (A-001 … A-013).
///
/// Built on the local event registry (Phase 9). Every number shown here has a
/// provenance trail in the transparency center — the model is deterministic
/// and its availability is disclosed on screen (`modelVersion='none'` until a
/// configured model exists). Risk verdicts are **observation only**: the AI
/// never changes a rule or a mode by itself; proposals go through L9 where a
/// parent explicitly approves them. Screens are permission-gated through
/// `FamilyRuntimeContext.can()` exactly like every other subsystem.

// ── Shared helpers ──────────────────────────────────────────────────────────

GuardianStatusKind _riskKind(AiRiskLevel level) => switch (level) {
      AiRiskLevel.safe => GuardianStatusKind.safe,
      AiRiskLevel.watch => GuardianStatusKind.watch,
      AiRiskLevel.alert => GuardianStatusKind.alert,
    };

String _levelLabel(AppLocalizations l10n, AiRiskLevel level) => switch (level) {
      AiRiskLevel.safe => l10n.t('aiRiskSafe'),
      AiRiskLevel.watch => l10n.t('aiRiskWatch'),
      AiRiskLevel.alert => l10n.t('aiRiskAlert'),
    };

String _sufficiencyLabel(AppLocalizations l10n, AiDataSufficiency s) =>
    switch (s) {
  AiDataSufficiency.sufficient => l10n.t('aiDataSufficient'),
  AiDataSufficiency.partial => l10n.t('aiDataPartial'),
  AiDataSufficiency.insufficient => l10n.t('aiDataInsufficient'),
};

String _suggestionStatus(AppLocalizations l10n, CopilotSuggestionStatus s) =>
    switch (s) {
  CopilotSuggestionStatus.open => l10n.t('aiSuggestionOpen'),
  CopilotSuggestionStatus.applied => l10n.t('aiSuggestionApplied'),
  CopilotSuggestionStatus.dismissed => l10n.t('aiSuggestionDismissed'),
};

String _proposalStatus(AppLocalizations l10n, PolicyProposalStatus s) =>
    switch (s) {
  PolicyProposalStatus.proposed => l10n.t('aiProposalProposed'),
  PolicyProposalStatus.approved => l10n.t('aiProposalApproved'),
  PolicyProposalStatus.rejected => l10n.t('aiProposalRejected'),
  PolicyProposalStatus.applied => l10n.t('aiProposalApplied'),
};

/// Note: the raw Outcome label is shown in the transparency feed through
/// `_TransparencyTile`; this helper exists for any future caller.
// ignore: unused_element
String _outcomeLabel(AppLocalizations l10n, String outcomeName) =>
    switch (outcomeName) {
  'normalized' => l10n.t('aiTransparencyProcessed'),
  'rejected' => l10n.t('aiTransparencyRejected'),
  'consentBlocked' => l10n.t('aiTransparencyConsentBlocked'),
  'duplicate' => l10n.t('aiTransparencyDuplicates'),
  _ => l10n.t('aiTransparencyProcessed'),
};

String _dimensionLabel(AppLocalizations l10n, String key) => switch (key) {
      'usage_balance' => l10n.t('aiDimUsageBalance'),
      'safety_incidents' => l10n.t('aiDimSafetyIncidents'),
      'sleep_offline' => l10n.t('aiDimSleepOffline'),
      'connection_minutes' => l10n.t('aiDimConnectionMinutes'),
      _ => l10n.t('aiDimUsageBalance'),
    };

String _dimensionNote(AppLocalizations l10n, String noteKey) => switch (noteKey) {
      'aiDimUsageBalanceNote' => l10n.t('aiDimUsageBalanceNote'),
      'aiDimSafetyIncidentsNote' => l10n.t('aiDimSafetyIncidentsNote'),
      'aiDimSleepOfflineNote' => l10n.t('aiDimSleepOfflineNote'),
      'aiDimConnectionMinutesNote' => l10n.t('aiDimConnectionMinutesNote'),
      _ => l10n.t('aiDimUsageBalanceNote'),
    };

String _titleKeyLabel(AppLocalizations l10n, String key) => switch (key) {
      'aiInsightStableWeek' => l10n.t('aiInsightStableWeek'),
      'aiInsightNightUsageUp' => l10n.t('aiInsightNightUsageUp'),
      'aiInsightIncidentsUp' => l10n.t('aiInsightIncidentsUp'),
      'aiInsightInsufficientData' => l10n.t('aiInsightInsufficientData'),
      _ => l10n.t('aiInsightInsufficientData'),
    };

String _bodyKeyLabel(AppLocalizations l10n, String key) => switch (key) {
      'aiInsightStableWeekBody' => l10n.t('aiInsightStableWeekBody'),
      'aiInsightNightUsageUpBody' => l10n.t('aiInsightNightUsageUpBody'),
      'aiInsightIncidentsUpBody' => l10n.t('aiInsightIncidentsUpBody'),
      'aiInsightInsufficientDataNote' => l10n.t('aiInsightInsufficientDataNote'),
      _ => l10n.t('aiInsightInsufficientDataNote'),
    };

String _metricKeyLabel(AppLocalizations l10n, String key) => switch (key) {
      'aiMetricEventsSeen' => l10n.t('aiMetricEventsSeen'),
      'aiMetricNightSessions' => l10n.t('aiMetricNightSessions'),
      'aiMetricIncidents' => l10n.t('aiMetricIncidents'),
      'aiMetricOverallScore' => l10n.t('aiMetricOverallScore'),
      _ => l10n.t('aiMetricEventsSeen'),
    };

String _contributorLabel(AppLocalizations l10n, String key) => switch (key) {
      'aiContributorSos' => l10n.t('aiContributorSos'),
      'aiContributorIncidentHigh' => l10n.t('aiContributorIncidentHigh'),
      'aiContributorGeofenceEntry' => l10n.t('aiContributorGeofenceEntry'),
      'aiContributorNightUsage' => l10n.t('aiContributorNightUsage'),
      'aiContributorUsageDeviation' => l10n.t('aiContributorUsageDeviation'),
      _ => l10n.t('aiContributorUsageDeviation'),
    };

String _suggestionTitle(AppLocalizations l10n, String key) => switch (key) {
      'aiSuggestionReviewNightRoutine' =>
        l10n.t('aiSuggestionReviewNightRoutine'),
      'aiSuggestionReviewAlert' => l10n.t('aiSuggestionReviewAlert'),
      'aiSuggestionConsistency' => l10n.t('aiSuggestionConsistency'),
      _ => l10n.t('aiSuggestionConsistency'),
    };

String _explanationTitle(AppLocalizations l10n, String key) => switch (key) {
      'aiExplainNoSignals' => l10n.t('aiExplainNoSignals'),
      'aiExplainNoChange' => l10n.t('aiExplainNoChange'),
      'aiExplainWatchSignals' => l10n.t('aiExplainWatchSignals'),
      'aiExplainAlertSignals' => l10n.t('aiExplainAlertSignals'),
      _ => l10n.t('aiExplainFallback'),
    };

String _explanationBody(AppLocalizations l10n, String key) => switch (key) {
      'aiExplainBodyNoSignals' => l10n.t('aiExplainBodyNoSignals'),
      'aiExplainBodyNoChange' => l10n.t('aiExplainBodyNoChange'),
      'aiExplainBodySignals' => l10n.t('aiExplainBodySignals'),
      _ => l10n.t('aiExplainFallback'),
    };

// ── Shared guard ────────────────────────────────────────────────────────────

/// Permission/async gate. Returns null when the screen content may render.
AsyncValueGuard? _guardIfBlocked(
  BuildContext context,
  WidgetRef ref,
  AsyncValue<Object?> runtime,
  AsyncValue<Object?> data,
  FamilyPermission permission,
  ProviderOrFamily retrySource,
) {
  final l10n = AppLocalizations.of(context);
  if (runtime.hasError || data.hasError) {
    return AsyncValueGuard.shielded(
      view: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('monitoringSyncFailed'),
        message: l10n.t('somethingWentWrong'),
        onRetry: () => ref.invalidate(retrySource),
      ),
    );
  }
  if (runtime.isLoading || data.isLoading) {
    return AsyncValueGuard.shielded(
        view: const GuardianStateView(state: GuardianViewState.loading));
  }
  final ctx = runtime.valueOrNull is FamilyRuntimeContext
      ? runtime.valueOrNull as FamilyRuntimeContext
      : null;
  if (ctx == null) {
    return AsyncValueGuard.shielded(
        view: const GuardianStateView(state: GuardianViewState.loading));
  }
  if (!ctx.can(permission)) {
    return AsyncValueGuard.shielded(
      view: GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('roleNotAllowed'),
        message: l10n.t('authorizationFailure'),
      ),
    );
  }
  return null;
}

/// Small wrapper used to distinguish "guard active" from "guard clear".
class AsyncValueGuard {
  const AsyncValueGuard.shielded({required this.view});
  final Widget view;
}

// ═══════════════════ A-001 — Insights Hub (dashboard) ═══════════════════════
/// `/insights/:familyId` — A-001. Hero scorecard, live risk verdicts, digest,
/// and routes to every downstream AI screen. Honest by construction: the
/// hub discloses `modelVersion='none'` and each insight's data sufficiency.
class InsightsHubScreen extends ConsumerWidget {
  const InsightsHubScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final scorecardAsync = ref.watch(aiScorecardProvider(familyId));
    final riskAsync = ref.watch(aiRiskStatesProvider(familyId));
    final insightAsync = ref.watch(aiInsightsProvider(familyId));
    final suggestionAsync = ref.watch(aiSuggestionsProvider(familyId));
    final availability = ref.watch(aiModelAvailabilityProvider);
    final guard = _guardIfBlocked(context, ref, runtime, scorecardAsync,
        FamilyPermission.viewAiInsights, aiScorecardProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiHubTitle')),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  GuardianCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: GuardianTokens.guardianTeal, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              !availability.isAvailable
                                  ? l10n.t('aiModelNoneNote')
                                  : l10n.t('aiFailClosedNote'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (scorecardAsync.valueOrNull != null)
                    GuardianHeroCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.t('aiHubScorecard'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(l10n.t('aiHubScorecardSubtitle'),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Text(
                            '${(scorecardAsync.valueOrNull?.overall ?? 0).toInt()}',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: GuardianTokens.guardianTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (scorecardAsync.valueOrNull != null)
                    _DimensionGrid(scorecard: scorecardAsync.valueOrNull!),
                  const SizedBox(height: 8),
                  _RiskVerdictsList(familyId: familyId, states: riskAsync),
                  const SizedBox(height: 8),
                  _DigestStrip(familyId: familyId, insights: insightAsync),
                  const SizedBox(height: 8),
                  _OpenSuggestionsStrip(
                      familyId: familyId, suggestions: suggestionAsync),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _HubDestinationsCard(familyId: familyId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionGrid extends StatelessWidget {
  const _DimensionGrid({required this.scorecard});
  final FamilyHealthScorecard scorecard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: scorecard.dimensions.map((dim) {
          final color = dim.score >= 70
              ? GuardianTokens.guardianTeal
              : dim.score >= 40
                  ? const Color(0xFFE9A100)
                  : const Color(0xFFD64545);
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 48) / 2,
            child: GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dimensionLabel(l10n, dim.key),
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      '${dim.score.toInt()}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_dimensionNote(l10n, dim.noteKey),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RiskVerdictsList extends StatelessWidget {
  const _RiskVerdictsList({required this.familyId, required this.states});
  final String familyId;
  final AsyncValue<List<AiRiskState>> states;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = states.valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GuardianSection(
        title: l10n.t('aiHubRiskTitle'),
        children: [
          if (states.hasError)
            GuardianStateView(
              state: GuardianViewState.error,
              title: l10n.t('aiHubRiskTitle'),
              message: l10n.t('somethingWentWrong'),
            ),
          if (items.isEmpty && !states.hasError)
            GuardianStateView(
              state: GuardianViewState.empty,
              title: l10n.t('aiRiskEmpty'),
              message: l10n.t('aiRiskEmptyNote'),
            ),
          for (final state in items)
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GuardianStatusChip(
                          kind: _riskKind(state.level),
                          label: _levelLabel(l10n, state.level),
                        ),
                        const Spacer(),
                        if (state.deterministicOnly)
                          Text(l10n.t('aiFailClosedNote'),
                              style:
                                  const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final c in state.contributors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 12, color: Colors.white70),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _contributorLabel(l10n, c.labelKey),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DigestStrip extends StatelessWidget {
  const _DigestStrip({required this.familyId, required this.insights});
  final String familyId;
  final AsyncValue<List<FamilyInsight>> insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = insights.valueOrNull ?? const [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GuardianSection(
        title: l10n.t('aiHubDigest'),
        children: [
          if (items.isEmpty && !insights.hasError)
            GuardianStateView(
              state: GuardianViewState.empty,
              title: l10n.t('aiInsightInsufficientData'),
              message: l10n.t('aiDigestEmpty'),
            ),
          for (final insight in items)
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_titleKeyLabel(l10n, insight.titleKey),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        Text(
                            _sufficiencyLabel(l10n, insight.dataSufficiency),
                            style:
                                const TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_bodyKeyLabel(l10n, insight.bodyKey),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 6),
                    for (final metric in insight.metrics)
                      Row(
                        children: [
                          Text(_metricKeyLabel(l10n, metric.labelKey),
                              style: const TextStyle(fontSize: 11)),
                          const Spacer(),
                          Text(metric.value,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: GuardianTokens.guardianTeal)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenSuggestionsStrip extends StatelessWidget {
  const _OpenSuggestionsStrip(
      {required this.familyId, required this.suggestions});
  final String familyId;
  final AsyncValue<List<CopilotSuggestion>> suggestions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = (suggestions.valueOrNull ?? const [])
        .where((s) => s.status == CopilotSuggestionStatus.open)
        .take(2)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GuardianSection(
        title: l10n.t('aiHubSuggestions'),
        children: [
          if (items.isEmpty && !suggestions.hasError)
            GuardianStateView(
              state: GuardianViewState.empty,
              title: l10n.t('aiHubSuggestions'),
              message: l10n.t('aiSuggestionEmpty'),
            ),
          for (final s in items)
            GuardianCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_suggestionTitle(l10n, s.titleKey),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(l10n.t('aiSuggestionBody'),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go(CopilotSuggestionsScreen.route),
                        child: Text(l10n.t('aiHubViewAll')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubDestinationsCard extends StatelessWidget {
  const _HubDestinationsCard({required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            _HubTile(
              title: l10n.t('aiHubRisk'),
              subtitle: l10n.t('aiHubRiskSubtitle'),
              icon: Icons.shield_outlined,
              onTap: () => context.go(ChildRiskScreen.route),
            ),
            _HubTile(
              title: l10n.t('aiHubCopilot'),
              subtitle: l10n.t('aiHubCopilotSubtitle'),
              icon: Icons.lightbulb_outline,
              onTap: () =>
                  context.go(CopilotSuggestionsScreen.route),
            ),
            _HubTile(
              title: l10n.t('aiHubPolicy'),
              subtitle: l10n.t('aiHubPolicySubtitle'),
              icon: Icons.scale_outlined,
              onTap: () => context.go(PolicyIntelligenceScreen.route),
            ),
            _HubTile(
              title: l10n.t('aiHubDetections'),
              subtitle: l10n.t('aiHubDetectionsSubtitle'),
              icon: Icons.search_outlined,
              onTap: () => context.go(DetectionsConsoleScreen.route),
            ),
            _HubTile(
              title: l10n.t('aiHubTransparency'),
              subtitle: l10n.t('aiHubTransparencySubtitle'),
              icon: Icons.visibility_outlined,
              onTap: () =>
                  context.go(TransparencyCenterScreen.route),
            ),
            _HubTile(
              title: l10n.t('aiHubPrivacy'),
              subtitle: l10n.t('aiHubPrivacySubtitle'),
              icon: Icons.lock_outline,
              onTap: () => context.go(AiPrivacyCenterScreen.route),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: GuardianTokens.guardianTeal),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ═══════════════ A-002 — Child Risk Console ═════════════════════════════════
/// `/insights/:familyId/risk` — A-002. Per-child risk verdicts with the full
/// contributor chain, every one linked to a real signal key. Verdicts are
/// observations; actions always live behind A-005.
class ChildRiskScreen extends ConsumerWidget {
  const ChildRiskScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/risk';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final statesAsync = ref.watch(aiRiskStatesProvider(familyId));
    final explanationsAsync = ref.watch(
        aiExplanationsProvider((familyId: familyId, childIds: const [])));
    final guard = _guardIfBlocked(context, ref, runtime, statesAsync,
        FamilyPermission.viewAiInsights, aiRiskStatesProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    final states = statesAsync.valueOrNull ?? const [];
    final explanations = explanationsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiRiskTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.t('aiRiskObservationOnly'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (states.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('aiRiskEmpty'),
                        message: l10n.t('aiRiskEmptyNote'),
                      ),
                    for (final state in states)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GuardianStatusChip(
                                    kind: _riskKind(state.level),
                                    label: _levelLabel(l10n, state.level),
                                  ),
                                  const Spacer(),
                                  Text(state.childId,
                                      style:
                                          const TextStyle(fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final explanation
                                  in explanations
                                      .where((e) =>
                                          e.referenceId == state.id)) ...[
                                Text(
                                  _explanationTitle(l10n, explanation.titleKey),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _explanationBody(l10n, explanation.bodyKey),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ A-003 — Copilot Suggestions ════════════════════════════════
/// `/insights/:familyId/copilot` — A-003. Actionable cards; applying one only
/// stages it for the parent to act on the corresponding subsystem screen —
/// the AI never executes anything by itself.
class CopilotSuggestionsScreen extends ConsumerWidget {
  const CopilotSuggestionsScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/copilot';

  Future<void> _decide(WidgetRef ref, CopilotSuggestion s,
      CopilotSuggestionStatus status) async {
    await ref
        .read(aiInsightRepositoryProvider)
        .decideSuggestion(familyId, s.id, status: status);
    ref.invalidate(aiSuggestionsProvider(familyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final suggestionsAsync = ref.watch(aiSuggestionsProvider(familyId));
    final guard = _guardIfBlocked(context, ref, runtime, suggestionsAsync,
        FamilyPermission.viewAiInsights, aiSuggestionsProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    final items = suggestionsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiCopilotTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('aiCopilotTitle'),
                        message: l10n.t('aiSuggestionEmpty'),
                      ),
                    for (final s in items)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                        _suggestionTitle(l10n, s.titleKey),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ),
                                  GuardianStatusChip(
                                    kind: s.status ==
                                            CopilotSuggestionStatus.open
                                        ? GuardianStatusKind.watch
                                        : s.status ==
                                                CopilotSuggestionStatus
                                                    .applied
                                            ? GuardianStatusKind.safe
                                            : GuardianStatusKind.offline,
                                    label: _suggestionStatus(l10n, s.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(l10n.t('aiSuggestionBody'),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text(l10n.t('aiSuggestionRationale'),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white70)),
                              const SizedBox(height: 12),
                              if (s.status == CopilotSuggestionStatus.open)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () => _decide(ref, s,
                                            CopilotSuggestionStatus.dismissed),
                                        child: Text(l10n.t('aiSuggestionDismiss')),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _decide(ref, s,
                                            CopilotSuggestionStatus.applied),
                                        child: Text(l10n.t('aiSuggestionApply')),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ A-004 — Policy Intelligence ════════════════════════════════
/// `/insights/:familyId/policy` — A-004. Proposals are *never* self-applied:
/// approval stages the proposal; applying it requires an explicit second
/// action, and the target rule must exist in FS-011.
class PolicyIntelligenceScreen extends ConsumerWidget {
  const PolicyIntelligenceScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/policy';

  Future<void> _decide(WidgetRef ref, PolicyProposal p,
      PolicyProposalStatus status) async {
    await ref
        .read(aiInsightRepositoryProvider)
        .decideProposal(familyId, p.id, status: status);
    ref.invalidate(aiProposalsProvider(familyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final proposalsAsync = ref.watch(aiProposalsProvider(familyId));
    final guard = _guardIfBlocked(context, ref, runtime, proposalsAsync,
        FamilyPermission.viewAiInsights, aiProposalsProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    final items = proposalsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiPolicyTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_outlined,
                                color: Color(0xFFE9A100)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.t('aiPolicyNeverSelfApply'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('aiPolicyTitle'),
                        message: l10n.t('aiPolicyEmpty'),
                      ),
                    for (final p in items)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(l10n.t('aiProposalNightLimitTitle'),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ),
                                  GuardianStatusChip(
                                    kind: p.status ==
                                            PolicyProposalStatus.proposed
                                        ? GuardianStatusKind.watch
                                        : p.status ==
                                                PolicyProposalStatus.approved
                                            ? GuardianStatusKind.safe
                                            : p.status ==
                                                    PolicyProposalStatus.applied
                                                ? GuardianStatusKind.safe
                                                : GuardianStatusKind.offline,
                                    label: _proposalStatus(l10n, p.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                  l10n.t('aiProposalNightLimitRationale'),
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 12),
                              if (p.status == PolicyProposalStatus.proposed)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () => _decide(ref, p,
                                            PolicyProposalStatus.rejected),
                                        child: Text(l10n.t('aiProposalReject')),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _decide(ref, p,
                                            PolicyProposalStatus.approved),
                                        child: Text(l10n.t('aiProposalApprove')),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ A-005 — Detections Console ═════════════════════════════════
/// `/insights/:familyId/detections` — A-005. The evidence-first review desk:
/// every detection carries its model version and confidence band, and
/// reviewing is an explicit human act.
class DetectionsConsoleScreen extends ConsumerWidget {
  const DetectionsConsoleScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/detections';

  Future<void> _review(WidgetRef ref, AiDetectionResult d) async {
    await ref
        .read(aiInsightRepositoryProvider)
        .markDetectionReviewed(familyId, d.id, reviewed: true);
    ref.invalidate(aiDetectionsProvider(familyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final detectionsAsync = ref.watch(aiDetectionsProvider(familyId));
    final guard = _guardIfBlocked(context, ref, runtime, detectionsAsync,
        FamilyPermission.viewAiInsights, aiDetectionsProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    final items = detectionsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiDetectionsTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('aiDetectionsTitle'),
                        message: l10n.t('aiDetectionsEmpty'),
                      ),
                    for (final d in items)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(d.category,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ),
                                  GuardianStatusChip(
                                    kind: d.reviewed
                                        ? GuardianStatusKind.safe
                                        : GuardianStatusKind.watch,
                                    label: d.reviewed
                                        ? l10n.t('aiDetectionsReviewed')
                                        : l10n.t('aiDetectionsPending'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${l10n.t('aiDetectionsModel')}: ${d.modelVersion} · '
                                '${l10n.t('aiDetectionsDetectedAt')}: '
                                '${d.detectedAt.toLocal().month}/${d.detectedAt.toLocal().day} '
                                '${d.detectedAt.toLocal().hour}:${d.detectedAt.toLocal().minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              if (!d.reviewed)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () => _review(ref, d),
                                    child: Text(
                                        l10n.t('aiDetectionsMarkReviewed')),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ A-006 — Transparency Center ════════════════════════════════
/// `/insights/:familyId/transparency` — A-006. The ledger behind every AI
/// number: processed / rejected / consent-blocked / duplicates, unmapped
/// types, and a family-wide purge with confirmation.
class TransparencyCenterScreen extends ConsumerWidget {
  const TransparencyCenterScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/transparency';

  Future<void> _purge(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GuardianTokens.guardianNavy,
        title: Text(AppLocalizations.of(c).t('aiPurgeConfirmTitle')),
        content: Text(AppLocalizations.of(c).t('aiPurgeConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(AppLocalizations.of(c).t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(AppLocalizations.of(c).t('confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(aiRegistryRepositoryProvider)
          .deleteFamilyEvents(familyId);
      ref.invalidate(aiEventsProvider(familyId));
      ref.invalidate(aiSignalsProvider(familyId));
      ref.invalidate(aiTransparencyProvider(familyId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final reportAsync = ref.watch(aiTransparencyProvider(familyId));
    final guard = _guardIfBlocked(context, ref, runtime, reportAsync,
        FamilyPermission.viewAiInsights, aiTransparencyProvider(familyId));
    if (guard != null) return Scaffold(body: guard.view);

    final report = reportAsync.valueOrNull;

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiTransparencyTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report == null)
                      const GuardianStateView(
                          state: GuardianViewState.loading),
                    if (report != null) ...[
                      GuardianHeroCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.t('aiTransparencyModel'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.modelVersion == 'none'
                                        ? l10n.t('aiModelNoneNote')
                                        : l10n.t('aiTransparencyModel'),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            Text(report.modelVersion,
                                style: const TextStyle(fontSize: 20)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CountRow(l10n,
                                  label: l10n.t('aiTransparencyProcessed'),
                                  value: report.eventsProcessed),
                              _CountRow(l10n,
                                  label: l10n.t('aiTransparencyRejected'),
                                  value: report.rejectedCount),
                              _CountRow(l10n,
                                  label: l10n.t(
                                      'aiTransparencyConsentBlocked'),
                                  value: report.consentBlockedCount),
                              _CountRow(l10n,
                                  label: l10n.t('aiTransparencyDuplicates'),
                                  value: report.duplicatesSkipped),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.t('aiTransparencyUnmapped'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              if (report.unmappedTypes.isEmpty)
                                Text(l10n.t('aiTransparencyNoUnmapped'),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                              for (final type in report.unmappedTypes)
                                Text('· $type',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _purge(ref, context),
                          child: Text(l10n.t('aiPurgeAll')),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow(this.l10n, {required this.label, required this.value});
  final AppLocalizations l10n;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ═══════════════ A-007 — AI Privacy Center ══════════════════════════════════
/// `/insights/:familyId/privacy` — A-007. The family's consent scope: the AI
/// is fail-closed until an owner parent opts each data class in, and each
/// class is disclosed independently (operational / behavioural / location /
/// biometric).
class AiPrivacyCenterScreen extends ConsumerStatefulWidget {
  const AiPrivacyCenterScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/insights/:familyId/privacy';

  @override
  ConsumerState<AiPrivacyCenterScreen> createState() =>
      _AiPrivacyCenterScreenState();
}

class _AiPrivacyCenterScreenState
    extends ConsumerState<AiPrivacyCenterScreen> {
  Future<void> _toggle(AiConsentScope Function(AiConsentScope) setter) async {
    final current = ref.read(aiConsentScopeProvider(widget.familyId));
    ref.read(aiConsentScopeProvider(widget.familyId).notifier).state =
        setter(current);
    ref.invalidate(aiInsightsProvider(widget.familyId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final runtimeGuard = _guardIfBlocked(context, ref, runtime, const AsyncValue.data(null),
        FamilyPermission.manageAiConsent, aiConsentScopeProvider(widget.familyId));
    if (runtimeGuard != null) return Scaffold(body: runtimeGuard.view);

    final scope = ref.watch(aiConsentScopeProvider(widget.familyId));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('aiPrivacyTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GuardianCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline,
                                color: GuardianTokens.guardianTeal, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.t('aiPrivacyFailClosedNote'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GuardianSection(
                      title: l10n.t('aiPrivacyScope'),
                      children: [
                        _ConsentRow(
                          title: l10n.t('aiPrivacyOperational'),
                          subtitle: l10n.t('aiPrivacyOperationalNote'),
                          granted: scope.processOperational,
                          locked: true,
                          onToggle: () {},
                        ),
                        _ConsentRow(
                          title: l10n.t('aiPrivacyBehavioural'),
                          subtitle: l10n.t('aiPrivacyBehaviouralNote'),
                          granted: scope.processBehavioural,
                          locked: false,
                          onToggle: () => _toggle(
                            (s) => s.copyWith(
                                processBehavioural: !s.processBehavioural),
                          ),
                        ),
                        _ConsentRow(
                          title: l10n.t('aiPrivacyLocation'),
                          subtitle: l10n.t('aiPrivacyLocationNote'),
                          granted: scope.processLocation,
                          locked: false,
                          onToggle: () => _toggle(
                            (s) =>
                                s.copyWith(processLocation: !s.processLocation),
                          ),
                        ),
                        _ConsentRow(
                          title: l10n.t('aiPrivacyBiometric'),
                          subtitle: l10n.t('aiPrivacyBiometricNote'),
                          granted: scope.processBiometric,
                          locked: false,
                          onToggle: () => _toggle(
                            (s) =>
                                s.copyWith(processBiometric: !s.processBiometric),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.locked,
    required this.onToggle,
  });
  final String title;
  final String subtitle;
  final bool granted;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            if (locked)
              GuardianStatusChip(
                kind: GuardianStatusKind.neutral,
                label: AppLocalizations.of(context).t('aiPrivacyLocked'),
              )
            else
              Switch.adaptive(
                value: granted,
                onChanged: (_) => onToggle(),
              ),
          ],
        ),
      ),
    );
  }
}
