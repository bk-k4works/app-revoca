import '../services/content_speech_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/vocabulary.dart';
import '../services/speech_service.dart';
import 'focus_theme.dart';
import 'widgets.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({
    super.key,
    required this.deck,
    required this.vocabulary,
    required this.speech,
  });
  final WordDeck deck;
  final Vocabulary vocabulary;
  final SpeechService speech;
  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen>
    with WidgetsBindingObserver {
  int _index = 0, _generation = 0, _repeat = 1;
  bool _playing = false, _meaning = true, _example = true, _completed = false;
  double _rate = 0.45;
  String _part = '준비되면 재생을 눌러주세요';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    _generation++;
    unawaited(widget.speech.stop());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _stop() async {
    _generation++;
    if (mounted) {
      setState(() {
        _playing = false;
        _part = '잠시 쉬어가요';
      });
    }
    await widget.speech.stop();
  }

  Future<void> _play() async {
    if (_playing) {
      await _stop();
      return;
    }
    if (widget.deck.wordIds.isEmpty) return;
    final token = ++_generation;
    setState(() {
      _playing = true;
      if (_completed) _index = 0;
      _completed = false;
    });
    bool active() => mounted && token == _generation;
    Future<void> say(
      String text,
      String label,
      String language,
      String senseId,
      String kind,
    ) async {
      if (!active()) return;
      setState(() => _part = label);
      await speakContent(
        widget.speech,
        text,
        language: language,
        rate: _rate,
        senseId: senseId,
        kind: kind,
      );
    }

    try {
      await widget.vocabulary.ensureDetails(widget.deck.wordIds);
      if (!active()) return;
      for (var i = _index; i < widget.deck.wordIds.length && active(); i++) {
        final word = widget.vocabulary.byId[widget.deck.wordIds[i]]!;
        setState(() => _index = i);
        for (var repeat = 0; repeat < _repeat && active(); repeat++) {
          await say(word.term, '단어를 듣고 있어요', 'en-US', word.id, 'word');
          if (!active()) return;
          setState(() => _part = '뜻을 떠올려 보세요');
          await Future<void>.delayed(const Duration(milliseconds: 900));
          if (!active()) return;
          if (_meaning) {
            await say(word.meaning, '뜻을 듣고 있어요', 'ko-KR', word.id, 'meaning');
          }
          if (!active()) return;
          if (_example) {
            await say(word.example, '예문을 듣고 있어요', 'en-US', word.id, 'example');
          }
          if (!active()) return;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (active()) {
        setState(() {
          _playing = false;
          _completed = true;
          _part = '단어장을 끝까지 들었어요';
        });
      }
    } catch (_) {
      if (mounted && token == _generation) {
        setState(() {
          _playing = false;
          _part = '음성을 재생하지 못했어요';
        });
        showNotice(context, '기기에 영어·한국어 음성이 설치되어 있는지 확인해 주세요.');
      }
    }
  }

  Future<void> _move(int offset) async {
    await _stop();
    if (mounted) {
      setState(() {
        _index = (_index + offset).clamp(0, widget.deck.wordIds.length - 1);
        _completed = false;
        _part = '준비되면 재생을 눌러주세요';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deck.wordIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('단어장 듣기')),
        body: const Center(child: Text('먼저 단어를 담아주세요.')),
      );
    }
    final word = widget.vocabulary.byId[widget.deck.wordIds[_index]]!;
    final c = FocusColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('귀로 한 번 더')),
      body: SafeArea(
        top: false,
        child: PageContent(
          children: [
            Caption(widget.deck.title),
            const SizedBox(height: 20),
            PaperCard(
              color: c.soft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Caption(
                          '${_index + 1} / ${widget.deck.wordIds.length}',
                        ),
                      ),
                      const Icon(Icons.graphic_eq_rounded, size: 28),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    word.term,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    word.meaning,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(word.example),
                  const SizedBox(height: 8),
                  Caption(word.exampleMeaning),
                  const SizedBox(height: 26),
                  Semantics(liveRegion: true, child: Caption(_part)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 단어',
                  onPressed: _index == 0 ? null : () => _move(-1),
                  icon: const Icon(Icons.skip_previous_rounded, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _play,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _playing
                          ? '일시정지'
                          : _completed
                          ? '다시 듣기'
                          : '재생하기',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: '다음 단어',
                  onPressed: _index == widget.deck.wordIds.length - 1
                      ? null
                      : () => _move(1),
                  icon: const Icon(Icons.skip_next_rounded, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const SectionHeading('나에게 맞게 듣기'),
            Row(
              children: [
                const Expanded(child: Text('읽는 속도')),
                Text(
                  _rate < 0.4
                      ? '천천히'
                      : _rate > 0.5
                      ? '빠르게'
                      : '보통',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Slider(
              value: _rate,
              min: 0.3,
              max: 0.6,
              divisions: 6,
              label: '읽는 속도',
              onChanged: _playing
                  ? null
                  : (value) => setState(() => _rate = value),
            ),
            Row(
              children: [
                const Expanded(child: Text('단어마다 반복')),
                DropdownButton<int>(
                  value: _repeat,
                  items: [1, 2, 3]
                      .map(
                        (v) => DropdownMenuItem(value: v, child: Text('$v번')),
                      )
                      .toList(),
                  onChanged: _playing
                      ? null
                      : (value) => setState(() => _repeat = value!),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('한국어 뜻 듣기'),
              value: _meaning,
              onChanged: _playing
                  ? null
                  : (value) => setState(() => _meaning = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('영어 예문 듣기'),
              value: _example,
              onChanged: _playing
                  ? null
                  : (value) => setState(() => _example = value),
            ),
            const SizedBox(height: 16),
            const Caption(
              '기기 음성으로 읽어요. 이 화면을 나가거나 앱을 닫으면 멈춰요. 듣기는 암기 성취도에 포함하지 않아요.',
            ),
          ],
        ),
      ),
    );
  }
}
