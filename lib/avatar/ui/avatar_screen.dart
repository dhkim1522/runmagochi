import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: AvatarView(
                stage: g.stage,
                mood: g.mood,
                action: AvatarAction.idle,
                scale: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${g.name} Lv.${g.level.level}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '누적 ${formatKm(g.totalDistanceM)}km · 러닝 ${g.runCount}회',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _StageProgress(g),
            const SizedBox(height: 28),
            Text('성장 단계', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var s = 1; s <= stageStartLevels.length; s++)
              _StageRow(stage: s, currentStage: g.stage),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: value, minHeight: 12),
        ),
        const SizedBox(height: 6),
        Text(
          remaining == null
              ? '최고 단계'
              : '다음 성장 단계까지 ${(remaining / 10).toStringAsFixed(1)}km',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.currentStage});
  final int stage;
  final int currentStage;

  @override
  Widget build(BuildContext context) {
    final locked = stage > currentStage;
    final status = stage == currentStage
        ? '현재'
        : locked
        ? '잠김'
        : '달성';
    final preview = AvatarView(
      stage: stage,
      mood: AvatarMood.normal,
      action: AvatarAction.idle,
      scale: 2,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Opacity(opacity: locked ? 0.35 : 1, child: preview),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$stage단계 ${_stageNames[stage - 1]} · ${_levelRange(stage)}',
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontWeight: stage == currentStage ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}
