import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../profile/app/providers.dart';
import '../../run/app/providers.dart';
import '../data/reminder_scheduler.dart';
import 'reminder_service.dart';

/// 쉬는 날 알림 예약. 테스트는 가짜로 바꾼다.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (_) => LocalReminderScheduler(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    profile: ref.watch(profileRepositoryProvider),
    runs: ref.watch(runRepositoryProvider),
    growth: ref.watch(growthServiceProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    clock: ref.watch(clockProvider),
  ),
);
