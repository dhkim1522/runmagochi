import '../../core/clock.dart';
import '../../run/data/run_repository.dart';
import '../data/growth_repository.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';

/// 완료된 러닝을 경험치로 옮기고, 화면이 보여 줄 상태를 만든다.
class GrowthService {
  GrowthService(this._runs, this._growth, this._clock);

  final RunRepository _runs;
  final GrowthRepository _growth;
  final Clock _clock;

  Future<void> _tail = Future.value();

  /// 동시에 불러도 한 번에 하나씩 실행해 같은 보상을 두 번 알리지 않는다.
  Future<GrowthGain> sync() => _serial(_sync);

  /// 저장소에서 지운 러닝의 거리 경험치를 무른다. 레벨이 내려갈 수 있다(결정 0016).
  /// sync 와 같은 줄에서 돈다.
  Future<void> runRemoved(String runId, DateTime runStartedAt) =>
      _serial(() => _runChanged(runId));

  /// 저장소에서 요약을 바꾼(끝부분 잘라내기) 러닝의 거리 경험치를 새 거리로
  /// 다시 매긴다. 시작 시각은 그대로라는 전제다.
  ///
  /// 이 호출이 바꾼 만큼을 돌려준다: 거리 경험치 차이(음수 가능), 호출 전·후
  /// 레벨과 단계. 요약 화면은 처음 받은 gain 에
  /// `GrowthGain.revisedBy` 로 더해 보여 준다. 레벨이 내려갈 수 있다.
  Future<GrowthGain> runRevised(String runId, DateTime runStartedAt) =>
      _serial(() async {
        final xpBefore = await _growth.totalXp();
        await _runChanged(runId);
        final xpAfter = await _growth.totalXp();
        final levelBefore = levelFor(xpBefore).level;
        final levelAfter = levelFor(xpAfter).level;
        return GrowthGain(
          distanceXp: xpAfter - xpBefore,
          goalBonusXp: 0,
          levelBefore: levelBefore,
          levelAfter: levelAfter,
          stageBefore: stageForLevel(levelBefore),
          stageAfter: stageForLevel(levelAfter),
        );
      });

  /// [job] 을 sync·runRemoved·runRevised 와 같은 줄에서 돌린다. 도는 동안 성장
  /// 계산이 끼어들지 않는다. 백업 가져오기처럼 DB 를 통째로 바꿀 때 쓴다.
  Future<T> exclusive<T>(Future<T> Function() job) => _serial(job);

  /// 일을 앞선 sync·runRemoved 뒤에 하나씩 돌린다.
  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// 러닝 하나가 지워지거나 바뀐 뒤 그 러닝의 거리 경험치를 맞춘다.
  /// 러닝이 남아 있으면(바뀐 경우) 새 거리로 경험치를 다시 매기고, 없으면 무른다.
  Future<void> _runChanged(String runId) async {
    await _growth.revokeDistanceXp(runId);
    final detail = await _runs.getRun(runId);
    if (detail != null) {
      // 무른 행을 새 값으로 살린다.
      await _growth.addDistanceXp(
        runId,
        distanceXp(detail.run.distanceM, detail.splits),
      );
    }
  }

  /// 기록과 경험치 사이에 앱이 죽거나 실패해 어긋난 러닝을 고친다. 고친 것은
  /// 알림(gain)에 넣지 않는다.
  /// - 지운 러닝: deleteRun 과 runRemoved 사이에 죽으면 경험치가 남는다. 저장소가
  ///   지웠다고 확인한 러닝만 경험치를 무른다.
  /// - 없는 러닝: 저장소에 행이 아예 없는(진행 중·완료·삭제 어디에도 없는) 러닝의
  ///   경험치도 무른다. 백업 가져오기처럼 DB 가 바뀌어 남은 경험치다. 시작 시각을
  ///   몰라 따로 하는 일은 없다.
  /// - 바꾼 러닝: replaceCompletedRun 뒤 runRevised 가 실패하면 경험치가 예전
  ///   거리 값으로 남는다. 기록을 바꾼 시각이 경험치 행을 바꾼 시각보다 늦으면
  ///   새 거리로 다시 매긴다. 다시 매기면 경험치 행 시각이 지금으로 바뀌어 한 번만 한다.
  Future<void> _healRuns(List<RunListItem> liveRuns) async {
    final xpAt = await _growth.distanceXpUpdatedAts();
    if (xpAt.isEmpty) return;
    final live = {for (final r in liveRuns) r.id: r};
    final orphans = xpAt.keys.where((id) => !live.containsKey(id)).toSet();
    if (orphans.isNotEmpty) {
      final deleted = await _runs.deletedRunStarts(orphans);
      for (final runId in deleted.keys) {
        await _runChanged(runId);
      }
      final existing = await _runs.existingRunIds(orphans);
      for (final runId in orphans.difference(existing)) {
        await _growth.revokeDistanceXp(runId);
      }
    }
    final revisedAt = await _runs.completedRunRevisions();
    for (final MapEntry(key: runId, value: at) in revisedAt.entries) {
      final xpUpdatedAt = xpAt[runId];
      final run = live[runId];
      if (xpUpdatedAt == null || run == null || !at.isAfter(xpUpdatedAt)) {
        continue;
      }
      await _runChanged(runId);
    }
  }

  Future<GrowthGain> _sync() async {
    final runs = await _runs.listRuns(); // 최신순
    // 복구로 무른 경험치는 이번 gain 의 시작 레벨에 넣지 않는다.
    await _healRuns(runs);
    final xpBefore = await _growth.totalXp();
    final levelBefore = levelFor(xpBefore).level;

    final known = await _growth.runIdsWithDistanceXp();
    var distanceXpSum = 0;
    for (final r in runs.reversed) {
      if (known.contains(r.id)) continue;
      final detail = await _runs.getRun(r.id);
      if (detail == null) continue;
      final xp = distanceXp(detail.run.distanceM, detail.splits);
      await _growth.addDistanceXp(r.id, xp);
      distanceXpSum += xp;
    }

    final levelAfter = levelFor(await _growth.totalXp()).level;
    return GrowthGain(
      distanceXp: distanceXpSum,
      goalBonusXp: 0,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      stageBefore: stageForLevel(levelBefore),
      stageAfter: stageForLevel(levelAfter),
    );
  }

  Future<GrowthState> load() async {
    final now = _clock();
    final totalXp = await _growth.totalXp();
    final level = levelFor(totalXp);
    final runs = await _runs.listRuns();

    return GrowthState(
      kind: await _growth.avatarKind(),
      name: await _growth.avatarName(),
      totalXp: totalXp,
      level: level,
      stage: stageForLevel(level.level),
      xpToNextStage: xpToNextStage(totalXp),
      mood: moodFor(runs.isEmpty ? null : runs.first.startedAt, now),
      totalDistanceM: runs.fold(0.0, (s, r) => s + r.distanceM),
      runCount: runs.length,
    );
  }
}
