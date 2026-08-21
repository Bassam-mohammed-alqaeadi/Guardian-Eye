import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/audio_monitoring.dart';
import '../domain/guardian_models.dart';
import '../data/audio_repository.dart';
import 'family_context_provider.dart';
import '../core/database/guardian_database.dart';

/// FS-008 — One-Way Audio Monitor Service.
/// 
/// Manages the lifecycle of live audio sessions, including consent gates,
/// duration caps, and session history.
class AudioMonitorService {
  AudioMonitorService({
    required this.repository,
    required this.familyId,
    required this.actor,
  });

  final AudioRepository repository;
  final String familyId;
  final FamilyMember actor;

  StreamController<AudioSession?>? _sessionController;
  Timer? _durationTimer;
  AudioSession? _activeSession;

  Stream<AudioSession?> get activeSessionStream {
    _sessionController ??= StreamController<AudioSession?>.broadcast();
    return _sessionController!.stream;
  }

  AudioSession? get activeSession => _activeSession;

  Future<AudioSession> startSession({
    required String childMemberId,
    required String deviceId,
    AudioPrivacyClass privacyClass = AudioPrivacyClass.ephemeral,
  }) async {
    if (_activeSession != null) {
      throw StateError('audio_session_already_active');
    }

    final policy = await repository.getPolicy(familyId);
    if (!policy.enabled) {
      throw StateError('audio_monitoring_disabled_by_policy');
    }

    // Create session record
    final session = AudioSession(
      id: 'au-${DateTime.now().millisecondsSinceEpoch}',
      familyId: familyId,
      memberId: childMemberId,
      deviceId: deviceId,
      status: AudioSessionStatus.connecting,
      privacyClass: privacyClass,
      startedAt: DateTime.now().toUtc(),
    );

    _activeSession = session;
    await repository.saveSession(session);
    _notify();

    // Simulate connection delay
    await Future.delayed(const Duration(seconds: 2));

    if (_activeSession?.id == session.id) {
      final active = session.copyWith(status: AudioSessionStatus.active);
      _activeSession = active;
      await repository.saveSession(active);
      _notify();

      // Start duration cap timer
      _durationTimer = Timer(Duration(minutes: policy.maxDurationMinutes), () {
        stopSession(reason: AudioSessionStatus.timedOut);
      });
    }

    return _activeSession!;
  }

  Future<void> stopSession({AudioSessionStatus reason = AudioSessionStatus.completed}) async {
    if (_activeSession == null) return;

    _durationTimer?.cancel();
    _durationTimer = null;

    final endedAt = DateTime.now().toUtc();
    final duration = endedAt.difference(_activeSession!.startedAt).inSeconds;

    final completed = _activeSession!.copyWith(
      status: reason,
      endedAt: endedAt,
      durationSeconds: duration,
    );

    await repository.saveSession(completed);
    _activeSession = null;
    _notify();
  }

  void _notify() {
    _sessionController?.add(_activeSession);
  }

  void dispose() {
    _durationTimer?.cancel();
    _sessionController?.close();
  }
}

extension on AudioSession {
  AudioSession copyWith({
    AudioSessionStatus? status,
    DateTime? endedAt,
    int? durationSeconds,
    String? notes,
  }) =>
      AudioSession(
        id: id,
        familyId: familyId,
        memberId: memberId,
        deviceId: deviceId,
        status: status ?? this.status,
        privacyClass: privacyClass,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        notes: notes ?? this.notes,
        syncState: syncState,
      );
}

final audioRepositoryProvider = Provider((ref) => AudioRepository(GuardianDatabase.instance));

final audioPolicyProvider = FutureProvider.family<AudioPolicy, String>(
    (ref, String familyId) => ref.watch(audioRepositoryProvider).getPolicy(familyId));

final audioHistoryProvider = FutureProvider.family<List<AudioSession>, String>(
    (ref, String familyId) => ref.watch(audioRepositoryProvider).getSessions(familyId));

final audioKeywordsProvider = FutureProvider.family<List<AudioKeyword>, String>(
    (ref, String familyId) => ref.watch(audioRepositoryProvider).getKeywords(familyId));

final audioMonitorServiceProvider = Provider.family<AudioMonitorService, String>((ref, familyId) {
  final ctx = ref.watch(familyRuntimeContextProvider(familyId)).value;
  if (ctx == null || ctx.actor == null) throw StateError('family_context_unavailable');
  
  final service = AudioMonitorService(
    repository: ref.watch(audioRepositoryProvider),
    familyId: familyId,
    actor: ctx.actor!,
  );
  
  ref.onDispose(() => service.dispose());
  return service;
});

final activeAudioSessionProvider = StreamProvider.family<AudioSession?, String>(
    (ref, familyId) => ref.watch(audioMonitorServiceProvider(familyId)).activeSessionStream);
