import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/gpx.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

void main() {
  // 위도 0.001도 ≈ 111.2m. 북쪽으로 곧게 달린 경로.
  final route = [for (var i = 0; i <= 20; i++) (37.5 + i * 0.001, 127.0)];
  final start = DateTime.utc(2026, 10, 24, 6, 30);
  const splits = [
    Split(index: 0, distanceM: 1000, duration: Duration(minutes: 5)),
    Split(index: 1, distanceM: 1000, duration: Duration(minutes: 6)),
    Split(index: 2, distanceM: 224, duration: Duration(seconds: 90)),
  ];

  String gpx() => buildGpx(
    name: '토요일 아침 러닝',
    startedAt: start,
    route: route,
    splits: splits,
  );

  test('GPX 1.1 머리와 이름, 경로 점마다 trkpt 가 있다', () {
    final s = gpx();
    expect(s, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(s, contains('<gpx version="1.1" creator="runmagochi"'));
    expect(s, contains('xmlns="http://www.topografix.com/GPX/1/1"'));
    expect(s, contains('<name>토요일 아침 러닝</name>'));
    expect(s, contains('<type>running</type>'));
    expect('<trkpt '.allMatches(s).length, route.length);
    expect(s, contains('<trkpt lat="37.500000" lon="127.000000">'));
  });

  test('첫 점은 시작 시각, 마지막 점은 시작 + 구간 시간 합(UTC)', () {
    final s = gpx();
    final times = RegExp(
      r'<time>([^<]+)</time>',
    ).allMatches(s).map((m) => m.group(1)!).toList();
    // 첫 time 은 metadata, 그다음부터 점.
    expect(times.first, '2026-10-24T06:30:00Z');
    expect(times[1], '2026-10-24T06:30:00Z');
    expect(times.last, '2026-10-24T06:42:30Z');
  });

  test('구간 페이스로 시각을 나눈다: 1km 지점은 5분 뒤', () {
    final t = gpxPointTimes(startedAt: start, route: route, splits: splits);
    // 9번째 점 ≈ 1000.8m.
    expect(t[9].difference(start).inSeconds, closeTo(300, 2));
    // 시각은 줄지 않는다.
    for (var i = 1; i < t.length; i++) {
      expect(t[i].isBefore(t[i - 1]), isFalse);
    }
  });

  test('이름의 XML 특수문자를 바꾼다', () {
    final s = buildGpx(
      name: 'A & B <러닝>',
      startedAt: start,
      route: route,
      splits: splits,
    );
    expect(s, contains('<name>A &amp; B &lt;러닝&gt;</name>'));
  });

  test('구간이 없으면 모든 점이 시작 시각이다', () {
    final t = gpxPointTimes(startedAt: start, route: route, splits: const []);
    expect(t.toSet(), {start});
  });

  test('파일 이름은 runmagochi-YYYYMMDD-HHMM.gpx (현지 시각)', () {
    expect(
      gpxFileName(DateTime(2026, 10, 24, 6, 5)),
      'runmagochi-20261024-0605.gpx',
    );
  });
}
