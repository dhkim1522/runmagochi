import 'package:flutter/material.dart';

import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../domain/run_stats.dart';
import 'share_card.dart' show shareCardSize;
import 'stats_chart.dart';

/// 주·월 결산 공유 카드 (F32, 결정 0037). 러닝 공유 카드와 같은 크기·짜임새다.
///
/// 머리줄(제목·기간) → 무대 위 펫 → 거리 크게 + 러닝 수·시간·평균 페이스 → 날짜별 막대 →
/// 캐릭터 이름과 레벨. 기기 테마·글자 크기와 상관없이 같은 모습이다.
class RecapCard extends StatelessWidget {
  const RecapCard({
    super.key,
    required this.title,
    required this.heading,
    required this.stats,
    required this.kind,
    required this.stage,
    required this.mood,
    required this.name,
    required this.level,
    this.hatItemId,
    this.accessoryItemId,
  });

  /// 기간(예: `2026년 10월`).
  final String title;

  /// 결산 이름(예: `이번 주 결산`).
  final String heading;
  final RunStats stats;
  final AvatarKind kind;
  final int stage;
  final AvatarMood mood;
  final String name;
  final int level;
  final String? hatItemId;
  final String? accessoryItemId;

  static const int _maxScale = 5;
  static const int _minScale = 2;
  static const double _chartHeight = 72;

  static double _stageHeight(int scale) =>
      spriteFramePx * scale +
      Stage.groundHeightCompact -
      Stage.footSink -
      spriteFootGapRows * scale;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: appLightTheme(),
      child: Builder(
        builder: (context) {
          final c = AppColors.of(context);
          final t = AppText.of(context);
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: SizedBox.fromSize(
              size: shareCardSize,
              child: Material(
                type: MaterialType.transparency,
                child: ColoredBox(
                  color: c.background,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.s6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              heading,
                              style: t.heading.copyWith(color: c.primaryDeep),
                            ),
                            const SizedBox(width: Gap.s2),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  title,
                                  style: t.caption.copyWith(color: c.inkMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.s3),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final scale =
                                  PetStage.largestScale(
                                    max: _maxScale,
                                    min: _minScale,
                                    fits: (s) =>
                                        _stageHeight(s) <= box.maxHeight,
                                  ) ??
                                  _minScale;
                              return PetStage(
                                height: box.maxHeight,
                                scale: scale,
                                groundHeight: Stage.groundHeightCompact,
                                pet: AvatarView(
                                  kind: kind,
                                  stage: stage,
                                  mood: mood,
                                  action: AvatarAction.idle,
                                  scale: scale,
                                  hatItemId: hatItemId,
                                  accessoryItemId: accessoryItemId,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: Gap.s3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    formatKm(stats.distanceM),
                                    style: t.numberL,
                                  ),
                                  const SizedBox(width: Gap.s1),
                                  Text(
                                    'km',
                                    style: t.titleS.copyWith(color: c.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.s1),
                        Row(
                          children: [
                            Expanded(child: _Stat('러닝', '${stats.count}회')),
                            Expanded(
                              child: _Stat(
                                '시간',
                                formatDuration(stats.movingTime),
                              ),
                            ),
                            Expanded(
                              child: _Stat(
                                '평균 페이스',
                                formatPace(stats.avgPaceSecPerKm),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.s3),
                        SizedBox(
                          height: _chartHeight,
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              painter: StatsChartPainter(
                                bars: stats.bars,
                                barColor: c.primaryDeep,
                                baseColor: c.inkMuted.withValues(alpha: 0.35),
                                labelStyle: t.caption.copyWith(
                                  color: c.inkMuted,
                                  fontSize: 10,
                                ),
                                textScaler: TextScaler.noScaling,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Gap.s3),
                        Text(
                          '$name Lv.$level',
                          textAlign: TextAlign.center,
                          style: t.heading.copyWith(color: c.primaryDeep),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: t.label.copyWith(color: c.inkMuted)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: t.stat),
        ),
      ],
    );
  }
}
