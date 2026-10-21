import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/app/achievement_service.dart';
import 'package:runmagochi/achievement/data/drift_badge_repository.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/backup/data/drift_backup_repository.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/shop/data/drift_shop_repository.dart';

import '../avatar/app/growth_service_test.dart' show FakeRunRepository;

void main() {
  final now = DateTime(2026, 10, 17, 12);
  late AppDatabase db;
  late FakeRunRepository runs;
  late DriftBadgeRepository badges;
  late DriftShopRepository shop;
  late GrowthService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    runs = FakeRunRepository();
    badges = DriftBadgeRepository(db);
    shop = DriftShopRepository(db);
    service = GrowthService(
      runs,
      DriftGrowthRepository(db),
      () => now,
      achievements: AchievementService(runs, badges, () => now),
    );
  });
  tearDown(() => db.close());

  Future<int> badgeCoins() async => (await shop.coinHistory())
      .where((e) => e.reason == 'badge')
      .fold<int>(0, (s, e) => s + e.amount);

  test('첫 러닝 뒤 first_run 한 개와 코인 50', () async {
    runs.add('a', DateTime(2026, 10, 13, 8), 3000);
    final gain = await service.sync();
    expect(gain.newBadges, ['first_run']);
    expect(gain.isEmpty, isFalse);
    expect((await badges.earned()).map((b) => b.badgeId), ['first_run']);
    expect(await badgeCoins(), 50);
    final row = (await shop.coinHistory()).firstWhere(
      (e) => e.reason == 'badge',
    );
    expect(row.itemId, 'first_run');
    expect(row.runId, isNull);
  });

  test('sync 를 두 번 불러도 한 번만 준다', () async {
    runs.add('a', DateTime(2026, 10, 13, 8), 3000);
    await service.sync();
    final again = await service.sync();
    expect(again.newBadges, isEmpty);
    expect(await badges.earned(), hasLength(1));
    expect(await badgeCoins(), 50);
  });

  test('동시에 부른 sync 도 두 번 주지 않는다', () async {
    runs.add('a', DateTime(2026, 10, 13, 8), 3000);
    final gains = await Future.wait([
      service.sync(),
      service.sync(),
      service.sync(),
    ]);
    expect(gains.expand((g) => g.newBadges), ['first_run']);
    expect(await badges.earned(), hasLength(1));
    expect(await badgeCoins(), 50);
  });

  test('소급: 기존 기록으로 받을 배지를 첫 sync 에서 모두 준다', () async {
    runs.add('a', DateTime(2026, 10, 13, 5), 5200); // 새벽, 5km
    runs.add('b', DateTime(2026, 10, 14, 8), 3000);
    final gain = await service.sync();
    expect(gain.newBadges, ['first_run', 'dist_5k', 'dawn']);
    expect(await badgeCoins(), 50 + 100 + 50);
    expect((await service.sync()).newBadges, isEmpty);
  });

  test('러닝을 지워도 배지와 코인은 남고 새로 받지도 않는다', () async {
    runs.add('a', DateTime(2026, 10, 13, 8), 3000);
    await service.sync();
    await runs.deleteRun('a');
    final gain = await service.sync();
    expect(gain.newBadges, isEmpty);
    expect(await badges.earned(), hasLength(1));
    expect(await badgeCoins(), 50);
  });

  test('백업 왕복 뒤 sync 해도 중복이 없다', () async {
    runs.add('a', DateTime(2026, 10, 13, 8), 3000);
    await service.sync();
    final backup = DriftBackupRepository(db);
    final json = await backup.exportJson(now);
    await backup.importJson(json);
    final gain = await service.sync();
    expect(gain.newBadges, isEmpty);
    expect(await badges.earned(), hasLength(1));
    expect(await badgeCoins(), 50);
  });

  test('award 는 받은 배지에 다시 쓰지 않는다', () async {
    expect(await badges.award('dawn', coins: 50, at: now), isTrue);
    expect(await badges.award('dawn', coins: 50, at: now), isFalse);
    expect(await badgeCoins(), 50);
  });
}
