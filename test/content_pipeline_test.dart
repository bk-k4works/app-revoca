import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_voca/data/learning_store.dart';
import 'package:focus_voca/domain/audio_asset.dart';
import 'package:focus_voca/domain/learning.dart';
import 'package:focus_voca/domain/vocabulary.dart';
import 'package:focus_voca/services/audio_pack_service.dart';
import 'package:focus_voca/services/content_speech_service.dart';
import 'package:focus_voca/services/speech_service.dart';

class TestSpeech implements SpeechService {
  final List<String> spoken = [];
  @override
  Future<void> speak(
    String text, {
    String language = 'en-US',
    double rate = .45,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class TestPlayer implements RecordedAudioPlayer {
  final List<String> played = [];
  bool fail = false;
  Completer<void>? nextStop;
  @override
  Future<void> play(String file, double rate) async {
    if (fail) throw StateError('player failed');
    played.add(file);
  }

  @override
  Future<void> stop() async {
    final pending = nextStop;
    nextStop = null;
    await pending?.future;
  }
}

Sense sense(
  String id,
  String meaning, {
  String pos = 'v',
  List<String> excluded = const [],
  List<String> alternatives = const [],
}) => Sense(
  id: id,
  headword: Headword(id: id, term: id, acceptedSpellings: [id]),
  pos: pos,
  meaning: meaning,
  distractorExclusions: excluded,
  meaningAlternatives: alternatives,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spelling accepts phrases with extra spaces and curly apostrophes', () {
    final phrase = Sense(
      id: 'p',
      headword: const Headword(
        id: 'p',
        term: 'in order to',
        acceptedSpellings: ['in order to', "o'clock"],
      ),
      pos: 'phrase',
      meaning: '~하기 위해',
    );
    expect(phrase.accepts('In  Order   to '), isTrue);
    expect(phrase.accepts('o\u2019clock'), isTrue);
    expect(phrase.accepts('in order'), isFalse);
    expect(phrase.accepts('inorderto'), isFalse);
  });

  test(
    'meaning choices exclude synonyms both ways, match POS and prefer similar length',
    () {
      final words = [
        sense(
          'achieve.v.goal',
          '달성하다',
          alternatives: ['성취하다'],
          excluded: ['accomplish'],
        ),
        sense('accomplish', '완수하다'),
        sense('attain', '성취하다'),
        sense('noun', '달성', pos: 'n'),
        sense('reverse', '끝내다', excluded: ['achieve.v.goal']),
        sense('a', '아주 길고 복잡한 뜻풀이'),
        sense('b', '준비하다'),
        sense('c', '생각하다'),
        sense('d', '비교하다'),
      ];
      final vocabulary = Vocabulary(
        words: words,
        decks: [
          WordDeck(
            id: 'deck',
            title: '',
            subtitle: '',
            wordIds: words.map((w) => w.id).toList(),
          ),
        ],
        provenance: {},
      );
      expect(vocabulary.choicesFor(words.first).map((w) => w.id).toSet(), {
        'achieve.v.goal',
        'b',
        'c',
        'd',
      });
    },
  );

  group('spelling synonyms', () {
    Sense word(
      String term,
      String pos,
      String meaning, {
      List<String> alternatives = const [],
      List<String> excluded = const [],
      List<String> synonyms = const [],
    }) => Sense(
      id: '$term.$pos',
      headword: Headword(id: term, term: term, acceptedSpellings: [term]),
      pos: pos,
      meaning: meaning,
      meaningAlternatives: alternatives,
      distractorExclusions: excluded,
      nearSynonymHeadwords: synonyms,
    );

    final words = [
      word('nevertheless', 'adv', '그럼에도 불구하고'),
      word('nonetheless', 'adv', '그렇더라도', alternatives: ['그럼에도 불구하고']),
      word('ban', 'v', '금지하다', synonyms: ['forbid']),
      word('forbid', 'v', '(하지 못하게) 금하다'),
      word('prohibit', 'v', '(법으로) 금지하다', synonyms: ['Ban']),
      word('affect', 'v', '영향을 주다', excluded: ['effect.v']),
      word('effect', 'v', '(결과를) 가져오다'),
      word('ban', 'n', '금지(령)'),
      word('prohibition', 'n', '금지하다'),
      word('allow', 'v', '허락하다'),
    ];
    final vocabulary = Vocabulary(
      words: words,
      decks: [
        WordDeck(
          id: 'deck',
          title: '',
          subtitle: '',
          wordIds: words.map((w) => w.id).toList(),
        ),
      ],
      provenance: {},
    );
    Sense byId(String id) => vocabulary.byId[id]!;

    test('overlapping meanings and synonym links are recognised both ways', () {
      // Meaning overlap through an alternative, in either direction.
      expect(
        vocabulary.synonymAnswer(byId('nevertheless.adv'), ' Nonetheless ')?.id,
        'nonetheless.adv',
      );
      expect(
        vocabulary.synonymAnswer(byId('nonetheless.adv'), 'nevertheless')?.id,
        'nevertheless.adv',
      );
      // nearSynonymHeadwords on either sense, compared like spellings.
      expect(vocabulary.synonymAnswer(byId('ban.v'), 'forbid')?.id, 'forbid.v');
      expect(vocabulary.synonymAnswer(byId('forbid.v'), 'ban')?.id, 'ban.v');
      expect(vocabulary.synonymAnswer(byId('prohibit.v'), 'ban')?.id, 'ban.v');
      expect(
        vocabulary.synonymAnswer(byId('ban.v'), 'prohibit')?.id,
        'prohibit.v',
      );
    });

    test(
      'correct, unrelated, other-POS and blank answers are not synonyms',
      () {
        expect(vocabulary.synonymAnswer(byId('ban.v'), 'ban'), isNull);
        expect(vocabulary.synonymAnswer(byId('ban.v'), 'allow'), isNull);
        expect(vocabulary.synonymAnswer(byId('ban.v'), 'banned'), isNull);
        expect(vocabulary.synonymAnswer(byId('ban.v'), '  '), isNull);
        // Same meaning text but a noun: the question asks for a verb.
        expect(vocabulary.synonymAnswer(byId('ban.v'), 'prohibition'), isNull);
        expect(vocabulary.synonymAnswer(byId('forbid.v'), 'allow'), isNull);
      },
    );

    test('hint reveals enough letters to differ, never the whole word', () {
      expect(Sense.spellingHint('nevertheless', 'nonetheless'), 'ne');
      expect(Sense.spellingHint('forbid', 'ban'), 'f');
      expect(Sense.spellingHint('forbid', 'for'), 'forb');
      expect(Sense.spellingHint('ban', 'banish'), 'ba');
      expect(Sense.spellingHint('a', 'b'), 'a');
    });
  });

  test(
    'migration preserves both modes, history, due dates, session state and exam scope',
    () {
      final time = DateTime(2026, 10, 16);
      final old = LearningSnapshot(
        progress: [
          for (final mode in StudyMode.values)
            LearningProgress(
              wordId: 'achieve',
              mode: mode,
              level: 3,
              dueAt: time.add(const Duration(days: 7)),
              lastReviewedAt: time,
              lapses: 2,
            ),
        ],
        events: [
          ReviewEvent(
            id: 'event',
            wordId: 'achieve',
            mode: StudyMode.recall,
            correct: true,
            practice: false,
            at: time,
          ),
        ],
        examWordIds: ['achieve'],
        session: const StudySession(
          id: 'session',
          title: 'Test',
          wordIds: ['achieve'],
          learningWordIds: [],
          position: 0,
          answered: true,
          revealed: true,
          lastAnswer: 'achieve',
          answers: [StudyAnswer('achieve', StudyMode.recall, true)],
        ),
      );
      final migrations = {
        'achieve': 'achieve.v.old',
        'achieve.v.old': 'achieve.v.goal',
      };
      final updated = migrateLearningSnapshot(old, migrations, {
        'achieve.v.goal',
      });
      expect(updated.progress.map((p) => p.wordId).toSet(), {'achieve.v.goal'});
      expect(
        updated.progress.map((p) => p.mode).toSet(),
        StudyMode.values.toSet(),
      );
      expect(updated.progress.first.dueAt, old.progress.first.dueAt);
      expect(updated.progress.first.lapses, 2);
      expect(updated.events.single.id, 'event');
      expect(updated.events.single.wordId, 'achieve.v.goal');
      expect(updated.examWordIds, ['achieve.v.goal']);
      expect(updated.session!.position, 0);
      expect(updated.session!.lastAnswer, 'achieve.v.goal');
      expect(updated.session!.answered, isTrue);
      expect(updated.session!.answers.single.wordId, 'achieve.v.goal');
      final repeated = migrateLearningSnapshot(updated, migrations, {
        'achieve.v.goal',
      });
      expect(repeated.session!.toJson(), updated.session!.toJson());
      expect(
        repeated.progress.map((p) => p.toJson()),
        updated.progress.map((p) => p.toJson()),
      );
    },
  );

  test(
    'migration keeps unavailable history, does not rewrite spelling input, rejects cycles',
    () {
      const snapshot = LearningSnapshot(
        examWordIds: ['missing'],
        session: StudySession(
          id: 's',
          title: '',
          wordIds: ['achieve'],
          learningWordIds: [],
          position: 1,
          lastAnswer: 'achieve',
          answered: true,
        ),
      );
      final updated = migrateLearningSnapshot(
        snapshot,
        {'achieve': 'achieve.v.goal', 'missing': 'not-shipped'},
        {'achieve.v.goal'},
      );
      expect(updated.examWordIds, ['missing']);
      expect(updated.session!.lastAnswer, 'achieve');
      expect(updated.session!.wordIds, ['achieve.v.goal']);
      expect(
        () => migrateLearningSnapshot(snapshot, {'a': 'b', 'b': 'a'}, {'a'}),
        throwsFormatException,
      );
    },
  );

  test(
    'many-to-one progress retains latest review rather than adding mastery',
    () {
      final now = DateTime(2026, 10, 16);
      final snapshot = LearningSnapshot(
        progress: [
          LearningProgress(
            wordId: 'old',
            mode: StudyMode.recall,
            level: 5,
            dueAt: now,
            lastReviewedAt: now.subtract(const Duration(days: 1)),
          ),
          LearningProgress(
            wordId: 'current',
            mode: StudyMode.recall,
            level: 1,
            dueAt: now,
            lastReviewedAt: now,
          ),
        ],
      );
      final updated = migrateLearningSnapshot(
        snapshot,
        {'old': 'current'},
        {'current'},
      );
      expect(updated.progress.single.level, 1);
    },
  );

  test('vocabulary loads details only for requested senses', () async {
    final requested = <String>[];
    final word = Sense(
      id: 'a',
      headword: const Headword(id: 'a', term: 'a', acceptedSpellings: ['a']),
      pos: 'v',
      meaning: '뜻',
      detailsLoaded: false,
    );
    final vocabulary = Vocabulary(
      words: [word],
      decks: const [
        WordDeck(id: 'd', title: '', subtitle: '', wordIds: ['a']),
      ],
      provenance: {},
      detailLoader: (ids) async {
        requested.addAll(ids);
        return [sense('a', '뜻')];
      },
    );
    await vocabulary.ensureDetails(['a']);
    await vocabulary.ensureDetails(['a']);
    expect(requested, ['a']);
    expect(vocabulary.byId['a']!.detailsLoaded, isTrue);
  });

  test('editorial audit matches actual app choices for all pilot senses', () {
    final snapshot =
        jsonDecode(
              File(
                'content/pilots/pilot-v1/audit-editorial-v2/snapshot.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final items = snapshot['items'] as Map<String, dynamic>;
    final words = items.values
        .map((item) => Sense.fromJson(item['content']))
        .toList();
    final vocabulary = Vocabulary(
      words: words,
      decks: [
        WordDeck(
          id: 'audit',
          title: '',
          subtitle: '',
          wordIds: words.map((w) => w.id).toList(),
        ),
      ],
      provenance: {},
    );
    expect(words, hasLength(154));
    for (final word in words) {
      final expected = items[word.id]['quiz'];
      final actual = vocabulary.choicesFor(word);
      expect(
        actual.map((w) => w.id).toList(),
        (expected['choices'] as List).map((c) => c['id']).toList(),
        reason: word.id,
      );
      expect(
        actual.length == 4 ? 'multiple_choice' : 'self_assessment',
        expected['mode'],
      );
      expect(actual.map((w) => w.meaning).toSet().length, actual.length);
    }
    for (final word in words.where(
      (w) => ['brilliant', 'neat', 'vivid'].contains(w.term),
    )) {
      expect(
        vocabulary
            .choicesFor(word)
            .where(
              (w) =>
                  w.id != word.id &&
                  ['brilliant', 'neat', 'vivid'].contains(w.term),
            ),
        isEmpty,
      );
    }
  });

  group('audio packs and fallback', () {
    late Directory directory;
    late AudioAsset asset;
    late AudioPack pack;
    late Uint8List zipBytes;
    late AudioPackService packs;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('focus-voca-test-');
      final data = Uint8List.fromList([1, 2, 3, 4]);
      final archive = Archive()
        ..addFile(ArchiveFile('audio/en/word/example.m4a', data.length, data));
      zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      asset = AudioAsset(
        id: 'achieve.v.goal:word',
        senseId: 'achieve.v.goal',
        kind: 'word',
        text: 'achieve',
        language: 'en-US',
        path: 'audio/en/word/example.m4a',
        sha256: sha256.convert(data).toString(),
        bytes: data.length,
        packId: 'deck',
      );
      pack = AudioPack(
        id: 'deck',
        sha256: sha256.convert(zipBytes).toString(),
        bytes: zipBytes.length,
        files: [
          {'path': asset.path, 'sha256': asset.sha256, 'bytes': asset.bytes},
        ],
      );
      packs = AudioPackService(
        directory: directory,
        assets: [asset],
        packs: [pack],
      );
    });
    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test(
      'stop during playback preparation cannot start a late fallback',
      () async {
        final fallback = TestSpeech();
        final player = TestPlayer();
        final pending = Completer<void>();
        player.nextStop = pending;
        final speech = ContentSpeechService(
          packs: packs,
          fallback: fallback,
          player: player,
        );
        final playback = speech.speakSense(asset.senseId, 'word', 'achieve');
        await speech.stop();
        pending.complete();
        await playback;
        expect(fallback.spoken, isEmpty);
        expect(player.played, isEmpty);
      },
    );

    test(
      'verified files install and are reused; corrupted packs fail before writing',
      () async {
        expect(await packs.isPackReady('deck'), isFalse);
        final corrupt = Uint8List.fromList(zipBytes)..[0] = 0;
        await expectLater(
          packs.installBytes(pack, corrupt),
          throwsFormatException,
        );
        expect(await packs.localPath(asset), isNull);
        await packs.installBytes(pack, zipBytes);
        expect(await packs.isPackReady('deck'), isTrue);
        expect(await packs.localPath(asset), endsWith(asset.path));
      },
    );

    test(
      'zip traversal is rejected even when the manifest contains that path',
      () async {
        final archive = Archive()
          ..addFile(ArchiveFile('../escape.m4a', 1, [1]));
        final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
        final bad = AudioPack(
          id: 'bad',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          files: [
            {
              'path': '../escape.m4a',
              'sha256': sha256.convert([1]).toString(),
              'bytes': 1,
            },
          ],
        );
        await expectLater(
          packs.installBytes(bad, bytes),
          throwsFormatException,
        );
      },
    );

    test(
      'missing or broken recorded audio falls back to device speech',
      () async {
        final fallback = TestSpeech();
        final player = TestPlayer();
        final speech = ContentSpeechService(
          packs: packs,
          fallback: fallback,
          player: player,
        );
        await speech.speakSense(asset.senseId, 'word', 'achieve');
        expect(fallback.spoken, ['achieve']);
        await packs.installBytes(pack, zipBytes);
        await speech.speakSense(asset.senseId, 'word', 'achieve');
        expect(player.played, hasLength(1));
        expect(fallback.spoken, hasLength(1));
        player.fail = true;
        await speech.speakSense(asset.senseId, 'word', 'achieve');
        expect(fallback.spoken, hasLength(2));
        await speech.speakSense(asset.senseId, 'word', 'edited text');
        expect(fallback.spoken.last, 'edited text');
      },
    );
  });
}
