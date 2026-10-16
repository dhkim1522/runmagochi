import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/format.dart';

void main() {
  test('formatPace', () {
    expect(formatPace(385), "6'25\"");
    expect(formatPace(null), "-'--\"");
    expect(formatPace(359.6), "6'00\"");
    expect(formatPace(305), "5'05\"");
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 62, seconds: 5)), '1:02:05');
    expect(formatDuration(const Duration(minutes: 18, seconds: 42)), '18:42');
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
  });

  test('formatKm', () {
    expect(formatKm(2910), '2.91');
    expect(formatKm(0), '0.00');
    expect(formatKm(12345), '12.35');
  });
}
