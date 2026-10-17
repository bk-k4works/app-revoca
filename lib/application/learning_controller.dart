import 'dart:math';
import 'package:flutter/foundation.dart';

import '../data/learning_store.dart';
import '../domain/learning.dart';
import '../domain/vocabulary.dart';

class LearningController extends ChangeNotifier {
  LearningController({
    required this.vocabulary,
    required this.store,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now;
  final Vocabulary vocabulary;
  final LearningStore store;
  final DateTime Function() now;
  final Map<String, LearningProgress> progress = {};
  final List<ReviewEvent> events = [];
  List<String> examWordIds = [];
  final Set<String> _unavailableExamWordIds = {};
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
    examWordIds = snapshot.examWordIds
        .where(vocabulary.byId.containsKey)
        .toList();
    _unavailableExamWordIds.addAll(
      snapshot.examWordIds.where((id) => !vocabulary.byId.containsKey(id)),
    );
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
  List<String> get newIds =>
      vocabulary.words.map((w) => w.id).where(isNew).toList();
  List<String> get todayIds => {...dueIds, ...newIds}.take(5).toList();
  Set<String> get studiedToday => events
      .where((e) => calendarDay(e.at) == calendarDay(now()))
      .map((e) => e.wordId)
      .toSet();
  Set<String> get activeDays => events.map((e) => calendarDay(e.at)).toSet();
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
  List<WordDeck> get decks => [...vocabulary.decks, examDeck];

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

  Future<bool> start({
    WordDeck? deck,
    List<String>? retryIds,
  }) => _mutate(() async {
    final candidates =
        deck?.wordIds ?? vocabulary.words.map((w) => w.id).toList();
    final eligible = {
      ...candidates.where(isDue),
      ...candidates.where(isNew),
    }.take(5).toList();
    final practice = retryIds != null || eligible.isEmpty;
    final ids =
        retryIds ?? (eligible.isEmpty ? candidates.take(5).toList() : eligible);
    if (ids.isEmpty) throw StateError('Empty study range');
    await vocabulary.ensureDetails(ids);
    final next = StudySession(
      id: '${now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
      title: retryIds != null ? '헷갈린 단어 다시 보기' : deck?.title ?? '오늘의 5개',
      wordIds: ids,
      learningWordIds: practice
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

  Future<bool> reveal() => _mutate(() async {
    if (session == null || session!.complete) return;
    final next = session!.reveal();
    await store.saveSession(next);
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

  Future<bool> setExamWords(Iterable<String> ids) => _mutate(() async {
    final selected = ids.where(vocabulary.byId.containsKey).toSet().toList();
    await store.saveExamWords([...selected, ..._unavailableExamWordIds]);
    examWordIds = selected;
  });
}
