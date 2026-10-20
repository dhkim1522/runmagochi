import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 예약된 알림 취소. 이전 버전이 예약해 둔 알림을 지우는 데 쓴다.
abstract interface class NotificationScheduler {
  /// 예약만 기다리는 알림을 모두 취소한다. 이미 띄운 알림은 그대로 둔다.
  Future<void> cancelScheduled();
}

/// 바로 띄우는 알림.
abstract interface class InstantNotifier {
  /// 러닝 자동 종료 알림.
  Future<void> showNow({required String title, required String body});

  /// 오늘 목표 달성 알림. 자동 종료와 알림 채널을 나눠 따로 끌 수 있게 한다.
  Future<void> showGoalReached({required String title, required String body});
}

/// flutter_local_notifications 구현.
/// 알림 권한은 페이즈 1 권한 화면(PermissionGate)이 위치 권한과 함께 요청한다.
class LocalNotificationScheduler
    implements NotificationScheduler, InstantNotifier {
  LocalNotificationScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _runChannel = AndroidNotificationDetails(
    'run_auto_end',
    '러닝 자동 종료 알림',
    channelDescription: '종료를 잊은 러닝을 자동으로 마치면 알려 줘요',
  );

  static const _goalChannel = AndroidNotificationDetails(
    'run_goal',
    '목표 달성',
    channelDescription: '오늘 목표를 채우면 알려요',
  );

  /// 예전 버전이 만든 주간 목표 알림 채널 id.
  static const _obsoleteChannelId = 'weekly_goal';

  /// 즉시 알림 번호.
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
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // 권한은 PermissionGate 가 묻는다. 초기화에서는 묻지 않는다.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<void> cancelScheduled() async {
    try {
      await _ensureInit();
      // 예약 대기 중인 것만 지운다. 이미 띄운 알림은 남는다.
      await _plugin.cancelAllPendingNotifications();
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.deleteNotificationChannel(channelId: _obsoleteChannelId);
      } catch (_) {} // 지워질 채널이 없어도 상관없다.
    } catch (e, st) {
      debugPrint('알림: 예약 취소 실패 $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) =>
      _show(_runChannel, title, body);

  @override
  Future<void> showGoalReached({required String title, required String body}) =>
      _show(_goalChannel, title, body);

  Future<void> _show(
    AndroidNotificationDetails channel,
    String title,
    String body,
  ) async {
    try {
      await _ensureInit();
      await _plugin.show(
        id: _instantId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: channel,
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      debugPrint('알림: 즉시 알림 실패 $e\n$st');
      rethrow;
    }
  }
}
