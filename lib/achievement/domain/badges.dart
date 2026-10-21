import '../../avatar/domain/growth_rules.dart';
import '../../run/data/run_repository.dart';

/// 배지 한 종류. 보상은 코인만이다.
class BadgeDef {
  const BadgeDef(this.id, this.name, this.condition, this.coins);

  final String id;
  final String name;

  /// 화면에 보일 조건 문구.
  final String condition;
  final int coins;
}

/// 배지 목록(초안). 받는 순서는 이 목록 순서다.
const badgeCatalog = <BadgeDef>[
  BadgeDef('first_run', '첫 러닝', '러닝 1회', 50),
  BadgeDef('first_goal', '첫 목표 달성', '목표 달성 1회', 50),
  BadgeDef('dist_5k', '첫 5km', '한 번에 5km', 100),
  BadgeDef('dist_10k', '첫 10km', '한 번에 10km', 150),
  BadgeDef('dist_half', '하프 완주', '한 번에 21.1km', 300),
  BadgeDef('total_50', '누적 50km', '누적 50km', 100),
  BadgeDef('total_100', '누적 100km', '누적 100km', 200),
  BadgeDef('total_300', '누적 300km', '누적 300km', 300),
  BadgeDef('goals_10', '목표 달성 10번', '목표 달성 10회', 100),
  BadgeDef('goals_30', '목표 달성 30번', '목표 달성 30회', 200),
  BadgeDef('streak_3', '3일 연속', '서로 다른 3일 연속 러닝', 50),
  BadgeDef('dawn', '새벽 러너', '오전 6시 전에 시작', 50),
];

/// 미획득 배지 하나의 진행 상황. [current]/[target] 은 배지마다 단위가 다르다
/// (횟수, 미터, 일수).
class BadgeProgress {
  const BadgeProgress({
    required this.badge,
    required this.current,
    required this.target,
  });

  final BadgeDef badge;
  final double current;
  final double target;

  /// 0~1 진행률.
  double get ratio => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

class _Stats {
  int runs = 0;
  int goals = 0;
  double bestSingleM = 0;
  double totalM = 0;
  int longestStreak = 0;
  bool dawn = false;
}

/// 경험치 거리(빠른 구간 제외)를 표시 단위(10m)로 반올림한 값. 목표 판정과 같은 규칙이다.
double _countedM(RunDetail d) {
  final counted = d.run.distanceM - excludedFastDistanceM(d.splits);
  return counted <= 0 ? 0 : (counted / 10).round() * 10.0;
}

_Stats _statsOf(List<RunDetail> runs) {
  final s = _Stats();
  final days = <DateTime>{};
  for (final d in runs) {
    s.runs++;
    final goal = d.run.goal;
    if (goal != null &&
        goalAchieved(
          distanceM: d.run.distanceM,
          splits: d.splits,
          movingTime: d.run.movingTime,
          goal: goal,
        )) {
      s.goals++;
    }
    final m = _countedM(d);
    if (m > s.bestSingleM) s.bestSingleM = m;
    s.totalM += m;
    final local = d.run.startedAt.toLocal();
    if (local.hour < 6) s.dawn = true;
    days.add(DateTime.utc(local.year, local.month, local.day));
  }
  final sorted = days.toList()..sort();
  var streak = 0;
  for (var i = 0; i < sorted.length; i++) {
    streak = i > 0 && sorted[i].difference(sorted[i - 1]).inDays == 1
        ? streak + 1
        : 1;
    if (streak > s.longestStreak) s.longestStreak = streak;
  }
  return s;
}

/// 배지별 (현재값, 목표값).
(double, double) _measure(String id, _Stats s) => switch (id) {
  'first_run' => (s.runs.toDouble(), 1),
  'first_goal' => (s.goals.toDouble(), 1),
  'dist_5k' => (s.bestSingleM, 5000),
  'dist_10k' => (s.bestSingleM, 10000),
  'dist_half' => (s.bestSingleM, 21100),
  'total_50' => (s.totalM, 50000),
  'total_100' => (s.totalM, 100000),
  'total_300' => (s.totalM, 300000),
  'goals_10' => (s.goals.toDouble(), 10),
  'goals_30' => (s.goals.toDouble(), 30),
  'streak_3' => (s.longestStreak.toDouble(), 3),
  'dawn' => (s.dawn ? 1.0 : 0.0, 1),
  _ => (0, 1),
};

/// 지운 러닝을 뺀 [runs] 로 새로 받을 배지 id 를 [badgeCatalog] 순서로 돌려준다.
/// [already] 에 있는 배지는 뺀다.
///
/// - 거리: 빠른 구간을 뺀 경험치 거리를 목표 판정과 같이 10m 로 반올림해 잰다.
///   4,995m 는 5.00km 로 보이므로 5km 로 센다.
/// - 목표 달성: 러닝에 저장된 목표(거리·시간)를 [goalAchieved] 로 판정한다. 목표 없는 러닝은 세지 않는다.
/// - 3일 연속: 현지 달력 날짜가 서로 다르고 하루씩 이어지는 3일.
/// - 새벽 러너: 현지 시각 06:00 전에 시작.
List<String> earnedBadgeIds(
  List<RunDetail> runs, {
  required Set<String> already,
}) {
  final stats = _statsOf(runs);
  return [
    for (final b in badgeCatalog)
      if (!already.contains(b.id) && _isEarned(b.id, stats)) b.id,
  ];
}

bool _isEarned(String id, _Stats s) {
  final (current, target) = _measure(id, s);
  return current >= target;
}

/// 조건을 아직 못 채운 배지 중 진행률이 가장 높은 것. 같으면 목록 앞쪽. 모두 받았으면 null.
BadgeProgress? nextBadge(List<RunDetail> runs, {required Set<String> already}) {
  final stats = _statsOf(runs);
  BadgeProgress? best;
  for (final b in badgeCatalog) {
    if (already.contains(b.id)) continue;
    final (current, target) = _measure(b.id, stats);
    if (current >= target) continue; // 받을 차례인 배지는 다음 동기화에서 준다.
    final p = BadgeProgress(badge: b, current: current, target: target);
    if (best == null || p.ratio > best.ratio) best = p;
  }
  return best;
}
