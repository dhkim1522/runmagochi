import '../../core/clock.dart';
import '../../core/week.dart';
import '../../run/data/run_repository.dart';
import '../data/growth_repository.dart';
import '../data/notification_scheduler.dart';
import '../domain/growth_rules.dart';
import '../domain/growth_state.dart';
import '../domain/reminder_plan.dart';

/// 완료된 러닝을 경험치·주간 목표 달성으로 옮기고, 화면이 보여 줄 상태를 만든다.
class GrowthService {
  GrowthService(
    this._runs,
    this._growth,
    this._clock, {
    this._scheduler,
    this.rescheduleTimeout = const Duration(seconds: 10),
  });

  final RunRepository _runs;
  final GrowthRepository _growth;
  final Clock _clock;
  final NotificationScheduler? _scheduler;

  /// 스케줄러가 멈춰도 뒤따르는 sync 를 막지 않도록 재예약에 두는 제한 시간.
  final Duration rescheduleTimeout;

  Future<void> _tail = Future.value();

  /// 동시에 불러도 한 번에 하나씩 실행해 같은 보상을 두 번 알리지 않는다.
  Future<GrowthGain> sync() => _serial(_sync);

  /// 저장소에서 지운 러닝의 거리 경험치를 무르고 그 주([runStartedAt] 이 속한 주)를
  /// 다시 판정한다. 레벨이 내려갈 수 있다(결정 0016). sync 와 같은 줄에서 돈다.
  Future<void> runRemoved(String runId, DateTime runStartedAt) =>
      _serial(() => _runChanged(runId, runStartedAt));

  /// 저장소에서 요약을 바꾼(끝부분 잘라내기) 러닝의 거리 경험치를 새 거리로
  /// 다시 매기고 그 주를 양방향으로 다시 판정한다. 시작 시각은 그대로라는 전제다.
  ///
  /// 이 호출이 바꾼 만큼을 돌려준다: 거리 경험치 차이(음수 가능), 주 보너스
  /// 차이(+50·0·−50), 호출 전·후 레벨과 단계. 요약 화면은 처음 받은 gain 에
  /// `GrowthGain.revisedBy` 로 더해 보여 준다. 레벨이 내려갈 수 있다.
  Future<GrowthGain> runRevised(String runId, DateTime runStartedAt) =>
      _serial(() async {
        final week = weekStartOf(runStartedAt);
        final xpBefore = await _growth.totalXp();
        final achievedBefore = await _growth.isWeekAchieved(week);
        await _runChanged(runId, runStartedAt);
        final xpAfter = await _growth.totalXp();
        final achievedAfter = await _growth.isWeekAchieved(week);
        final bonus =
            ((achievedAfter ? 1 : 0) - (achievedBefore ? 1 : 0)) *
            weeklyGoalBonusXp;
        final levelBefore = levelFor(xpBefore).level;
        final levelAfter = levelFor(xpAfter).level;
        return GrowthGain(
          distanceXp: xpAfter - xpBefore - bonus,
          goalBonusXp: bonus,
          levelBefore: levelBefore,
          levelAfter: levelAfter,
          stageBefore: stageForLevel(levelBefore),
          stageAfter: stageForLevel(levelAfter),
        );
      });

  /// 일을 앞선 sync·runRemoved 뒤에 하나씩 돌린다.
  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _tail.then((_) => job());
    // 재예약은 일 뒤, 다음 일 앞에 직렬로 돌되 호출자는 기다리지 않는다.
    _tail = result.then<void>((_) => _reschedule(), onError: (_) {});
    return result;
  }

  /// 러닝 하나가 지워지거나 바뀐 뒤 그 러닝의 거리 경험치와 그 주 달성을 맞춘다.
  /// 러닝이 남아 있으면(바뀐 경우) 새 거리로 경험치를 다시 매기고, 없으면 무른다.
  Future<void> _runChanged(String runId, DateTime runStartedAt) async {
    await _growth.revokeDistanceXp(runId);
    final detail = await _runs.getRun(runId);
    if (detail != null) {
      // 무른 행을 새 값으로 살린다.
      await _growth.addDistanceXp(
        runId,
        distanceXp(detail.run.distanceM, detail.splits),
      );
    }
    await _rejudgeWeek(weekStartOf(runStartedAt));
  }

  /// 그 주 거리로 달성을 양방향으로 다시 정한다. 목표 아래면 달성·보너스를 무른다.
  Future<void> _rejudgeWeek(DateTime week) async {
    if (await _awardWeekIfReached(week) > 0) return;
    if (!await _growth.isWeekAchieved(week)) return;
    final (distanceM, _) = await _runs.weeklyTotal(week);
    if (distanceM < await _growth.weeklyTarget(week)) {
      await _growth.unmarkWeekAchieved(week);
    }
  }

  /// 아직 달성하지 않은 주가 목표에 닿았으면 달성으로 표시하고 받은 보너스를 돌려준다.
  Future<int> _awardWeekIfReached(DateTime week) async {
    if (await _growth.isWeekAchieved(week)) return 0;
    final target = await _growth.weeklyTarget(week);
    final (distanceM, _) = await _runs.weeklyTotal(week);
    if (distanceM < target) return 0;
    await _growth.markWeekAchieved(week, _clock(), weeklyGoalBonusXp);
    return weeklyGoalBonusXp;
  }

  /// 알림을 현재 주 상태로 다시 예약한다. 실패해도 sync 를 깨뜨리지 않는다.
  Future<void> _reschedule() async {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    try {
      final now = _clock();
      final thisWeek = weekStartOf(now);
      final (distanceM, _) = await _runs.weeklyTotal(now);
      final plan = planReminders(
        now: now,
        weekTargetM: await _growth.weeklyTarget(thisWeek),
        weekDistanceM: distanceM,
        weekAchieved: await _growth.isWeekAchieved(thisWeek),
      );
      await scheduler.replaceAll(plan).timeout(rescheduleTimeout);
    } catch (_) {
      // 알림은 부가 기능이다.
    }
  }

  /// 기록과 경험치 사이에 앱이 죽거나 실패해 어긋난 러닝을 고친다. 고친 러닝의
  /// 주만 다시 판정하고 알림(gain)에는 넣지 않는다.
  /// - 지운 러닝: deleteRun 과 runRemoved 사이에 죽으면 경험치가 남는다. 저장소가
  ///   지웠다고 확인한 러닝만 경험치를 무른다.
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
      for (final MapEntry(key: runId, value: startedAt) in deleted.entries) {
        await _runChanged(runId, startedAt);
      }
    }
    final revisedAt = await _runs.completedRunRevisions();
    for (final MapEntry(key: runId, value: at) in revisedAt.entries) {
      final xpUpdatedAt = xpAt[runId];
      final run = live[runId];
      if (xpUpdatedAt == null || run == null || !at.isAfter(xpUpdatedAt)) {
        continue;
      }
      await _runChanged(runId, run.startedAt);
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
    // 러닝이 있는 모든 주와 이번 주를 판정한다 (중간에 끊긴 보너스도 복구).
    final weeks = <DateTime>{
      weekStartOf(_clock()),
      for (final r in runs) weekStartOf(r.startedAt),
    };
    for (final r in runs.reversed) {
      if (known.contains(r.id)) continue;
      final detail = await _runs.getRun(r.id);
      if (detail == null) continue;
      final xp = distanceXp(detail.run.distanceM, detail.splits);
      await _growth.addDistanceXp(r.id, xp);
      distanceXpSum += xp;
    }

    var bonusSum = 0;
    for (final week in weeks) {
      bonusSum += await _awardWeekIfReached(week);
    }

    final levelAfter = levelFor(await _growth.totalXp()).level;
    return GrowthGain(
      distanceXp: distanceXpSum,
      goalBonusXp: bonusSum,
      levelBefore: levelBefore,
      levelAfter: levelAfter,
      stageBefore: stageForLevel(levelBefore),
      stageAfter: stageForLevel(levelAfter),
    );
  }

  Future<GrowthState> load() async {
    final now = _clock();
    final thisWeek = weekStartOf(now);
    final totalXp = await _growth.totalXp();
    final level = levelFor(totalXp);
    final runs = await _runs.listRuns();
    final (weekDistanceM, _) = await _runs.weeklyTotal(now);
    final weekAchieved = await _growth.isWeekAchieved(thisWeek);

    final achieved = (await _growth.achievedWeeks()).map(weekStartOf).toSet();
    var streak = 0;
    var cursor = weekAchieved ? thisWeek : _previousWeek(thisWeek);
    while (achieved.contains(cursor)) {
      streak++;
      cursor = _previousWeek(cursor);
    }

    return GrowthState(
      kind: await _growth.avatarKind(),
      name: await _growth.avatarName(),
      totalXp: totalXp,
      level: level,
      stage: stageForLevel(level.level),
      xpToNextStage: xpToNextStage(totalXp),
      mood: moodFor(runs.isEmpty ? null : runs.first.startedAt, now),
      weekTargetM: await _growth.weeklyTarget(thisWeek),
      weekDistanceM: weekDistanceM,
      weekAchieved: weekAchieved,
      streakWeeks: streak,
      totalDistanceM: runs.fold(0.0, (s, r) => s + r.distanceM),
      runCount: runs.length,
    );
  }

  /// 이번 주 목표를 바꾸고 다시 판정한다.
  Future<GrowthGain> setWeeklyTarget(double targetM) async {
    await _growth.setWeeklyTarget(weekStartOf(_clock()), targetM);
    return sync();
  }

  static DateTime _previousWeek(DateTime weekStart) =>
      DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
}
