import 'package:flutter/material.dart';
import 'audio_pack_button.dart';
import '../application/learning_controller.dart';
import '../domain/vocabulary.dart';
import '../services/speech_service.dart';
import 'focus_theme.dart';
import 'listen_screen.dart';
import 'search_screen.dart';
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
      Caption('한 번에 ${controller.sessionSize}개씩, 부담 없이 시작해요.'),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        key: const Key('open-word-search'),
        style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
        onPressed: () => openWordSearch(context, controller, speech),
        icon: const Icon(Icons.search_rounded),
        label: const Text('모든 단어장에서 영단어·뜻 찾기'),
      ),
      const SizedBox(height: 28),
      const SectionHeading('내 단어'),
      DeckTile(
        deck: controller.favoriteDeck,
        controller: controller,
        speech: speech,
        index: 1,
      ),
      const SizedBox(height: 16),
      DeckTile(
        deck: controller.weakDeck,
        controller: controller,
        speech: speech,
        index: 2,
      ),
      const SizedBox(height: 16),
      DeckTile(
        deck: controller.examDeck,
        controller: controller,
        speech: speech,
        index: 3,
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => editExamWords(context, controller),
          icon: const Icon(Icons.add_rounded),
          label: const Text('시험 범위 고르기'),
        ),
      ),
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
                        switch (deck.id) {
                          'my-exam' => 'MY\nTEST',
                          'my-favorites' => 'MY\nSTARS',
                          'my-weak' => 'RE\nTEST',
                          _ => _badge(deck.id, index),
                        },
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

/// What the word list covers so the student can check themselves.
enum ListCover { none, meaning, term }

class _DeckScreenState extends State<DeckScreen> {
  String _query = '';
  ListCover _cover = ListCover.none;
  // Headwords or senses uncovered one by one while a cover is on.
  final Set<String> _uncovered = {};
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) {
      final controller = widget.controller;
      final deck = controller.latest(widget.deck);
      final favorites = deck.id == 'my-favorites';
      final weak = deck.id == 'my-weak';
      final retest = deck.wordIds.take(controller.sessionSize).length;
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
              Text(switch (deck.id) {
                'my-exam' => '이번 시험에 필요한\n단어를 모았어요.',
                'my-favorites' => '별표한 단어를\n다시 꺼내 봐요.',
                'my-weak' => '틀린 단어만\n다시 시험해요.',
                _ => '오늘은 ${controller.sessionSize}개씩,\n차근차근 익혀요.',
              }, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              PrimaryAction(
                weak
                    ? deck.wordIds.isEmpty
                          ? '아직 틀린 단어가 없어요'
                          : '틀린 단어 $retest개 다시 시험'
                    : deck.wordIds.isEmpty
                    ? favorites
                          ? '단어 찾아서 별표하기'
                          : '시험 범위에 단어 담기'
                    : '${controller.sessionSize}개 학습하기',
                onPressed: controller.busy || (weak && deck.wordIds.isEmpty)
                    ? null
                    : () {
                        if (weak) {
                          openStudy(
                            context,
                            controller,
                            widget.speech,
                            deck: deck,
                            start: controller.retestWeak,
                          );
                        } else if (deck.wordIds.isEmpty && favorites) {
                          openWordSearch(context, controller, widget.speech);
                        } else if (deck.wordIds.isEmpty) {
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
                            onHeard: controller.recordListen,
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
              const SizedBox(height: 12),
              SegmentedButton<ListCover>(
                key: const Key('list-cover'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ListCover.none, label: Text('모두')),
                  ButtonSegment(value: ListCover.meaning, label: Text('영어만')),
                  ButtonSegment(value: ListCover.term, label: Text('뜻만')),
                ],
                selected: {_cover},
                onSelectionChanged: (value) => setState(() {
                  _cover = value.single;
                  _uncovered.clear();
                }),
              ),
              if (_cover != ListCover.none) ...[
                const SizedBox(height: 8),
                const Caption('가린 부분을 누르면 하나씩 보여요.'),
              ],
              const SizedBox(height: 16),
              if (words.isEmpty)
                PaperCard(
                  child: Caption(
                    deck.wordIds.isEmpty
                        ? weak
                              ? '뜻 고르기나 철자 쓰기에서 틀린 단어가 여기에 모여요. 여러 날에 걸쳐 다시 맞히면 빠져요.'
                              : favorites
                              ? '단어 옆의 별을 누르면 여기에 모여요.'
                              : '시험 범위를 고르면 여기에 단어가 모여요.'
                        : '검색한 단어가 없어요.',
                  ),
                ),
              for (final group in groupByHeadword(words)) ...[
                HeadwordHeading(
                  group: group,
                  covered:
                      _cover == ListCover.term &&
                      !_uncovered.contains(group.first.headword.id),
                  onUncover: () =>
                      setState(() => _uncovered.add(group.first.headword.id)),
                ),
                for (final word in group)
                  SenseTile(
                    word: word,
                    controller: controller,
                    speech: widget.speech,
                    meaningCovered:
                        _cover == ListCover.meaning &&
                        !_uncovered.contains(word.id),
                    onUncover: () => setState(() => _uncovered.add(word.id)),
                    detail: weak
                        ? '틀린 횟수 ${controller.wrongCount(word.id)}번'
                        : null,
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Learning stays per sense; lists show a headword once with its meanings.
List<List<WordEntry>> groupByHeadword(List<WordEntry> words) {
  final groups = <String, List<WordEntry>>{};
  for (final word in words) {
    groups.putIfAbsent('${word.headword.id}|${word.term}', () => []).add(word);
  }
  return groups.values.toList();
}

class HeadwordHeading extends StatelessWidget {
  const HeadwordHeading({
    super.key,
    required this.group,
    this.covered = false,
    this.onUncover,
  });
  final List<WordEntry> group;

  /// Shows a cover instead of the word until [onUncover] is called.
  final bool covered;
  final VoidCallback? onUncover;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 2),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        if (covered)
          _Cover(label: '단어 보기', onTap: onUncover, large: true)
        else
          Text(
            group.first.term,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        if (group.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Caption('뜻 ${group.length}개'),
          ),
      ],
    ),
  );
}

/// One sense in a list: opens its details and toggles the exam range.
class SenseTile extends StatelessWidget {
  const SenseTile({
    super.key,
    required this.word,
    required this.controller,
    required this.speech,
    this.detail,
    this.meaningCovered = false,
    this.onUncover,
  });
  final WordEntry word;
  final LearningController controller;
  final SpeechService speech;
  final String? detail;

  /// Shows a cover instead of the meaning until [onUncover] is called.
  final bool meaningCovered;
  final VoidCallback? onUncover;

  @override
  Widget build(BuildContext context) {
    final saved = controller.examWordIds.contains(word.id);
    return ListTile(
      key: ValueKey('sense-${word.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      title: meaningCovered
          ? Row(
              children: [
                Text(
                  '${word.partOfSpeech} · ',
                  style: TextStyle(
                    fontSize: 15,
                    color: FocusColors.of(context).muted,
                  ),
                ),
                _Cover(label: '뜻 보기', onTap: onUncover),
              ],
            )
          : Text(
              '${word.partOfSpeech} · ${word.meaning}',
              style: TextStyle(
                fontSize: 15,
                color: FocusColors.of(context).muted,
              ),
            ),
      subtitle: detail == null ? null : Caption(detail!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteButton(controller: controller, wordId: word.id),
          IconButton(
            tooltip: saved ? '시험 범위에서 빼기' : '시험 범위에 담기',
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
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
        ],
      ),
      onTap: () async {
        final senses = controller.vocabulary.sensesOf(word);
        try {
          await controller.vocabulary.ensureDetails([word.id]);
          if (context.mounted) {
            await showWordDetails(
              context,
              controller.vocabulary.byId[word.id]!,
              speech,
              senses: senses,
              controller: controller,
            );
          }
        } catch (_) {
          if (context.mounted) {
            showNotice(context, '단어를 불러오지 못했어요. 다시 시도해 주세요.');
          }
        }
      },
    );
  }
}

/// A tappable cover hiding a word or meaning in a self-check list.
class _Cover extends StatelessWidget {
  const _Cover({required this.label, this.onTap, this.large = false});
  final String label;
  final VoidCallback? onTap;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    return Material(
      color: c.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: large ? 16 : 10,
            vertical: large ? 6 : 3,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 15 : 13,
              color: c.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stars or unstars a sense; starred senses gather in the 즐겨찾기 deck.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.controller,
    required this.wordId,
  });
  final LearningController controller;
  final String wordId;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final starred = controller.isFavorite(wordId);
      return IconButton(
        key: ValueKey('favorite-$wordId'),
        tooltip: starred ? '즐겨찾기에서 빼기' : '즐겨찾기에 담기',
        isSelected: starred,
        icon: const Icon(Icons.star_outline_rounded),
        selectedIcon: Icon(
          Icons.star_rounded,
          color: FocusColors.of(context).warning,
        ),
        onPressed: controller.busy
            ? null
            : () async {
                if (!await controller.toggleFavorite(wordId) &&
                    context.mounted &&
                    controller.error != null) {
                  showNotice(context, controller.error!);
                }
              },
      );
    },
  );
}

Future<void> showWordDetails(
  BuildContext context,
  WordEntry word,
  SpeechService speech, {
  List<WordEntry> senses = const [],
  LearningController? controller,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: PageContent(
          children: [
            Caption(senseLabel(word, senses)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.term,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                if (controller != null)
                  FavoriteButton(controller: controller, wordId: word.id),
              ],
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
            OtherSenses(word: word, senses: senses),
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
  String _query = '';
  WordDeck? _deck;

  // Senses narrowed by deck and by a search over the word and its meaning.
  List<WordEntry> get _visible {
    final vocabulary = widget.controller.vocabulary;
    final query = _query.trim().toLowerCase();
    final words =
        _deck?.wordIds.map((id) => vocabulary.byId[id]!) ?? vocabulary.words;
    return words
        .where(
          (w) =>
              query.isEmpty ||
              w.term.toLowerCase().contains(query) ||
              w.meaning.contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final allVisibleSelected =
        visible.isNotEmpty && visible.every((w) => _selected.contains(w.id));
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
        child: Caption('${_selected.length}개 선택 · 단어장이나 검색으로 좁혀서 담아요'),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonFormField<WordDeck?>(
          key: const Key('exam-deck-filter'),
          initialValue: _deck,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '단어장'),
          items: [
            const DropdownMenuItem<WordDeck?>(child: Text('전체 단어장')),
            for (final deck in widget.controller.vocabulary.decks)
              DropdownMenuItem<WordDeck?>(
                value: deck,
                child: Text(deck.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (deck) => setState(() => _deck = deck),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          key: const Key('exam-search'),
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(
            hintText: '영단어 또는 뜻 검색',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _saving || visible.isEmpty
                ? null
                : () => setState(() {
                    final ids = visible.map((w) => w.id);
                    if (allVisibleSelected) {
                      _selected.removeAll(ids);
                    } else {
                      _selected.addAll(ids);
                    }
                  }),
            child: Text(
              allVisibleSelected
                  ? '보이는 ${visible.length}개 모두 빼기'
                  : '보이는 ${visible.length}개 모두 담기',
            ),
          ),
        ),
      ),
    ];
    Widget item(WordEntry word) => CheckboxListTile(
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
    );
    const empty = Padding(
      padding: EdgeInsets.all(16),
      child: Caption('검색한 단어가 없어요.'),
    );
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
                420 + MediaQuery.textScalerOf(context).scale(24) * 5;
            // Short screens scroll the filters away with the list.
            final leading = constraints.maxHeight < minimumHeight
                ? header
                : const <Widget>[];
            final list = ListView.builder(
              itemCount:
                  leading.length + (visible.isEmpty ? 1 : visible.length),
              itemBuilder: (context, index) => index < leading.length
                  ? leading[index]
                  : visible.isEmpty
                  ? empty
                  : item(visible[index - leading.length]),
            );
            return Column(
              children: [
                if (leading.isEmpty) ...header,
                Expanded(child: list),
                saveAction,
              ],
            );
          },
        ),
      ),
    );
  }
}
