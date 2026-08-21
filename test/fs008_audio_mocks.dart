import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}
class MockAudioPlayer extends Mock implements AudioPlayer {}

void setupAudioMocks() {
  registerFallbackValue(const RecordConfig());
  registerFallbackValue(AssetSource(''));
}

void main() {}
