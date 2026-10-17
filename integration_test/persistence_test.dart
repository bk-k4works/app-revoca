import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/data/content_repository.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'content SQLite loads details on demand and migrates legacy history atomically',
    (tester) async {
      final content = await ContentRepository.openBundled();
      final bundled = await content.loadVocabulary();
      expect(bundled.words, hasLength(2594));
      expect(bundled.words.map((w) => w.headword.id).toSet(), hasLength(2000));
      expect(bundled.provenance['track'], 'high');
      final phrase = bundled.byId['hs.in-order-to.phrase.for-the-purpose']!;
      expect(phrase.pos, 'phrase');
      expect(phrase.accepts(' In  order to'), isTrue);
      expect(phrase.accepts('in order'), isFalse);
      expect(bundled.choicesFor(phrase), hasLength(4));
      expect(
        bundled.choicesFor(phrase).every((choice) => choice.pos == 'phrase'),
        isTrue,
      );
      // The installed package has no legacy IDs; exercise migration explicitly.
      final vocabulary = Vocabulary(
        words: bundled.words,
        decks: bundled.decks,
        provenance: bundled.provenance,
        idMigrations: {'achieve': 'hs.effort.n.attempt'},
        detailLoader: content.loadSenses,
      );
      expect(vocabulary.byId['hs.book.v.reserve']!.detailsLoaded, isFalse);
      await vocabulary.ensureDetails(vocabulary.byId.keys);
      expect(vocabulary.byId['hs.book.v.reserve']!.example, contains('booked'));
      expect(
        vocabulary.words.fold<int>(
          0,
          (n, w) => n + 1 + w.additionalExamples.length,
        ),
        5188,
      );
      expect((await content.search('analysis')).single.example, isNotEmpty);
      expect(
        (await content.loadDeck(vocabulary.decks.first.id)),
        hasLength(vocabulary.decks.first.wordIds.length),
      );
      expect((await content.search('%')).isEmpty, isTrue);
      final filename = 'content_migration_test.db';
      final dbPath = path.join(await getDatabasesPath(), filename);
      await deleteDatabase(dbPath);
      final store = await SqliteLearningStore.open(filename: filename);
      final time = DateTime(2026, 10, 16);
      const session = StudySession(
        id: 'legacy-session',
        title: '이전 학습',
        wordIds: ['achieve'],
        learningWordIds: [],
        answered: true,
        revealed: true,
        lastAnswer: 'achieve',
        answers: [StudyAnswer('achieve', StudyMode.recall, true)],
      );
      await store.saveAnswer(
        ReviewEvent(
          id: 'legacy-event',
          wordId: 'achieve',
          mode: StudyMode.recall,
          correct: true,
          practice: false,
          at: time,
        ),
        LearningProgress(
          wordId: 'achieve',
          mode: StudyMode.recall,
          level: 2,
          dueAt: time.add(const Duration(days: 3)),
          lastReviewedAt: time,
        ),
        session,
      );
      await store.saveExamWords(['achieve']);
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
      );
      await controller.initialize();
      expect(controller.events.single.wordId, 'hs.effort.n.attempt');
      expect(controller.events.single.id, 'legacy-event');
      expect(controller.examWordIds, ['hs.effort.n.attempt']);
      expect(controller.session!.lastAnswer, 'hs.effort.n.attempt');
      expect(controller.session!.answered, isTrue);
      expect(vocabulary.byId['hs.effort.n.attempt']!.example, isNotEmpty);
      expect(
        controller.stateFor('hs.effort.n.attempt', StudyMode.recall)!.level,
        2,
      );
      await store.database.close();
      final reopened = await SqliteLearningStore.open(filename: filename);
      await reopened.migrateSenseIds(
        vocabulary.idMigrations,
        vocabulary.byId.keys.toSet(),
      );
      final persisted = await reopened.load();
      expect(persisted.events, hasLength(1));
      expect(persisted.progress.single.wordId, 'hs.effort.n.attempt');
      expect(
        persisted.progress.single.dueAt,
        time.add(const Duration(days: 3)),
      );
      await reopened.migrateSenseIds(vocabulary.idMigrations, {
        'hs.book.v.reserve',
      });
      expect((await reopened.load()).session, isNull);
      expect(
        (await reopened.load()).progress.single.wordId,
        'hs.effort.n.attempt',
      );
      expect(
        (await reopened.database.query(
          'app_state',
          where: "id LIKE 'suspended_session:%'",
        )),
        hasLength(1),
      );
      await reopened.migrateSenseIds(
        vocabulary.idMigrations,
        vocabulary.byId.keys.toSet(),
      );
      expect((await reopened.load()).session!.id, 'legacy-session');
      expect((await reopened.load()).session!.answered, isTrue);
      await expectLater(
        content.database.execute('DELETE FROM senses'),
        throwsA(isA<DatabaseException>()),
      );
      await reopened.database.close();
      await content.database.close();
      controller.dispose();
      await deleteDatabase(dbPath);
    },
  );

  testWidgets(
    'high-school round completes and persists independent recall and spelling schedules',
    (tester) async {
      final content = await ContentRepository.openBundled();
      final vocabulary = await content.loadVocabulary();
      const filename = 'pilot_round_test.db';
      final dbPath = path.join(await getDatabasesPath(), filename);
      await deleteDatabase(dbPath);
      final store = await SqliteLearningStore.open(filename: filename);
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
        clock: () => DateTime(2026, 10, 16, 10),
      );
      await controller.initialize();
      final ids = [
        'hs.book.v.reserve',
        'hs.room.n.space',
        'hs.right.n.entitlement',
        'hs.right.adv.immediately',
        'hs.any.det.whatever',
      ];
      await controller.start(
        deck: WordDeck(
          id: 'pilot-test',
          title: '검증',
          subtitle: '',
          wordIds: ids,
        ),
      );
      while (controller.session!.stage == SessionStage.learn) {
        await controller.reveal();
        await controller.next();
      }
      while (controller.session!.stage == SessionStage.recall) {
        final word = vocabulary.byId[controller.session!.currentId]!;
        final choices = vocabulary.choicesFor(word);
        expect(choices.where((c) => c.id == word.id), hasLength(1));
        expect(
          choices.where(
            (c) => c.id != word.id && c.headword.id == word.headword.id,
          ),
          isEmpty,
        );
        await controller.answer(recalled: true, input: word.id);
        await controller.next();
      }
      while (!controller.session!.complete) {
        final word = vocabulary.byId[controller.session!.currentId]!;
        await controller.answer(input: word.acceptedSpellings.last);
        await controller.next();
      }
      expect(controller.session!.wrongIds, isEmpty);
      expect(controller.events, hasLength(10));
      for (final id in ids) {
        for (final mode in StudyMode.values) {
          expect(controller.stateFor(id, mode)!.dueAt, DateTime(2026, 10, 17));
        }
      }
      await store.database.close();
      controller.dispose();
      final reopened = await SqliteLearningStore.open(filename: filename);
      expect((await reopened.load()).session!.complete, isTrue);
      expect((await reopened.load()).progress, hasLength(10));
      await reopened.database.close();
      await content.database.close();
      await deleteDatabase(dbPath);
    },
  );

  testWidgets(
    'bundled synonyms are asked again in spelling instead of being marked wrong',
    (tester) async {
      final content = await ContentRepository.openBundled();
      final vocabulary = await content.loadVocabulary();
      final nevertheless = vocabulary.byId['hs.nevertheless.adv.however']!;
      final ban = vocabulary.byId['hs.ban.v.forbid']!;
      // Startup index carries synonym links without loading details.
      expect(ban.detailsLoaded, isFalse);
      expect(ban.nearSynonymHeadwords, contains('prohibit'));
      expect(
        vocabulary.synonymAnswer(nevertheless, 'nonetheless')?.id,
        'hs.nonetheless.adv.nevertheless',
      );
      expect(
        vocabulary.synonymAnswer(ban, 'prohibit')?.id,
        'hs.prohibit.v.forbid',
      );
      expect(vocabulary.synonymAnswer(ban, 'ban'), isNull);
      expect(vocabulary.synonymAnswer(ban, 'allow'), isNull);
      // The exclusion closure links change to hundreds of unrelated senses.
      final change = vocabulary.byId['hs.change.v.alter']!;
      expect(change.distractorExclusions, contains('hs.absorb.v.soak-up'));
      expect(vocabulary.synonymAnswer(change, 'absorb'), isNull);
      expect(vocabulary.synonymAnswer(change, 'alter')?.term, 'alter');

      const filename = 'synonym_spelling_test.db';
      final dbPath = path.join(await getDatabasesPath(), filename);
      await deleteDatabase(dbPath);
      final store = await SqliteLearningStore.open(filename: filename);
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
        clock: () => DateTime(2026, 10, 17, 10),
      );
      await controller.initialize();
      await controller.start(
        deck: WordDeck(
          id: 'synonym-test',
          title: '유의어',
          subtitle: '',
          wordIds: [ban.id],
        ),
      );
      await controller.reveal();
      await controller.next();
      await controller.answer(recalled: true, input: ban.id);
      await controller.next();
      expect(controller.spellingSynonym('prohibit')?.term, 'prohibit');
      await controller.answer(input: 'prohibit');
      expect(controller.session!.answered, isFalse);
      expect(controller.stateFor(ban.id, StudyMode.spelling), isNull);
      expect((await store.load()).events, hasLength(1));
      await controller.answer(input: 'ban');
      expect(controller.session!.answers.last.correct, isTrue);
      expect((await store.load()).events, hasLength(2));
      await store.database.close();
      await content.database.close();
      controller.dispose();
      await deleteDatabase(dbPath);
    },
  );

  testWidgets(
    'native SQLite restores answers, review dates and session position',
    (tester) async {
      // Isolate the test from the user's actual learning database.
      final dbPath = path.join(await getDatabasesPath(), 'persistence_test.db');
      await deleteDatabase(dbPath);
      Future<SqliteLearningStore> openStore() =>
          SqliteLearningStore.open(filename: 'persistence_test.db');

      final vocabulary = await Vocabulary.load();
      final word = vocabulary.words.first;
      DateTime clock() => DateTime(2026, 10, 15, 10);
      final firstStore = await openStore();
      final first = LearningController(
        vocabulary: vocabulary,
        store: firstStore,
        clock: clock,
      );
      await first.initialize();
      expect(await first.setExamWords([word.id]), isTrue);
      expect(await first.start(deck: first.examDeck), isTrue);
      expect(await first.reveal(), isTrue);
      expect(await first.next(), isTrue);
      expect(await first.answer(recalled: true, input: word.id), isTrue);
      final sessionId = first.session!.id;
      await firstStore.database.close();
      first.dispose();

      final secondStore = await openStore();
      final second = LearningController(
        vocabulary: vocabulary,
        store: secondStore,
        clock: clock,
      );
      await second.initialize();
      expect(second.examWordIds, [word.id]);
      expect(second.session!.id, sessionId);
      expect(second.session!.stage, SessionStage.recall);
      expect(second.session!.answered, isTrue);
      expect(second.session!.lastAnswer, word.id);
      expect(second.events.length, 1);
      expect(
        second.stateFor(word.id, StudyMode.recall)!.dueAt,
        DateTime(2026, 10, 16),
      );
      expect(second.stateFor(word.id, StudyMode.spelling), isNull);
      await second.answer(recalled: true, input: word.id);
      expect(
        second.events.length,
        1,
        reason: 'restored answers cannot be submitted twice',
      );
      expect(await second.next(), isTrue);
      expect(second.session!.stage, SessionStage.spelling);
      await second.answer(input: 'incorrect');
      expect(second.stateFor(word.id, StudyMode.spelling)!.level, 0);
      expect((await secondStore.load()).events.length, 2);
      await secondStore.database.close();
      second.dispose();
      await deleteDatabase(dbPath);
    },
  );
}
