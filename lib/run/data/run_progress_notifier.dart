import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/format.dart';
import '../../core/local_notifications.dart';
import '../domain/run_engine.dart';
import '../domain/run_goal.dart';

/// 알림 버튼이 하는 일.
enum RunProgressAction { pause, resume }

/// 러닝 진행 알림에 보일 내용.
class RunProgressContent {
  const RunProgressContent({
    required this.title,
    required this.body,
    required this.elapsed,
    required this.actions,
  });

  final String title;
  final String body;

  /// 있으면 알림이 크로노미터로 시간을 올린다(`when = 지금 - elapsed`).
  final Duration? elapsed;

  /// 알림 버튼. 앞에서부터 놓인다.
  final List<RunProgressAction> actions;

  @override
  bool operator ==(Object other) =>
      other is RunProgressContent &&
      other.title == title &&
      other.body == body &&
      other.elapsed == elapsed &&
      listEquals(other.actions, actions);

  @override
  int get hashCode =>
      Object.hash(title, body, elapsed, Object.hashAll(actions));

  @override
  String toString() =>
      'RunProgressContent($title | $body | $elapsed | $actions)';
}

/// 러닝 중 알림창에 거리·시간·목표 진행을 보이고, 오래 멈추면 종료를 예고한다.
abstract interface class RunProgressNotifier {
  Future<void> show(RunProgressContent content);
  Future<void> cancel();

  /// [deadline] 에 러닝을 끝낸다고 진동과 카운트다운으로 알린다 (결정 0020).
  /// [paused] 가 true 면 사용자 일시정지라 움직여도 풀리지 않으므로 재개만 안내한다.
  /// [signalLost] 가 true 면 신호 끊김이 오래 이어진 경우다 (결정 0033).
  Future<void> showEndWarning(
    DateTime deadline, {
    required bool paused,
    bool signalLost = false,
  });
  Future<void> cancelEndWarning();
}

/// 사용자 일시정지 종료 예고 문구. 알림과 음성 안내가 같이 쓴다.
const String pausedEndWarningTitle = '일시정지가 길어 러닝을 마쳐요';
const String pausedEndWarningBody = '30초 안에 재개를 누르세요';

/// 탈것 의심 안내. 러닝 화면 무대 말풍선과 러닝 알림이 같이 쓴다 (결정 0033).
const String vehicleNoticeText = '혹시 뭘 타셨나요? 이 구간은 기록에서 뺄게요';

/// 신호 끊김 안내. 러닝 화면 무대 말풍선·러닝 알림·음성 안내가 같이 쓴다 (결정 0033).
const String signalLostNotice = '신호가 끊겼어요. 밖으로 나오면 다시 찾을게요';

/// 신호 끊김 종료 예고 제목. 알림과 음성 안내가 같이 쓴다.
const String signalLostEndWarningTitle = '신호가 오래 끊겨 러닝을 마쳐요';

/// 종료 예고 알림 문구. 자동 일시정지는 움직여도 풀리지만 사용자 일시정지는 재개만
/// 푼다. 신호 끊김은 위치 점이 다시 오거나 재개하면 풀린다.
({String title, String body}) endWarningContent({
  required bool paused,
  bool signalLost = false,
}) => paused
    ? (title: pausedEndWarningTitle, body: pausedEndWarningBody)
    : signalLost
    ? (title: signalLostEndWarningTitle, body: '30초 안에 밖으로 나오거나 재개를 누르세요')
    : (title: '움직이지 않으면 러닝을 마쳐요', body: '30초 안에 움직이거나 재개를 누르세요');

/// 종료 예고 알림이 스스로 사라질 때까지의 밀리초. 끝날 시각까지 남은 시간에
/// 여유 5초를 더해, 앱이 죽어도 알림이 러닝보다 오래 남지 않게 한다.
int endWarningTimeoutMs(DateTime deadline, DateTime now) {
  final left = deadline.difference(now);
  return (left.isNegative ? Duration.zero : left).inMilliseconds + 5000;
}

/// 상태·거리·목표로 알림 문구를 만든다. 끝나지 않은 러닝 상태만 다룬다.
/// 자동 일시정지·탈것 의심·신호 끊김은 재개와 함께 사용자 일시정지로 바꾸는 버튼을
/// 둔다(오래 쉴 때).
///
/// [vehicleNotice] 는 본문에 탈것 의심 문구를 보일지다(기록 중·탈것 의심에만 쓴다).
/// 없으면 탈것 의심 상태일 때 보인다. 컨트롤러는 문구가 60초에 한 번만 바뀌도록
/// 따로 정해 넘긴다. 제목·버튼·시간은 늘 상태를 따른다.
RunProgressContent runProgressContent({
  required RunState state,
  required double distanceM,
  required Duration movingTime,
  required RunGoal? goal,
  required bool goalReached,
  bool? vehicleNotice,
}) {
  final showVehicle =
      (vehicleNotice ?? state == RunState.vehicle) &&
      (state == RunState.vehicle || state == RunState.recording);
  final km = '${formatKm(distanceM)}km';
  if (state == RunState.autoPaused) {
    return RunProgressContent(
      title: '멈춰서 일시정지했어요 · $km',
      body: '움직이면 이어져요',
      elapsed: null,
      actions: [RunProgressAction.resume, RunProgressAction.pause],
    );
  }
  if (state == RunState.signalLost) {
    return RunProgressContent(
      title: '일시정지 · $km',
      body: signalLostNotice,
      elapsed: null,
      actions: [RunProgressAction.resume, RunProgressAction.pause],
    );
  }
  final String body;
  if (showVehicle) {
    body = vehicleNoticeText;
  } else if (goal == null) {
    body = '화면을 꺼도 기록이 이어져요';
  } else if (goalReached) {
    body = '목표 ${goal.label} 달성!';
  } else {
    final remaining = switch (goal) {
      DistanceGoal(:final meters) => '${formatKm(meters - distanceM)}km',
      TimeGoal(:final time) => formatDuration(
        time > movingTime ? time - movingTime : Duration.zero,
      ),
    };
    body = '목표 ${goal.label}까지 $remaining';
  }
  if (state == RunState.paused) {
    return RunProgressContent(
      title: '일시정지 · $km · ${formatDuration(movingTime)}',
      body: body,
      elapsed: null,
      actions: [RunProgressAction.resume],
    );
  }
  if (state == RunState.vehicle) {
    return RunProgressContent(
      title: '일시정지 · $km',
      body: body,
      elapsed: null,
      actions: [RunProgressAction.resume, RunProgressAction.pause],
    );
  }
  return RunProgressContent(
    title: '러닝 중 · $km',
    body: body,
    elapsed: movingTime,
    actions: [RunProgressAction.pause],
  );
}

/// 위치 서비스(geolocator)가 띄우는 포그라운드 알림과 같은 번호로 덮어쓴다.
/// 결정 0021.
class LocalRunProgressNotifier implements RunProgressNotifier {
  LocalRunProgressNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const notificationId = NotificationIds.runProgress;

  static const channelId = 'run_progress';
  static const pauseActionId = runPauseActionId;
  static const resumeActionId = runResumeActionId;

  static const endWarningId = NotificationIds.endWarning;
  static const endWarningChannelId = 'run_end_warning';

  static const _pauseAction = AndroidNotificationAction(
    pauseActionId,
    '일시정지',
    showsUserInterface: false,
  );
  static const _resumeAction = AndroidNotificationAction(
    resumeActionId,
    '재개',
    showsUserInterface: false,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  /// iOS 러닝 알림. 같은 번호로 몇 초마다 덮어쓰므로 소리·배너 없이 알림 목록에만
  /// 조용히 둔다(passive). 버튼은 조합에 맞는 묶음(category)으로 붙인다.
  static DarwinNotificationDetails _darwinProgress(
    List<RunProgressAction> actions,
  ) => DarwinNotificationDetails(
    presentAlert: false,
    presentBanner: false,
    presentSound: false,
    presentBadge: false,
    presentList: true,
    interruptionLevel: InterruptionLevel.passive,
    categoryIdentifier: switch (actions) {
      [RunProgressAction.pause] => darwinRunPauseCategory,
      [RunProgressAction.resume] => darwinRunResumeCategory,
      _ => darwinRunResumePauseCategory,
    },
  );

  @override
  Future<void> show(RunProgressContent content) async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
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
              for (final action in content.actions)
                switch (action) {
                  RunProgressAction.resume => _resumeAction,
                  RunProgressAction.pause => _pauseAction,
                },
            ],
          ),
          iOS: _darwinProgress(content.actions),
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

  @override
  Future<void> showEndWarning(
    DateTime deadline, {
    required bool paused,
    bool signalLost = false,
  }) async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      final content = endWarningContent(paused: paused, signalLost: signalLost);
      await _plugin.show(
        id: endWarningId,
        title: content.title,
        body: content.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            endWarningChannelId,
            '러닝 종료 예고',
            channelDescription: '오래 멈추면 러닝을 마치기 전에 알려 줘요',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            showWhen: true,
            when: deadline.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: endWarningTimeoutMs(deadline, DateTime.now()),
            actions: const [_resumeAction],
          ),
          // iOS 는 시간이 지나도 스스로 사라지지 않는다. 컨트롤러가 재개·종료 때 지운다.
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: darwinRunResumeCategory,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('알림: 종료 예고 알림 실패 $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> cancelEndWarning() async {
    try {
      await ensureLocalNotificationsInitialized(_plugin);
      await _plugin.cancel(id: endWarningId);
    } catch (e, st) {
      debugPrint('알림: 종료 예고 알림 취소 실패 $e\n$st');
      rethrow;
    }
  }
}
