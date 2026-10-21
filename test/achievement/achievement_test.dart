import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/domain/badges.dart';
import 'package:runmagochi/achievement/domain/personal_records.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

/// 1km 구간 [n]개. 페이스는 [secs] 초/km 로 모두 같다.
List<Split> km(int n, {int secs = 360, int from = 0}) => [
  for (var i = 0; i < n; i++)
    Split(
      index: from + i,
      distanceM: 1000,
      duration: Duration(seconds: secs),
    ),
];

RunDetail run({
  DateTime? at,
  double distanceM = 3000,
  Duration? moving,
  RunGoal? goal,
  List<Split>? splits,
}) => RunDetail(
  run: RunListItem(
    id: 'r',
    name: 'n',
    startedAt: at ?? DateTime(2026, 1, 1, 12),
    distanceM: distanceM,
    movingTime: moving ?? Duration(seconds: (distanceM * 0.36).round()),
    avgPaceSecPerKm: 360,
    goal: goal,
  ),
  calories: 0,
  route: const [],
  splits: splits ?? km((distanceM / 1000).floor()),
);

List<String> earned(List<RunDetail> runs, [Set<String> already = const {}]) =>
    earnedBadgeIds(runs, already: already);

void main() {
  group('개인 기록', () {
    test('러닝이 없으면 모두 null', () {
      final r = recordsFor([]);
      expect(r.longestDistanceM, isNull);
      expect(r.longestTime, isNull);
      expect(r.bestKm, isNull);
      expect(r.bestFiveKm, isNull);
    });

    test('최장 거리·최장 시간', () {
      final r = recordsFor([
        run(distanceM: 3000, moving: const Duration(minutes: 20)),
        run(distanceM: 8000, moving: const Duration(minutes: 50)),
        run(distanceM: 5000, moving: const Duration(minutes: 70)),
      ]);
      expect(r.longestDistanceM, 8000);
      expect(r.longestTime, const Duration(minutes: 70));
    });

    test('최고 1km 는 빠른 구간과 1km 미만 구간을 뺀다', () {
      final r = recordsFor([
        run(
          splits: [
            ...km(1, secs: 100), // 100초/km: 빠른 구간
            const Split(
              index: 1,
              distanceM: 500,
              duration: Duration(seconds: 120),
            ), // 1km 미만
            ...km(1, secs: 330, from: 2),
            ...km(1, secs: 300, from: 3),
          ],
        ),
      ]);
      expect(r.bestKm, const Duration(seconds: 300));
    });

    test('최고 5km 는 연속한 5개 구간 합이 가장 짧은 값', () {
      final r = recordsFor([
        run(
          splits: [
            ...km(1, secs: 400),
            ...km(5, secs: 300, from: 1),
            ...km(1, secs: 400, from: 6),
          ],
        ),
      ]);
      expect(r.bestFiveKm, const Duration(seconds: 1500));
    });

    test('최고 5km 는 빠른 구간·끊긴 번호가 낀 창을 건너뛴다', () {
      final withFast = recordsFor([
        run(
          splits: [
            ...km(2, secs: 300),
            ...km(1, secs: 100, from: 2),
            ...km(2, secs: 300, from: 3),
          ],
        ),
      ]);
      expect(withFast.bestFiveKm, isNull);
      final gap = recordsFor([
        run(splits: [...km(2), ...km(3, from: 3)]),
      ]);
      expect(gap.bestFiveKm, isNull);
      final shortRun = recordsFor([run(splits: km(4))]);
      expect(shortRun.bestFiveKm, isNull);
    });

    test('최고 5km 는 러닝 사이 구간을 잇지 않는다', () {
      final r = recordsFor([run(splits: km(3)), run(splits: km(2))]);
      expect(r.bestFiveKm, isNull);
    });
  });

  group('배지', () {
    test('목록은 12개, 코인 50~300', () {
      expect(badgeCatalog.length, 12);
      expect(
        badgeCatalog.map((b) => b.coins).every((c) => c >= 50 && c <= 300),
        isTrue,
      );
      expect(badgeCatalog.map((b) => b.id).toSet().length, 12);
    });

    test('러닝이 없으면 없다, 1회면 first_run', () {
      expect(earned([]), isEmpty);
      expect(earned([run()]), ['first_run']);
    });

    test('한 번에 5km: 4.99km 는 아니고 5.00km 는 맞다 (4,995m 도 5km)', () {
      expect(
        earned([run(distanceM: 4990, splits: km(4))]),
        isNot(contains('dist_5k')),
      );
      expect(
        earned([run(distanceM: 4994, splits: km(4))]),
        isNot(contains('dist_5k')),
      );
      expect(
        earned([run(distanceM: 4995, splits: km(4))]),
        contains('dist_5k'),
      );
      expect(
        earned([run(distanceM: 5000, splits: km(5))]),
        contains('dist_5k'),
      );
    });

    test('한 번에 10km, 하프 21.1km', () {
      final ids = earned([run(distanceM: 21100, splits: km(21))]);
      expect(ids, containsAll(['dist_5k', 'dist_10k', 'dist_half']));
      expect(
        earned([run(distanceM: 21080, splits: km(21))]),
        isNot(contains('dist_half')),
      );
    });

    test('빠른 구간 거리는 거리 배지에서 뺀다', () {
      final r = run(
        distanceM: 5000,
        splits: [...km(4), ...km(1, secs: 100, from: 4)],
      );
      expect(earned([r]), isNot(contains('dist_5k')));
    });

    test('누적 50km 는 러닝을 합쳐 센다', () {
      final runs = [
        for (var i = 0; i < 5; i++) run(distanceM: 10000, splits: km(10)),
      ];
      expect(earned(runs), contains('total_50'));
      expect(earned(runs), isNot(contains('total_100')));
      final more = [
        for (var i = 0; i < 10; i++) run(distanceM: 10000, splits: km(10)),
      ];
      expect(earned(more), containsAll(['total_50', 'total_100']));
      expect(earned(more), isNot(contains('total_300')));
    });

    test('목표 달성: 거리·시간 목표, 못 채운 것과 목표 없는 것은 제외', () {
      final hit = run(distanceM: 3000, goal: const DistanceGoal(3000));
      final miss = run(distanceM: 2900, goal: const DistanceGoal(3000));
      final none = run(distanceM: 3000);
      expect(earned([miss, none]), isNot(contains('first_goal')));
      expect(earned([hit]), contains('first_goal'));
      final time = run(
        moving: const Duration(minutes: 30),
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(earned([time]), contains('first_goal'));
      final timeMiss = run(
        moving: const Duration(minutes: 29, seconds: 59),
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(earned([timeMiss]), isNot(contains('first_goal')));
    });

    test('빠른 구간을 빼면 거리 목표를 못 채운다', () {
      final r = run(
        distanceM: 3000,
        goal: const DistanceGoal(3000),
        splits: [...km(2), ...km(1, secs: 100, from: 2)],
      );
      expect(earned([r]), isNot(contains('first_goal')));
    });

    test('목표 달성 10번·30번', () {
      List<RunDetail> n(int c) => [
        for (var i = 0; i < c; i++) run(goal: const DistanceGoal(3000)),
      ];
      expect(earned(n(9)), isNot(contains('goals_10')));
      expect(earned(n(10)), contains('goals_10'));
      expect(earned(n(10)), isNot(contains('goals_30')));
      expect(earned(n(30)), containsAll(['goals_10', 'goals_30']));
    });

    test('새벽 러너: 05:59 는 맞고 06:00 은 아니다', () {
      expect(earned([run(at: DateTime(2026, 1, 1, 5, 59))]), contains('dawn'));
      expect(
        earned([run(at: DateTime(2026, 1, 1, 6, 0))]),
        isNot(contains('dawn')),
      );
    });

    test('3일 연속: 달이 바뀌어도 이어지고, 같은 날 여러 번이나 하루 건너뜀은 아니다', () {
      final across = [
        run(at: DateTime(2026, 1, 30, 20)),
        run(at: DateTime(2026, 1, 31, 7)),
        run(at: DateTime(2026, 2, 1, 23, 59)),
      ];
      expect(earned(across), contains('streak_3'));
      final sameDay = [
        run(at: DateTime(2026, 1, 1, 7)),
        run(at: DateTime(2026, 1, 1, 12)),
        run(at: DateTime(2026, 1, 2, 7)),
      ];
      expect(earned(sameDay), isNot(contains('streak_3')));
      final gap = [
        run(at: DateTime(2026, 1, 1)),
        run(at: DateTime(2026, 1, 2)),
        run(at: DateTime(2026, 1, 4)),
      ];
      expect(earned(gap), isNot(contains('streak_3')));
      final unordered = [
        run(at: DateTime(2026, 1, 3)),
        run(at: DateTime(2026, 1, 1)),
        run(at: DateTime(2026, 1, 2)),
      ];
      expect(earned(unordered), contains('streak_3'));
    });

    test('3일 연속: 자정 직전과 직후는 서로 다른 날', () {
      final runs = [
        run(at: DateTime(2026, 3, 1, 23, 59)),
        run(at: DateTime(2026, 3, 2, 0, 1)),
      ];
      expect(earned(runs), isNot(contains('streak_3')));
      expect(
        earned([...runs, run(at: DateTime(2026, 3, 3, 0, 1))]),
        contains('streak_3'),
      );
    });

    test('이미 받은 배지는 뺀다, 순서는 목록 순서', () {
      final runs = [
        run(
          at: DateTime(2026, 1, 1, 5),
          distanceM: 5000,
          splits: km(5),
          goal: const DistanceGoal(5000),
        ),
      ];
      expect(earned(runs), ['first_run', 'first_goal', 'dist_5k', 'dawn']);
      expect(earned(runs, {'first_run', 'dist_5k'}), ['first_goal', 'dawn']);
      expect(earned(runs, {for (final b in badgeCatalog) b.id}), isEmpty);
    });
  });

  group('다음 배지', () {
    test('러닝이 없으면 진행률 0 중 첫 배지', () {
      final p = nextBadge([], already: const {})!;
      expect(p.badge.id, 'first_run');
      expect(p.ratio, 0);
    });

    test('진행률이 가장 높은 미획득 배지', () {
      final runs = [run(distanceM: 4000, splits: km(4))];
      // first_run 받음(already), 4km/5km = 0.8 이 가장 높다.
      final p = nextBadge(runs, already: const {'first_run'})!;
      expect(p.badge.id, 'dist_5k');
      expect(p.ratio, closeTo(0.8, 1e-9));
    });

    test('모두 받았으면 null', () {
      expect(
        nextBadge([], already: {for (final b in badgeCatalog) b.id}),
        isNull,
      );
    });
  });
}
