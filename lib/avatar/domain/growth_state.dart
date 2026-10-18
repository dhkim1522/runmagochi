import 'growth_rules.dart';

/// 홈·요약·아바타 화면이 보여 주는 성장 상태.
class GrowthState {
  const GrowthState({
    required this.kind,
    required this.name,
    required this.totalXp,
    required this.level,
    required this.stage,
    required this.xpToNextStage,
    required this.mood,
    required this.weekTargetM,
    required this.weekDistanceM,
    required this.weekAchieved,
    required this.streakWeeks,
    required this.totalDistanceM,
    required this.runCount,
  });

  final AvatarKind kind;
  final String name;
  final int totalXp;
  final LevelProgress level;
  final int stage;

  /// 다음 외형 단계까지 남은 경험치. 최고 단계면 null.
  final int? xpToNextStage;
  final AvatarMood mood;
  final double weekTargetM;
  final double weekDistanceM;
  final bool weekAchieved;
  final int streakWeeks;
  final double totalDistanceM;
  final int runCount;
}

/// 이번 sync 에서 새로 받은 것.
class GrowthGain {
  const GrowthGain({
    required this.distanceXp,
    required this.goalBonusXp,
    required this.levelBefore,
    required this.levelAfter,
    required this.stageBefore,
    required this.stageAfter,
  });

  final int distanceXp;
  final int goalBonusXp;
  final int levelBefore;
  final int levelAfter;
  final int stageBefore;
  final int stageAfter;

  bool get leveledUp => levelAfter > levelBefore;
  bool get stageUp => stageAfter > stageBefore;
  bool get isEmpty => distanceXp == 0 && goalBonusXp == 0;

  /// 이 gain 을 받은 러닝을 다시 계산한 변화 [delta](`GrowthService.runRevised`)
  /// 를 더한 값. 경험치는 더하고, 레벨·단계는 이 gain 의 시작에서 [delta] 뒤
  /// 지금 값으로 잇는다. 여러 번 고쳐도 이어서 부르면 된다.
  GrowthGain revisedBy(GrowthGain delta) => GrowthGain(
    distanceXp: distanceXp + delta.distanceXp,
    goalBonusXp: goalBonusXp + delta.goalBonusXp,
    levelBefore: levelBefore,
    levelAfter: delta.levelAfter,
    stageBefore: stageBefore,
    stageAfter: delta.stageAfter,
  );
}
