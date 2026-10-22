import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/route_pace.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

const _lat0 = 37.5;

/// 북쪽으로 [meters] 떨어진 점의 위도.
double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

/// 북쪽으로 [stepM] 마다 [count] 개의 점. 점이 1km 경계에 딱 걸리지 않게 반 칸 띄워
/// 시작한다(누적 거리는 50, 150, …, 950, 1,050m 마다 경계를 넘는다).
List<(double, double)> _line(int count, {double stepM = 100}) => [
  for (var i = 0; i < count; i++) (_northOf(i * stepM + stepM / 2), 127.0),
];

Split _s(int i, int sec, [double m = 1000]) => Split(
  index: i,
  distanceM: m,
  duration: Duration(seconds: sec),
);

List<RoutePace> _paces(List<RouteSegment> segs) => [
  for (final s in segs) s.pace,
];

/// 앞 구간 끝점과 다음 구간 첫 점이 같아 선이 끊기지 않는다.
void _expectContinuous(List<RouteSegment> segs) {
  for (var i = 0; i + 1 < segs.length; i++) {
    expect(segs[i].points.last, segs[i + 1].points.first, reason: '경계 $i');
  }
}

void main() {
  test('점이 2개 미만이면 구간이 없다', () {
    expect(routePaceSegments(const [], [_s(1, 360)]), isEmpty);
    expect(routePaceSegments(_line(1), [_s(1, 360)]), isEmpty);
  });

  test('구간 0개: 경로 전체가 한 색 한 덩어리', () {
    final pts = _line(5);
    final segs = routePaceSegments(pts, const []);
    expect(segs, hasLength(1));
    expect(segs.single.pace, RoutePace.single);
    expect(segs.single.points, pts);
  });

  test('구간 1개: 경로 전체가 한 색 한 덩어리', () {
    final pts = _line(12);
    final segs = routePaceSegments(pts, [_s(1, 360)]);
    expect(segs, hasLength(1));
    expect(segs.single.pace, RoutePace.single);
    expect(segs.single.points, pts);
  });

  test('구간 3개: 1km 마다 나누고 가장 빠른·느린 구간 사이를 3단으로 칠한다', () {
    // 50~2,450m, 100m 간격 25점.
    final pts = _line(25);
    final segs = routePaceSegments(pts, [
      _s(1, 300),
      _s(2, 360),
      _s(3, 168, 400),
    ]);
    expect(segs, hasLength(3));
    // 300 이 가장 빠르고 420(168초/400m) 이 가장 느리다. 360 은 가운데.
    expect(_paces(segs), [RoutePace.fast, RoutePace.mid, RoutePace.slow]);
    // 50~1,050m, 1,050~2,050m, 2,050~2,450m(경계를 넘는 선은 앞 구간에 붙는다).
    expect(segs[0].points, pts.sublist(0, 11));
    expect(segs[1].points, pts.sublist(10, 21));
    expect(segs[2].points, pts.sublist(20));
    _expectContinuous(segs);
  });

  test('3단 경계: 범위의 1/3 이하는 빠름, 2/3 이상은 느림', () {
    final pts = _line(45);
    // 300~420 범위: 330(0.25) 빠름, 360(0.5) 보통, 390(0.75) 느림.
    final segs = routePaceSegments(pts, [
      _s(1, 300),
      _s(2, 330),
      _s(3, 360),
      _s(4, 390),
      _s(5, 420),
    ]);
    expect(_paces(segs), [
      RoutePace.fast,
      RoutePace.fast,
      RoutePace.mid,
      RoutePace.slow,
      RoutePace.slow,
    ]);
  });

  test('모든 구간 페이스가 같으면(1초 미만 차이) 한 색', () {
    final pts = _line(25);
    final segs = routePaceSegments(pts, [
      _s(1, 360),
      const Split(
        index: 2,
        distanceM: 1000,
        duration: Duration(milliseconds: 360500),
      ),
      _s(3, 144, 400),
    ]);
    expect(segs, hasLength(3));
    expect(_paces(segs), everyElement(RoutePace.single));
    _expectContinuous(segs);
  });

  test('빠른 이동 구간은 fastMove 이고 색 범위에서 빠진다', () {
    final pts = _line(25);
    final segs = routePaceSegments(pts, [
      _s(1, 360),
      _s(2, 100), // 150초/km 미만: 빠른 이동
      _s(3, 168, 400),
    ]);
    expect(_paces(segs), [RoutePace.fast, RoutePace.fastMove, RoutePace.slow]);
    _expectContinuous(segs);
  });

  test('빠른 이동을 빼고 남은 구간이 1개면 그 구간은 한 색', () {
    final pts = _line(15);
    final segs = routePaceSegments(pts, [_s(1, 360), _s(2, 100, 500)]);
    // 1km 미만 마지막 구간은 빠른 이동 검사를 하지 않는다(경험치 규칙과 같다).
    // 200초/km 로 가장 빨라 빠름, 360 은 느림.
    expect(_paces(segs), [RoutePace.slow, RoutePace.fast]);
    final segs2 = routePaceSegments(_line(25), [
      _s(1, 360),
      _s(2, 100),
      _s(3, 144, 400),
    ]);
    expect(_paces(segs2), [
      RoutePace.single,
      RoutePace.fastMove,
      RoutePace.single,
    ]);
  });

  test('시간 0 구간(페이스를 알 수 없음)은 fastMove', () {
    final segs = routePaceSegments(_line(25), [
      _s(1, 360),
      _s(2, 0),
      _s(3, 168, 400),
    ]);
    expect(_paces(segs), [RoutePace.fast, RoutePace.fastMove, RoutePace.slow]);
  });

  test('경로가 구간 합보다 길면 남는 점은 마지막 구간에 붙는다', () {
    // 경로 3,000m, 구간은 2개뿐.
    final pts = _line(31);
    final segs = routePaceSegments(pts, [_s(1, 300), _s(2, 420)]);
    expect(segs, hasLength(2));
    expect(segs.last.points.last, pts.last);
    expect(segs.first.points.first, pts.first);
    _expectContinuous(segs);
  });

  test('점 사이가 1km 를 넘는 큰 간격이어도 끊기지 않는다', () {
    // 0, 500, 2,500, 2,600m: 두 번째 선이 1km 경계 두 개를 건너뛴다.
    final pts = [
      (_northOf(0), 127.0),
      (_northOf(500), 127.0),
      (_northOf(2500), 127.0),
      (_northOf(2600), 127.0),
    ];
    final segs = routePaceSegments(pts, [
      _s(1, 300),
      _s(2, 360),
      _s(3, 252, 600),
    ]);
    // 선은 시작점이 속한 구간에 붙는다: 0→500, 500→2,500 은 1구간, 2,500→2,600 은 3구간.
    expect(segs, hasLength(2));
    expect(segs[0].points, pts.sublist(0, 3));
    expect(segs[1].points, pts.sublist(2));
    expect(_paces(segs), [RoutePace.fast, RoutePace.slow]);
    _expectContinuous(segs);
  });
}
