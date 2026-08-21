import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:guardian_ai/domain/audio_monitoring.dart';
import 'package:guardian_ai/domain/guardian_models.dart';
import 'package:guardian_ai/domain/family_authorization.dart';
import 'package:guardian_ai/data/audio_repository.dart';
import 'package:guardian_ai/application/audio_monitor_service.dart';
import 'package:guardian_ai/application/family_context_provider.dart';
import 'package:guardian_ai/core/database/guardian_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'fs008_audio_mocks.dart';

void main() {
  setupAudioMocks();
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late AudioRepository repository;
  late GuardianDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = GuardianDatabase.forTesting(
      factory: databaseFactoryFfi,
      pathResolver: () async => ':memory:',
    );
    await database.initialize(); // Initialize
    final db = await database.database;
    repository = AudioRepository(database);

    // Seed required tables to satisfy FOREIGN KEY constraints
    final familyId = 'fam-1';
    await db.insert('families', {
      'id': familyId,
      'name': 'Test Family',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final actor = FamilyMember(
      id: 'parent-1',
      familyId: familyId,
      displayName: 'Parent',
      role: FamilyRole.primaryParent,
      status: FamilyMemberStatus.active,
      joinedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await db.insert('family_members', {
      'id': actor.id,
      'family_id': actor.familyId,
      'display_name': actor.displayName,
      'role': actor.role.name,
      'status': actor.status.name,
      'joined_at': actor.joinedAt?.toIso8601String(),
      'created_at': actor.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Seed child and device for session tests
    await db.insert('family_members', {
      'id': 'child-1',
      'family_id': familyId,
      'display_name': 'Child',
      'role': 'child',
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('devices', {
      'id': 'dev-1',
      'family_id': familyId,
      'member_id': 'child-1',
      'role': 'child',
      'sync_state': 'synced',
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    container = ProviderContainer(
      overrides: [
        audioRepositoryProvider.overrideWithValue(repository),
        familyRuntimeContextProvider('fam-1').overrideWith((ref) => FamilyRuntimeContext(
          familyId: 'fam-1',
          family: null,
          actor: actor,
          isVerified: true,
          permissionsFor: const FamilyAuthorization().permissionsFor,
          allMembers: [actor],
          children: [],
          devices: [],
        )),
      ],
    );

    // Mock PathProvider to avoid MissingPluginException
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
  });

  tearDown(() {
    container.dispose();
  });

  group('FS-008 Audio Monitoring Domain & Logic', () {
    test('Default policy is disabled', () async {
      final policy = await repository.getPolicy('fam-1');
      expect(policy.enabled, isFalse);
      expect(policy.maxDurationMinutes, 5);
    });

    test('Policy persistence', () async {
      final policy = AudioPolicy(
        familyId: 'fam-1',
        enabled: true,
        maxDurationMinutes: 10,
        wifiOnly: true,
      );
      await repository.savePolicy(policy);
      
      final saved = await repository.getPolicy('fam-1');
      expect(saved.enabled, isTrue);
      expect(saved.maxDurationMinutes, 10);
      expect(saved.wifiOnly, isTrue);
    });

    test('Session recording and history', () async {
      final session = AudioSession(
        id: 'au-1',
        familyId: 'fam-1',
        memberId: 'child-1',
        deviceId: 'dev-1',
        status: AudioSessionStatus.active,
        privacyClass: AudioPrivacyClass.ephemeral,
        startedAt: DateTime.now(),
      );
      
      await repository.saveSession(session);
      final history = await repository.getSessions('fam-1');
      
      expect(history.length, 1);
      expect(history.first.id, 'au-1');
      expect(history.first.status, AudioSessionStatus.active);
    });

    test('Keyword management', () async {
      final keyword = AudioKeyword(
        id: 'kw-1',
        familyId: 'fam-1',
        phrase: 'help',
        enabled: true,
        createdAt: DateTime.now(),
      );
      
      await repository.saveKeyword(keyword);
      final keywords = await repository.getKeywords('fam-1');
      
      expect(keywords.length, 1);
      expect(keywords.first.phrase, 'help');
      
      await repository.deleteKeyword('kw-1');
      final afterDelete = await repository.getKeywords('fam-1');
      expect(afterDelete.isEmpty, isTrue);
    });
  });

  group('FS-008 Audio Monitoring Service Hardening', () {
    test('startSession verifies policy before recording', () async {
      final actor = FamilyMember(
        id: 'parent-1',
        familyId: 'fam-1',
        displayName: 'Parent',
        role: FamilyRole.primaryParent,
        status: FamilyMemberStatus.active,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      
      final mockRecorder = MockAudioRecorder();
      final mockPlayer = MockAudioPlayer();
      
      // Ensure policy is disabled in DB
      await repository.savePolicy(AudioPolicy(familyId: 'fam-1', enabled: false));

      final service = AudioMonitorService(
        repository: repository,
        familyId: 'fam-1',
        actor: actor,
        recorder: mockRecorder,
        player: mockPlayer,
      );

      // Policy is disabled, should throw before any plugin calls
      expect(
        service.startSession(childMemberId: 'child-1', deviceId: 'dev-1'),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'audio_monitoring_disabled_by_policy')),
      );
      
      // Verify no plugin methods were called
      verifyNever(() => mockRecorder.hasPermission());
    });

    test('Session lifecycle updates repository status with mocks', () async {
      final actor = FamilyMember(
        id: 'parent-1',
        familyId: 'fam-1',
        displayName: 'Parent',
        role: FamilyRole.primaryParent,
        status: FamilyMemberStatus.active,
        joinedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      
      await repository.savePolicy(AudioPolicy(
        familyId: 'fam-1',
        enabled: true,
      ));

      final mockRecorder = MockAudioRecorder();
      final mockPlayer = MockAudioPlayer();
      
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRecorder.start(any(), path: any(named: 'path'))).thenAnswer((_) async {});
      when(() => mockRecorder.stop()).thenAnswer((_) async => 'test.m4a');
      when(() => mockPlayer.setSourceDeviceFile(any())).thenAnswer((_) async {});
      when(() => mockPlayer.resume()).thenAnswer((_) async {});
      when(() => mockPlayer.stop()).thenAnswer((_) async {});
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      final service = AudioMonitorService(
        repository: repository,
        familyId: 'fam-1',
        actor: actor,
        recorder: mockRecorder,
        player: mockPlayer,
      );

      final session = await service.startSession(childMemberId: 'child-1', deviceId: 'dev-1');
      expect(session.status, AudioSessionStatus.active);
      
      final saved = await repository.getSessions('fam-1');
      expect(saved.first.status, AudioSessionStatus.active);
      
      await service.stopSession();
      final ended = await repository.getSessions('fam-1');
      expect(ended.first.status, AudioSessionStatus.completed);
      expect(ended.first.endedAt, isNotNull);
    });
  });
}
