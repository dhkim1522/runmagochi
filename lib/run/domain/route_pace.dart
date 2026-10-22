import 'dart:math' as math;

import '../../avatar/domain/growth_rules.dart' show isFastSplit;
import 'geo.dart';
import 'run_summary.dart';

/// 경로 한 덩어리의 페이스 색 단계.
/// - [slow]·[mid]·[fast]: 이 러닝의 가장 느린·빠른 구간 사이를 3등분한 단계
/// - [fastMove]: 경험치에서 빼는 빠른 이동 구간(또는 페이스를 알 수 없는 구간)
/// - [single]: 구간이 1개 이하이거나 모든 구간 페이스가 같아 한 색으로 칠할 때
enum RoutePace { slow, mid, fast, fastMove, single }

/// 같은 색으로 칠하는 경로 한 덩어리. 앞 덩어리의 끝점이 다음 덩어리의 첫 점이다.
class RouteSegment {
  const RouteSegment({required this.points, required this.pace});

  /// (위도, 경도) 점. 2개 이상.
  final List<(double, double)> points;
  final RoutePace pace;
}

/// 이보다 차이가 작으면(초/km) 모든 구간 페이스가 같다고 본다. 화면 표시 단위가 1초다.
const double _samePaceSecPerKm = 1;

/// 경로 [points] 를 누적 거리로 1km 구간([splits])에 나누고 구간마다 페이스 색 단계를 붙인다.
///
/// - 점 사이 선은 시작점이 속한 구간에 붙는다. 그래서 경계를 넘는 선은 앞 구간 끝에 있고,
///   다음 구간은 그 선의 끝점에서 시작해 선이 끊기지 않는다.
/// - 경로 거리가 구간 합보다 길면 남는 선은 마지막 구간에 붙는다(GPS 거리와 기록 거리 차이).
/// - 빠른 이동 구간([isFastSplit])과 시간 0 구간은 [RoutePace.fastMove] 이고 색 범위에서 뺀다.
/// - 나머지 구간이 1개 이하이거나 페이스가 모두 같으면 [RoutePace.single].
/// - 구간이 없으면 경로 전체가 [RoutePace.single] 한 덩어리. 점이 2개 미만이면 빈 목록.
List<RouteSegment> routePaceSegments(
  List<(double, double)> points,
  List<Split> splits,
) {
  if (points.length < 2) return const [];
  final paces = _splitPaces(splits);
  final segments = <RouteSegment>[];
  var current = <(double, double)>[points.first];
  var currentIndex = 0;
  var cumulative = 0.0;
  for (var i = 1; i < points.length; i++) {
    final index = splits.isEmpty
        ? 0
        : math.min((cumulative / 1000).floor(), splits.length - 1);
    if (index != currentIndex) {
      segments.add(_segment(current, paces, currentIndex));
      current = [points[i - 1]];
      currentIndex = index;
    }
    current.add(points[i]);
    final (lat1, lng1) = points[i - 1];
    final (lat2, lng2) = points[i];
    cumulative += haversineMeters(lat1, lng1, lat2, lng2);
  }
  segments.add(_segment(current, paces, currentIndex));
  return segments;
}

RouteSegment _segment(
  List<(double, double)> points,
  List<RoutePace> paces,
  int index,
) => RouteSegment(
  points: points,
  pace: paces.isEmpty ? RoutePace.single : paces[index],
);

bool _validPace(double p) => p.isFinite && p > 0;

/// 구간마다 색 단계.
List<RoutePace> _splitPaces(List<Split> splits) {
  bool excluded(Split s) => !_validPace(s.paceSecPerKm) || isFastSplit(s);
  final rated = [
    for (final s in splits)
      if (!excluded(s)) s.paceSecPerKm,
  ];
  final fastest = rated.isEmpty ? 0.0 : rated.reduce(math.min);
  final slowest = rated.isEmpty ? 0.0 : rated.reduce(math.max);
  final range = slowest - fastest;
  final oneColor = rated.length <= 1 || range < _samePaceSecPerKm;
  return [
    for (final s in splits)
      if (excluded(s))
        RoutePace.fastMove
      else if (oneColor)
        RoutePace.single
      else
        switch ((s.paceSecPerKm - fastest) / range) {
          <= 1 / 3 => RoutePace.fast,
          >= 2 / 3 => RoutePace.slow,
          _ => RoutePace.mid,
        },
  ];
}
