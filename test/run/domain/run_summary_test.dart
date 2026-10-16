import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

void main() {
  test('autoRunName 은 요일과 시간대로 이름을 짓는다', () {
    expect(autoRunName(DateTime(2026, 10, 16, 19)), '금요일 저녁 러닝');
    expect(autoRunName(DateTime(2026, 10, 17, 6)), '토요일 아침 러닝');
  });

  test('autoRunName 시간대 경계', () {
    // 2026-10-12 는 월요일.
    String at(int hour) => autoRunName(DateTime(2026, 10, 12, hour));
    expect(at(0), '월요일 새벽 러닝');
    expect(at(4), '월요일 새벽 러닝');
    expect(at(5), '월요일 아침 러닝');
    expect(at(11), '월요일 점심 러닝');
    expect(at(14), '월요일 오후 러닝');
    expect(at(18), '월요일 저녁 러닝');
    expect(at(22), '월요일 밤 러닝');
    expect(at(23), '월요일 밤 러닝');
    expect(autoRunName(DateTime(2026, 10, 18, 12)), '일요일 점심 러닝');
  });

  test('estimateCalories(5000) ≈ 336.7', () {
    expect(estimateCalories(5000), closeTo(336.7, 0.1));
    expect(estimateCalories(5000, weightKg: 80), closeTo(414.4, 0.1));
  });

  test('Split.paceSecPerKm = duration ÷ km', () {
    const split = Split(
      index: 3,
      distanceM: 500,
      duration: Duration(seconds: 200),
    );
    expect(split.paceSecPerKm, closeTo(400, 1e-9));
  });
}
