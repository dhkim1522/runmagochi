import '../domain/growth_rules.dart';

/// 경험치·아바타 이름 저장소.
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

  /// 그 러닝이 지금 받아 둔 달성 보너스(살아 있는 `runGoal` 행). 없으면 0.
  Future<int> runGoalXp(String runId);

  /// 그 러닝의 거리 경험치를 [distanceXp] 로, 달성 보너스(`runGoal`)를 [goalBonusXp] 로
  /// 맞춘다(한 트랜잭션). 거리 행은 만들거나 살려 값을 바꾸고 시각을 갱신한다.
  /// 보너스가 0보다 크면 보너스 행을 만들거나 살려 값을 바꾸고, 0이면 삭제 표시를 한다.
  /// 같은 러닝을 여러 번 불러도 행은 러닝마다 하나씩이다.
  Future<void> setRunXp(
    String runId, {
    required int distanceXp,
    required int goalBonusXp,
  });

  /// 그 러닝의 거리·보너스 행에 삭제 표시를 한다. 없거나 이미 물렀으면 아무 일도 없다.
  Future<void> revokeRunXp(String runId);
}
