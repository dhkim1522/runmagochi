import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum GateResult {
  ready,
  needsLocation,
  needsPreciseLocation,
  locationDeniedForever,
  needsBatteryGuide,
}

abstract interface class PermissionGate {
  Future<GateResult> check();

  /// 정밀 위치 + 알림 권한을 요청하고 새 [check] 결과를 돌려준다.
  Future<GateResult> requestLocation();

  /// 배터리 최적화 설정 화면을 연다.
  Future<void> openBatterySettings();

  /// 앱 설정 화면을 연다.
  Future<void> openAppSettings();

  /// 배터리 안내를 이번 앱 실행 동안 다시 띄우지 않는다.
  void dismissBatteryGuide();
}

class PermissionHandlerGate implements PermissionGate {
  PermissionHandlerGate({
    Future<ph.PermissionStatus> Function()? locationStatus,
    Future<LocationAccuracyStatus> Function()? locationAccuracy,
    Future<ph.PermissionStatus> Function()? requestLocationPermission,
    Future<ph.PermissionStatus> Function()? requestNotificationPermission,
  }) : _locationStatus =
           locationStatus ?? (() => ph.Permission.locationWhenInUse.status),
       _requestLocation =
           requestLocationPermission ??
           (() => ph.Permission.locationWhenInUse.request()),
       _requestNotification =
           requestNotificationPermission ??
           (() => ph.Permission.notification.request()),
       _locationAccuracy = locationAccuracy ?? Geolocator.getLocationAccuracy;

  static const _battery = MethodChannel('runmagochi/battery');

  final Future<ph.PermissionStatus> Function() _locationStatus;
  final Future<LocationAccuracyStatus> Function() _locationAccuracy;
  final Future<ph.PermissionStatus> Function() _requestLocation;
  final Future<ph.PermissionStatus> Function() _requestNotification;
  bool _batteryGuideDismissed = false;

  /// 요청 결과가 영구 거부였다. Android 는 상태 조회([_locationStatus])가 영구
  /// 거부를 알려주지 않고 denied 만 준다. 요청 창이 닫히며 앱이 다시 활성화될 때
  /// 화면이 부르는 [check] 가 영구 거부를 덮어쓰지 않게 기억한다. 허용되면 잊는다.
  bool _deniedForever = false;

  @override
  Future<GateResult> check() async {
    final location = await _locationStatus();
    if (location.isPermanentlyDenied) return GateResult.locationDeniedForever;
    // 설정에서 대략적인 위치만 허용했으면 영구 거부가 아니다.
    if (await _isReducedAccuracy()) return GateResult.needsPreciseLocation;
    if (location.isGranted) {
      _deniedForever = false;
    } else {
      return _deniedForever
          ? GateResult.locationDeniedForever
          : GateResult.needsLocation;
    }
    if (!_batteryGuideDismissed &&
        await _battery.invokeMethod<bool>('isIgnoringBatteryOptimizations') !=
            true) {
      return GateResult.needsBatteryGuide;
    }
    return GateResult.ready;
  }

  // 대략적인 위치만 허용되면 정확도 20m 초과 점이 모두 버려져 거리가 0이 된다.
  Future<bool> _isReducedAccuracy() async {
    try {
      return await _locationAccuracy() == LocationAccuracyStatus.reduced;
    } on PlatformException {
      // 위치 권한이 전혀 없으면 정확도 조회가 오류를 낸다.
      return false;
    }
  }

  @override
  Future<GateResult> requestLocation() async {
    final location = await _requestLocation();
    await _requestNotification();
    // Android 는 status 가 영구 거부를 알려주지 않아, 요청 결과로만 알 수 있다.
    if (location.isPermanentlyDenied) {
      _deniedForever = true;
      return GateResult.locationDeniedForever;
    }
    return check();
  }

  @override
  Future<void> openBatterySettings() =>
      _battery.invokeMethod<void>('openBatteryOptimizationSettings');

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  @override
  void dismissBatteryGuide() => _batteryGuideDismissed = true;
}

final permissionGateProvider = Provider<PermissionGate>(
  (_) => PermissionHandlerGate(),
);
