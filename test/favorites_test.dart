import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/data/learning_store.dart';
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

  Future<LearningController> open(MemoryStore store) async {
    final controller = LearningController(
      vocabulary: vocabulary,
      store: store,
      clock: () => DateTime(2026, 10, 19, 10),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    return controller;
  }

  group('Favorites', () {
    test('starring keeps the newest first and survives a restart', () async {
      final store = MemoryStore();
      final controller = await open(store);
      expect(await controller.toggleFavorite('achieve'), isTrue);
      expect(await controller.toggleFavorite('practice'), isTrue);
      expect(controller.favoriteDeck.wordIds, ['practice', 'achieve']);
      expect(controller.decks.map((d) => d.id), contains('my-favorites'));

      expect(await controller.toggleFavorite('achieve'), isTrue);
      expect(controller.isFavorite('achieve'), isFalse);

      final reopened = await open(store);
      expect(reopened.favoriteWordIds, ['practice']);
    });

    test('a failed save leaves the stars as they were', () async {
      final store = MemoryStore()..failNextWrite = true;
      final controller = await open(store);
      expect(await controller.toggleFavorite('achieve'), isFalse);
      expect(controller.favoriteWordIds, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('stars on senses missing from this release are kept', () async {
      final store = MemoryStore(
        initial: const LearningSnapshot(
          favoriteWordIds: ['removed-sense', 'achieve'],
        ),
      );
      final controller = await open(store);
      expect(controller.favoriteWordIds, ['achieve']);
      await controller.toggleFavorite('practice');
      expect(store.snapshot.favoriteWordIds, [
        'practice',
        'achieve',
        'removed-sense',
      ]);
    });
  });

  testWidgets('a star on the learn card fills the favorites deck', (
    tester,
  ) async {
    final store = MemoryStore(
      initial: const LearningSnapshot(seenHints: ['search']),
    );
    final controller = await open(store);
    final word = vocabulary.decks.first.wordIds.first;
    await controller.start(deck: vocabulary.decks.first);
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tapText(tester, '이어서 학습하기');
    await tester.tap(find.byKey(ValueKey('favorite-$word')));
    await tester.pumpAndSettle();
    expect(controller.favoriteWordIds, [word]);
    expect(find.byTooltip('즐겨찾기에서 빼기'), findsOneWidget);

    await tester.tap(find.byTooltip('나중에 이어하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('단어장'));
    await tester.pumpAndSettle();
    await tapText(tester, '즐겨찾기');
    expect(find.text(vocabulary.byId[word]!.term), findsOneWidget);
    expect(find.text('5개 학습하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the search button is pointed out once, on first launch', (
    tester,
  ) async {
    final store = MemoryStore();
    final first = await open(store);
    expect(first.searchHintPending, isTrue);
    await tester.pumpWidget(
      FocusVocaApp(controller: first, speech: FakeSpeech()),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('단어 찾기'), findsOneWidget, reason: 'labelled pill');
    await tester.pumpAndSettle();
    expect(find.text('단어 찾기'), findsNothing, reason: 'folded to the icon');
    expect(store.snapshot.seenHints, ['search']);

    final second = await open(store);
    expect(second.searchHintPending, isFalse);
    await tester.pumpWidget(
      FocusVocaApp(
        key: const ValueKey('second'),
        controller: second,
        speech: FakeSpeech(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('단어 찾기'), findsNothing);
    expect(find.byTooltip('단어 찾기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the highlighted button opens search and ends it', (
    tester,
  ) async {
    final store = MemoryStore();
    final controller = await open(store);
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('단어 찾기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('word-search')), findsOneWidget);
    expect(controller.searchHintPending, isFalse);
    expect(store.snapshot.seenHints, ['search']);
  });
}
