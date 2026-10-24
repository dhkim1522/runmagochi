import 'geo.dart';
import 'run_summary.dart';

/// 완료한 러닝을 GPX 1.1 문자열로 만든다 (F30, 결정 0037). Strava 등 다른 앱이 읽는다.
///
/// 저장된 경로에는 점마다 시각이 없어서 1km 구간 기록으로 시각을 나눈다. 구간 안에서는
/// 같은 페이스로 본다. 일시정지한 시간은 들어가지 않는다(움직인 시간 기준).
String buildGpx({
  required String name,
  required DateTime startedAt,
  required List<(double, double)> route,
  required List<Split> splits,
}) {
  final times = gpxPointTimes(
    startedAt: startedAt,
    route: route,
    splits: splits,
  );
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="runmagochi" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln('  <metadata><time>${_iso(startedAt)}</time></metadata>')
    ..writeln('  <trk>')
    ..writeln('    <name>${_escape(name)}</name>')
    ..writeln('    <type>running</type>')
    ..writeln('    <trkseg>');
  for (var i = 0; i < route.length; i++) {
    final (lat, lng) = route[i];
    b
      ..writeln(
        '      <trkpt lat="${lat.toStringAsFixed(6)}" '
        'lon="${lng.toStringAsFixed(6)}">',
      )
      ..writeln('        <time>${_iso(times[i])}</time>')
      ..writeln('      </trkpt>');
  }
  b
    ..writeln('    </trkseg>')
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}

/// 경로 점마다 시각. 점까지의 누적 거리를 구간(1km)별 시간으로 바꾼다.
/// 저장된 경로는 단순화돼 구간 거리 합과 조금 다르므로, 경로 끝이 구간 합에 닿게
/// 거리를 비례로 맞춘다. 구간이 없으면 모두 시작 시각.
List<DateTime> gpxPointTimes({
  required DateTime startedAt,
  required List<(double, double)> route,
  required List<Split> splits,
}) {
  final start = startedAt.toUtc();
  final cumulative = <double>[];
  var distance = 0.0;
  for (var i = 0; i < route.length; i++) {
    if (i > 0) {
      final (a1, b1) = route[i - 1];
      final (a2, b2) = route[i];
      distance += haversineMeters(a1, b1, a2, b2);
    }
    cumulative.add(distance);
  }
  final splitTotal = splits.fold(0.0, (sum, s) => sum + s.distanceM);
  final scale = distance > 0 && splitTotal > 0 ? splitTotal / distance : 1.0;
  return [for (final d in cumulative) start.add(_elapsedAt(d * scale, splits))];
}

Duration _elapsedAt(double distanceM, List<Split> splits) {
  var covered = 0.0;
  var elapsedUs = 0;
  for (final s in splits) {
    if (s.distanceM <= 0) continue;
    final us = s.duration.inMicroseconds;
    if (distanceM <= covered + s.distanceM) {
      return Duration(
        microseconds:
            elapsedUs + (us * (distanceM - covered) / s.distanceM).round(),
      );
    }
    covered += s.distanceM;
    elapsedUs += us;
  }
  final last = splits.lastWhere(
    (s) => s.distanceM > 0,
    orElse: () => const Split(index: 0, distanceM: 0, duration: Duration.zero),
  );
  if (last.distanceM <= 0) return Duration(microseconds: elapsedUs);
  final extra = distanceM - covered;
  return Duration(
    microseconds:
        elapsedUs +
        (last.duration.inMicroseconds * extra / last.distanceM).round(),
  );
}

/// `runmagochi-YYYYMMDD-HHMM.gpx` (기기 현지 시각).
String gpxFileName(DateTime startedAt) {
  final d = startedAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'runmagochi-${d.year}${two(d.month)}${two(d.day)}'
      '-${two(d.hour)}${two(d.minute)}.gpx';
}

String _iso(DateTime t) {
  final u = t.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)}'
      'T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
