import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/ui/route_painter.dart';

void main() {
  const size = Size(300, 200);

  test('projectRoute 결과가 모두 여백 안쪽에 있다', () {
    final pts = projectRoute(const [
      (37.5000, 127.0000),
      (37.5100, 127.0050),
      (37.5050, 127.0200),
      (37.5200, 127.0100),
    ], size);
    expect(pts, hasLength(4));
    for (final p in pts) {
      expect(p.dx, inInclusiveRange(16, 284));
      expect(p.dy, inInclusiveRange(16, 184));
    }
  });

  test('가로세로 비율을 유지하고 경도는 cos(평균 위도) 로 줄인다', () {
    // 위도 60도 부근: 경도 0.02도 = 위도 0.01도 와 같은 길이.
    final pts = projectRoute(const [(60.0, 10.0), (60.01, 10.02)], size);
    final dx = (pts[1].dx - pts[0].dx).abs();
    final dy = (pts[1].dy - pts[0].dy).abs();
    expect(dx / dy, closeTo(1, 0.01));
  });

  test('북쪽이 위쪽이다', () {
    final pts = projectRoute(const [(37.0, 127.0), (37.01, 127.0)], size);
    expect(pts[1].dy, lessThan(pts[0].dy));
  });

  test('점 1개 경로는 중앙 한 점', () {
    final pts = projectRoute(const [(37.5, 127.0)], size);
    expect(pts, [const Offset(150, 100)]);
  });

  test('빈 경로는 빈 목록', () {
    expect(projectRoute(const [], size), isEmpty);
  });

  void expectFinite(List<Offset> pts) {
    for (final p in pts) {
      expect(p.dx.isFinite, isTrue);
      expect(p.dy.isFinite, isTrue);
    }
  }

  test('같은 점이 여러 개면 모두 중앙', () {
    final pts = projectRoute(const [
      (37.5, 127.0),
      (37.5, 127.0),
      (37.5, 127.0),
    ], size);
    expectFinite(pts);
    expect(pts, everyElement(const Offset(150, 100)));
  });

  test('세로 경로는 가로 중앙에 놓이고 여백 안쪽이다', () {
    final pts = projectRoute(const [
      (37.5, 127.0),
      (37.505, 127.0),
      (37.51, 127.0),
    ], size);
    expectFinite(pts);
    for (final p in pts) {
      expect(p.dx, 150);
      expect(p.dy, inInclusiveRange(16, 184));
    }
    expect(pts.first.dy, closeTo(184, 1e-9));
    expect(pts.last.dy, closeTo(16, 1e-9));
  });

  test('가로 경로는 세로 중앙에 놓이고 여백 안쪽이다', () {
    final pts = projectRoute(const [
      (37.5, 127.0),
      (37.5, 127.005),
      (37.5, 127.01),
    ], size);
    expectFinite(pts);
    for (final p in pts) {
      expect(p.dy, 100);
      expect(p.dx, inInclusiveRange(16, 284));
    }
    expect(pts.first.dx, closeTo(16, 1e-9));
    expect(pts.last.dx, closeTo(284, 1e-9));
  });

  test('크기가 여백의 2배보다 작으면 모두 중앙 한 점', () {
    final pts = projectRoute(const [
      (37.5, 127.0),
      (37.51, 127.01),
    ], const Size(20, 10));
    expectFinite(pts);
    expect(pts, everyElement(const Offset(10, 5)));
  });
}
