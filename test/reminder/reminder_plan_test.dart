import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/reminder/domain/reminder_plan.dart';

void main() {
  final lastRun = DateTime(2026, 10, 20, 7, 30); // 화요일 아침

  ReminderPlan? plan({DateTime? now, double? km = 3.2, DateTime? last}) =>
      planReminder(
        now: now ?? DateTime(2026, 10, 20, 9),
        lastRunAt: last ?? lastRun,
        petName: '말랑이',
        kmToNextLevel: km,
      );

  test('마지막 러닝 날부터 3일째 저녁 7시(현지)에 한 번', () {
    expect(plan()!.at, DateTime(2026, 10, 23, 19));
  });

  test('제목은 이름 뒤 조사 없이, 본문은 가볍게 같이 달리자는 말', () {
    final p = plan()!;
    expect(p.title, '말랑이 기다리는 중');
    expect(p.body, '오늘 가볍게 같이 달려요');
  });

  test('다음 레벨까지 1km 이하면 남은 거리를 말한다', () {
    expect(plan(km: 0.84)!.body, '0.8km만 더 달리면 레벨 업이에요');
    expect(plan(km: 1.0)!.body, '1.0km만 더 달리면 레벨 업이에요');
    expect(plan(km: 1.05)!.body, '오늘 가볍게 같이 달려요');
  });

  test('러닝 기록이 없으면 예약하지 않는다', () {
    expect(
      planReminder(
        now: DateTime(2026, 10, 20),
        lastRunAt: null,
        petName: '말랑이',
        kmToNextLevel: 5,
      ),
      isNull,
    );
  });

  test('이미 그 시각이 지났으면 다시 부르지 않는다(쉬는 동안 한 번만)', () {
    expect(plan(now: DateTime(2026, 10, 23, 19)), isNull);
    expect(plan(now: DateTime(2026, 10, 30)), isNull);
    expect(plan(now: DateTime(2026, 10, 23, 18, 59)), isNotNull);
  });
}
