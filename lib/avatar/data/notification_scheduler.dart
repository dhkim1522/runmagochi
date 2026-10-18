import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
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
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    try {
      await _ensureInit();
      await _plugin.cancelAllPendingNotifications();
      for (var i = 0; i < reminders.length; i++) {
        final r = reminders[i];
        await _plugin.zonedSchedule(
          id: i,
          title: '러니',
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: _channel,
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e, st) {
      debugPrint('알림: 주간 알림 예약 실패 $e\n$st');
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
