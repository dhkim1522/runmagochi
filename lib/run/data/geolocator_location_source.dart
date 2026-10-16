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

  // iOS 설정은 페이즈 3.
  LocationSettings _settings() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: '러닝 기록 중',
        notificationText: '화면을 꺼도 기록이 이어집니다',
        enableWakeLock: true,
      ),
    );
  }
}
