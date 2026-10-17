import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
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
}
