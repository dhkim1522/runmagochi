import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
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

  group('excludedFastDistanceM', () {
    Split sp(int i, double m, int sec) => Split(
      index: i,
      distanceM: m,
      duration: Duration(seconds: sec),
    );

    test('빠른 1km 구간 거리만 합한다', () {
      final splits = [sp(1, 1000, 140), sp(2, 1000, 300), sp(3, 1000, 100)];
      expect(excludedFastDistanceM(splits), 2000);
    });
    test('정확히 150초/km 와 1km 미만 마지막 구간은 뺀 거리에 안 든다', () {
      expect(excludedFastDistanceM([sp(1, 1000, 150), sp(2, 500, 60)]), 0);
    });
    test('구간이 없으면 0', () => expect(excludedFastDistanceM([]), 0));
    test('distanceXp 와 같은 기준이다', () {
      final splits = [sp(1, 1000, 140), sp(2, 1000, 300)];
      expect(distanceXp(2000, splits), 10);
      expect(excludedFastDistanceM(splits), 1000);
    });
  });

  group('목표 달성', () {
    Split fast(int i) => Split(
      index: i,
      distanceM: 1000,
      duration: const Duration(seconds: 120),
    );

    test('보너스는 목표 km × 5', () {
      expect(goalBonusXp(const DistanceGoal(3000)), 15);
      expect(goalBonusXp(const DistanceGoal(10000)), 50);
    });

    test('거리가 목표 이상이면 달성', () {
      expect(
        goalAchieved(
          distanceM: 5000,
          splits: [],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isTrue,
      );
      expect(
        goalAchieved(
          distanceM: 4999,
          splits: [],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isTrue,
      );
      expect(
        goalAchieved(
          distanceM: 4995,
          splits: [],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isTrue,
      );
      expect(
        goalAchieved(
          distanceM: 4994,
          splits: [],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isFalse,
      );
    });

    test('빠른 구간 거리는 뺀다', () {
      expect(
        goalAchieved(
          distanceM: 5000,
          splits: [fast(1)],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isFalse,
      );
      expect(
        goalAchieved(
          distanceM: 6000,
          splits: [fast(1)],
          movingTime: Duration.zero,
          goal: const DistanceGoal(5000),
        ),
        isTrue,
      );
    });

    group('시간 목표', () {
      const thirty = TimeGoal(Duration(minutes: 30));
      bool achieved(Duration moving, {double distanceM = 0}) => goalAchieved(
        distanceM: distanceM,
        splits: [],
        movingTime: moving,
        goal: thirty,
      );

      test('29분 59초는 미달, 30분은 달성', () {
        expect(achieved(const Duration(minutes: 29, seconds: 59)), isFalse);
        expect(achieved(const Duration(minutes: 30)), isTrue);
        expect(achieved(const Duration(minutes: 45)), isTrue);
      });

      test('거리와 빠른 구간은 판정에 쓰지 않는다', () {
        expect(
          goalAchieved(
            distanceM: 100000,
            splits: [fast(1)],
            movingTime: const Duration(minutes: 10),
            goal: thirty,
          ),
          isFalse,
        );
        expect(
          goalAchieved(
            distanceM: 0,
            splits: [fast(1)],
            movingTime: const Duration(minutes: 30),
            goal: thirty,
          ),
          isTrue,
        );
      });

      test('보너스는 목표 분 ÷ 6 반올림 × 5, 코인도 같다', () {
        for (final (minutes, bonus) in [
          (15, 15),
          (20, 15),
          (30, 25),
          (45, 40),
          (60, 50),
          (180, 150),
        ]) {
          final goal = TimeGoal(Duration(minutes: minutes));
          expect(goalBonusXp(goal), bonus, reason: '$minutes분');
          expect(goalBonusCoins(goal), bonus, reason: '$minutes분 코인');
        }
      });
    });
  });
}
