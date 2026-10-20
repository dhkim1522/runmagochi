import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 예약된 알림 취소. 이전 버전이 예약해 둔 알림을 지우는 데 쓴다.
abstract interface class NotificationScheduler {
  /// 예약만 기다리는 알림을 모두 취소한다. 이미 띄운 알림은 그대로 둔다.
  Future<void> cancelScheduled();
}

/// 바로 띄우는 알림. 예: 러닝 자동 종료.
abstract interface class InstantNotifier {
  Future<void> showNow({required String title, required String body});
}

/// 기기가 준 시간대 이름을 찾는다. 시간대 데이터는 별칭(GMT, Asia/Calcutta 등)까지
/// 들어 있는 전체판을 쓴다. 그래도 모르는 이름이면 UTC 로 대신한다. 예약 시각은
/// 절대 시각으로 넘기므로 UTC 여도 알림 시각은 같다.
tz.Location resolveTimeZone(String identifier) {
  tzdata.initializeTimeZones();
  try {
    return tz.getLocation(identifier);
  } on tz.LocationNotFoundException {
    debugPrint('알림: 시간대 "$identifier" 를 몰라 UTC 로 대신한다.');
    return tz.UTC;
  }
}

/// flutter_local_notifications 구현. 정확한 알람 권한 없이 inexact 로 예약한다.
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
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(resolveTimeZone(zone.identifier));
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
    } catch (e, st) {
      debugPrint('알림: 예약 취소 실패 $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> showNow({required String title, required String body}) async {
    try {
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
    } catch (e, st) {
      debugPrint('알림: 즉시 알림 실패 $e\n$st');
      rethrow;
    }
  }
}
