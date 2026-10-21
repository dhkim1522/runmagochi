import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/core/week.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/shop/data/drift_shop_repository.dart';

class FakeRunRepository implements RunRepository {
  final List<RunDetail> runs = [];

  void add(
    String id,
    DateTime startedAt,
    double distanceM, {
    double? goalM,
    RunGoal? goal,
    Duration movingTime = const Duration(minutes: 30),
    List<Split> splits = const [],
  }) {
    runs.add(
      RunDetail(
        run: RunListItem(
          id: id,
          name: id,
          startedAt: startedAt,
          distanceM: distanceM,
          movingTime: movingTime,
          avgPaceSecPerKm: 360,
          goal: goal ?? (goalM == null ? null : DistanceGoal(goalM)),
        ),
        calories: 0,
        route: const [],
        splits: splits,
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
  Future<RunGoal?> lastGoal() async => null;

  @override
  Future<String> createActiveRun(DateTime startedAt, {required RunGoal goal}) =>
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
  void revise(
    String id,
    double distanceM, {
    DateTime? at,
    Duration? movingTime,
  }) {
    final i = runs.indexWhere((r) => r.run.id == id);
    final old = runs[i].run;
    runs.removeAt(i);
    add(
      id,
      old.startedAt,
      distanceM,
      goal: old.goal,
      movingTime: movingTime ?? old.movingTime,
    );
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
    await service.sync();
    expect(await growth.totalXp(), 110);
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

  group('러닝 삭제', () {
    test('지워도 경험치·레벨이 그대로고 다음 sync 도 그대로다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 6000);
      runs.add('b', DateTime(2026, 10, 15, 7), 11000, goalM: 10000);
      await service.sync();
      expect(await growth.totalXp(), 60 + 110 + 50);
      final level = (await service.load()).level.level;

      await runs.deleteRun('b');
      final gain = await service.sync();

      expect(gain.isEmpty, isTrue);
      expect(gain.levelBefore, gain.levelAfter);
      expect(await growth.totalXp(), 220);
      final state = await service.load();
      expect(state.level.level, level);
      expect(state.runCount, 1);
      expect(await service.sync().then((g) => g.isEmpty), isTrue);
      expect(await growth.totalXp(), 220);
    });

    test('저장소가 지웠다고 확인하지 않은 경험치는 그대로 둔다', () async {
      runs.otherIds.add('kept'); // 목록에는 없지만 행은 있다(진행 중 등).
      await growth.setRunRewards(
        'kept',
        distanceXp: 30,
        goalBonusXp: 0,
        distanceCoins: null,
        goalCoins: null,
      );
      await service.sync();
      expect(await growth.totalXp(), 30);
    });

    test('저장소에 아예 없는 러닝의 경험치는 sync 가 무른다', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 5020);
      await service.sync();
      await growth.setRunRewards(
        'ghost',
        distanceXp: 30,
        goalBonusXp: 15,
        distanceCoins: null,
        goalCoins: null,
      );
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

  group('달성 보너스 (sync)', () {
    final at = DateTime(2026, 10, 13, 7);

    test('10km 목표로 5km 는 미달, 보너스 없음(+50)', () async {
      runs.add('a', at, 5000, goalM: 10000);
      final gain = await service.sync();
      expect(gain.goalBonusXp, 0);
      expect(await growth.totalXp(), 50);
    });

    test('5km 목표로 5km 는 +75', () async {
      runs.add('a', at, 5000, goalM: 5000);
      final gain = await service.sync();
      expect(gain.distanceXp, 50);
      expect(gain.goalBonusXp, 25);
      expect(await growth.totalXp(), 75);
    });

    test('5km 목표로 7km 는 +95', () async {
      runs.add('a', at, 7000, goalM: 5000);
      await service.sync();
      expect(await growth.totalXp(), 95);
    });

    test('목표 없는 예전 러닝은 보너스 0', () async {
      runs.add('a', at, 5000);
      final gain = await service.sync();
      expect(gain.goalBonusXp, 0);
      expect(await growth.totalXp(), 50);
    });

    test('빠른 구간을 빼면 미달이라 보너스 0', () async {
      final splits = [
        for (var i = 0; i < 5; i++)
          Split(
            index: i,
            distanceM: 1000,
            duration: Duration(seconds: i == 0 ? 120 : 360),
          ),
      ];
      runs.add('a', at, 5000, goalM: 5000, splits: splits);
      final gain = await service.sync();
      expect(gain.goalBonusXp, 0);
      expect(await growth.totalXp(), 40);
    });
  });

  group('시간 목표 보너스', () {
    final at = DateTime(2026, 10, 13, 7);
    Future<int> balance() => DriftShopRepository(db).balance();
    const thirty = TimeGoal(Duration(minutes: 30));

    test('30분 목표로 30분을 움직이면 보너스 25 + 코인 25', () async {
      runs.add(
        'a',
        at,
        3000,
        goal: thirty,
        movingTime: const Duration(minutes: 30),
      );
      final gain = await service.sync();
      expect(gain.goalBonusXp, 25);
      expect(gain.goalCoins, 25);
      expect(await growth.totalXp(), 30 + 25);
    });

    test('29분 59초면 미달이라 보너스와 목표 코인이 없다', () async {
      runs.add(
        'a',
        at,
        3000,
        goal: thirty,
        movingTime: const Duration(minutes: 29, seconds: 59),
      );
      final gain = await service.sync();
      expect(gain.goalBonusXp, 0);
      expect(gain.goalCoins, 0);
      expect(await balance(), 15);
    });

    test('잘라내 29분이 되면 보너스와 목표 코인을 무르고 다시 늘리면 돌려준다', () async {
      runs.add(
        'a',
        at,
        3000,
        goal: thirty,
        movingTime: const Duration(minutes: 31),
      );
      await service.sync();
      expect(await balance(), 15 + 25);

      runs.revise('a', 2800, movingTime: const Duration(minutes: 29));
      final cut = await service.runRevised('a', at);
      expect(cut.goalBonusXp, -25);
      expect(cut.goalCoins, -25);
      expect(await balance(), 14);

      runs.revise('a', 3000, movingTime: const Duration(minutes: 30));
      final back = await service.runRevised('a', at);
      expect(back.goalBonusXp, 25);
      expect(back.goalCoins, 25);
    });
  });

  group('러닝 코인', () {
    final at = DateTime(2026, 10, 13, 7);
    Future<int> balance() => DriftShopRepository(db).balance();

    test('5km 목표로 5.02km 를 달리면 거리 25 + 달성 25', () async {
      runs.add('a', at, 5020, goalM: 5000);
      final gain = await service.sync();
      expect(gain.distanceCoins, 25);
      expect(gain.goalCoins, 25);
      expect(await balance(), 50);
    });

    test('10km 목표로 5km 를 달리면 거리 25 + 달성 0', () async {
      runs.add('a', at, 5000, goalM: 10000);
      final gain = await service.sync();
      expect(gain.distanceCoins, 25);
      expect(gain.goalCoins, 0);
      expect(await balance(), 25);
    });

    test('빠른 구간은 거리 코인에서 빠지고 달성도 못 한다', () async {
      final splits = [
        for (var i = 0; i < 5; i++)
          Split(
            index: i,
            distanceM: 1000,
            duration: Duration(seconds: i == 0 ? 120 : 360),
          ),
      ];
      runs.add('a', at, 5000, goalM: 5000, splits: splits);
      final gain = await service.sync();
      expect(gain.distanceCoins, 20);
      expect(gain.goalCoins, 0);
      expect(await balance(), 20);
    });

    test('업데이트 전 러닝(경험치만 있음)은 sync·잘라내기 뒤에도 코인 0', () async {
      runs.add('a', at, 5000, goalM: 5000);
      await growth.setRunRewards(
        'a',
        distanceXp: 50,
        goalBonusXp: 25,
        distanceCoins: null,
        goalCoins: null,
      );
      final gain = await service.sync();
      expect(gain.distanceCoins, 0);
      expect(await balance(), 0);

      runs.revise('a', 3000);
      final delta = await service.runRevised('a', at);
      expect(delta.distanceCoins, 0);
      expect(delta.goalCoins, 0);
      expect(await balance(), 0);
      expect(await db.select(db.coinTxns).get(), isEmpty);
    });

    test('새 러닝을 잘라내 미달이 되면 달성 코인을 무르고 gain 은 -25', () async {
      runs.add('a', at, 5000, goalM: 5000);
      await service.sync();
      expect(await balance(), 50);

      runs.revise('a', 4000);
      final delta = await service.runRevised('a', at);
      expect(delta.goalCoins, -25);
      expect(delta.distanceCoins, -5);
      expect(await balance(), 20);
      final rows = await db.select(db.coinTxns).get();
      expect(rows.where((r) => r.deletedAt != null), hasLength(1));
    });

    test('첫 sync 전에 잘라낸 새 러닝도 코인을 받는다', () async {
      runs.add('a', at, 5000, goalM: 5000);
      runs.revise('a', 3000);
      await service.runRevised('a', at);
      expect(await balance(), greaterThan(0));
      expect(await db.select(db.coinTxns).get(), isNotEmpty);

      // 이어진 sync 도 같은 러닝을 새 러닝으로 다시 주지 않는다.
      final before = await balance();
      await service.sync();
      expect(await balance(), before);
    });

    test('경험치만 있는 예전 러닝은 잘라내도 코인 0', () async {
      runs.add('a', at, 5000, goalM: 5000);
      await growth.setRunRewards(
        'a',
        distanceXp: 50,
        goalBonusXp: 25,
        distanceCoins: null,
        goalCoins: null,
      );
      runs.revise('a', 3000);
      await service.runRevised('a', at);
      expect(await balance(), 0);
      expect(await db.select(db.coinTxns).get(), isEmpty);
    });

    test('러닝 삭제 뒤 잔액 그대로', () async {
      runs.add('a', at, 5000, goalM: 5000);
      await service.sync();
      await runs.deleteRun('a');
      await service.sync();
      expect(await balance(), 50);
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

    test('코인이 있는 새 러닝을 잘라낸 뒤 runRevised 가 없었으면 sync 가 코인도 고친다', () async {
      final at = DateTime(2026, 10, 13, 7);
      runs.add('a', at, 5000, goalM: 5000);
      await service.sync();
      final shop = DriftShopRepository(db);
      expect(await shop.balance(), 50);

      wall = wall.add(const Duration(minutes: 1));
      runs.revise('a', 4000, at: wall);
      wall = wall.add(const Duration(minutes: 1));
      await service.sync();

      expect(await shop.balance(), 20);
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

    test('잘라내 미달이 되면 보너스를 물렀다가 같은 끝으로 다시 부르면 차이 0', () async {
      runs.add('a', DateTime(2026, 10, 13, 7), 5000, goalM: 5000);
      await service.sync();
      expect(await growth.totalXp(), 75);

      final cut = await revise('a', 4000);
      expect(cut.goalBonusXp, -25);
      expect(cut.distanceXp, -10);
      expect(await growth.totalXp(), 40);

      final same = await service.runRevised('a', DateTime(2026, 10, 13, 7));
      expect(same.goalBonusXp, 0);
      expect(same.distanceXp, 0);
      expect(await growth.totalXp(), 40);

      // 다시 늘리면 보너스가 돌아온다.
      final back = await revise('a', 5000);
      expect(back.goalBonusXp, 25);
      expect(await growth.totalXp(), 75);
      expect(await db.select(db.xpTxns).get(), hasLength(2));
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
