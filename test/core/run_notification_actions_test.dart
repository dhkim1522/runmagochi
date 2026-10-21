import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/local_notifications.dart';

NotificationResponse _response(String? actionId) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotificationAction,
  actionId: actionId,
);

void main() {
  tearDown(() {
    IsolateNameServer.removePortNameMapping(runNotificationActionsPortName);
  });

  test('포트가 없으면 백그라운드 함수는 예외 없이 끝난다', () {
    IsolateNameServer.removePortNameMapping(runNotificationActionsPortName);
    expect(
      () => onRunNotificationBackgroundResponse(_response('run_pause')),
      returnsNormally,
    );
  });

  test('등록된 포트로 액션 id 를 보낸다', () async {
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      runNotificationActionsPortName,
    );
    final first = port.first;
    onRunNotificationBackgroundResponse(_response('run_resume'));
    expect(await first, 'run_resume');
    port.close();
  });

  test('액션 id 가 없는 응답(본문 탭)은 보내지 않는다', () async {
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      runNotificationActionsPortName,
    );
    final received = <Object?>[];
    port.listen(received.add);
    onRunNotificationBackgroundResponse(_response(null));
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    port.close();
  });

  test('메인 isolate 포트를 등록하고 받은 id 를 스트림으로 내보낸다', () async {
    final stream = registerRunNotificationActionPort();
    final first = stream.first;
    onRunNotificationBackgroundResponse(_response('run_pause'));
    expect(await first, 'run_pause');
  });
}
