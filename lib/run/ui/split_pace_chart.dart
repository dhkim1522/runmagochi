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

  /// 막대 길이 비율(0~1). 속도(1/페이스)에 비례해 빠를수록 길다.
  double _ratio(double paceSecPerKm, double maxSpeed) =>
      (1 / paceSecPerKm) / maxSpeed;

  @override
  void paint(Canvas canvas, Size size) {
    final n = splits.length;
    if (n == 0) return;
    final tp = TextPainter(
      text: TextSpan(text: '0', style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final plotH = size.height - tp.height - 4;
    final slot = size.width / n;
    final barW = math.min(slot * 0.62, 28.0);
    final paces = [
      for (final s in splits)
        if (s.paceSecPerKm.isFinite && s.paceSecPerKm > 0) s.paceSecPerKm,
    ];
    if (paces.isEmpty) return;
    final maxSpeed = paces.fold<double>(0, (m, p) => math.max(m, 1 / p));
    for (var i = 0; i < n; i++) {
      final s = splits[i];
      final cx = slot * i + slot / 2;
      final pace = s.paceSecPerKm;
      if (pace.isFinite && pace > 0) {
        final h = math.max(3.0, plotH * _ratio(pace, maxSpeed));
        var color = isFastSplit(s) ? fastColor : barColor;
        if (s.distanceM < 1000) color = color.withValues(alpha: 0.4);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, plotH - h, barW, h),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          Paint()..color = color,
        );
      }
      final label = TextPainter(
        text: TextSpan(text: '${s.index}', style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      label.paint(canvas, Offset(cx - label.width / 2, plotH + 4));
    }
    final avg = avgPaceSecPerKm;
    if (avg != null && avg.isFinite && avg > 0) {
      final y = plotH - plotH * _ratio(avg, maxSpeed).clamp(0.0, 1.0);
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
