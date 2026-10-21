import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../shop/domain/catalog.dart';

/// 카드의 논리 크기. 3배로 찍으면 1080×1350 PNG 가 된다.
const shareCardSize = Size(360, 450);
const shareCardPixelRatio = 3.0;

/// 러닝 요약을 한 장으로 만든 공유 카드. 기기 테마·글자 크기와 상관없이 같은 모습이다.
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

  @override
  Widget build(BuildContext context) {
    // 사용자 테마·글자 배율에 흔들리지 않게 라이트 토큰과 고정 배율로 그린다.
    return Theme(
      data: appLightTheme(),
      child: Builder(
        builder: (context) {
          final c = AppColors.of(context);
          final t = AppText.of(context);
          final k = kind;
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: SizedBox.fromSize(
              size: shareCardSize,
              child: ColoredBox(
                color: c.cream,
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
                                style: t.caption.copyWith(color: c.inkMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Center(
                          child: k == null
                              ? const SizedBox.shrink()
                              : AvatarView(
                                  kind: k,
                                  stage: stage,
                                  mood: mood,
                                  action: AvatarAction.idle,
                                  scale: 5,
                                  hatItemId: hatItemId,
                                  accessoryItemId: accessoryItemId,
                                ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(formatKm(distanceM), style: t.numberL),
                          const SizedBox(width: Gap.s2),
                          Text(
                            'km',
                            style: t.titleS.copyWith(color: c.primaryDeep),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.s4),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat('평균 페이스', formatPace(avgPaceSecPerKm)),
                          ),
                          Expanded(
                            child: _Stat('시간', formatDuration(movingTime)),
                          ),
                        ],
                      ),
                      if (goalLine != null) ...[
                        const SizedBox(height: Gap.s4),
                        Text(
                          goalLine!,
                          textAlign: TextAlign.center,
                          style: t.heading.copyWith(color: c.success),
                        ),
                      ],
                      if (levelUpLine != null) ...[
                        const SizedBox(height: Gap.s2),
                        Text(
                          levelUpLine!,
                          textAlign: TextAlign.center,
                          style: t.heading.copyWith(color: c.accentDeep),
                        ),
                      ],
                    ],
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
      children: [
        Text(label, style: t.caption.copyWith(color: c.inkMuted)),
        Text(value, style: t.stat),
      ],
    );
  }
}

/// [card] 를 화면 밖에서 그려 PNG 바이트로 만든다.
///
/// 아바타 시트를 먼저 읽어 두고(비어 있는 아바타가 찍히지 않게) 그린 뒤 찍는다.
/// [sheets] 는 [ShareCard.sheetPaths] 의 결과다.
Future<Uint8List> renderShareCard(
  BuildContext context,
  ShareCard card, {
  List<String> sheets = const [],
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  for (final p in sheets) {
    await precacheImage(AssetImage(p), context);
  }
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // 화면 왼쪽 밖. 배치·그리기는 되지만 보이지 않는다.
      left: -shareCardSize.width - 100,
      top: 0,
      child: RepaintBoundary(key: key, child: card),
    ),
  );
  overlay.insert(entry);
  try {
    // 그려진 뒤 이미지 리스너가 한 번 더 그리게 한다.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: shareCardPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
