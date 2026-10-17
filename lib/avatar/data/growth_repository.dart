import '../domain/growth_rules.dart';

/// 경험치·주간 목표·아바타 이름 저장소.
abstract interface class GrowthRepository {
  /// 행이 없으면 '러니' 로 만든다.
  Future<String> avatarName();

  /// 처음 정해진 종류. 없거나 모르는 값이면 한 번 무작위로 정해 저장한다.
  Future<AvatarKind> avatarKind();
  Future<int> totalXp();
  Future<Set<String>> runIdsWithDistanceXp();

  /// 이미 있으면 무시한다.
  Future<void> addDistanceXp(String runId, int amount);

  /// 그 주 행, 없으면 이전 주 중 최근 행, 없으면 10000.
  Future<double> weeklyTarget(DateTime weekStart);
  Future<void> setWeeklyTarget(DateTime weekStart, double targetM);
  Future<bool> isWeekAchieved(DateTime weekStart);

  /// 한 트랜잭션으로 처리하고, 이미 달성이면 무시한다.
  Future<void> markWeekAchieved(DateTime weekStart, DateTime at, int bonusXp);

  /// 최신순.
  Future<List<DateTime>> achievedWeeks();
}
