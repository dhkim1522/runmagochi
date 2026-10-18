import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/data/notification_scheduler.dart';
import '../../core/clock.dart';
import '../data/app_database.dart';
import '../data/drift_run_repository.dart';
import '../data/geolocator_location_source.dart';
import '../data/location_source.dart';
import '../data/run_repository.dart';
import 'app_lifecycle.dart';
import 'run_controller.dart';
import 'run_guard.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.production();
  ref.onDispose(db.close);
  return db;
});

final runRepositoryProvider = Provider<RunRepository>(
  (ref) => DriftRunRepository(ref.watch(appDatabaseProvider)),
);

final locationSourceProvider = Provider<LocationSource>(
  (_) => GeolocatorLocationSource(),
);

final clockProvider = Provider<Clock>((_) => DateTime.now);

final appLifecycleProvider = Provider<AppLifecycle>((ref) {
  final lifecycle = FlutterAppLifecycle();
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

final runControllerProvider = NotifierProvider<RunController, RunViewState>(
  RunController.new,
);

/// 자동 종료 기준. 테스트·E2E 에서 줄일 때만 바꾼다.
final runGuardConfigProvider = Provider<RunGuardConfig>(
  (_) => const RunGuardConfig(),
);

/// 주간 목표 알림과 러닝 자동 종료 알림이 같이 쓰는 알림 구현 하나.
final localNotificationSchedulerProvider = Provider<LocalNotificationScheduler>(
  (_) => LocalNotificationScheduler(),
);

/// 러닝 자동 종료 알림.
final instantNotifierProvider = Provider<InstantNotifier>(
  (ref) => ref.watch(localNotificationSchedulerProvider),
);
