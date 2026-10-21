import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart';
import '../data/drift_shop_repository.dart';
import '../data/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => DriftShopRepository(ref.watch(appDatabaseProvider)),
);
