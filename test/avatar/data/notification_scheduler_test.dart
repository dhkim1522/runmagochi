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
  final cancelledIds = <int>[];
  final shownIds = <int>[];

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
  }) async {
    shownIds.add(id);
    shown.add((title!, notificationDetails?.android?.channelId));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelledIds.add(id);

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

  test('목표 달성 알림은 자동 종료와 다른 번호라 따로 지울 수 있다', () async {
    await scheduler.showNow(title: '종료', body: 'b');
    await scheduler.showGoalReached(title: '달성', body: 'b');
    await scheduler.cancelGoalReached();

    expect(plugin.shownIds, [1000, 1002]);
    expect(plugin.cancelledIds, [1002]);
  });

  test('자동 종료 알림만 지울 수 있다', () async {
    await scheduler.showNow(title: '종료', body: 'b');
    await scheduler.showGoalReached(title: '달성', body: 'b');
    await scheduler.cancelAutoEnd();

    expect(plugin.cancelledIds, [1000]);
  });

  test('예약 취소 때 예전 주간 목표 채널을 지운다', () async {
    await scheduler.cancelScheduled();

    expect(plugin.cancelled, 1);
    expect(plugin.android.deleted, ['weekly_goal']);
  });
}
