import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isMuted = false;
  bool _isInitialized = false;

  bool get isMuted => _isMuted;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      if (kIsWeb) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {

        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // Configure for Arabic
      await _flutterTts.setLanguage("ar-SA");
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for better clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TtsService] Error initializing TTS: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  void setMute(bool mute) {
    _isMuted = mute;
    if (_isMuted) {
      stop();
    }
  }

  Future<void> speak(String text) async {
    if (_isMuted || !_isInitialized || text.isEmpty) return;

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Error speaking: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('[TtsService] Error stopping TTS: $e');
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
