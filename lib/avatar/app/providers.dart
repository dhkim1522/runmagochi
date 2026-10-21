import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/app/providers.dart';
import '../../run/app/providers.dart';
import '../../shop/app/providers.dart';
import '../data/drift_growth_repository.dart';
import '../data/growth_repository.dart';
import '../data/notification_scheduler.dart';
import '../domain/growth_state.dart';
import 'growth_service.dart';

final growthRepositoryProvider = Provider<GrowthRepository>(
  (ref) => DriftGrowthRepository(ref.watch(appDatabaseProvider)),
);

final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => ref.watch(localNotificationSchedulerProvider),
);

final growthServiceProvider = Provider<GrowthService>(
  (ref) => GrowthService(
    ref.watch(runRepositoryProvider),
    ref.watch(growthRepositoryProvider),
    ref.watch(clockProvider),
    achievements: ref.watch(achievementServiceProvider),
  ),
);

/// sync 뒤 load. 러닝이 끝난 뒤 invalidate 하면 다시 계산한다.
final growthStateProvider = FutureProvider<GrowthState>((ref) async {
  final service = ref.watch(growthServiceProvider);
  final gain = await service.sync();
  // 시작할 때 소급으로 받은 배지·코인이 칩과 내역에 바로 보이게 한다.
  if (gain.newBadges.isNotEmpty) {
    ref.invalidate(coinBalanceProvider);
    ref.invalidate(coinHistoryProvider);
    ref.invalidate(earnedBadgesProvider);
  }
  return service.load();
});
