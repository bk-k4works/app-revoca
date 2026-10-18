import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

const partOfSpeechLabels = {
  'n': '명사',
  'v': '동사',
  'adj': '형용사',
  'adv': '부사',
  'pron': '대명사',
  'prep': '전치사',
  'conj': '접속사',
  'det': '한정사',
  'interj': '감탄사',
  'aux': '조동사',
  'phrase': '구',
};

class Headword {
  const Headword({
    required this.id,
    required this.term,
    required this.acceptedSpellings,
    this.source = const {},
  });
  final String id, term;
  final List<String> acceptedSpellings;
  final Map<String, dynamic> source;
  factory Headword.fromJson(Map<String, dynamic> json) => Headword(
    id: json['id'],
    term: json['term'],
    acceptedSpellings: List<String>.from(json['acceptedSpellings']),
    source: Map<String, dynamic>.from(json['source'] ?? {}),
  );
}

class SenseExample {
  const SenseExample(this.en, this.ko);
  final String en, ko;
}

class Sense {
  const Sense({
    required this.id,
    required this.headword,
    required this.pos,
    required this.meaning,
    this.explanation = '',
    this.collocation = '',
    this.collocationMeaning = '',
    this.example = '',
    this.exampleMeaning = '',
    this.additionalExamples = const [],
    this.meaningAlternatives = const [],
    this.distractorExclusions = const [],
    this.nearSynonymHeadwords = const [],
    this.detailsLoaded = true,
    this.provenance = const {},
  });
  final String id, pos, meaning, explanation;
  final Headword headword;
  final String collocation, collocationMeaning, example, exampleMeaning;
  final List<SenseExample> additionalExamples;
  final List<String> meaningAlternatives, distractorExclusions;
  final List<String> nearSynonymHeadwords;
  final bool detailsLoaded;
  final Map<String, dynamic> provenance;
  String get term => headword.term;
  String get partOfSpeech => partOfSpeechLabels[pos] ?? pos;
  List<String> get acceptedSpellings => headword.acceptedSpellings;

  factory Sense.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('meaningKo')) {
      final example = json['examples'][json['selectedExampleIndex'] ?? 0];
      return Sense(
        id: json['id'],
        headword: Headword(
          id: json['headwordId'],
          // A display form (Antarctica, customs) may differ from the list key.
          term: json['term'] ?? json['headword'],
          acceptedSpellings: List<String>.from(json['acceptedSpellings']),
          source: Map<String, dynamic>.from(json['source'] ?? {}),
        ),
        pos: json['pos'],
        meaning: json['meaningKo'],
        explanation: json['explanationKo'],
        collocation: json['collocation'],
        collocationMeaning: json['collocationKo'],
        example: example['en'],
        exampleMeaning: example['ko'],
        additionalExamples: [
          for (var i = 0; i < (json['examples'] as List).length; i++)
            if (i != (json['selectedExampleIndex'] ?? 0))
              SenseExample(
                json['examples'][i]['en'],
                json['examples'][i]['ko'],
              ),
        ],
        meaningAlternatives: List<String>.from(json['meaningKoAlt'] ?? []),
        distractorExclusions: List<String>.from(
          json['distractorExclusions'] ?? [],
        ),
        nearSynonymHeadwords: List<String>.from(
          json['nearSynonymHeadwords'] ?? [],
        ),
        provenance: {
          'source': json['source'],
          'generation': json['generation'],
          'review': json['review'],
          'contentHash': json['contentHash'],
        },
      );
    }
    final label = json['partOfSpeech'] as String;
    return Sense(
      id: json['id'],
      headword: Headword(
        id: json['term'],
        term: json['term'],
        acceptedSpellings: List<String>.from(json['acceptedSpellings']),
      ),
      pos:
          partOfSpeechLabels.entries
              .where((e) => e.value == label)
              .map((e) => e.key)
              .firstOrNull ??
          label,
      meaning: json['meaning'],
      explanation: json['explanation'],
      collocation: json['collocation'],
      collocationMeaning: json['collocationMeaning'],
      example: json['example'],
      exampleMeaning: json['exampleMeaning'],
    );
  }
  // Phrases are typed with spaces; ignore extra spaces and curly apostrophes.
  static String normalizeAnswer(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('\u2019', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
  bool accepts(String answer) => acceptedSpellings.any(
    (value) => normalizeAnswer(value) == normalizeAnswer(answer),
  );

  // Meanings compare without spacing and punctuation, as in meaning choices.
  static String normalizeMeaning(String value) =>
      value.replaceAll(RegExp(r'[\s.,!?·~～()]+'), '').toLowerCase();
  Set<String> get normalizedMeanings =>
      {meaning, ...meaningAlternatives}.map(normalizeMeaning).toSet();

  /// Reveals just enough of [term] to tell it apart from [typed], never all of it.
  static String spellingHint(String term, String typed) {
    final target = normalizeAnswer(term), other = normalizeAnswer(typed);
    var length = 1;
    while (length < target.length &&
        length <= other.length &&
        target[length - 1] == other[length - 1]) {
      length++;
    }
    return target.substring(0, length.clamp(1, max(1, target.length - 1)));
  }
}

// Compatibility name for UI components; every entry represents one sense.
typedef WordEntry = Sense;

class WordDeck {
  const WordDeck({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.wordIds,
  });
  final String id, title, subtitle;
  final List<String> wordIds;
  factory WordDeck.fromJson(Map<String, dynamic> json) => WordDeck(
    id: json['id'],
    title: json['title'],
    subtitle: json['subtitle'],
    wordIds: List<String>.from(json['wordIds']),
  );
}

class Vocabulary {
  Vocabulary({
    required this.words,
    required this.decks,
    required this.provenance,
    this.idMigrations = const {},
    this.detailLoader,
  }) {
    byId = {for (final word in words) word.id: word};
    if (byId.length != words.length || words.isEmpty || decks.isEmpty) {
      throw const FormatException('Invalid vocabulary identifiers.');
    }
    if (decks.map((d) => d.id).toSet().length != decks.length) {
      throw const FormatException('Duplicate deck identifiers.');
    }
    for (final deck in decks) {
      if (deck.wordIds.any((id) => !byId.containsKey(id))) {
        throw const FormatException('Unknown word in deck.');
      }
    }
    for (final id in idMigrations.keys) {
      resolveId(id);
    }
  }
  final List<Sense> words;
  final List<WordDeck> decks;
  final Map<String, dynamic> provenance;
  final Map<String, String> idMigrations;
  final Future<List<Sense>> Function(List<String>)? detailLoader;
  late final Map<String, Sense> byId;

  String resolveId(String id) {
    var current = id;
    final seen = <String>{};
    while (idMigrations.containsKey(current)) {
      if (!seen.add(current)) {
        throw const FormatException('Cyclic sense migration.');
      }
      current = idMigrations[current]!;
    }
    return current;
  }

  Future<void> ensureDetails(Iterable<String> ids) async {
    final missing = ids
        .toSet()
        .where((id) => byId[id]?.detailsLoaded == false)
        .toList();
    if (missing.isEmpty || detailLoader == null) return;
    final loaded = await detailLoader!(missing);
    if (loaded.length != missing.length) {
      throw const FormatException('Missing sense details.');
    }
    for (final sense in loaded) {
      final index = words.indexWhere((word) => word.id == sense.id);
      if (index < 0) throw const FormatException('Unexpected sense details.');
      words[index] = sense;
      byId[sense.id] = sense;
    }
  }

  // Stable tie-breaking avoids repeating the same alphabetically first distractors.
  static int choiceRank(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
    }
    return hash;
  }

  /// Another same-POS headword the student may rightly give for [word]'s
  /// meaning: the meanings overlap or either sense lists the other as a near
  /// synonym. Spelling asks again instead of recording such an answer as wrong.
  /// distractorExclusions is not used: it is a transitive closure that also
  /// joins confusable words (affect/effect), which must stay wrong answers.
  Sense? synonymAnswer(Sense word, String answer) {
    if (Sense.normalizeAnswer(answer).isEmpty || word.accepts(answer)) {
      return null;
    }
    final meanings = word.normalizedMeanings;
    final linkedTerms = word.nearSynonymHeadwords
        .map(Sense.normalizeAnswer)
        .toSet();
    final term = Sense.normalizeAnswer(word.term);
    for (final other in words) {
      if (other.pos != word.pos ||
          other.headword.id == word.headword.id ||
          !other.accepts(answer)) {
        continue;
      }
      if (linkedTerms.contains(Sense.normalizeAnswer(other.term)) ||
          other.nearSynonymHeadwords
              .map(Sense.normalizeAnswer)
              .contains(term) ||
          other.normalizedMeanings.any(meanings.contains)) {
        return other;
      }
    }
    return null;
  }

  List<Sense> choicesFor(Sense word) {
    const normalized = Sense.normalizeMeaning;
    final meanings = word.normalizedMeanings;
    final others = words
        .where(
          (other) =>
              other.id != word.id &&
              other.pos == word.pos &&
              other.headword.id != word.headword.id &&
              !word.distractorExclusions.contains(other.id) &&
              !other.distractorExclusions.contains(word.id) &&
              !other.normalizedMeanings.any(meanings.contains),
        )
        .toList();
    others.sort((a, b) {
      final difference = (a.meaning.runes.length - word.meaning.runes.length)
          .abs()
          .compareTo(
            (b.meaning.runes.length - word.meaning.runes.length).abs(),
          );
      if (difference != 0) return difference;
      final variety = choiceRank(
        '${word.id}:${a.id}',
      ).compareTo(choiceRank('${word.id}:${b.id}'));
      return variety == 0 ? a.id.compareTo(b.id) : variety;
    });
    final distinct = <String, Sense>{};
    for (final other in others) {
      distinct.putIfAbsent(normalized(other.meaning), () => other);
    }
    final choices = [word, ...distinct.values.take(3)];
    final offset = word.id.codeUnits.fold(0, (a, b) => a + b) % choices.length;
    return [...choices.skip(offset), ...choices.take(offset)];
  }

  factory Vocabulary.fromJson(Map<String, dynamic> json) => Vocabulary(
    words: (json['words'] as List).map((w) => Sense.fromJson(w)).toList(),
    decks: (json['decks'] as List).map((d) => WordDeck.fromJson(d)).toList(),
    provenance: Map<String, dynamic>.from(json['provenance']),
    idMigrations: Map<String, String>.from(json['idMigrations'] ?? {}),
  );

  /// Explicit development fixture. Production bootstrap uses ContentRepository.
  static Future<Vocabulary> load() async => Vocabulary.fromJson(
    jsonDecode(
          await rootBundle.loadString('assets/content/starter_vocabulary.json'),
        )
        as Map<String, dynamic>,
  );
}
