import '../../core/clock.dart';
import '../../run/data/run_repository.dart';
import '../data/badge_repository.dart';
import '../domain/badges.dart';

/// 완료 러닝 기록으로 새 배지를 가려 코인과 함께 준다.
class AchievementService {
  AchievementService(this._runs, this._badges, this._clock);

  final RunRepository _runs;
  final BadgeRepository _badges;
  final Clock _clock;

  /// 지금 기록으로 받을 수 있는 새 배지를 모두 주고 그 id 를 돌려준다(목록 순서).
  /// 지운 러닝은 판정에서 빠지지만 이미 받은 배지·코인은 그대로다.
  /// 동시에 부르지 않는다: `GrowthService.sync` 줄 안에서 부른다.
  ///
  /// [items] 는 호출한 쪽이 읽은 완료 러닝(최신순) 스냅샷이다. 그 사이 끼어든
  /// 러닝은 이번 판정에 넣지 않는다. 배지를 모두 받았으면 상세를 읽지 않는다.
  Future<List<String>> awardNew(List<RunListItem> items) async {
    if (items.isEmpty) return const [];
    final already = {for (final b in await _badges.earned()) b.badgeId};
    if (badgeCatalog.every((b) => already.contains(b.id))) return const [];
    final ids = {for (final i in items) i.id};
    final details = [
      for (final d in await _runs.listRunDetails())
        if (ids.contains(d.run.id)) d,
    ];
    final newIds = earnedBadgeIds(details, already: already);
    if (newIds.isEmpty) return const [];
    final latestRunId = items.first.id;
    final given = <String>[];
    for (final id in newIds) {
      final def = badgeCatalog.firstWhere((b) => b.id == id);
      final done = await _badges.award(
        id,
        runId: latestRunId,
        coins: def.coins,
        at: _clock(),
      );
      if (done) given.add(id);
    }
    return given;
  }
}
