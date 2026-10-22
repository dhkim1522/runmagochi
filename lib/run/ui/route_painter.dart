import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../domain/route_pace.dart';

/// (위도, 경도) 경로를 [size] 안의 화면 좌표로 투영한다.
///
/// 등장방형 투영에 경도 × cos(평균 위도) 보정을 하고, 가로세로 비율을 유지하며,
/// 사방에 [padding] 여백을 둔다. 북쪽이 위. 점 1개는 중앙, 빈 경로는 빈 목록.
List<Offset> projectRoute(
  List<(double, double)> route,
  Size size, {
  double padding = 16,
}) {
  if (route.isEmpty) return const [];
  final project = routeProjector(route, size, padding: padding);
  return [for (final p in route) project(p)];
}

/// [route] 전체가 [size] 에 들어가게 맞춘 투영 함수. 경로의 일부(구간)를 같은 축척으로
/// 그릴 때 쓴다. [route] 는 비어 있지 않아야 한다. 규칙은 [projectRoute] 와 같다.
Offset Function((double, double)) routeProjector(
  List<(double, double)> route,
  Size size, {
  double padding = 16,
}) {
  final meanLat = route.fold<double>(0, (a, p) => a + p.$1) / route.length;
  final k = math.cos(meanLat * math.pi / 180);
  final xs = [for (final p in route) p.$2 * k];
  final ys = [for (final p in route) -p.$1];
  final minX = xs.reduce(math.min);
  final maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min);
  final maxY = ys.reduce(math.max);
  final spanX = maxX - minX;
  final spanY = maxY - minY;
  final availW = math.max(0.0, size.width - 2 * padding);
  final availH = math.max(0.0, size.height - 2 * padding);
  final scale = switch ((spanX > 0, spanY > 0)) {
    (true, true) => math.min(availW / spanX, availH / spanY),
    (true, false) => availW / spanX,
    (false, true) => availH / spanY,
    _ => 0.0,
  };
  final offsetX = (size.width - spanX * scale) / 2;
  final offsetY = (size.height - spanY * scale) / 2;
  return (p) => Offset(
    offsetX + (p.$2 * k - minX) * scale,
    offsetY + (-p.$1 - minY) * scale,
  );
}

/// 경로 페이스 단계별 선 색. 모두 토큰에서 온다([RoutePaceColors.of]).
@immutable
class RoutePaceColors {
  const RoutePaceColors({
    required this.slow,
    required this.mid,
    required this.fast,
    required this.fastMove,
    required this.single,
  });

  /// 느림 pace-slow, 보통 pace-mid, 빠름 pace-fast, 빠른 이동 ink-muted, 한 색 primary-deep.
  factory RoutePaceColors.of(AppColors c) => RoutePaceColors(
    slow: c.paceSlow,
    mid: c.paceMid,
    fast: c.paceFast,
    fastMove: c.inkMuted,
    single: c.primaryDeep,
  );

  final Color slow;
  final Color mid;
  final Color fast;
  final Color fastMove;
  final Color single;

  Color of(RoutePace pace) => switch (pace) {
    RoutePace.slow => slow,
    RoutePace.mid => mid,
    RoutePace.fast => fast,
    RoutePace.fastMove => fastMove,
    RoutePace.single => single,
  };

  @override
  bool operator ==(Object other) =>
      other is RoutePaceColors &&
      other.slow == slow &&
      other.mid == mid &&
      other.fast == fast &&
      other.fastMove == fastMove &&
      other.single == single;

  @override
  int get hashCode => Object.hash(slow, mid, fast, fastMove, single);
}

/// 지도 타일 없이 경로 선과 시작·끝 점만 그린다. 선은 [segments]([routePaceSegments])
/// 마다 페이스 색으로 칠하고, 색은 모두 호출하는 쪽이 토큰에서 넘긴다.
///
/// - 시작 점: [startColor](연두) 면 + [startEdge] 경계선([Borders.edge]). 연두 면 규칙.
/// - 끝 점: [endColor](진한 점) + 바깥 [endRing] 고리. 선 위에서도 점이 떨어져 보인다.
class RoutePainter extends CustomPainter {
  RoutePainter(
    this.route, {
    required this.segments,
    required this.colors,
    required this.startColor,
    required this.startEdge,
    required this.endColor,
    required this.endRing,
    this.lineWidth = defaultLineWidth,
  });

  final List<(double, double)> route;
  final List<RouteSegment> segments;
  final RoutePaceColors colors;
  final Color startColor;
  final Color startEdge;
  final Color endColor;
  final Color endRing;
  final double lineWidth;

  static const double defaultLineWidth = 6;
  static const double dotRadius = 8;

  /// 끝 점 바깥 고리 두께.
  static const double endRingWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.isEmpty) return;
    final project = routeProjector(route, size);
    for (final segment in segments) {
      if (segment.points.length < 2) continue;
      final first = project(segment.points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final p in segment.points.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors.of(segment.pace)
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
    final start = project(route.first);
    if (route.length > 1) {
      final end = project(route.last);
      canvas.drawCircle(
        end,
        dotRadius + endRingWidth,
        Paint()..color = endRing,
      );
      canvas.drawCircle(end, dotRadius, Paint()..color = endColor);
    }
    canvas.drawCircle(start, dotRadius, Paint()..color = startColor);
    canvas.drawCircle(
      start,
      dotRadius,
      Paint()
        ..color = startEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = Borders.edge,
    );
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.route != route ||
      old.segments != segments ||
      old.colors != colors ||
      old.startColor != startColor ||
      old.startEdge != startEdge ||
      old.endColor != endColor ||
      old.endRing != endRing ||
      old.lineWidth != lineWidth;
}

/// 경로 페이스 색 범례. 색만으로 뜻을 전하지 않도록 경로 아래에 둔다(디자인 시스템).
/// [segments] 에 3단·빠른 이동 색이 하나도 없으면(한 색 경로) 아무것도 그리지 않는다.
class RoutePaceLegend extends StatelessWidget {
  const RoutePaceLegend({super.key, required this.segments});

  final List<RouteSegment> segments;

  static const _labels = {
    RoutePace.slow: '느림',
    RoutePace.mid: '보통',
    RoutePace.fast: '빠름',
    RoutePace.fastMove: '빠른 이동',
  };

  /// 범례가 보이는가.
  static bool shows(List<RouteSegment> segments) =>
      segments.any((s) => s.pace != RoutePace.single);

  @override
  Widget build(BuildContext context) {
    if (!shows(segments)) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final colors = RoutePaceColors.of(c);
    final present = {for (final s in segments) s.pace};
    return Wrap(
      spacing: Gap.s4,
      runSpacing: Gap.s1,
      children: [
        for (final MapEntry(key: pace, value: label) in _labels.entries)
          if (present.contains(pace))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.of(pace),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: const SizedBox(
                    width: Gap.s4,
                    height: RoutePainter.defaultLineWidth,
                  ),
                ),
                const SizedBox(width: Gap.s1 + 2),
                Text(label, style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
      ],
    );
  }
}
