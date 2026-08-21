import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/database/guardian_database.dart';
import '../domain/family_authorization.dart';
import '../domain/guardian_models.dart';

class FamilyMembershipRepository {
  FamilyMembershipRepository(this._database,
      {Uuid? uuid,
      DateTime Function()? clock,
      FamilyAuthorization? authorization})
      : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now,
        _authorization = authorization ?? const FamilyAuthorization();

  final GuardianDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final FamilyAuthorization _authorization;

  Future<List<FamilyMember>> membersForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('family_members',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at ASC');
    return rows.map(FamilyMember.fromMap).toList(growable: false);
  }

  Future<List<FamilyInvitation>> invitationsForFamily(String familyId) async {
    await expireDue(familyId: familyId);
    final db = await _database.database;
    final rows = await db.query('family_invitations',
        where: 'family_id = ?',
        whereArgs: [familyId],
        orderBy: 'created_at DESC');
    return rows.map(FamilyInvitation.fromMap).toList(growable: false);
  }

  Future<Map<String, int>> activeDeviceCountsForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
        'SELECT member_id, COUNT(*) AS device_count FROM devices '
        'WHERE family_id = ? AND revoked_at IS NULL GROUP BY member_id',
        [familyId]);
    return {
      for (final row in rows)
        row['member_id']! as String: (row['device_count']! as num).toInt(),
    };
  }

  Future<FamilyMember> activeOwnerForFamily(String familyId) async {
    final db = await _database.database;
    final rows = await db.query('family_members',
        where: 'family_id = ? AND role = ? AND status = ?',
        whereArgs: [
          familyId,
          FamilyRole.primaryParent.name,
          FamilyMemberStatus.active.name
        ],
        limit: 1);
    if (rows.isEmpty) throw StateError('family_active_owner_not_found');
    return FamilyMember.fromMap(rows.single);
  }

  Future<FamilyMember?> memberForFamily({
    required String familyId,
    required String memberId,
  }) async {
    final db = await _database.database;
    final rows = await db.query('family_members',
        where: 'family_id = ? AND id = ?',
        whereArgs: [familyId, memberId],
        limit: 1);
    return rows.isEmpty ? null : FamilyMember.fromMap(rows.single);
  }

  /// Persists only a locally verified mirror of an already active remote
  /// membership. It intentionally creates no Outbox event because this device
  /// must not initiate or overwrite a Firebase identity binding.
  Future<FamilyMember> bindVerifiedAccount({
    required String familyId,
    required String memberId,
    required String accountUid,
    required FamilyRole expectedRole,
  }) async {
    final uid = accountUid.trim();
    if (uid.isEmpty) throw ArgumentError.value(accountUid, 'accountUid');
    final db = await _database.database;
    return db.transaction((tx) async {
      final member = await _requiredMember(tx, familyId, memberId);
      if (!member.isActive) {
        throw StateError('family_binding_local_member_inactive');
      }
      if (member.role != expectedRole) {
        throw StateError('family_binding_local_role_mismatch');
      }
      if (member.role == FamilyRole.child) {
        throw StateError('family_child_identity_cannot_bind_adult_actor');
      }
      if (member.accountUid != null && member.accountUid != uid) {
        throw StateError('family_binding_local_uid_mismatch');
      }
      final childRows = await tx.query('family_members',
          columns: const ['id'],
          where: 'account_uid = ? AND role = ? AND status = ? AND id != ?',
          whereArgs: [
            uid,
            FamilyRole.child.name,
            FamilyMemberStatus.active.name,
            memberId,
          ],
          limit: 1);
      if (childRows.isNotEmpty) {
        throw StateError('family_child_identity_cannot_bind_adult_actor');
      }
      final duplicates = await tx.query('family_members',
          columns: const ['id'],
          where: 'family_id = ? AND account_uid = ? AND status = ? AND id != ?',
          whereArgs: [
            familyId,
            uid,
            FamilyMemberStatus.active.name,
            memberId,
          ],
          limit: 1);
      if (duplicates.isNotEmpty) {
        throw StateError('family_binding_active_uid_ambiguous');
      }
      if (member.accountUid == uid) return member;
      final now = _now();
      await tx.update(
          'family_members',
          {
            'account_uid': uid,
            'updated_at': now.toIso8601String(),
          },
          where: 'family_id = ? AND id = ?',
          whereArgs: [familyId, memberId]);
      return FamilyMember(
          id: member.id,
          familyId: member.familyId,
          displayName: member.displayName,
          role: member.role,
          createdAt: member.createdAt,
          status: member.status,
          accountUid: uid,
          invitationId: member.invitationId,
          invitedAt: member.invitedAt,
          joinedAt: member.joinedAt,
          revokedAt: member.revokedAt,
          updatedAt: now);
    });
  }

  Future<FamilyInvitation> inviteAdult(
      {required String familyId,
      required String actorMemberId,
      required String targetEmail,
      required FamilyRole proposedRole,
      Duration validity = const Duration(days: 7)}) async {
    final email = _canonicalEmail(targetEmail);
    if (!_isInvitableAdultRole(proposedRole)) {
      throw ArgumentError.value(proposedRole, 'proposedRole',
          'Only parent or coParent may be invited in Phase 17.');
    }
    if (validity <= Duration.zero) {
      throw ArgumentError.value(
          validity, 'validity', 'Invitation must expire later.');
    }
    final now = _now();
    final invitation = FamilyInvitation(
        id: _uuid.v4(),
        familyId: familyId,
        inviterMemberId: actorMemberId,
        targetEmail: email,
        proposedRole: proposedRole,
        status: FamilyInvitationStatus.pending,
        code: _generateInvitationCode(),
        createdAt: now,
        expiresAt: now.add(validity));
    final db = await _database.database;
    return db.transaction((tx) async {
      await _requireOwner(
          tx, familyId, actorMemberId, FamilyPermission.inviteMembers);
      await tx.insert('family_invitations', _invitationMap(invitation));
      await _enqueue(tx,
          aggregateId: invitation.id,
          operation: 'family.member.invited',
          payload: {
            'familyId': invitation.familyId,
            'invitationId': invitation.id,
            'inviterMemberId': invitation.inviterMemberId,
            'targetEmail': invitation.targetEmail,
            'proposedRole': invitation.proposedRole.name,
            'code': invitation.code,
            'createdAt': invitation.createdAt.toIso8601String(),
            'expiresAt': invitation.expiresAt.toIso8601String(),
          });
      return invitation;
    });
  }

  Future<FamilyInvitation?> lookupInvitationByCode(String code) async {
    final value = code.trim().toUpperCase();
    if (value.isEmpty) return null;
    final db = await _database.database;
    final rows = await db.query('family_invitations',
        where: 'code = ? AND status = ?',
        whereArgs: [value, FamilyInvitationStatus.pending.name],
        limit: 1);
    if (rows.isEmpty) return null;
    final invitation = FamilyInvitation.fromMap(rows.single);
    if (invitation.isExpiredAt(_now())) return null;
    return invitation;
  }

  Future<FamilyMember> acceptInvitation(
      {required String invitationId,
      required String accountUid,
      required String accountEmail,
      required String displayName}) async {
    final uid = accountUid.trim();
    final email = _canonicalEmail(accountEmail);
    final name = displayName.trim();
    if (uid.isEmpty || name.isEmpty) {
      throw ArgumentError(
          'An authenticated account UID and display name are required.');
    }
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _now();
      final invitation = await _requiredInvitation(tx, invitationId);
      if (invitation.status == FamilyInvitationStatus.accepted) {
        if (invitation.acceptedAccountUid != uid ||
            invitation.acceptedMemberId == null) {
          throw StateError('family_invitation_already_accepted');
        }
        return _requiredMember(
            tx, invitation.familyId, invitation.acceptedMemberId!);
      }
      await _expireIfDue(tx, invitation, now);
      if (invitation.isExpiredAt(now) ||
          invitation.status == FamilyInvitationStatus.expired) {
        throw StateError('family_invitation_expired');
      }
      if (invitation.status != FamilyInvitationStatus.pending) {
        throw StateError('family_invitation_not_pending');
      }
      if (invitation.targetEmail != email) {
        throw StateError('family_invitation_target_mismatch');
      }
      if (!_isInvitableAdultRole(invitation.proposedRole)) {
        throw StateError('family_invitation_role_not_allowed');
      }
      final childIdentity = await tx.query('family_members',
          columns: const ['id'],
          where: 'account_uid = ? AND role = ? AND status = ?',
          whereArgs: [
            uid,
            FamilyRole.child.name,
            FamilyMemberStatus.active.name
          ],
          limit: 1);
      if (childIdentity.isNotEmpty) {
        throw StateError(
            'family_child_identity_cannot_accept_adult_invitation');
      }
      final existing = await tx.query('family_members',
          columns: const ['id'],
          where: 'family_id = ? AND account_uid = ? AND status = ?',
          whereArgs: [invitation.familyId, uid, FamilyMemberStatus.active.name],
          limit: 1);
      if (existing.isNotEmpty) {
        throw StateError('family_account_already_active_member');
      }
      final member = FamilyMember(
          id: _uuid.v4(),
          familyId: invitation.familyId,
          displayName: name,
          role: invitation.proposedRole,
          createdAt: now,
          status: FamilyMemberStatus.active,
          accountUid: uid,
          invitationId: invitation.id,
          invitedAt: invitation.createdAt,
          joinedAt: now,
          updatedAt: now);
      await tx.insert('family_members', _memberMap(member));
      await tx.update(
          'family_invitations',
          {
            'status': FamilyInvitationStatus.accepted.name,
            'accepted_at': now.toIso8601String(),
            'accepted_account_uid': uid,
            'accepted_member_id': member.id,
          },
          where: 'id = ?',
          whereArgs: [invitation.id]);
      await _enqueue(tx,
          aggregateId: member.id,
          operation: 'family.member.accepted',
          payload: {
            'familyId': invitation.familyId,
            'invitationId': invitation.id,
            'memberId': member.id,
            'accountUid': uid,
            'displayName': member.displayName,
            'role': member.role.name,
            'acceptedAt': now.toIso8601String(),
          });
      return member;
    });
  }

  Future<void> cancelInvitation(
      {required String familyId,
      required String invitationId,
      required String actorMemberId}) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final now = _now();
      final invitation = await _requiredInvitation(tx, invitationId);
      if (invitation.familyId != familyId) {
        throw StateError('family_invitation_family_mismatch');
      }
      await _requireOwner(
          tx, familyId, actorMemberId, FamilyPermission.inviteMembers);
      await _expireIfDue(tx, invitation, now);
      if (invitation.status != FamilyInvitationStatus.pending ||
          invitation.isExpiredAt(now)) {
        throw StateError('family_invitation_not_cancellable');
      }
      await tx.update(
          'family_invitations',
          {
            'status': FamilyInvitationStatus.cancelled.name,
            'cancelled_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invitationId]);
      await _enqueue(tx,
          aggregateId: invitationId,
          operation: 'family.invitation.cancelled',
          payload: {
            'familyId': familyId,
            'invitationId': invitationId,
            'cancelledAt': now.toIso8601String(),
          });
    });
  }

  Future<void> revokeMember(
      {required String familyId,
      required String actorMemberId,
      required String targetMemberId}) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      final now = _now();
      await _requireOwner(
          tx, familyId, actorMemberId, FamilyPermission.revokeMembers);
      final target = await _requiredMember(tx, familyId, targetMemberId);
      _requireRevocableAdult(target);
      await tx.update(
          'family_members',
          {
            'status': FamilyMemberStatus.revoked.name,
            'revoked_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ? AND family_id = ?',
          whereArgs: [targetMemberId, familyId]);
      await tx.update(
          'devices',
          {
            'revoked_at': now.toIso8601String(),
            'sync_state': SyncState.queued.name,
          },
          where: 'family_id = ? AND member_id = ? AND revoked_at IS NULL',
          whereArgs: [familyId, targetMemberId]);
      if (target.accountUid == null) {
        throw StateError('family_adult_member_account_not_bound');
      }
      await _enqueue(tx,
          aggregateId: targetMemberId,
          operation: 'family.member.revoked',
          payload: {
            'familyId': familyId,
            'memberId': targetMemberId,
            'accountUid': target.accountUid,
            'revokedAt': now.toIso8601String(),
          });
    });
  }

  Future<void> updateAdultRole(
      {required String familyId,
      required String actorMemberId,
      required String targetMemberId,
      required FamilyRole role}) async {
    if (!_isInvitableAdultRole(role)) {
      throw ArgumentError.value(role, 'role',
          'Only parent and coParent roles are mutable in Phase 17.');
    }
    final db = await _database.database;
    await db.transaction((tx) async {
      final now = _now();
      await _requireOwner(
          tx, familyId, actorMemberId, FamilyPermission.manageRoles);
      final target = await _requiredMember(tx, familyId, targetMemberId);
      _requireRevocableAdult(target);
      if (target.status != FamilyMemberStatus.active) {
        throw StateError('family_member_not_active');
      }
      if (target.accountUid == null) {
        throw StateError('family_adult_member_account_not_bound');
      }
      await tx.update(
          'family_members',
          {
            'role': role.name,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ? AND family_id = ?',
          whereArgs: [targetMemberId, familyId]);
      await _enqueue(tx,
          aggregateId: targetMemberId,
          operation: 'family.member.role.updated',
          payload: {
            'familyId': familyId,
            'memberId': targetMemberId,
            'accountUid': target.accountUid,
            'role': role.name,
            'updatedAt': now.toIso8601String(),
          });
    });
  }

  Future<int> expireDue({required String familyId}) async {
    final db = await _database.database;
    return db.transaction((tx) async {
      final now = _now();
      final rows = await tx.query('family_invitations',
          where: 'family_id = ? AND status = ?',
          whereArgs: [familyId, FamilyInvitationStatus.pending.name]);
      var changed = 0;
      for (final row in rows) {
        final invitation = FamilyInvitation.fromMap(row);
        if (!invitation.isExpiredAt(now)) continue;
        await _expireIfDue(tx, invitation, now);
        changed++;
      }
      return changed;
    });
  }

  Future<FamilyInvitation> _requiredInvitation(
      Transaction tx, String invitationId) async {
    final rows = await tx.query('family_invitations',
        where: 'id = ?', whereArgs: [invitationId], limit: 1);
    if (rows.isEmpty) throw StateError('family_invitation_not_found');
    return FamilyInvitation.fromMap(rows.single);
  }

  Future<FamilyMember> _requiredMember(
      Transaction tx, String familyId, String memberId) async {
    final rows = await tx.query('family_members',
        where: 'id = ? AND family_id = ?',
        whereArgs: [memberId, familyId],
        limit: 1);
    if (rows.isEmpty) throw StateError('family_member_not_found');
    return FamilyMember.fromMap(rows.single);
  }

  Future<void> _requireOwner(Transaction tx, String familyId,
      String actorMemberId, FamilyPermission permission) async {
    final actor = await _requiredMember(tx, familyId, actorMemberId);
    _authorization.require(actor, permission);
  }

  Future<void> _expireIfDue(
      Transaction tx, FamilyInvitation invitation, DateTime now) async {
    if (!invitation.isExpiredAt(now)) return;
    await tx.update(
        'family_invitations', {'status': FamilyInvitationStatus.expired.name},
        where: 'id = ? AND status = ?',
        whereArgs: [invitation.id, FamilyInvitationStatus.pending.name]);
  }

  void _requireRevocableAdult(FamilyMember member) {
    if (member.role == FamilyRole.primaryParent) {
      throw StateError('family_ownership_transfer_not_implemented');
    }
    if (!_isInvitableAdultRole(member.role)) {
      throw StateError('family_member_role_not_managed_in_phase_17');
    }
    if (member.status != FamilyMemberStatus.active) {
      throw StateError('family_member_not_active');
    }
  }

  bool _isInvitableAdultRole(FamilyRole role) =>
      role == FamilyRole.parent || role == FamilyRole.coParent;

  String _canonicalEmail(String rawEmail) {
    final value = rawEmail.trim().toLowerCase();
    if (value.isEmpty || !value.contains('@')) {
      throw ArgumentError.value(
          rawEmail, 'email', 'A valid target email is required.');
    }
    return value;
  }

  DateTime _now() => _clock().toUtc();

  Map<String, Object?> _memberMap(FamilyMember member) => {
        'id': member.id,
        'family_id': member.familyId,
        'display_name': member.displayName,
        'role': member.role.name,
        'status': member.status.name,
        'account_uid': member.accountUid,
        'invitation_id': member.invitationId,
        'invited_at': member.invitedAt?.toIso8601String(),
        'joined_at': member.joinedAt?.toIso8601String(),
        'revoked_at': member.revokedAt?.toIso8601String(),
        'updated_at': member.updatedAt?.toIso8601String(),
        'created_at': member.createdAt.toIso8601String(),
      };

  Map<String, Object?> _invitationMap(FamilyInvitation invitation) => {
        'id': invitation.id,
        'family_id': invitation.familyId,
        'inviter_member_id': invitation.inviterMemberId,
        'target_email': invitation.targetEmail,
        'proposed_role': invitation.proposedRole.name,
        'status': invitation.status.name,
        'code': invitation.code,
        'created_at': invitation.createdAt.toIso8601String(),
        'expires_at': invitation.expiresAt.toIso8601String(),
        'accepted_at': invitation.acceptedAt?.toIso8601String(),
        'accepted_account_uid': invitation.acceptedAccountUid,
        'accepted_member_id': invitation.acceptedMemberId,
        'cancelled_at': invitation.cancelledAt?.toIso8601String(),
      };

  String _generateInvitationCode() {
    final random = _uuid.v4().replaceAll('-', '').substring(0, 6).toUpperCase();
    return random;
  }

  Future<void> _enqueue(Transaction tx,
      {required String aggregateId,
      required String operation,
      required Map<String, Object?> payload}) async {
    final now = _now();
    final eventId = _uuid.v4();
    await tx.insert('outbox', {
      'id': eventId,
      'aggregate_type': 'familyMembership',
      'aggregate_id': aggregateId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'idempotency_key': eventId,
      'state': SyncState.queued.name,
      'attempt_count': 0,
      'next_attempt_at': now.toIso8601String(),
      'created_at': now.toIso8601String(),
    });
  }
}
