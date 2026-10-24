import 'package:flutter/material.dart';

import '../avatar/domain/growth_rules.dart';
import '../avatar/ui/avatar_view.dart';
import '../avatar/ui/sprite_sheet.dart';
import '../core/stage/stage_weather.dart';
import '../core/theme.dart';
import '../core/ui/components.dart';
import '../run/ui/share_card.dart' show ShareCard;

/// 홈 화면 위젯 그림의 논리 크기(2×2 칸). 3배로 찍어 510×510 PNG 로 보낸다.
const petWidgetSize = Size(170, 170);
const petWidgetPixelRatio = 3.0;

/// 홈 화면 위젯 카드 (F29, 결정 0037): 날씨 무대 위 캐릭터, 아래에 이름·레벨과 다음
/// 레벨까지 거리. 앱 안에서 PNG 로 그려 Android·iOS 위젯이 같은 그림을 보인다.
/// 기기 테마·글자 크기와 상관없이 라이트로 그린다(밤·비 무대는 날씨가 정한다).
class PetWidgetCard extends StatelessWidget {
  const PetWidgetCard({
    super.key,
    required this.kind,
    required this.stage,
    required this.mood,
    required this.name,
    required this.level,
    required this.kmToNextLevel,
    required this.weather,
    this.hatItemId,
    this.accessoryItemId,
  });

  final AvatarKind kind;
  final int stage;
  final AvatarMood mood;
  final String name;
  final int level;
  final double kmToNextLevel;
  final StageWeather weather;
  final String? hatItemId;
  final String? accessoryItemId;

  /// 미리 읽어 둘 아바타 시트.
  List<String> get sheets => ShareCard.sheetPaths(
    kind: kind,
    stage: stage,
    mood: mood,
    hatItemId: hatItemId,
    accessoryItemId: accessoryItemId,
  );

  static const int _maxScale = 3;
  static const int _minScale = 2;

  static double _stageHeight(int scale) =>
      spriteFramePx * scale +
      Stage.groundHeightCompact -
      Stage.footSink -
      spriteFootGapRows * scale;

  @override
  Widget build(BuildContext context) {
    return StageWeatherScope(
      weather: weather,
      child: Theme(
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
                size: petWidgetSize,
                child: Material(
                  type: MaterialType.transparency,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.lg),
                    child: ColoredBox(
                      color: c.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Gap.s3,
                              Gap.s2,
                              Gap.s3,
                              Gap.s3,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '$name Lv.$level',
                                    style: t.bodyStrong.copyWith(color: c.ink),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '다음 레벨까지 ${kmToNextLevel.toStringAsFixed(1)}km',
                                    style: t.caption.copyWith(
                                      color: c.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
