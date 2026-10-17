enum StudyMode { recall, spelling }

enum SessionStage { learn, recall, spelling }

String calendarDay(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class LearningProgress {
  const LearningProgress({
    required this.wordId,
    required this.mode,
    required this.level,
    required this.dueAt,
    required this.lastReviewedAt,
    this.lapses = 0,
  });
  final String wordId;
  final StudyMode mode;
  final int level, lapses;
  final DateTime dueAt, lastReviewedAt;
  String get key => '$wordId:${mode.name}';
  bool get established => level >= 3;

  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'mode': mode.name,
    'level': level,
    'lapses': lapses,
    'dueAt': dueAt.toIso8601String(),
    'lastReviewedAt': lastReviewedAt.toIso8601String(),
  };
  factory LearningProgress.fromJson(Map<String, dynamic> json) =>
      LearningProgress(
        wordId: json['wordId'],
        mode: StudyMode.values.byName(json['mode']),
        level: json['level'],
        lapses: json['lapses'],
        dueAt: DateTime.parse(json['dueAt']),
        lastReviewedAt: DateTime.parse(json['lastReviewedAt']),
      );
}

class ReviewScheduler {
  static const intervals = [1, 1, 3, 7, 14, 30];

  /// Early practice and immediate retries never advance the review schedule.
  static LearningProgress? apply({
    required String wordId,
    required StudyMode mode,
    required bool correct,
    required bool practice,
    required DateTime now,
    LearningProgress? previous,
  }) {
    if (practice || (previous != null && previous.dueAt.isAfter(now))) {
      return previous;
    }
    final level = correct ? ((previous?.level ?? 0) + 1).clamp(1, 5) : 0;
    return LearningProgress(
      wordId: wordId,
      mode: mode,
      level: level,
      dueAt: DateTime(now.year, now.month, now.day + intervals[level]),
      lastReviewedAt: now,
      lapses: (previous?.lapses ?? 0) + (correct ? 0 : 1),
    );
  }
}

class ReviewEvent {
  const ReviewEvent({
    required this.id,
    required this.wordId,
    required this.mode,
    required this.correct,
    required this.practice,
    required this.at,
  });
  final String id, wordId;
  final StudyMode mode;
  final bool correct, practice;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'id': id,
    'wordId': wordId,
    'mode': mode.name,
    'correct': correct,
    'practice': practice,
    'at': at.toIso8601String(),
  };
  factory ReviewEvent.fromJson(Map<String, dynamic> json) => ReviewEvent(
    id: json['id'],
    wordId: json['wordId'],
    mode: StudyMode.values.byName(json['mode']),
    correct: json['correct'],
    practice: json['practice'],
    at: DateTime.parse(json['at']),
  );
}

class StudyAnswer {
  const StudyAnswer(this.wordId, this.mode, this.correct);
  final String wordId;
  final StudyMode mode;
  final bool correct;
  Map<String, dynamic> toJson() => {
    'wordId': wordId,
    'mode': mode.name,
    'correct': correct,
  };
  factory StudyAnswer.fromJson(Map<String, dynamic> json) => StudyAnswer(
    json['wordId'],
    StudyMode.values.byName(json['mode']),
    json['correct'],
  );
}

class StudySession {
  const StudySession({
    required this.id,
    required this.title,
    required this.wordIds,
    List<String>? learningWordIds,
    this.position = 0,
    this.revealed = false,
    this.answered = false,
    this.lastAnswer = '',
    this.practice = false,
    this.answers = const [],
  }) : _learningWordIds = learningWordIds;
  final String id, title, lastAnswer;
  final List<String> wordIds;
  final List<String>? _learningWordIds;
  List<String> get learningWordIds => _learningWordIds ?? wordIds;
  final int position;
  final bool revealed, answered, practice;
  final List<StudyAnswer> answers;
  int get total => learningWordIds.length + wordIds.length * 2;
  bool get complete => position >= total;
  SessionStage get stage => position < learningWordIds.length
      ? SessionStage.learn
      : position < learningWordIds.length + wordIds.length
      ? SessionStage.recall
      : SessionStage.spelling;
  StudyMode get mode =>
      stage == SessionStage.spelling ? StudyMode.spelling : StudyMode.recall;
  int get stageCount =>
      stage == SessionStage.learn ? learningWordIds.length : wordIds.length;
  int get stageIndex => switch (stage) {
    SessionStage.learn => position,
    SessionStage.recall => position - learningWordIds.length,
    SessionStage.spelling => position - learningWordIds.length - wordIds.length,
  };
  String get currentId => stage == SessionStage.learn
      ? learningWordIds[stageIndex]
      : wordIds[stageIndex];
  int get step => stageIndex + 1;
  Set<String> get wrongIds =>
      answers.where((a) => !a.correct).map((a) => a.wordId).toSet();

  StudySession reveal() => StudySession(
    id: id,
    title: title,
    wordIds: wordIds,
    learningWordIds: learningWordIds,
    position: position,
    revealed: true,
    answered: answered,
    lastAnswer: lastAnswer,
    practice: practice,
    answers: answers,
  );
  StudySession answer(bool correct, String input) => StudySession(
    id: id,
    title: title,
    wordIds: wordIds,
    learningWordIds: learningWordIds,
    position: position,
    revealed: true,
    answered: true,
    lastAnswer: input,
    practice: practice,
    answers: [...answers, StudyAnswer(currentId, mode, correct)],
  );
  StudySession next() => StudySession(
    id: id,
    title: title,
    wordIds: wordIds,
    learningWordIds: learningWordIds,
    position: position + 1,
    practice: practice,
    answers: answers,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'wordIds': wordIds,
    'learningWordIds': learningWordIds,
    'position': position,
    'revealed': revealed,
    'answered': answered,
    'lastAnswer': lastAnswer,
    'practice': practice,
    'answers': answers.map((a) => a.toJson()).toList(),
  };
  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
    id: json['id'],
    title: json['title'],
    wordIds: List<String>.from(json['wordIds']),
    learningWordIds: json['learningWordIds'] == null
        ? null
        : List<String>.from(json['learningWordIds']),
    position: json['position'],
    revealed: json['revealed'],
    answered: json['answered'],
    lastAnswer: json['lastAnswer'],
    practice: json['practice'],
    answers: (json['answers'] as List)
        .map((a) => StudyAnswer.fromJson(a))
        .toList(),
  );
}
