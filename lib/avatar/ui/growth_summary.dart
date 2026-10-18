import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';
import 'avatar_view.dart';
import 'sprite_sheet.dart';
import 'weekly_goal_bar.dart';

/// 러닝 직후 요약 위쪽에 놓는 경험치 획득·레벨업 영역.
class GrowthSummary extends StatefulWidget {
  const GrowthSummary({
    super.key,
    required this.kind,
    required this.gain,
    required this.distanceM,
    this.weekTargetM,
    this.excludedM = 0,
  });

  /// 아바타 종류. 아직 모르면 null 이고 같은 크기의 빈자리를 둔다.
  final AvatarKind? kind;
  final GrowthGain gain;

  /// 방금 달린 거리(미터).
  final double distanceM;

  /// 이번 주 목표(미터). 모르면 null.
  final double? weekTargetM;

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
    final target = widget.weekTargetM;
    final goalLabel = target == null
        ? '이번 주 목표 달성'
        : '이번 주 목표 ${WeeklyGoalBar.targetLabel(target)}km 달성';
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _XpRow('달린 거리 ${formatKm(widget.distanceM)}km', '경험치 +${g.distanceXp}'),
        if (widget.excludedM > 0) ...[
          const SizedBox(height: Gap.s2),
          Text(
            '빠른 이동 ${formatKm(widget.excludedM)}km는 경험치에서 뺐어요',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
        if (g.goalBonusXp > 0) ...[
          const SizedBox(height: Gap.s3),
          _XpRow(goalLabel, '경험치 +${g.goalBonusXp}', merged: true),
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
                : AvatarView(
                    kind: kind,
                    stage: stage,
                    mood: AvatarMood.normal,
                    action: AvatarAction.idle,
                    scale: 6,
                  ),
          );
        },
      ),
    );
  }
}

/// 경험치 한 줄: 흰 카드, 값은 success 색 Jua 22.
class _XpRow extends StatelessWidget {
  const _XpRow(this.label, this.xp, {this.merged = false});
  final String label;
  final String xp;

  /// true 면 라벨과 경험치를 한 문장으로 붙여 보인다.
  final bool merged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final xpStyle = t.titleS.copyWith(color: c.success);
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Gap.s4),
      child: merged
          ? Text.rich(
              TextSpan(
                style: t.body,
                children: [
                  TextSpan(text: '$label · '),
                  TextSpan(text: xp, style: xpStyle),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(child: Text(label, style: t.body)),
                const SizedBox(width: Gap.s2),
                Text(xp, style: xpStyle),
              ],
            ),
    );
  }
}
