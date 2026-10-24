import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/local_notifications.dart';
import '../domain/reminder_plan.dart';

/// 쉬는 날 알림 예약. 한 번에 하나만 둔다.
abstract interface class ReminderScheduler {
  /// [plan] 시각에 알림을 예약한다. 이전 예약은 같은 번호라 덮어쓴다.
  Future<void> schedule(ReminderPlan plan);

  /// 예약한 쉬는 날 알림을 지운다.
  Future<void> cancel();
}

/// flutter_local_notifications 구현. 시간대 자료 없이 UTC 로 바꿔 예약한다
/// (기기 시간대가 바뀌어도 같은 순간에 뜬다). 정확한 알람 권한이 필요 없게
/// 느슨한 예약(inexactAllowWhileIdle)을 쓴다. 몇 분 늦을 수 있다.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'rest_reminder';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> schedule(ReminderPlan plan) async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      await _plugin.zonedSchedule(
        id: NotificationIds.reminder,
        title: plan.title,
        body: plan.body,
        scheduledDate: tz.TZDateTime.from(plan.at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            '쉬는 날 알림',
            channelDescription: '며칠 쉬면 캐릭터가 한 번 불러요',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      debugPrint('알림: 쉬는 날 알림 예약 실패 $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      await _plugin.cancel(id: NotificationIds.reminder);
    } catch (e, st) {
      debugPrint('알림: 쉬는 날 알림 취소 실패 $e\n$st');
      rethrow;
    }
  }
}
