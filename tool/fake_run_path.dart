import 'dart:math' as math;

const double _metersPerDegreeLat = 111320;

/// 북동 방향 직선 경로를 만든다. 1초에 한 점이며 시작점을 포함해 seconds + 1개다.
/// [burstAt] 초부터 [burstFor] 초 동안은 초속 [burstSpeedMps] 로 간다(탈것 흉내).
List<(double, double)> buildPath({
  required int seconds,
  required double speedMps,
  required double lat,
  required double lng,
  int? burstAt,
  int burstFor = 0,
  double? burstSpeedMps,
}) {
  final perMeterLat = 1 / _metersPerDegreeLat / math.sqrt2;
  final perMeterLng =
      1 / (_metersPerDegreeLat * math.cos(lat * math.pi / 180)) / math.sqrt2;
  final path = [(lat, lng)];
  var meters = 0.0;
  for (var i = 1; i <= seconds; i++) {
    final burst =
        burstAt != null &&
        burstSpeedMps != null &&
        i > burstAt &&
        i <= burstAt + burstFor;
    meters += burst ? burstSpeedMps : speedMps;
    path.add((lat + perMeterLat * meters, lng + perMeterLng * meters));
  }
  return path;
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
