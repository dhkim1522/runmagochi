import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/local_notifications.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';

class _FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  InitializationSettings? settings;
  final shown = <(int, DarwinNotificationDetails?)>[];
  final androidActions = <List<String>>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    this.settings = settings;
    return true;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shown.add((id, notificationDetails?.iOS));
    androidActions.add([
      for (final a in notificationDetails?.android?.actions ?? const [])
        a.title,
    ]);
  }
}

RunProgressContent _content(List<RunProgressAction> actions) =>
    RunProgressContent(title: 't', body: 'b', elapsed: null, actions: actions);

void main() {
  late _FakePlugin plugin;
  late LocalRunProgressNotifier notifier;

  setUp(() {
    plugin = _FakePlugin();
    notifier = LocalRunProgressNotifier(plugin);
  });

  test('iOS 러닝 알림은 소리·배너 없이 알림 목록에만 조용히 둔다', () async {
    await notifier.show(_content([RunProgressAction.pause]));

    final ios = plugin.shown.single.$2!;
    expect(ios.presentSound, false);
    expect(ios.presentBanner, false);
    expect(ios.presentAlert, false);
    expect(ios.presentList, true);
    expect(ios.interruptionLevel, InterruptionLevel.passive);
  });

  test('iOS 러닝 알림 버튼 조합마다 맞는 묶음을 붙인다', () async {
    await notifier.show(_content([RunProgressAction.pause]));
    await notifier.show(_content([RunProgressAction.resume]));
    await notifier.show(
      _content([RunProgressAction.resume, RunProgressAction.pause]),
    );

    expect(plugin.shown.map((s) => s.$2!.categoryIdentifier), [
      darwinRunPauseCategory,
      darwinRunResumeCategory,
      darwinRunResumePauseCategory,
    ]);
  });

  test('iOS 종료 예고 알림에는 재개 버튼 묶음을 붙인다', () async {
    await notifier.showEndWarning(
      DateTime.now().add(const Duration(seconds: 30)),
      paused: true,
    );

    final (id, ios) = plugin.shown.single;
    expect(id, LocalRunProgressNotifier.endWarningId);
    expect(ios!.categoryIdentifier, darwinRunResumeCategory);
  });

  test('초기화 때 iOS 버튼 묶음을 Android 와 같은 버튼 id 로 등록한다', () async {
    await notifier.show(_content([RunProgressAction.pause]));

    final categories = plugin.settings!.iOS!.notificationCategories;
    final byId = {
      for (final c in categories)
        c.identifier: [for (final a in c.actions) a.identifier],
    };
    expect(byId, {
      darwinRunPauseCategory: [LocalRunProgressNotifier.pauseActionId],
      darwinRunResumeCategory: [LocalRunProgressNotifier.resumeActionId],
      darwinRunResumePauseCategory: [
        LocalRunProgressNotifier.resumeActionId,
        LocalRunProgressNotifier.pauseActionId,
      ],
    });
  });

  test('스스로 멈춘 상태의 두 번째 버튼은 계속 쉬기다 (Android·iOS)', () async {
    await notifier.show(_content([RunProgressAction.pause]));
    await notifier.show(
      _content([RunProgressAction.resume, RunProgressAction.pause]),
    );
    // 러닝 중 버튼은 그대로 일시정지, 이미 멈춘 상태에서는 하는 일(계속 쉬기)을 이름으로 쓴다.
    expect(plugin.androidActions, [
      ['일시정지'],
      ['재개', '계속 쉬기'],
    ]);
    final titles = {
      for (final c in plugin.settings!.iOS!.notificationCategories)
        c.identifier: [for (final a in c.actions) a.title],
    };
    expect(titles[darwinRunPauseCategory], ['일시정지']);
    expect(titles[darwinRunResumePauseCategory], ['재개', '계속 쉬기']);
  });
}
