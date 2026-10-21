import '../domain/run_goal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/data/notification_scheduler.dart';
import '../../core/clock.dart';
import '../../profile/app/providers.dart';
import '../data/app_database.dart';
import '../data/drift_run_repository.dart';
import '../data/geolocator_location_source.dart';
import '../data/location_source.dart';
import '../data/run_progress_notifier.dart';
import '../data/run_repository.dart';
import '../data/tts_speaker.dart';
import 'app_lifecycle.dart';
import 'run_controller.dart';
import 'run_guard.dart';
import 'voice_guide.dart';

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

/// 예약 알림 취소와 러닝 자동 종료 알림이 같이 쓰는 알림 구현 하나.
final localNotificationSchedulerProvider = Provider<LocalNotificationScheduler>(
  (_) => LocalNotificationScheduler(),
);

/// 러닝 자동 종료 알림.
final instantNotifierProvider = Provider<InstantNotifier>(
  (ref) => ref.watch(localNotificationSchedulerProvider),
);

/// 러닝 중 알림창 진행 표시.
final runProgressNotifierProvider = Provider<RunProgressNotifier>(
  (_) => LocalRunProgressNotifier(),
);

/// 알림 버튼 id(`run_pause`·`run_resume`) 스트림. 기본은 비어 있고,
/// 앱 시작(main)에서 실제 포트 스트림으로 바꾼다.
final runNotificationActionsProvider = Provider<Stream<String>>(
  (_) => const Stream<String>.empty(),
);

/// 홈 목표 선택의 초기값: 가장 최근에 시작한 러닝의 목표(종류 포함), 없으면 거리 3km.
final lastRunGoalProvider = FutureProvider.autoDispose<RunGoal>(
  (ref) async =>
      await ref.read(runRepositoryProvider).lastGoal() ??
      const DistanceGoal(3000),
);

/// 음성 안내를 읽는 곳. 테스트는 가짜로 바꾼다.
final speakerProvider = Provider<Speaker>((_) => TtsSpeaker());

/// 러닝 중 음성 안내. 켜짐 여부는 말할 때마다 프로필에서 읽는다.
final voiceGuideProvider = Provider<VoiceGuide>(
  (ref) => VoiceGuide(
    speaker: ref.watch(speakerProvider),
    enabled: () => ref.read(profileRepositoryProvider).voiceGuide(),
  ),
);
