import '../domain/catalog.dart';

/// 코인 내역 한 줄. [amount] 는 지급 +, 구매 −.
class CoinEntry {
  const CoinEntry({
    required this.amount,
    required this.reason,
    required this.runId,
    required this.itemId,
    required this.at,
  });

  final int amount;

  /// `distance` | `runGoal` | `purchase`
  final String reason;
  final String? runId;
  final String? itemId;
  final DateTime at;
}

/// 장착 중인 아이템 id. 안 쓰는 부위는 null.
class Equipped {
  const Equipped({this.hatItemId, this.accessoryItemId});

  final String? hatItemId;
  final String? accessoryItemId;
}

/// 코인이 모자라 살 수 없다.
class InsufficientCoins implements Exception {
  const InsufficientCoins();
}

/// 이미 가진 아이템이다.
class AlreadyOwned implements Exception {
  const AlreadyOwned();
}

/// 가지지 않은 아이템이다.
class NotOwned implements Exception {
  const NotOwned();
}

/// 코인·보유 아이템·장착 저장소.
abstract interface class ShopRepository {
  /// 살아 있는 코인 행의 합.
  Future<int> balance();

  /// 최신순.
  Future<List<CoinEntry>> coinHistory();

  Future<Set<String>> ownedItemIds();

  /// 한 트랜잭션. 이미 가졌으면 [AlreadyOwned], 잔액이 [price] 보다 적으면
  /// [InsufficientCoins] 를 던지고 아무 행도 쓰지 않는다.
  /// 아니면 −[price] 코인 행과 보유 행을 쓴다.
  Future<void> purchase(String itemId, int price);

  Future<Equipped> equipped();

  /// [itemId] 가 null 이면 해제한다. 가지지 않은 아이템이면 [NotOwned].
  Future<void> equip(ItemSlot slot, String? itemId);
}
