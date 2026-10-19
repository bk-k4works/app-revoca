import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../application/study_nudges.dart';
import '../domain/learning.dart';
import '../services/speech_service.dart';
import 'deck_screen.dart';
import 'focus_theme.dart';
import 'listen_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'study_log_view.dart';
import 'study_screen.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.speech,
    this.nudges = const NoStudyNudges(),
  });
  final LearningController controller;
  final SpeechService speech;
  final StudyNudges nudges;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) {
      final colors = FocusColors.of(context);
      final controller = widget.controller;
      final textScaler = MediaQuery.textScalerOf(context);
      final headerHeight = textScaler.scale(13) * 2.8 + 16;
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: headerHeight < 64 ? 64 : headerHeight,
          title: Semantics(
            label: '리보카',
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  text: 're',
                  children: [
                    TextSpan(
                      text: ':',
                      style: TextStyle(color: colors.warning),
                    ),
                    const TextSpan(text: 'voca'),
                  ],
                ),
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                ),
              ),
            ),
          ),
          actions: [
            _SearchButton(
              controller: controller,
              onPressed: () =>
                  openWordSearch(context, controller, widget.speech),
            ),
            IconButton(
              tooltip: '학습 설정',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => openSettings(context, controller, widget.nudges),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 20),
              child: Semantics(
                label: '연속 학습 ${controller.streak}일',
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.22,
                    ),
                    // Shrinks rather than overflows next to the other actions.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_outlined,
                            size: 18,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${controller.streak}일',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch (_tab) {
            0 => _Today(
              controller: controller,
              speech: widget.speech,
              onLibrary: () => setState(() => _tab = 1),
            ),
            1 => DeckLibrary(controller: controller, speech: widget.speech),
            _ => _Records(controller: controller, speech: widget.speech),
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: '오늘',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: '단어장',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: '기록',
            ),
          ],
        ),
      );
    },
  );
}

class _Today extends StatelessWidget {
  const _Today({
    required this.controller,
    required this.speech,
    required this.onLibrary,
  });
  final LearningController controller;
  final SpeechService speech;
  final VoidCallback onLibrary;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    final pending = controller.session != null;
    final done = !pending && controller.todayIds.isEmpty;
    final count = pending
        ? controller.session!.wordIds.length
        : controller.todayIds.length;
    final now = controller.now();
    final completed = controller.session?.complete == true;
    final newToday = controller.introducedToday.length.clamp(
      0,
      controller.dailyNewLimit,
    );
    final deck = controller.currentDeck;
    return PageContent(
      children: [
        Caption('${now.month}월 ${now.day}일 · 나를 위한 작은 루틴'),
        const SizedBox(height: 8),
        Text(
          done ? '오늘의 학습을\n차근차근 해냈어요.' : '오늘의 단어,\n가볍게 끝내요.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            height: 1.35,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 24),
        PaperCard(
          color: c.accent,
          child: DefaultTextStyle(
            style: TextStyle(color: c.accentInk),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        completed
                            ? '마친 학습 확인하기'
                            : pending
                            ? '이어서 할 작은 목표'
                            : done
                            ? '오늘도 한 걸음 전진'
                            : '지금 집중할 작은 목표',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.north_east_rounded,
                      size: 19,
                      color: Color(0xFF243016),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${done ? controller.studiedToday.length : count}',
                      style: const TextStyle(
                        fontSize: 76,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -4,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      done ? '개 학습' : '개 단어',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  pending
                      ? controller.session!.title
                      : done
                      ? '오늘 새 단어 $newToday개와 복습을 마쳤어요. 더 하고 싶으면 단어장에서 이어가요.'
                      : '복습 ${controller.todayIds.where(controller.isDue).length}개 · 새 단어 ${controller.todayIds.where((id) => !controller.isDue(id)).length}개',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                if (!pending) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: '오늘 새 단어 $newToday개 / ${controller.dailyNewLimit}개',
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘 새 단어 $newToday / ${controller.dailyNewLimit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: newToday / controller.dailyNewLimit,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(3),
                            color: c.accentInk,
                            backgroundColor: c.accentInk.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF26331A),
                    foregroundColor: const Color(0xFFF2FFDD),
                  ),
                  onPressed: controller.busy
                      ? null
                      : () => openStudy(context, controller, speech),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            completed
                                ? '학습 결과 보기'
                                : pending
                                ? '이어서 학습하기'
                                : done
                                ? '가볍게 연습하기'
                                : '$count개씩 시작하기',
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 21),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        WeekActivity(controller: controller, speech: speech),
        if (controller.weakIds.isNotEmpty) ...[
          const SizedBox(height: 20),
          InkWell(
            key: const Key('weak-words'),
            borderRadius: BorderRadius.circular(24),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DeckScreen(
                  deck: controller.weakDeck,
                  controller: controller,
                  speech: speech,
                ),
              ),
            ),
            child: PaperCard(
              color: c.warningSurface,
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, color: c.warning),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '헷갈린 단어 ${controller.weakIds.length}개',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Caption('틀린 단어만 골라 다시 시험해요'),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SectionHeading(
          '지금 학습 중인 단어장',
          action: TextButton(onPressed: onLibrary, child: const Text('전체 보기')),
        ),
        DeckTile(
          deck: deck,
          controller: controller,
          speech: speech,
          index: controller.vocabulary.decks.indexOf(deck),
        ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ListenScreen(
                deck: deck,
                vocabulary: controller.vocabulary,
                speech: speech,
                onHeard: controller.recordListen,
              ),
            ),
          ),
          child: PaperCard(
            color: c.soft,
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded, size: 26),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '귀로 한 번 더',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Caption('${deck.title} 단어와 예문을 편하게 들어요'),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WeekActivity extends StatelessWidget {
  const WeekActivity({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  Widget build(BuildContext context) {
    final colors = FocusColors.of(context);
    final now = controller.now();
    final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
    final scaledDiameter = MediaQuery.textScalerOf(context).scale(12) * 1.6 + 4;
    final diameter = scaledDiameter < 32 ? 32.0 : scaledDiameter;
    final days = List.generate(7, (index) {
      final date = DateTime(monday.year, monday.month, monday.day + index);
      final done = controller.activeDays.contains(calendarDay(date));
      final today = calendarDay(date) == calendarDay(now);
      final future = date.isAfter(now);
      return Semantics(
        button: !future,
        label:
            '${date.month}월 ${date.day}일 ${done ? '학습함' : '학습 기록 없음'}${today ? ', 오늘' : ''}',
        child: ExcludeSemantics(
          child: InkWell(
            key: ValueKey('week-${calendarDay(date)}'),
            borderRadius: BorderRadius.circular(12),
            onTap: future
                ? null
                : () => showDaySummary(context, controller, speech, date),
            child: SizedBox(
              width: diameter + 4,
              child: Column(
                children: [
                  Caption(['월', '화', '수', '목', '금', '토', '일'][index]),
                  const SizedBox(height: 8),
                  Container(
                    width: diameter,
                    height: diameter,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? colors.ink : colors.soft,
                      shape: BoxShape.circle,
                      border: today
                          ? Border.all(color: colors.ink, width: 1.5)
                          : null,
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colors.background,
                          )
                        : Text(
                            '${date.day}',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days,
          ),
        ),
      ),
    );
  }
}

class _Records extends StatelessWidget {
  const _Records({required this.controller, required this.speech});
  final LearningController controller;
  final SpeechService speech;
  @override
  Widget build(BuildContext context) {
    final c = FocusColors.of(context);
    final events = controller.events.where((e) => !e.practice).toList();
    return PageContent(
      children: [
        Text(
          '작은 반복이\n쌓이고 있어요.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        PaperCard(
          color: c.soft,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 250 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              final statistics = [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Caption('오늘 학습한 단어'),
                    const SizedBox(height: 8),
                    Text(
                      '${controller.studiedToday.length}개',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Caption('학습한 날'),
                    const SizedBox(height: 8),
                    Text(
                      '${controller.activeDays.length}일',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ];
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statistics[0],
                        const SizedBox(height: 20),
                        statistics[1],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: statistics[0]),
                        const SizedBox(width: 16),
                        Expanded(child: statistics[1]),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 28),
        const SectionHeading('달력으로 보는 기록'),
        MonthCalendar(controller: controller, speech: speech),
        const SizedBox(height: 12),
        const Caption('날짜를 누르면 그날 공부한 단어와 헷갈린 단어를 볼 수 있어요.'),
        const SizedBox(height: 28),
        const SectionHeading('전체 진도'),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '시작한 뜻 ${controller.startedCount} / ${controller.vocabulary.words.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    controller.startedCount /
                    controller.vocabulary.words.length,
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Caption('앞으로 7일 안에 복습할 뜻 ${controller.dueWithin(7)}개'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const SectionHeading('뜻과 철자는 따로 확인해요'),
        for (final mode in StudyMode.values) ...[
          Builder(
            builder: (context) {
              final attempts = events.where((e) => e.mode == mode).toList();
              final correct = attempts.where((e) => e.correct).length;
              final established = controller.progress.values
                  .where((p) => p.mode == mode && p.established)
                  .length;
              return PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          mode == StudyMode.recall ? '뜻 떠올리기' : '철자 쓰기',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          attempts.isEmpty
                              ? '—'
                              : '${(correct / attempts.length * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: attempts.isEmpty ? 0 : correct / attempts.length,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                    Caption(
                      '첫 시도 $correct / ${attempts.length} · 여러 날 기억한 단어 $established개',
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        const Caption(
          '당일 추가 연습과 오답 재시도는 첫 시도 정답률에 합산하지 않아요. 듣기도 암기 성공으로 계산하지 않아요.',
        ),
        const SizedBox(height: 28),
        if (controller.events.isEmpty)
          const PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 기록이 없어요.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Caption('첫 5개를 시작하면 이곳에 나의 학습 기록이 쌓여요.'),
              ],
            ),
          )
        else
          Caption(
            '다음 복습은 단어별 일정에 맞춰 오늘 화면에 나타나요. 현재 복습할 단어 ${controller.dueIds.length}개.',
          ),
      ],
    );
  }
}

/// The app bar search button. On first launch it opens as a labelled lime
/// pill that blinks three times and then folds back into the icon.
class _SearchButton extends StatefulWidget {
  const _SearchButton({required this.controller, required this.onPressed});
  final LearningController controller;
  final VoidCallback onPressed;
  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.controller.searchHintPending) {
      _hint.forward().whenComplete(_seen);
    }
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _seen() => widget.controller.markHintSeen(LearningController.searchHint);

  void _press() {
    if (_hint.isAnimating) {
      _hint.stop();
      _seen();
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _hint,
    builder: (context, child) {
      if (!_hint.isAnimating) {
        return IconButton(
          tooltip: '단어 찾기',
          icon: const Icon(Icons.search_rounded),
          onPressed: _press,
        );
      }
      final c = FocusColors.of(context);
      final t = _hint.value;
      // Unfold, blink three times, fold back.
      final open = t < 0.08
          ? Curves.easeOut.transform((t / 0.08).clamp(0.0, 1.0))
          : t > 0.85
          ? 1 - Curves.easeIn.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0))
          : 1.0;
      final blink =
          MediaQuery.disableAnimationsOf(context) || t < 0.08 || t > 0.85
          ? 1.0
          : 0.5 + 0.5 * math.cos(2 * math.pi * 3 * (t - 0.08) / 0.77);
      return Tooltip(
        message: '단어 찾기',
        child: Material(
          color: c.accent.withValues(alpha: open * (0.35 + 0.65 * blink)),
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: _press,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded, color: c.accentInk),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: open,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.22,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '단어 찾기',
                              style: TextStyle(
                                color: c.accentInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
