import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/child_device_enforcement.dart';
import '../domain/policy_engine.dart';
import 'child_device_repository.dart';
import 'firestore_contracts.dart';

class RemoteChildPolicyMutation {
  const RemoteChildPolicyMutation(this.policy);
  final DigitalPolicy policy;
}

abstract class ChildPolicySource {
  Future<List<RemoteChildPolicyMutation>> fetchPolicies(String familyId);
}

class FirestoreChildPolicySource implements ChildPolicySource {
  FirestoreChildPolicySource(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<List<RemoteChildPolicyMutation>> fetchPolicies(String familyId) async {
    final snapshot = await _firestore
        .collection('${FirestorePaths.family(familyId)}/policies')
        .get();
    return snapshot.docs.map((document) {
      final data = document.data();
      final policyId = data['policyId'] as String?;
      final name = data['name'] as String?;
      final priority = data['priority'] as int?;
      final enabled = data['enabled'] as bool?;
      final startMinute = data['startMinute'] as int?;
      final endMinute = data['endMinute'] as int?;
      final version = data['version'] as int?;
      final targets = data['restrictedTargets'];
      final dailyLimitMinutes = data['dailyLimitMinutes'] as int?;
      if (policyId == null ||
          name == null ||
          priority == null ||
          enabled == null ||
          startMinute == null ||
          endMinute == null ||
          version == null ||
          targets is! List) {
        throw const FormatException('remote_child_policy_payload_invalid');
      }
      return RemoteChildPolicyMutation(DigitalPolicy(
          id: policyId,
          familyId: familyId,
          name: name,
          priority: priority,
          enabled: enabled,
          startMinute: startMinute,
          endMinute: endMinute,
          restrictedTargets: Set<String>.from(targets),
          dailyLimitMinutes: dailyLimitMinutes,
          version: version));
    }).toList();
  }
}

class ChildPolicySyncReport {
  const ChildPolicySyncReport(
      {required this.fetched,
      required this.applied,
      required this.idempotent,
      required this.ignoredOlder,
      required this.offline,
      required this.reason});
  final int fetched;
  final int applied;
  final int idempotent;
  final int ignoredOlder;
  final bool offline;
  final String reason;
}

/// Pulls only the family policy documents that the authenticated child may read.
/// It deliberately does not read parent-only policy overrides and never treats a
/// local fetch as a server acknowledgement of enforcement.
class ChildPolicyDeliveryService {
  const ChildPolicyDeliveryService(this._repository, this._source);
  final ChildDeviceRepository _repository;
  final ChildPolicySource _source;

  Future<ChildPolicySyncReport> synchronize(String deviceId) async {
    final state = await _repository.getState(deviceId);
    if (state == null) {
      return const ChildPolicySyncReport(
          fetched: 0,
          applied: 0,
          idempotent: 0,
          ignoredOlder: 0,
          offline: false,
          reason: 'child_device_state_missing');
    }
    if (state.lifecycle == ChildDeviceLifecycle.revoked) {
      return const ChildPolicySyncReport(
          fetched: 0,
          applied: 0,
          idempotent: 0,
          ignoredOlder: 0,
          offline: false,
          reason: 'device_revoked');
    }
    try {
      final remote = await _source.fetchPolicies(state.familyId);
      final requiredVersion = remote.fold<int>(
          state.requiredPolicyVersion,
          (highest, mutation) => mutation.policy.version > highest
              ? mutation.policy.version
              : highest);
      var applied = 0;
      var idempotent = 0;
      var ignoredOlder = 0;
      for (final mutation in remote) {
        switch (await _repository.deliverPolicy(
            deviceId: deviceId,
            policy: mutation.policy,
            knownMinimumVersion: requiredVersion)) {
          case ChildPolicyDeliveryResult.applied:
            applied++;
          case ChildPolicyDeliveryResult.idempotent:
            idempotent++;
          case ChildPolicyDeliveryResult.ignoredOlder:
            ignoredOlder++;
        }
      }
      return ChildPolicySyncReport(
          fetched: remote.length,
          applied: applied,
          idempotent: idempotent,
          ignoredOlder: ignoredOlder,
          offline: false,
          reason: 'policy_snapshot_read');
    } catch (_) {
      final current = await _repository.getState(deviceId);
      if (current != null &&
          current.lifecycle != ChildDeviceLifecycle.revoked &&
          const ChildDeviceStateMachine()
              .canTransition(current.lifecycle, ChildDeviceLifecycle.offline)) {
        await _repository.transition(
            deviceId: deviceId,
            to: ChildDeviceLifecycle.offline,
            failureCode: 'policy_delivery_unavailable');
      }
      return const ChildPolicySyncReport(
          fetched: 0,
          applied: 0,
          idempotent: 0,
          ignoredOlder: 0,
          offline: true,
          reason: 'policy_delivery_unavailable');
    }
  }
}
