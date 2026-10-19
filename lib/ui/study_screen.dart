import 'dart:async';
import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../domain/learning.dart';
import '../domain/vocabulary.dart';
import '../services/speech_service.dart';
import 'focus_theme.dart';
import 'widgets.dart';

Future<void> openStudy(
  BuildContext context,
  LearningController controller,
  SpeechService speech, {
  WordDeck? deck,
}) async {
  var startNew = controller.session == null;
  if (deck != null && controller.session != null) {
    if (controller.session!.complete) {
      startNew = true;
    } else if (controller.session!.title != deck.title) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('진행 중인 학습이 있어요'),
          content: const Text(
            '이전 학습을 이어가거나 선택한 단어장으로 새로 시작할 수 있어요. 이미 답한 기록은 남아요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('이전 학습 이어가기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새로 시작'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      startNew = choice;
    }
  }
  if (startNew && !await controller.start(deck: deck)) {
    if (context.mounted) {
      showNotice(context, controller.error ?? '잠시 후 다시 시도해 주세요.');
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StudyScreen(controller: controller, speech: speech),
    ),
  );
  await speech.stop();
}

Future<void> studyAction(
  BuildContext context,
  LearningController controller,
  Future<bool> Function() action,
) async {
  if (!await action() && context.mounted && controller.error != null) {
    showNotice(context, controller.error!);
  }
}

class StudyScreen extends StatelessWidget {
  const StudyScreen({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) unawaited(speech.stop());
    },
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final session = controller.session;
        if (session == null) return const Scaffold(body: SizedBox.shrink());
        if (session.complete) {
          return _Result(controller: controller, speech: speech);
        }
        final word = controller.vocabulary.byId[session.currentId]!;
        final c = FocusColors.of(context);
        final labels = ['익히기', '뜻 떠올리기', '철자 쓰기'];
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '나중에 이어하기',
              icon: const Icon(Icons.close_rounded),
              onPressed: controller.busy ? null : () => Navigator.pop(context),
            ),
            title: Text(labels[session.stage.index]),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Center(
                  child: Caption('${session.step} / ${session.stageCount}'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: PageContent(
              key: ValueKey('${session.id}:${session.position}'),
              children: [
                Row(
                  children: List.generate(
                    3,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: i < session.stage.index
                                  ? 1
                                  : i > session.stage.index
                                  ? 0
                                  : (session.step - 1) / session.stageCount,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(3),
                              color: c.ink,
                              backgroundColor: c.line,
                            ),
                            const SizedBox(height: 8),
                            Caption('${i + 1} ${labels[i]}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (session.practice) ...[
                  const Caption('추가 연습 · 다음 복습 일정은 그대로 유지돼요.'),
                  const SizedBox(height: 12),
                ],
                if (session.stage == SessionStage.learn) ...[
                  PaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Caption(
                          senseLabel(
                            word,
                            controller.vocabulary.sensesOf(word),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          word.term,
                          style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SpeechButton(
                          speech: speech,
                          text: word.term,
                          senseId: word.id,
                        ),
                        const SizedBox(height: 24),
                        if (session.revealed) ...[
                          Divider(color: c.line),
                          const SizedBox(height: 16),
                          Text(
                            word.meaning,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            word.collocation,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Caption(word.collocationMeaning),
                          const SizedBox(height: 20),
                          Text(word.example),
                          const SizedBox(height: 6),
                          Caption(word.exampleMeaning),
                          const SizedBox(height: 14),
                          SpeechButton(
                            speech: speech,
                            text: word.example,
                            senseId: word.id,
                            kind: 'example',
                            label: '예문 듣기',
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('짧은 설명'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(word.explanation),
                                ),
                              ),
                            ],
                          ),
                          OtherSenses(
                            word: word,
                            senses: controller.vocabulary.sensesOf(word),
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: 24, bottom: 8),
                            child: Caption('발음을 들어보고, 어떤 뜻인지 떠올려 보세요.'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryAction(
                    session.revealed
                        ? session.step == session.stageCount
                              ? '뜻 떠올리기로'
                              : '다음 단어'
                        : '뜻 확인하기',
                    onPressed: controller.busy
                        ? null
                        : () async {
                            await speech.stop();
                            if (!context.mounted) return;
                            await studyAction(
                              context,
                              controller,
                              session.revealed
                                  ? controller.next
                                  : controller.reveal,
                            );
                          },
                  ),
                  const SizedBox(height: 12),
                  const Caption('진행 중인 위치는 자동으로 저장돼요.'),
                ] else if (session.stage == SessionStage.recall) ...[
                  Caption(
                    controller.vocabulary.choicesFor(word).length < 4
                        ? '표현 속 뜻을 떠올린 뒤 확인해 주세요'
                        : '표현에 알맞은 뜻을 골라주세요',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    word.term,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Caption(word.partOfSpeech),
                  Text(word.collocation),
                  const SizedBox(height: 16),
                  if (controller.vocabulary.choicesFor(word).length < 4)
                    _RecallWithoutChoices(controller: controller, word: word)
                  else
                    for (final choice in _choices(
                      word,
                      controller.vocabulary,
                    )) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          backgroundColor:
                              session.answered && choice.id == word.id
                              ? c.accent
                              : session.answered &&
                                    session.lastAnswer == choice.id
                              ? c.warningSurface
                              : c.surface,
                          disabledForegroundColor:
                              session.answered && choice.id == word.id
                              ? c.accentInk
                              : c.ink,
                        ),
                        onPressed: controller.busy || session.answered
                            ? null
                            : () => studyAction(
                                context,
                                controller,
                                () => controller.answer(
                                  recalled: choice.id == word.id,
                                  input: choice.id,
                                ),
                              ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(choice.meaning),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  if (session.answered) ...[
                    _Feedback(
                      correct: session.answers.last.correct,
                      answer: word.meaning,
                    ),
                    const SizedBox(height: 20),
                    PrimaryAction(
                      session.step == session.wordIds.length
                          ? '철자 쓰기로'
                          : '다음 문제',
                      onPressed: controller.busy
                          ? null
                          : () => studyAction(
                              context,
                              controller,
                              controller.next,
                            ),
                    ),
                  ],
                ] else
                  _SpellingQuestion(
                    key: ValueKey('${session.id}:${session.position}'),
                    controller: controller,
                    word: word,
                    speech: speech,
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  List<WordEntry> _choices(WordEntry word, Vocabulary vocabulary) =>
      vocabulary.choicesFor(word);
}

// Sparse parts of speech must not produce a quiz containing only its answer.
class _RecallWithoutChoices extends StatelessWidget {
  const _RecallWithoutChoices({required this.controller, required this.word});
  final LearningController controller;
  final WordEntry word;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    if (!session.revealed) {
      return PrimaryAction(
        '뜻 확인하기',
        onPressed: controller.busy
            ? null
            : () => studyAction(context, controller, controller.reveal),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(word.meaning, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (!session.answered) ...[
          const Caption('뜻을 보기 전에 기억했는지 직접 확인해요.'),
          OutlinedButton(
            onPressed: controller.busy
                ? null
                : () => studyAction(
                    context,
                    controller,
                    () => controller.answer(
                      recalled: false,
                      input: 'self:forgot',
                    ),
                  ),
            child: const Text('다시 익힐게요'),
          ),
          OutlinedButton(
            onPressed: controller.busy
                ? null
                : () => studyAction(
                    context,
                    controller,
                    () => controller.answer(
                      recalled: true,
                      input: 'self:remembered',
                    ),
                  ),
            child: const Text('기억했어요'),
          ),
        ],
      ],
    );
  }
}

class _SpellingQuestion extends StatefulWidget {
  const _SpellingQuestion({
    super.key,
    required this.controller,
    required this.word,
    required this.speech,
  });
  final LearningController controller;
  final WordEntry word;
  final SpeechService speech;
  @override
  State<_SpellingQuestion> createState() => _SpellingQuestionState();
}

class _SpellingQuestionState extends State<_SpellingQuestion> {
  late final TextEditingController _input = TextEditingController(
    text: widget.controller.session!.lastAnswer,
  );
  final FocusNode _focus = FocusNode();
  // The synonym and exact text from the last attempt, shown until answered.
  Sense? _synonym;
  String _synonymInput = '';
  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_input.text.trim().isEmpty ||
        widget.controller.busy ||
        widget.controller.session!.answered) {
      return;
    }
    final synonym = widget.controller.spellingSynonym(_input.text);
    if (synonym != null) {
      setState(() {
        _synonym = synonym;
        _synonymInput = _input.text;
        _input.clear();
      });
      _focus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    await studyAction(
      context,
      widget.controller,
      () => widget.controller.answer(input: _input.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;
    final wordCount = widget.word.term.trim().split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Caption(wordCount > 1 ? '뜻을 보고 영어 표현을 써주세요' : '뜻을 보고 영어 단어를 써주세요'),
        const SizedBox(height: 16),
        Text(
          widget.word.meaning,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Caption(
          wordCount > 1
              ? '${widget.word.partOfSpeech} · $wordCount단어 표현'
              : widget.word.partOfSpeech,
        ),
        const SizedBox(height: 28),
        TextField(
          key: const Key('spelling-input'),
          controller: _input,
          focusNode: _focus,
          readOnly: session.answered,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 24),
          decoration: InputDecoration(
            hintText: wordCount > 1 ? '영어 표현 입력' : '영어 단어 입력',
            labelText: '나의 답',
          ),
        ),
        const SizedBox(height: 20),
        if (_synonym != null && !session.answered) ...[
          _SynonymNotice(
            typed: _synonym!.term,
            hint: Sense.spellingHint(widget.word.term, _synonymInput),
            title: wordCount > 1
                ? '맞는 뜻이지만 이번에 찾는 표현은 다른 표현이에요.'
                : '맞는 뜻이지만 이번에 찾는 단어는 다른 단어예요.',
            letters: wordCount > 1 ? null : widget.word.term.length,
          ),
          const SizedBox(height: 20),
        ],
        if (session.answered) ...[
          _Feedback(
            correct: session.answers.last.correct,
            answer: widget.word.term,
          ),
          const SizedBox(height: 12),
          SpeechButton(
            speech: widget.speech,
            text: widget.word.term,
            senseId: widget.word.id,
          ),
          const SizedBox(height: 24),
          PrimaryAction(
            session.step == session.wordIds.length ? '결과 보기' : '다음 문제',
            onPressed: widget.controller.busy
                ? null
                : () async {
                    await widget.speech.stop();
                    if (context.mounted) {
                      await studyAction(
                        context,
                        widget.controller,
                        widget.controller.next,
                      );
                    }
                  },
          ),
        ] else ...[
          PrimaryAction(
            '정답 확인',
            icon: Icons.check_rounded,
            onPressed: widget.controller.busy || _input.text.trim().isEmpty
                ? null
                : _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.controller.busy
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    studyAction(
                      context,
                      widget.controller,
                      () => widget.controller.answer(input: ''),
                    );
                  },
            child: const Text('모르겠어요 · 정답 보기'),
          ),
        ],
      ],
    );
  }
}

// A correct synonym is not a mistake: say so and help find the intended word.
class _SynonymNotice extends StatelessWidget {
  const _SynonymNotice({
    required this.typed,
    required this.hint,
    required this.title,
    this.letters,
  });
  final String typed, hint, title;
  final int? letters;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    return Semantics(
      liveRegion: true,
      child: PaperCard(
        key: const Key('spelling-synonym'),
        color: c.soft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: c.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('‘$typed’도 같은 뜻으로 쓸 수 있어서 오답으로 기록하지 않았어요. 다시 입력해 보세요.'),
                  const SizedBox(height: 10),
                  Text(
                    letters == null
                        ? '힌트 · $hint···'
                        : '힌트 · $hint··· ($letters글자)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.correct, required this.answer});
  final bool correct;
  final String answer;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    return Semantics(
      liveRegion: true,
      child: PaperCard(
        color: correct ? c.soft : c.warningSurface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              correct
                  ? Icons.check_circle_outline_rounded
                  : Icons.refresh_rounded,
              color: correct ? c.ink : c.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? '잘 떠올렸어요.' : '한 번 더 보면 돼요.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(answer),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.controller, required this.speech});
  final LearningController controller;
  final SpeechService speech;
  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final c = FocusColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('학습 결과')),
      body: SafeArea(
        top: false,
        child: PageContent(
          children: [
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: c.accentInk, size: 32),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '이번 라운드를\n마쳤어요.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Caption(
              session.practice
                  ? '추가 연습 결과예요. 다음 복습 일정은 유지돼요.'
                  : '오늘의 첫 확인이에요. 다음 복습에서 다시 만나세요.',
            ),
            const SizedBox(height: 28),
            PaperCard(
              child: Column(
                children: [
                  for (final mode in StudyMode.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              mode == StudyMode.recall ? '뜻 떠올리기' : '철자 쓰기',
                            ),
                          ),
                          Text(
                            '${session.answers.where((a) => a.mode == mode && a.correct).length} / ${session.wordIds.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (session.wrongIds.isNotEmpty) ...[
              SectionHeading('한 번 더 볼 단어 ${session.wrongIds.length}개'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: session.wrongIds
                    .map(
                      (id) => Chip(
                        label: Text(controller.vocabulary.byId[id]!.term),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              PrimaryAction(
                '헷갈린 단어 다시 보기',
                icon: Icons.refresh_rounded,
                onPressed: controller.busy
                    ? null
                    : () => studyAction(
                        context,
                        controller,
                        () => controller.start(
                          retryIds: session.wrongIds.toList(),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: controller.busy
                  ? null
                  : () async {
                      if (await controller.finish() && context.mounted) {
                        Navigator.pop(context);
                      } else if (context.mounted && controller.error != null) {
                        showNotice(context, controller.error!);
                      }
                    },
              child: const Text('학습 마치기'),
            ),
            const SizedBox(height: 16),
            const Caption('뜻과 철자는 따로 기록해요. 여러 날에 걸쳐 기억한 단어만 장기 성취에 반영돼요.'),
          ],
        ),
      ),
    );
  }
}
