import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart';
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
    scheduler: ref.watch(notificationSchedulerProvider),
  ),
);

/// sync 뒤 load. 러닝이 끝나거나 목표를 바꾼 뒤 invalidate 하면 다시 계산한다.
final growthStateProvider = FutureProvider<GrowthState>((ref) async {
  final service = ref.watch(growthServiceProvider);
  await service.sync();
  return service.load();
});
