import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
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
  Future<double?> lastGoalM() async => null;

  @override
  Future<String> createActiveRun(DateTime startedAt, {required double goalM}) =>
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
  /// [at] 은 저장소가 바꾼 시각(updatedAt). 없으면 아주 예전으로 둔다.
  void revise(String id, double distanceM, {DateTime? at}) {
    final i = runs.indexWhere((r) => r.run.id == id);
    final old = runs[i].run;
    runs.removeAt(i);
    add(id, old.startedAt, distanceM);
    if (at != null) revisedAt[id] = at;
  }

  final Map<String, DateTime> revisedAt = {};

  @override
  Future<Map<String, DateTime>> completedRunRevisions() async => {
    for (final r in runs) r.run.id: revisedAt[r.run.id] ?? DateTime(2000),
  };

  @override
  Future<void> replaceCompletedRun(String runId, RunSummary summary) =>
      throw UnimplementedError();

  @override
  Future<Map<String, DateTime>> deletedRunStarts(Set<String> ids) async => {
    for (final id in ids)
      if (deleted.containsKey(id)) id: deleted[id]!,
  };

  /// 목록에 없지만 저장소에 행이 있는 러닝(진행 중 등).
  final Set<String> otherIds = {};

  @override
  Future<Set<String>> existingRunIds(Set<String> ids) async => {
    for (final id in ids)
      if (otherIds.contains(id) ||
          deleted.containsKey(id) ||
          runs.any((r) => r.run.id == id))
        id,
  };
}

void main() {
  // 2026-10-17 은 토요일.
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
    expect(gain.goalBonusXp, 0);
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

  test('이번 주 거리가 얼마든 sync 는 보너스를 주지 않는다', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 6000);
    runs.add('b', DateTime(2026, 10, 15, 7), 5000);
    final gain = await service.sync();
    expect(gain.distanceXp, 110);
    expect(gain.goalBonusXp, 0);
    expect(await growth.totalXp(), 110);
  });

  test('이전 버전이 준 주간 보너스 행도 총 경험치에 들어간다', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 6000);
    await service.sync();
    final at = DateTime.utc(2026, 10, 14);
    await db
        .into(db.xpTxns)
        .insert(
          XpTxnsCompanion.insert(
            id: 'old-bonus',
            amount: 50,
            reason: 'weeklyGoal',
            weekStart: const Value('2026-10-12'),
            createdAt: at,
            updatedAt: at,
          ),
        );
    expect(await growth.totalXp(), 60 + 50);
    expect((await service.load()).totalXp, 110);
    // 이후 sync·삭제도 그 행을 건드리지 않는다.
    await service.sync();
    await runs.deleteRun('a');
    await service.runRemoved('a', DateTime(2026, 10, 13, 7));
    expect(await growth.totalXp(), 50);
  });

  test('마지막 러닝 4일 전이면 졸린 표정, 러닝이 없으면 기본', () async {
    expect((await service.load()).mood, AvatarMood.normal);
    runs.add('a', DateTime(2026, 10, 13, 7), 1000);
    final state = await service.load();
    expect(state.mood, AvatarMood.sleepy);
    expect(state.runCount, 1);
    expect(state.totalDistanceM, 1000);
  });

  test('동시에 sync 해도 경험치는 한 번만 알린다', () async {
    runs.add('a', DateTime(2026, 10, 13, 7), 11000);
    final gains = await Future.wait([service.sync(), service.sync()]);
    expect(gains.fold(0, (s, g) => s + g.distanceXp), 110);
    expect(await growth.totalXp(), 110);
  });

  group('러닝 삭제 (runRemoved)', () {
    // 실제 흐름처럼 저장소에서 먼저 지운 뒤 runRemoved 를 부른다.
    Future<void> remove(String id) async {
      final startedAt = (await runs.getRun(id))!.run.startedAt;
      await runs.deleteRun(id);
      await service.runRemoved(id, startedAt);
    }

    test('그 러닝의 경험치를 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 60 + 50);

      await remove('b');

      expect(await growth.totalXp(), 60);
      expect((await service.load()).runCount, 1);
    });

    test('다시 sync 해도 무른 경험치를 다시 주지 않는다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      await remove('b');
      final gain = await service.sync();
      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 60);
    });

    test('레벨이 내려갈 수 있다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 16000);
      await service.sync();
      expect((await service.load()).level.level, 3); // 160
      await remove('a');
      final state = await service.load();
      expect(state.totalXp, 0);
      expect(state.level.level, 1);
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
    });
  });

  group('지운 러닝 자가 복구 (sync)', () {
    test('runRemoved 전에 앱이 죽어도 다음 sync 가 경험치를 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 60 + 50);

      await runs.deleteRun('b'); // runRemoved 를 부르기 전에 죽었다.
      final gain = await service.sync();

      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 60);
      expect(await growth.runIdsWithDistanceXp(), {'a'});
    });

    test('저장소가 지웠다고 확인하지 않은 경험치는 그대로 둔다', () async {
      runs.otherIds.add('kept'); // 목록에는 없지만 행은 있다(진행 중 등).
      await growth.addDistanceXp('kept', 30);
      await service.sync();
      expect(await growth.totalXp(), 30);
    });

    test('저장소에 아예 없는 러닝의 경험치는 sync 가 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      await service.sync();
      await growth.addDistanceXp('ghost', 30);
      final gain = await service.sync();
      expect(gain.isEmpty, isTrue);
      expect(await growth.totalXp(), 50);
      expect(await growth.runIdsWithDistanceXp(), {'a'});
    });

    test('exclusive 는 앞선 sync 가 끝난 뒤에 돈다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      final s = service.sync();
      // 앞선 sync 가 쓴 경험치를 이미 본다.
      final seen = service.exclusive(() => growth.totalXp());
      expect(await seen, 50);
      await s;
    });
  });

  group('바꾼 러닝 자가 복구 (sync)', () {
    late DateTime wall;
    setUp(() {
      wall = DateTime.utc(2026, 10, 17, 3);
      growth = DriftGrowthRepository(db, now: () => wall);
      service = GrowthService(runs, growth, () => now);
    });

    test('잘라낸 뒤 runRevised 가 없었으면 다음 sync 가 경험치를 고친다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 5000);
      await service.sync();
      expect(await growth.totalXp(), 110);

      wall = wall.add(const Duration(minutes: 1));
      runs.revise('b', 3000, at: wall); // 기록만 바뀌고 runRevised 전에 실패했다.
      wall = wall.add(const Duration(minutes: 1));
      final gain = await service.sync();

      expect(gain.isEmpty, isTrue);
      expect(gain.levelBefore, gain.levelAfter);
      expect(await growth.totalXp(), 90);

      // 다시 sync 해도 그대로다.
      wall = wall.add(const Duration(minutes: 1));
      final again = await service.sync();
      expect(again.isEmpty, isTrue);
      expect(await growth.totalXp(), 90);
    });

    test('runRevised 까지 끝났으면 sync 는 다시 매기지 않는다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 11000);
      await service.sync();
      wall = wall.add(const Duration(minutes: 1));
      runs.revise('a', 10500, at: wall);
      wall = wall.add(const Duration(minutes: 1));
      await service.runRevised('a', DateTime(2026, 10, 13, 7));
      final before = await growth.distanceXpUpdatedAts();
      wall = wall.add(const Duration(minutes: 1));
      await service.sync();
      expect(await growth.distanceXpUpdatedAts(), before);
      expect(await growth.totalXp(), 105);
    });
  });

  group('러닝 잘라내기 (runRevised)', () {
    Future<GrowthGain> revise(String id, double distanceM) async {
      final startedAt = (await runs.getRun(id))!.run.startedAt;
      runs.revise(id, distanceM);
      return service.runRevised(id, startedAt);
    }

    test('경험치가 새 거리 값이 되고 레벨이 내려갈 수 있다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 11000);
      await service.sync();
      expect(await growth.totalXp(), 170); // 레벨 3

      final delta = await revise('b', 1000);

      expect(delta.distanceXp, -100);
      expect(delta.goalBonusXp, 0);
      expect(delta.levelBefore, 3);
      expect(delta.levelAfter, 2);
      expect(delta.stageBefore, stageForLevel(3));
      expect(delta.stageAfter, stageForLevel(2));
      expect(await growth.totalXp(), 70);
      expect((await service.load()).level.level, 2);
    });

    test('다시 늘리면 경험치가 늘어난다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 3000);
      await service.sync();

      final delta = await revise('b', 5000);

      expect(delta.distanceXp, 20);
      expect(await growth.totalXp(), 110);
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
      expect(delta.goalBonusXp, 0);
      expect(await growth.totalXp(), 90);
    });
  });
}
