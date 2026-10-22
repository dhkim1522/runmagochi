import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 앱이 쓰는 알림 번호 모음. 번호가 겹치면 알림이 서로를 덮어쓰거나 지우므로
/// 새 알림은 여기에 추가한다.
abstract final class NotificationIds {
  /// 자동 종료 알림.
  static const autoEnd = 1000;

  /// 종료 예고 알림. 러닝 알림과 따로 띄워 진동한다.
  static const endWarning = 1001;

  /// 목표 달성 알림. 자동 종료 알림과 나눠, 러닝이 끝날 때 목표 달성 알림만
  /// 지우고 방금 띄운 자동 종료 알림은 남긴다.
  static const goalReached = 1002;

  /// 러닝 진행 알림. `GeolocatorLocationService.ONGOING_NOTIFICATION_ID`.
  static const runProgress = 75415;

  static const all = [autoEnd, endWarning, goalReached, runProgress];
}

/// 플러그인마다 한 번만 초기화한다.
final Expando<Future<void>> _inits = Expando<Future<void>>();

/// flutter_local_notifications 초기화. 앱 전체에서 이 함수 한 곳만 `initialize`
/// 를 부른다. 이미 했으면 같은 결과를 돌려주고, 실패하면 다음 호출에서 다시 한다.
Future<void> ensureLocalNotificationsInitialized(
  FlutterLocalNotificationsPlugin plugin,
) async {
  try {
    await (_inits[plugin] ??= _initialize(plugin));
  } catch (_) {
    _inits[plugin] = null;
    rethrow;
  }
}

Future<void> _initialize(FlutterLocalNotificationsPlugin plugin) async {
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      // 권한은 PermissionGate 가 묻는다. 초기화에서는 묻지 않는다.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: darwinRunNotificationCategories,
      ),
    ),
    onDidReceiveNotificationResponse: forwardRunNotificationAction,
    onDidReceiveBackgroundNotificationResponse:
        onRunNotificationBackgroundResponse,
  );
}

/// 러닝 알림 버튼 id. Android·iOS 가 같은 id 를 쓴다.
const String runPauseActionId = 'run_pause';
const String runResumeActionId = 'run_resume';

/// iOS 는 알림 버튼을 초기화 때 등록한 묶음(category)으로만 붙일 수 있다.
/// 러닝 알림에 나오는 버튼 조합마다 묶음을 하나씩 둔다. 버튼은 앱을 열지 않고
/// 백그라운드에서 처리된다([onRunNotificationBackgroundResponse]).
const String darwinRunPauseCategory = 'run_actions_pause';
const String darwinRunResumeCategory = 'run_actions_resume';
const String darwinRunResumePauseCategory = 'run_actions_resume_pause';

final List<DarwinNotificationCategory> darwinRunNotificationCategories = [
  DarwinNotificationCategory(
    darwinRunPauseCategory,
    actions: [DarwinNotificationAction.plain(runPauseActionId, '일시정지')],
  ),
  DarwinNotificationCategory(
    darwinRunResumeCategory,
    actions: [DarwinNotificationAction.plain(runResumeActionId, '재개')],
  ),
  DarwinNotificationCategory(
    darwinRunResumePauseCategory,
    actions: [
      DarwinNotificationAction.plain(runResumeActionId, '재개'),
      DarwinNotificationAction.plain(runPauseActionId, '일시정지'),
    ],
  ),
];

/// 메인 isolate 가 알림 버튼 id 를 받는 포트의 등록 이름.
const runNotificationActionsPortName = 'run_notification_actions';

/// 메인 isolate 에서 받은 알림 응답의 버튼 id 를 포트로 보낸다.
/// 버튼이 아닌 응답(본문 탭)이나 등록된 포트가 없으면 아무것도 하지 않는다.
void forwardRunNotificationAction(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;
  try {
    IsolateNameServer.lookupPortByName(
      runNotificationActionsPortName,
    )?.send(actionId);
  } catch (_) {
    // 버튼 처리는 최선 노력이다. 오류가 isolate 밖으로 나가지 않게 한다.
  }
}

/// 앱이 백그라운드 isolate 에서 알림 버튼을 받을 때 불린다. 별도 isolate 라
/// 메인 isolate 의 포트로 id 만 넘긴다. 포트가 없으면(앱 프로세스 없음) 무시한다.
@pragma('vm:entry-point')
void onRunNotificationBackgroundResponse(NotificationResponse response) =>
    forwardRunNotificationAction(response);

/// 메인 isolate 에서 포트를 등록하고 받은 버튼 id 를 스트림으로 내보낸다.
/// 남아 있던 같은 이름의 등록은 먼저 지운다. 앱 시작 때 한 번만 부른다.
Stream<String> registerRunNotificationActionPort() {
  final port = ReceivePort();
  IsolateNameServer.removePortNameMapping(runNotificationActionsPortName);
  IsolateNameServer.registerPortWithName(
    port.sendPort,
    runNotificationActionsPortName,
  );
  return port.where((message) => message is String).cast<String>();
}
