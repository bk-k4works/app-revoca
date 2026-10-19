import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../application/study_nudges.dart';
import '../domain/study_settings.dart';
import 'widgets.dart';

Future<void> openSettings(
  BuildContext context,
  LearningController controller, [
  StudyNudges nudges = const NoStudyNudges(),
]) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => SettingsScreen(controller: controller, nudges: nudges),
  ),
);

String reminderTime(int minutes) {
  final hour = minutes ~/ 60, minute = minutes % 60;
  final shown = hour % 12 == 0 ? 12 : hour % 12;
  return '${hour < 12 ? '오전' : '오후'} $shown:${minute.toString().padLeft(2, '0')}';
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.nudges = const NoStudyNudges(),
  });
  final LearningController controller;
  final StudyNudges nudges;

  Future<void> _setReminder(BuildContext context, bool on) async {
    if (on && !await nudges.requestPermission()) {
      if (context.mounted) {
        showNotice(context, '알림이 꺼져 있어요. 기기 설정에서 리보카 알림을 켜 주세요.');
      }
      return;
    }
    if (context.mounted) {
      await _save(context, controller.settings.copyWith(reminder: on));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final minutes = controller.settings.reminderMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: '알림 시각',
    );
    if (picked == null || !context.mounted) return;
    await _save(
      context,
      controller.settings.copyWith(
        reminderMinutes: picked.hour * 60 + picked.minute,
      ),
    );
  }

  Future<void> _save(BuildContext context, StudySettings next) async {
    if (!await controller.updateSettings(next) &&
        context.mounted &&
        controller.error != null) {
      showNotice(context, controller.error!);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final settings = controller.settings;
      Widget choice(
        String title,
        String caption,
        List<int> options,
        int value,
        StudySettings Function(int value) apply,
        Key key,
      ) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Caption(caption),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            key: key,
            showSelectedIcon: false,
            segments: [
              for (final option in options)
                ButtonSegment(value: option, label: Text('$option개')),
            ],
            selected: {value},
            onSelectionChanged: controller.busy
                ? null
                : (selected) => _save(context, apply(selected.single)),
          ),
          const SizedBox(height: 28),
        ],
      );
      return Scaffold(
        appBar: AppBar(title: const Text('학습 설정')),
        body: SafeArea(
          top: false,
          child: PageContent(
            children: [
              const SectionHeading('학습량'),
              choice(
                '하루 새 단어',
                '오늘 화면이 하루에 새로 소개하는 뜻의 수예요. 단어장에서는 더 할 수 있어요.',
                StudySettings.dailyNewOptions,
                settings.dailyNewLimit,
                (value) => settings.copyWith(dailyNewLimit: value),
                const Key('daily-new-limit'),
              ),
              choice(
                '한 번에 학습할 단어',
                '익히기·뜻 떠올리기·철자 쓰기를 한 바퀴 도는 단어 수예요. 다음 학습부터 적용돼요.',
                StudySettings.sessionSizeOptions,
                settings.sessionSize,
                (value) => settings.copyWith(sessionSize: value),
                const Key('session-size'),
              ),
              const SectionHeading('문제 풀기'),
              SwitchListTile(
                key: const Key('auto-play-word'),
                contentPadding: EdgeInsets.zero,
                title: const Text('발음 자동 재생'),
                subtitle: const Caption(
                  '익히기 카드와 뜻 고르기 문제가 나오면 단어를 읽어 줘요. 철자 쓰기는 답을 쓴 뒤에 읽어 줘요.',
                ),
                value: settings.autoPlayWord,
                onChanged: controller.busy
                    ? null
                    : (value) => _save(
                        context,
                        settings.copyWith(autoPlayWord: value),
                      ),
              ),
              SwitchListTile(
                key: const Key('auto-advance'),
                contentPadding: EdgeInsets.zero,
                title: const Text('맞히면 자동으로 다음 문제'),
                subtitle: const Caption('틀렸을 때는 정답을 확인할 수 있게 멈춰요.'),
                value: settings.autoAdvance,
                onChanged: controller.busy
                    ? null
                    : (value) =>
                          _save(context, settings.copyWith(autoAdvance: value)),
              ),
              const SizedBox(height: 28),
              const SectionHeading('알림'),
              SwitchListTile(
                key: const Key('reminder'),
                contentPadding: EdgeInsets.zero,
                title: const Text('매일 학습 알림'),
                subtitle: const Caption(
                  '정한 시각에 오늘 복습할 단어 수를 알려 줘요. 그날 이미 공부했으면 보내지 않아요.',
                ),
                value: settings.reminder,
                onChanged: controller.busy
                    ? null
                    : (value) => _setReminder(context, value),
              ),
              ListTile(
                key: const Key('reminder-time'),
                contentPadding: EdgeInsets.zero,
                enabled: settings.reminder && !controller.busy,
                title: const Text('알림 시각'),
                trailing: Text(
                  reminderTime(settings.reminderMinutes),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _pickTime(context),
              ),
              const SizedBox(height: 12),
              const Caption(
                'Android에서는 홈 화면에 리보카 위젯을 추가하면 오늘 남은 단어 수와 연속 학습일을 볼 수 있어요.',
              ),
            ],
          ),
        ),
      );
    },
  );
}
