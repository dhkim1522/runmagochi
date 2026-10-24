import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/local_notifications.dart';
import 'package:runmagochi/reminder/data/reminder_scheduler.dart';
import 'package:runmagochi/reminder/domain/reminder_plan.dart';
import 'package:timezone/timezone.dart' as tz;

class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final scheduled = <(int, tz.TZDateTime, String?, AndroidScheduleMode)>[];
  final cancelled = <int>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async => scheduled.add((id, scheduledDate, title, androidScheduleMode));

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);
}

void main() {
  test('같은 순간을 UTC 로 바꿔 느슨하게 예약하고, 같은 번호로 지운다', () async {
    final plugin = _FakePlugin();
    final scheduler = LocalReminderScheduler(plugin);
    final at = DateTime(2026, 10, 23, 19);
    await scheduler.schedule(
      ReminderPlan(at: at, title: '말랑이 기다리는 중', body: '오늘 가볍게 같이 달려요'),
    );
    final (id, date, title, mode) = plugin.scheduled.single;
    expect(id, NotificationIds.reminder);
    expect(date.isAtSameMomentAs(at), isTrue);
    expect(date.location, tz.UTC);
    expect(title, '말랑이 기다리는 중');
    expect(mode, AndroidScheduleMode.inexactAllowWhileIdle);

    await scheduler.cancel();
    expect(plugin.cancelled, [NotificationIds.reminder]);
  });
}
