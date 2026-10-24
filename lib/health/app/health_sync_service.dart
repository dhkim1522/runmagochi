import 'package:flutter/foundation.dart';

import '../../avatar/app/growth_service.dart';
import '../../core/clock.dart';
import '../../profile/data/profile_repository.dart';
import '../../run/data/run_repository.dart';
import '../data/health_source.dart';
import '../domain/health_workout.dart';

/// 건강 앱(Apple 건강·Health Connect)의 러닝을 러닝 기록으로 들인다 (F15, 결정 0037).
///
/// 워치로 달린 기록이 건강 앱에 올라오면 읽어 러닝 한 건으로 저장하고 경험치·코인·배지를
/// 다시 계산한다. 경로가 없어 경로는 비고 거리·시간·평균 페이스만 있다. 같은 운동은
/// 한 번만 들인다(지운 기록도 다시 들이지 않는다). 앱을 열 때·화면으로 돌아올 때 부른다.
class HealthSyncService {
  HealthSyncService({
    required this.profile,
    required this.source,
    required this.store,
    required this.growth,
    required this.clock,
  });

  final ProfileRepository profile;
  final HealthSource source;
  final HealthRunStore store;
  final GrowthService growth;
  final Clock clock;

  /// 처음 켤 때 거슬러 올라가 읽는 기간.
  static const firstLookback = Duration(days: 30);

  /// 들인 마지막 러닝보다 이만큼 앞에서부터 읽어 늦게 올라온 운동을 놓치지 않는다.
  static const overlap = Duration(days: 1);

  /// 켠다: 권한을 요청하고 허용되면 켜짐으로 저장한다. 거절하거나 쓸 수 없으면 false.
  /// 기기가 건강 앱을 못 쓰는 것(Health Connect 미설치 등)은 [isSupported] 로 먼저 알 수 있다.
  Future<bool> enable() async {
    try {
      if (!await source.isAvailable()) return false;
      if (!await source.hasPermission() && !await source.requestPermission()) {
        await profile.setHealth(false);
        return false;
      }
      await profile.setHealth(true);
      return true;
    } catch (e) {
      debugPrint('건강: 켜기 실패 $e');
      return false;
    }
  }

  /// 이 기기에서 건강 앱을 쓸 수 있는가(Health Connect 설치 여부 등).
  Future<bool> isSupported() async {
    try {
      return await source.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// 새 러닝을 들이고 들인 개수를 돌려준다. 꺼져 있거나 쓸 수 없거나 권한이 없으면 0.
  /// 어떤 실패도 던지지 않는다.
  Future<int> sync() async {
    try {
      if (!await profile.health()) return 0;
      if (!await source.isAvailable()) return 0;
      if (!await source.hasPermission()) return 0;
      final last = await store.lastHealthRunStartedAt();
      final since = last == null
          ? clock().subtract(firstLookback)
          : last.subtract(overlap);
      final imported = await store.importedHealthIds();
      final fresh = importableWorkouts(
        await source.readRunningWorkouts(since),
        alreadyImported: imported,
      );
      for (final w in fresh) {
        await store.importHealthRun(w.id, summaryOf(w));
      }
      if (fresh.isNotEmpty) await growth.sync();
      return fresh.length;
    } catch (e) {
      debugPrint('건강: 가져오기 실패 $e');
      return 0;
    }
  }
}
