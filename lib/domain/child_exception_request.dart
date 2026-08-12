import 'guardian_models.dart';

enum ChildExceptionRequestStatus { pending, approved, denied, expired, cancelled }

enum ChildExceptionReason {
  homework,
  schoolAssignment,
  familyActivity,
  importantCommunication,
  other
}

class ChildExceptionRequest {
  const ChildExceptionRequest(
      {required this.id,
      required this.familyId,
      required this.childDeviceId,
      required this.childMemberId,
      required this.childUid,
      required this.target,
      required this.requestedDuration,
      required this.reason,
      required this.createdAt,
      required this.requestExpiresAt,
      required this.status,
      required this.syncState,
      this.policyId,
      this.reasonDetail,
      this.reviewedByMemberId,
      this.reviewedAt,
      this.overrideId,
      this.expiresAt});

  final String id;
  final String familyId;
  final String childDeviceId;
  final String childMemberId;
  final String childUid;
  final String target;
  final String? policyId;
  final Duration requestedDuration;
  final ChildExceptionReason reason;
  final String? reasonDetail;
  final DateTime createdAt;
  final DateTime requestExpiresAt;
  final ChildExceptionRequestStatus status;
  final String? reviewedByMemberId;
  final DateTime? reviewedAt;
  final String? overrideId;
  final DateTime? expiresAt;
  final SyncState syncState;

  bool isExpiredAt(DateTime moment) {
    final now = moment.toUtc();
    return switch (status) {
      ChildExceptionRequestStatus.pending => !requestExpiresAt.isAfter(now),
      ChildExceptionRequestStatus.approved =>
        expiresAt != null && !expiresAt!.toUtc().isAfter(now),
      _ => false
    };
  }
}

class ChildExceptionRequestStateMachine {
  const ChildExceptionRequestStateMachine();

  bool canTransition(ChildExceptionRequestStatus from,
      ChildExceptionRequestStatus to) {
    if (from == to) return true;
    return switch (from) {
      ChildExceptionRequestStatus.pending => {
          ChildExceptionRequestStatus.approved,
          ChildExceptionRequestStatus.denied,
          ChildExceptionRequestStatus.expired,
          ChildExceptionRequestStatus.cancelled
        }.contains(to),
      ChildExceptionRequestStatus.approved =>
        to == ChildExceptionRequestStatus.expired,
      ChildExceptionRequestStatus.denied ||
      ChildExceptionRequestStatus.expired ||
      ChildExceptionRequestStatus.cancelled => false,
    };
  }

  void validateCreate(
      {required String target,
      required String childUid,
      required Duration duration,
      required ChildExceptionReason reason,
      String? detail}) {
    if (target.trim().isEmpty || childUid.trim().isEmpty) {
      throw ArgumentError('exception_request_identity_or_target_invalid');
    }
    if (duration <= Duration.zero || duration > const Duration(hours: 8)) {
      throw ArgumentError('exception_request_duration_invalid');
    }
    if (reason == ChildExceptionReason.other && (detail == null || detail.trim().isEmpty)) {
      throw ArgumentError('exception_request_other_reason_required');
    }
  }

  void requireTransition(ChildExceptionRequestStatus from,
      ChildExceptionRequestStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('invalid_exception_request_transition:${from.name}->${to.name}');
    }
  }
}
