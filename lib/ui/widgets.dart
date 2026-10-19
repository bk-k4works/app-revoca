import '../services/content_speech_service.dart';
import 'package:flutter/material.dart';
import '../domain/vocabulary.dart';
import '../services/speech_service.dart';
import 'focus_theme.dart';

class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.children, this.padding = 24});
  final List<Widget> children;
  final double padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
        children: children,
      ),
    ),
  );
}

class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.color,
    this.padding = 20,
  });
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) {
    final colors = FocusColors.of(context);
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color == null ? colors.line : Colors.transparent,
        ),
      ),
      child: child,
    );
  }
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: color ?? FocusColors.of(context).muted,
      height: 1.5,
    ),
  );
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Icon(icon, size: 21),
          ],
        ),
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        ?action,
      ],
    ),
  );
}

class SpeechButton extends StatefulWidget {
  const SpeechButton({
    super.key,
    required this.speech,
    required this.text,
    this.label = '발음 듣기',
    this.language = 'en-US',
    this.senseId,
    this.kind = 'word',
  });
  final SpeechService speech;
  final String text, label, language;
  final String? senseId;
  final String kind;
  @override
  State<SpeechButton> createState() => _SpeechButtonState();
}

class _SpeechButtonState extends State<SpeechButton> {
  bool _playing = false;
  Future<void> _play() async {
    if (_playing) {
      await widget.speech.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await widget.speech.stop();
      await speakContent(
        widget.speech,
        widget.text,
        language: widget.language,
        senseId: widget.senseId,
        kind: widget.kind,
      );
    } catch (_) {
      if (mounted) {
        showNotice(context, '음성을 재생할 수 없어요. 기기에 영어 음성이 설치되어 있는지 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _play,
    icon: Icon(
      _playing ? Icons.stop_rounded : Icons.volume_up_outlined,
      size: 20,
    ),
    label: Text(_playing ? '듣기 멈추기' : widget.label),
  );
}

void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Part of speech, plus the sense's place among its headword's meanings.
String senseLabel(Sense word, List<Sense> senses) {
  final index = senses.indexWhere((s) => s.id == word.id);
  return senses.length > 1 && index >= 0
      ? '${word.partOfSpeech} · 뜻 ${senses.length}개 중 ${index + 1}번째'
      : word.partOfSpeech;
}

/// The headword's other meanings, so a sense is never learned in isolation.
class OtherSenses extends StatelessWidget {
  const OtherSenses({super.key, required this.word, required this.senses});
  final Sense word;
  final List<Sense> senses;
  @override
  Widget build(BuildContext context) {
    final others = senses.where((s) => s.id != word.id).toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: const Key('other-senses'),
      tilePadding: EdgeInsets.zero,
      title: Text('이 단어의 다른 뜻 ${others.length}개'),
      children: [
        for (final other in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (other.term != word.term) other.term,
                  other.partOfSpeech,
                  other.meaning,
                ].join(' · '),
              ),
            ),
          ),
      ],
    );
  }
}
