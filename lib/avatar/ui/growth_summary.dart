import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/domain/badges.dart';
import '../../achievement/ui/badge_image.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../run/domain/run_goal.dart';
import '../../shop/app/providers.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';
import 'avatar_view.dart';
import 'sprite_sheet.dart';

/// 러닝 직후 요약 위쪽에 놓는 경험치 획득·레벨업 영역.
class GrowthSummary extends StatefulWidget {
  const GrowthSummary({
    super.key,
    required this.kind,
    required this.gain,
    required this.distanceM,
    required this.goal,
    required this.movingTime,
    required this.achieved,
    this.excludedM = 0,
  });

  /// 아바타 종류. 아직 모르면 null 이고 같은 크기의 빈자리를 둔다.
  final AvatarKind? kind;
  final GrowthGain gain;

  /// 방금 달린 거리(미터).
  final double distanceM;

  /// 이 러닝의 오늘 목표. 목표가 없는 예전 러닝은 null 이고 목표 줄을 그리지 않는다.
  final RunGoal? goal;

  /// 움직인 시간. 시간 목표의 남은 시간을 셀 때 쓴다.
  final Duration movingTime;

  /// [goal] 을 채웠는가. 호출하는 쪽이 지금 거리·구간으로 [goalAchieved] 를 계산해 넘긴다.
  final bool achieved;

  /// 속도 검사로 경험치에서 뺀 거리(미터). 0 이면 안내를 보이지 않는다.
  final double excludedM;

  @override
  State<GrowthSummary> createState() => _GrowthSummaryState();
}

class _GrowthSummaryState extends State<GrowthSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _animates => widget.gain.leveledUp || widget.gain.stageUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (_animates) _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 외형이 바뀌는 순간 새 단계 시트가 비어 보이지 않게 미리 읽어 둔다.
    final g = widget.gain;
    final kind = widget.kind;
    if (kind != null && g.stageUp) {
      precacheImage(
        AssetImage(bodySheet(kind, g.stageAfter, AvatarAction.idle)),
        context,
      );
      precacheImage(
        AssetImage(faceSheet(kind, AvatarMood.normal, AvatarAction.idle)),
        context,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final g = widget.gain;
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _XpRow(
          '달린 거리 ${formatKm(widget.distanceM)}km',
          '경험치 +${g.distanceXp}',
          coins: g.distanceCoins,
        ),
        if (widget.excludedM > 0) ...[
          const SizedBox(height: Gap.s2),
          Text(
            '빠른 이동 ${formatKm(widget.excludedM)}km는 경험치에서 뺐어요',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
        if (widget.goal case final goal?) ...[
          const SizedBox(height: Gap.s3),
          GoalResult(
            goal: goal,
            distanceM: widget.distanceM,
            movingTime: widget.movingTime,
            excludedM: widget.excludedM,
            achieved: widget.achieved,
            bonusXp: g.goalBonusXp,
            coins: g.goalCoins,
          ),
        ],
        for (final id in g.newBadges)
          if (badgeCatalog.where((b) => b.id == id).firstOrNull
              case final badge?) ...[
            const SizedBox(height: Gap.s3),
            _XpRow(
              '배지 획득: ${badge.name}',
              '코인 +${badge.coins}',
              valueColor: c.coin,
              leading: BadgeImage(
                badge.id,
                key: ValueKey('new-badge-${badge.id}'),
                earned: true,
              ),
            ),
          ],
      ],
    );
    if (!_animates) return rows;
    return DecoratedBox(
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
            if (g.leveledUp) ...[
              Text(
                '레벨 업!',
                textAlign: TextAlign.center,
                style: t.title.copyWith(color: c.primaryDeep),
              ),
              const SizedBox(height: Gap.s2),
              Text(
                'Lv.${g.levelBefore} 에서 Lv.${g.levelAfter} 로',
                textAlign: TextAlign.center,
                style: t.label.copyWith(color: c.inkMuted),
              ),
            ],
            if (g.stageUp) ...[
              const SizedBox(height: Gap.s2),
              Text('새 외형 단계!', textAlign: TextAlign.center, style: t.heading),
            ],
            const SizedBox(height: Gap.s3),
            _avatar(),
            const SizedBox(height: Gap.s5),
            rows,
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final g = widget.gain;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 커졌다 돌아온다: 1 → 1.3 → 1.
          final scale = g.leveledUp ? 1 + 0.3 * math.sin(math.pi * t) : 1.0;
          // 절반이 지나면 이전 단계에서 새 단계로 바뀐다.
          final stage = g.stageUp && t < 0.5 ? g.stageBefore : g.stageAfter;
          final kind = widget.kind;
          return Transform.scale(
            key: const ValueKey('level-up-scale'),
            scale: scale,
            child: kind == null
                ? const AvatarSlot(scale: 6)
                : Consumer(
                    builder: (context, ref, _) {
                      final equipped = ref.watch(equippedProvider).value;
                      return AvatarView(
                        kind: kind,
                        stage: stage,
                        mood: AvatarMood.normal,
                        action: AvatarAction.idle,
                        scale: 6,
                        hatItemId: equipped?.hatItemId,
                        accessoryItemId: equipped?.accessoryItemId,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

/// 오늘 목표 결과 한 줄. 달성이면 보너스, 미달이면 남은 거리나 빠른 이동 안내.
class GoalResult extends StatelessWidget {
  const GoalResult({
    super.key,
    required this.goal,
    required this.distanceM,
    required this.movingTime,
    required this.excludedM,
    required this.achieved,
    required this.bonusXp,
    this.coins = 0,
  });

  final RunGoal goal;

  /// 기록 거리(미터). 빠른 이동 거리를 빼기 전 값.
  final double distanceM;

  /// 움직인 시간. 시간 목표의 남은 시간을 셀 때 쓴다.
  final Duration movingTime;

  /// 속도 검사로 뺀 거리(미터).
  final double excludedM;
  final bool achieved;
  final int bonusXp;

  /// 이 줄에서 받은 코인. 0 이면 코인 줄을 그리지 않는다.
  final int coins;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    if (achieved) {
      // 보너스를 이미 받아 이번 증가분이 0 이어도 달성 보너스 값을 보여 준다.
      final shown = bonusXp > 0 ? bonusXp : goalBonusXp(goal);
      return _XpRow('목표 ${goal.label} 달성', '보너스 +$shown', coins: coins);
    }
    final String message = switch (goal) {
      DistanceGoal(:final meters) when distanceM >= meters =>
        '빠른 이동을 빼면 목표에 못 미쳤어요',
      DistanceGoal(:final meters) =>
        '목표 ${goal.label}까지 ${formatKm(meters - (distanceM - excludedM))}km 남았어요',
      TimeGoal(:final time) =>
        '목표 ${goal.label}까지 ${formatDuration(time > movingTime ? time - movingTime : Duration.zero)} 남았어요',
    };
    return Text(message, style: t.body.copyWith(color: c.inkMuted));
  }
}

/// 경험치 한 줄: 흰 카드, 값은 success 색 titleS 22. 코인이 있으면 값 아래에 한 줄 더한다.
class _XpRow extends StatelessWidget {
  const _XpRow(
    this.label,
    this.xp, {
    this.coins = 0,
    this.valueColor,
    this.leading,
  });
  final String label;
  final String xp;
  final int coins;

  /// 값 글자색. 없으면 success.
  final Color? valueColor;

  /// 이름 앞 그림(새 배지).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Gap.s4),
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: Gap.s3),
          ],
          Expanded(child: Text(label, style: t.body)),
          const SizedBox(width: Gap.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                xp,
                style: t.titleS.copyWith(color: valueColor ?? c.success),
              ),
              if (coins > 0)
                Text(
                  '코인 +$coins',
                  style: t.caption.copyWith(color: c.coin),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
