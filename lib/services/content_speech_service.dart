import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../domain/audio_asset.dart';
import 'audio_pack_service.dart';
import 'speech_service.dart';

abstract interface class RecordedAudioPlayer {
  Future<void> play(String file, double rate);
  Future<void> stop();
}

class LocalAudioPlayer implements RecordedAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _completion;
  int _generation = 0;

  @override
  Future<void> play(String file, double rate) async {
    final generation = ++_generation;
    await _stopCurrent();
    if (generation != _generation) return;
    final completion = Completer<void>();
    _completion = completion;
    final subscription = _player.onPlayerComplete.listen(
      (_) {
        if (!completion.isCompleted) completion.complete();
      },
      onError: (Object error) {
        if (!completion.isCompleted) completion.completeError(error);
      },
    );
    try {
      await _player.setPlaybackRate((rate / .45).clamp(.5, 2.0));
      if (generation != _generation) return;
      await _player.play(DeviceFileSource(file));
      if (generation != _generation) {
        await _player.stop();
        return;
      }
      await completion.future.timeout(const Duration(seconds: 90));
    } finally {
      await subscription.cancel();
      if (identical(_completion, completion)) _completion = null;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _stopCurrent();
  }

  Future<void> _stopCurrent() async {
    final pending = _completion;
    _completion = null;
    if (pending != null && !pending.isCompleted) pending.complete();
    await _player.stop();
  }
}

class ContentSpeechService implements SpeechService {
  ContentSpeechService({
    required this.packs,
    required this.fallback,
    required this.player,
  });
  final AudioPackService packs;
  final SpeechService fallback;
  final RecordedAudioPlayer player;
  int _generation = 0;

  Future<void> _stopPlayers() async {
    // A broken/unavailable file player must not prevent the device-TTS fallback.
    await Future.wait([
      player.stop().catchError((Object _) {}),
      fallback.stop(),
    ]);
  }

  Future<void> speakSense(
    String senseId,
    String kind,
    String text, {
    String language = 'en-US',
    double rate = .45,
  }) async {
    final generation = ++_generation;
    await _stopPlayers();
    if (generation != _generation) return;
    final AudioAsset? asset = packs.assets
        .where(
          (a) =>
              a.senseId == senseId &&
              a.kind == kind &&
              a.text == text &&
              a.language == language,
        )
        .firstOrNull;
    if (asset != null) {
      try {
        final local = await packs.localPath(asset);
        if (generation != _generation) return;
        if (local != null) {
          await player.play(local, rate);
          return;
        }
      } catch (_) {
        if (generation != _generation) return;
        await player.stop().catchError((Object _) {});
      }
    }
    if (generation == _generation) {
      await fallback.speak(text, language: language, rate: rate);
    }
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'en-US',
    double rate = .45,
  }) async {
    final generation = ++_generation;
    await _stopPlayers();
    if (generation == _generation) {
      await fallback.speak(text, language: language, rate: rate);
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _stopPlayers();
  }
}

Future<void> speakContent(
  SpeechService service,
  String text, {
  String? senseId,
  String kind = 'word',
  String language = 'en-US',
  double rate = .45,
}) => service is ContentSpeechService && senseId != null
    ? service.speakSense(senseId, kind, text, language: language, rate: rate)
    : service.speak(text, language: language, rate: rate);
