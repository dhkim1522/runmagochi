import 'dart:typed_data';

import 'package:flutter/material.dart' hide Split;

import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart';
import '../../core/format.dart';
import '../../core/stage/stage_weather.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../../core/ui/offscreen.dart';
import '../../shop/domain/catalog.dart';
import '../domain/route_pace.dart';
import '../domain/run_summary.dart';
import 'route_painter.dart';

/// 카드의 논리 크기. 3배로 찍으면 1080×1350 PNG 가 된다.
const shareCardSize = Size(360, 450);
const shareCardPixelRatio = 3.0;

/// 러닝 요약을 한 장으로 만든 공유 카드. 기기 테마·글자 크기와 상관없이 같은 모습이다.
///
/// 배치(연두 무드보드, 결정 0029): 머리줄(앱 이름·날짜) → 폭 전체 사각 무대 위 펫(남는
/// 높이에 들어가는 가장 큰 배율) → 경로 칸(페이스 색) + 거리·지표 → 범례 → 목표·레벨 문구.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.kind,
    required this.stage,
    required this.mood,
    required this.startedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    this.route = const [],
    this.splits = const [],
    this.hatItemId,
    this.accessoryItemId,
    this.goalLine,
    this.levelUpLine,
  });

  /// 아바타. 모르면 null 이고 아바타 자리를 그리지 않는다.
  final AvatarKind? kind;
  final int stage;
  final AvatarMood mood;
  final String? hatItemId;
  final String? accessoryItemId;
  final DateTime startedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;

  /// (위도, 경도) 경로. 비어 있으면 경로 칸을 그리지 않는다.
  final List<(double, double)> route;

  /// 1km 구간. 경로 페이스 색을 정한다([routePaceSegments]).
  final List<Split> splits;

  /// 목표 결과 한 줄. 목표 없는 예전 러닝은 null.
  final String? goalLine;

  /// 레벨업 한 줄. 레벨이 오르지 않았으면 null.
  final String? levelUpLine;

  /// 아바타 시트 경로. 그리기 전에 미리 읽어 둘 때 쓴다.
  static List<String> sheetPaths({
    required AvatarKind kind,
    required int stage,
    required AvatarMood mood,
    String? hatItemId,
    String? accessoryItemId,
  }) {
    const a = AvatarAction.idle;
    String? item(String? id, ItemSlot slot) {
      final it = id == null ? null : itemById(id);
      return it == null || it.slot != slot ? null : itemSheet(kind, it, a);
    }

    return [
      bodySheet(kind, stage, a),
      faceSheet(kind, mood, a),
      ?item(hatItemId, ItemSlot.hat),
      ?item(accessoryItemId, ItemSlot.accessory),
    ];
  }

  /// 펫 배율 범위. 무대 높이에 들어가는 가장 큰 정수 배율을 고른다.
  static const int _maxScale = 6;
  static const int _minScale = 2;

  /// 경로 칸 한 변.
  static const double _routeSide = 120;

  /// [scale] 배 펫이 땅 위에 서는 무대 높이(땅 띠 [Stage.groundHeightCompact]).
  static double _stageHeight(int scale) =>
      spriteFramePx * scale +
      Stage.groundHeightCompact -
      Stage.footSink -
      spriteFootGapRows * scale;

  @override
  Widget build(BuildContext context) {
    // 사용자 테마·글자 배율에 흔들리지 않게 라이트 토큰과 고정 배율로 그린다.
    // 사용자 테마·날씨와 상관없이 라이트·맑은 낮으로 그린다.
    return StageWeatherScope(
      weather: StageWeather.clearDay,
      child: Theme(
        data: appLightTheme(),
        child: Builder(
          builder: (context) {
            final c = AppColors.of(context);
            final t = AppText.of(context);
            final k = kind;
            final segments = routePaceSegments(route, splits);
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: SizedBox.fromSize(
                size: shareCardSize,
                // 화면 밖 Overlay 에는 Material 이 없어 글자에 노란 밑줄이 그려진다.
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
                                'runmagochi',
                                style: t.heading.copyWith(color: c.primaryDeep),
                              ),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    formatRunDate(startedAt),
                                    style: t.caption.copyWith(
                                      color: c.inkMuted,
                                    ),
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
                                  pet: k == null
                                      ? SizedBox.square(
                                          dimension: (spriteFramePx * scale)
                                              .toDouble(),
                                        )
                                      : AvatarView(
                                          kind: k,
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
                          SizedBox(
                            height: _routeSide,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (route.isNotEmpty) ...[
                                  AppCard(
                                    radius: Radii.md,
                                    child: SizedBox.square(
                                      dimension: _routeSide,
                                      child: CustomPaint(
                                        painter: RoutePainter(
                                          route,
                                          segments: segments,
                                          colors: RoutePaceColors.of(c),
                                          startColor: c.primary,
                                          startEdge: c.primaryEdge,
                                          endColor: c.ink,
                                          endRing: c.surface,
                                          lineWidth: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Gap.s3),
                                ],
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: route.isEmpty
                                        ? CrossAxisAlignment.center
                                        : CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              formatKm(distanceM),
                                              style: t.numberL,
                                            ),
                                            const SizedBox(width: Gap.s1),
                                            Text(
                                              'km',
                                              style: t.titleS.copyWith(
                                                color: c.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: Gap.s1),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _Stat(
                                              '평균 페이스',
                                              formatPace(avgPaceSecPerKm),
                                            ),
                                          ),
                                          const SizedBox(width: Gap.s2),
                                          Expanded(
                                            child: _Stat(
                                              '시간',
                                              formatDuration(movingTime),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (RoutePaceLegend.shows(segments)) ...[
                            const SizedBox(height: Gap.s2),
                            RoutePaceLegend(segments: segments),
                          ],
                          if (goalLine != null) ...[
                            const SizedBox(height: Gap.s3),
                            Text(
                              goalLine!,
                              textAlign: TextAlign.center,
                              style: t.heading.copyWith(color: c.success),
                            ),
                          ],
                          if (levelUpLine != null) ...[
                            SizedBox(
                              height: goalLine == null ? Gap.s3 : Gap.s1,
                            ),
                            Text(
                              levelUpLine!,
                              textAlign: TextAlign.center,
                              style: t.heading.copyWith(color: c.primaryDeep),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 지표 한 칸: 라벨(label, inkMuted) 위, 값(stat) 아래. 폭이 모자라면 작아진다.
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

/// [card](러닝 공유 카드·결산 카드)를 화면 밖에서 그려 PNG 바이트로 만든다.
/// [sheets] 는 [ShareCard.sheetPaths] 의 결과다.
Future<Uint8List> renderShareCard(
  BuildContext context,
  Widget card, {
  List<String> sheets = const [],
}) => renderOffscreen(
  context,
  card,
  size: shareCardSize,
  pixelRatio: shareCardPixelRatio,
  sheets: sheets,
);
