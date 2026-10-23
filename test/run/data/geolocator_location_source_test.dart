import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runmagochi/run/data/geolocator_location_source.dart';
import 'package:runmagochi/run/data/location_source.dart';

void main() {
  test('위치 서비스 꺼짐 오류는 LocationServiceOffException 으로 바꾼다', () {
    expect(
      locationErrorFrom(const LocationServiceDisabledException()),
      isA<LocationServiceOffException>(),
    );
  });

  test('다른 오류는 그대로 둔다', () {
    final error = StateError('gps');
    expect(locationErrorFrom(error), same(error));
  });
}
