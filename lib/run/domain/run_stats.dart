import '../../core/week.dart';
import '../data/run_repository.dart';

enum StatsPeriod { week, month, year, all }

class StatsBar {
  const StatsBar({required this.label, required this.distanceM});
  final String label;
  final double distanceM;
}

class RunStats {
  const RunStats({
    required this.distanceM,
    required this.count,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    required this.bars,
    required this.start,
    required this.end,
  });

  final double distanceM;
  final int count;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
  final List<StatsBar> bars;

  /// 기간 시작(포함)과 끝(제외), 현지 시각.
  final DateTime start;
  final DateTime end;
}

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// [runs] 중 [anchor] 가 속한 기간의 통계. 전체는 [anchor] 해까지(첫 러닝 해부터).
RunStats statsFor(List<RunListItem> runs, StatsPeriod period, DateTime anchor) {
  final a = anchor.toLocal();
  final local = [for (final r in runs) (r, r.startedAt.toLocal())];
  late DateTime start;
  late DateTime end;
  late int binCount;
  late int Function(DateTime) binOf;
  late List<String> labels;
  switch (period) {
    case StatsPeriod.week:
      start = weekStartOf(a);
      end = DateTime(start.year, start.month, start.day + 7);
      binCount = 7;
      labels = _weekdayLabels;
      binOf = (t) => t.weekday - 1;
    case StatsPeriod.month:
      start = DateTime(a.year, a.month);
      end = DateTime(a.year, a.month + 1);
      binCount = DateTime(a.year, a.month + 1, 0).day;
      labels = [for (var d = 1; d <= binCount; d++) '$d'];
      binOf = (t) => t.day - 1;
    case StatsPeriod.year:
      start = DateTime(a.year);
      end = DateTime(a.year + 1);
      binCount = 12;
      labels = [for (var m = 1; m <= 12; m++) '$m'];
      binOf = (t) => t.month - 1;
    case StatsPeriod.all:
      end = DateTime(a.year + 1);
      var first = a.year;
      for (final (_, t) in local) {
        if (t.year < first) first = t.year;
      }
      start = DateTime(first);
      binCount = a.year - first + 1;
      labels = [for (var y = first; y <= a.year; y++) '$y'];
      binOf = (t) => t.year - first;
  }
  final dist = List<double>.filled(binCount, 0);
  var total = 0.0;
  var count = 0;
  var time = Duration.zero;
  for (final (r, t) in local) {
    if (t.isBefore(start) || !t.isBefore(end)) continue;
    dist[binOf(t)] += r.distanceM;
    total += r.distanceM;
    count++;
    time += r.movingTime;
  }
  return RunStats(
    distanceM: total,
    count: count,
    movingTime: time,
    avgPaceSecPerKm: total > 0
        ? time.inMilliseconds / 1000 / (total / 1000)
        : null,
    bars: [
      for (var i = 0; i < binCount; i++)
        StatsBar(label: labels[i], distanceM: dist[i]),
    ],
    start: start,
    end: end,
  );
}
