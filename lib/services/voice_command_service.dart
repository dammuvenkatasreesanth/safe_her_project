import 'dart:async';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'settings_service.dart';

/// Module 6/Accessibility — "Voice Command": listens on-device for "help
/// me" or "emergency" and fires the registered trigger (SOS) when heard.
///
/// Foreground only. The OS speech recognizer session is short-lived (tens
/// of seconds), so this keeps re-arming it in a loop for as long as the
/// setting is on and something has registered a trigger callback — there
/// is no background service, so this only listens while the app is open.
class VoiceCommandService {
  VoiceCommandService._();

  static final _speech = SpeechToText();
  static bool _running = false;
  static bool _initialized = false;
  static VoidCallback? _onTrigger;

  static const _keywords = ['help me', 'emergency'];

  /// Registers the callback fired when a trigger phrase is heard (SOS
  /// screen navigation, normally set once from HomeScreen). Call with
  /// `null` to unregister when the host widget is disposed.
  static void registerTrigger(VoidCallback? onTrigger) {
    _onTrigger = onTrigger;
  }

  /// Starts or stops listening to match the persisted setting. Safe to
  /// call repeatedly (e.g. every time the host widget resumes). Returns
  /// false only when the setting is on but starting actually failed (e.g.
  /// microphone permission denied) — callers use that to reflect the real
  /// state back to the toggle instead of showing it as on when it isn't.
  static Future<bool> syncWithSetting() async {
    final enabled = await SettingsService.getVoiceCommand();
    if (enabled) {
      return start();
    }
    await stop();
    return true;
  }

  static Future<bool> start() async {
    if (_running) return true;
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return false;
    }
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: (_) {}, // transient errors just let the restart loop retry
      );
      if (!_initialized) return false;
    }
    _running = true;
    await _listenOnce();
    return true;
  }

  static Future<void> stop() async {
    _running = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static Future<void> _listenOnce() async {
    if (!_running) return;
    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 8),
      ),
    );
  }

  static void _onResult(SpeechRecognitionResult result) {
    final heard = result.recognizedWords.toLowerCase();
    if (_keywords.any(heard.contains)) {
      _onTrigger?.call();
    }
  }

  static void _onStatus(String status) {
    // Re-arm listening once the current session ends, as long as the
    // feature is still supposed to be on — the platform recognizer only
    // listens for a limited window at a time.
    if (!_running) return;
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      Future.delayed(const Duration(milliseconds: 500), _listenOnce);
    }
  }
}
