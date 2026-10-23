import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/application/study_nudges.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/study_settings.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';
import 'package:focus_voca/ui/deck_screen.dart';
import 'package:focus_voca/ui/focus_theme.dart';
import 'package:focus_voca/ui/settings_screen.dart';

import 'support/memory_store.dart';
import 'widget_test.dart' show FakeSpeech, tapText;

class FakeNudges implements StudyNudges {
  FakeNudges({this.granted = true});
  final bool granted;
  int asked = 0;
  @override
  Future<bool> requestPermission() async {
    asked++;
    return granted;
  }

  @override
  Future<void> refresh(LearningController controller) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  var clock = DateTime(2026, 10, 19, 10);
  setUp(() => clock = DateTime(2026, 10, 19, 10));

  Future<LearningController> open(MemoryStore store) async {
    final controller = LearningController(
      vocabulary: vocabulary,
      store: store,
      clock: () => clock,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return controller;
  }

  var serial = 0;
  ReviewEvent answer(
    String id,
    DateTime at, {
    bool correct = true,
    StudyMode mode = StudyMode.recall,
  }) => ReviewEvent(
    id: 'e${serial++}',
    wordId: id,
    mode: mode,
    correct: correct,
    practice: false,
    at: at,
  );

  group('Study settings', () {
    test('saved settings shape today and the round size', () async {
      final store = MemoryStore();
      final controller = await open(store);
      expect(controller.todayIds, hasLength(5));
      expect(
        await controller.updateSettings(
          const StudySettings(dailyNewLimit: 10, sessionSize: 10),
        ),
        isTrue,
      );
      expect(controller.todayIds, hasLength(10));
      expect(await controller.start(), isTrue);
      expect(controller.session!.wordIds, hasLength(10));
      expect(controller.session!.title, '오늘의 10개');

      final reopened = await open(store);
      expect(reopened.settings.dailyNewLimit, 10);
      expect(reopened.settings.sessionSize, 10);
    });

    test('unknown or damaged values fall back to the defaults', () {
      final settings = StudySettings.fromJson({
        'dailyNewLimit': 7,
        'sessionSize': 'ten',
        'autoPlayWord': true,
        'reminderMinutes': 99999,
      });
      expect(settings.dailyNewLimit, 20);
      expect(settings.sessionSize, 5);
      expect(settings.autoPlayWord, isTrue);
      expect(settings.reminderMinutes, 20 * 60);
      expect(StudySettings.fromJson(null).dailyNewLimit, 20);
    });

    testWidgets('the settings screen saves choices', (tester) async {
      final store = MemoryStore();
      final controller = await open(store);
      final nudges = FakeNudges();
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: SettingsScreen(controller: controller, nudges: nudges),
        ),
      );
      await tester.tap(find.text('30개'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10개').last);
      await tester.pumpAndSettle();
      await tapText(tester, '맞히면 자동으로 다음 문제');
      await tapText(tester, '매일 학습 알림');
      expect(nudges.asked, 1);
      expect(store.snapshot.settings, {
        ...const StudySettings(
          dailyNewLimit: 30,
          sessionSize: 10,
          autoAdvance: true,
          reminder: true,
        ).toJson(),
      });
      expect(find.text('오후 8:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused notification permission keeps reminders off', (
      tester,
    ) async {
      final controller = await open(MemoryStore());
      await tester.pumpWidget(
        MaterialApp(
          theme: focusTheme(Brightness.light),
          home: SettingsScreen(
            controller: controller,
            nudges: FakeNudges(granted: false),
          ),
        ),
      );
      await tapText(tester, '매일 학습 알림');
      expect(controller.settings.reminder, isFalse);
      expect(find.textContaining('알림이 꺼져 있어요'), findsOneWidget);
    });
  });

  group('Weak words', () {
    test('missed senses gather until remembered over several days', () async {
      final controller = await open(
        MemoryStore(
          initial: LearningSnapshot(
            events: [
              answer('achieve', DateTime(2026, 10, 17), correct: false),
              answer('practice', DateTime(2026, 10, 18), correct: false),
              answer('practice', DateTime(2026, 10, 18, 1)),
              answer('prepare', DateTime(2026, 10, 16), correct: false),
              answer('improve', DateTime(2026, 10, 18)),
            ],
            progress: [
              for (final mode in StudyMode.values)
                LearningProgress(
                  wordId: 'prepare',
                  mode: mode,
                  level: 3,
                  dueAt: DateTime(2026, 10, 30),
                  lastReviewedAt: DateTime(2026, 10, 18),
                ),
            ],
          ),
        ),
      );
      expect(controller.weakIds, ['achieve', 'practice']);
      expect(controller.wrongCount('practice'), 1);
      expect(controller.weakDeck.wordIds, controller.weakIds);

      expect(await controller.retestWeak(), isTrue);
      final session = controller.session!;
      expect(session.practice, isTrue);
      expect(session.learningWordIds, isEmpty);
      expect(session.stage, SessionStage.recall);
      expect(session.title, '헷갈린 단어 다시 시험');
      expect(session.wordIds.toSet(), {'achieve', 'practice'});
    });

    testWidgets('the weak words deck retests without learn cards', (
      tester,
    ) async {
      final controller = await open(
        MemoryStore(
          initial: LearningSnapshot(
            seenHints: const ['search'],
            events: [answer('achieve', DateTime(2026, 10, 18), correct: false)],
          ),
        ),
      );
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: FakeSpeech()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weak-words')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('weak-words')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('틀린 횟수 1번'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('틀린 횟수 1번'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('틀린 단어 1개 다시 시험'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapText(tester, '틀린 단어 1개 다시 시험');
      expect(controller.session!.stage, SessionStage.recall);
      expect(find.text('뜻 떠올리기'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a word list can cover meanings or words to self-check', (
    tester,
  ) async {
    final controller = await open(MemoryStore());
    final deck = vocabulary.decks.first;
    final word = vocabulary.byId[deck.wordIds.first]!;
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
    final meaning = '${word.partOfSpeech} · ${word.meaning}';
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text(meaning), 200, scrollable: list);
    await tapText(tester, '영어만');
    expect(find.text(meaning), findsNothing);
    expect(find.text(word.term), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('뜻 보기').first,
      200,
      scrollable: list,
    );
    await tester.tap(find.text('뜻 보기').first);
    await tester.pumpAndSettle();
    expect(find.text(meaning), findsOneWidget);

    await tester.scrollUntilVisible(find.text('뜻만'), -200, scrollable: list);
    await tapText(tester, '뜻만');
    await tester.scrollUntilVisible(
      find.text('단어 보기').first,
      200,
      scrollable: list,
    );
    expect(find.text(word.term), findsNothing);
    expect(find.text(meaning), findsOneWidget);
    await tester.tap(find.text('단어 보기').first);
    await tester.pumpAndSettle();
    expect(find.text(word.term), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'words are said aloud and correct answers move on by themselves',
    (tester) async {
      final store = MemoryStore(
        initial: const LearningSnapshot(seenHints: ['search']),
      );
      final controller = await open(store);
      await controller.updateSettings(
        const StudySettings(autoPlayWord: true, autoAdvance: true),
      );
      final speech = FakeSpeech();
      await controller.start(deck: vocabulary.decks.first);
      final first = vocabulary.byId[controller.session!.currentId]!;
      await tester.pumpWidget(
        FocusVocaApp(controller: controller, speech: speech),
      );
      await tester.pumpAndSettle();
      await tapText(tester, '이어서 학습하기');
      expect(speech.utterances.last, first.term, reason: 'learn card');
      while (controller.session!.stage == SessionStage.learn) {
        await controller.reveal();
        await controller.next();
      }
      await tester.pumpAndSettle();
      final asked = vocabulary.byId[controller.session!.currentId]!;
      expect(speech.utterances.last, asked.term, reason: 'recall question');
      final position = controller.session!.position;
      await tester.scrollUntilVisible(
        find.text(asked.choiceLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(asked.choiceLabel));
      await tester.pump();
      expect(find.text('맞혔어요. 곧 다음으로 넘어가요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(controller.session!.position, position + 1);

      // Spelling must not say the answer before it is written.
      while (controller.session!.stage == SessionStage.recall) {
        await controller.answer(recalled: false, input: 'x');
        await controller.next();
      }
      await tester.pumpAndSettle();
      final spoken = speech.utterances.length;
      expect(controller.session!.stage, SessionStage.spelling);
      expect(speech.utterances.length, spoken);
      final spelled = vocabulary.byId[controller.session!.currentId]!;
      await tester.enterText(find.byKey(const Key('spelling-input')), 'zzz');
      await tester.pump();
      await tapText(tester, '정답 확인');
      expect(speech.utterances.last, spelled.term, reason: 'after answering');
      expect(find.text('맞혔어요. 곧 다음으로 넘어가요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('Reminders and widget', () {
    test('nothing is planned while reminders are off', () async {
      final controller = await open(MemoryStore());
      expect(planReminders(controller), isEmpty);
    });

    test('a week of reminders, skipping today once studied', () async {
      final store = MemoryStore(
        initial: LearningSnapshot(
          events: [answer('achieve', DateTime(2026, 10, 18, 9))],
          progress: [
            for (final mode in StudyMode.values)
              LearningProgress(
                wordId: 'achieve',
                mode: mode,
                level: 1,
                dueAt: DateTime(2026, 10, 20),
                lastReviewedAt: DateTime(2026, 10, 18, 9),
              ),
          ],
        ),
      );
      final controller = await open(store);
      await controller.updateSettings(
        const StudySettings(reminder: true, reminderMinutes: 20 * 60 + 30),
      );
      var plans = planReminders(controller);
      expect(plans, hasLength(7));
      expect(plans.first.at, DateTime(2026, 10, 19, 20, 30));
      expect(plans.first.body, '오늘의 새 단어 20개, 5개씩 가볍게 시작해요.');
      expect(plans[1].body, '복습 1개와 새 단어 20개가 기다려요. 5개씩 가볍게 시작해요.');

      clock = DateTime(2026, 10, 19, 21);
      expect(planReminders(controller).first.at.day, 20, reason: 'time passed');

      clock = DateTime(2026, 10, 19, 10);
      await controller.recordListen('practice');
      plans = planReminders(controller);
      expect(plans.first.at.day, 20, reason: 'already studied today');
    });

    test('the widget shows what is left today and the streak', () async {
      final controller = await open(MemoryStore());
      final summary = widgetSummary(controller);
      expect(summary.count, 20);
      expect(summary.headline, '복습 0개 · 새 단어 20개');
      expect(summary.streak, '0일 연속');
    });
  });
}
