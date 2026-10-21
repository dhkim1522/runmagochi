import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_stats.dart';

RunListItem r(DateTime at, double m, {int sec = 600}) => RunListItem(
  id: at.toIso8601String(),
  name: 'x',
  startedAt: at,
  distanceM: m,
  movingTime: Duration(seconds: sec),
  avgPaceSecPerKm: 400,
);

void main() {
  final anchor = DateTime(2026, 10, 17, 12); // 토요일

  test('주: 일요일 23:59 는 이번 주, 월요일 00:00 은 다음 주', () {
    final runs = [
      r(DateTime(2026, 10, 18, 23, 59), 1000),
      r(DateTime(2026, 10, 19), 2000),
      r(DateTime(2026, 10, 12), 3000),
      r(DateTime(2026, 10, 11, 23, 59), 4000),
    ];
    final s = statsFor(runs, StatsPeriod.week, anchor);
    expect(s.start, DateTime(2026, 10, 12));
    expect(s.end, DateTime(2026, 10, 19));
    expect(s.count, 2);
    expect(s.distanceM, 4000);
    expect(s.bars.length, 7);
    expect(s.bars.map((b) => b.label), ['월', '화', '수', '목', '금', '토', '일']);
    expect(s.bars[0].distanceM, 3000);
    expect(s.bars[6].distanceM, 1000);
    final next = statsFor(runs, StatsPeriod.week, DateTime(2026, 10, 19));
    expect(next.distanceM, 2000);
  });

  test('월: 말일 23:59 는 포함, 다음 달 1일 0시는 제외, 막대는 날짜 수', () {
    final runs = [
      r(DateTime(2026, 10, 31, 23, 59), 1000),
      r(DateTime(2026, 11), 5000),
      r(DateTime(2026, 10), 2000),
    ];
    final s = statsFor(runs, StatsPeriod.month, anchor);
    expect(s.count, 2);
    expect(s.bars.length, 31);
    expect(s.bars[30].distanceM, 1000);
    expect(s.bars[0].distanceM, 2000);
    expect(
      statsFor(runs, StatsPeriod.month, DateTime(2026, 2, 3)).bars.length,
      28,
    );
  });

  test('년: 12월 31일 23:59 포함, 1월 1일 제외, 막대 12개', () {
    final runs = [
      r(DateTime(2026, 12, 31, 23, 59), 1000),
      r(DateTime(2027), 9000),
      r(DateTime(2026, 1, 1), 2000),
    ];
    final s = statsFor(runs, StatsPeriod.year, anchor);
    expect(s.bars.length, 12);
    expect(s.count, 2);
    expect(s.bars[11].distanceM, 1000);
    expect(s.bars[0].distanceM, 2000);
  });

  test('전체: 첫 러닝 해부터 올해까지 연도별 막대', () {
    final runs = [r(DateTime(2024, 5, 1), 1000), r(DateTime(2026, 1, 1), 2000)];
    final s = statsFor(runs, StatsPeriod.all, anchor);
    expect(s.bars.map((b) => b.label), ['2024', '2025', '2026']);
    expect(s.bars[1].distanceM, 0);
    expect(s.count, 2);
    expect(s.distanceM, 3000);
  });

  test('빈 기간은 0 이고 평균 페이스가 없다', () {
    final s = statsFor([], StatsPeriod.week, anchor);
    expect(s.distanceM, 0);
    expect(s.count, 0);
    expect(s.movingTime, Duration.zero);
    expect(s.avgPaceSecPerKm, isNull);
    expect(s.bars.every((b) => b.distanceM == 0), isTrue);
    final all = statsFor([], StatsPeriod.all, anchor);
    expect(all.bars.length, 1);
    expect(all.bars.single.label, '2026');
  });

  test('평균 페이스는 시간 ÷ 거리', () {
    final runs = [
      r(DateTime(2026, 10, 13), 2000, sec: 600),
      r(DateTime(2026, 10, 14), 3000, sec: 1500),
    ];
    final s = statsFor(runs, StatsPeriod.week, anchor);
    expect(s.movingTime, const Duration(seconds: 2100));
    expect(s.avgPaceSecPerKm, closeTo(420, 1e-9));
  });
}
