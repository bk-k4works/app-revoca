import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';

import 'support/memory_store.dart';
import 'widget_test.dart' show FakeSpeech, tapText;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  final today = DateTime(2026, 10, 19, 20);
  var serial = 0;

  ReviewEvent answer(
    String wordId,
    DateTime at, {
    StudyMode mode = StudyMode.recall,
    bool correct = true,
    bool practice = false,
  }) => ReviewEvent(
    id: 'e${serial++}',
    wordId: wordId,
    mode: mode,
    correct: correct,
    practice: practice,
    at: at,
  );

  ActivityEvent activity(String wordId, ActivityKind kind, DateTime at) =>
      ActivityEvent(id: 'a${serial++}', wordId: wordId, kind: kind, at: at);

  Future<LearningController> open(MemoryStore store) async {
    final controller = LearningController(
      vocabulary: vocabulary,
      store: store,
      clock: () => today,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return controller;
  }

  // achieve: new on the 17th, reviewed today. practice: new today, missed.
  // prepare: first answered on the 18th, only extra practice today.
  MemoryStore history() => MemoryStore(
    initial: LearningSnapshot(
      seenHints: const ['search'],
      events: [
        answer('achieve', DateTime(2026, 10, 17, 9)),
        answer('prepare', DateTime(2026, 10, 18, 9)),
        answer('achieve', DateTime(2026, 10, 19, 19, 5)),
        answer(
          'achieve',
          DateTime(2026, 10, 19, 19, 6),
          mode: StudyMode.spelling,
          correct: false,
        ),
        answer('practice', DateTime(2026, 10, 19, 19, 7), correct: false),
        answer('prepare', DateTime(2026, 10, 19, 19, 8), practice: true),
      ],
      activities: [
        activity('practice', ActivityKind.learn, DateTime(2026, 10, 19, 19)),
        activity(
          'improve',
          ActivityKind.listen,
          DateTime(2026, 10, 19, 19, 30),
        ),
        activity(
          'improve',
          ActivityKind.listen,
          DateTime(2026, 10, 19, 19, 31),
        ),
        activity('effort', ActivityKind.listen, DateTime(2026, 10, 5, 8)),
      ],
    ),
  );

  group('Day summary', () {
    test(
      'splits new, reviewed and practised words and their accuracy',
      () async {
        final controller = await open(history());
        final day = controller.daySummary(today);
        expect(day.newIds, ['practice']);
        expect(day.reviewedIds, ['achieve']);
        expect(day.practicedIds, ['prepare']);
        expect(day.wrongIds, ['achieve', 'practice']);
        expect(day.learnedIds, ['practice']);
        expect(day.listenedIds, ['improve']);
        expect((day.recallCorrect, day.recallTotal), (1, 2));
        expect((day.spellingCorrect, day.spellingTotal), (0, 1));
        expect(day.start, DateTime(2026, 10, 19, 19));
        expect(day.end, DateTime(2026, 10, 19, 19, 31));
        expect(day.studiedIds, {'practice', 'achieve', 'prepare'});
        expect(controller.daySummary(DateTime(2026, 10, 16)).isEmpty, isTrue);
      },
    );

    test('a listening-only day counts as a study day', () async {
      final controller = await open(history());
      expect(controller.activeDays, contains('2026-10-05'));
      expect(controller.daySummary(DateTime(2026, 10, 5)).listenedIds, [
        'effort',
      ]);
      expect(controller.streak, 3, reason: '17th to 19th');
    });

    test('a month adds up its days', () async {
      final controller = await open(history());
      final month = controller.monthSummary(2026, 10);
      expect(month.days.keys, [5, 17, 18, 19]);
      expect(month.studiedDays, 4);
      expect(month.newCount, 3);
      expect(month.reviewedCount, 1);
      expect(month.learnedCount, 1);
      expect(month.listenedCount, 2);
      expect((month.correct, month.attempts), (3, 5));
      expect(controller.monthSummary(2026, 9).studiedDays, 0);
      expect(controller.startedCount, 3);
    });
  });

  group('Activity records', () {
    test('opening a learn card is recorded once, never as an answer', () async {
      final store = MemoryStore();
      final controller = await open(store);
      await controller.start(deck: vocabulary.decks.first);
      expect(await controller.reveal(), isTrue);
      expect(await controller.reveal(), isTrue, reason: 'already open');
      expect(controller.events, isEmpty);
      expect(controller.progress, isEmpty);
      expect(store.snapshot.activities, hasLength(1));
      expect(store.snapshot.activities.single.kind, ActivityKind.learn);
      expect(store.snapshot.session!.revealed, isTrue);
      expect(controller.activeDays, {'2026-10-19'});
      expect(controller.daySummary(today).learnedIds, [
        controller.session!.currentId,
      ]);
    });

    test('a failed learn record leaves the card closed', () async {
      final store = MemoryStore();
      final controller = await open(store);
      await controller.start(deck: vocabulary.decks.first);
      store.failNextWrite = true;
      expect(await controller.reveal(), isFalse);
      expect(controller.session!.revealed, isFalse);
      expect(controller.activities, isEmpty);
    });

    test('heard words are saved, and a failed save is skipped', () async {
      final store = MemoryStore();
      final controller = await open(store);
      await controller.recordListen('achieve');
      store.failNextWrite = true;
      await controller.recordListen('practice');
      expect(controller.activities.map((a) => a.wordId), ['achieve']);
      expect(store.snapshot.activities.map((a) => a.wordId), ['achieve']);
      expect(controller.events, isEmpty);
    });
  });

  testWidgets('a day in the week opens what was studied that day', (
    tester,
  ) async {
    final controller = await open(history());
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('week-2026-10-19')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('week-2026-10-19')));
    await tester.pumpAndSettle();
    expect(find.text('10월 19일 월요일'), findsOneWidget);
    expect(find.text('오후 7:00 – 오후 7:31'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('헷갈린 단어 2개'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 2 · 50%'), findsOneWidget);

    await tapText(tester, '헷갈린 단어 2개 다시 시험');
    expect(controller.session!.practice, isTrue);
    expect(controller.session!.wordIds.toSet(), {'achieve', 'practice'});
    expect(controller.session!.learningWordIds, isEmpty, reason: 'test only');
    expect(find.text('뜻 떠올리기'), findsWidgets, reason: 'study screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the records tab shows the month and earlier months', (
    tester,
  ) async {
    final controller = await open(history());
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('2026년 10월'), 200);
    expect(find.byTooltip('다음 달'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('10월 합계'), 200);
    expect(find.text('10월 합계'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('day-2026-10-05')));
    await tester.tap(find.byKey(const ValueKey('day-2026-10-05')));
    await tester.pumpAndSettle();
    expect(find.text('10월 5일 월요일'), findsOneWidget);
    expect(find.text('헷갈린 단어 2개'), findsNothing);
    Navigator.of(tester.element(find.text('10월 5일 월요일'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('9월에는 아직 공부 기록이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
