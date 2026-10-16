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
}

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 시작 시각의 요일·시간대로 짓는 이름. 예: "금요일 저녁 러닝".
String autoRunName(DateTime startedAt) {
  final hour = startedAt.hour;
  final period = switch (hour) {
    < 5 => '새벽',
    < 11 => '아침',
    < 14 => '점심',
    < 18 => '오후',
    < 22 => '저녁',
    _ => '밤',
  };
  return '${_weekdayNames[startedAt.weekday - 1]}요일 $period 러닝';
}

/// 체중(kg) × 거리(km) × 1.036.
double estimateCalories(double distanceM, {double weightKg = 65}) =>
    weightKg * distanceM / 1000 * 1.036;
