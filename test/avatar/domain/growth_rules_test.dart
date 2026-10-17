import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

void main() {
  test('5.02km 는 50', () => expect(distanceXp(5020, []), 50));
  test('1296m 는 13 (표시 1.30km)', () => expect(distanceXp(1296, []), 13));
  test('1294m 는 12 (표시 1.29km)', () => expect(distanceXp(1294, []), 12));
  test('94m 는 0, 95m 는 1 (표시 단위 10m 로 반올림)', () {
    expect(distanceXp(94, []), 0);
    expect(distanceXp(95, []), 1);
  });
  test('99m 는 1 (표시 0.10km)', () => expect(distanceXp(99, []), 1));
  test('44m 는 0', () => expect(distanceXp(44, []), 0));
  test('149초 구간은 빼고 150초 구간은 넣는다', () {
    final splits = [
      Split(index: 0, distanceM: 1000, duration: Duration(seconds: 149)),
      Split(index: 1, distanceM: 1000, duration: Duration(seconds: 150)),
    ];
    expect(distanceXp(2500, splits), 15);
  });
  test('모든 구간이 너무 빠르면 남은 거리만', () {
    final s = [
      Split(index: 0, distanceM: 1000, duration: Duration(seconds: 100)),
    ];
    expect(distanceXp(1000, s), 0);
  });
  test('1km 미만 마지막 구간은 검사하지 않는다', () {
    final s = [
      Split(index: 0, distanceM: 500, duration: Duration(seconds: 50)),
    ];
    expect(distanceXp(500, s), 5);
  });
  test('레벨 경계', () {
    expect(levelFor(0).level, 1);
    expect(levelFor(49).level, 1);
    expect(levelFor(50).level, 2);
    expect(levelFor(500).level, 5);
    expect(levelFor(9500).level, 20);
    expect(levelFor(120).xpIntoLevel, 70);
    expect(levelFor(120).xpForNext, 100);
  });
  test('단계 경계', () {
    expect([1, 4, 5, 9, 10, 19, 20, 99].map(stageForLevel), [
      1,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
    ]);
    expect(xpToNextStage(0), 500);
    expect(xpToNextStage(9500), isNull);
  });
  test('표정은 달력 날짜 차이', () {
    final now = DateTime(2026, 10, 20, 0, 10);
    expect(moodFor(null, now), AvatarMood.normal);
    expect(moodFor(DateTime(2026, 10, 18, 23, 59), now), AvatarMood.normal);
    expect(moodFor(DateTime(2026, 10, 17, 9), now), AvatarMood.sleepy);
    expect(moodFor(DateTime(2026, 10, 13, 9), now), AvatarMood.asleep);
  });
  test('동작', () {
    expect(
      actionFor(paused: true, currentPaceSecPerKm: 300),
      AvatarAction.idle,
    );
    expect(
      actionFor(paused: false, currentPaceSecPerKm: null),
      AvatarAction.walk,
    );
    expect(
      actionFor(paused: false, currentPaceSecPerKm: 541),
      AvatarAction.walk,
    );
    expect(
      actionFor(paused: false, currentPaceSecPerKm: 540),
      AvatarAction.run,
    );
  });
}
