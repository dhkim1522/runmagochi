import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart';
import '../data/badge_repository.dart';
import '../data/drift_badge_repository.dart';
import 'achievement_service.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => DriftBadgeRepository(ref.watch(appDatabaseProvider)),
);

final achievementServiceProvider = Provider<AchievementService>(
  (ref) => AchievementService(
    ref.watch(runRepositoryProvider),
    ref.watch(badgeRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

/// 받은 배지. 동기화·백업 가져오기 뒤 invalidate 한다.
final earnedBadgesProvider = FutureProvider.autoDispose<List<EarnedBadge>>(
  (ref) => ref.read(badgeRepositoryProvider).earned(),
);
