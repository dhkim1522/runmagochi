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
  );
}
