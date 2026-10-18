import 'location_sample.dart';

class Split {
  const Split({
    required this.index,
    required this.distanceM,
    required this.duration,
  });

  final int index;
  final double distanceM;
  final Duration duration;

  double get paceSecPerKm =>
      duration.inMicroseconds /
      Duration.microsecondsPerSecond /
      (distanceM / 1000);
}

class RunSummary {
  const RunSummary({
    required this.startedAt,
    required this.endedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    required this.calories,
    required this.name,
    required this.splits,
    required this.points,
    this._segments,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
  final double calories;
  final String name;
  final List<Split> splits;
  final List<LocationSample> points;

  final List<List<LocationSample>>? _segments;

  /// 일시정지·재개로 나뉜 기록 구간별 점. 끝부분 잘라내기에 쓴다.
  /// 구간 정보 없이 만든 요약은 [points] 전체를 한 구간으로 본다.
  List<List<LocationSample>> get segments =>
      _segments ?? (points.isEmpty ? const [] : [points]);
}

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 시작 시각의 요일·시간대로 짓는 이름. 예: "금요일 저녁 러닝".
/// 요일·시간대는 기기 현지 시각 기준이다. UTC 시각은 현지 시각으로 바꿔 쓴다.
String autoRunName(DateTime startedAt) {
  final local = startedAt.toLocal();
  final hour = local.hour;
  final period = switch (hour) {
    < 5 => '새벽',
    < 11 => '아침',
    < 14 => '점심',
    < 18 => '오후',
    < 22 => '저녁',
    _ => '밤',
  };
  return '${_weekdayNames[local.weekday - 1]}요일 $period 러닝';
}

/// 체중(kg) × 거리(km) × 1.036.
/// 체중을 모를 때 칼로리 계산에 쓰는 기본 체중(kg).
const double defaultWeightKg = 65;

double estimateCalories(
  double distanceM, {
  double weightKg = defaultWeightKg,
}) => weightKg * distanceM / 1000 * 1.036;
