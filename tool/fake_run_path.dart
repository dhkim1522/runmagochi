import 'dart:math' as math;

const double _metersPerDegreeLat = 111320;

/// 북동 방향 직선 경로를 만든다. 1초에 한 점이며 시작점을 포함해 seconds + 1개다.
List<(double, double)> buildPath({
  required int seconds,
  required double speedMps,
  required double lat,
  required double lng,
}) {
  final stepMeters = speedMps / math.sqrt2;
  final dLat = stepMeters / _metersPerDegreeLat;
  final dLng =
      stepMeters / (_metersPerDegreeLat * math.cos(lat * math.pi / 180));
  return [for (var i = 0; i <= seconds; i++) (lat + dLat * i, lng + dLng * i)];
}

/// [path] 의 [stopAt] 번째 점(초) 뒤에 같은 좌표를 [stopFor] 개 더 넣는다.
/// 1초에 한 점이므로 [stopFor] 초 동안 멈췄다가 경로를 이어 간다.
List<(double, double)> withStop(
  List<(double, double)> path, {
  required int stopAt,
  required int stopFor,
}) {
  final at = stopAt.clamp(0, path.length - 1);
  return [
    ...path.take(at + 1),
    for (var i = 0; i < stopFor; i++) path[at],
    ...path.skip(at + 1),
  ];
}
