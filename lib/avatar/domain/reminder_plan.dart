import '../../core/format.dart';
import '../../core/week.dart';

/// 예약할 알림 한 건.
class PlannedReminder {
  const PlannedReminder({required this.at, required this.body});

  final DateTime at;
  final String body;
}

/// 금요일 18:00(현지) 주간 목표 알림 계획.
/// 이번 주 목표가 남았으면 이번 주 금요일, 그리고 이후 3주의 금요일.
List<PlannedReminder> planReminders({
  required DateTime now,
  required double weekTargetM,
  required double weekDistanceM,
  required bool weekAchieved,
}) {
  final monday = weekStartOf(now);
  final result = <PlannedReminder>[];
  // DateTime 의 day 연산으로 더해 일광절약 시간에도 18:00 을 지킨다.
  DateTime friday(int weeks) =>
      DateTime(monday.year, monday.month, monday.day + 4 + 7 * weeks, 18);

  final thisFriday = friday(0);
  if (!weekAchieved && thisFriday.isAfter(now)) {
    final remaining = (weekTargetM - weekDistanceM).clamp(0, double.infinity);
    result.add(
      PlannedReminder(
        at: thisFriday,
        body: '이번 주 목표까지 ${formatKm(remaining.toDouble())}km 남았어요',
      ),
    );
  }
  for (var w = 1; w <= 3; w++) {
    result.add(
      PlannedReminder(
        at: friday(w),
        body: '이번 주 목표 ${formatTargetKm(weekTargetM)}km, 러니와 달려 볼까요?',
      ),
    );
  }
  return result;
}
