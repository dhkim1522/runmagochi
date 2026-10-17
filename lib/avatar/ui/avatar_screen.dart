import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/providers.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';
import 'avatar_view.dart';

/// 단계 이름. 인덱스 0 이 1단계.
const _stageNames = ['알·새싹', '어린 러너', '러너', '마라토너'];

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
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('아바타'),
            const SizedBox(height: Gap.s4),
            // 무대 카드: surface-soft, radius-xl, 립 없음.
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: c.line, width: Borders.thick),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Gap.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: AvatarView(
                        kind: g.kind,
                        stage: g.stage,
                        mood: g.mood,
                        action: AvatarAction.idle,
                        scale: 4,
                      ),
                    ),
                    const SizedBox(height: Gap.s2),
                    Text(
                      '${g.name} Lv.${g.level.level}',
                      textAlign: TextAlign.center,
                      style: t.title,
                    ),
                    const SizedBox(height: Gap.s2),
                    Text(
                      '누적 ${formatKm(g.totalDistanceM)}km · 러닝 ${g.runCount}회',
                      textAlign: TextAlign.center,
                      style: t.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _StageProgress(g),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.s5),
            Text('성장 단계', style: t.heading),
            const SizedBox(height: Gap.s3),
            for (var s = 1; s <= stageStartLevels.length; s++)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s3 - Borders.lip),
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
        ClayBar(value: value, height: 14, fill: c.primary, track: c.surface),
        const SizedBox(height: 6),
        Text(
          remaining == null
              ? '최고 단계'
              : '다음 성장 단계까지 ${(remaining / 10).toStringAsFixed(1)}km',
          style: t.caption.copyWith(color: c.inkMuted),
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
    final tile = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceSoft,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: AvatarView(
          kind: kind,
          stage: stage,
          mood: AvatarMood.normal,
          action: AvatarAction.idle,
          scale: 2,
        ),
      ),
    );
    return ClayCard(
      radius: Radii.md,
      borderColor: current ? c.primary : null,
      lipColor: current ? c.primaryDeep : null,
      padding: const EdgeInsets.symmetric(vertical: Gap.s3, horizontal: Gap.s4),
      child: Row(
        children: [
          Opacity(opacity: locked ? 0.45 : 1, child: tile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$stage단계 ${_stageNames[stage - 1]}', style: t.heading),
                Text(
                  _levelRange(stage),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.s2),
          Text(
            status,
            style: current
                ? t.label.copyWith(color: c.primaryDeep)
                : t.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: c.inkMuted,
                  ),
          ),
        ],
      ),
    );
  }
}
