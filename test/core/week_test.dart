import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/week.dart';

void main() {
  test('일요일 23:50 은 그 주 월요일', () {
    expect(weekStartOf(DateTime(2026, 10, 18, 23, 50)), DateTime(2026, 10, 12));
  });
  test('월요일 0시는 그대로', () {
    expect(weekStartOf(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
  });
  test('달을 넘어가는 주', () {
    expect(weekStartOf(DateTime(2026, 11, 1, 10)), DateTime(2026, 10, 26));
  });
}
