import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/application/review_prompt.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';

import 'support/memory_store.dart';
import 'widget_test.dart' show FakeSpeech;

class CountingReviews implements ReviewPrompt {
  int requests = 0;
  @override
  Future<void> request() async => requests++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Vocabulary vocabulary;
  setUpAll(() async {
    vocabulary = await Vocabulary.load();
  });

  const deck = WordDeck(
    id: 'one-word-test',
    title: '한 단어',
    subtitle: '리뷰 요청 검증',
    wordIds: ['achieve'],
  );

  late DateTime clock;
  late MemoryStore store;
  late LearningController controller;

  setUp(() async {
    clock = DateTime(2026, 10, 15, 10);
    store = MemoryStore();
    controller = LearningController(
      vocabulary: vocabulary,
      store: store,
      clock: () => clock,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
  });

  Future<void> studyOneRound() async {
    expect(await controller.start(deck: deck), isTrue);
    while (!controller.session!.complete) {
      final session = controller.session!;
      if (session.stage == SessionStage.spelling) {
        expect(await controller.answer(input: 'achieve'), isTrue);
      } else {
        expect(await controller.reveal(), isTrue);
        if (session.stage == SessionStage.recall) {
          expect(await controller.answer(recalled: true), isTrue);
        }
      }
      expect(await controller.next(), isTrue);
    }
  }

  test('a rating is due only as a round ends on the third day', () async {
    await studyOneRound();
    expect(controller.reviewRequestDue, isFalse, reason: 'first day');
    expect(await controller.finish(), isTrue);

    clock = clock.add(const Duration(days: 1));
    await studyOneRound();
    expect(controller.reviewRequestDue, isFalse, reason: 'second day');
    expect(await controller.finish(), isTrue);

    clock = clock.add(const Duration(days: 1));
    expect(await controller.start(deck: deck), isTrue);
    expect(controller.reviewRequestDue, isFalse, reason: 'mid-round');
    expect(await controller.finish(), isTrue);
    await studyOneRound();
    expect(controller.activeDays, hasLength(3));
    expect(controller.reviewRequestDue, isTrue);

    await controller.markHintSeen(LearningController.reviewHint);
    expect(controller.reviewRequestDue, isFalse);
    expect(store.snapshot.seenHints, [LearningController.reviewHint]);
  });

  testWidgets('the app asks the store once, after the result settles', (
    tester,
  ) async {
    for (var day = 0; day < 2; day++) {
      await studyOneRound();
      await controller.finish();
      clock = clock.add(const Duration(days: 1));
    }
    final reviews = CountingReviews();
    await tester.pumpWidget(
      FocusVocaApp(
        controller: controller,
        speech: FakeSpeech(),
        reviews: reviews,
      ),
    );

    await studyOneRound();
    await tester.pump();
    expect(reviews.requests, 0, reason: 'waits for the result screen');
    await tester.pump(const Duration(seconds: 2));
    expect(reviews.requests, 1);

    await controller.finish();
    await studyOneRound();
    await tester.pump(const Duration(seconds: 2));
    expect(reviews.requests, 1, reason: 'never asked twice');
  });
}
