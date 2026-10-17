import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../domain/learning.dart';
import '../services/speech_service.dart';
import 'deck_screen.dart';
import 'focus_theme.dart';
import 'listen_screen.dart';
import 'study_screen.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.speech});
  final LearningController controller;
  final SpeechService speech;
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
            label: '포커스 보카',
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  text: 'voca',
                  children: [
                    TextSpan(
                      text: '.',
                      style: TextStyle(color: colors.warning),
                    ),
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
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        controller.streak > 0
                            ? '${controller.streak}일 연속'
                            : '오늘부터 한 걸음',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
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
            _ => _Records(controller: controller),
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
                      ? '필요하면 가볍게 한 번 더 연습해요.'
                      : '복습 ${controller.todayIds.where(controller.isDue).length}개 · 새 단어 ${controller.todayIds.where((id) => !controller.isDue(id)).length}개',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
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
        WeekActivity(controller: controller),
        const SizedBox(height: 28),
        SectionHeading(
          '내 단어장',
          action: TextButton(onPressed: onLibrary, child: const Text('전체 보기')),
        ),
        DeckTile(
          deck: controller.vocabulary.decks.first,
          controller: controller,
          speech: speech,
          index: 0,
        ),
        const SizedBox(height: 22),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ListenScreen(
                deck: controller.vocabulary.decks.first,
                vocabulary: controller.vocabulary,
                speech: speech,
              ),
            ),
          ),
          child: PaperCard(
            color: c.soft,
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded, size: 26),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '귀로 한 번 더',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Caption('단어와 예문을 편하게 들어요'),
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
  const WeekActivity({super.key, required this.controller});
  final LearningController controller;
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
      return Semantics(
        label:
            '${date.month}월 ${date.day}일 ${done ? '학습함' : '학습 기록 없음'}${today ? ', 오늘' : ''}',
        child: ExcludeSemantics(
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
  const _Records({required this.controller});
  final LearningController controller;
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
        const SizedBox(height: 24),
        WeekActivity(controller: controller),
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
