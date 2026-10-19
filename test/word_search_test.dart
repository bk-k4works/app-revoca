import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/application/learning_controller.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/main.dart';

import 'support/memory_store.dart';
import 'widget_test.dart' show FakeSpeech, tapText;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Sense sense(
    String id,
    String term,
    String meaning, {
    String? headword,
    List<String> spellings = const [],
  }) => Sense(
    id: id,
    headword: Headword(
      id: headword ?? term,
      term: term,
      acceptedSpellings: [term, ...spellings],
    ),
    pos: 'v',
    meaning: meaning,
  );

  final words = [
    sense('earn.money', 'earn', '(돈을) 벌다'),
    sense('earn.respect', 'earn', '(노력으로) 얻다'),
    sense('learn', 'learn', '배우다'),
    sense('earnest', 'earnest', '진지한'),
    sense('study', 'study', '공부하다; 연구하다'),
    sense('run', 'run', '운영하다'),
    sense('look-after', 'look after', '돌보다'),
    sense('after', 'after', '~ 후에'),
    sense('practice', 'practice', '연습하다', spellings: ['practise']),
    sense('obtain', 'obtain', '얻다'),
  ];
  final vocabulary = Vocabulary(
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
  );
  List<String> ids(String query) =>
      vocabulary.search(query).map((w) => w.id).toList();

  group('Word search', () {
    test('an exact word comes first, then words that start with it', () {
      expect(ids('earn'), ['earn.money', 'earn.respect', 'earnest', 'learn']);
      expect(ids(' EARN '), ids('earn'));
    });

    test('a word inside a phrase ranks before a match inside a word', () {
      expect(ids('after'), ['after', 'look-after']);
      expect(ids('look after'), ['look-after']);
    });

    test('accepted spellings and inflected forms find the headword', () {
      expect(ids('practise'), ['practice']);
      expect(ids('earned'), ['earn.money', 'earn.respect']);
      expect(ids('studies'), ['study']);
      expect(ids('running'), ['run']);
    });

    test('Korean finds meanings without parenthesised hints or spaces', () {
      expect(ids('얻다').toSet(), {'obtain', 'earn.respect'});
      expect(ids('벌다'), ['earn.money']);
      expect(ids('연구'), ['study']);
      expect(ids('후에'), ['after']);
    });

    test('blank or unknown queries find nothing', () {
      expect(ids(''), isEmpty);
      expect(ids('  '), isEmpty);
      expect(ids('.'), isEmpty);
      expect(ids('xylophone'), isEmpty);
    });
  });

  testWidgets('search from the app bar opens a word and saves it', (
    tester,
  ) async {
    final bundled = await Vocabulary.load();
    final store = MemoryStore();
    final controller = LearningController(
      vocabulary: bundled,
      store: store,
      clock: () => DateTime(2026, 10, 19, 10),
    );
    await controller.initialize();
    await tester.pumpWidget(
      FocusVocaApp(controller: controller, speech: FakeSpeech()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('단어 찾기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('word-search')), 'achieved');
    await tester.pumpAndSettle();
    final achieve = bundled.byId['achieve']!;
    expect(find.text(achieve.term), findsOneWidget);
    expect(find.text('${bundled.decks.first.title} · 새 단어'), findsOneWidget);

    await tester.tap(find.byTooltip('시험 범위에 담기').first);
    await tester.pumpAndSettle();
    expect(controller.examWordIds, ['achieve']);
    expect(store.snapshot.examWordIds, ['achieve']);

    await tapText(tester, '${achieve.partOfSpeech} · ${achieve.meaning}');
    expect(find.text('함께 기억해요'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('word-search')), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('목록에 없는 단어예요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
