import 'guardian_models.dart';

/// ---------------------------------------------------------------------------
/// FS-010 — Ephemeral Family Chat. Domain models.
///
/// Product intent (MASTER_DEVELOPMENT_PLAN.md §6.10): in-family messaging
/// with 24-hour auto-expiration. Lightweight: list + chat, no attachments
/// in Phase 1. Threads are family / per-member / spouse, role-scoped.
///
/// Expiration semantics (Phase A contract confirmation):
/// - `expiresAt = createdAt + 24 hours`, always in UTC.
/// - Timezone-independent by construction: the contract is a UTC instant,
///   never a wall-clock offset; a message is expired when the current UTC
///   instant is at or past [expiresAt].
/// - Expired messages are NEVER surfaced as active messages. The UI shows an
///   honest expired-conversation notice (CH-004) instead of fake persistence.
/// ---------------------------------------------------------------------------

/// Clock function injected everywhere time is needed so tests and production
/// share one deterministic source. Production uses [DateTime.now].
typedef ChatClock = DateTime Function();

/// The thread scopes permitted by the master specification (§6.10):
/// `family` — every active member can participate;
/// `member` — scoped to one specific family member;
/// `spouse` — scoped to a linked couple pair (symmetric; only either spouse).
enum FamilyChatThreadType { family, member, spouse }

/// Thread-level expiration configuration. Phase 1 ships a single approved
/// window (24 hours); the control surface (CH-003) exposes the approved
/// options only — custom windows are a future product decision, not invented
/// here.
enum FamilyChatExpirationWindow { hours24 }

extension FamilyChatExpirationWindowX on FamilyChatExpirationWindow {
  /// Phase 1: exactly one approved window — 24 hours. Any extension MUST go
  /// through a product decision; this getter refuses to invent windows.
  Duration get duration => const Duration(hours: 24);
}

/// Storage helpers for the chat-specific enums. The platform-wide
/// [EnumStorage] extension (guardian_models.dart) does not cover these enums
/// because they live in the FS-010 module — the keys are the approved
/// domain strings, never client-supplied values.
extension FamilyChatTypeStorage on FamilyChatThreadType {
  String get storageKey => switch (this) {
        FamilyChatThreadType.family => 'family',
        FamilyChatThreadType.member => 'member',
        FamilyChatThreadType.spouse => 'spouse',
      };
}

extension FamilyChatMessageStateStorage on FamilyChatMessageState {
  String get storageKey => switch (this) {
        FamilyChatMessageState.queued => 'queued',
        FamilyChatMessageState.failed => 'failed',
        FamilyChatMessageState.sent => 'sent',
        FamilyChatMessageState.expired => 'expired',
      };
}

/// A chat thread within a family. Stable `id`, family binding, role-scoped
/// participants, and an immutable expiration policy chosen at creation.
class FamilyChatThread {
  const FamilyChatThread({
    required this.id,
    required this.familyId,
    required this.type,
    this.memberId,
    required this.expirationWindow,
    required this.createdByMemberId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String familyId;
  final FamilyChatThreadType type;

  /// Present for `member` and `spouse` threads; absent for `family` threads.
  /// Bound at creation and never overwritten by client input after that.
  final String? memberId;
  final FamilyChatExpirationWindow expirationWindow;
  final String createdByMemberId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFamilyThread => type == FamilyChatThreadType.family;
  bool get isMemberThread => type == FamilyChatThreadType.member;
  bool get isSpouseThread => type == FamilyChatThreadType.spouse;
}

/// Honest per-message delivery states (never fake success):
///
/// - `queued`   — written locally, outbox pending (offline-first).
/// - `failed`   — local write or outbox attempt failed; retry available.
/// - `sent`     — local write confirmed and outbox flushed/expired cleanly.
/// - `expired`  — the message's UTC expiry instant has passed; it is removed
///                from active views and only the CH-004 notice references it.
enum FamilyChatMessageState { queued, failed, sent, expired }

/// One ephemeral message inside a thread.
///
/// `idempotencyKey` makes repeated sends provably idempotent: the local
/// write (UNIQUE column) and the outbox row (UNIQUE column) both short-
/// circuit on a replay, so an honest `sent` state is never claimed twice
/// and never silently duplicated.
class FamilyChatMessage {
  const FamilyChatMessage({
    required this.id,
    required this.familyId,
    required this.threadId,
    required this.senderMemberId,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    required this.state,
    required this.idempotencyKey,
  });

  final String id;
  final String familyId;
  final String threadId;
  final String senderMemberId;
  final String body;

  /// UTC instants. `expiresAt` is exactly [createdAt] + the approved
  /// 24-hour window — timezone-independent by construction.
  final DateTime createdAt;
  final DateTime expiresAt;
  final FamilyChatMessageState state;

  /// Stable idempotency key derived from (thread, sender, body, minute
  /// bucket) so a double-tapped send cannot duplicate a message.
  final String idempotencyKey;

  /// UTC-expiry evaluation. A message is expired when the current UTC
  /// instant is at or past its [expiresAt].
  bool isExpired(DateTime nowUtc) => nowUtc.toUtc().isAfter(expiresAt) ||
      nowUtc.toUtc().isAtSameMomentAs(expiresAt);
}

/// Summary row used by the CH-001 list: the thread plus its most recent
/// non-expired message and per-thread expiration indicator.
class FamilyChatThreadSummary {
  const FamilyChatThreadSummary({
    required this.thread,
    required this.lastMessage,
    required this.unreadCount,
  });

  final FamilyChatThread thread;
  final FamilyChatMessage? lastMessage;
  final int unreadCount;
}

/// Outcome of the honest read-time expiration sweep.
class FamilyChatExpirationReport {
  const FamilyChatExpirationReport({
    required this.expiredMessageCount,
    required this.expiredThreads,
    required this.sweptAt,
  });

  final int expiredMessageCount;

  /// Threads whose every remaining message has expired (candidates for the
  /// CH-004 notice and for thread-list removal).
  final List<String> expiredThreads;
  final DateTime sweptAt;
}

/// Honest send result. Never a silent failure: the caller always learns
/// whether the message is queued (offline), failed (with the real reason),
/// or already handled by a previous idempotent send.
enum FamilyChatSendOutcome { sent, queued, failed, duplicate }

/// Authorization-relevant thread eligibility answers returned by the
/// centralized layer; the UI only ever renders an honest verdict.
enum FamilyChatThreadAccess { allowed, deniedRevoked, deniedInvited,
    deniedChild, deniedCrossFamily, deniedUnbound, deniedScope }
