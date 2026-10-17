import 'package:flutter/material.dart';
import 'audio_pack_button.dart';
import '../application/learning_controller.dart';
import '../domain/vocabulary.dart';
import '../services/speech_service.dart';
import 'focus_theme.dart';
import 'listen_screen.dart';
import 'study_screen.dart';
import 'widgets.dart';

class DeckLibrary extends StatelessWidget {
  const DeckLibrary({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  Widget build(BuildContext context) => PageContent(
    children: [
      Text(
        '내 속도로,\n내 범위만큼.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Caption('한 번에 5개씩, 부담 없이 시작해요.'),
      const SizedBox(height: 28),
      SectionHeading(
        '단어장 컬렉션',
        action: IconButton(
          tooltip: '콘텐츠 안내',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('콘텐츠 안내'),
              content: Text(
                '${controller.vocabulary.words.map((w) => w.headword.id).toSet().length}개 단어 · ${controller.vocabulary.words.length}개 뜻과 예문으로 구성했어요.\n\n현재 검수 전 체험용 초안이며, 학교별 시험 범위나 교육과정 전체를 포함하지 않아요. 발음은 기기의 음성 기능을 사용해요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          ),
        ),
      ),
      ..._courseSections(context),
      const SizedBox(height: 16),
      const SectionHeading('내가 고른 단어'),
      DeckTile(
        deck: controller.examDeck,
        controller: controller,
        speech: speech,
        index: 3,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => editExamWords(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: const Text('시험 범위 고르기'),
      ),
    ],
  );

  // Content packages may describe courses; older packages show a flat list.
  List<Widget> _courseSections(BuildContext context) {
    final decks = controller.vocabulary.decks;
    final courses = controller.vocabulary.provenance['courses'];
    Widget tile(WordDeck deck) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DeckTile(
        deck: deck,
        controller: controller,
        speech: speech,
        index: decks.indexOf(deck),
      ),
    );
    if (courses is! List) return [for (final deck in decks) tile(deck)];
    return [
      for (final course in courses.cast<Map>())
        if (course['status'] == 'available') ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              course['title'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final tier in (course['tiers'] as List).cast<Map>()) ...[
            SectionHeading(
              tier['title'] as String,
              action: Caption(
                '${tier['authored']} / ${tier['planned']}${tier['unit'] ?? '단어'}',
              ),
            ),
            if (decks.any((d) => d.id.startsWith('hs-${tier['id']}-')))
              for (final deck in decks.where(
                (d) => d.id.startsWith('hs-${tier['id']}-'),
              ))
                tile(deck)
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: ComingSoonTile(label: '준비하고 있어요'),
              ),
          ],
        ] else ...[
          SectionHeading(course['title'] as String),
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: ComingSoonTile(label: '곧 만나요 · 준비 중'),
          ),
        ],
    ];
  }
}

class ComingSoonTile extends StatelessWidget {
  const ComingSoonTile({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final colors = FocusColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, size: 20, color: colors.muted),
            const SizedBox(width: 12),
            Expanded(child: Caption(label)),
          ],
        ),
      ),
    );
  }
}

class DeckTile extends StatelessWidget {
  const DeckTile({
    super.key,
    required this.deck,
    required this.controller,
    required this.speech,
    required this.index,
  });
  final WordDeck deck;
  final LearningController controller;
  final SpeechService speech;
  final int index;
  @override
  Widget build(BuildContext context) {
    final colors = FocusColors.of(context);
    final count = controller.practicedCount(deck.wordIds);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DeckScreen(deck: deck, controller: controller, speech: speech),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 56,
                height: 74,
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
                decoration: BoxDecoration(
                  color: [
                    const Color(0xFF304B7A),
                    const Color(0xFF9B684C),
                    const Color(0xFF556348),
                    const Color(0xFF292F27),
                  ][index % 4],
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(3),
                    right: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Text(
                        deck.id == 'my-exam'
                            ? 'MY\nWORDS'
                            : _badge(deck.id, index),
                        textScaler: TextScaler.noScaling,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const Text(
                      'VOCA',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Caption(_deckCaption(deck)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: deck.wordIds.isEmpty
                        ? 0
                        : count / deck.wordIds.length,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor: colors.line,
                    color: colors.ink,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

// Course decks already state word and meaning counts in their subtitle.
String _deckCaption(WordDeck deck) => deck.id.startsWith('hs-')
    ? deck.subtitle
    : '${deck.wordIds.length}개 카드 · ${deck.subtitle}';

String _badge(String deckId, int index) {
  final match = RegExp(r'^hs-(\w+)-0*(\d+)$').firstMatch(deckId);
  if (match == null) return 'DAY\n${(index + 1).toString().padLeft(2, '0')}';
  final tier = {
    'basic': 'BASIC',
    'familiar': 'PLUS',
    'core': 'CORE',
    'phrase': 'IDIOM',
    'advanced': 'CSAT',
  };
  return '${tier[match[1]] ?? 'SET'}\n${match[2]!.padLeft(2, '0')}';
}

class DeckScreen extends StatefulWidget {
  const DeckScreen({
    super.key,
    required this.deck,
    required this.controller,
    required this.speech,
  });
  final WordDeck deck;
  final LearningController controller;
  final SpeechService speech;
  @override
  State<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends State<DeckScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) {
      final controller = widget.controller;
      final deck = widget.deck.id == 'my-exam'
          ? controller.examDeck
          : widget.deck;
      final words = deck.wordIds
          .map((id) => controller.vocabulary.byId[id]!)
          .where(
            (w) =>
                w.term.toLowerCase().contains(_query.toLowerCase()) ||
                w.meaning.contains(_query),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(deck.title)),
        body: SafeArea(
          top: false,
          child: PageContent(
            children: [
              Caption(_deckCaption(deck)),
              const SizedBox(height: 12),
              Text(
                deck.id == 'my-exam'
                    ? '이번 시험에 필요한\n단어를 모았어요.'
                    : '오늘은 다섯 개,\n차근차근 익혀요.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              PrimaryAction(
                deck.wordIds.isEmpty ? '시험 범위에 단어 담기' : '5개 학습하기',
                onPressed: controller.busy
                    ? null
                    : () {
                        if (deck.wordIds.isEmpty) {
                          editExamWords(context, controller);
                        } else {
                          openStudy(
                            context,
                            controller,
                            widget.speech,
                            deck: deck,
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: deck.wordIds.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ListenScreen(
                            deck: deck,
                            vocabulary: controller.vocabulary,
                            speech: widget.speech,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.headphones_outlined),
                label: const Text('이 단어장 듣기'),
              ),
              if (deck.id == 'my-exam')
                TextButton(
                  onPressed: () => editExamWords(context, controller),
                  child: const Text('담은 단어 편집'),
                ),
              AudioPackButton(speech: widget.speech, deckId: deck.id),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '단어 미리보기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Caption(
                      '${controller.practicedCount(deck.wordIds)} / ${deck.wordIds.length}개 학습',
                    ),
                  ],
                ),
              ),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: '영단어 또는 뜻 검색',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (words.isEmpty)
                PaperCard(
                  child: Caption(
                    deck.wordIds.isEmpty
                        ? '시험 범위를 고르면 여기에 단어가 모여요.'
                        : '검색한 단어가 없어요.',
                  ),
                ),
              for (final word in words)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(
                    word.term,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Caption('${word.partOfSpeech} · ${word.meaning}'),
                  ),
                  trailing: IconButton(
                    tooltip: controller.examWordIds.contains(word.id)
                        ? '시험 범위에서 빼기'
                        : '시험 범위에 담기',
                    icon: Icon(
                      controller.examWordIds.contains(word.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                    onPressed: controller.busy
                        ? null
                        : () async {
                            final ids = controller.examWordIds.toSet();
                            if (!ids.remove(word.id)) ids.add(word.id);
                            if (!await controller.setExamWords(ids) &&
                                context.mounted) {
                              showNotice(context, controller.error!);
                            }
                          },
                  ),
                  onTap: () async {
                    try {
                      await controller.vocabulary.ensureDetails([word.id]);
                      if (context.mounted) {
                        await showWordDetails(
                          context,
                          controller.vocabulary.byId[word.id]!,
                          widget.speech,
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        showNotice(context, '단어를 불러오지 못했어요. 다시 시도해 주세요.');
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showWordDetails(
  BuildContext context,
  WordEntry word,
  SpeechService speech,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: PageContent(
          children: [
            Caption(word.partOfSpeech),
            const SizedBox(height: 8),
            Text(
              word.term,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              word.meaning,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            SpeechButton(speech: speech, text: word.term, senseId: word.id),
            const SizedBox(height: 24),
            const SectionHeading('함께 기억해요'),
            Text(
              word.collocation,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Caption(word.collocationMeaning),
            const SizedBox(height: 20),
            Text(word.example),
            const SizedBox(height: 6),
            Caption(word.exampleMeaning),
            const SizedBox(height: 12),
            SpeechButton(
              speech: speech,
              text: word.example,
              label: '예문 듣기',
              senseId: word.id,
              kind: 'example',
            ),
            for (final example in word.additionalExamples) ...[
              const SizedBox(height: 24),
              const SectionHeading('다른 예문'),
              Text(example.en),
              const SizedBox(height: 6),
              Caption(example.ko),
              const SizedBox(height: 12),
              SpeechButton(speech: speech, text: example.en, label: '다른 예문 듣기'),
            ],
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('짧은 설명'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(word.explanation),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  await speech.stop();
}

Future<void> editExamWords(
  BuildContext context,
  LearningController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ExamSelector(controller: controller),
);

class _ExamSelector extends StatefulWidget {
  const _ExamSelector({required this.controller});
  final LearningController controller;
  @override
  State<_ExamSelector> createState() => _ExamSelectorState();
}

class _ExamSelectorState extends State<_ExamSelector> {
  late final Set<String> _selected = widget.controller.examWordIds.toSet();
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final header = <Widget>[
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '시험 범위 고르기',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Caption('${_selected.length}개 선택 · 필요한 만큼 담아요'),
      ),
      const SizedBox(height: 12),
    ];
    final items = widget.controller.vocabulary.words
        .map(
          (word) => CheckboxListTile(
            value: _selected.contains(word.id),
            title: Text(word.term),
            subtitle: Caption(word.meaning),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selected.add(word.id);
                    } else {
                      _selected.remove(word.id);
                    }
                  }),
          ),
        )
        .toList();
    final saveAction = Padding(
      padding: const EdgeInsets.all(24),
      child: PrimaryAction(
        '${_selected.length}개 담기',
        icon: Icons.check_rounded,
        onPressed: _saving
            ? null
            : () async {
                setState(() => _saving = true);
                final saved = await widget.controller.setExamWords(_selected);
                if (!context.mounted) return;
                if (saved) {
                  Navigator.pop(context);
                } else {
                  setState(() => _saving = false);
                  showNotice(context, widget.controller.error!);
                }
              },
      ),
    );
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimumHeight =
                260 + MediaQuery.textScalerOf(context).scale(24) * 5;
            if (constraints.maxHeight < minimumHeight) {
              return Column(
                children: [
                  Expanded(child: ListView(children: [...header, ...items])),
                  saveAction,
                ],
              );
            }
            return Column(
              children: [
                ...header,
                Expanded(child: ListView(children: items)),
                saveAction,
              ],
            );
          },
        ),
      ),
    );
  }
}
