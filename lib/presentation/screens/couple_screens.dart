import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/family_context_provider.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/couple_harmony.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// FS-013 — Couple Harmony screens (C-001 … C-007).
///
/// Spouses are first-class participants who **never gain device authority**:
/// nothing here mutates a rule by itself. Every proposal is a mutual request
/// that only materialises once the other spouse explicitly approves it, and
/// expired proposals flip visibly to `expired` instead of silently applying.
/// All screens are permission-gated through `FamilyRuntimeContext.can()`.

String _stateLabel(AppLocalizations l10n, CoupleLinkingState s) => switch (s) {
      CoupleLinkingState.requested => l10n.t('coupleLinkingPending'),
      CoupleLinkingState.accepted => l10n.t('coupleLinkingLinked'),
      CoupleLinkingState.declined => l10n.t('coupleProposalDeclined'),
    };

String _proposalStatus(AppLocalizations l10n, CoupleProposalStatus s) =>
    switch (s) {
  CoupleProposalStatus.pending => l10n.t('aiProposalProposed'),
  CoupleProposalStatus.approved => l10n.t('aiProposalApproved'),
  CoupleProposalStatus.rejected => l10n.t('aiProposalRejected'),
  CoupleProposalStatus.expired => l10n.t('coupleProposalExpired'),
};

String _weekdayName(AppLocalizations l10n, int weekday) => switch (weekday) {
      DateTime.monday => l10n.t('weekdayMonday'),
      DateTime.tuesday => l10n.t('weekdayTuesday'),
      DateTime.wednesday => l10n.t('weekdayWednesday'),
      DateTime.thursday => l10n.t('weekdayThursday'),
      DateTime.friday => l10n.t('weekdayFriday'),
      DateTime.saturday => l10n.t('weekdaySaturday'),
      DateTime.sunday => l10n.t('weekdaySunday'),
      _ => '$weekday',
    };

String _timeFromMinute(int minute) =>
    '${minute ~/ 60}:${(minute % 60).toString().padLeft(2, '0')}';

String _proposalKindTitle(AppLocalizations l10n, CoupleProposalKind kind) =>
    switch (kind) {
  CoupleProposalKind.locationSharing =>
    l10n.t('coupleKindLocationSharing'),
  CoupleProposalKind.appBlockingRule =>
    l10n.t('coupleKindAppBlocking'),
  CoupleProposalKind.screenTimeRule =>
    l10n.t('coupleKindScreenTime'),
  CoupleProposalKind.routine =>
    l10n.t('coupleKindRoutine'),
  CoupleProposalKind.responsibility =>
    l10n.t('coupleKindResponsibility'),
};

String _responsibilityArea(AppLocalizations l10n, String areaKey) =>
    switch (areaKey) {
  'school_runs' => l10n.t('coupleAreaSchoolRuns'),
  'homework' => l10n.t('coupleAreaHomework'),
  'screen_time_enforcement' => l10n.t('coupleAreaScreenTime'),
  'appointments' => l10n.t('coupleAreaAppointments'),
  _ => l10n.t('coupleAreaSchoolRuns'),
};

String _handoverStatus(AppLocalizations l10n, HandoverStatus s) => switch (s) {
      HandoverStatus.pending => l10n.t('coupleHandoverPending'),
      HandoverStatus.active => l10n.t('coupleHandoverActive'),
      HandoverStatus.completed => l10n.t('coupleHandoverCompleted'),
    };

GuardianStatusKind _handoverKind(HandoverStatus s) => switch (s) {
      HandoverStatus.pending => GuardianStatusKind.watch,
      HandoverStatus.active => GuardianStatusKind.alert,
      HandoverStatus.completed => GuardianStatusKind.safe,
    };

// ═══════════════ C-001 — Couple Harmony Hub ═════════════════════════════════
/// `/couple/:familyId` — C-001. Entry point: linking state, proposal inbox,
/// handover console, and responsibilities. Shows the honest linking state —
/// never assumes the spouses are connected.
class CoupleHubScreen extends ConsumerWidget {
  const CoupleHubScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final linkingAsync = ref.watch(coupleLinkingProvider(familyId));
    final proposalsAsync = ref.watch(coupleProposalsProvider(familyId));
    final routinesAsync = ref.watch(coupleRoutinesProvider(familyId));
    final handoversAsync = ref.watch(coupleHandoversProvider(familyId));
    final guard = _guard(context, ref, runtime, proposalsAsync,
        FamilyPermission.manageCoupleDecisions, familyId: familyId);
    if (guard != null) return Scaffold(body: guard);

    final proposals = proposalsAsync.valueOrNull ?? const [];
    final pendingCount =
        proposals.where((p) => p.status == CoupleProposalStatus.pending).length;

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleTitle')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              child: Text(l10n.t('coupleHubNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LinkingCard(familyId: familyId, linking: linkingAsync),
                    const SizedBox(height: 12),
                    _InboxCard(
                      familyId: familyId,
                      pendingCount: pendingCount,
                      onTap: () => context.go(
                          CoupleProposalsScreen.route),
                    ),
                    const SizedBox(height: 12),
                    _DestinationsCard(
                      familyId: familyId,
                      routines: routinesAsync.valueOrNull ?? const [],
                      handovers: handoversAsync.valueOrNull ?? const [],
                      l10n: l10n,
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

  static GuardianStateView? _guard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Object?> runtime,
    AsyncValue<List<CoupleProposal>> data,
    FamilyPermission permission, {
    required String familyId,
  }) {
    final l10n = AppLocalizations.of(context);
    if (runtime.hasError || data.hasError) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('monitoringSyncFailed'),
        message: l10n.t('somethingWentWrong'),
        onRetry: () => ref.invalidate(coupleProposalsProvider(familyId)),
      );
    }
    if (runtime.isLoading || data.isLoading) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    final ctx = runtime.valueOrNull is FamilyRuntimeContext
        ? runtime.valueOrNull as FamilyRuntimeContext
        : null;
    if (ctx == null) {
      return const GuardianStateView(state: GuardianViewState.loading);
    }
    if (!ctx.can(permission)) {
      return GuardianStateView(
        state: GuardianViewState.error,
        title: l10n.t('roleNotAllowed'),
        message: l10n.t('authorizationFailure'),
      );
    }
    return null;
  }
}

class _LinkingCard extends StatelessWidget {
  const _LinkingCard({required this.familyId, required this.linking});
  final String familyId;
  final AsyncValue<List<CoupleLinking>> linking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('coupleLinkingTitle'),
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            if (linking.hasError)
              GuardianStateView(
                state: GuardianViewState.error,
                title: l10n.t('coupleLinkingTitle'),
                message: l10n.t('somethingWentWrong'),
              )
            else if (linking.valueOrNull == null || linking.valueOrNull!.isEmpty)
              Column(
                children: [
                  Text(l10n.t('coupleLinkingNote'),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go(
                          CoupleLinkingScreen.route),
                      child: Text(l10n.t('coupleLinkingLinkSpouse')),
                    ),
                  ),
                ],
              )
            else
              ...linking.valueOrNull!.map((link) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        GuardianStatusChip(
                          kind: link.requestState ==
                                  CoupleLinkingState.accepted
                              ? GuardianStatusKind.safe
                              : link.requestState ==
                                      CoupleLinkingState.declined
                                  ? GuardianStatusKind.offline
                                  : GuardianStatusKind.watch,
                          label: _stateLabel(l10n, link.requestState),
                        ),
                        const Spacer(),
                        Text(link.partnerMemberId,
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.familyId,
    required this.pendingCount,
    required this.onTap,
  });
  final String familyId;
  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GuardianCard(
      child: ListTile(
        leading: const Icon(Icons.mail,
            color: GuardianTokens.guardianTeal),
        title: Text(l10n.t('coupleProposalInbox')),
        subtitle: Text(l10n.t('coupleProposalInboxNote')),
        trailing: Badge(
          label: Text('$pendingCount'),
          child: const Icon(Icons.chevron_right),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _DestinationsCard extends StatelessWidget {
  const _DestinationsCard({
    required this.familyId,
    required this.routines,
    required this.handovers,
    required this.l10n,
  });
  final String familyId;
  final List<SharedRoutine> routines;
  final List<HandoverRequest> handovers;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final active =
        handovers.where((h) => h.status == HandoverStatus.active).length;
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.event_repeat,
                  color: GuardianTokens.guardianTeal),
              title: Text(l10n.t('coupleRoutines')),
              subtitle: Text('${routines.length} ${l10n.t('coupleRoutineCount')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(CoupleRoutinesScreen.route),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz,
                  color: GuardianTokens.guardianTeal),
              title: Text(l10n.t('coupleHandovers')),
              subtitle: Text('$active ${l10n.t('coupleHandoverActiveCount')}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(CoupleHandoversScreen.route),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind,
                  color: GuardianTokens.guardianTeal),
              title: Text(l10n.t('coupleResponsibilities')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(
                  CoupleResponsibilitiesScreen.route),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════ C-002 — Couple Linking ═════════════════════════════════════
/// `/couple/:familyId/linking` — C-002. The owner formally links a spouse.
/// The state is rendered exactly (requested / accepted / declined) — the UI
/// never pretends connection is automatic.
class CoupleLinkingScreen extends ConsumerStatefulWidget {
  const CoupleLinkingScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/linking';

  @override
  ConsumerState<CoupleLinkingScreen> createState() =>
      _CoupleLinkingScreenState();
}

class _CoupleLinkingScreenState extends ConsumerState<CoupleLinkingScreen> {
  String? _partnerMemberId;

  Future<void> _sendRequest() async {
    if (_partnerMemberId == null || _partnerMemberId!.isEmpty) return;
    final runtime = ref.read(familyRuntimeContextProvider(widget.familyId));
    final actor = runtime.valueOrNull is FamilyRuntimeContext
        ? runtime.valueOrNull as FamilyRuntimeContext
        : null;
    final ctx = actor;
    if (ctx == null) return;
    await ref.read(coupleRepositoryProvider).recordLinking(CoupleLinking(
          familyId: widget.familyId,
          partnerMemberId: _partnerMemberId!,
          requestState: CoupleLinkingState.requested,
          requestedBy: ctx.actor?.id ?? ctx.actor?.displayName ?? 'unknown',
          requestedAt: DateTime.now().toUtc(),
        ));
    ref.invalidate(coupleLinkingProvider(widget.familyId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(widget.familyId));
    final linkingAsync = ref.watch(coupleLinkingProvider(widget.familyId));
    final guard = CoupleHubScreen._guard(context, ref, runtime,
        AsyncValue.data(const []), FamilyPermission.manageCoupleDecisions, familyId: widget.familyId);
    if (guard != null) return Scaffold(body: guard);

    final linking = linkingAsync.valueOrNull ?? const [];
    final linked = linking.any(
        (l) => l.requestState == CoupleLinkingState.accepted);

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleLinkingTitle')),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('coupleLinkingSpouse'),
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            TextField(
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: l10n.t('coupleLinkingPartnerHint'),
                                hintStyle: const TextStyle(fontSize: 13),
                                filled: true,
                                fillColor:
                                    GuardianTokens.guardianNavy.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                              onChanged: (v) => _partnerMemberId = v.trim(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: linked ? null : _sendRequest,
                                child: Text(l10n.t('coupleLinkingLinkSpouse')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (linked)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              GuardianStatusChip(
                                kind: GuardianStatusKind.safe,
                                label: l10n.t('coupleLinkingLinked'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.t('coupleLinkingLinkedNote'),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final link in linking.where(
                        (l) => l.requestState == CoupleLinkingState.requested))
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              GuardianStatusChip(
                                kind: GuardianStatusKind.watch,
                                label: _stateLabel(l10n, link.requestState),
                              ),
                              const SizedBox(width: 8),
                              Text(link.partnerMemberId,
                                  style: const TextStyle(fontSize: 12)),
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

// ═══════════════ C-003 — Couple Proposals Inbox ═════════════════════════════
/// `/couple/:familyId/proposals` — C-003. Every mutual proposal awaits one
/// spouse's explicit decision; expired proposals are displayed as expired.
class CoupleProposalsScreen extends ConsumerWidget {
  const CoupleProposalsScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/proposals';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final proposalsAsync = ref.watch(coupleProposalsProvider(familyId));
    final guard = CoupleHubScreen._guard(context, ref, runtime, proposalsAsync,
        FamilyPermission.manageCoupleDecisions, familyId: familyId);
    if (guard != null) return Scaffold(body: guard);

    final proposals = proposalsAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleProposalInbox')),
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
                              child: Text(l10n.t('coupleProposalNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (proposals.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('coupleProposalInbox'),
                        message: l10n.t('coupleProposalEmpty'),
                      ),
                    for (final p in proposals
                        .map((x) => x.withResolvedStatus(DateTime.now().toUtc()))
                        .toList())
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            _proposalKindTitle(
                                                l10n, p.kind),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                        Text(p.titleKey,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  GuardianStatusChip(
                                    kind: p.status ==
                                            CoupleProposalStatus.pending
                                        ? GuardianStatusKind.watch
                                        : p.status ==
                                                CoupleProposalStatus.approved
                                            ? GuardianStatusKind.safe
                                            : p.status ==
                                                    CoupleProposalStatus.expired
                                                ? GuardianStatusKind.offline
                                                : GuardianStatusKind.offline,
                                    label: _proposalStatus(l10n, p.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (p.isDecidable)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () async {
                                          final runtime = ref.read(
                                              familyRuntimeContextProvider(
                                                  familyId));
                                          final actor =
                                              runtime.valueOrNull
                                                      is FamilyRuntimeContext
                                                  ? runtime.valueOrNull
                                                      as FamilyRuntimeContext
                                                  : null;
                                          if (actor == null) return;
                                          final memberId = actor.actor?.id;
                                          if (memberId == null) return;
                                          await ref
                                              .read(coupleRepositoryProvider)
                                              .decideProposal(familyId, p.id,
                                                  decision:
                                                      CoupleProposalStatus
                                                          .rejected,
                                                  reviewedBy: memberId);
                                          ref.invalidate(
                                              coupleProposalsProvider(
                                                  familyId));
                                        },
                                        child:
                                            Text(l10n.t('coupleProposalDecline')),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () async {
                                          final runtime = ref.read(
                                              familyRuntimeContextProvider(
                                                  familyId));
                                          final actor =
                                              runtime.valueOrNull
                                                      is FamilyRuntimeContext
                                                  ? runtime.valueOrNull
                                                      as FamilyRuntimeContext
                                                  : null;
                                          if (actor == null) return;
                                          final memberId = actor.actor?.id;
                                          if (memberId == null) return;
                                          await ref
                                              .read(coupleRepositoryProvider)
                                              .decideProposal(familyId, p.id,
                                                  decision:
                                                      CoupleProposalStatus
                                                          .approved,
                                                  reviewedBy: memberId);
                                          ref.invalidate(
                                              coupleProposalsProvider(
                                                  familyId));
                                        },
                                        child:
                                            Text(l10n.t('coupleProposalAccept')),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go(
                            CoupleNewProposalScreen.route),
                        child: Text(l10n.t('coupleNewProposal')),
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

// ═══════════════ C-004 — New Proposal ═══════════════════════════════════════
/// `/couple/:familyId/proposals/new` — C-004. The authoring form for a mutual
/// proposal. It *stages* a request; nothing activates until the other spouse
/// approves in C-003.
class CoupleNewProposalScreen extends ConsumerStatefulWidget {
  const CoupleNewProposalScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/proposals/new';

  @override
  ConsumerState<CoupleNewProposalScreen> createState() =>
      _CoupleNewProposalScreenState();
}

class _CoupleNewProposalScreenState
    extends ConsumerState<CoupleNewProposalScreen> {
  CoupleProposalKind _kind = CoupleProposalKind.routine;
  String _title = '';

  Future<void> _submit() async {
    if (_title.trim().isEmpty) return;
    final runtime = ref.read(familyRuntimeContextProvider(widget.familyId));
    final actor = runtime.valueOrNull is FamilyRuntimeContext
        ? runtime.valueOrNull as FamilyRuntimeContext
        : null;
    if (actor == null) return;
    final memberId = actor.actor?.id;
    if (memberId == null) return;
    await ref.read(coupleRepositoryProvider).recordProposal(CoupleProposal(
          id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
          familyId: widget.familyId,
          kind: _kind,
          titleKey: _title.trim(),
          proposedBy: memberId,
          status: CoupleProposalStatus.pending,
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
          createdAt: DateTime.now().toUtc(),
        ));
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleNewProposal')),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.t('coupleNewProposalTitle'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: l10n.t('coupleNewProposalHint'),
                                filled: true,
                                fillColor: GuardianTokens.guardianNavy
                                    .withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                              onChanged: (v) => _title = v,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<CoupleProposalKind>(
                              value: _kind,
                              items: CoupleProposalKind.values
                                  .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(_proposalKindTitle(
                                            l10n, k)),
                                      ))
                                  .toList(),
                              onChanged: (k) {
                                if (k != null) setState(() => _kind = k);
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _submit,
                                child: Text(l10n.t('coupleProposalSend')),
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

// ═══════════════ C-005 — Shared Routines ════════════════════════════════════
/// `/couple/:familyId/routines` — C-005. Joint routines co-owned by spouses;
/// each one can be toggled without affecting the other spouse's schedules.
class CoupleRoutinesScreen extends ConsumerWidget {
  const CoupleRoutinesScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/routines';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final routinesAsync = ref.watch(coupleRoutinesProvider(familyId));
    final guard = CoupleHubScreen._guard(context, ref, runtime,
        AsyncValue.data(const []), FamilyPermission.manageCoupleDecisions, familyId: familyId);
    if (guard != null) return Scaffold(body: guard);

    final routines = routinesAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleRoutines')),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (routines.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('coupleRoutines'),
                        message: l10n.t('coupleRoutinesEmpty'),
                      ),
                    for (final routine in routines)
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(routine.titleKey,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_weekdayName(l10n, routine.weekdays.first)} · '
                                      '${_timeFromMinute(routine.startMinute)} – '
                                      '${_timeFromMinute(routine.endMinute)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: routine.enabled,
                                onChanged: (enabled) async {
                                  await ref
                                      .read(coupleRepositoryProvider)
                                      .updateRoutine(familyId, routine.id,
                                          enabled: enabled);
                                  ref.invalidate(
                                      coupleRoutinesProvider(familyId));
                                },
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

// ═══════════════ C-006 — Responsibilities ═══════════════════════════════════
/// `/couple/:familyId/responsibilities` — C-006. Ownership areas with explicit
/// delegation windows; a delegation always shows *who* owns it and *who* is
/// covering, and ends explicitly rather than silently.
class CoupleResponsibilitiesScreen extends ConsumerWidget {
  const CoupleResponsibilitiesScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/responsibilities';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final respAsync = ref.watch(coupleResponsibilitiesProvider(familyId));
    final guard = CoupleHubScreen._guard(context, ref, runtime,
        AsyncValue.data(const []), FamilyPermission.manageCoupleDecisions, familyId: familyId);
    if (guard != null) return Scaffold(body: guard);

    final items = respAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleResponsibilities')),
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
                        title: l10n.t('coupleResponsibilities'),
                        message: l10n.t('coupleResponsibilitiesEmpty'),
                      ),
                    for (final r in items)
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
                                        _responsibilityArea(l10n, r.areaKey),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  GuardianStatusChip(
                                    kind: r.isDelegated
                                        ? GuardianStatusKind.watch
                                        : GuardianStatusKind.safe,
                                    label: r.isDelegated
                                        ? l10n.t('coupleDelegated')
                                        : l10n.t('coupleOwned'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(r.isDelegated
                                  ? '${l10n.t('coupleDelegatedTo')}: ${r.delegateMemberId}'
                                  : '${l10n.t('coupleOwnedBy')}: ${r.ownerMemberId}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white70)),
                              const SizedBox(height: 10),
                              if (!r.isDelegated)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () async {
                                      final actor =
                                          ref
                                                  .read(familyRuntimeContextProvider(
                                                      familyId))
                                                  .valueOrNull
                                              is FamilyRuntimeContext
                                              ? ref
                                                  .read(familyRuntimeContextProvider(
                                                      familyId))
                                                  .valueOrNull
                                                  as FamilyRuntimeContext
                                              : null;
                                      if (actor == null) return;
                                      await ref
                                          .read(coupleRepositoryProvider)
                                          .delegateResponsibility(familyId,
                                              r.id, delegateMemberId: r.ownerMemberId);
                                      ref.invalidate(
                                          coupleResponsibilitiesProvider(
                                              familyId));
                                    },
                                    child:
                                        Text(l10n.t('coupleDelegate')),
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

// ═══════════════ C-007 — Handover Console ═══════════════════════════════════
/// `/couple/:familyId/handovers` — C-007. Supervision handovers: one parent
/// requests, the other responds, and the completion is an explicit act
/// logged on both edges.
class CoupleHandoversScreen extends ConsumerWidget {
  const CoupleHandoversScreen({super.key, required this.familyId});
  final String familyId;

  static const String route = '/couple/:familyId/handovers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final handoversAsync = ref.watch(coupleHandoversProvider(familyId));
    final guard = CoupleHubScreen._guard(context, ref, runtime,
        AsyncValue.data(const []), FamilyPermission.manageCoupleDecisions, familyId: familyId);
    if (guard != null) return Scaffold(body: guard);

    final items = handoversAsync.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GuardianTokens.guardianNavy,
              foregroundColor: Colors.white,
              title: Text(l10n.t('coupleHandovers')),
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
                              child: Text(l10n.t('coupleHandoverNote'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      GuardianStateView(
                        state: GuardianViewState.empty,
                        title: l10n.t('coupleHandovers'),
                        message: l10n.t('coupleHandoversEmpty'),
                      ),
                    for (final h in items)
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
                                      '${h.fromMemberId} → ${h.toMemberId}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  GuardianStatusChip(
                                    kind: _handoverKind(h.status),
                                    label: _handoverStatus(l10n, h.status),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (h.status == HandoverStatus.active)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () async {
                                      final actor = ref
                                              .read(familyRuntimeContextProvider(
                                                  familyId))
                                              .valueOrNull
                                          is FamilyRuntimeContext
                                      ? ref
                                          .read(familyRuntimeContextProvider(
                                              familyId))
                                          .valueOrNull
                                          as FamilyRuntimeContext
                                      : null;
                                      if (actor == null) return;
                                      final memberId = actor.actor?.id;
                                      if (memberId == null) return;
                                      await ref
                                          .read(coupleRepositoryProvider)
                                          .completeHandover(familyId,
                                              h.id, memberId);
                                      ref.invalidate(
                                          coupleHandoversProvider(familyId));
                                    },
                                    child:
                                        Text(l10n.t('coupleHandoverComplete')),
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
