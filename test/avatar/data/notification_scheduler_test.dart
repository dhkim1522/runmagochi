import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';

class _FakeAndroid extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  final deleted = <String>[];

  @override
  Future<void> deleteNotificationChannel({required String channelId}) async =>
      deleted.add(channelId);
}

class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  final android = _FakeAndroid();
  final shown = <(String, String?)>[]; // (제목, 채널 id)
  var cancelled = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<void> cancelAllPendingNotifications() async => cancelled++;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async => shown.add((title!, notificationDetails?.android?.channelId));

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => android as T;
}

void main() {
  late _FakePlugin plugin;
  late LocalNotificationScheduler scheduler;

  setUp(() {
    plugin = _FakePlugin();
    scheduler = LocalNotificationScheduler(plugin);
  });

  test('목표 달성 알림은 자동 종료와 다른 채널로 보낸다', () async {
    await scheduler.showNow(title: '종료', body: 'b');
    await scheduler.showGoalReached(title: '달성', body: 'b');

    expect(plugin.shown, [('종료', 'run_auto_end'), ('달성', 'run_goal')]);
  });

  test('예약 취소 때 예전 주간 목표 채널을 지운다', () async {
    await scheduler.cancelScheduled();

    expect(plugin.cancelled, 1);
    expect(plugin.android.deleted, ['weekly_goal']);
  });
}
