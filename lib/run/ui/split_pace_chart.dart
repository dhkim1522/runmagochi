import 'dart:math' as math;

import 'package:flutter/material.dart' hide Split;

import '../../avatar/domain/growth_rules.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../domain/run_summary.dart';

/// 1km 구간별 페이스 막대 그래프. 빠를수록 길고, 평균 페이스는 가로선으로 그린다.
/// 1km 미만 마지막 구간은 흐리게, 경험치에서 빠지는 빠른 구간은 `ink-muted` 로 그린다.
/// 구간이 1개 이하면 아무것도 그리지 않는다.
class SplitPaceChart extends StatelessWidget {
  const SplitPaceChart({
    super.key,
    required this.splits,
    required this.avgPaceSecPerKm,
  });

  final List<Split> splits;
  final double? avgPaceSecPerKm;

  static const height = 132.0;

  @override
  Widget build(BuildContext context) {
    if (splits.length <= 1) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final summary = [
      for (final s in splits) '${s.index}번째 ${formatPace(s.paceSecPerKm)}',
    ].join(', ');
    return Semantics(
      label: '구간별 페이스 막대 그래프, 평균 ${formatPace(avgPaceSecPerKm)}: $summary',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: SplitPacePainter(
            splits: splits,
            avgPaceSecPerKm: avgPaceSecPerKm,
            barColor: c.primary,
            fastColor: c.inkMuted,
            lineColor: c.primaryDeep,
            labelStyle: t.caption.copyWith(color: c.inkMuted),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

class SplitPacePainter extends CustomPainter {
  SplitPacePainter({
    required this.splits,
    required this.avgPaceSecPerKm,
    required this.barColor,
    required this.fastColor,
    required this.lineColor,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<Split> splits;
  final double? avgPaceSecPerKm;
  final Color barColor;
  final Color fastColor;
  final Color lineColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final n = splits.length;
    if (n == 0) return;
    final tp = TextPainter(
      text: TextSpan(text: '${splits.last.index}', style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final plotH = size.height - tp.height - 4;
    final slot = size.width / n;
    final barW = math.min(slot * 0.62, 28.0);
    final step = paceLabelStep(slot, tp.width);
    final layout = layoutPaceBars(
      splits: splits,
      avgPaceSecPerKm: avgPaceSecPerKm,
      plotH: plotH,
      barColor: barColor,
      fastColor: fastColor,
    );
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final bar = layout.bars[i];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, plotH - bar.height, barW, bar.height),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = bar.color,
      );
      if (i % step == 0) {
        final label = TextPainter(
          text: TextSpan(text: '${splits[i].index}', style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        label.paint(canvas, Offset(cx - label.width / 2, plotH + 4));
      }
    }
    final y = layout.avgLineY;
    if (y != null) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(SplitPacePainter old) =>
      old.splits != splits ||
      old.avgPaceSecPerKm != avgPaceSecPerKm ||
      old.barColor != barColor ||
      old.fastColor != fastColor ||
      old.lineColor != lineColor ||
      old.labelStyle != labelStyle ||
      old.textScaler != textScaler;
}

/// 막대 하나의 높이와 색.
class PaceBar {
  const PaceBar(this.height, this.color);
  final double height;
  final Color color;
}

/// 막대 목록과 평균 페이스 가로선의 y(위에서부터, 평균이 없으면 null).
class PaceLayout {
  const PaceLayout(this.bars, this.avgLineY);
  final List<PaceBar> bars;
  final double? avgLineY;
}

const _minBarHeight = 3.0;
const _shortSplitAlpha = 0.4;

/// 막대 높이·색을 계산한다. 높이는 속도(1/페이스)에 비례해 빠를수록 크다.
/// 페이스를 알 수 없는 구간(시간 0 등)은 최소 높이의 `fastColor` 막대로 그린다.
/// 1km 미만 구간은 알파 0.4 로 흐리게 한다.
PaceLayout layoutPaceBars({
  required List<Split> splits,
  required double? avgPaceSecPerKm,
  required double plotH,
  required Color barColor,
  required Color fastColor,
}) {
  bool valid(double p) => p.isFinite && p > 0;
  final maxSpeed = splits.fold<double>(
    0,
    (m, s) => valid(s.paceSecPerKm) ? math.max(m, 1 / s.paceSecPerKm) : m,
  );
  final bars = <PaceBar>[];
  for (final s in splits) {
    final p = s.paceSecPerKm;
    final height = valid(p)
        ? math.max(_minBarHeight, plotH * (1 / p) / maxSpeed)
        : _minBarHeight;
    var color = (!valid(p) || isFastSplit(s)) ? fastColor : barColor;
    if (s.distanceM < 1000) color = color.withValues(alpha: _shortSplitAlpha);
    bars.add(PaceBar(height, color));
  }
  final avg = avgPaceSecPerKm;
  final y = (avg != null && valid(avg) && maxSpeed > 0)
      ? plotH - plotH * ((1 / avg) / maxSpeed).clamp(0.0, 1.0)
      : null;
  return PaceLayout(bars, y);
}

/// 라벨이 겹치지 않게 몇 칸마다 하나씩 그릴지.
int paceLabelStep(double slotWidth, double labelWidth) =>
    math.max(1, ((labelWidth + 4) / slotWidth).ceil());
