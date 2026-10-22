import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/ui/achievement_screen.dart';
import '../../shop/app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/providers.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';
import 'avatar_view.dart';
import 'sprite_sheet.dart' show spriteFramePx;

/// 단계 이름. 1단계는 종류마다 다르고, 2~4단계는 모두 같다.
const _laterStageNames = ['어린 러너', '러너', '마라토너'];

String _stageName(AvatarKind kind, int stage) {
  if (stage > 1) return _laterStageNames[stage - 2];
  return switch (kind) {
    AvatarKind.chick => '알',
    AvatarKind.jelly => '새싹',
    AvatarKind.acorn => '꼬마 도토리',
  };
}

/// `Lv.1~4`, 마지막 단계는 `Lv.20~`.
String _levelRange(int stage) {
  final start = stageStartLevels[stage - 1];
  if (stage >= stageStartLevels.length) return 'Lv.$start~';
  return 'Lv.$start~${stageStartLevels[stage] - 1}';
}

/// 세 번째 탭: 아바타와 성장 단계.
class AvatarScreen extends ConsumerWidget {
  const AvatarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 갱신 중에도 이전 값을 유지한다.
    final g = ref.watch(growthStateProvider).value;
    if (g == null) return const SizedBox.shrink();
    final equipped = ref.watch(equippedProvider).value;
    final c = AppColors.of(context);
    final t = AppText.of(context);
    // 시안 c 짜임새: 큰 사각 무대(마스코트가 주인공) → 이름·레벨 → 진행 → 업적 → 성장 단계.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s5, Gap.s5, Gap.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('아바타'),
            const SizedBox(height: Gap.s4),
            LayoutBuilder(
              builder: (context, box) {
                // 홈처럼 8배, 폭이 모자라면 들어가는 가장 큰 정수 배율.
                final scale =
                    PetStage.largestScale(
                      max: 8,
                      min: 4,
                      fits: (s) =>
                          spriteFramePx * s + 2 * Gap.s4 <= box.maxWidth,
                    ) ??
                    4;
                final stage = PetStage(
                  key: const ValueKey('avatar-stage'),
                  scale: scale,
                  pet: AvatarView(
                    kind: g.kind,
                    stage: g.stage,
                    mood: g.mood,
                    action: AvatarAction.idle,
                    scale: scale,
                    hatItemId: equipped?.hatItemId,
                    accessoryItemId: equipped?.accessoryItemId,
                  ),
                );
                // 펫 위로 무대 여백(말풍선 자리 없이 하늘만).
                return SizedBox(
                  height: spriteFramePx * scale + stage.petBottom + Gap.s5,
                  child: stage,
                );
              },
            ),
            const SizedBox(height: Gap.s4),
            Text(
              '${g.name} Lv.${g.level.level}',
              textAlign: TextAlign.center,
              style: t.title,
            ),
            const SizedBox(height: Gap.s1),
            Text(
              '누적 ${formatKm(g.totalDistanceM)}km · 러닝 ${g.runCount}회',
              textAlign: TextAlign.center,
              style: t.label.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Gap.s4),
            _StageProgress(g),
            const SizedBox(height: Gap.s5),
            AppButton.secondary(
              label: '업적',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AchievementScreen(),
                ),
              ),
            ),
            const SizedBox(height: Gap.s7),
            Text('성장 단계', style: t.heading),
            const SizedBox(height: Gap.s3),
            for (var s = 1; s <= stageStartLevels.length; s++)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s3),
                child: _StageRow(kind: g.kind, stage: s, currentStage: g.stage),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageProgress extends StatelessWidget {
  const _StageProgress(this.g);
  final GrowthState g;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final remaining = g.xpToNextStage;
    double value = 1;
    if (remaining != null) {
      final from = xpToReachLevel(stageStartLevels[g.stage - 1]);
      final to = xpToReachLevel(stageStartLevels[g.stage]);
      value = ((g.totalXp - from) / (to - from)).clamp(0.0, 1.0);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBar(value: value),
        const SizedBox(height: Gap.s2),
        Text(
          remaining == null
              ? '최고 단계'
              : '다음 성장 단계까지 ${(remaining / 10).toStringAsFixed(1)}km',
          style: t.label.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.kind,
    required this.stage,
    required this.currentStage,
  });
  final AvatarKind kind;
  final int stage;
  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final locked = stage > currentStage;
    final current = stage == currentStage;
    final status = current
        ? '현재'
        : locked
        ? '잠김'
        : '달성';
    // 작은 사각 무대(하늘·땅) 위 2배 미리보기. 상점 아이템 카드와 같은 문법이다.
    final tile = SizedBox(
      width: 64,
      height: 72,
      child: PetStage(
        scale: 2,
        groundHeight: Stage.groundHeightMini,
        radius: Radii.sm,
        pet: AvatarView(
          kind: kind,
          stage: stage,
          mood: AvatarMood.normal,
          action: AvatarAction.idle,
          scale: 2,
        ),
      ),
    );
    final Widget badge = current
        // 현재 단계: 무대색 알약(요약의 새 외형 단계! 와 같은 모양).
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: c.stageSky,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.s3,
                vertical: Gap.s1,
              ),
              child: Text(status, style: t.label.copyWith(color: c.stageInk)),
            ),
          )
        : Text(
            status,
            style: t.label.copyWith(color: locked ? c.inkMuted : c.primaryDeep),
          );
    return AppCard(
      radius: Radii.md,
      borderColor: current ? c.primaryEdge : null,
      padding: const EdgeInsets.fromLTRB(Gap.s3, Gap.s3, Gap.s5, Gap.s3),
      child: Row(
        children: [
          Opacity(opacity: locked ? 0.45 : 1, child: tile),
          const SizedBox(width: Gap.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$stage단계 ${_stageName(kind, stage)}', style: t.heading),
                const SizedBox(height: 2),
                Text(
                  _levelRange(stage),
                  style: t.label.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.s2),
          badge,
        ],
      ),
    );
  }
}
