import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart';
import '../data/drift_shop_repository.dart';
import '../data/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => DriftShopRepository(ref.watch(appDatabaseProvider)),
);

/// 코인 잔액. 러닝 보상을 반영한 뒤 invalidate 한다.
final coinBalanceProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.read(shopRepositoryProvider).balance(),
);

/// 코인 내역(최신순).
final coinHistoryProvider = FutureProvider.autoDispose<List<CoinEntry>>(
  (ref) => ref.read(shopRepositoryProvider).coinHistory(),
);
