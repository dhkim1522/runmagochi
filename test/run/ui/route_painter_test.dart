import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/domain/route_pace.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
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

  group('경로 페이스 색', () {
    test('RoutePaceColors 는 단계마다 토큰 색을 쓴다(라이트·다크)', () {
      for (final c in [AppColors.light, AppColors.dark]) {
        final p = RoutePaceColors.of(c);
        expect(p.of(RoutePace.slow), c.paceSlow);
        expect(p.of(RoutePace.mid), c.paceMid);
        expect(p.of(RoutePace.fast), c.paceFast);
        expect(p.of(RoutePace.fastMove), c.inkMuted);
        expect(p.of(RoutePace.single), c.primaryDeep);
        expect(RoutePaceColors.of(c), p);
      }
    });

    // 북쪽으로 곧게 50~2,450m, 100m 간격. 1km 구간 3개: 빠름·보통·느림.
    double northOf(double m) => 37.5 + m / 6371000 * 180 / math.pi;
    final route = [
      for (var i = 0; i < 25; i++) (northOf(i * 100.0 + 50), 127.0),
    ];
    const splits = [
      Split(index: 1, distanceM: 1000, duration: Duration(seconds: 300)),
      Split(index: 2, distanceM: 1000, duration: Duration(seconds: 360)),
      Split(index: 3, distanceM: 400, duration: Duration(seconds: 168)),
    ];

    Future<Color Function(int x, int y)> paint(
      WidgetTester tester,
      RoutePainter painter,
    ) async {
      final recorder = PictureRecorder();
      painter.paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      final bytes = (await tester.runAsync(() async {
        final image = await picture.toImage(300, 200);
        return image.toByteData();
      }))!;
      // rawRgba 는 알파가 곱해진 값이라 되돌린다.
      return (x, y) {
        final o = (y * 300 + x) * 4;
        final a = bytes.getUint8(o + 3);
        int ch(int i) => a == 0
            ? 0
            : (bytes.getUint8(o + i) * 255 / a).round().clamp(0, 255);
        return Color.fromARGB(a, ch(0), ch(1), ch(2));
      };
    }

    RoutePainter painterFor(List<Split> splits, AppColors c) => RoutePainter(
      route,
      segments: routePaceSegments(route, splits),
      colors: RoutePaceColors.of(c),
      startColor: c.primary,
      startEdge: c.primaryEdge,
      endColor: c.ink,
      endRing: c.surface,
    );

    // 세로 경로: 시작(50m) y=184, 끝(2,450m) y=16. 구간 가운데 y.
    int yAt(double m) => (184 - (m - 50) / 2400 * 168).round();

    testWidgets('구간마다 페이스 색으로 선을 그린다', (tester) async {
      final c = AppColors.light;
      final pixel = await paint(tester, painterFor(splits, c));
      expect(pixel(150, yAt(550)), c.paceFast);
      expect(pixel(150, yAt(1550)), c.paceMid);
      expect(pixel(150, yAt(2150)), c.paceSlow);
      // 선 밖은 칠하지 않는다.
      expect(pixel(100, yAt(1550)).a, 0.0);
    });

    testWidgets('구간 경계 바로 앞뒤도 칠해져 선이 끊기지 않는다', (tester) async {
      final c = AppColors.light;
      final pixel = await paint(tester, painterFor(splits, c));
      for (var y = yAt(2400); y <= yAt(100); y++) {
        expect(pixel(150, y).a, 1.0, reason: 'y=$y');
      }
    });

    testWidgets('구간이 1개 이하면 primary-deep 한 색(다크 포함)', (tester) async {
      for (final c in [AppColors.light, AppColors.dark]) {
        final pixel = await paint(tester, painterFor(const [], c));
        for (final m in [550.0, 1550.0, 2150.0]) {
          expect(pixel(150, yAt(m)), c.primaryDeep);
        }
      }
    });

    testWidgets('시작 점은 연두 + 경계선, 끝 점은 진한 점 + 바깥 고리', (tester) async {
      final c = AppColors.light;
      final pixel = await paint(tester, painterFor(splits, c));
      // 경계선·고리는 가장자리가 부드럽게 칠해져 알파를 빼고 색만 본다.
      Matcher near(Color want) => predicate<Color>(
        (got) =>
            got.a > 0.5 &&
            (got.r - want.r).abs() < 0.02 &&
            (got.g - want.g).abs() < 0.02 &&
            (got.b - want.b).abs() < 0.02,
        '$want 에 가까운 색',
      );
      expect(pixel(150, 184), c.primary);
      expect(pixel(150 + 8, 184), near(c.primaryEdge));
      expect(pixel(150, 16), c.ink);
      expect(pixel(150 + 9, 16), near(c.surface));
    });
  });
}
