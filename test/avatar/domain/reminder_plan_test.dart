import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/reminder_plan.dart';

void main() {
  // 2026-10-14 는 수요일. 이번 주 금요일은 10-16.
  test('수요일 6.2km/10km: 이번 주 금 18:00 + 다음 3주', () {
    final plan = planReminders(
      now: DateTime(2026, 10, 14, 9),
      weekTargetM: 10000,
      weekDistanceM: 6200,
      weekAchieved: false,
    );
    expect(plan.map((r) => r.at), [
      DateTime(2026, 10, 16, 18),
      DateTime(2026, 10, 23, 18),
      DateTime(2026, 10, 30, 18),
      DateTime(2026, 11, 6, 18),
    ]);
    expect(plan[0].body, '이번 주 목표까지 3.80km 남았어요');
    expect(plan[1].body, '이번 주 목표 10km, 러니와 달려 볼까요?');
  });

  test('이번 주 달성이면 다음 3주만', () {
    final plan = planReminders(
      now: DateTime(2026, 10, 14, 9),
      weekTargetM: 10000,
      weekDistanceM: 10000,
      weekAchieved: true,
    );
    expect(plan.map((r) => r.at), [
      DateTime(2026, 10, 23, 18),
      DateTime(2026, 10, 30, 18),
      DateTime(2026, 11, 6, 18),
    ]);
  });

  test('금요일 18:01 이면 이번 주 것은 없다', () {
    final plan = planReminders(
      now: DateTime(2026, 10, 16, 18, 1),
      weekTargetM: 10000,
      weekDistanceM: 0,
      weekAchieved: false,
    );
    expect(plan.length, 3);
    expect(plan.first.at, DateTime(2026, 10, 23, 18));
  });

  test('목표가 12.5km 면 소수 그대로 적는다', () {
    final plan = planReminders(
      now: DateTime(2026, 10, 14),
      weekTargetM: 12500,
      weekDistanceM: 0,
      weekAchieved: true,
    );
    expect(plan.first.body, '이번 주 목표 12.5km, 러니와 달려 볼까요?');
  });
}
