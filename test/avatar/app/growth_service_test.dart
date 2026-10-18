import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/domain/reminder_plan.dart';
import 'package:runmagochi/core/week.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

class FakeRunRepository implements RunRepository {
  final List<RunDetail> runs = [];

  void add(String id, DateTime startedAt, double distanceM) {
    runs.add(
      RunDetail(
        run: RunListItem(
          id: id,
          name: id,
          startedAt: startedAt,
          distanceM: distanceM,
          movingTime: const Duration(minutes: 30),
          avgPaceSecPerKm: 360,
        ),
        calories: 0,
        route: const [],
        splits: const [],
      ),
    );
  }

  @override
  Future<List<RunListItem>> listRuns() async {
    final l = runs.map((r) => r.run).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return l;
  }

  @override
  Future<RunDetail?> getRun(String id) async {
    for (final r in runs) {
      if (r.run.id == id) return r;
    }
    return null;
  }

  @override
  Future<(double, int)> weeklyTotal(DateTime now) async {
    final ws = weekStartOf(now);
    final inWeek = runs.where((r) => weekStartOf(r.run.startedAt) == ws);
    return (inWeek.fold(0.0, (s, r) => s + r.run.distanceM), inWeek.length);
  }

  @override
  Future<String> createActiveRun(DateTime startedAt) =>
      throw UnimplementedError();
  @override
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  }) => throw UnimplementedError();
  @override
  Future<ActiveRun?> findActiveRun() => throw UnimplementedError();
  @override
  Future<void> completeRun(String runId, RunSummary summary) =>
      throw UnimplementedError();

  /// 지운 러닝의 시작 시각.
  final Map<String, DateTime> deleted = {};

  @override
  Future<void> deleteRun(String id) async {
    final detail = await getRun(id);
    if (detail != null) deleted[id] = detail.run.startedAt;
    runs.removeWhere((r) => r.run.id == id);
  }

  /// 잘라내기처럼 거리만 바꾼다(시작 시각은 그대로).
  void revise(String id, double distanceM) {
    final i = runs.indexWhere((r) => r.run.id == id);
    final old = runs[i].run;
    runs.removeAt(i);
    add(id, old.startedAt, distanceM);
  }

  @override
  Future<void> replaceCompletedRun(String runId, RunSummary summary) =>
      throw UnimplementedError();

  @override
  Future<Map<String, DateTime>> deletedRunStarts(Set<String> ids) async => {
    for (final id in ids)
      if (deleted.containsKey(id)) id: deleted[id]!,
  };
}

class FakeScheduler implements NotificationScheduler {
  final List<List<PlannedReminder>> calls = [];
  bool fail = false;
  Completer<void>? hold;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    calls.add(reminders);
    await hold?.future;
    if (fail) throw StateError('예약 실패');
  }
}

void main() {
  // 2026-10-17 은 토요일. 이번 주 월요일은 10-12.
  final now = DateTime(2026, 10, 17, 12);
  late AppDatabase db;
  late DriftGrowthRepository growth;
  late FakeRunRepository runs;
  late GrowthService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    growth = DriftGrowthRepository(db);
    runs = FakeRunRepository();
    service = GrowthService(runs, growth, () => now);
  });
  tearDown(() => db.close());

  test('load 는 저장된 종류를 상태에 채운다', () async {
    final kind = await growth.avatarKind();
    expect((await service.load()).kind, kind);
  });

  test('5.02km 러닝 1건은 경험치 50, 레벨 1에서 2', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 5020);
    final gain = await service.sync();
    expect(gain.distanceXp, 50);
    expect(gain.levelBefore, 1);
    expect(gain.levelAfter, 2);
    expect(gain.leveledUp, isTrue);
    expect(gain.isEmpty, isFalse);
  });

  test('sync 두 번째 호출은 비어 있고 경험치가 그대로다', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 5020);
    await service.sync();
    final xp = await growth.totalXp();
    final gain = await service.sync();
    expect(gain.isEmpty, isTrue);
    expect(await growth.totalXp(), xp);
  });

  test('목표 10km, 6km 뒤 5km 를 달리면 두 번째 sync 에서 보너스 50', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 6000);
    final g1 = await service.sync();
    expect(g1.goalBonusXp, 0);
    runs.add('b', DateTime(2026, 10, 15, 7), 5000);
    final g2 = await service.sync();
    expect(g2.goalBonusXp, 50);
    expect(g2.distanceXp, 50);
    expect((await service.load()).weekAchieved, isTrue);
  });

  test('일요일 23:50 시작 러닝은 그 주에 들어간다', () async {
    final sunNow = DateTime(2026, 10, 18, 23, 55);
    service = GrowthService(runs, growth, () => sunNow);
    runs.add('a', DateTime(2026, 10, 12, 7), 6000);
    runs.add('b', DateTime(2026, 10, 18, 23, 50), 5000);
    final gain = await service.sync();
    expect(gain.goalBonusXp, 50);
  });

  test('달성 뒤 목표를 20km 로 올려도 달성 유지, 보너스 그대로', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 11000);
    await service.sync();
    final xp = await growth.totalXp();
    final gain = await service.setWeeklyTarget(20000);
    expect(gain.goalBonusXp, 0);
    final state = await service.load();
    expect(state.weekAchieved, isTrue);
    expect(state.weekTargetM, 20000);
    expect(await growth.totalXp(), xp);
  });

  test('이번 주 6km 에서 목표를 5km 로 내리면 보너스 50', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 6000);
    await service.sync();
    final gain = await service.setWeeklyTarget(5000);
    expect(gain.goalBonusXp, 50);
    expect(gain.distanceXp, 0);
  });

  test('연속 달성: 이번 주·지난주·3주 전 달성이면 2', () async {
    for (final w in [0, 1, 3]) {
      await growth.markWeekAchieved(DateTime(2026, 10, 12 - 7 * w), now, 0);
    }
    expect((await service.load()).streakWeeks, 2);
  });

  test('연속 달성: 이번 주 미달성, 지난주·2주 전 달성이면 2', () async {
    for (final w in [1, 2]) {
      await growth.markWeekAchieved(DateTime(2026, 10, 12 - 7 * w), now, 0);
    }
    final state = await service.load();
    expect(state.weekAchieved, isFalse);
    expect(state.streakWeeks, 2);
  });

  test('마지막 러닝 4일 전이면 졸린 표정, 러닝이 없으면 기본', () async {
    expect((await service.load()).mood, AvatarMood.normal);
    runs.add('a', DateTime(2026, 10, 13, 7), 1000);
    final state = await service.load();
    expect(state.mood, AvatarMood.sleepy);
    expect(state.runCount, 1);
    expect(state.totalDistanceM, 1000);
    expect(state.weekDistanceM, 1000);
    expect(state.weekTargetM, 10000);
  });

  test('동시에 sync 해도 경험치와 보너스는 한 번만 알린다', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 11000);
    final gains = await Future.wait([service.sync(), service.sync()]);
    expect(gains.fold(0, (s, g) => s + g.distanceXp), 110);
    expect(gains.fold(0, (s, g) => s + g.goalBonusXp), 50);
    expect(await growth.totalXp(), 160);
  });

  test('경험치는 있지만 보너스가 빠진 지난 주도 sync 가 보너스를 준다', () async {
    runs.add('a', DateTime(2026, 10, 6, 7), 11000);
    await growth.addDistanceXp('a', 110);
    final gain = await service.sync();
    expect(gain.distanceXp, 0);
    expect(gain.goalBonusXp, 50);
  });

  group('알림 재예약', () {
    test('sync 뒤 replaceAll 이 한 번 불린다', () async {
      final scheduler = FakeScheduler();
      service = GrowthService(runs, growth, () => now, scheduler: scheduler);
      runs.add('a', DateTime(2026, 10, 13, 7), 6200);
      await service.sync();
      await pumpEventQueue();
      expect(scheduler.calls.length, 1);
      // 토요일 낮이라 이번 주 금요일은 지났다: 다음 3주만.
      expect(scheduler.calls.single.length, 3);
    });

    test('스케줄러가 실패해도 sync 결과는 그대로다', () async {
      final scheduler = FakeScheduler()..fail = true;
      service = GrowthService(runs, growth, () => now, scheduler: scheduler);
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      final gain = await service.sync();
      expect(gain.distanceXp, 50);
      await pumpEventQueue();
      expect(scheduler.calls.length, 1);
    });

    test('replaceAll 이 끝나지 않아도 sync 는 gain 을 돌려준다', () async {
      final scheduler = FakeScheduler()..hold = Completer<void>();
      service = GrowthService(runs, growth, () => now, scheduler: scheduler);
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      final gain = await service.sync().timeout(const Duration(seconds: 2));
      expect(gain.distanceXp, 50);
      await pumpEventQueue();
      expect(scheduler.calls.length, 1);
      scheduler.hold!.complete();
    });

    test('replaceAll 이 멈춰도 제한 시간 뒤 다음 sync 가 끝난다', () async {
      final scheduler = FakeScheduler()..hold = Completer<void>();
      service = GrowthService(
        runs,
        growth,
        () => now,
        scheduler: scheduler,
        rescheduleTimeout: const Duration(milliseconds: 50),
      );
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      await service.sync();
      final second = await service.sync().timeout(const Duration(seconds: 2));
      expect(second.distanceXp, 0);
      await pumpEventQueue();
      expect(scheduler.calls.length, greaterThanOrEqualTo(1));
      scheduler.hold!.complete();
    });
  });

  group('러닝 삭제 (runRemoved)', () {
    // 실제 흐름처럼 저장소에서 먼저 지운 뒤 runRemoved 를 부른다.
    Future<void> remove(String id) async {
      final startedAt = (await runs.getRun(id))!.run.startedAt;
      await runs.deleteRun(id);
      await service.runRemoved(id, startedAt);
    }

    test('목표 아래로 내려가면 그 러닝 경험치와 주 보너스를 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 60 + 50 + 50);

      await remove('b');

      expect(await growth.totalXp(), 60);
      final state = await service.load();
      expect(state.weekAchieved, isFalse);
      expect(state.weekDistanceM, 6000);
      expect(state.runCount, 1);
    });

    test('다시 sync 해도 무른 경험치와 보너스를 다시 주지 않는다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      await remove('b');
      final gain = await service.sync();
      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 60);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isFalse);
    });

    test('지운 뒤에도 목표 이상이면 주 보너스는 남는다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      runs.add('b', DateTime(2026, 10, 15, 7), 2000);
      await service.sync();
      expect(await growth.totalXp(), 110 + 20 + 50);

      await remove('b');

      expect(await growth.totalXp(), 110 + 50);
      expect((await service.load()).weekAchieved, isTrue);
    });

    test('레벨이 내려갈 수 있다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      await service.sync();
      expect((await service.load()).level.level, 3); // 160
      await remove('a');
      final state = await service.load();
      expect(state.totalXp, 0);
      expect(state.level.level, 1);
    });

    test('지난 주 러닝을 지우면 그 주를 다시 판정하고 이번 주는 그대로다', () async {
      runs.add('old', DateTime(2026, 10, 6, 7), 11000);
      runs.add('now', DateTime(2026, 10, 13, 7), 10000);
      await service.sync();
      expect((await service.load()).streakWeeks, 2);

      await remove('old');

      expect(await growth.isWeekAchieved(DateTime(2026, 10, 5)), isFalse);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isTrue);
      expect(await growth.totalXp(), 100 + 50);
      expect((await service.load()).streakWeeks, 1);
    });

    test('그 주가 목표 이상인데 달성 표시가 빠져 있으면 달성으로 고친다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      runs.add('b', DateTime(2026, 10, 15, 7), 1000);
      await growth.addDistanceXp('a', 110);
      await growth.addDistanceXp('b', 10);

      await remove('b');

      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isTrue);
      expect(await growth.totalXp(), 110 + 50);
    });

    test('지운 러닝을 다시 무르면 아무 일도 없다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      await remove('b');
      await service.runRemoved('b', DateTime(2026, 10, 15, 7));
      expect(await growth.totalXp(), 60);
    });

    test('sync 와 동시에 불러도 한 번에 하나씩 처리한다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      final startedAt = (await runs.getRun('b'))!.run.startedAt;
      await runs.deleteRun('b');
      await Future.wait([
        service.sync(),
        service.runRemoved('b', startedAt),
        service.sync(),
      ]);
      expect(await growth.totalXp(), 60);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isFalse);
    });

    test('지운 뒤 알림을 다시 예약한다', () async {
      final scheduler = FakeScheduler();
      service = GrowthService(runs, growth, () => now, scheduler: scheduler);
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      await service.sync();
      await pumpEventQueue();
      expect(scheduler.calls.length, 1);
      await remove('a');
      await pumpEventQueue();
      expect(scheduler.calls.length, 2);
    });
  });

  group('지운 러닝 자가 복구 (sync)', () {
    test('runRemoved 전에 앱이 죽어도 다음 sync 가 경험치와 주 보너스를 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 60 + 50 + 50);

      await runs.deleteRun('b'); // runRemoved 를 부르기 전에 죽었다.
      final gain = await service.sync();

      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 60);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isFalse);
      expect(await growth.runIdsWithDistanceXp(), {'a'});
    });

    test('지난 주 러닝이면 그 주만 다시 판정한다', () async {
      runs.add('old', DateTime(2026, 10, 6, 7), 11000);
      runs.add('now', DateTime(2026, 10, 13, 7), 10000);
      await service.sync();
      await runs.deleteRun('old');
      await service.sync();
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 5)), isFalse);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isTrue);
      expect(await growth.totalXp(), 100 + 50);
    });

    test('저장소가 지웠다고 확인하지 않은 경험치는 그대로 둔다', () async {
      await growth.addDistanceXp('unknown', 30);
      await service.sync();
      expect(await growth.totalXp(), 30);
    });
  });

  group('러닝 잘라내기 (runRevised)', () {
    Future<GrowthGain> revise(String id, double distanceM) async {
      final startedAt = (await runs.getRun(id))!.run.startedAt;
      runs.revise(id, distanceM);
      return service.runRevised(id, startedAt);
    }

    test('목표 아래로 내려가면 경험치가 새 거리 값이 되고 주 보너스를 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 160); // 레벨 3

      final delta = await revise('b', 3000);

      expect(delta.distanceXp, -20);
      expect(delta.goalBonusXp, -50);
      expect(delta.levelBefore, 3);
      expect(delta.levelAfter, 2);
      expect(delta.stageBefore, stageForLevel(3));
      expect(delta.stageAfter, stageForLevel(2));
      expect(await growth.totalXp(), 90);
      final state = await service.load();
      expect(state.weekAchieved, isFalse);
      expect(state.level.level, 2);
      expect(state.weekDistanceM, 9000);
    });

    test('목표에 닿으면 주 보너스를 준다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 3000);
      await service.sync();

      final delta = await revise('b', 5000);

      expect(delta.distanceXp, 20);
      expect(delta.goalBonusXp, 50);
      expect(await growth.totalXp(), 160);
      expect(await growth.isWeekAchieved(DateTime(2026, 10, 12)), isTrue);
    });

    test('목표 이상이 남으면 보너스는 그대로이고 거리 경험치만 준다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      await service.sync();
      final delta = await revise('a', 10500);
      expect(delta.distanceXp, -5);
      expect(delta.goalBonusXp, 0);
      expect(await growth.totalXp(), 105 + 50);
    });

    test('다시 sync 해도 바뀐 경험치를 또 주지 않는다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      await service.sync();
      await revise('a', 5000);
      final gain = await service.sync();
      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 50);
    });

    test('sync 와 동시에 불러도 한 번에 하나씩 처리한다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      final startedAt = (await runs.getRun('b'))!.run.startedAt;
      runs.revise('b', 3000);
      final results = await Future.wait([
        service.sync(),
        service.runRevised('b', startedAt),
        service.sync(),
      ]);
      final delta = results[1];
      expect(delta.distanceXp, -20);
      expect(delta.goalBonusXp, -50);
      expect(await growth.totalXp(), 90);
    });
  });
}
