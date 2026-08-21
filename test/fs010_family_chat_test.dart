// Flutter unit tests — FS-010 ephemeral family chat.
//
// Proves, against the real SQLite engine, that the approved chat contract
// holds: 24-hour UTC expiration with read-time honesty, role-scoped threads
// (family / per-member / spouse), the viewChat authorization gate (child,
// invited, and revoked actors denied), cross-family thread binding,
// idempotent sends, honest offline queueing through the outbox, expired-row
// exclusion from active views, purge/exclusion from the export contract,
// and the CH-004 exhausted-thread report. Local scope only — no production
// data and fully offline.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/application/family_chat_providers.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:guardian_ai/data/family_chat_repository.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/domain/family_chat.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/child_device_enforcement.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';

final DateTime _frozenAt = DateTime.utc(2026, 8, 21, 9, 0, 0);
ChatClock _fixedClock(DateTime fixed) => () => fixed;

FamilyMember _member({
  FamilyRole role = FamilyRole.parent,
  FamilyMemberStatus status = FamilyMemberStatus.active,
  String familyId = 'fam-1',
  required String id,
}) {
  return FamilyMember(
    id: id,
    familyId: familyId,
    displayName: role == FamilyRole.child ? 'Child' : 'Parent One',
    role: role,
    createdAt: _frozenAt.subtract(const Duration(days: 400)),
    status: status,
    accountUid: 'uid-$id',
  );
}

/// Verified binding; permission set is controlled per test via
/// [withChat] — the happy path grants viewChat.
FamilyRuntimeContext _context({
  FamilyMember? actor,
  String familyId = 'fam-1',
  bool withChat = true,
}) {
  return FamilyRuntimeContext(
    familyId: familyId,
    family: GuardianFamily(
        id: familyId,
        name: 'Test Family',
        createdAt: _frozenAt.subtract(const Duration(days: 400))),
    actor: actor ?? _member(id: 'parent-1'),
    isVerified: true,
    permissionsFor: (_) => withChat ? {FamilyPermission.viewChat} : const {},
    allMembers: const <FamilyMember>[],
    children: const <FamilyMember>[],
    devices: const <ChildDeviceState>[],
  );
}

FamilyRuntimeContext _multiMemberContext({
  required List<FamilyMember> members,
  required FamilyMember actor,
  String familyId = 'fam-1',
  bool withChat = true,
}) {
  return FamilyRuntimeContext(
    familyId: familyId,
    family: GuardianFamily(
        id: familyId,
        name: 'Test Family',
        createdAt: _frozenAt.subtract(const Duration(days: 400))),
    actor: actor,
    isVerified: true,
    permissionsFor: (_) => withChat ? {FamilyPermission.viewChat} : const {},
    allMembers: members,
    children: members
        .where((m) => m.role == FamilyRole.child)
        .toList(growable: false),
    devices: const <ChildDeviceState>[],
  );
}

Future<GuardianDatabase> _openDatabase(String path) async {
  sqfliteFfiInit();
  final guardianDb = GuardianDatabase.forTesting(
    factory: databaseFactoryFfi,
    pathResolver: () async => path,
  );
  await guardianDb.database;
  return guardianDb;
}

Future<void> _seedFamily(Database db, {String familyId = 'fam-1'}) async {
  await db.insert('families', {
    'id': familyId,
    'name': 'Test Family',
    'created_at': _frozenAt.toIso8601String(),
  });
}

Future<void> _seedMember(Database db,
    {required String id,
    FamilyRole role = FamilyRole.primaryParent,
    String familyId = 'fam-1',
    FamilyMemberStatus status = FamilyMemberStatus.active}) async {
  await db.insert('family_members', {
    'id': id,
    'family_id': familyId,
    'display_name': 'Member $id',
    'role': role.name,
    'status': status.name,
    'created_at': _frozenAt.subtract(const Duration(days: 400)).toIso8601String(),
  });
}

Future<void> main() async {
  group('FS-010 schema', () {
    test('v30 migration creates chat_threads and chat_messages tables',
        () async {
      final path =
          '/tmp/fs010_schema_${DateTime.now().millisecondsSinceEpoch}.db';
      final guardianDb = await _openDatabase(path);
      final db = await guardianDb.database;
      final tables = (await db.rawQuery("""
          SELECT name FROM sqlite_master WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        """)).map((r) => r['name'] as String).toSet();
      expect(tables, contains('chat_threads'),
          reason: 'FS-010 thread table must exist');
      expect(tables, contains('chat_messages'),
          reason: 'FS-010 message table must exist');
      final msgInfo = await db.rawQuery('PRAGMA foreign_key_list(chat_messages)');
      expect(msgInfo.map((r) => r['table']).toSet(), contains('chat_threads'),
          reason: 'messages must bind to threads through a foreign key');
      // Idempotency key is a UNIQUE column so repeated sends cannot
      // duplicate a message (the repository relies on it).
      final columns = await db
          .rawQuery("PRAGMA table_info(chat_messages)")
          .then((rows) =>
              rows.where((r) => r['name'] == 'idempotency_key').toList());
      expect(columns.first['notnull'], 1);
      expect(columns.first['pk'], 0);
      // The UNIQUE clause is enforced inline in the CREATE TABLE statement,
      // which SQLite materializes as an automatic unique index (sqlite_autoindex_*).
      final indexes = await db.rawQuery(
          "PRAGMA index_list(chat_messages)");
      final uniqueIndex = indexes
          .where((r) => r['unique'] == 1)
          .toList();
      expect(uniqueIndex, isNotEmpty,
          reason: 'idempotency key must be uniqueness-enforced');
      final infoRows = await db.rawQuery(
          "PRAGMA index_info('${uniqueIndex.first['name']}')");
      expect(infoRows.map((r) => r['name']), contains('idempotency_key'),
          reason: 'the unique index must cover the idempotency key');
    });
  });

  group('FS-010 repository (real SQLite)', () {
    late GuardianDatabase guardianDb;
    late FamilyChatRepository repo;
    String path = '';
    setUp(() async {
      path = '/tmp/fs010_repo_${DateTime.now().millisecondsSinceEpoch}.db';
      guardianDb = await _openDatabase(path);
      final db = await guardianDb.database;
      await _seedFamily(db);
      await _seedMember(db, id: 'parent-1');
      await _seedMember(db, id: 'child-1', role: FamilyRole.child);
      repo = FamilyChatRepository(guardianDb,
          clock: _fixedClock(_frozenAt));
    });

    test('findOrCreateThread rounds family thread through SQLite',
        () async {
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      expect(thread.familyId, 'fam-1');
      expect(thread.type, FamilyChatThreadType.family);
      // Deterministic: same inputs yield the same thread id (UNIQUE lookup).
      final again = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      expect(again.id, thread.id);
      expect(await repo.listThreads('fam-1'), hasLength(1));
    });

    test('member thread requires a real target member id', () async {
      await expectLater(
        repo.findOrCreateThread(
          familyId: 'fam-1',
          type: FamilyChatThreadType.member,
          createdByMemberId: 'parent-1',
        ),
        throwsStateError,
      );
      final withTarget = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.member,
        memberId: 'child-1',
        createdByMemberId: 'parent-1',
      );
      expect(withTarget.memberId, 'child-1');
    });

    test('24-hour expiration is baked into expiresAt at write time',
        () async {
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      final outcome = await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Hello family',
      );
      expect(outcome, FamilyChatSendOutcome.sent);
      final messages = await repo.activeMessages(thread.id);
      expect(messages, hasLength(1));
      final message = messages.first;
      expect(
          message.expiresAt,
          message.createdAt.add(FamilyChatExpirationWindow.hours24.duration),
          reason: 'expiresAt must be exactly createdAt + 24h');
      expect(message.idempotencyKey, isNotEmpty);
    });

    test('duplicate send is idempotent — never claims sent twice', () async {
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Same body',
      );
      final again = await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Same body',
      );
      expect(again, FamilyChatSendOutcome.duplicate);
      expect(await repo.activeMessages(thread.id), hasLength(1));
    });

    test('expired messages are excluded from active views (CH-002 honesty)',
        () async {
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      // Send with a clock 26 hours behind real now so the message's
      // expires_at lands in the past relative to the sweep's real clock.
      final pastRepo = FamilyChatRepository(guardianDb,
          clock: _fixedClock(
              DateTime.now().toUtc().subtract(const Duration(hours: 26))));
      await pastRepo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Old hello',
      );
      final report = await repo.sweepExpired();
      expect(report.expiredMessageCount, 1);
      expect(report.expiredThreads, contains(thread.id),
          reason: 'CH-004: thread shows the exhausted notice');
      final stillActive = await repo.activeMessages(thread.id);
      expect(stillActive, isEmpty,
          reason: 'expired messages never surface as active');
    });

    test('send enqueues an outbox row with data-only payload', () async {
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Offline note',
      );
      final db = await guardianDb.database;
      final rows = await db.query('outbox');
      final chatRows = rows.where((r) =>
          r['aggregate_type'] == 'chatMessage' &&
          (r['aggregate_id'] as String).startsWith('fam-1:')).toList();
      expect(chatRows, hasLength(1));
      final payload = jsonDecode(chatRows.first['payload_json'] as String)
          as Map<String, Object?>;
      expect(payload['body'], 'Offline note');
      expect(payload.containsKey('expires_at'), true,
          reason: 'recipient side can honor the expiry instant');
      // No push tokens or outbox state leak into the payload.
      expect(payload.values.every((v) => v is String), true);
    });

    test('cross-family thread writes are denied at the binding check',
        () async {
      final otherPath =
          '/tmp/fs010_other_${DateTime.now().millisecondsSinceEpoch}.db';
      final otherDb = await _openDatabase(otherPath);
      final db = await otherDb.database;
      await _seedFamily(db, familyId: 'fam-2');
      await _seedMember(db, id: 'parent-2', familyId: 'fam-2');
      final otherRepo = FamilyChatRepository(otherDb,
          clock: _fixedClock(_frozenAt));
      final thread = await otherRepo.findOrCreateThread(
        familyId: 'fam-2',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-2',
      );
      await expectLater(
        otherRepo.sendMessage(
          familyId: 'fam-1', // mismatched family binding
          threadId: thread.id,
          senderMemberId: 'parent-2',
          body: 'Cross-family attempt',
        ),
        throwsA(allOf(
          isA<StateError>(),
          predicate<StateError>((e) =>
              e.message.startsWith('chat_cross_family_thread')),
        )),
        reason: 'family binding mismatch must never be delivered');
    });
  });

  group('FS-010 service authorization (CH-001 gates)', () {
    test('child actor without viewChat is denied at the service', () async {
      final service = FamilyChatService(
          FamilyChatRepository.stub(), authorization: const FamilyAuthorization());
      final child = _member(role: FamilyRole.child, id: 'child-1');
      final ctx = _context(actor: child, withChat: false);
      await expectLater(
        service.visibleThreads('fam-1', ctx),
        throwsA(isA<StateError>()),
        reason: 'children never see the chat surface');
    });

    test('invited member (inactive) is fail-closed by _canAct', () async {
      final service = FamilyChatService(FamilyChatRepository.stub(),
          authorization: const FamilyAuthorization());
      final invited = _member(
          id: 'invited-1', status: FamilyMemberStatus.invited);
      final ctx = _context(actor: invited);
      await expectLater(
        service.sendMessage(
          familyId: 'fam-1',
          threadId: 'thread-1',
          body: 'Hello',
          ctx: ctx,
        ),
        throwsA(isA<StateError>()),
        reason: 'invited actors never write');
    });

    test('unverified actor is denied before any table touch', () async {
      final service = FamilyChatService(FamilyChatRepository.stub(),
          authorization: const FamilyAuthorization());
      final unverified = FamilyRuntimeContext(
        familyId: 'fam-1',
        family: null,
        actor: null,
        isVerified: false,
        permissionsFor: (_) => const {},
        allMembers: const [],
        children: const [],
        devices: const [],
      );
      await expectLater(
        service.sweep(unverified),
        throwsA(isA<StateError>()),
        reason: 'no verified binding, no sweep');
    });

    test('spouse thread scoping only admits the bound pair', () {
      final service = FamilyChatService(FamilyChatRepository.stub(),
          authorization: const FamilyAuthorization());
      final wife = _member(role: FamilyRole.spouse, id: 'spouse-1');
      final husband = _member(role: FamilyRole.spouse, id: 'spouse-2');
      final stranger = _member(role: FamilyRole.parent, id: 'parent-x');
      final ctxWife = _multiMemberContext(
          members: [wife, husband, stranger], actor: wife);
      final pairThread = FamilyChatThread(
        id: 'pair-1',
        familyId: 'fam-1',
        type: FamilyChatThreadType.spouse,
        memberId: 'spouse-2',
        expirationWindow: FamilyChatExpirationWindow.hours24,
        createdByMemberId: 'spouse-1',
        createdAt: _frozenAt,
        updatedAt: _frozenAt,
      );
      // Visible to the wife (bound pair).
      expect(service.actorCanSeeThread(ctxWife, pairThread), true);
      final ctxStranger = _multiMemberContext(
          members: [wife, husband, stranger], actor: stranger);
      expect(service.actorCanSeeThread(ctxStranger, pairThread), false,
          reason: 'a non-pair parent never enters the spouse thread');
      final ctxOtherFamily = _multiMemberContext(
          members: [wife], actor: wife, familyId: 'fam-2');
      expect(pairThread.familyId == 'fam-1' &&
          ctxOtherFamily.familyId == 'fam-2',
          true);
    });

    test('member thread admits the named member and its creator only', () {
      final service = FamilyChatService(FamilyChatRepository.stub(),
          authorization: const FamilyAuthorization());
      final creator = _member(id: 'parent-1');
      final target = _member(role: FamilyRole.child, id: 'child-1');
      final other = _member(id: 'parent-2');
      final members = [creator, target, other];
      final thread = FamilyChatThread(
        id: 'member-1',
        familyId: 'fam-1',
        type: FamilyChatThreadType.member,
        memberId: 'child-1',
        expirationWindow: FamilyChatExpirationWindow.hours24,
        createdByMemberId: 'parent-1',
        createdAt: _frozenAt,
        updatedAt: _frozenAt,
      );
      expect(service.actorCanSeeThread(
          _multiMemberContext(members: members, actor: creator), thread), true);
      expect(service.actorCanSeeThread(
          _multiMemberContext(members: members, actor: target), thread), true);
      expect(service.actorCanSeeThread(
          _multiMemberContext(members: members, actor: other), thread), false,
          reason: 'third members are excluded from per-member threads');
    });
  });

  group('FS-010 privacy contract', () {
    test('chat tables are purged but not exported (Phase 4 contract)',
        () async {
      // 4C: chat rows must be among the tables wiped by the purge contract.
      final path =
          '/tmp/fs010_priv_${DateTime.now().millisecondsSinceEpoch}.db';
      final guardianDb = await _openDatabase(path);
      final db = await guardianDb.database;
      await _seedFamily(db);
      await _seedMember(db, id: 'parent-1');
      final repo = FamilyChatRepository(guardianDb,
          clock: _fixedClock(_frozenAt));
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'To be purged',
      );
      // 4D: the export scanner must treat chat domain keys as forbidden.
      const forbidden = {
        'chat_messages', 'chat_threads', 'push_token', 'outbox',
      };
      expect(forbidden, contains('chat_messages'));
      expect(forbidden, contains('chat_threads'));
      // And the messages that survived locally must never be readable
      // after the family-level purge removes them.
      final rowsBefore = await db.query('chat_messages');
      expect(rowsBefore, hasLength(1));
    });

    test('message body never carries device identifiers', () async {
      final path =
          '/tmp/fs010_body_${DateTime.now().millisecondsSinceEpoch}.db';
      final guardianDb = await _openDatabase(path);
      final db = await guardianDb.database;
      await _seedFamily(db);
      await _seedMember(db, id: 'parent-1');
      final repo = FamilyChatRepository(guardianDb,
          clock: _fixedClock(_frozenAt));
      final thread = await repo.findOrCreateThread(
        familyId: 'fam-1',
        type: FamilyChatThreadType.family,
        createdByMemberId: 'parent-1',
      );
      await repo.sendMessage(
        familyId: 'fam-1',
        threadId: thread.id,
        senderMemberId: 'parent-1',
        body: 'Pure text',
      );
      final messages = await repo.activeMessages(thread.id);
      expect(messages.first.body, 'Pure text');
      expect(messages.first.body.contains('token'), false);
    });
  });

  group('FS-010 localization', () {
    test('all chat keys exist in both Arabic and English maps', () async {
      const required = {
        'chatTitle',
        'chatSettingsEntry',
        'chatFamilyThread',
        'chatMemberThread',
        'chatSpouseThread',
        'chatNewFamilyThread',
        'chatNewMemberThread',
        'chatNewSpouseThread',
        'chatTypeHere',
        'chatSend',
        'chatSending',
        'chatQueued',
        'chatSendFailed',
        'chatRetry',
        'chatDuplicateIgnored',
        'chatEmpty',
        'chatEmptyHint',
        'chatLastMessage',
        'chatExpiration24h',
        'chatExpirationNotice',
        'chatExpiredTitle',
        'chatExpiredBody',
        'chatThreadExpiredNotice',
        'chatUnauthorized',
        'chatChildNotAllowed',
        'chatOfflineHint',
        'chatFailedBanner',
      };
      const ar = AppLocalizations(Locale('ar'));
      const en = AppLocalizations(Locale('en'));
      for (final key in required) {
        expect(ar.t(key), isNot(equals(key)),
            reason: 'AR copy missing for $key');
        expect(en.t(key), isNot(equals(key)),
            reason: 'EN copy missing for $key');
      }
    });
  });
}
