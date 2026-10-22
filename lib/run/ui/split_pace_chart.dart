import 'dart:math' as math;

import 'package:flutter/material.dart' hide Split;

import '../../avatar/domain/growth_rules.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../domain/run_summary.dart';

/// 1km 구간별 페이스 막대 그래프. 빠를수록 길고, 평균 페이스는 가로선으로 그린다.
/// 막대는 primary-deep(연두로 채우지 않는다), 위끝 radius-sm 둥근 모서리. 1km 미만 마지막
/// 구간은 흐리게, 경험치에서 빠지는 빠른 구간은 `ink-muted` 로 그린다. 막대 아래 라벨은
/// 구간 표와 같은 이름([splitLabel]). 구간이 1개 이하면 아무것도 그리지 않는다.
class SplitPaceChart extends StatelessWidget {
  const SplitPaceChart({
    super.key,
    required this.splits,
    required this.avgPaceSecPerKm,
  });

  final List<Split> splits;
  final double? avgPaceSecPerKm;

  /// 막대 130 + 라벨 자리(시안 c).
  static const height = 160.0;

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
            labels: [
              for (var i = 0; i < splits.length; i++) splitLabel(splits, i),
            ],
            avgPaceSecPerKm: avgPaceSecPerKm,
            barColor: c.primaryDeep,
            fastColor: c.inkMuted,
            lineColor: c.ink,
            lineGapColor: c.surface,
            labelStyle: t.caption.copyWith(color: c.inkMuted),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

/// 온전한 1km 구간은 번호, 마지막 짧은 구간은 누적 거리(km)로 부른다. 그래프 라벨과 구간 표가 같이 쓴다.
String splitLabel(List<Split> splits, int i) {
  final sp = splits[i];
  if (sp.distanceM >= 1000) return '${sp.index}';
  final cumulative = splits
      .take(i + 1)
      .fold<double>(0, (a, e) => a + e.distanceM);
  return formatKm(cumulative).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// 막대 사이 간격(가장 큰 값). 칸이 좁으면 칸의 30% 로 줄인다.
const _barGap = Gap.s3;

/// [slot] 폭 칸 안의 막대 폭.
double paceBarWidth(double slot) => slot - math.min(_barGap, slot * 0.3);

class SplitPacePainter extends CustomPainter {
  SplitPacePainter({
    required this.splits,
    required this.labels,
    required this.avgPaceSecPerKm,
    required this.barColor,
    required this.fastColor,
    required this.lineColor,
    required this.lineGapColor,
    required this.labelStyle,
    required this.textScaler,
  });

  final List<Split> splits;

  /// 막대 아래 라벨([splitLabel]).
  final List<String> labels;
  final double? avgPaceSecPerKm;
  final Color barColor;
  final Color fastColor;

  /// 평균 페이스 가로선. 막대와 같은 초록이면 안 보여 진한 글자색을 쓴다.
  final Color lineColor;

  /// 평균선 아래 깔아 막대와 떼어 놓는 카드 바탕색 띠.
  final Color lineGapColor;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final n = splits.length;
    if (n == 0) return;
    TextPainter label(String text) => TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final widest = labels.fold<double>(
      0,
      (w, l) => math.max(w, label(l).width),
    );
    final labelH = label('0').height;
    final plotH = size.height - labelH - Gap.s3;
    final slot = size.width / n;
    final barW = paceBarWidth(slot);
    final step = paceLabelStep(slot, widest);
    final layout = layoutPaceBars(
      splits: splits,
      avgPaceSecPerKm: avgPaceSecPerKm,
      plotH: plotH,
      barColor: barColor,
      fastColor: fastColor,
    );
    final top = Radius.circular(math.min(Radii.sm, barW / 2));
    final bottom = Radius.circular(math.min(4, barW / 2));
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final bar = layout.bars[i];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, plotH - bar.height, barW, bar.height),
          topLeft: top,
          topRight: top,
          bottomLeft: bottom,
          bottomRight: bottom,
        ),
        Paint()..color = bar.color,
      );
      if (i % step == 0) {
        final l = label(labels[i]);
        l.paint(canvas, Offset(cx - l.width / 2, plotH + Gap.s3));
      }
    }
    final y = layout.avgLineY;
    if (y != null) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = lineGapColor
          ..strokeWidth = 6,
      );
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
      old.lineGapColor != lineGapColor ||
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
