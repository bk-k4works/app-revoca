import 'dart:math';
import 'package:flutter/foundation.dart';

import '../data/learning_store.dart';
import '../domain/learning.dart';
import '../domain/study_settings.dart';
import '../domain/vocabulary.dart';
import 'study_log.dart';

class LearningController extends ChangeNotifier {
  LearningController({
    required this.vocabulary,
    required this.store,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;

  /// How much and how the student studies; see [updateSettings].
  StudySettings settings = const StudySettings();
  int get dailyNewLimit => settings.dailyNewLimit;
  int get sessionSize => settings.sessionSize;
  final Vocabulary vocabulary;
  final LearningStore store;
  final DateTime Function() now;
  final Map<String, LearningProgress> progress = {};
  final List<ReviewEvent> events = [];

  /// Learn cards opened and words heard; never part of accuracy or schedule.
  final List<ActivityEvent> activities = [];
  List<String> examWordIds = [];
  final Set<String> _unavailableExamWordIds = {};

  /// Starred senses, most recently starred first.
  List<String> favoriteWordIds = [];
  final Set<String> _unavailableFavoriteIds = {};

  /// One-time guidance already shown, such as [searchHint].
  final Set<String> seenHints = {};
  static const searchHint = 'search';
  StudySession? session;
  bool busy = false;
  String? error;

  Future<void> initialize() async {
    await store.migrateSenseIds(
      vocabulary.idMigrations,
      vocabulary.byId.keys.toSet(),
    );
    final snapshot = await store.load();
    progress.addAll({for (final item in snapshot.progress) item.key: item});
    events.addAll(snapshot.events);
    activities.addAll(snapshot.activities);
    examWordIds = snapshot.examWordIds
        .where(vocabulary.byId.containsKey)
        .toList();
    _unavailableExamWordIds.addAll(
      snapshot.examWordIds.where((id) => !vocabulary.byId.containsKey(id)),
    );
    favoriteWordIds = snapshot.favoriteWordIds
        .where(vocabulary.byId.containsKey)
        .toList();
    _unavailableFavoriteIds.addAll(
      snapshot.favoriteWordIds.where((id) => !vocabulary.byId.containsKey(id)),
    );
    seenHints.addAll(snapshot.seenHints);
    settings = StudySettings.fromJson(snapshot.settings);
    session = snapshot.session;
    if (session != null &&
        (session!.wordIds.isEmpty ||
            session!.wordIds.any((id) => !vocabulary.byId.containsKey(id)))) {
      throw const FormatException('Session references unavailable content.');
    }
    if (session != null) await vocabulary.ensureDetails(session!.wordIds);
  }

  LearningProgress? stateFor(String id, StudyMode mode) =>
      progress['$id:${mode.name}'];
  bool isNew(String id) =>
      StudyMode.values.any((mode) => stateFor(id, mode) == null);
  bool isDue(String id) => StudyMode.values.any((mode) {
    final value = stateFor(id, mode);
    return value != null && !value.dueAt.isAfter(now());
  });
  List<String> get dueIds =>
      vocabulary.words.map((w) => w.id).where(isDue).toList();

  /// New senses in study order: the current deck first, then the decks after
  /// it, then earlier decks, so the today card follows where the student is.
  List<String> get newIds {
    final decks = vocabulary.decks;
    final start = decks.indexOf(currentDeck);
    final ordered = <String>{
      for (final deck in [...decks.skip(start), ...decks.take(start)])
        ...deck.wordIds,
      ...vocabulary.words.map((w) => w.id),
    };
    return ordered.where(isNew).toList();
  }

  /// Senses first answered today, in any mode, practice included.
  Set<String> get introducedToday {
    final first = <String, DateTime>{};
    for (final event in events) {
      final seen = first[event.wordId];
      if (seen == null || event.at.isBefore(seen)) {
        first[event.wordId] = event.at;
      }
    }
    final today = calendarDay(now());
    return {
      for (final entry in first.entries)
        if (calendarDay(entry.value) == today) entry.key,
    };
  }

  int get newTodayRemaining => max(0, dailyNewLimit - introducedToday.length);

  /// Due reviews, then new senses until today's new-sense goal is met. Empty
  /// once both are done, so the today card can say the day is finished.
  List<String> get todayIds =>
      {...dueIds, ...newIds.take(newTodayRemaining)}.take(sessionSize).toList();
  Set<String> get studiedToday => events
      .where((e) => calendarDay(e.at) == calendarDay(now()))
      .map((e) => e.wordId)
      .toSet();

  /// Words answered today for optional extra practice: those whose latest
  /// answer today was wrong first, then the ones practised least often.
  List<String> get practiceTodayIds {
    final today = calendarDay(now());
    final count = <String, int>{};
    final lastCorrect = <String, bool>{};
    for (final event in events) {
      if (calendarDay(event.at) != today) continue;
      count[event.wordId] = (count[event.wordId] ?? 0) + 1;
      lastCorrect[event.wordId] = event.correct;
    }
    final ids = count.keys.toList();
    int rank(String id) => lastCorrect[id]! ? 1 : 0;
    final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
    ids.sort((a, b) {
      final wrong = rank(a).compareTo(rank(b));
      if (wrong != 0) return wrong;
      final fewer = count[a]!.compareTo(count[b]!);
      return fewer != 0 ? fewer : order[a]!.compareTo(order[b]!);
    });
    return ids.take(sessionSize).toList();
  }

  late final Map<String, WordDeck> _deckOfWord = {
    for (final deck in vocabulary.decks.reversed)
      for (final id in deck.wordIds) id: deck,
  };

  /// The first course deck that contains the sense, if any.
  WordDeck? deckOf(String id) => _deckOfWord[id];

  /// When the sense next comes up for review, or null while it is new.
  DateTime? nextReview(String id) {
    if (isNew(id)) return null;
    return StudyMode.values
        .map((mode) => stateFor(id, mode)!.dueAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// The deck the student is working through: the open session's deck, else
  /// the deck of the latest answer, moving on once that deck has no new words.
  WordDeck get currentDeck {
    final decks = vocabulary.decks;
    final open = session;
    WordDeck? deck = open == null
        ? null
        : decks.where((d) => d.title == open.title).firstOrNull ??
              _deckOfWord[open.wordIds.first];
    if (deck == null && events.isNotEmpty) {
      final latest = events.reduce((a, b) => b.at.isBefore(a.at) ? a : b);
      deck = _deckOfWord[latest.wordId];
    }
    if (deck == null) return decks.first;
    if (open == null && !deck.wordIds.any(isNew)) {
      final index = decks.indexOf(deck);
      return decks
              .skip(index + 1)
              .where((d) => d.wordIds.any(isNew))
              .firstOrNull ??
          deck;
    }
    return deck;
  }

  /// Days with any answer, learn card or listening.
  Set<String> get activeDays => log.activeDays;

  // Rebuilt only when records were added since the last request.
  StudyLog? _log;
  int _logSize = -1;
  StudyLog get log {
    final size = events.length + activities.length;
    if (_log == null || size != _logSize) {
      _log = StudyLog(events, activities);
      _logSize = size;
    }
    return _log!;
  }

  DaySummary daySummary(DateTime day) => log.day(day);
  MonthSummary monthSummary(int year, int month) => log.month(year, month);

  /// Senses ever answered, out of every sense in the course.
  int get startedCount => {
    for (final event in events) event.wordId,
  }.where(vocabulary.byId.containsKey).length;

  /// Senses due for review from today through the next [days] days.
  int dueWithin(int days) {
    final today = now();
    final limit = DateTime(today.year, today.month, today.day + days + 1);
    return vocabulary.words.where((w) {
      final review = nextReview(w.id);
      return review != null && review.isBefore(limit);
    }).length;
  }

  /// Notes that a word was heard while listening. Best effort: a failed save
  /// only leaves the word out of the day's record.
  Future<void> recordListen(String wordId) async {
    final time = now();
    final activity = ActivityEvent(
      id: '${time.microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}:listen',
      wordId: wordId,
      kind: ActivityKind.listen,
      at: time,
    );
    try {
      await store.saveActivities([activity]);
      activities.add(activity);
      notifyListeners();
    } catch (_) {}
  }

  int get streak {
    var day = DateTime(now().year, now().month, now().day);
    if (!activeDays.contains(calendarDay(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    var count = 0;
    while (activeDays.contains(calendarDay(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  int practicedCount(Iterable<String> ids) =>
      ids.where((id) => !isNew(id)).length;
  WordDeck get examDeck => WordDeck(
    id: 'my-exam',
    title: '나의 시험 범위',
    subtitle: '필요한 단어만 모아서',
    wordIds: examWordIds,
  );
  WordDeck get favoriteDeck => WordDeck(
    id: 'my-favorites',
    title: '즐겨찾기',
    subtitle: '별표한 단어만 모아서',
    wordIds: favoriteWordIds,
  );
  WordDeck get weakDeck => WordDeck(
    id: 'my-weak',
    title: '헷갈린 단어',
    subtitle: '틀린 적 있는 단어를 모아서',
    wordIds: weakIds,
  );
  List<WordDeck> get decks => [
    ...vocabulary.decks,
    favoriteDeck,
    weakDeck,
    examDeck,
  ];

  // Wrong answers per sense, rebuilt only when answers were added.
  ({List<String> ids, Map<String, int> wrong})? _weak;
  int _weakSize = -1;

  /// Senses answered wrong at least once that are not yet remembered over
  /// several days in both modes. Those whose latest answer was wrong come
  /// first, then the most recently missed.
  List<String> get weakIds => _weakRecords.ids;

  /// How many times the sense was answered wrong, practice included.
  int wrongCount(String id) => _weakRecords.wrong[id] ?? 0;

  ({List<String> ids, Map<String, int> wrong}) get _weakRecords {
    final size = events.length;
    if (_weak != null && size == _weakSize) return _weak!;
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    final wrong = <String, int>{};
    final lastWrong = <String, DateTime>{};
    final lastCorrect = <String, bool>{};
    for (final event in sorted) {
      lastCorrect[event.wordId] = event.correct;
      if (event.correct) continue;
      wrong[event.wordId] = (wrong[event.wordId] ?? 0) + 1;
      lastWrong[event.wordId] = event.at;
    }
    bool recovered(String id) => StudyMode.values.every(
      (mode) => stateFor(id, mode)?.established ?? false,
    );
    final ids =
        lastWrong.keys
            .where((id) => vocabulary.byId.containsKey(id) && !recovered(id))
            .toList()
          ..sort((a, b) {
            final missed = (lastCorrect[a]! ? 1 : 0).compareTo(
              lastCorrect[b]! ? 1 : 0,
            );
            return missed != 0
                ? missed
                : lastWrong[b]!.compareTo(lastWrong[a]!);
          });
    _weakSize = size;
    return _weak = (ids: ids, wrong: wrong);
  }

  /// The current contents of a personal deck; course decks never change.
  WordDeck latest(WordDeck deck) => switch (deck.id) {
    'my-exam' => examDeck,
    'my-favorites' => favoriteDeck,
    'my-weak' => weakDeck,
    _ => deck,
  };

  bool isFavorite(String id) => favoriteWordIds.contains(id);

  bool get searchHintPending => !seenHints.contains(searchHint);

  /// Records guidance as shown. Saving is best effort: if it fails, the hint
  /// simply appears once more on the next launch.
  Future<void> markHintSeen(String hint) async {
    if (!seenHints.add(hint)) return;
    notifyListeners();
    try {
      await store.saveSeenHints(seenHints.toList());
    } catch (_) {}
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await operation();
      return true;
    } catch (_) {
      error = '기록을 저장하지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Starts a round. [retryIds] makes it extra practice of those senses;
  /// with [testOnly] the learn cards are skipped and only questions are asked.
  Future<bool> start({
    WordDeck? deck,
    List<String>? retryIds,
    bool testOnly = false,
    String? title,
  }) => _mutate(() async {
    final candidates =
        deck?.wordIds ?? vocabulary.words.map((w) => w.id).toList();
    // The today card keeps to today's goal; a chosen deck may go beyond it.
    final eligible = deck == null
        ? todayIds
        : {
            ...candidates.where(isDue),
            ...candidates.where(isNew),
          }.take(sessionSize).toList();
    final practice = retryIds != null || eligible.isEmpty;
    final fallback = deck == null ? practiceTodayIds : const <String>[];
    final ids =
        retryIds ??
        (eligible.isNotEmpty
            ? eligible
            : fallback.isNotEmpty
            ? fallback
            : candidates.take(sessionSize).toList());
    if (ids.isEmpty) throw StateError('Empty study range');
    await vocabulary.ensureDetails(ids);
    final next = StudySession(
      id: '${now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      title:
          title ??
          (retryIds != null
              ? '헷갈린 단어 다시 보기'
              : deck?.title ??
                    (practice ? '오늘 배운 단어 연습' : '오늘의 $sessionSize개')),
      // Senses of one headword are learned together but quizzed apart, so
      // one answer does not give away the next.
      wordIds: separateHeadwords(ids),
      learningWordIds: testOnly
          ? const []
          : practice
          ? ids
          : ids
                .where(
                  (id) => StudyMode.values.every(
                    (mode) => stateFor(id, mode) == null,
                  ),
                )
                .toList(),
      practice: practice,
    );
    await store.saveSession(next);
    session = next;
  });

  /// A test-only practice round of the weakest senses, up to a round's size.
  Future<bool> retestWeak() => start(
    retryIds: weakIds.take(sessionSize).toList(),
    testOnly: true,
    title: '헷갈린 단어 다시 시험',
  );

  /// [ids] reordered so that no two neighbours share a headword where
  /// possible; otherwise the content order is kept.
  List<String> separateHeadwords(List<String> ids) {
    String headword(String id) => vocabulary.byId[id]!.headword.id;
    final remaining = [...ids];
    final ordered = <String>[];
    while (remaining.isNotEmpty) {
      final last = ordered.isEmpty ? null : headword(ordered.last);
      // Place the headword with the most senses left first, so that its
      // senses can still be spread out.
      int left(String id) =>
          remaining.where((other) => headword(other) == headword(id)).length;
      String? pick;
      for (final id in remaining) {
        if (headword(id) == last) continue;
        if (pick == null || left(id) > left(pick)) pick = id;
      }
      pick ??= remaining.first;
      remaining.remove(pick);
      ordered.add(pick);
    }
    return ordered;
  }

  Future<bool> reveal() => _mutate(() async {
    final current = session;
    if (current == null || current.complete) return;
    final next = current.reveal();
    // Opening a learn card is study, recorded once per card.
    final learned = current.stage == SessionStage.learn && !current.revealed
        ? ActivityEvent(
            id: '${current.id}:${current.position}:learn',
            wordId: current.currentId,
            kind: ActivityKind.learn,
            at: now(),
          )
        : null;
    if (learned == null) {
      await store.saveSession(next);
    } else {
      await store.saveActivities([learned], session: next);
      activities.removeWhere((a) => a.id == learned.id);
      activities.add(learned);
    }
    session = next;
  });

  /// The synonym typed for the current spelling question, if any. Such an
  /// answer is not graded; the student is asked for the intended word instead.
  Sense? spellingSynonym(String input) {
    final current = session;
    if (current == null ||
        current.complete ||
        current.answered ||
        current.stage != SessionStage.spelling) {
      return null;
    }
    return vocabulary.synonymAnswer(vocabulary.byId[current.currentId]!, input);
  }

  Future<bool> answer({bool? recalled, String input = ''}) => _mutate(() async {
    final current = session;
    if (current == null ||
        current.complete ||
        current.answered ||
        current.stage == SessionStage.learn ||
        spellingSynonym(input) != null) {
      return;
    }
    final word = vocabulary.byId[current.currentId]!;
    final correct = current.mode == StudyMode.recall
        ? recalled == true
        : word.accepts(input);
    final previous = stateFor(word.id, current.mode);
    final time = now();
    final practice =
        current.practice || (previous != null && previous.dueAt.isAfter(time));
    final updated = ReviewScheduler.apply(
      wordId: word.id,
      mode: current.mode,
      correct: correct,
      practice: practice,
      now: time,
      previous: previous,
    );
    final event = ReviewEvent(
      id: '${current.id}:${current.position}',
      wordId: word.id,
      mode: current.mode,
      correct: correct,
      practice: practice,
      at: time,
    );
    final next = current.answer(correct, input);
    await store.saveAnswer(event, updated, next);
    if (updated != null) progress[updated.key] = updated;
    events.removeWhere((e) => e.id == event.id);
    events.add(event);
    session = next;
  });

  Future<bool> next() => _mutate(() async {
    if (session == null || session!.complete) return;
    if (session!.stage == SessionStage.learn
        ? !session!.revealed
        : !session!.answered) {
      return;
    }
    final next = session!.next();
    await store.saveSession(next);
    session = next;
  });

  Future<bool> finish() => _mutate(() async {
    await store.saveSession(null);
    session = null;
  });

  Future<bool> updateSettings(StudySettings next) => _mutate(() async {
    await store.saveSettings(next.toJson());
    settings = next;
  });

  Future<bool> toggleFavorite(String id) => _mutate(() async {
    final next = isFavorite(id)
        ? favoriteWordIds.where((other) => other != id).toList()
        : [id, ...favoriteWordIds];
    await store.saveFavoriteWords([...next, ..._unavailableFavoriteIds]);
    favoriteWordIds = next;
  });

  Future<bool> setExamWords(Iterable<String> ids) => _mutate(() async {
    final selected = ids.where(vocabulary.byId.containsKey).toSet().toList();
    await store.saveExamWords([...selected, ..._unavailableExamWordIds]);
    examWordIds = selected;
  });
}
