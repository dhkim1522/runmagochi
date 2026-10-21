/// 받은 배지 한 건.
class EarnedBadge {
  const EarnedBadge({
    required this.badgeId,
    required this.earnedAt,
    this.runId,
  });

  final String badgeId;
  final DateTime earnedAt;

  /// 조건을 채운 러닝. 모르면 null.
  final String? runId;
}

abstract interface class BadgeRepository {
  /// 받은 배지(받은 시각 순).
  Future<List<EarnedBadge>> earned();

  /// 배지 행과 코인 행을 한 트랜잭션으로 쓴다. 이미 받은 배지면 아무것도 쓰지 않는다.
  /// 새로 줬으면 true.
  Future<bool> award(
    String badgeId, {
    String? runId,
    required int coins,
    required DateTime at,
  });
}
