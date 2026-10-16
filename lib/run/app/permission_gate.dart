import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum GateResult {
  ready,
  needsLocation,
  locationDeniedForever,
  needsBatteryGuide,
}

abstract interface class PermissionGate {
  Future<GateResult> check();

  /// 정밀 위치 + 알림 권한을 요청하고 새 [check] 결과를 돌려준다.
  Future<GateResult> requestLocation();

  /// 앱 설정 화면을 연다.
  Future<void> openBatterySettings();

  /// 배터리 안내를 이번 앱 실행 동안 다시 띄우지 않는다.
  void dismissBatteryGuide();
}

class PermissionHandlerGate implements PermissionGate {
  bool _batteryGuideDismissed = false;

  @override
  Future<GateResult> check() async {
    final location = await Permission.locationWhenInUse.status;
    if (location.isPermanentlyDenied) return GateResult.locationDeniedForever;
    if (!location.isGranted) return GateResult.needsLocation;
    if (!_batteryGuideDismissed &&
        !(await Permission.ignoreBatteryOptimizations.status).isGranted) {
      return GateResult.needsBatteryGuide;
    }
    return GateResult.ready;
  }

  @override
  Future<GateResult> requestLocation() async {
    await Permission.locationWhenInUse.request();
    await Permission.notification.request();
    return check();
  }

  @override
  Future<void> openBatterySettings() async {
    await openAppSettings();
  }

  @override
  void dismissBatteryGuide() => _batteryGuideDismissed = true;
}

final permissionGateProvider = Provider<PermissionGate>(
  (_) => PermissionHandlerGate(),
);
