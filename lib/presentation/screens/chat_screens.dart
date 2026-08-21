import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/family_chat_providers.dart';
import '../../application/family_context_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/guardian_tokens.dart';
import '../../domain/family_chat.dart';
import '../../domain/guardian_models.dart';
import '../widgets/guardian_primitives.dart';

/// ---------------------------------------------------------------------------
/// FS-010 — Ephemeral Family Chat. Screens (CH-001 … CH-004).
///
/// Messages are ephemeral by contract: `expiresAt = createdAt + 24h` UTC,
/// and expired rows are never surfaced as active messages. The UI therefore
/// never claims persistence — an expired thread shows the CH-004 notice,
/// a queued send shows the honest `queued` state, and a failed send shows
/// a real retry affordance. Authorization is delegated exclusively to
/// `FamilyRuntimeContext.can(FamilyPermission.viewChat)`; children, invited,
/// revoked, and unverified actors are never given the chat surface.
/// ---------------------------------------------------------------------------

String _threadLabel(AppLocalizations l10n, FamilyChatThread thread) =>
    switch (thread.type) {
      FamilyChatThreadType.family => l10n.t('chatFamilyThread'),
      FamilyChatThreadType.member => l10n.t('chatMemberThread'),
      FamilyChatThreadType.spouse => l10n.t('chatSpouseThread'),
    };

String _sendOutcomeLabel(AppLocalizations l10n, FamilyChatSendOutcome o) =>
    switch (o) {
      FamilyChatSendOutcome.sent => l10n.t('chatSend'),
      FamilyChatSendOutcome.queued => l10n.t('chatQueued'),
      FamilyChatSendOutcome.failed => l10n.t('chatSendFailed'),
      FamilyChatSendOutcome.duplicate => l10n.t('chatDuplicateIgnored'),
    };

/// Honesty gate shared by both chat screens: no actor, no verified family
/// membership, or no `viewChat` — the screen renders the real denied state
/// instead of a blank page.
GuardianStateView? _chatGuard(
  BuildContext context,
  WidgetRef ref,
  AsyncValue<Object?> runtime,
  FamilyPermission permission,
  String familyId,
) {
  final l10n = AppLocalizations.of(context);
  if (runtime.hasError) {
    return GuardianStateView(
      state: GuardianViewState.error,
      title: l10n.t('chatFailedBanner'),
      message: l10n.t('somethingWentWrong'),
      onRetry: () => ref.invalidate(familyRuntimeContextProvider(familyId)),
    );
  }
  if (runtime.isLoading) {
    return const GuardianStateView(state: GuardianViewState.loading);
  }
  final ctx = runtime.valueOrNull is FamilyRuntimeContext
      ? runtime.valueOrNull as FamilyRuntimeContext
      : null;
  if (ctx == null || !ctx.isVerified || ctx.actor == null) {
    return GuardianStateView(
      state: GuardianViewState.error,
      title: l10n.t('chatUnauthorized'),
      message: l10n.t('authorizationFailure'),
    );
  }
  if (!ctx.can(FamilyPermission.viewChat)) {
    return GuardianStateView(
      state: GuardianViewState.error,
      title: l10n.t('chatChildNotAllowed'),
      message: l10n.t('authorizationFailure'),
    );
  }
  return null;
}

// ═══════════════ CH-001 — Chat List ══════════════════════════════════════════
/// `/chat/:familyId` — visible thread list (honest summary per thread) plus
/// the CH-003 thread creation affordances and the 24-hour expiration note.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key, required this.familyId});

  final String familyId;

  static const String route = '/chat/:familyId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(familyRuntimeContextProvider(familyId));
    final guard = _chatGuard(
        context, ref, runtime, FamilyPermission.viewChat, familyId);
    if (guard != null) {
      return Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        body: guard,
      );
    }
    final ctx = runtime.valueOrNull as FamilyRuntimeContext;
    final summariesAsync = ref.watch(familyChatThreadSummariesProvider(familyId));
    final sweepAsync = ref.watch(chatSweepProvider(familyId));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: CustomScrollView(slivers: [
          SliverAppBar.large(
            backgroundColor: GuardianTokens.guardianNavy,
            foregroundColor: Colors.white,
            title: Text(l10n.t('chatTitle')),
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
                      child: Row(children: [
                        const Icon(Icons.timelapse_outlined,
                            color: GuardianTokens.guardianTeal, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.t('chatExpirationNotice'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GuardianCard(
                    onTap: () async {
                      final service = ref.read(familyChatServiceProvider);
                      try {
                        final thread = await service.findOrCreateThread(
                          familyId: familyId,
                          type: FamilyChatThreadType.family,
                          ctx: ctx,
                        );
                        if (!context.mounted) return;
                        context
                            .push('/chat/$familyId/${thread.id}');
                      } catch (_) {
                        if (!context.mounted) return;
                        _showSendError(context, l10n);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const GuardianIconBadge(
                            icon: Icons.people_outline,
                            background: GuardianTokens.guardianTeal),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l10n.t('chatNewFamilyThread'),
                            style: const TextStyle(
                                fontFamily: GuardianTokens.fontFamily,
                                fontWeight: FontWeight.w600))),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MemberThreadTile(
                    familyId: familyId,
                    ctx: ctx,
                    labelKey: 'chatNewMemberThread',
                    icon: Icons.person_outline,
                    allowTypes: const {FamilyChatThreadType.member},
                  ),
                  if (ctx.actor!.role == FamilyRole.spouse) ...[
                    const SizedBox(height: 12),
                    _SpouseThreadTile(familyId: familyId, ctx: ctx),
                  ],
                  const SizedBox(height: 16),
                  summariesAsync.when(
                    loading: () => const GuardianStateView(
                        state: GuardianViewState.loading),
                    error: (err, _) => GuardianStateView(
                      state: GuardianViewState.error,
                      title: l10n.t('chatFailedBanner'),
                      message: err.toString(),
                      onRetry: () => ref.invalidate(
                          familyChatThreadSummariesProvider(familyId)),
                    ),
                    data: (summaries) {
                      if (summaries.isEmpty) {
                        return GuardianStateView(
                          state: GuardianViewState.empty,
                          message: l10n.t('chatEmptyHint'),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final summary in summaries)
                            _ThreadRow(
                              familyId: familyId,
                              summary: summary,
                              sweep: sweepAsync.valueOrNull,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static void _showSendError(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.t('chatFailedBanner')),
      backgroundColor: GuardianTokens.statusAlert,
    ));
  }
}

class _MemberThreadTile extends StatelessWidget {
  const _MemberThreadTile({
    required this.familyId,
    required this.ctx,
    required this.labelKey,
    required this.icon,
    required this.allowTypes,
  });

  final String familyId;
  final FamilyRuntimeContext ctx;
  final String labelKey;
  final IconData icon;
  final Set<FamilyChatThreadType> allowTypes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final others = ctx.allMembers
        .where((m) => m.id != ctx.actor!.id && m.isActive)
        .toList(growable: false);
    return GuardianCard(
      onTap: () async {
        if (others.isEmpty) return;
        final ref = ProviderScope.containerOf(context);
        try {
          final target = others.first;
          final thread = await ref.read(familyChatServiceProvider).findOrCreateThread(
                familyId: familyId,
                type: allowTypes.first,
                memberId: target.id,
                ctx: ctx,
              );
          if (!context.mounted) return;
          context.push('/chat/$familyId/${thread.id}');
        } catch (_) {
          if (!context.mounted) return;
          ChatListScreen._showSendError(context, l10n);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          GuardianIconBadge(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t(labelKey),
                    style: const TextStyle(
                        fontFamily: GuardianTokens.fontFamily,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(others.isEmpty
                    ? l10n.t('nothingHereYet')
                    : others.first.displayName,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

class _SpouseThreadTile extends StatelessWidget {
  const _SpouseThreadTile({required this.familyId, required this.ctx});

  final String familyId;
  final FamilyRuntimeContext ctx;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otherSpouse = ctx.allMembers.where((m) =>
        m.id != ctx.actor!.id &&
        m.isActive &&
        m.role == FamilyRole.spouse).toList(growable: false);
    return GuardianCard(
      onTap: otherSpouse.isEmpty
          ? null
          : () async {
              final ref = ProviderScope.containerOf(context);
              try {
                final thread =
                    await ref.read(familyChatServiceProvider).findOrCreateThread(
                          familyId: familyId,
                          type: FamilyChatThreadType.spouse,
                          memberId: otherSpouse.first.id,
                          ctx: ctx,
                        );
                if (!context.mounted) return;
                context.push('/chat/$familyId/${thread.id}');
              } catch (_) {
                if (!context.mounted) return;
                ChatListScreen._showSendError(context, l10n);
              }
            },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const GuardianIconBadge(icon: Icons.favorite_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('chatNewSpouseThread'),
                    style: const TextStyle(
                        fontFamily: GuardianTokens.fontFamily,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(otherSpouse.isEmpty
                    ? l10n.t('nothingHereYet')
                    : otherSpouse.first.displayName,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.familyId,
    required this.summary,
    required this.sweep,
  });

  final String familyId;
  final FamilyChatThreadSummary summary;
  final FamilyChatExpirationReport? sweep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final swept = sweep?.expiredThreads
            .contains(summary.thread.id) ==
        true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GuardianCard(
        onTap: () => context.push('/chat/$familyId/${summary.thread.id}'),
        child: Row(children: [
          GuardianIconBadge(
              icon: summary.thread.isFamilyThread
                  ? Icons.people_outline
                  : Icons.chat_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_threadLabel(l10n, summary.thread),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  summary.lastMessage == null
                      ? l10n.t('chatEmpty')
                      : (summary.lastMessage!.body.length > 48
                          ? '${summary.lastMessage!.body.substring(0, 48)}…'
                          : summary.lastMessage!.body),
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            GuardianStatusChip(
              label: l10n.t('chatExpiration24h'),
              kind: GuardianStatusKind.watch,
              live: !swept,
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════ CH-002 / CH-004 — Chat Screen ══════════════════════════════
/// `/chat/:familyId/:threadId` — honest message list with the 24-hour
/// expiration notice (CH-003) and the CH-004 expired-thread banner when the
/// sweep reports no active messages left.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.familyId,
    required this.threadId,
  });

  final String familyId;
  final String threadId;

  static const String route = '/chat/:familyId/:threadId';

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  FamilyChatSendOutcome? _lastOutcome;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _messagesKey => '${widget.familyId}/${widget.threadId}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtime =
        ref.watch(familyRuntimeContextProvider(widget.familyId));
    final guard = _chatGuard(context, ref, runtime,
        FamilyPermission.viewChat, widget.familyId);
    if (guard != null) {
      return Scaffold(
        backgroundColor: GuardianTokens.guardianNavy,
        body: guard,
      );
    }
    final ctx = runtime.valueOrNull as FamilyRuntimeContext;
    final messagesAsync = ref.watch(chatActiveMessagesProvider(_messagesKey));
    final sweepAsync = ref.watch(chatSweepProvider(widget.familyId));

    return Scaffold(
      backgroundColor: GuardianTokens.guardianNavy,
      body: Directionality(
        textDirection: l10n.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Column(children: [
          Expanded(
            child: CustomScrollView(slivers: [
              SliverAppBar.large(
                backgroundColor: GuardianTokens.guardianNavy,
                foregroundColor: Colors.white,
                title: Text(l10n.t('chatTitle')),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GuardianCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            const Icon(Icons.timelapse_outlined,
                                color: GuardianTokens.guardianTeal,
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(l10n.t('chatExpirationNotice'),
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // CH-004 — honest expired-conversation notice.
                      if (sweepAsync.valueOrNull != null &&
                          messagesAsync.valueOrNull != null &&
                          messagesAsync.valueOrNull!.isEmpty &&
                          sweepAsync.valueOrNull!
                              .expiredThreads
                              .contains(widget.threadId))
                        GuardianCard(
                          color: GuardianTokens.statusWatchSoft,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              const Icon(Icons.hourglass_top_outlined,
                                  color: GuardianTokens.statusWatch,
                                  size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l10n.t('chatThreadExpiredNotice'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                            ),
                          ),
                        ),
                      if (sweepAsync.valueOrNull != null &&
                          messagesAsync.valueOrNull != null &&
                          messagesAsync.valueOrNull!.isEmpty &&
                          !(sweepAsync.valueOrNull!.expiredThreads
                              .contains(widget.threadId)))
                        GuardianStateView(
                          state: GuardianViewState.empty,
                          message: l10n.t('chatEmptyHint'),
                        ),
                      messagesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (err, _) => GuardianStateView(
                          state: GuardianViewState.error,
                          title: l10n.t('chatFailedBanner'),
                          message: err.toString(),
                          onRetry: () =>
                              ref.invalidate(chatActiveMessagesProvider(_messagesKey)),
                        ),
                        data: (messages) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final message in messages)
                              _MessageBubble(
                                message: message,
                                isSelf: message.senderMemberId == ctx.actor!.id,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_lastOutcome != null)
                        _OutcomeBanner(outcome: _lastOutcome!),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          _Composer(familyId: widget.familyId, threadId: widget.threadId, ctx: ctx,
              controller: _input, sending: _sending,
              onOutcome: (outcome) => setState(() => _lastOutcome = outcome),
              onSending: (v) => setState(() => _sending = v)),
        ]),
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});
  final FamilyChatSendOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = switch (outcome) {
      FamilyChatSendOutcome.sent => GuardianTokens.statusSafe,
      FamilyChatSendOutcome.queued => GuardianTokens.statusWatch,
      FamilyChatSendOutcome.failed => GuardianTokens.statusAlert,
      FamilyChatSendOutcome.duplicate => GuardianTokens.statusWatch,
    };
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Icon(switch (outcome) {
            FamilyChatSendOutcome.sent => Icons.check_circle_outline,
            FamilyChatSendOutcome.queued => Icons.cloud_queue_outlined,
            FamilyChatSendOutcome.failed => Icons.error_outline,
            FamilyChatSendOutcome.duplicate => Icons.info_outline,
          }, size: 16, color: palette),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_sendOutcomeLabel(l10n, outcome),
                style: TextStyle(fontSize: 12, color: palette)),
          ),
          if (outcome == FamilyChatSendOutcome.failed)
            const Icon(Icons.refresh_outlined, size: 14,
                color: GuardianTokens.statusAlert),
        ]),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isSelf});
  final FamilyChatMessage message;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final palette = switch (message.state) {
      FamilyChatMessageState.sent => const GuardianStatusPalette(
          GuardianTokens.statusSafe, GuardianTokens.statusSafeSoft),
      FamilyChatMessageState.queued => const GuardianStatusPalette(
          GuardianTokens.statusWatch, GuardianTokens.statusWatchSoft),
      FamilyChatMessageState.failed => const GuardianStatusPalette(
          GuardianTokens.statusAlert, GuardianTokens.statusAlertSoft),
      FamilyChatMessageState.expired => const GuardianStatusPalette(
          Color(0xFF4A5A78), Color(0xFFEDF2F9)),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelf ? palette.soft : Colors.white,
          borderRadius: BorderRadius.circular(GuardianTokens.radiusCard),
          border: Border.all(color: palette.text.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.body,
                style: const TextStyle(
                    fontFamily: GuardianTokens.fontFamily, fontSize: 14)),
            const SizedBox(height: 4),
            Row(children: [
              Text(_timeLabel(message.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: palette.text.withValues(alpha: 0.75))),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_stateLabel(message.state),
                    style: TextStyle(fontSize: 10, color: palette.text)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _stateLabel(FamilyChatMessageState state) => switch (state) {
        FamilyChatMessageState.sent => 'sent',
        FamilyChatMessageState.queued => 'offline',
        FamilyChatMessageState.failed => 'failed',
        FamilyChatMessageState.expired => 'expired',
      };

  String _timeLabel(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class _Composer extends ConsumerStatefulWidget {
  const _Composer({
    required this.familyId,
    required this.threadId,
    required this.ctx,
    required this.controller,
    required this.sending,
    required this.onOutcome,
    required this.onSending,
  });

  final String familyId;
  final String threadId;
  final FamilyRuntimeContext ctx;
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<FamilyChatSendOutcome> onOutcome;
  final ValueChanged<bool> onSending;

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = widget.controller.text.trim();
    final canSend = text.isNotEmpty && !widget.sending;
    return GuardianCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.t('chatTypeHere'),
                border: InputBorder.none,
                hintStyle: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const GuardianOfflineBanner(),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: canSend ? _submit : null,
            icon: widget.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
          ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    final body = widget.controller.text.trim();
    if (body.isEmpty || widget.sending) return;
    widget.onSending(true);
    try {
      final outcome = await ref.read(familyChatServiceProvider).sendMessage(
            familyId: widget.familyId,
            threadId: widget.threadId,
            body: body,
            ctx: widget.ctx,
          );
      widget.onOutcome(outcome);
      // Honest reset: the draft is cleared only after the write result is
      // known — a `queued` outcome keeps the draft visible until the user
      // clears it (offline honesty).
      if (outcome == FamilyChatSendOutcome.sent ||
          outcome == FamilyChatSendOutcome.duplicate) {
        widget.controller.clear();
      }
    } catch (_) {
      widget.onOutcome(FamilyChatSendOutcome.failed);
    } finally {
      widget.onSending(false);
    }
  }
}
