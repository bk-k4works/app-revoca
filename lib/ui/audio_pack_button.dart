import 'package:flutter/material.dart';
import '../services/content_speech_service.dart';
import '../services/speech_service.dart';

class AudioPackButton extends StatefulWidget {
  const AudioPackButton({
    super.key,
    required this.speech,
    required this.deckId,
  });
  final SpeechService speech;
  final String deckId;
  @override
  State<AudioPackButton> createState() => _AudioPackButtonState();
}

class _AudioPackButtonState extends State<AudioPackButton> {
  bool _ready = false, _busy = false;
  String? _error;
  ContentSpeechService? get _service => widget.speech is ContentSpeechService
      ? widget.speech as ContentSpeechService
      : null;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final ready = await _service?.packs.isPackReady(widget.deckId) ?? false;
      if (mounted) setState(() => _ready = ready);
    } catch (_) {
      /* Missing/corrupt assets remain downloadable. */
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service!.packs.download(widget.deckId);
      await _check();
    } catch (_) {
      if (mounted) setState(() => _error = '다운로드하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pack = _service?.packs.packs
        .where((p) => p.id == widget.deckId)
        .firstOrNull;
    if (pack == null) return const SizedBox.shrink();
    return Column(
      children: [
        TextButton.icon(
          onPressed: _ready || _busy || pack.url == null ? null : _download,
          icon: Icon(
            _ready ? Icons.offline_pin_outlined : Icons.download_rounded,
          ),
          label: Text(
            _ready
                ? '오프라인 음성 준비 완료'
                : _busy
                ? '음성 다운로드 중…'
                : pack.url == null
                ? '음성 팩 준비 중 · 기기 음성으로 듣기'
                : '음성 다운로드 (${(pack.bytes / 1024 / 1024).toStringAsFixed(1)} MB)',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
