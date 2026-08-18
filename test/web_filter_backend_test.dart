import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:guardian_ai/data/firestore_contracts.dart';
import 'package:guardian_ai/data/firebase_auth_context.dart';
import 'package:guardian_ai/data/web_filter_remote_service.dart';
import 'package:guardian_ai/data/web_filter_repository.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';

const _identity = AuthenticatedIdentity(
    uid: 'parent-1', email: 'parent@example.com', isAnonymous: false);

GuardianDatabase _testDatabase() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  return GuardianDatabase.forTesting(
      factory: factory,
      pathResolver: () async =>
          inMemoryDatabasePath); // fresh, isolated DB per test run
}

/// Inserts a real family row so the web_* tables' family_id FK is satisfied.
Future<void> _seedFamily(WebFilterRepository repository) async {
  await repository.database.database.then((db) => db.insert(
        'families',
        {
          'id': 'fam-1',
          'name': 'Test Family',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ));
}

void main() {
  group('FirestoreEventContract — FS-002 web operations (+incident ack)', () {
    const contract = FirestoreEventContract();

    test('web.hit maps to a real web_hits document with idempotency key', () {
      final mutation = contract.businessMutation(
        operation: 'web.hit',
        identity: _identity,
        idempotencyKey: 'web.hit:hit-7',
        payload: {
          'familyId': 'fam-1',
          'hitId': 'hit-7',
          'childId': 'child-2',
          'childDisplayName': 'Sara',
          'domain': 'bad-site.example',
          'category': 'adult',
          'blockedAt': '2026-08-18T10:00:00Z',
          'decision': 'blocked',
          'recordedAt': '2026-08-18T10:00:01Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_hits/hit-7');
      expect(mutation.idempotencyKey, 'web.hit:hit-7');
      expect(mutation.data['domain'], 'bad-site.example');
      expect(mutation.data['childId'], 'child-2');
      expect(mutation.data['decision'], 'blocked');
    });

    test('web.domain upserts a real web_domains document', () {
      final mutation = contract.businessMutation(
        operation: 'web.domain',
        identity: _identity,
        idempotencyKey: 'web.domain:dom-3',
        payload: {
          'familyId': 'fam-1',
          'domainId': 'dom-3',
          'domain': 'school.example',
          'kind': 'allow',
          'reason': 'School portal',
          'createdAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_domains/dom-3');
      expect(mutation.data['kind'], 'allow');
      expect(mutation.data['enabled'], true);
    });

    test('web.domain.removal stamps the server deletion marker', () {
      final mutation = contract.businessMutation(
        operation: 'web.domain.removal',
        identity: _identity,
        idempotencyKey: 'web.domain.removal:dom-3',
        payload: {
          'familyId': 'fam-1',
          'domainId': 'dom-3',
          'removedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_domains/dom-3');
      expect(mutation.data['removed'], true);
    });

    test('web.category upserts a real web_category_rules document', () {
      final mutation = contract.businessMutation(
        operation: 'web.category',
        identity: _identity,
        idempotencyKey: 'web.category:fam-1:child-2:gambling:1',
        payload: {
          'familyId': 'fam-1',
          'ruleId': 'child-2:gambling',
          'childId': 'child-2',
          'childDisplayName': 'Sara',
          'category': 'gambling',
          'enabled': false,
          'updatedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_category_rules/child-2:gambling');
      expect(mutation.data['enabled'], false);
    });

    test('incident.acknowledged merges the ack onto the real incidents document', () {
      final mutation = contract.businessMutation(
        operation: 'incident.acknowledged',
        identity: _identity,
        idempotencyKey: 'incident.acknowledged:fam-1:inc-1:1',
        payload: {
          'familyId': 'fam-1',
          'incidentId': 'inc-1',
          'acknowledgedAt': '2026-08-18T11:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/incidents/inc-1');
      expect(mutation.data['status'], 'acknowledged');
      expect(mutation.data['acknowledgedAtClient'], '2026-08-18T11:00:00Z');
    });

    test('web.setting writes a real web_settings document', () {
      final mutation = contract.businessMutation(
        operation: 'web.setting',
        identity: _identity,
        idempotencyKey: 'web.setting:fam-1:safe_search:1',
        payload: {
          'familyId': 'fam-1',
          'key': 'safe_search',
          'value': 'strict',
          'updatedAt': '2026-08-18T10:00:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_settings/safe_search');
      expect(mutation.data['value'], 'strict');
    });

    test('web.hit.overridden stamps the parent override without rewriting history', () {
      final mutation = contract.businessMutation(
        operation: 'web.hit.overridden',
        identity: _identity,
        idempotencyKey: 'web.hit.overridden:hit-7',
        payload: {
          'familyId': 'fam-1',
          'hitId': 'hit-7',
          'overriddenBy': 'parent-1',
          'overriddenAt': '2026-08-18T10:05:00Z',
        },
      );
      expect(mutation.path, 'families/fam-1/web_hits/hit-7');
      expect(mutation.data['overriddenBy'], 'parent-1');
      expect(mutation.data['domain'], isNull); // history stays intact
    });

    test('incomplete web payloads fail loudly instead of writing garbage', () {
      expect(
        () => contract.businessMutation(
            operation: 'web.hit',
            identity: _identity,
            idempotencyKey: 'web.hit:bad',
            payload: {'familyId': 'fam-1', 'domain': 'x.example'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => contract.businessMutation(
            operation: 'web.category',
            identity: _identity,
            idempotencyKey: 'k',
            payload: {'familyId': 'fam-1'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WebPolicySyncApplier — verified server facts merge honestly', () {
    late GuardianDatabase database;
    late WebFilterRepository repository;
    late WebPolicySyncApplier applier;

    setUp(() async {
      database = _testDatabase();
      repository = WebFilterRepository(database);
      applier = WebPolicySyncApplier(repository);
      await _seedFamily(repository);
    });

    test('applies new server hits, domains, rules and settings locally', () async {
      const policy = RemoteWebPolicy(
          path: 'families/fam-1/web_policy',
          familyId: 'fam-1',
          version: 1,
          updatedAtServer: null,
          idempotencyKey: 'key-1',
          hits: [
            RemoteWebHit(
                hitId: 'hit-9',
                childId: 'child-2',
                childDisplayName: 'Sara',
                domain: 'blocked.example',
                category: 'adult',
                blockedAt: '2026-08-18T10:00:00Z',
                decision: 'blocked'),
          ],
          domains: [
            RemoteWebDomain(
                domainId: 'dom-5',
                domain: 'allow.example',
                kind: 'allow',
                reason: 'School',
                enabled: true,
                removed: false),
          ],
          categoryRules: [
            RemoteWebCategoryRule(
                ruleId: 'child-2:gambling',
                childId: 'child-2',
                childDisplayName: 'Sara',
                category: 'gambling',
                enabled: false),
          ],
          settings: {'safe_search': 'strict'});

      final report = await applier.apply(policy);
      expect(report.appliedHits, 1);
      expect(report.appliedDomains, 1);
      expect(report.appliedRules, 1);

      final hits = await repository.hitsForFamily('fam-1');
      expect(hits.any((h) => h.id == 'hit-9'), true);

      final domains = await repository.domainsForFamily('fam-1');
      expect(domains.any((d) => d.id == 'dom-5'), true);
    });

    test('server removals delete the local row so stale domains never appear', () async {
      final entry = await repository.addDomain(
          familyId: 'fam-1',
          domain: 'gone.example',
          kind: 'block',
          reason: 'Test');
      // Server-side removal marker pointed at the exact row we just created.
      final removalPolicy = RemoteWebPolicy(
          path: 'families/fam-1/web_policy',
          familyId: 'fam-1',
          version: 2,
          updatedAtServer: null,
          idempotencyKey: 'key-2',
          hits: const [],
          domains: [
            RemoteWebDomain(
                domainId: entry.id,
                domain: entry.domain,
                kind: 'block',
                reason: null,
                enabled: false,
                removed: true),
          ],
          categoryRules: const [],
          settings: const {});

      await applier.apply(removalPolicy);
      final domains = await repository.domainsForFamily('fam-1');
      expect(domains.any((d) => d.id == entry.id), false);
    });
  });

  group('WebPullService — a failed remote read never pretends success', () {
    test('read failure surfaces an honest reason', () async {
      final database = _testDatabase();
      final repository = WebFilterRepository(database);
      final service = WebFilterPullService(
          const _FailingReader(), WebPolicySyncApplier(repository));
      await _seedFamily(repository);
      final result = await service.pull('fam-1');
      expect(result.success, false);
      expect(result.applied, false);
      expect(result.reason, contains('remote_read_failed'));
    });
  });
}

class _FailingReader implements WebPolicyRemoteReader {
  const _FailingReader();
  @override
  Future<RemoteWebPolicy?> readWebPolicy({required String familyId}) =>
      Future<RemoteWebPolicy?>.error(Exception('network_unavailable'));
}
