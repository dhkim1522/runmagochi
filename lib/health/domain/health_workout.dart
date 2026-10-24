import '../../run/domain/run_summary.dart';

/// 건강 앱(Apple 건강·Health Connect)에서 읽은 운동 하나 (F15, 결정 0037).
class HealthWorkout {
  const HealthWorkout({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.energyKcal,
    required this.isRunning,
    required this.writtenByThisApp,
  });

  /// 건강 앱이 주는 운동 고유 id. 같은 운동을 한 번만 들이는 열쇠다.
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final double? distanceM;
  final double? energyKcal;

  /// 달리기 종류인가(걷기·자전거 등은 아니다).
  final bool isRunning;

  /// 이 앱이 건강 앱에 쓴 운동인가. 들이면 같은 러닝이 두 번 잡히므로 뺀다.
  final bool writtenByThisApp;
}

/// 러닝 기록에 `source` 로 남기는 값. 앱이 직접 기록한 러닝은 `app`.
const String appRunSource = 'app';
String healthSourceOf(String workoutId) => 'health:$workoutId';

/// `health:<id>` 의 id. 건강 앱에서 들인 기록이 아니면 null.
String? healthIdOf(String source) =>
    source.startsWith('health:') ? source.substring(7) : null;

/// 들일 운동만 골라 오래된 순서로 돌려준다: 달리기이고, 이 앱이 쓴 것이 아니고,
/// 거리가 [minSavedDistanceM] 이상이며, 이미 들인 것이 아니다.
List<HealthWorkout> importableWorkouts(
  Iterable<HealthWorkout> all, {
  required Set<String> alreadyImported,
}) {
  final out = [
    for (final w in all)
      if (w.isRunning &&
          !w.writtenByThisApp &&
          (w.distanceM ?? 0) >= minSavedDistanceM &&
          !alreadyImported.contains(w.id))
        w,
  ];
  out.sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return out;
}

/// 건강 앱 운동을 러닝 요약으로 바꾼다. 경로 점이 없어 경로는 비고, 1km 구간은 평균
/// 페이스로 고르게 나눈다(마지막 구간은 남은 거리). 이름은 시작 시각으로 짓는다.
RunSummary summaryOf(HealthWorkout w) {
  final distance = w.distanceM ?? 0;
  final moving = w.endedAt.difference(w.startedAt);
  final avgPace = distance > 0
      ? moving.inMicroseconds /
            Duration.microsecondsPerSecond /
            (distance / 1000)
      : null;
  final splits = <Split>[];
  var left = distance;
  for (var i = 0; left > 0.5; i++) {
    final d = left >= 1000 ? 1000.0 : left;
    splits.add(
      Split(
        index: i,
        distanceM: d,
        duration: Duration(
          microseconds: (moving.inMicroseconds * d / distance).round(),
        ),
      ),
    );
    left -= d;
  }
  return RunSummary(
    startedAt: w.startedAt,
    endedAt: w.endedAt,
    distanceM: distance,
    movingTime: moving,
    avgPaceSecPerKm: avgPace,
    calories: w.energyKcal ?? 0,
    name: autoRunName(w.startedAt),
    splits: splits,
    points: const [],
  );
}
