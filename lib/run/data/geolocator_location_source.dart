import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_sample.dart';
import 'location_source.dart';

class GeolocatorLocationSource implements LocationSource {
  @override
  Stream<LocationSample> watch() {
    return Geolocator.getPositionStream(locationSettings: _settings()).map(
      (p) => LocationSample(
        time: p.timestamp,
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
      ),
    );
  }

  /// 거리 거름은 두지 않는다(0). 멈춰 서도 1초마다 점이 와야 신호 끊김(점 30초
  /// 없음)과 멈춤을 구별한다. 최소 이동 3m 는 기록 엔진이 거른다 (결정 0033).
  static const int _distanceFilterM = 0;

  LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // 기본 LocationSettings 는 iOS 백그라운드 위치를 끈다. '앱 사용 중' 권한이라도
      // 화면에 있을 때 시작했고 Background Modes 에 location 이 있으면 화면을 꺼도 이어진다.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterM,
        activityType: ActivityType.fitness,
        // 멈춰 있을 때 iOS 가 위치를 멈추면 백그라운드에서 다시 켜지지 않는다.
        // 자동 일시정지는 기록 엔진이 판단한다.
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        // 상태 막대에 위치 사용 표시를 띄워 기록 중임을 보인다.
        showBackgroundLocationIndicator: true,
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterM,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterM,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: '러닝 기록 중',
        notificationText: '화면을 꺼도 기록이 이어집니다',
        notificationChannelName: '러닝 기록',
        enableWakeLock: true,
      ),
    );
  }
}
