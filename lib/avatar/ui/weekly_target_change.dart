import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../domain/growth_state.dart';

/// 주간 목표를 [targetM] 으로 바꾸고(같은 주 저장 + sync·알림 재예약), 성장 상태를 다시 읽게 한다.
/// 목표를 낮춰 보너스를 받으면 스낵바, 레벨이 오르면 레벨 업 창을 띄운다.
/// 홈 목표 카드와 설정 화면이 같이 쓴다.
Future<void> changeWeeklyTarget(
  BuildContext context,
  WidgetRef ref,
  double targetM,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  GrowthGain? gain;
  try {
    gain = await ref.read(growthServiceProvider).setWeeklyTarget(targetM);
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('목표를 바꾸지 못했어요')));
  }
  if (!context.mounted) return;
  ref.invalidate(growthStateProvider);
  final g = gain;
  if (g == null) return;
  // 목표 보너스 말고도 아직 반영하지 않은 러닝 경험치로 레벨이 오를 수 있다.
  if (g.leveledUp) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('레벨 업!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Lv.${g.levelBefore} 에서 Lv.${g.levelAfter} 로'),
            if (g.stageUp) const Text('새 외형 단계!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  } else if (g.goalBonusXp > 0) {
    messenger?.showSnackBar(
      SnackBar(content: Text('이번 주 목표 달성 · 경험치 +${g.goalBonusXp}')),
    );
  }
}
