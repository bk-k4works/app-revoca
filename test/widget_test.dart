import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';
import 'package:focus_voca/services/speech_service.dart';
import 'package:focus_voca/ui/deck_screen.dart';
import 'package:focus_voca/ui/focus_theme.dart';
import 'package:focus_voca/ui/listen_screen.dart';
import 'support/memory_store.dart';

class FakeSpeech implements SpeechService {
  int stopCount = 0;
  final List<String> utterances = [];
  Completer<void>? pending;
  @override
  Future<void> speak(
    String text, {
    String language = 'en-US',
    double rate = 0.45,
  }) {
    utterances.add(text);
    pending = Completer<void>();
    return pending!.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    if (pending != null && !pending!.isCompleted) pending!.complete();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) break;
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
    } else {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    }
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsWidgets, reason: '$text must be reachable');
  await tester.tap(finder.hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  testWidgets(
    'complete one round, mark an unknown spelling, retry without granting mastery',
    (tester) async {
      final controller = LearningController(
        vocabulary: vocabulary,
        store: MemoryStore(),
        clock: () => DateTime(2026, 10, 15, 10),
      );
      await controller.initialize();
      final word = vocabulary.words.first;
      await controller.start(
        deck: WordDeck(
          id: 'test',
          title: '한 단어 학습',
          subtitle: '',
          wordIds: [word.id],
        ),
      );
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: FakeSpeech()),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '이어서 학습하기');
      expect(find.text(word.meaning), findsNothing);
      await tapText(tester, '뜻 확인하기');
      expect(find.text(word.meaning), findsOneWidget);
      await tapText(tester, '뜻 떠올리기로');
      await tapText(tester, word.meaning);
      await tapText(tester, '철자 쓰기로');
      await tapText(tester, '모르겠어요 · 정답 보기');
      expect(controller.stateFor(word.id, StudyMode.spelling)!.level, 0);
      await tapText(tester, '결과 보기');
      expect(find.text('이번 라운드를\n마쳤어요.'), findsOneWidget);
      await tapText(tester, '헷갈린 단어 다시 보기');
      await tapText(tester, '뜻 확인하기');
      await tapText(tester, '뜻 떠올리기로');
      await tapText(tester, word.meaning);
      await tapText(tester, '철자 쓰기로');
      await tester.enterText(
        find.byKey(const Key('spelling-input')),
        word.term,
      );
      await tester.pump();
      await tapText(tester, '정답 확인');
      await tapText(tester, '결과 보기');
      expect(controller.stateFor(word.id, StudyMode.spelling)!.level, 0);
      expect(controller.events.where((e) => e.practice).length, 2);
      await tapText(tester, '학습 마치기');
      expect(controller.session, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sparse recall requires reveal and explicit self assessment', (
    tester,
  ) async {
    final word = Sense(
      id: 'yes',
      headword: const Headword(
        id: 'yes',
        term: 'yes',
        acceptedSpellings: ['yes'],
      ),
      pos: 'interj',
      meaning: '네',
      collocation: 'say yes',
    );
    final deck = WordDeck(
      id: 'sparse',
      title: '한 단어',
      subtitle: '',
      wordIds: [word.id],
    );
    final controller = LearningController(
      vocabulary: Vocabulary(words: [word], decks: [deck], provenance: {}),
      store: MemoryStore(),
    );
    await controller.initialize();
    await controller.start(deck: deck);
    await controller.reveal();
    await controller.next();
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '이어서 학습하기');
    expect(find.text('네'), findsNothing);
    expect(find.text('기억했어요'), findsNothing);
    expect(controller.events, isEmpty);
    await tapText(tester, '뜻 확인하기');
    expect(find.text('네'), findsOneWidget);
    expect(controller.events, isEmpty);
    await tapText(tester, '다시 익힐게요');
    expect(controller.events.single.correct, isFalse);
    await tapText(tester, '철자 쓰기로');
    await tester.enterText(find.byKey(const Key('spelling-input')), 'yes');
    await tester.pump();
    await tapText(tester, '정답 확인');
    await tapText(tester, '결과 보기');
    expect(controller.session!.complete, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a synonym in spelling shows a hint and asks again instead of marking wrong',
    (tester) async {
      Sense word(String term, String meaning, {List<String> alt = const []}) =>
          Sense(
            id: term,
            headword: Headword(id: term, term: term, acceptedSpellings: [term]),
            pos: 'adv',
            meaning: meaning,
            meaningAlternatives: alt,
            collocation: '$term, we went',
          );
      final words = [
        word('nevertheless', '그럼에도 불구하고'),
        word('nonetheless', '그렇더라도', alt: ['그럼에도 불구하고']),
        word('however', '하지만'),
        word('therefore', '그러므로'),
      ];
      final deck = WordDeck(
        id: 'synonyms',
        title: '유의어',
        subtitle: '',
        wordIds: ['nevertheless'],
      );
      final controller = LearningController(
        vocabulary: Vocabulary(words: words, decks: [deck], provenance: {}),
        store: MemoryStore(),
      );
      await controller.initialize();
      await controller.start(deck: deck);
      await controller.reveal();
      await controller.next();
      await controller.answer(recalled: true, input: 'nevertheless');
      await controller.next();
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: FakeSpeech()),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '이어서 학습하기');
      final input = find.byKey(const Key('spelling-input'));
      await tester.enterText(input, 'nonetheless');
      await tester.pump();
      await tapText(tester, '정답 확인');

      expect(find.byKey(const Key('spelling-synonym')), findsOneWidget);
      expect(find.text('맞는 뜻이지만 이번에 찾는 단어는 다른 단어예요.'), findsOneWidget);
      expect(
        find.text('‘nonetheless’도 같은 뜻으로 쓸 수 있어서 오답으로 기록하지 않았어요. 다시 입력해 보세요.'),
        findsOneWidget,
      );
      expect(find.text('힌트 · ne··· (12글자)'), findsOneWidget);
      expect(find.text('한 번 더 보면 돼요.'), findsNothing);
      expect(controller.session!.answered, isFalse);
      expect(
        controller.events.where((e) => e.mode == StudyMode.spelling),
        isEmpty,
      );
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(tester.widget<TextField>(input).readOnly, isFalse);

      await tester.enterText(input, 'however');
      await tester.pump();
      await tapText(tester, '정답 확인');
      expect(find.byKey(const Key('spelling-synonym')), findsNothing);
      expect(find.text('한 번 더 보면 돼요.'), findsOneWidget);
      expect(controller.session!.answers.last.correct, isFalse);
      expect(controller.session!.wrongIds, {'nevertheless'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a synonym retry can still be answered correctly', (
    tester,
  ) async {
    final words = [
      for (final (term, meaning) in [('ban', '금지하다'), ('forbid', '금하다')])
        Sense(
          id: term,
          headword: Headword(id: term, term: term, acceptedSpellings: [term]),
          pos: 'v',
          meaning: meaning,
          nearSynonymHeadwords: term == 'ban' ? ['forbid'] : [],
          collocation: '$term smoking',
        ),
    ];
    final deck = WordDeck(
      id: 'ban',
      title: '금지',
      subtitle: '',
      wordIds: ['ban'],
    );
    final controller = LearningController(
      vocabulary: Vocabulary(words: words, decks: [deck], provenance: {}),
      store: MemoryStore(),
    );
    await controller.initialize();
    await controller.start(deck: deck);
    await controller.reveal();
    await controller.next();
    await controller.answer(recalled: true, input: 'ban');
    await controller.next();
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '이어서 학습하기');
    final input = find.byKey(const Key('spelling-input'));
    await tester.enterText(input, 'forbid');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('힌트 · b··· (3글자)'), findsOneWidget);
    expect(controller.session!.answered, isFalse);
    await tester.enterText(input, 'ban');
    await tester.pump();
    await tapText(tester, '정답 확인');
    expect(find.byKey(const Key('spelling-synonym')), findsNothing);
    expect(find.text('잘 떠올렸어요.'), findsOneWidget);
    expect(controller.session!.answers.last.correct, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screen and 200 percent text remain usable in light and dark',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      for (final brightness in Brightness.values) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        final controller = LearningController(
          vocabulary: vocabulary,
          store: MemoryStore(),
        );
        await controller.initialize();
        await tester.pumpWidget(
          FocusVocaApp(
            key: ValueKey(brightness),
            controller: controller,
            speech: FakeSpeech(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(NavigationDestination).at(2));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  group('one headword, several senses', () {
    Sense still(String slug, String pos, String meaning) => Sense(
      id: 'hs.still.$pos.$slug',
      headword: const Headword(
        id: 'still',
        term: 'still',
        acceptedSpellings: ['still'],
      ),
      pos: pos,
      meaning: meaning,
      collocation: 'still here',
      example: 'She is still here.',
      exampleMeaning: '그녀는 아직 여기 있다.',
      explanation: '설명이에요.',
    );
    final words = [
      still('continuing', 'adv', '아직도'),
      still('nevertheless', 'adv', '그런데도'),
      still('motionless', 'adj', '고요한'),
      Sense(
        id: 'hs.calm.adj.peaceful',
        headword: const Headword(
          id: 'calm',
          term: 'calm',
          acceptedSpellings: ['calm'],
        ),
        pos: 'adj',
        meaning: '침착한',
        collocation: 'stay calm',
        example: 'Stay calm.',
        exampleMeaning: '침착해라.',
        explanation: '설명이에요.',
      ),
    ];
    final deck = WordDeck(
      id: 'basic',
      title: '고교 기본 01',
      subtitle: '',
      wordIds: words.map((w) => w.id).toList(),
    );

    test('senses of a headword come back in content order', () {
      final vocabulary = Vocabulary(
        words: words,
        decks: [deck],
        provenance: {},
      );
      expect(vocabulary.sensesOf(words[1]).map((w) => w.meaning), [
        '아직도',
        '그런데도',
        '고요한',
      ]);
      expect(vocabulary.sensesOf(words[3]).single.id, 'hs.calm.adj.peaceful');
    });

    testWidgets('the deck lists a headword once with each meaning', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = LearningController(
        vocabulary: Vocabulary(words: words, decks: [deck], provenance: {}),
        store: MemoryStore(),
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: DeckScreen(
            deck: deck,
            controller: controller,
            speech: FakeSpeech(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('still'), findsOneWidget);
      expect(find.text('뜻 3개'), findsOneWidget);
      expect(find.text('calm'), findsOneWidget);
      for (final line in ['부사 · 아직도', '부사 · 그런데도', '형용사 · 고요한']) {
        expect(find.text(line), findsOneWidget);
      }
      // Each meaning keeps its own exam bookmark.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('sense-hs.still.adv.nevertheless')),
          matching: find.byIcon(Icons.bookmark_border_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.examWordIds, ['hs.still.adv.nevertheless']);
      await tapText(tester, '부사 · 그런데도');
      expect(find.text('부사 · 뜻 3개 중 2번째'), findsOneWidget);
      await tapText(tester, '이 단어의 다른 뜻 2개');
      expect(find.text('부사 · 아직도'), findsWidgets);
      expect(find.text('형용사 · 고요한'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the learn card places the sense among its meanings', (
      tester,
    ) async {
      final second = WordDeck(
        id: 'second',
        title: '그런데도',
        subtitle: '',
        wordIds: ['hs.still.adv.nevertheless'],
      );
      final controller = LearningController(
        vocabulary: Vocabulary(
          words: words,
          decks: [deck, second],
          provenance: {},
        ),
        store: MemoryStore(),
      );
      await controller.initialize();
      await controller.start(deck: second);
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: FakeSpeech()),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '이어서 학습하기');
      expect(find.text('부사 · 뜻 3개 중 2번째'), findsOneWidget);
      expect(find.text('이 단어의 다른 뜻 2개'), findsNothing);
      await tapText(tester, '뜻 확인하기');
      await tapText(tester, '이 단어의 다른 뜻 2개');
      expect(find.text('부사 · 아직도'), findsOneWidget);
      expect(find.text('형용사 · 고요한'), findsOneWidget);
      // Recall must not reveal the other meanings or their count.
      await tapText(tester, '뜻 떠올리기로');
      expect(find.textContaining('뜻 3개'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'exam selection persists and the chosen word appears in its deck',
    (tester) async {
      final store = MemoryStore();
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: DeckScreen(
            deck: controller.examDeck,
            controller: controller,
            speech: FakeSpeech(),
          ),
        ),
      );
      await tapText(tester, '시험 범위에 단어 담기');
      await tapText(tester, vocabulary.words.first.term);
      await tapText(tester, '1개 담기');
      expect(controller.examWordIds, [vocabulary.words.first.id]);
      expect(store.snapshot.examWordIds, controller.examWordIds);
      expect(find.text(vocabulary.words.first.term), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving listening cancels the active utterance and the rest of the queue',
    (tester) async {
      final speech = FakeSpeech();
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ListenScreen(
                      deck: vocabulary.decks.first,
                      vocabulary: vocabulary,
                      speech: speech,
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, '열기');
      await tapText(tester, '재생하기');
      expect(speech.utterances.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(speech.stopCount, greaterThan(0));
      expect(speech.utterances.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'course layout groups tiers and marks middle school as coming soon',
    (tester) async {
      final ids = vocabulary.words.take(3).map((w) => w.id).toList();
      final courseVocabulary = Vocabulary(
        words: vocabulary.words,
        decks: [
          WordDeck(
            id: 'hs-basic-001',
            title: '고교 기본 01',
            subtitle: '3단어 · 뜻 3개',
            wordIds: ids,
          ),
        ],
        provenance: {
          'courses': [
            {
              'id': 'high',
              'title': '고등 영단어',
              'status': 'available',
              'tiers': [
                {
                  'id': 'basic',
                  'title': '고교 기본',
                  'planned': 599,
                  'authored': 3,
                },
                {'id': 'core', 'title': '고교 핵심', 'planned': 966, 'authored': 0},
              ],
            },
            {
              'id': 'middle',
              'title': '중학 영단어',
              'status': 'comingSoon',
              'tiers': [],
            },
          ],
        },
      );
      final controller = LearningController(
        vocabulary: courseVocabulary,
        store: MemoryStore(),
        clock: () => DateTime(2026, 10, 16, 10),
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: Scaffold(
            body: DeckLibrary(controller: controller, speech: FakeSpeech()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('고등 영단어'), findsOneWidget);
      expect(find.text('고교 기본 01'), findsOneWidget);
      expect(find.text('BASIC\n01'), findsOneWidget);
      expect(find.text('3 / 599단어'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('곧 만나요 · 준비 중'), 200);
      expect(find.text('준비하고 있어요'), findsOneWidget);
      expect(find.text('중학 영단어'), findsOneWidget);
    },
  );

  testWidgets(
    'phrase spelling shows a word-count hint and ignores extra spaces',
    (tester) async {
      final phrase = Sense(
        id: 'hs.in-order-to.phrase.purpose',
        headword: const Headword(
          id: 'in-order-to',
          term: 'in order to',
          acceptedSpellings: ['in order to'],
        ),
        pos: 'phrase',
        meaning: '~하기 위해',
        collocation: 'in order to win',
      );
      final deck = WordDeck(
        id: 'phrase',
        title: '숙어',
        subtitle: '',
        wordIds: [phrase.id],
      );
      final controller = LearningController(
        vocabulary: Vocabulary(words: [phrase], decks: [deck], provenance: {}),
        store: MemoryStore(),
      );
      await controller.initialize();
      await controller.start(deck: deck);
      await controller.reveal();
      await controller.next();
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: FakeSpeech()),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '이어서 학습하기');
      await tapText(tester, '뜻 확인하기');
      await tapText(tester, '기억했어요');
      await tapText(tester, '철자 쓰기로');
      expect(find.text('뜻을 보고 영어 표현을 써주세요'), findsOneWidget);
      expect(find.text('구 · 3단어 표현'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('spelling-input')),
        '  In   order to ',
      );
      await tester.pump();
      await tapText(tester, '정답 확인');
      expect(controller.events.last.mode, StudyMode.spelling);
      expect(controller.events.last.correct, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
