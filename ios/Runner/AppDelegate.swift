import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 알림 응답(본문 탭·버튼)과 앱이 열려 있을 때의 알림 표시를 flutter_local_notifications 가 받게 한다.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // 알림 버튼(일시정지·재개)은 별도 엔진에서 처리된다. 그 엔진에도 플러그인을 등록한다.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBatteryChannel(engineBridge.pluginRegistry)
  }

  /// Android 배터리 최적화 예외 채널(`runmagochi/battery`)의 iOS 짝.
  /// iOS 에는 앱별 배터리 최적화 예외가 없고, 백그라운드 위치 모드로 기록이 이어지므로
  /// 늘 예외 상태라고 답해 배터리 안내를 띄우지 않는다.
  private func registerBatteryChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "RunmagochiBattery") else { return }
    let channel = FlutterMethodChannel(
      name: "runmagochi/battery",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isIgnoringBatteryOptimizations":
        result(true)
      case "openBatteryOptimizationSettings":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
