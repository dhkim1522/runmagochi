import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_plan.dart';

/// 주간 목표 알림 예약. 이전 예약을 모두 지우고 새로 예약한다.
abstract interface class NotificationScheduler {
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// flutter_local_notifications 구현. 정확한 알람 권한 없이 inexact 로 예약한다.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'weekly_goal',
    '주간 목표 알림',
    channelDescription: '금요일 저녁에 이번 주 목표를 알려 줘요',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;
  bool _permissionAsked = false;

  Future<void> _ensureInit() => _init ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    try {
      await _ensureInit();
    } catch (_) {
      _init = null; // 다음 호출에서 다시 시도한다.
      rethrow;
    }
    if (!_permissionAsked) {
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        _permissionAsked = true;
      } catch (_) {
        // 권한 요청이 실패해도 예약은 진행하고, 다음에 다시 묻는다.
      }
    }
    await _plugin.cancelAllPendingNotifications();
    for (var i = 0; i < reminders.length; i++) {
      final r = reminders[i];
      await _plugin.zonedSchedule(
        id: i,
        title: '러니',
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
