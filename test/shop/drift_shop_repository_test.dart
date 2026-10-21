import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/shop/data/drift_shop_repository.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/domain/catalog.dart';

final _t = DateTime.utc(2026, 10, 5, 7);

void main() {
  late AppDatabase db;
  late DriftShopRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    var tick = 0;
    repo = DriftShopRepository(
      db,
      now: () => _t.add(Duration(minutes: ++tick)),
    );
  });
  tearDown(() => db.close());

  Future<void> grant(int amount, String runId, String reason) async {
    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(
            id: runId,
            startedAt: _t,
            status: 'completed',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await db
        .into(db.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: 'c-$runId',
            amount: amount,
            reason: reason,
            runId: Value(runId),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
  }

  test('처음에는 잔액 0, 보유·장착 없음', () async {
    expect(await repo.balance(), 0);
    expect(await repo.ownedItemIds(), isEmpty);
    expect(await repo.coinHistory(), isEmpty);
    final e = await repo.equipped();
    expect(e.hatItemId, isNull);
    expect(e.accessoryItemId, isNull);
  });

  test('잔액 100 에 120짜리는 InsufficientCoins, 행이 생기지 않는다', () async {
    await grant(100, 'r1', 'distance');
    await expectLater(
      repo.purchase('hat1', 120),
      throwsA(isA<InsufficientCoins>()),
    );
    expect(await repo.balance(), 100);
    expect(await db.select(db.ownedItems).get(), isEmpty);
    expect(await db.select(db.coinTxns).get(), hasLength(1));
  });

  test('구매하면 잔액이 줄고 보유가 생긴다', () async {
    await grant(300, 'r1', 'distance');
    await repo.purchase('hat1', 120);
    expect(await repo.balance(), 180);
    expect(await repo.ownedItemIds(), {'hat1'});
    final h = await repo.coinHistory();
    expect(h.first.amount, -120);
    expect(h.first.reason, 'purchase');
    expect(h.first.itemId, 'hat1');
  });

  test('같은 아이템을 두 번 사면 두 번째는 AlreadyOwned, 잔액은 한 번만 준다', () async {
    await grant(300, 'r1', 'distance');
    await repo.purchase('hat1', 100);
    await expectLater(repo.purchase('hat1', 100), throwsA(isA<AlreadyOwned>()));
    expect(await repo.balance(), 200);
    expect(await db.select(db.ownedItems).get(), hasLength(1));
  });

  test('보유하지 않은 아이템 장착은 NotOwned', () async {
    await expectLater(
      repo.equip(ItemSlot.hat, 'hat1'),
      throwsA(isA<NotOwned>()),
    );
  });

  test('장착과 해제', () async {
    await db
        .into(db.avatars)
        .insert(
          AvatarsCompanion.insert(
            id: 'a1',
            name: '러니',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await grant(300, 'r1', 'distance');
    await repo.purchase('hat1', 100);
    await repo.purchase('acc1', 100);
    await repo.equip(ItemSlot.hat, 'hat1');
    await repo.equip(ItemSlot.accessory, 'acc1');
    var e = await repo.equipped();
    expect(e.hatItemId, 'hat1');
    expect(e.accessoryItemId, 'acc1');
    await repo.equip(ItemSlot.hat, null);
    e = await repo.equipped();
    expect(e.hatItemId, isNull);
    expect(e.accessoryItemId, 'acc1');
  });
}
