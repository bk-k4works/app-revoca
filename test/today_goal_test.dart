import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';
import 'package:focus_voca/ui/deck_screen.dart';
import 'package:focus_voca/ui/focus_theme.dart';

import 'support/memory_store.dart';
import 'widget_test.dart' show FakeSpeech, tapText;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  final today = DateTime(2026, 10, 19, 10);

  // Answered in both modes on [at], next due well after today.
  LearningSnapshot answered(
    Iterable<String> ids, {
    required DateTime at,
    Set<String> wrong = const {},
  }) => LearningSnapshot(
    progress: [
      for (final id in ids)
        for (final mode in StudyMode.values)
          LearningProgress(
            wordId: id,
            mode: mode,
            level: 1,
            dueAt: DateTime(2026, 10, 25),
            lastReviewedAt: at,
          ),
    ],
    events: [
      for (final id in ids)
        for (final mode in StudyMode.values)
          ReviewEvent(
            id: '$id:${mode.name}',
            wordId: id,
            mode: mode,
            correct: !wrong.contains(id),
            practice: false,
            at: at,
          ),
    ],
  );

  Future<LearningController> controllerWith(LearningSnapshot snapshot) async {
    final controller = LearningController(
      vocabulary: vocabulary,
      store: MemoryStore(initial: snapshot),
      clock: () => today,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return controller;
  }

  List<String> idsOf(int deck) => vocabulary.decks[deck].wordIds;

  group('Today goal', () {
    test('new senses stop at the daily goal and the day can finish', () async {
      final learned = [...idsOf(0), ...idsOf(1)];
      expect(learned, hasLength(20));
      final controller = await controllerWith(
        answered(learned, at: today, wrong: {learned[7], learned[12]}),
      );

      expect(controller.newIds, isNotEmpty, reason: 'deck 3 is still new');
      expect(controller.newTodayRemaining, 0);
      expect(controller.todayIds, isEmpty);

      expect(await controller.start(), isTrue);
      final session = controller.session!;
      expect(session.practice, isTrue);
      expect(session.title, '오늘 배운 단어 연습');
      expect(session.wordIds.toSet().take(2), {learned[7], learned[12]});
      expect(session.wordIds.every(learned.contains), isTrue);
    });

    test('yesterday\'s words do not count toward today\'s goal', () async {
      final controller = await controllerWith(
        answered(idsOf(0), at: DateTime(2026, 10, 18, 10)),
      );
      expect(controller.introducedToday, isEmpty);
      expect(controller.newTodayRemaining, 20);
      expect(controller.todayIds, idsOf(1).take(5));
    });

    test('a chosen deck may go beyond the daily goal', () async {
      final controller = await controllerWith(
        answered([...idsOf(0), ...idsOf(1)], at: today),
      );
      expect(await controller.start(deck: vocabulary.decks[2]), isTrue);
      expect(controller.session!.practice, isFalse);
      expect(controller.session!.wordIds.toSet(), idsOf(2).take(5).toSet());
    });
  });

  group('Current deck', () {
    test('starts at the first deck', () async {
      final controller = await controllerWith(const LearningSnapshot());
      expect(controller.currentDeck.id, vocabulary.decks.first.id);
    });

    test('follows the latest answer and offers its new words first', () async {
      final controller = await controllerWith(
        answered(idsOf(2).take(3), at: today),
      );
      expect(controller.currentDeck.id, vocabulary.decks[2].id);
      expect(controller.newIds.take(7), idsOf(2).skip(3));
      expect(controller.todayIds, idsOf(2).skip(3).take(5));
    });

    test('moves on once the deck has no new words', () async {
      final controller = await controllerWith(
        answered(idsOf(1), at: DateTime(2026, 10, 18, 10)),
      );
      expect(controller.currentDeck.id, vocabulary.decks[2].id);
    });
  });

  group('Meaning choices', () {
    Sense sense(String id, String headword, String meaning) => Sense(
      id: id,
      headword: Headword(
        id: headword,
        term: headword,
        acceptedSpellings: [headword],
      ),
      pos: 'v',
      meaning: meaning,
      collocation: '$headword it',
    );

    test('choice labels drop parenthesised usage hints', () {
      expect(sense('a', 'earn', '(돈을) 벌다').choiceLabel, '벌다');
      expect(sense('b', 'license', '면허(증); 허가').choiceLabel, '면허; 허가');
      expect(sense('c', 'term', '조건; (사람 사이의) 관계').choiceLabel, '조건; 관계');
      expect(sense('d', 'odd', '(복수형) ').choiceLabel, '(복수형) ');
    });

    test('a distractor never reads the same as the answer once stripped', () {
      final words = [
        sense('earn.money', 'earn', '(돈을) 벌다'),
        sense('make.money', 'make', '벌다'),
        sense('keep', 'keep', '지키다'),
        sense('stare', 'stare', '빤히 쳐다보다'),
        sense('value', 'value', '소중히 여기다'),
      ];
      final choices = Vocabulary(
        words: words,
        decks: [
          WordDeck(
            id: 'all',
            title: '전체',
            subtitle: '',
            wordIds: words.map((w) => w.id).toList(),
          ),
        ],
        provenance: const {},
      ).choicesFor(words.first);
      expect(choices.map((c) => c.id), isNot(contains('make.money')));
      expect(choices.map((c) => c.choiceLabel).toSet(), hasLength(4));
    });

    test('senses of one headword are not quizzed back to back', () async {
      final words = [
        sense('earn.money', 'earn', '(돈을) 벌다'),
        sense('earn.respect', 'earn', '(노력으로) 얻다'),
        sense('keep', 'keep', '지키다'),
        sense('stare', 'stare', '빤히 쳐다보다'),
        sense('value', 'value', '소중히 여기다'),
      ];
      final deck = WordDeck(
        id: 'all',
        title: '전체',
        subtitle: '',
        wordIds: words.map((w) => w.id).toList(),
      );
      final controller = LearningController(
        vocabulary: Vocabulary(words: words, decks: [deck], provenance: {}),
        store: MemoryStore(),
        clock: () => today,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.start(deck: deck);
      final session = controller.session!;
      expect(session.learningWordIds, deck.wordIds, reason: 'learn together');
      expect(session.wordIds, [
        'earn.money',
        'keep',
        'earn.respect',
        'stare',
        'value',
      ]);
    });
  });

  testWidgets('a finished day reads as done, even at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = await controllerWith(
      answered([...idsOf(0), ...idsOf(1)], at: today),
    );
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘의 학습을'), findsOneWidget);
    expect(find.text('오늘 새 단어 20 / 20'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(vocabulary.decks[2].title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('가볍게 연습하기'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    await tapText(tester, '가볍게 연습하기');
    expect(controller.session!.title, '오늘 배운 단어 연습');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the next step is reachable without scrolling after an answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LearningController(
      vocabulary: vocabulary,
      store: MemoryStore(),
      clock: () => today,
    );
    await controller.initialize();
    await controller.start(deck: vocabulary.decks.first);
    while (controller.session!.stage == SessionStage.learn) {
      await controller.reveal();
      await controller.next();
    }
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '이어서 학습하기');
    final word = vocabulary.byId[controller.session!.currentId]!;
    await tester.ensureVisible(find.text(word.choiceLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(word.choiceLabel).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('다음 문제').hitTestable(), findsOneWidget);
    expect(find.text('잘 떠올렸어요.').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the exam range can be narrowed and filled by deck or search', (
    tester,
  ) async {
    final store = MemoryStore();
    final controller = LearningController(vocabulary: vocabulary, store: store);
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
    await tester.tap(find.byKey(const Key('exam-deck-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(vocabulary.decks[1].title).last);
    await tester.pumpAndSettle();
    await tapText(tester, '보이는 10개 모두 담기');
    await tester.enterText(find.byKey(const Key('exam-search')), 'achieve');
    await tester.pumpAndSettle();
    expect(find.text('보이는 0개 모두 담기'), findsOneWidget, reason: 'deck 2');
    await tester.tap(find.byKey(const Key('exam-deck-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 단어장').last);
    await tester.pumpAndSettle();
    await tapText(tester, '보이는 1개 모두 담기');
    await tapText(tester, '11개 담기');
    expect(controller.examWordIds.toSet(), {...idsOf(1), 'achieve'});
    expect(store.snapshot.examWordIds.toSet(), controller.examWordIds.toSet());
    expect(tester.takeException(), isNull);
  });
}
