import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../application/study_log.dart';
import '../domain/learning.dart';
import '../services/speech_service.dart';
import 'deck_screen.dart';
import 'focus_theme.dart';
import 'study_screen.dart';
import 'widgets.dart';

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _clock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}

/// How strongly a day is shaded: 0 for no record up to 4 for a long session.
int studyLevel(DaySummary day) {
  final count = day.studiedIds.length;
  if (day.isEmpty) return 0;
  if (count < 5) return 1;
  if (count < 15) return 2;
  if (count < 30) return 3;
  return 4;
}

Color studyColor(FocusColors c, int level) => switch (level) {
  0 => Colors.transparent,
  1 => c.accent.withValues(alpha: 0.35),
  2 => c.accent.withValues(alpha: 0.65),
  3 => c.accent,
  _ => c.ink,
};

Color studyInk(FocusColors c, int level) => switch (level) {
  0 => c.muted,
  4 => c.background,
  _ => c.accentInk,
};

bool _isFuture(LearningController controller, DateTime day) {
  final now = controller.now();
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).isAfter(DateTime(now.year, now.month, now.day));
}

/// Opens what the student did on [day]; future days have nothing to show.
Future<void> showDaySummary(
  BuildContext context,
  LearningController controller,
  SpeechService speech,
  DateTime day,
) async {
  if (_isFuture(controller, day)) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: _DaySheet(controller: controller, speech: speech, day: day),
      ),
    ),
  );
  await speech.stop();
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.controller,
    required this.speech,
    required this.day,
  });
  final LearningController controller;
  final SpeechService speech;
  final DateTime day;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final summary = controller.daySummary(day);
      final title = '${day.month}월 ${day.day}일 ${_weekdays[day.weekday - 1]}요일';
      if (summary.isEmpty) {
        return PageContent(
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Caption('이날은 공부 기록이 없어요.'),
          ],
        );
      }
      final vocabulary = controller.vocabulary;
      final decks = <String>{
        for (final id in [...summary.studiedIds, ...summary.listenedIds])
          ?controller.deckOf(id)?.title,
      };
      final wrong = summary.wrongIds
          .where(vocabulary.byId.containsKey)
          .toList();
      final studied = summary.studiedIds
          .where(vocabulary.byId.containsKey)
          .map((id) => vocabulary.byId[id]!)
          .toList();
      final retry = wrong.take(controller.sessionSize).toList();
      final canRetry =
          retry.isNotEmpty &&
          (controller.session == null || controller.session!.complete);
      return PageContent(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Caption(
            summary.start == summary.end
                ? _clock(summary.start!)
                : '${_clock(summary.start!)} – ${_clock(summary.end!)}',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Count('새 단어', summary.newIds.length),
              _Count('복습', summary.reviewedIds.length),
              _Count('익히기', summary.learnedIds.length),
              _Count('듣기', summary.listenedIds.length),
              if (summary.practicedIds.isNotEmpty)
                _Count('추가 연습', summary.practicedIds.length),
            ],
          ),
          if (summary.recallTotal + summary.spellingTotal > 0) ...[
            const SizedBox(height: 20),
            if (summary.recallTotal > 0)
              _Accuracy('뜻 떠올리기', summary.recallCorrect, summary.recallTotal),
            if (summary.spellingTotal > 0)
              _Accuracy(
                '철자 쓰기',
                summary.spellingCorrect,
                summary.spellingTotal,
              ),
          ],
          if (decks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Caption(decks.join(' · ')),
          ],
          if (wrong.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeading('헷갈린 단어 ${wrong.length}개'),
            for (final group in groupByHeadword(
              wrong.map((id) => vocabulary.byId[id]!).toList(),
            )) ...[
              HeadwordHeading(group: group),
              for (final word in group)
                SenseTile(word: word, controller: controller, speech: speech),
            ],
            if (canRetry) ...[
              const SizedBox(height: 16),
              PrimaryAction(
                '헷갈린 단어 ${retry.length}개 다시 시험',
                icon: Icons.refresh_rounded,
                onPressed: controller.busy
                    ? null
                    : () async {
                        if (!await controller.start(
                          retryIds: retry,
                          testOnly: true,
                          title: '헷갈린 단어 다시 시험',
                        )) {
                          if (context.mounted && controller.error != null) {
                            showNotice(context, controller.error!);
                          }
                          return;
                        }
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StudyScreen(
                              controller: controller,
                              speech: speech,
                            ),
                          ),
                        );
                      },
              ),
            ],
          ],
          if (studied.isNotEmpty)
            ExpansionTile(
              key: const Key('day-studied-words'),
              tilePadding: EdgeInsets.zero,
              title: Text('이날 공부한 단어 ${studied.length}개'),
              children: [
                for (final group in groupByHeadword(studied)) ...[
                  HeadwordHeading(group: group),
                  for (final word in group)
                    SenseTile(
                      word: word,
                      controller: controller,
                      speech: speech,
                    ),
                ],
              ],
            ),
          const SizedBox(height: 12),
          const Caption('익히기와 듣기는 공부한 날로 기록하지만 정답률과 복습 일정에는 넣지 않아요.'),
        ],
      );
    },
  );
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption(label),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Accuracy extends StatelessWidget {
  const _Accuracy(this.label, this.correct, this.total);
  final String label;
  final int correct, total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '$correct / $total · ${(correct / total * 100).round()}%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

/// A month of study days, shaded by how much was studied, with the month's
/// totals. Months before the current one can be browsed.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final c = FocusColors.of(context);
    final now = controller.now();
    final first = DateTime(now.year, now.month + _offset);
    final month = controller.monthSummary(first.year, first.month);
    final length = DateTime(first.year, first.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 1; i < first.weekday; i++) null,
      for (var day = 1; day <= length; day++)
        DateTime(first.year, first.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    Widget cell(DateTime? date) {
      if (date == null) return const SizedBox.shrink();
      final summary = month.days[date.day];
      final level = summary == null ? 0 : studyLevel(summary);
      final future = _isFuture(controller, date);
      final today = calendarDay(date) == calendarDay(now);
      final count = summary?.studiedIds.length ?? 0;
      return Semantics(
        button: !future,
        label:
            '${date.month}월 ${date.day}일, ${summary == null ? '기록 없음' : '공부한 단어 $count개'}${today ? ', 오늘' : ''}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Material(
              color: future ? Colors.transparent : studyColor(c, level),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: today
                    ? BorderSide(color: c.ink, width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                key: ValueKey('day-${calendarDay(date)}'),
                borderRadius: BorderRadius.circular(10),
                onTap: future
                    ? null
                    : () => showDaySummary(
                        context,
                        controller,
                        widget.speech,
                        date,
                      ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: level > 0
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: future ? c.line : studyInk(c, level),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final cellHeight = (36 * textScale).clamp(36.0, 56.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() => _offset--),
            ),
            Expanded(
              child: Text(
                '${first.year}년 ${first.month}월',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 달',
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _offset < 0 ? () => setState(() => _offset++) : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in _weekdays)
              Expanded(child: Center(child: Caption(day))),
          ],
        ),
        const SizedBox(height: 6),
        for (var week = 0; week < cells.length; week += 7)
          SizedBox(
            height: cellHeight,
            child: Row(
              children: [
                for (final date in cells.sublist(week, week + 7))
                  Expanded(child: cell(date)),
              ],
            ),
          ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Caption('적게'),
              for (var level = 1; level <= 4; level++)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: studyColor(c, level),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const Caption('많이'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MonthTotals(month: month),
      ],
    );
  }
}

class _MonthTotals extends StatelessWidget {
  const _MonthTotals({required this.month});
  final MonthSummary month;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    if (month.studiedDays == 0) {
      return PaperCard(
        color: c.soft,
        child: Caption('${month.month}월에는 아직 공부 기록이 없어요.'),
      );
    }
    final rate = month.attempts == 0
        ? null
        : (month.correct / month.attempts * 100).round();
    return PaperCard(
      color: c.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month.month}월 합계',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Count('공부한 날', month.studiedDays),
              _Count('새 단어', month.newCount),
              _Count('복습', month.reviewedCount),
              _Count('익히기', month.learnedCount),
              _Count('듣기', month.listenedCount),
            ],
          ),
          const SizedBox(height: 12),
          Caption(
            rate == null
                ? '${month.month}월에는 아직 푼 문제가 없어요.'
                : '정답률 $rate% · 첫 시도 ${month.correct} / ${month.attempts}',
          ),
        ],
      ),
    );
  }
}
