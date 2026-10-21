import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // 권한은 PermissionGate 가 묻는다. 초기화에서는 묻지 않는다.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: forwardRunNotificationAction,
    onDidReceiveBackgroundNotificationResponse:
        onRunNotificationBackgroundResponse,
  );
}

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
