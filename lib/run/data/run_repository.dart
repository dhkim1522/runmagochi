import '../domain/location_sample.dart';
import '../domain/run_summary.dart';

class RunListItem {
  const RunListItem({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
}

class RunDetail {
  const RunDetail({
    required this.run,
    required this.calories,
    required this.route,
    required this.splits,
  });

  final RunListItem run;
  final double calories;
  final List<(double, double)> route;
  final List<Split> splits;
}

class ActiveRun {
  const ActiveRun({
    required this.id,
    required this.startedAt,
    required this.segments,
    required this.movingTime,
  });

  final String id;
  final DateTime startedAt;
  final List<List<LocationSample>> segments;
  final Duration movingTime;
}

abstract interface class RunRepository {
  Future<String> createActiveRun(DateTime startedAt);

  /// 점을 구간 번호와 함께 저장하고 진행 중 러닝의 움직인 시간을 [movingTime] 으로 갱신한다.
  /// [points] 가 비어 있어도 움직인 시간은 갱신한다.
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  });

  Future<ActiveRun?> findActiveRun();
  Future<void> completeRun(String runId, RunSummary summary);

  /// 완료된 러닝만, 최신순.
  Future<List<RunListItem>> listRuns();
  Future<RunDetail?> getRun(String id);

  /// 완료된 러닝의 `now` 가 속한 주(현지 월요일 0시 시작) 거리 합계와 횟수.
  Future<(double distanceM, int count)> weeklyTotal(DateTime now);
}
