import 'dart:math';

import '../domain/learning.dart';
import 'learning_controller.dart';

/// Reminders and the home widget, kept out of the controller so it stays free
/// of platform plugins. [NoStudyNudges] is used where neither is available.
abstract interface class StudyNudges {
  /// Asks the system for permission to notify; false if it was refused.
  Future<bool> requestPermission();

  /// Brings scheduled reminders and the widget in line with [controller].
  Future<void> refresh(LearningController controller);
}

class NoStudyNudges implements StudyNudges {
  const NoStudyNudges();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> refresh(LearningController controller) async {}
}

/// One reminder to schedule: when, and what it says.
class PlannedReminder {
  const PlannedReminder(this.at, this.body);
  final DateTime at;
  final String body;

  @override
  String toString() => '${at.toIso8601String()} $body';
}

/// What the home widget shows.
class WidgetSummary {
  const WidgetSummary({
    required this.count,
    required this.headline,
    required this.streak,
  });

  /// Senses left for today: due reviews and today's remaining new senses.
  final int count;
  final String headline, streak;
}

/// Reminders for the next [days] days at the chosen time. Today is skipped
/// once the time has passed or the student has already studied. Counts for
/// later days assume no study in between and are refreshed on every visit.
List<PlannedReminder> planReminders(
  LearningController controller, {
  int days = 7,
}) {
  final settings = controller.settings;
  if (!settings.reminder) return const [];
  final now = controller.now();
  final today = DateTime(now.year, now.month, now.day);
  final studiedToday = controller.activeDays.contains(calendarDay(now));
  final newLeft = controller.newIds.length;
  final reviews = [
    for (final word in controller.vocabulary.words)
      ?controller.nextReview(word.id),
  ];
  final plans = <PlannedReminder>[];
  for (var offset = 0; offset < days; offset++) {
    final at = DateTime(
      today.year,
      today.month,
      today.day + offset,
      settings.reminderMinutes ~/ 60,
      settings.reminderMinutes % 60,
    );
    if (offset == 0 && (!at.isAfter(now) || studiedToday)) continue;
    final end = DateTime(today.year, today.month, today.day + offset + 1);
    final due = reviews.where((review) => review.isBefore(end)).length;
    final fresh = offset == 0
        ? min(controller.newTodayRemaining, newLeft)
        : min(settings.dailyNewLimit, newLeft);
    final size = settings.sessionSize;
    final body = due > 0 && fresh > 0
        ? '복습 $due개와 새 단어 $fresh개가 기다려요. $size개씩 가볍게 시작해요.'
        : due > 0
        ? '복습할 단어 $due개가 기다려요. 잊기 전에 한 번 더 봐요.'
        : fresh > 0
        ? '오늘의 새 단어 $fresh개, $size개씩 가볍게 시작해요.'
        : null;
    if (body != null) plans.add(PlannedReminder(at, body));
  }
  return plans;
}

WidgetSummary widgetSummary(LearningController controller) {
  final due = controller.dueIds.length;
  final fresh = min(controller.newTodayRemaining, controller.newIds.length);
  return WidgetSummary(
    count: due + fresh,
    headline: due + fresh == 0 ? '오늘 학습을 마쳤어요' : '복습 $due개 · 새 단어 $fresh개',
    streak: '${controller.streak}일 연속',
  );
}
