import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_plan.dart';

/// 주간 목표 알림 예약. 이전 예약을 모두 지우고 새로 예약한다.
abstract interface class NotificationScheduler {
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

/// 바로 띄우는 알림. 예: 러닝 자동 종료.
abstract interface class InstantNotifier {
  Future<void> showNow({required String title, required String body});
}

/// flutter_local_notifications 구현. 정확한 알람 권한 없이 inexact 로 예약한다.
/// 알림 권한은 페이즈 1 권한 화면(PermissionGate)이 위치 권한과 함께 요청한다.
class LocalNotificationScheduler
    implements NotificationScheduler, InstantNotifier {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationDetails(
    'weekly_goal',
    '주간 목표 알림',
    channelDescription: '금요일 저녁에 이번 주 목표를 알려 줘요',
  );

  static const _runChannel = AndroidNotificationDetails(
    'run_auto_end',
    '러닝 자동 종료 알림',
    channelDescription: '종료를 잊은 러닝을 자동으로 마치면 알려 줘요',
  );

  /// 즉시 알림 번호. 주간 알림(0부터 차례로)과 겹치지 않게 둔다.
  static const _instantId = 1000;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _init;

  Future<void> _ensureInit() async {
    try {
      await (_init ??= _initialize());
    } catch (_) {
      _init = null; // 다음 호출에서 다시 시도한다.
      rethrow;
    }
  }

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
    await _ensureInit();
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

  @override
  Future<void> showNow({required String title, required String body}) async {
    await _ensureInit();
    await _plugin.show(
      id: _instantId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _runChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
