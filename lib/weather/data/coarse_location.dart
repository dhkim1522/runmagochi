import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// 날씨용 대략 위치. 권한을 새로 묻지 않는다.
abstract interface class CoarseLocation {
  /// (위도, 경도). 권한이 없거나 모르면 null.
  Future<(double, double)?> lastKnown();
}

/// 이미 받은 위치 권한으로 마지막 위치를 읽는다. 없으면 낮은 정확도로 한 번 짧게 찾는다.
class GeolocatorCoarseLocation implements CoarseLocation {
  const GeolocatorCoarseLocation();

  @override
  Future<(double, double)?> lastKnown() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final last = await Geolocator.getLastKnownPosition();
      final p =
          last ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 5),
            ),
          );
      return (p.latitude, p.longitude);
    } catch (e) {
      debugPrint('날씨: 위치 읽기 실패 $e');
      return null;
    }
  }
}
