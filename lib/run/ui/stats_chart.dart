import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../domain/run_stats.dart';

/// 기간별 거리 막대 그래프. [name] 은 읽어 줄 때 쓰는 구분(요일별 등), [unit] 은 라벨 뒤 단위.
class StatsChart extends StatelessWidget {
  const StatsChart({
    super.key,
    required this.bars,
    required this.name,
    this.unit = '',
  });

  final List<StatsBar> bars;
  final String name;
  final String unit;

  static const height = 132.0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final filled = [
      for (final b in bars)
        if (b.distanceM > 0) '${b.label}$unit ${formatKm(b.distanceM)}km',
    ];
    final summary = filled.isEmpty ? '기록 없음' : filled.join(', ');
    return Semantics(
      label: '막대 그래프, $name 거리: $summary',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            bars: bars,
            barColor: c.primary,
            baseColor: c.inkMuted.withValues(alpha: 0.35),
            labelStyle: t.caption.copyWith(color: c.inkMuted),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.bars,
    required this.barColor,
    required this.baseColor,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<StatsBar> bars;
  final Color barColor;
  final Color baseColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  int get _step {
    final n = bars.length;
    if (n <= 12) return 1;
    if (n <= 31) return 5;
    return (n / 5).ceil();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0) return;
    final tp = TextPainter(
      text: TextSpan(text: '0', style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final labelH = tp.height + 4;
    final plotH = size.height - labelH;
    final slot = size.width / n;
    final barW = math.min(slot * 0.62, 28.0);
    final maxD = bars.fold<double>(0, (m, b) => math.max(m, b.distanceM));
    final fill = Paint()..color = barColor;
    final base = Paint()..color = baseColor;
    final step = _step;
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final d = bars[i].distanceM;
      if (d > 0) {
        final h = math.max(3.0, plotH * d / maxD);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, plotH - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          fill,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barW / 2, plotH - 2, barW, 2),
            const Radius.circular(1),
          ),
          base,
        );
      }
      final show = step == 1 ? true : (i == 0 || (i + 1) % step == 0);
      if (show) {
        final label = TextPainter(
          text: TextSpan(text: bars[i].label, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        label.paint(canvas, Offset(cx - label.width / 2, plotH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.bars != bars ||
      old.barColor != barColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}
