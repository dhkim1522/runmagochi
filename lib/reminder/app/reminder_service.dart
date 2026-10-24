import 'package:flutter/foundation.dart';

import '../../avatar/app/growth_service.dart';
import '../../core/clock.dart';
import '../../profile/data/profile_repository.dart';
import '../../run/data/run_repository.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder_plan.dart';

/// 쉬는 날 캐릭터 알림을 지금 상태에 맞게 다시 예약한다 (F27, 결정 0037).
///
/// 앱을 열 때, 러닝을 마칠 때, 설정을 바꿀 때, 가져오기·초기화 뒤에 부른다.
/// 늘 지난 예약을 먼저 지우고, 켜져 있으면 최근 러닝 기준으로 하나만 예약한다.
class ReminderService {
  ReminderService({
    required this._profile,
    required this._runs,
    required this._growth,
    required this._scheduler,
    required this._clock,
  });

  final ProfileRepository _profile;
  final RunRepository _runs;
  final GrowthService _growth;
  final ReminderScheduler _scheduler;
  final Clock _clock;

  /// 어떤 실패도 밖으로 던지지 않는다. 알림은 러닝·화면에 영향을 주지 않는다.
  Future<void> refresh() async {
    try {
      await _scheduler.cancel();
      if (!await _profile.reminder()) return;
      final runs = await _runs.listRuns(); // 최신순
      if (runs.isEmpty) return;
      final state = await _growth.load();
      final plan = planReminder(
        now: _clock(),
        lastRunAt: runs.first.startedAt,
        petName: state.name,
        kmToNextLevel: state.kmToNextLevel,
      );
      if (plan != null) await _scheduler.schedule(plan);
    } catch (e) {
      debugPrint('알림: 쉬는 날 알림 갱신 실패 $e');
    }
  }
}
