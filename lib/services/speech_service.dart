import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class SpeechService {
  Future<void> speak(
    String text, {
    String language = 'en-US',
    double rate = 0.45,
  });
  Future<void> stop();
}

class DeviceSpeechService implements SpeechService {
  final FlutterTts _tts = FlutterTts();
  Future<void>? _initialization;
  Completer<void>? _cancellation;
  int _generation = 0;

  Future<void> _initialize() async {
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'en-US',
    double rate = 0.45,
  }) async {
    final generation = ++_generation;
    await _stopCurrent();
    if (generation != _generation) return;
    final cancellation = Completer<void>();
    _cancellation = cancellation;
    try {
      await (_initialization ??= _initialize());
      if (generation != _generation) return;
      if (await _tts.isLanguageAvailable(language) != true) {
        throw StateError('요청한 언어의 음성이 기기에 없어요.');
      }
      if (generation != _generation) return;
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(rate);
      if (generation != _generation) return;
      final result = await Future.any<Object?>([
        _tts.speak(text),
        cancellation.future.then<Object?>((_) => null),
      ]).timeout(const Duration(seconds: 45));
      if (generation != _generation) return;
      if (result != 1) throw StateError('음성을 재생하지 못했어요.');
    } catch (_) {
      if (generation == _generation) await stop();
      rethrow;
    } finally {
      if (identical(_cancellation, cancellation)) _cancellation = null;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final cancellation = _cancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    _cancellation = null;
    try {
      await _tts.stop();
    } catch (_) {
      /* Cleanup is safe before engine initialization. */
    }
  }
}
