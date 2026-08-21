import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
    const darwin = DarwinInitializationSettings();
    await _notifications.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
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
    
    // 2. Start recording and streaming
    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('unauthenticated');
      final token = await user.getIdToken();

      final uploadUrl = 'https://guardian-backend.onrender.com/api/audio/upload/$sessionId';

      // 3. Pipe stream to Render Relay
      stream.listen((data) async {
        if (!_isMonitoring) return;
        try {
          await http.post(
            Uri.parse(uploadUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'audio/aac',
            },
            body: data,
          );
        } catch (e) {
          // In production, we would handle retry or failure signaling.
        }
      });

      // 4. Update Signaling Status in Firestore
      await FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('audio_sessions')
          .doc(sessionId)
          .update({
        'status': 'active',
        'startedAt': FieldValue.serverTimestamp(),
        'consentStatus': 'granted',
      });
    } catch (e) {
      await onStopCommandReceived();
      rethrow;
    }
  }

  /// Called when a 'stop_audio' command is received via FCM or local timeout.
  Future<void> onStopCommandReceived() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    await _recorder.stop();
    await _notifications.cancel(id: 808); // AU-008 notification ID
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
      id: 808,
      title: 'Audio Monitoring Active',
      body: 'The device surroundings are being monitored by parents.',
      notificationDetails: NotificationDetails(android: android),
    );
  }
}

final audioCaptureServiceProvider = Provider((ref) => AudioCaptureService(ref));
