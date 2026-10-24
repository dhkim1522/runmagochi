/// 쉬는 날 캐릭터 알림 한 건 (F27, 결정 0037).
class ReminderPlan {
  const ReminderPlan({
    required this.at,
    required this.title,
    required this.body,
  });

  /// 알림을 띄울 현지 시각.
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderPlan &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(at, title, body);
}

/// 마지막 러닝 뒤 며칠째에 부르는지.
const int reminderRestDays = 3;

/// 부르는 시각(현지, 시). 퇴근 뒤 달리기 좋은 저녁.
const int reminderHour = 19;

/// 남은 거리를 말해 주는 기준(km). 이 이하면 "Nkm만 더" 로 부른다.
const double reminderNearLevelKm = 1.0;

/// 다음 쉬는 날 알림. 마지막 러닝 날부터 [reminderRestDays] 일째 [reminderHour] 시에
/// 한 번 부른다. 러닝 기록이 없거나 그 시각이 이미 지났으면 null(쉬는 동안 한 번만,
/// 벌점·연속 압박 없음). 이름 뒤에는 조사를 붙이지 않는다.
ReminderPlan? planReminder({
  required DateTime now,
  required DateTime? lastRunAt,
  required String petName,
  required double? kmToNextLevel,
}) {
  if (lastRunAt == null) return null;
  final last = lastRunAt.toLocal();
  final at = DateTime(
    last.year,
    last.month,
    last.day + reminderRestDays,
    reminderHour,
  );
  if (!at.isAfter(now.toLocal())) return null;
  final km = kmToNextLevel;
  final body = km != null && km > 0 && km <= reminderNearLevelKm
      ? '${km.toStringAsFixed(1)}km만 더 달리면 레벨 업이에요'
      : '오늘 가볍게 같이 달려요';
  return ReminderPlan(at: at, title: '$petName 기다리는 중', body: body);
}
