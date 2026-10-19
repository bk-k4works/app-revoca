import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../application/learning_controller.dart';
import '../application/study_nudges.dart';

/// Daily study reminders through local notifications, and the Android home
/// widget. Nothing leaves the device.
class DeviceStudyNudges implements StudyNudges {
  static const _firstId = 100;
  static const _days = 7;
  static const _androidWidget = 'StudyWidgetProvider';

  final _notifications = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  String? _scheduled;
  String? _shown;

  Future<void> _setUp() async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone: keep UTC rather than fail; times may then be off.
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked only when the student turns reminders on.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    await (_ready ??= _setUp());
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> refresh(LearningController controller) async {
    try {
      await (_ready ??= _setUp());
      await _schedule(planReminders(controller, days: _days));
    } catch (_) {
      // A reminder is a convenience; studying must never depend on it.
    }
    if (Platform.isAndroid) {
      try {
        await _updateWidget(widgetSummary(controller));
      } catch (_) {}
    }
  }

  Future<void> _schedule(List<PlannedReminder> plans) async {
    final signature = plans.join('\n');
    if (signature == _scheduled) return;
    for (var i = 0; i < _days; i++) {
      await _notifications.cancel(id: _firstId + i);
    }
    for (var i = 0; i < plans.length; i++) {
      final plan = plans[i];
      await _notifications.zonedSchedule(
        id: _firstId + i,
        title: '리보카',
        body: plan.body,
        scheduledDate: tz.TZDateTime.from(plan.at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'study-reminder',
            '학습 알림',
            channelDescription: '정한 시각에 오늘 학습할 단어를 알려 줘요.',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    _scheduled = signature;
  }

  Future<void> _updateWidget(WidgetSummary summary) async {
    final signature = '${summary.count}|${summary.headline}|${summary.streak}';
    if (signature == _shown) return;
    await HomeWidget.saveWidgetData<String>('count', '${summary.count}');
    await HomeWidget.saveWidgetData<String>('headline', summary.headline);
    await HomeWidget.saveWidgetData<String>('streak', summary.streak);
    await HomeWidget.updateWidget(androidName: _androidWidget);
    _shown = signature;
  }
}
