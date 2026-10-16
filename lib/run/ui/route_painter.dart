import 'dart:math' as math;

import 'package:flutter/material.dart';

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
  return [
    for (var i = 0; i < route.length; i++)
      Offset(
        offsetX + (xs[i] - minX) * scale,
        offsetY + (ys[i] - minY) * scale,
      ),
  ];
}

/// 지도 타일 없이 경로 선만 그린다.
class RoutePainter extends CustomPainter {
  RoutePainter(this.route, {required this.color});

  final List<(double, double)> route;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = projectRoute(route, size);
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (pts.length == 1) {
      canvas.drawCircle(pts.first, 5, paint..style = PaintingStyle.fill);
      return;
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RoutePainter old) =>
      old.route != route || old.color != color;
}
