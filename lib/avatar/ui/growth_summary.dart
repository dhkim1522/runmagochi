import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/domain/badges.dart';
import '../../achievement/ui/badge_image.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
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
    with TickerProviderStateMixin {
  /// 레벨 업 커짐·단계 바뀜.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.celebrate,
  );

  /// 새 배지 튀어 오름.
  late final AnimationController _badge = AnimationController(
    vsync: this,
    duration: Motion.celebrate,
  );
  bool _started = false;

  bool get _animates => widget.gain.leveledUp || widget.gain.stageUp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 처음 한 번 연출을 시작한다. 애니메이션 줄이기면 바로 끝 값(새 단계·제 크기)에 둔다.
    if (!_started) {
      _started = true;
      final reduced = Motion.reduced(context);
      for (final (c, on) in [
        (_controller, _animates),
        (_badge, widget.gain.newBadges.isNotEmpty),
      ]) {
        if (reduced) {
          c.value = 1;
        } else if (on) {
          c.forward();
        }
      }
    }
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
    _badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final g = widget.gain;
    // 행 사이는 간격만 두고 선을 긋지 않는다(시안 c).
    final rows = AppCard(
      padding: const EdgeInsets.all(Gap.s5),
      child: Column(
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
            const SizedBox(height: Gap.s4),
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
              const SizedBox(height: Gap.s4),
              // 배지 코인은 이 줄의 값이라 경험치 값과 같은 크기·굵기로 다른 코인 +N 보다
              // 눈에 띈다(관문 2 비평).
              _XpRow(
                '배지 획득: ${badge.name}',
                '코인 +${badge.coins}',
                valueColor: c.coin,
                leading: _BadgePop(
                  scaleKey: ValueKey('new-badge-pop-${badge.id}'),
                  animation: _badge,
                  child: BadgeImage(
                    badge.id,
                    key: ValueKey('new-badge-${badge.id}'),
                    earned: true,
                  ),
                ),
              ),
            ],
        ],
      ),
    );
    if (!_animates) return rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 마스코트 판: 흰 카드 안에 문구, 그 아래 카드 폭 사각 무대. 무대 위에는 글자를 두지
        // 않는다(무대 하늘 위 초록 글자는 큰 글자만 대비가 맞는다).
        AppCard(
          key: const ValueKey('level-up-card'),
          radius: Radii.xl,
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (g.leveledUp) ...[
                Text(
                  '레벨 업!',
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(color: c.primaryDeep),
                ),
                const SizedBox(height: Gap.s1),
                Text(
                  'Lv.${g.levelBefore} 에서 Lv.${g.levelAfter} 로',
                  textAlign: TextAlign.center,
                  style: _weight(t.body, FontWeight.w600),
                ),
              ],
              if (g.stageUp) ...[
                const SizedBox(height: Gap.s2),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.stageSky,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gap.s4,
                        vertical: 6,
                      ),
                      child: Text(
                        '새 외형 단계!',
                        textAlign: TextAlign.center,
                        style: _weight(
                          t.label.copyWith(color: c.stageInk),
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Gap.s3),
              LayoutBuilder(
                builder: (context, box) {
                  // 시안은 8배. 카드가 좁으면 폭에 들어가는 가장 큰 정수 배율로 줄인다.
                  final scale =
                      PetStage.largestScale(
                        max: _maxScale,
                        min: 1,
                        fits: (s) => spriteFramePx * s <= box.maxWidth,
                      ) ??
                      1;
                  return PetStage(
                    scale: scale,
                    radius: Stage.radiusInCard,
                    height: _stageHeight(scale),
                    pet: _avatar(scale),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.s3),
        rows,
      ],
    );
  }

  /// 마스코트 판 펫 배율(시안 8배).
  static const int _maxScale = 8;

  /// 레벨 업 때 커지는 정도. 발끝을 축으로 커져도 무대 안에 들어가게 0.15 로 둔다.
  static const double _pop = 0.15;

  /// [scale] 배 펫이 땅 위에 서는 무대 높이.
  static double _stageHeight(int scale) =>
      (spriteFramePx * scale +
              Stage.groundHeight -
              Stage.footSink -
              spriteFootGapRows * scale)
          .toDouble();

  Widget _avatar(int petScale) {
    final g = widget.gain;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // 커졌다 돌아온다: 1 → 1.15 → 1. 발끝을 축으로 커진다.
        final scale = g.leveledUp ? 1 + _pop * math.sin(math.pi * t) : 1.0;
        // 절반이 지나면 이전 단계에서 새 단계로 바뀐다.
        final stage = g.stageUp && t < 0.5 ? g.stageBefore : g.stageAfter;
        final kind = widget.kind;
        return Transform.scale(
          key: const ValueKey('level-up-scale'),
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: kind == null
              ? AvatarSlot(scale: petScale)
              : Consumer(
                  builder: (context, ref, _) {
                    final equipped = ref.watch(equippedProvider).value;
                    return AvatarView(
                      kind: kind,
                      stage: stage,
                      mood: AvatarMood.normal,
                      action: AvatarAction.idle,
                      scale: petScale,
                      hatItemId: equipped?.hatItemId,
                      accessoryItemId: equipped?.accessoryItemId,
                    );
                  },
                ),
        );
      },
    );
  }
}

/// 새 배지 그림 튀어 오름: [animation] 0 → 1 동안 [_from] 크기에서 [Motion.pop] 으로
/// 살짝 넘쳤다가 제 크기. 자리(레이아웃)는 그대로이고 그림만 커진다.
class _BadgePop extends StatelessWidget {
  const _BadgePop({
    required this.scaleKey,
    required this.animation,
    required this.child,
  });

  static const double _from = 0.4;

  /// 크기를 바꾸는 [Transform] 의 키(테스트가 읽는다).
  final Key scaleKey;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Transform.scale(
      key: scaleKey,
      scale: _from + (1 - _from) * Motion.pop.transform(animation.value),
      child: child,
    ),
  );
}

/// [style] 의 굵기를 [w] 로 바꾼다. 가변 글꼴이라 wght 축도 함께 바꾼다.
TextStyle _weight(TextStyle style, FontWeight w) => style.copyWith(
  fontWeight: w,
  fontVariations: [FontVariation('wght', w.value.toDouble())],
);

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

/// 경험치 한 줄(판 없음, 행 카드 안): 이름 17/600 왼쪽, 값 17/800 success 오른쪽.
/// 코인이 있으면 값 아래에 코인 +N 14/600 한 줄을 더한다.
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
    return Row(
      children: [
        if (leading case final leading?) ...[
          leading,
          const SizedBox(width: Gap.s3),
        ],
        Expanded(child: Text(label, style: _weight(t.body, FontWeight.w600))),
        const SizedBox(width: Gap.s3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(xp, style: t.heading.copyWith(color: valueColor ?? c.success)),
            if (coins > 0)
              Text('코인 +$coins', style: t.label.copyWith(color: c.coin)),
          ],
        ),
      ],
    );
  }
}
