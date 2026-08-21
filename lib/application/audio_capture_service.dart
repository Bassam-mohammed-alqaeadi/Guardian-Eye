import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../domain/audio_monitoring.dart';
import 'guardian_providers.dart';

/// FS-008 — Audio Capture Service (Child-side).
/// 
/// Listens for audio session events from the backend (FCM/Firestore)
/// and manages local microphone capture and notifications.
class AudioCaptureService {
  AudioCaptureService(this._ref);
  final Ref _ref;
  
  final _recorder = AudioRecorder();
  final _notifications = FlutterLocalNotificationsPlugin();
  
  bool _isMonitoring = false;
  
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, ios: ios),
    );
  }

  /// Called when a 'start_audio' command is received via FCM.
  Future<void> onStartCommandReceived(String familyId, String sessionId) async {
    if (_isMonitoring) return;
    
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    _isMonitoring = true;
    
    // 1. Show persistent notification (Transparency & Honest State)
    await _showActiveNotification();
    
    // 2. Start recording
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/$sessionId.m4a';
    
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    
    // 3. In a real app, we would stream the bytes to a secure socket or WebRTC.
    // For this implementation, we simulate the active capture.
  }

  /// Called when a 'stop_audio' command is received via FCM or local timeout.
  Future<void> onStopCommandReceived() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    await _recorder.stop();
    await _notifications.cancel(808); // AU-008 notification ID
  }

  Future<void> _showActiveNotification() async {
    // Note: In a real app, we'd use localized strings from a context-less source
    // or pass them in the command. Here we use placeholders.
    const android = AndroidNotificationDetails(
      'audio_monitoring',
      'Audio Monitoring',
      channelDescription: 'Active live audio monitoring sessions',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      icon: '@mipmap/ic_launcher',
    );
    
    await _notifications.show(
      808,
      'Audio Monitoring Active',
      'The device surroundings are being monitored by parents.',
      const NotificationDetails(android: android),
    );
  }
}

final audioCaptureServiceProvider = Provider((ref) => AudioCaptureService(ref));
