import '../domain/learning.dart';

/// What the student did on one calendar day, derived from saved records.
class DaySummary {
  const DaySummary({
    required this.day,
    this.newIds = const [],
    this.reviewedIds = const [],
    this.practicedIds = const [],
    this.wrongIds = const [],
    this.learnedIds = const [],
    this.listenedIds = const [],
    this.recallCorrect = 0,
    this.recallTotal = 0,
    this.spellingCorrect = 0,
    this.spellingTotal = 0,
    this.start,
    this.end,
  });
  final DateTime day;

  /// Senses answered for the first time ever on this day.
  final List<String> newIds;

  /// Senses answered on their review schedule, not for the first time.
  final List<String> reviewedIds;

  /// Senses only answered as extra practice.
  final List<String> practicedIds;

  /// Senses with at least one wrong answer, practice included.
  final List<String> wrongIds;
  final List<String> learnedIds, listenedIds;

  /// Scheduled answers only, as in the records tab.
  final int recallCorrect, recallTotal, spellingCorrect, spellingTotal;
  final DateTime? start, end;

  bool get isEmpty => start == null;

  /// Senses studied actively: answered or opened on a learn card.
  Set<String> get studiedIds => {
    ...newIds,
    ...reviewedIds,
    ...practicedIds,
    ...learnedIds,
  };
}

/// A month of [DaySummary]s and their totals.
class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.days,
  });
  final int year, month;

  /// Studied days only, keyed by day of month.
  final Map<int, DaySummary> days;

  int _sum(int Function(DaySummary day) value) =>
      days.values.fold(0, (total, day) => total + value(day));
  int get studiedDays => days.length;
  int get newCount => _sum((d) => d.newIds.length);
  int get reviewedCount => _sum((d) => d.reviewedIds.length);
  int get learnedCount => _sum((d) => d.learnedIds.length);
  int get listenedCount => _sum((d) => d.listenedIds.length);
  int get correct => _sum((d) => d.recallCorrect + d.spellingCorrect);
  int get attempts => _sum((d) => d.recallTotal + d.spellingTotal);
  int get mostStudied => days.values.fold(
    0,
    (most, d) => d.studiedIds.length > most ? d.studiedIds.length : most,
  );
}

/// Groups answers and activities by calendar day once, for summaries.
class StudyLog {
  StudyLog(List<ReviewEvent> events, List<ActivityEvent> activities) {
    final sortedEvents = [...events]..sort((a, b) => a.at.compareTo(b.at));
    for (final event in sortedEvents) {
      _firstAnswerDay.putIfAbsent(event.wordId, () => calendarDay(event.at));
      _events.putIfAbsent(calendarDay(event.at), () => []).add(event);
    }
    final sortedActivities = [...activities]
      ..sort((a, b) => a.at.compareTo(b.at));
    for (final activity in sortedActivities) {
      _activities.putIfAbsent(calendarDay(activity.at), () => []).add(activity);
    }
  }

  final Map<String, String> _firstAnswerDay = {};
  final Map<String, List<ReviewEvent>> _events = {};
  final Map<String, List<ActivityEvent>> _activities = {};

  Set<String> get activeDays => {..._events.keys, ..._activities.keys};

  DaySummary day(DateTime date) {
    final key = calendarDay(date);
    final events = _events[key] ?? const <ReviewEvent>[];
    final activities = _activities[key] ?? const <ActivityEvent>[];
    final times = [...events.map((e) => e.at), ...activities.map((a) => a.at)]
      ..sort();
    final newIds = <String>{}, reviewedIds = <String>{}, practiced = <String>{};
    final wrongIds = <String>{};
    var recallCorrect = 0, recallTotal = 0;
    var spellingCorrect = 0, spellingTotal = 0;
    for (final event in events) {
      if (!event.correct) wrongIds.add(event.wordId);
      if (_firstAnswerDay[event.wordId] == key) {
        newIds.add(event.wordId);
      } else if (!event.practice) {
        reviewedIds.add(event.wordId);
      } else {
        practiced.add(event.wordId);
      }
      if (event.practice) continue;
      if (event.mode == StudyMode.recall) {
        recallTotal++;
        if (event.correct) recallCorrect++;
      } else {
        spellingTotal++;
        if (event.correct) spellingCorrect++;
      }
    }
    List<String> of(ActivityKind kind) => activities
        .where((a) => a.kind == kind)
        .map((a) => a.wordId)
        .toSet()
        .toList();
    return DaySummary(
      day: DateTime(date.year, date.month, date.day),
      newIds: newIds.toList(),
      reviewedIds: reviewedIds.difference(newIds).toList(),
      practicedIds: practiced.difference({...newIds, ...reviewedIds}).toList(),
      wrongIds: wrongIds.toList(),
      learnedIds: of(ActivityKind.learn),
      listenedIds: of(ActivityKind.listen),
      recallCorrect: recallCorrect,
      recallTotal: recallTotal,
      spellingCorrect: spellingCorrect,
      spellingTotal: spellingTotal,
      start: times.firstOrNull,
      end: times.lastOrNull,
    );
  }

  MonthSummary month(int year, int month) {
    final days = <int, DaySummary>{};
    final length = DateTime(year, month + 1, 0).day;
    for (var day = 1; day <= length; day++) {
      final summary = this.day(DateTime(year, month, day));
      if (!summary.isEmpty) days[day] = summary;
    }
    return MonthSummary(year: year, month: month, days: days);
  }
}
