import '../domain/location_sample.dart';

abstract interface class LocationSource {
  /// 위치 점 스트림. 기기의 위치 서비스가 꺼져 끊기면 [LocationServiceOffException]
  /// 오류를 낸다.
  Stream<LocationSample> watch();

  /// 기기의 위치 서비스(GPS)가 켜져 있는가. 시스템 창을 띄우지 않고 확인만 한다.
  Future<bool> isServiceEnabled();
}

/// 기기의 위치 서비스(GPS)가 꺼져 위치 스트림이 끊겼다.
class LocationServiceOffException implements Exception {
  const LocationServiceOffException();

  @override
  String toString() => 'LocationServiceOffException';
}
