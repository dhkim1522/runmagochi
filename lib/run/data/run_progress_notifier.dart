import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/format.dart';
import '../../core/local_notifications.dart';
import '../domain/run_engine.dart';

/// 알림 버튼이 하는 일.
enum RunProgressAction { pause, resume }

/// 러닝 진행 알림에 보일 내용.
class RunProgressContent {
  const RunProgressContent({
    required this.title,
    required this.body,
    required this.elapsed,
    required this.action,
  });

  final String title;
  final String body;

  /// 있으면 알림이 크로노미터로 시간을 올린다(`when = 지금 - elapsed`).
  final Duration? elapsed;
  final RunProgressAction action;

  @override
  bool operator ==(Object other) =>
      other is RunProgressContent &&
      other.title == title &&
      other.body == body &&
      other.elapsed == elapsed &&
      other.action == action;

  @override
  int get hashCode => Object.hash(title, body, elapsed, action);

  @override
  String toString() =>
      'RunProgressContent($title | $body | $elapsed | $action)';
}

/// 러닝 중 알림창에 거리·시간·목표 진행을 보인다.
abstract interface class RunProgressNotifier {
  Future<void> show(RunProgressContent content);
  Future<void> cancel();
}

/// 상태·거리·목표로 알림 문구를 만든다. 기록 중과 일시정지·자동 일시정지 중만 다룬다.
RunProgressContent runProgressContent({
  required RunState state,
  required double distanceM,
  required Duration movingTime,
  required double? goalM,
  required bool goalReached,
}) {
  final km = '${formatKm(distanceM)}km';
  if (state == RunState.autoPaused) {
    return RunProgressContent(
      title: '멈춰서 일시정지했어요 · $km',
      body: '움직이면 이어져요',
      elapsed: null,
      action: RunProgressAction.resume,
    );
  }
  final String body;
  if (goalM == null) {
    body = '화면을 꺼도 기록이 이어져요';
  } else if (goalReached) {
    body = '목표 ${formatTargetKm(goalM)}km 달성!';
  } else {
    body = '목표 ${formatTargetKm(goalM)}km까지 ${formatKm(goalM - distanceM)}km';
  }
  if (state == RunState.paused) {
    return RunProgressContent(
      title: '일시정지 · $km · ${formatDuration(movingTime)}',
      body: body,
      elapsed: null,
      action: RunProgressAction.resume,
    );
  }
  return RunProgressContent(
    title: '러닝 중 · $km',
    body: body,
    elapsed: movingTime,
    action: RunProgressAction.pause,
  );
}

/// 위치 서비스(geolocator)가 띄우는 포그라운드 알림과 같은 번호로 덮어쓴다.
/// 결정 0021.
class LocalRunProgressNotifier implements RunProgressNotifier {
  LocalRunProgressNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// `GeolocatorLocationService.ONGOING_NOTIFICATION_ID`.
  static const notificationId = 75415;

  static const channelId = 'run_progress';
  static const pauseActionId = 'run_pause';
  static const resumeActionId = 'run_resume';

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> show(RunProgressContent content) async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      final resume = content.action == RunProgressAction.resume;
      final elapsed = content.elapsed;
      await _plugin.show(
        id: notificationId,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            '러닝 진행',
            channelDescription: '러닝 중 거리와 시간을 알림창에 보여 줘요',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            onlyAlertOnce: true,
            ongoing: true,
            autoCancel: false,
            showWhen: elapsed != null,
            when: elapsed == null
                ? null
                : DateTime.now().subtract(elapsed).millisecondsSinceEpoch,
            usesChronometer: elapsed != null,
            actions: [
              AndroidNotificationAction(
                resume ? resumeActionId : pauseActionId,
                resume ? '재개' : '일시정지',
                showsUserInterface: false,
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('알림: 러닝 진행 알림 실패 $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      await _plugin.cancel(id: notificationId);
    } catch (e, st) {
      debugPrint('알림: 러닝 진행 알림 취소 실패 $e\n$st');
      rethrow;
    }
  }
}
