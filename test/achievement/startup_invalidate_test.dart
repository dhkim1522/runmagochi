import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/drift_shop_repository.dart';

import '../run/ui/fakes.dart';

void main() {
  test('시작 sync 가 새 배지를 받으면 코인 잔액을 다시 읽는다', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fake = FakeGrowthService(growthState())
      ..syncGain = const GrowthGain(
        distanceXp: 0,
        goalBonusXp: 0,
        levelBefore: 1,
        levelAfter: 1,
        stageBefore: 1,
        stageAfter: 1,
        newBadges: ['first_run'],
      );
    final c = ProviderContainer(
      overrides: [
        growthServiceProvider.overrideWithValue(fake),
        shopRepositoryProvider.overrideWithValue(DriftShopRepository(db)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(coinBalanceProvider, (_, _) {});
    expect(await c.read(coinBalanceProvider.future), 0);
    final at = DateTime.utc(2026, 10, 17);
    await db
        .into(db.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: 'x',
            amount: 50,
            reason: 'badge',
            createdAt: at,
            updatedAt: at,
          ),
        );
    await c.read(growthStateProvider.future);
    expect(await c.read(coinBalanceProvider.future), 50);
  });
}
