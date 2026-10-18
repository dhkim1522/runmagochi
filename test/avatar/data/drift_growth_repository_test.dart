import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/run/data/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftGrowthRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftGrowthRepository(db);
  });
  tearDown(() => db.close());

  test('종류는 처음 한 번 정해지고 다시 불러도 같다', () async {
    final first = await DriftGrowthRepository(
      db,
      random: Random(1),
    ).avatarKind();
    expect(AvatarKind.values, contains(first));
    expect(await repo.avatarKind(), first);
    expect(await repo.avatarName(), '러니'); // 이름 조회가 종류를 덮지 않는다
    expect(await repo.avatarKind(), first);
  });

  test('새 DB 에서 이름·종류를 동시에 불러도 아바타는 한 줄이고 종류가 같다', () async {
    final r = await Future.wait<Object>([
      repo.avatarName(),
      repo.avatarKind(),
      repo.avatarKind(),
    ]);
    expect(await db.select(db.avatars).get(), hasLength(1));
    expect(r[1], r[2]);
    expect(
      (await db.select(db.avatars).get()).single.kind,
      (r[1] as AvatarKind).name,
    );
  });

  test('이름을 먼저 불러도 종류는 한 번 정해져 유지된다', () async {
    await repo.avatarName();
    final k = await repo.avatarKind();
    expect(await repo.avatarKind(), k);
    expect((await db.select(db.avatars).get()).single.kind, k.name);
  });

  test('저장값 default 는 한 번 무작위로 정해진 뒤 바뀌지 않는다', () async {
    final now = DateTime.now().toUtc();
    await db
        .into(db.avatars)
        .insert(
          AvatarsCompanion.insert(
            id: 'a1',
            name: '러니',
            createdAt: now,
            updatedAt: now,
          ),
        );
    expect((await db.select(db.avatars).get()).single.kind, 'default');
    final k = await repo.avatarKind();
    expect(AvatarKind.values, contains(k));
    for (var i = 0; i < 5; i++) {
      expect(await repo.avatarKind(), k);
    }
    expect((await db.select(db.avatars).get()).single.kind, k.name);
  });

  test('여러 시드로 세 종류가 모두 나온다', () async {
    final seen = <AvatarKind>{};
    for (var seed = 0; seed < 40; seed++) {
      final d = AppDatabase(NativeDatabase.memory());
      seen.add(
        await DriftGrowthRepository(d, random: Random(seed)).avatarKind(),
      );
      await d.close();
    }
    expect(seen, AvatarKind.values.toSet());
  });

  test('아바타 이름은 행이 없으면 러니로 만든다', () async {
    expect(await repo.avatarName(), '러니');
    expect(await repo.avatarName(), '러니');
    expect((await db.select(db.avatars).get()).length, 1);
  });

  test('같은 runId 로 거리 경험치를 두 번 넣어도 한 번만 쌓인다', () async {
    await repo.addDistanceXp('r1', 50);
    await repo.addDistanceXp('r1', 50);
    await repo.addDistanceXp('r2', 30);
    expect(await repo.totalXp(), 80);
    expect(await repo.runIdsWithDistanceXp(), {'r1', 'r2'});
  });

  test('경험치가 없으면 합계 0', () async {
    expect(await repo.totalXp(), 0);
  });

  test('주간 목표는 기본 10000, 이전 주 값을 이어받는다', () async {
    expect(await repo.weeklyTarget(DateTime(2026, 10, 19)), 10000);
    await repo.setWeeklyTarget(DateTime(2026, 10, 12), 12000);
    expect(await repo.weeklyTarget(DateTime(2026, 10, 19)), 12000);
    expect(await repo.weeklyTarget(DateTime(2026, 10, 5)), 10000);
    await repo.setWeeklyTarget(DateTime(2026, 10, 12), 15000);
    expect(await repo.weeklyTarget(DateTime(2026, 10, 12)), 15000);
  });

  test('markWeekAchieved 를 두 번 불러도 보너스는 한 번', () async {
    final w = DateTime(2026, 10, 12);
    expect(await repo.isWeekAchieved(w), isFalse);
    await repo.markWeekAchieved(w, DateTime(2026, 10, 14, 7), 50);
    await repo.markWeekAchieved(w, DateTime(2026, 10, 15, 7), 50);
    expect(await repo.isWeekAchieved(w), isTrue);
    expect(await repo.totalXp(), 50);
    expect(await repo.weeklyTarget(w), 10000);
  });

  test('목표 행이 있는 주도 달성 처리되고 목표는 유지된다', () async {
    final w = DateTime(2026, 10, 12);
    await repo.setWeeklyTarget(w, 8000);
    await repo.markWeekAchieved(w, DateTime(2026, 10, 14), 50);
    expect(await repo.weeklyTarget(w), 8000);
    expect(await repo.isWeekAchieved(w), isTrue);
  });

  test('달성한 주는 최신순으로 돌려준다', () async {
    for (final d in [5, 19, 12]) {
      await repo.markWeekAchieved(
        DateTime(2026, 10, d),
        DateTime(2026, 10, d),
        50,
      );
    }
    await repo.setWeeklyTarget(DateTime(2026, 10, 26), 9000);
    expect(await repo.achievedWeeks(), [
      DateTime(2026, 10, 19),
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 5),
    ]);
  });
}
