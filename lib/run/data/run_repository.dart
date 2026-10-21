import '../domain/location_sample.dart';
import '../domain/run_goal.dart';
import '../domain/run_summary.dart';

class RunListItem {
  const RunListItem({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    this.goal,
  });

  final String id;
  final String name;
  final DateTime startedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;

  /// 시작 때 고른 오늘 목표. 목표 없이 만든 예전 러닝은 null.
  final RunGoal? goal;
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
    this.goal,
  });

  final String id;
  final DateTime startedAt;
  final List<List<LocationSample>> segments;
  final Duration movingTime;

  /// 시작 때 고른 오늘 목표.
  final RunGoal? goal;
}

abstract interface class RunRepository {
  /// 진행 중 러닝을 만든다. [goal] 은 시작 때 고른 오늘 목표(거리 또는 시간).
  Future<String> createActiveRun(DateTime startedAt, {required RunGoal goal});

  /// 시작 시각이 가장 늦은 러닝(진행 중·완료·삭제 표시 모두)의 목표(종류 포함).
  /// 러닝이 없거나 그 러닝에 목표가 없으면 null.
  Future<RunGoal?> lastGoal();

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

  /// 완료·미삭제 러닝 전체의 상세를 경로(route) 없이 한 번에 읽는다(최신순).
  /// 통계·배지 판정용이라 경로 디코딩과 러닝별 조회를 피한다. `route` 는 비어 있다.
  Future<List<RunDetail>> listRunDetails();

  /// 완료된 러닝의 `now` 가 속한 주(현지 월요일 0시 시작) 거리 합계와 횟수.
  Future<(double distanceM, int count)> weeklyTotal(DateTime now);

  /// 완료된 러닝과 그 구간에 삭제 표시를 한다(한 트랜잭션). 목록·상세·합계에서 빠진다.
  /// 이미 지운 러닝이면 아무 일도 없다. 진행 중이거나 없는 러닝이면 [StateError].
  /// 받은 경험치는 그대로 둔다(결정 0018).
  Future<void> deleteRun(String id);

  /// 완료된 러닝의 끝 시각·거리·움직인 시간·평균 페이스·칼로리·경로·구간을
  /// [summary] 값으로 바꾼다(한 트랜잭션). 예전 구간에는 삭제 표시를 하고 새
  /// 구간을 넣는다. 시작 시각·이름은 그대로다. 끝부분 잘라내기에 쓴다.
  /// 지웠거나 진행 중이거나 없는 러닝이면 [StateError].
  /// 경험치는 따로 다시 계산한다(`GrowthService.runRevised`).
  Future<void> replaceCompletedRun(String runId, RunSummary summary);

  /// [ids] 가운데 저장소에 행이 있는 러닝 id(진행 중·완료·삭제 표시 모두).
  /// 성장 자가 복구가 저장소에 아예 없는 러닝의 경험치를 찾는 데 쓴다.
  Future<Set<String>> existingRunIds(Set<String> ids);

  /// 살아 있는 완료 러닝 id → 그 기록을 마지막으로 바꾼 시각(현지).
  /// 기록을 바꾼 뒤 경험치를 다시 매기지 못한 러닝을 찾는 데 쓴다.
  Future<Map<String, DateTime>> completedRunRevisions();
}
