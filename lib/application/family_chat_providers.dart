import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/guardian_database.dart';
import '../data/family_chat_repository.dart';
import '../domain/family_authorization.dart';
import '../domain/family_chat.dart';
import '../domain/guardian_models.dart';
import 'family_context_provider.dart';

/// ---------------------------------------------------------------------------
/// FS-010 — Ephemeral Family Chat. Application layer.
///
/// One responsibility per piece: [FamilyChatService] owns the authorization
/// and honesty logic; the Riverpod providers expose read/write state to the
/// UI without re-implementing roles, and the role-permission matrix stays in
/// [FamilyAuthorization] as the single permission source.
/// ---------------------------------------------------------------------------

/// An unverified actor must never see chat. Screens render this as the
/// honest unauthenticated state instead of silently hiding.
FamilyRuntimeContext _unverifiedContext(String familyId) =>
    FamilyRuntimeContext(
      familyId: familyId,
      family: null,
      actor: null,
      isVerified: false,
      permissionsFor: (_) => const {},
      allMembers: const [],
      children: const [],
      devices: const [],
    );

final familyChatRepositoryProvider =
    Provider((ref) => FamilyChatRepository(GuardianDatabase.instance));

/// Thread scope verdicts are computed here — never duplicated in the UI.
class FamilyChatService {
  FamilyChatService(
    this._repo, {
    FamilyAuthorization? authorization,
  }) : _authorization = authorization ?? const FamilyAuthorization();

  final FamilyChatRepository _repo;
  final FamilyAuthorization _authorization; // reserved for future test seams

  /// Honesty rule: anyone without `viewChat` sees nothing (children,
  /// invited and revoked members, anonymous users). `ctx.actor` MUST be
  /// non-null and verified before calling.
  Future<List<FamilyChatThread>> visibleThreads(
      String familyId, FamilyRuntimeContext ctx) async {
    if (!_canAct(ctx)) {
      throw StateError('chat_actor_unbound');
    }
    requireViewChat(ctx);
    final threads = await _repo.listThreads(familyId);
    return threads
        .where((t) => _actorCanSee(ctx, t))
        .toList(growable: false);
  }

  bool _actorCanSee(FamilyRuntimeContext ctx, FamilyChatThread thread) {
    switch (thread.type) {
      case FamilyChatThreadType.family:
        return true;
      case FamilyChatThreadType.member:
        return thread.memberId == ctx.actor!.id ||
            thread.createdByMemberId == ctx.actor!.id;
      case FamilyChatThreadType.spouse:
        return _isInSpousePair(ctx, thread);
    }
  }

  /// Test-visible thread-scoping verdict used by the authorization tests.
  bool actorCanSeeThread(FamilyRuntimeContext ctx, FamilyChatThread thread) =>
      _actorCanSee(ctx, thread);

  bool _isInSpousePair(FamilyRuntimeContext ctx, FamilyChatThread thread) {
    // A spouse thread is scoped to exactly the symmetric pair bound at
    // creation. The actor participates only when their member id matches
    // one side of the pair AND their role is spouse.
    if (ctx.actor!.role != FamilyRole.spouse) return false;
    if (thread.memberId == null) return false;
    final creator = ctx.allMembers
        .where((m) => m.id == thread.createdByMemberId)
        .firstOrNull;
    if (creator == null) return false;
    if (creator.role != FamilyRole.spouse) return false;
    final pair = <String>{thread.createdByMemberId, thread.memberId!};
    return pair.contains(ctx.actor!.id);
  }

  bool _canAct(FamilyRuntimeContext ctx) =>
      ctx.isVerified && ctx.actor != null && ctx.actor!.isActive;

  /// Explicit authorization fail point: a revoked or non-child-privileged
  /// actor reaches here and fails closed with the honest StateError the UI
  /// renders — `ctx.can(viewChat)` alone is not enough evidence because
  /// `can` silently returns `false` for unverified actors.
  void requireViewChat(FamilyRuntimeContext ctx) {
    _authorization.require(ctx.actor!, FamilyPermission.viewChat);
  }

  Future<List<FamilyChatMessage>> activeMessages(
      String threadId, FamilyRuntimeContext ctx) async {
    if (!_canAct(ctx)) {
      throw StateError('chat_actor_unbound');
    }
    return _repo.activeMessages(threadId);
  }

  /// Honesty write: authorization is checked BEFORE the thread is touched;
  /// the underlying repository enforces idempotency, expiration, and the
  /// outbox enqueue. The outcome is returned verbatim to the UI — never a
  /// fake `sent` when the write did not complete.
  Future<FamilyChatSendOutcome> sendMessage({
    required String familyId,
    required String threadId,
    required String body,
    required FamilyRuntimeContext ctx,
  }) async {
    if (!_canAct(ctx)) {
      throw StateError('chat_actor_unbound');
    }
    if (!ctx.can(FamilyPermission.viewChat)) {
      throw StateError('family_permission_denied:viewChat');
    }
    final thread = await _repo.findThread(familyId, threadId);
    if (thread == null) throw StateError('chat_thread_missing:$threadId');
    if (thread.familyId != familyId) {
      throw StateError('chat_cross_family_thread');
    }
    if (!_actorCanSee(ctx, thread)) {
      throw StateError('chat_thread_scope_denied:$threadId');
    }
    return _repo.sendMessage(
      familyId: familyId,
      threadId: threadId,
      senderMemberId: ctx.actor!.id,
      body: body,
    );
  }

  Future<FamilyChatExpirationReport> sweep(
      FamilyRuntimeContext ctx) async {
    if (!_canAct(ctx)) {
      throw StateError('chat_actor_unbound');
    }
    return _repo.sweepExpired();
  }

  /// Creates a role-scoped thread when the actor has the required standing.
  /// `family` threads are open to any active adult; `member` threads are
  /// scoped to an existing active member; `spouse` threads require both
  /// sides to be spouses of each other.
  Future<FamilyChatThread> findOrCreateThread({
    required String familyId,
    required FamilyChatThreadType type,
    String? memberId,
    required FamilyRuntimeContext ctx,
  }) async {
    if (!_canAct(ctx)) {
      throw StateError('chat_actor_unbound');
    }
    if (!ctx.can(FamilyPermission.viewChat)) {
      throw StateError('family_permission_denied:viewChat');
    }
    requireViewChat(ctx);
    if (type == FamilyChatThreadType.member) {
      final target = ctx.allMembers
          .where((m) => m.id == memberId && m.isActive)
          .firstOrNull;
      if (target == null) {
        throw StateError('chat_member_unavailable:$memberId');
      }
      memberId = target.id;
    }
    if (type == FamilyChatThreadType.spouse) {
      if (ctx.actor!.role != FamilyRole.spouse) {
        throw StateError('chat_spouse_thread_not_spouse');
      }
      final other = memberId == null
          ? null
          : ctx.allMembers
              .where((m) => m.id == memberId && m.isActive)
              .firstOrNull;
      if (other == null || other.role != FamilyRole.spouse) {
        throw StateError('chat_spouse_pair_missing');
      }
    }
    return _repo.findOrCreateThread(
      familyId: familyId,
      type: type,
      memberId: memberId,
      createdByMemberId: ctx.actor!.id,
    );
  }
}

final familyChatServiceProvider = Provider<FamilyChatService>(
    (ref) => FamilyChatService(ref.watch(familyChatRepositoryProvider)));

/// Threads visible to the actor, refreshed after every send or sweep.
final familyChatThreadsProvider =
    FutureProvider.family<List<FamilyChatThread>, String>(
        (ref, String familyId) async {
  final context = ref.watch(familyRuntimeContextProvider(familyId));
  return ref
      .watch(familyChatServiceProvider)
      .visibleThreads(familyId, context.valueOrNull ?? _unverifiedContext(familyId));
});

/// Thread summaries (CH-001 list rows): thread + last non-expired message.
final familyChatThreadSummariesProvider =
    FutureProvider.family<List<FamilyChatThreadSummary>, String>(
        (ref, String familyId) async {
  final context = ref.watch(familyRuntimeContextProvider(familyId));
  final service = ref.watch(familyChatServiceProvider);
  final threads = await service.visibleThreads(
      familyId, context.valueOrNull ?? _unverifiedContext(familyId));
  final summaries = <FamilyChatThreadSummary>[];
  for (final thread in threads) {
    final messages =
        await service.activeMessages(thread.id, context.valueOrNull!);
    summaries.add(FamilyChatThreadSummary(
        thread: thread,
        lastMessage: messages.isEmpty ? null : messages.last,
        unreadCount: 0));
  }
  return summaries;
});

/// Active (non-expired) messages on a thread. The provider key is the
/// `familyId/threadId` composite so the chat screen stays bound to one
/// family at a time and can never display another family's conversation.
final chatActiveMessagesProvider =
    FutureProvider.family<List<FamilyChatMessage>, String>(
        (ref, String familyThreadKey) async {
  final slash = familyThreadKey.indexOf('/');
  final familyId = familyThreadKey.substring(0, slash);
  final threadId = familyThreadKey.substring(slash + 1);
  final context = ref.watch(familyRuntimeContextProvider(familyId));
  final service = ref.watch(familyChatServiceProvider);
  final ctx = context.valueOrNull ?? _unverifiedContext(familyId);
  final thread = await service.visibleThreads(familyId, ctx)
      .then((threads) => threads.where((t) => t.id == threadId).firstOrNull);
  if (thread == null) return const <FamilyChatMessage>[];
  return service.activeMessages(threadId, ctx);
});

/// Honest sweep result. Callers decide the CH-004 notice.
final chatSweepProvider = FutureProvider.family<FamilyChatExpirationReport,
    String>((ref, String familyId) async {
  final context = ref.watch(familyRuntimeContextProvider(familyId));
  return ref.watch(familyChatServiceProvider).sweep(
      context.valueOrNull ?? _unverifiedContext(familyId));
});
