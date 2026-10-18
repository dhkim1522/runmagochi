import 'location_sample.dart';
import 'run_engine.dart';
import 'run_summary.dart';

/// [original] 의 끝을 [newEnd] 로 앞당긴 요약을 만든다.
///
/// - [newEnd] 가 시작보다 앞이거나 원래 끝보다 뒤면 [ArgumentError].
/// - 시각이 [newEnd] 보다 뒤인 점을 버린다. 점이 없어진 구간은 사라진다.
/// - 남은 구간을 기록 엔진에 복원 모드로 다시 넣어 거리·구간·평균 페이스·
///   칼로리를 계산한다. 거리·구간 규칙은 엔진과 같다.
/// - 움직인 시간 = 원래 움직인 시간 − 잘려 나간 기록 시간. 구간의 기록
///   시간은 첫 점부터 마지막 점까지이고, 마지막 구간은 원래 끝 시각까지
///   이어진 것으로 본다. 잘린 기록 시간은 각 구간에서 [newEnd] 뒤에 걸친
///   길이의 합이다. 일시정지 중이던 사이 시간은 세지 않는다. 음수는 0 으로
///   막는다.
RunSummary trimRunEnd(
  RunSummary original,
  DateTime newEnd, {
  double weightKg = defaultWeightKg,
}) {
  if (newEnd.isBefore(original.startedAt)) {
    throw ArgumentError.value(newEnd, 'newEnd', '시작보다 앞일 수 없다.');
  }
  if (newEnd.isAfter(original.endedAt)) {
    throw ArgumentError.value(newEnd, 'newEnd', '원래 끝보다 뒤일 수 없다.');
  }

  final segments = original.segments;
  var cut = Duration.zero;
  final kept = <List<LocationSample>>[];
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment.isEmpty) continue;
    final first = segment.first.time;
    final isLast = i == segments.length - 1;
    final last = isLast && segment.last.time.isBefore(original.endedAt)
        ? original.endedAt
        : segment.last.time;
    if (last.isAfter(newEnd)) {
      cut += last.difference(first.isAfter(newEnd) ? first : newEnd);
    }
    final keptPoints = [
      for (final p in segment)
        if (!p.time.isAfter(newEnd)) p,
    ];
    if (keptPoints.isNotEmpty) kept.add(keptPoints);
  }

  var moving = original.movingTime - cut;
  if (moving.isNegative) moving = Duration.zero;

  final engine = RunEngine(
    clock: () => newEnd,
    startedAt: original.startedAt,
    restoredSegments: kept,
    restoredMovingTime: moving,
  );
  final trimmed = engine.end(weightKg: weightKg);
  return RunSummary(
    startedAt: original.startedAt,
    endedAt: newEnd,
    distanceM: trimmed.distanceM,
    movingTime: trimmed.movingTime,
    avgPaceSecPerKm: trimmed.avgPaceSecPerKm,
    calories: trimmed.calories,
    name: original.name,
    splits: trimmed.splits,
    points: trimmed.points,
    segments: trimmed.segments,
  );
}
