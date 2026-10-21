import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../run/data/app_database.dart';
import '../domain/catalog.dart';
import 'shop_repository.dart';

class DriftShopRepository implements ShopRepository {
  /// [now] 는 행 시각에 쓴다. 테스트에서만 바꾼다.
  DriftShopRepository(this._db, {Clock? now}) : _clock = now ?? DateTime.now;

  final AppDatabase _db;
  final Clock _clock;
  final _uuid = const Uuid();

  DateTime _now() => _clock().toUtc();

  Future<int> _balance() async {
    final sum = _db.coinTxns.amount.sum();
    final row =
        await (_db.selectOnly(_db.coinTxns)
              ..addColumns([sum])
              ..where(_db.coinTxns.deletedAt.isNull()))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  Future<bool> _owned(String itemId) async {
    final row =
        await (_db.select(_db.ownedItems)
              ..where((o) => o.itemId.equals(itemId) & o.deletedAt.isNull()))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<int> balance() => _balance();

  @override
  Future<List<CoinEntry>> coinHistory() async {
    final rows =
        await (_db.select(_db.coinTxns)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.updatedAt),
              ]))
            .get();
    return [
      for (final r in rows)
        CoinEntry(
          amount: r.amount,
          reason: r.reason,
          runId: r.runId,
          itemId: r.itemId,
          at: r.createdAt.toLocal(),
        ),
    ];
  }

  @override
  Future<Set<String>> ownedItemIds() async {
    final rows = await (_db.select(
      _db.ownedItems,
    )..where((o) => o.deletedAt.isNull())).get();
    return {for (final r in rows) r.itemId};
  }

  @override
  Future<void> purchase(String itemId, int price) => _db.transaction(() async {
    if (await _owned(itemId)) throw const AlreadyOwned();
    if (await _balance() < price) throw const InsufficientCoins();
    final now = _now();
    await _db
        .into(_db.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: _uuid.v4(),
            amount: -price,
            reason: 'purchase',
            itemId: Value(itemId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    // 무른 보유 행이 있으면 고유 키가 겹치므로 살려 쓴다.
    final dead = await (_db.select(
      _db.ownedItems,
    )..where((o) => o.itemId.equals(itemId))).getSingleOrNull();
    if (dead == null) {
      await _db
          .into(_db.ownedItems)
          .insert(
            OwnedItemsCompanion.insert(
              id: _uuid.v4(),
              itemId: itemId,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.ownedItems,
      )..where((o) => o.id.equals(dead.id))).write(
        OwnedItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  });

  Future<Avatar?> _avatar() =>
      (_db.select(_db.avatars)
            ..where((a) => a.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  @override
  Future<Equipped> equipped() async {
    final a = await _avatar();
    return Equipped(
      hatItemId: a?.hatItemId,
      accessoryItemId: a?.accessoryItemId,
    );
  }

  @override
  Future<void> equip(ItemSlot slot, String? itemId) =>
      _db.transaction(() async {
        if (itemId != null && !await _owned(itemId)) throw const NotOwned();
        final a = await _avatar();
        // 아바타 행은 앱이 처음 열릴 때 만들어진다. 없으면 장착할 곳이 없다.
        if (a == null) return;
        final value = Value<String?>(itemId);
        await (_db.update(_db.avatars)..where((r) => r.id.equals(a.id))).write(
          AvatarsCompanion(
            hatItemId: slot == ItemSlot.hat ? value : const Value.absent(),
            accessoryItemId: slot == ItemSlot.accessory
                ? value
                : const Value.absent(),
            updatedAt: Value(_now()),
          ),
        );
      });
}
