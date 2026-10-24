import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../profile/app/providers.dart';
import '../../run/app/providers.dart';
import '../../run/data/run_repository.dart';
import '../../run/domain/run_summary.dart';
import '../data/health_source.dart';
import 'health_sync_service.dart';

/// 건강 앱을 읽을 수 있는 기기 종류인가(Android·iOS 앱). 테스트·웹에서는 false.
final healthAvailableProvider = Provider<bool>(
  (_) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

final healthSourceProvider = Provider<HealthSource>(
  (_) => const UnavailableHealthSource(),
);

/// 건강 앱에서 러닝을 들이는 서비스. 건강 기록 저장은 드리프트 러닝 저장소만 한다.
/// 테스트가 러닝 저장소를 가짜로 바꾸면 이 provider 도 같이 바꾼다.
final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  final repository = ref.watch(runRepositoryProvider);
  return HealthSyncService(
    profile: ref.watch(profileRepositoryProvider),
    source: ref.watch(healthSourceProvider),
    store: repository is HealthRunStore
        ? repository as HealthRunStore
        : const _NoHealthStore(),
    growth: ref.watch(growthServiceProvider),
    clock: ref.watch(clockProvider),
  );
});

/// 건강 기록을 저장할 수 없는 저장소(테스트의 가짜): 아무것도 들이지 않는다.
class _NoHealthStore implements HealthRunStore {
  const _NoHealthStore();

  @override
  Future<Set<String>> importedHealthIds() async => const {};

  @override
  Future<DateTime?> lastHealthRunStartedAt() async => null;

  @override
  Future<void> importHealthRun(String healthId, RunSummary summary) async {}
}
