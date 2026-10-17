import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';

import 'support/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  group('Review schedule', () {
    test(
      'same-day and early repetition cannot advance an existing schedule',
      () {
        final reviewedAt = DateTime(2026, 10, 15, 9);
        final previous = LearningProgress(
          wordId: 'achieve',
          mode: StudyMode.recall,
          level: 2,
          dueAt: DateTime(2026, 10, 18),
          lastReviewedAt: reviewedAt,
        );

        for (final time in [
          DateTime(2026, 10, 15, 18),
          DateTime(2026, 10, 17, 23, 59),
        ]) {
          for (final correct in [true, false]) {
            final result = ReviewScheduler.apply(
              wordId: previous.wordId,
              mode: previous.mode,
              correct: correct,
              practice: false,
              now: time,
              previous: previous,
            );
            expect(result?.toJson(), previous.toJson());
          }
        }
      },
    );

    test(
      'a due success advances once and a repeat cannot advance it again',
      () {
        final dueAt = DateTime(2026, 10, 18);
        final previous = LearningProgress(
          wordId: 'achieve',
          mode: StudyMode.spelling,
          level: 2,
          dueAt: dueAt,
          lastReviewedAt: DateTime(2026, 10, 15, 9),
        );
        final result = ReviewScheduler.apply(
          wordId: previous.wordId,
          mode: previous.mode,
          correct: true,
          practice: false,
          now: dueAt,
          previous: previous,
        )!;
        expect(result.level, 3);
        expect(result.dueAt.isAfter(previous.dueAt), isTrue);

        final repeated = ReviewScheduler.apply(
          wordId: result.wordId,
          mode: result.mode,
          correct: true,
          practice: false,
          now: dueAt.add(const Duration(hours: 1)),
          previous: result,
        );
        expect(repeated?.toJson(), result.toJson());
      },
    );

    test(
      'a due failure removes mastery and immediate practice cannot restore it',
      () {
        final time = DateTime(2026, 10, 15, 10);
        final previous = LearningProgress(
          wordId: 'achieve',
          mode: StudyMode.recall,
          level: 3,
          dueAt: DateTime(2026, 10, 15),
          lastReviewedAt: DateTime(2026, 10, 8, 9),
          lapses: 1,
        );
        final failed = ReviewScheduler.apply(
          wordId: previous.wordId,
          mode: previous.mode,
          correct: false,
          practice: false,
          now: time,
          previous: previous,
        )!;
        expect(failed.level, 0);
        expect(failed.established, isFalse);
        expect(failed.lapses, 2);
        expect(failed.dueAt, DateTime(2026, 10, 16));

        final retry = ReviewScheduler.apply(
          wordId: failed.wordId,
          mode: failed.mode,
          correct: true,
          practice: true,
          now: time.add(const Duration(minutes: 1)),
          previous: failed,
        );
        expect(retry?.toJson(), failed.toJson());
        expect(
          ReviewScheduler.apply(
            wordId: 'practice',
            mode: StudyMode.recall,
            correct: true,
            practice: true,
            now: time,
          ),
          isNull,
          reason: 'Practice alone must not create a mastered learning state.',
        );
      },
    );
  });

  group('Learning persistence and sessions', () {
    late MemoryStore store;
    late LearningController controller;
    late DateTime clock;

    setUp(() async {
      clock = DateTime(2026, 10, 15, 10);
      store = MemoryStore();
      controller = LearningController(
        vocabulary: vocabulary,
        store: store,
        clock: () => clock,
      );
      await controller.initialize();
    });

    tearDown(() {
      controller.dispose();
    });

    WordDeck oneWordDeck() => const WordDeck(
      id: 'one-word-test',
      title: '한 단어',
      subtitle: '학습 상태 검증',
      wordIds: ['achieve'],
    );

    Future<void> revealAndContinueLearning() async {
      while (controller.session!.stage == SessionStage.learn &&
          !controller.session!.complete) {
        expect(await controller.reveal(), isTrue);
        expect(await controller.next(), isTrue);
      }
    }

    Future<LearningController> controllerWithDueWord() async {
      final seededStore = MemoryStore(
        initial: LearningSnapshot(
          progress: [
            for (final mode in StudyMode.values)
              LearningProgress(
                wordId: 'achieve',
                mode: mode,
                level: 2,
                dueAt: DateTime(2026, 10, 15),
                lastReviewedAt: DateTime(2026, 10, 12, 10),
              ),
          ],
        ),
      );
      final seededController = LearningController(
        vocabulary: vocabulary,
        store: seededStore,
        clock: () => clock,
      );
      addTearDown(seededController.dispose);
      await seededController.initialize();
      return seededController;
    }

    test('learning five cards creates no review events or mastery', () async {
      expect(await controller.start(), isTrue);
      expect(controller.session!.wordIds, hasLength(5));

      for (var index = 0; index < 5; index++) {
        expect(controller.session!.stage, SessionStage.learn);
        await controller.answer(recalled: true);
        expect(controller.session!.answered, isFalse);
        expect(await controller.reveal(), isTrue);
        expect(await controller.next(), isTrue);
        expect(controller.events, isEmpty);
        expect(controller.progress, isEmpty);
      }

      expect(controller.session!.stage, SessionStage.recall);
      expect(controller.session!.position, 5);
      expect(controller.studiedToday, isEmpty);
      final stored = await store.load();
      expect(stored.events, isEmpty);
      expect(stored.progress, isEmpty);
      expect(stored.session!.position, 5);
    });

    test(
      'due-only study starts at recall without exposing answers first',
      () async {
        final dueController = await controllerWithDueWord();
        expect(await dueController.start(deck: oneWordDeck()), isTrue);
        final session = dueController.session!;

        expect(session.learningWordIds, isEmpty);
        expect(session.wordIds, ['achieve']);
        expect(session.total, 2);
        expect(session.stage, SessionStage.recall);
        expect(session.currentId, 'achieve');
        expect(session.stageIndex, 0);
        expect(session.stageCount, 1);
        expect(session.step, 1);
        expect(session.revealed, isFalse);
        expect(session.answered, isFalse);
        expect(session.practice, isFalse);
        expect(session.answers, isEmpty);
        expect(dueController.events, isEmpty);

        // The learner must attempt this recall item before moving past it.
        await dueController.next();
        expect(dueController.session!.position, 0);
        expect(dueController.session!.revealed, isFalse);
        final stored = await dueController.store.load();
        expect(stored.session!.learningWordIds, isEmpty);
        expect(stored.session!.stage, SessionStage.recall);
        expect(stored.session!.revealed, isFalse);
      },
    );

    test(
      'mixed study learns only new words then recalls both new and due words',
      () async {
        final mixedController = await controllerWithDueWord();
        const mixedDeck = WordDeck(
          id: 'mixed-test',
          title: '새 단어와 복습',
          subtitle: '익히기 대상 분리 검증',
          wordIds: ['practice', 'achieve'],
        );
        expect(await mixedController.start(deck: mixedDeck), isTrue);
        expect(mixedController.session!.wordIds, ['achieve', 'practice']);
        expect(mixedController.session!.learningWordIds, ['practice']);
        expect(mixedController.session!.total, 5);
        expect(mixedController.session!.stage, SessionStage.learn);
        expect(mixedController.session!.currentId, 'practice');
        expect(mixedController.session!.stageCount, 1);
        expect(mixedController.session!.step, 1);

        expect(await mixedController.reveal(), isTrue);
        expect(await mixedController.next(), isTrue);
        expect(mixedController.session!.stage, SessionStage.recall);
        expect(mixedController.session!.currentId, 'achieve');
        expect(mixedController.session!.stageCount, 2);
        expect(mixedController.session!.step, 1);
        expect(mixedController.session!.revealed, isFalse);
        expect(mixedController.events, isEmpty);

        // The shorter learning phase must survive persistence without offset drift.
        final restored = LearningController(
          vocabulary: vocabulary,
          store: mixedController.store,
          clock: () => clock,
        );
        addTearDown(restored.dispose);
        await restored.initialize();
        expect(restored.session!.learningWordIds, ['practice']);
        expect(restored.session!.currentId, 'achieve');
        expect(restored.session!.stageIndex, 0);

        final recalledIds = <String>[];
        for (var index = 0; index < 2; index++) {
          expect(restored.session!.stage, SessionStage.recall);
          expect(restored.session!.step, index + 1);
          expect(restored.session!.revealed, isFalse);
          recalledIds.add(restored.session!.currentId);
          expect(await restored.reveal(), isTrue);
          expect(await restored.answer(recalled: true), isTrue);
          expect(await restored.next(), isTrue);
        }
        expect(recalledIds, ['achieve', 'practice']);
        expect(restored.events.map((event) => event.wordId), recalledIds);
        expect(restored.session!.stage, SessionStage.spelling);
        expect(restored.session!.currentId, 'achieve');
        expect(restored.session!.stageCount, 2);
        expect(restored.session!.step, 1);
        expect(restored.session!.revealed, isFalse);
      },
    );

    test('recall and spelling keep independent due dates and levels', () async {
      expect(await controller.start(deck: oneWordDeck()), isTrue);
      await revealAndContinueLearning();
      expect(await controller.reveal(), isTrue);
      expect(await controller.answer(recalled: true), isTrue);
      final recallBefore = controller.stateFor('achieve', StudyMode.recall)!;
      expect(controller.stateFor('achieve', StudyMode.spelling), isNull);
      expect(await controller.next(), isTrue);

      clock = clock.add(const Duration(days: 1));
      expect(controller.session!.stage, SessionStage.spelling);
      expect(await controller.answer(input: 'achieve'), isTrue);
      final spelling = controller.stateFor('achieve', StudyMode.spelling)!;
      final recallAfter = controller.stateFor('achieve', StudyMode.recall)!;
      expect(recallAfter.toJson(), recallBefore.toJson());
      expect(spelling.dueAt, isNot(recallAfter.dueAt));
      expect(spelling.level, 1);
      expect(controller.progress, hasLength(2));
      expect(controller.events.map((e) => e.mode), [
        StudyMode.recall,
        StudyMode.spelling,
      ]);
    });

    test(
      'wrong-answer retry records practice without increasing achievement',
      () async {
        expect(await controller.start(deck: oneWordDeck()), isTrue);
        await revealAndContinueLearning();
        await controller.reveal();
        expect(await controller.answer(recalled: false), isTrue);
        final failure = controller.stateFor('achieve', StudyMode.recall)!;
        expect(controller.session!.wrongIds, {'achieve'});
        expect(failure.level, 0);

        clock = clock.add(const Duration(minutes: 1));
        expect(await controller.start(retryIds: ['achieve']), isTrue);
        expect(controller.session!.practice, isTrue);
        await revealAndContinueLearning();
        await controller.reveal();
        expect(await controller.answer(recalled: true), isTrue);
        expect(
          controller.stateFor('achieve', StudyMode.recall)!.toJson(),
          failure.toJson(),
        );
        expect(controller.events, hasLength(2));
        expect(controller.events.last.correct, isTrue);
        expect(controller.events.last.practice, isTrue);
        expect(await controller.next(), isTrue);
        expect(await controller.answer(input: 'achieve'), isTrue);
        expect(controller.stateFor('achieve', StudyMode.spelling), isNull);
        expect(controller.events.last.practice, isTrue);
      },
    );

    test(
      'restarting restores stage, answer, wrong words and exam selection',
      () async {
        await controller.setExamWords(['achieve', 'practice']);
        await controller.start(deck: oneWordDeck());
        await revealAndContinueLearning();
        await controller.reveal();
        await controller.answer(recalled: true);
        await controller.next();
        await controller.answer(input: 'acheive');
        final expectedSession = controller.session!.toJson();

        final restored = LearningController(
          vocabulary: vocabulary,
          store: store,
          clock: () => clock,
        );
        addTearDown(restored.dispose);
        await restored.initialize();

        expect(restored.session!.toJson(), expectedSession);
        expect(restored.session!.stage, SessionStage.spelling);
        expect(restored.session!.answered, isTrue);
        expect(restored.session!.lastAnswer, 'acheive');
        expect(restored.session!.wrongIds, {'achieve'});
        expect(restored.examWordIds, ['achieve', 'practice']);
        expect(restored.events, hasLength(2));
        expect(restored.progress, hasLength(2));

        // Re-submitting a restored, already saved answer must not duplicate it.
        await restored.answer(input: 'achieve');
        expect(restored.events, hasLength(2));
        expect(restored.session!.lastAnswer, 'acheive');
        expect(await restored.next(), isTrue);
        expect(restored.session!.complete, isTrue);
      },
    );

    test(
      'answer-save failure preserves memory and allows one clean retry',
      () async {
        await controller.start(deck: oneWordDeck());
        await revealAndContinueLearning();
        await controller.reveal();
        final before = controller.session!.toJson();
        store.failNextWrite = true;

        expect(await controller.answer(recalled: true), isFalse);
        expect(controller.session!.toJson(), before);
        expect(controller.session!.answered, isFalse);
        expect(controller.events, isEmpty);
        expect(controller.progress, isEmpty);
        expect(controller.error, isNotNull);
        expect(controller.busy, isFalse);
        expect(store.snapshot.session!.toJson(), before);
        expect(store.snapshot.events, isEmpty);
        expect(store.snapshot.progress, isEmpty);

        expect(await controller.answer(recalled: true), isTrue);
        expect(controller.error, isNull);
        expect(controller.session!.answered, isTrue);
        expect(controller.events, hasLength(1));
        expect(controller.progress, hasLength(1));
        expect(store.snapshot.events, hasLength(1));
        expect(store.snapshot.progress, hasLength(1));
      },
    );

    test('failed position save does not skip a card on resume', () async {
      await controller.start();
      await controller.reveal();
      final before = controller.session!.toJson();
      store.failNextWrite = true;

      expect(await controller.next(), isFalse);
      expect(controller.session!.toJson(), before);
      expect(store.snapshot.session!.toJson(), before);
      expect(await controller.next(), isTrue);
      expect(controller.session!.position, 1);
      expect(store.snapshot.session!.position, 1);
    });

    test(
      'memory store loads independent snapshots and simulates atomic writes',
      () async {
        await controller.setExamWords(['achieve']);
        await controller.start();
        final detached = await store.load();
        detached.examWordIds.add('practice');
        detached.session!.wordIds.clear();
        final unchanged = await store.load();
        expect(unchanged.examWordIds, ['achieve']);
        expect(unchanged.session!.wordIds, hasLength(5));

        store.failNextWrite = true;
        await expectLater(store.saveExamWords(['practice']), throwsStateError);
        expect(store.snapshot.examWordIds, ['achieve']);
        await store.saveExamWords(['practice']);
        expect(store.snapshot.examWordIds, ['practice']);
      },
    );
  });

  test(
    'a synonym in spelling is not graded and the question stays open',
    () async {
      Sense word(
        String term,
        String meaning, {
        List<String> synonyms = const [],
      }) => Sense(
        id: term,
        headword: Headword(id: term, term: term, acceptedSpellings: [term]),
        pos: 'v',
        meaning: meaning,
        collocation: '$term it',
        nearSynonymHeadwords: synonyms,
      );
      final words = [
        word('ban', '금지하다', synonyms: ['forbid']),
        word('forbid', '금하다'),
      ];
      final deck = WordDeck(
        id: 'synonyms',
        title: '유의어',
        subtitle: '',
        wordIds: ['ban'],
      );
      final store = MemoryStore();
      final controller = LearningController(
        vocabulary: Vocabulary(words: words, decks: [deck], provenance: {}),
        store: store,
        clock: () => DateTime(2026, 10, 17, 10),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.start(deck: deck);
      expect(
        controller.spellingSynonym('forbid'),
        isNull,
        reason: 'learn stage',
      );
      await controller.reveal();
      await controller.next();
      await controller.answer(recalled: true, input: 'ban');
      await controller.next();
      expect(controller.session!.stage, SessionStage.spelling);

      expect(controller.spellingSynonym(' Forbid')?.term, 'forbid');
      expect(await controller.answer(input: 'forbid'), isTrue);
      expect(controller.session!.answered, isFalse);
      expect(
        controller.events.where((e) => e.mode == StudyMode.spelling),
        isEmpty,
      );
      expect(controller.stateFor('ban', StudyMode.spelling), isNull);
      expect(store.snapshot.events, hasLength(1));

      expect(controller.spellingSynonym('ban'), isNull);
      expect(await controller.answer(input: 'ban'), isTrue);
      expect(controller.session!.answered, isTrue);
      expect(controller.session!.answers.last.correct, isTrue);
      expect(controller.session!.wrongIds, isEmpty);
    },
  );

  group('Bundled development content', () {
    test('30 unique drafts form three complete ten-word decks', () {
      expect(vocabulary.words, hasLength(30));
      expect(vocabulary.byId, hasLength(30));
      expect(vocabulary.decks, hasLength(3));
      expect(vocabulary.decks.map((deck) => deck.id).toSet(), hasLength(3));
      expect(vocabulary.provenance['kind'], 'original_draft');
      expect(vocabulary.provenance['reviewStatus'], 'unreviewed');

      final deckWords = <String>[];
      for (final deck in vocabulary.decks) {
        expect(deck.wordIds, hasLength(10));
        expect(deck.wordIds.toSet(), hasLength(10));
        for (final id in deck.wordIds) {
          expect(vocabulary.byId.containsKey(id), isTrue);
        }
        deckWords.addAll(deck.wordIds);
      }
      expect(deckWords, hasLength(30));
      expect(deckWords.toSet(), vocabulary.byId.keys.toSet());

      for (final word in vocabulary.words) {
        for (final value in [
          word.id,
          word.term,
          word.partOfSpeech,
          word.meaning,
          word.explanation,
          word.collocation,
          word.collocationMeaning,
          word.example,
          word.exampleMeaning,
        ]) {
          expect(value.trim(), isNotEmpty, reason: word.id);
        }
        expect(word.acceptedSpellings, contains(word.term));
        for (final spelling in word.acceptedSpellings) {
          expect(spelling.trim(), isNotEmpty);
          expect(word.accepts('  ${spelling.toUpperCase()}  '), isTrue);
        }
        expect(word.accepts(''), isFalse);
        expect(word.accepts('${word.term}x'), isFalse);
      }
    });

    test(
      'intentional spelling alternatives are accepted, misspellings are not',
      () {
        final practice = vocabulary.byId['practice']!;
        expect(practice.accepts('practice'), isTrue);
        expect(practice.accepts('practise'), isTrue);
        expect(practice.accepts('pratice'), isFalse);
        expect(vocabulary.byId['achieve']!.accepts('acheive'), isFalse);
      },
    );

    test('unknown word references are rejected before study can begin', () {
      expect(
        () => Vocabulary(
          words: vocabulary.words,
          decks: const [
            WordDeck(
              id: 'broken',
              title: '잘못된 단어장',
              subtitle: '잘못된 참조',
              wordIds: ['unknown_word'],
            ),
          ],
          provenance: vocabulary.provenance,
        ),
        throwsFormatException,
      );
    });

    test('unavailable content prevents restoring an invalid session', () async {
      final store = MemoryStore(
        initial: const LearningSnapshot(
          session: StudySession(
            id: 'old-session',
            title: '이전 세션',
            wordIds: ['removed_word'],
          ),
        ),
      );
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
      );
      addTearDown(controller.dispose);
      await expectLater(controller.initialize(), throwsFormatException);
    });
  });
}
