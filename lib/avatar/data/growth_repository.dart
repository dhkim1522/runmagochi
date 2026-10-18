import '../domain/growth_rules.dart';

/// 경험치·주간 목표·아바타 이름 저장소.
abstract interface class GrowthRepository {
  /// 행이 없으면 '러니' 로 만든다.
  Future<String> avatarName();

  /// 앞뒤 공백을 빼고 저장한다. 규칙(`validateAvatarName`)에 맞지 않으면 [ArgumentError].
  /// 아바타 행이 없으면 [avatarName] 처럼 만든 뒤 바꾼다.
  Future<void> setAvatarName(String name);

  /// 처음 정해진 종류. 없거나 모르는 값이면 한 번 무작위로 정해 저장한다.
  Future<AvatarKind> avatarKind();
  Future<int> totalXp();
  Future<Set<String>> runIdsWithDistanceXp();

  /// 살아 있는 거리 경험치 행의 러닝 id → 그 행을 마지막으로 바꾼 시각(현지).
  /// 기록을 바꾼 뒤 경험치를 다시 매기지 못한 러닝을 찾는 데 쓴다.
  Future<Map<String, DateTime>> distanceXpUpdatedAts();

  /// 살아 있는 행이 이미 있으면 무시한다. 무른 행이 있으면 [amount] 로 그 행을 살린다.
  Future<void> addDistanceXp(String runId, int amount);

  /// 그 러닝의 거리 경험치 행에 삭제 표시를 한다. 없거나 이미 물렀으면 아무 일도 없다.
  Future<void> revokeDistanceXp(String runId);

  /// 그 주 행, 없으면 이전 주 중 최근 행, 없으면 10000.
  Future<double> weeklyTarget(DateTime weekStart);
  Future<void> setWeeklyTarget(DateTime weekStart, double targetM);
  Future<bool> isWeekAchieved(DateTime weekStart);

  /// 한 트랜잭션으로 처리하고, 이미 달성이면 무시한다.
  /// 전에 무른 보너스 행이 있으면 [bonusXp] 로 그 행을 살린다.
  Future<void> markWeekAchieved(DateTime weekStart, DateTime at, int bonusXp);

  /// 달성 표시를 지우고 그 주 보너스 행에 삭제 표시를 한다(한 트랜잭션).
  /// 목표 값은 남긴다. 달성하지 않은 주면 아무 일도 없다.
  Future<void> unmarkWeekAchieved(DateTime weekStart);

  /// 최신순.
  Future<List<DateTime>> achievedWeeks();
}
