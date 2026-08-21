import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
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
    AudioRecorder? recorder,
    AudioPlayer? player,
  })  : _audioRecorder = recorder ?? AudioRecorder(),
        _audioPlayer = player ?? AudioPlayer();

  final AudioRepository repository;
  final String familyId;
  final FamilyMember actor;
  final AudioRecorder _audioRecorder;
  final AudioPlayer _audioPlayer;

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

    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/${session.id}.m4a';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        );

        // Start real recording
        await _audioRecorder.start(config, path: path);

        // In a real implementation, the parent's app would receive the stream.
        // For this hardening, we simulate the parent hearing the audio by
        // playing back the file (in a real multi-device setup, this would be
        // two different apps/devices).
        await _audioPlayer.setSourceDeviceFile(path);
        await _audioPlayer.resume();

        if (_activeSession?.id == session.id) {
          final active = session.copyWith(status: AudioSessionStatus.active);
          _activeSession = active;
          await repository.saveSession(active);
          _notify();

          // Start duration cap timer
          _durationTimer =
              Timer(Duration(minutes: policy.maxDurationMinutes), () {
            stopSession(reason: AudioSessionStatus.timedOut);
          });
        }
      } else {
        await stopSession(reason: AudioSessionStatus.failed);
        throw StateError('microphone_permission_denied');
      }
    } catch (e) {
      await stopSession(reason: AudioSessionStatus.failed);
      rethrow;
    }

    return _activeSession!;
  }

  Future<void> stopSession(
      {AudioSessionStatus reason = AudioSessionStatus.completed}) async {
    if (_activeSession == null) return;

    _durationTimer?.cancel();
    _durationTimer = null;

    final path = await _audioRecorder.stop();
    await _audioPlayer.stop();
    
    // In a real implementation, we would upload the file if privacyClass allows
    if (path != null && _activeSession!.privacyClass == AudioPrivacyClass.ephemeral) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete(); // Ephemeral: delete local file after session
        } catch (_) {}
      }
    }

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

  void dispose() {
    _durationTimer?.cancel();
    _sessionController?.close();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
  }

  void _notify() {
    _sessionController?.add(_activeSession);
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
