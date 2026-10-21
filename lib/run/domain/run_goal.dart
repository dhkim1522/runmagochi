import '../../core/format.dart';

/// 러닝 시작 때 고른 오늘 목표. 거리 또는 시간 중 하나다.
sealed class RunGoal {
  const RunGoal();

  /// DB 열 두 개에서 목표를 만든다. 둘 다 null 이면 목표가 없는 예전 러닝이라 null.
  /// 거리 열이 있으면 거리 목표가 먼저다.
  static RunGoal? fromColumns(double? goalM, int? goalSec) {
    if (goalM != null) return DistanceGoal(goalM);
    if (goalSec != null) return TimeGoal(Duration(seconds: goalSec));
    return null;
  }

  /// "목표 …" 문구에 들어가는 값. 거리는 `5km`, 시간은 `30분`.
  String get label => switch (this) {
    DistanceGoal(:final meters) => '${formatTargetKm(meters)}km',
    TimeGoal(:final time) => '${time.inMinutes}분',
  };
}

/// 거리 목표. [meters] 는 미터.
final class DistanceGoal extends RunGoal {
  const DistanceGoal(this.meters);

  final double meters;

  @override
  bool operator ==(Object other) =>
      other is DistanceGoal && other.meters == meters;

  @override
  int get hashCode => Object.hash(DistanceGoal, meters);

  @override
  String toString() => 'DistanceGoal($meters)';
}

/// 시간 목표. [time] 은 움직인 시간 기준이다.
final class TimeGoal extends RunGoal {
  const TimeGoal(this.time);

  final Duration time;

  @override
  bool operator ==(Object other) => other is TimeGoal && other.time == time;

  @override
  int get hashCode => Object.hash(TimeGoal, time);

  @override
  String toString() => 'TimeGoal($time)';
}
