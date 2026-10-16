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
