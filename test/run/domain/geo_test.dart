import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/geo.dart';

void main() {
  test('서울역-시청 직선거리', () {
    final d = haversineMeters(37.5547, 126.9707, 37.5663, 126.9779);
    expect(d, closeTo(1450, 30));
  });
}
