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
  Future<GrowthGain> sync() {
    final result = _tail.then((_) => _sync());
    // 재예약은 sync 뒤, 다음 sync 앞에 직렬로 돌되 호출자는 기다리지 않는다.
    _tail = result.then<void>((_) => _reschedule(), onError: (_) {});
    return result;
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

  Future<GrowthGain> _sync() async {
    final xpBefore = await _growth.totalXp();
    final levelBefore = levelFor(xpBefore).level;

    final known = await _growth.runIdsWithDistanceXp();
    final runs = await _runs.listRuns(); // 최신순
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
      if (await _growth.isWeekAchieved(week)) continue;
      final target = await _growth.weeklyTarget(week);
      final (distanceM, _) = await _runs.weeklyTotal(week);
      if (distanceM >= target) {
        await _growth.markWeekAchieved(week, _clock(), weeklyGoalBonusXp);
        bonusSum += weeklyGoalBonusXp;
      }
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
