// FS-015 — Device Linking & Enrollment domain model.
//
// This file extends the M4 pairing foundation (PairingRequest,
// PairingRepository, PairingLifecycle) with the domain types the 11 FS-015
// screens consume: the family device roster, the honest device-health
// verdicts, the permission-onboarding ladder and the device-transfer state
// machine. Nothing here touches the database directly — every method is a
// pure function or a thin adapter over repository rows.

import 'guardian_models.dart';

/// Honest device-health verdict used by the DL-010 Device Health Dashboard.
/// The verdict is derived ONLY from stored facts (last sync freshness,
/// lifecycle, revocation) — it never claims a device is healthy without
/// evidence.
enum DeviceHealthKind {
  /// The device synced recently and its lifecycle is enrolled.
  healthy,
  /// The device is enrolled but its last sync is stale.
  stale,
  /// The device has not synced for a long time or never synced.
  offline,
  /// The device was revoked by its owner.
  revoked,
}

/// Derived, human-honest device health record.
class DeviceHealth {
  const DeviceHealth({
    required this.deviceId,
    required this.familyId,
    required this.memberId,
    required this.role,
    required this.health,
    required this.lastSyncedAt,
    required this.lifecycle,
    this.freshnessMinutes,
  });

  final String deviceId;
  final String familyId;
  final String memberId;
  final String role;
  final DeviceHealthKind health;
  final DateTime? lastSyncedAt;
  final String lifecycle;
  final int? freshnessMinutes;

  static const Duration _staleThreshold = Duration(hours: 3);
  static const Duration _offlineThreshold = Duration(days: 3);

  /// Derives the health verdict from a raw devices row plus its optional
  /// child lifecycle record. Freshness is computed against [now].
  factory DeviceHealth.fromRows(
    Map<String, Object?> deviceRow,
    Map<String, Object?>? lifecycleRow, {
    DateTime? now,
  }) {
    final nowStamp = now ?? DateTime.now();
    final deviceId = deviceRow['id'] as String;
    final familyId = deviceRow['family_id'] as String;
    final memberId = deviceRow['member_id'] as String;
    final role = deviceRow['role'] as String;
    final rawSync = deviceRow['last_synced_at'];
    final revokedAt = deviceRow['revoked_at'];
    final lifecycle =
        (lifecycleRow?['lifecycle'] as String?) ?? 'enrolled';

    if (revokedAt != null) {
      return DeviceHealth(
          deviceId: deviceId,
          familyId: familyId,
          memberId: memberId,
          role: role,
          health: DeviceHealthKind.revoked,
          lastSyncedAt: _tryParse(rawSync),
          lifecycle: lifecycle);
    }

    final lastSyncedAt = _tryParse(rawSync);
    int? freshnessMinutes;
    DeviceHealthKind kind;
    if (lastSyncedAt == null) {
      kind = DeviceHealthKind.offline;
    } else {
      freshnessMinutes = nowStamp.difference(lastSyncedAt).inMinutes;
      final age = nowStamp.difference(lastSyncedAt);
      if (age <= _staleThreshold) {
        kind = DeviceHealthKind.healthy;
      } else if (age <= _offlineThreshold) {
        kind = DeviceHealthKind.stale;
      } else {
        kind = DeviceHealthKind.offline;
      }
    }
    return DeviceHealth(
        deviceId: deviceId,
        familyId: familyId,
        memberId: memberId,
        role: role,
        health: kind,
        lastSyncedAt: lastSyncedAt,
        lifecycle: lifecycle,
        freshnessMinutes: freshnessMinutes);
  }

  static DateTime? _tryParse(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

/// One step of the Android permission onboarding ladder (DL-008). Each row
/// reports its REAL state — never a synthesized "granted".
enum PermissionLadderStep {
  /// location_coarse → location_fine → location_background.
  location,
  /// ACCESS_NOTIFICATION_POLICY / accessibility disclosure.
  notificationAccess,
  /// PACKAGE_USAGE_STATS usage statistics.
  usageStats,
  /// Foreground service / battery-optimization exemption disclosure.
  backgroundService,
}

/// Honest state of one ladder step.
enum LadderStepState {
  /// The permission is granted on the device.
  granted,
  /// The permission exists but requires opening system settings.
  requiresSettings,
  /// The Android version / edition cannot support this permission.
  unsupported,
  /// The actor explicitly deferred the step.
  deferred,
}

/// One row of the DL-008 permission ladder.
class PermissionLadderRow {
  const PermissionLadderRow({
    required this.step,
    required this.state,
    this.detail,
  });
  final PermissionLadderStep step;
  final LadderStepState state;
  final String? detail;
}

/// Result of a device-transfer attempt (DL-011).
class DeviceTransferResult {
  const DeviceTransferResult({
    required this.succeeded,
    this.newDeviceId,
    this.failure,
  });
  final bool succeeded;
  final String? newDeviceId;
  final String? failure;

  static const DeviceTransferResult successNoop =
      DeviceTransferResult(succeeded: true);
}

/// Pure state machine for device role transitions during enrollment and
/// transfer.
class DeviceLinkingLifecycle {
  const DeviceLinkingLifecycle();

  /// Allowed transitions for a pairing session status.
  static bool canTransitionSession(PairingState from, PairingState to) =>
      PairingLifecycle.canTransition(from, to);

  /// Whether a device row may receive a transfer (enrolled, not revoked).
  static bool isTransferable(String lifecycle, String? revokedAt) =>
      lifecycle == 'enrolled' && revokedAt == null;

  /// Whether a new device can be enrolled under the same member
  /// (no active unrevoked device already bound).
  static bool memberIsFree({
    required bool memberHasActiveDevice,
    required String? existingRole,
  }) =>
      !memberHasActiveDevice || existingRole != null;
}
