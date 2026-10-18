import '../../run/domain/run_summary.dart';

/// 주간 목표 달성 보너스 경험치 (주마다 한 번).
const int weeklyGoalBonusXp = 50;

/// 1km 구간 페이스가 이보다 빠르면(초/km) 그 구간 거리는 경험치에서 뺀다.
const double _minPaceSecPerKm = 150;

/// 이 페이스(초/km)보다 느리면 걷는 동작.
const double _runPaceSecPerKm = 540;

/// 속도 검사에 걸려 경험치에서 빼는 구간인가. 1km 미만 마지막 구간은 검사하지 않는다.
bool _isExcludedSplit(Split s) =>
    s.distanceM >= 1000 && s.paceSecPerKm < _minPaceSecPerKm;

/// 속도 검사에 걸려 경험치에서 뺀 거리 합(미터).
double excludedFastDistanceM(List<Split> splits) {
  var excluded = 0.0;
  for (final s in splits) {
    if (_isExcludedSplit(s)) excluded += s.distanceM;
  }
  return excluded;
}

/// 러닝 거리로 얻는 경험치. 거리를 먼저 10m(화면 표시 단위)로 반올림하고 100m당 1, 소수점 버림.
/// 속도 검사에 걸린 1km 구간의 거리는 뺀다. 1km 미만 마지막 구간은 검사하지 않는다.
int distanceXp(double distanceM, List<Split> splits) {
  final counted = distanceM - excludedFastDistanceM(splits);
  if (counted <= 0) return 0;
  return (counted / 10).round() ~/ 10;
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  final int level;

  /// 현재 레벨에 들어온 뒤 쌓은 경험치.
  final int xpIntoLevel;

  /// 현재 레벨에서 다음 레벨까지 필요한 전체 경험치 (50 × level).
  final int xpForNext;
}

/// 레벨 [level] 에 도달하는 데 필요한 누적 경험치.
int xpToReachLevel(int level) => 25 * level * (level - 1);

LevelProgress levelFor(int totalXp) {
  final xp = totalXp < 0 ? 0 : totalXp;
  var level = 1;
  while (xpToReachLevel(level + 1) <= xp) {
    level++;
  }
  return LevelProgress(
    level: level,
    xpIntoLevel: xp - xpToReachLevel(level),
    xpForNext: 50 * level,
  );
}

/// 외형 단계별 시작 레벨.
const stageStartLevels = [1, 5, 10, 20];

/// 레벨의 외형 단계 (1~4).
int stageForLevel(int level) {
  var stage = 1;
  for (var i = 0; i < stageStartLevels.length; i++) {
    if (level >= stageStartLevels[i]) stage = i + 1;
  }
  return stage;
}

/// 다음 외형 단계까지 남은 경험치. 최고 단계면 null.
int? xpToNextStage(int totalXp) {
  final stage = stageForLevel(levelFor(totalXp).level);
  if (stage >= stageStartLevels.length) return null;
  return xpToReachLevel(stageStartLevels[stage]) - totalXp;
}

/// 아바타 종류. 처음 한 번 무작위로 정해 바꾸지 않는다 (결정 0011).
enum AvatarKind { chick, jelly, acorn }

enum AvatarMood { normal, sleepy, asleep }

/// 마지막 러닝 시작일과 오늘의 현지 달력 날짜 차이로 표정을 정한다.
AvatarMood moodFor(DateTime? lastRunStartedAt, DateTime now) {
  if (lastRunStartedAt == null) return AvatarMood.normal;
  final last = lastRunStartedAt.toLocal();
  final today = now.toLocal();
  // UTC 로 옮겨 일광절약 시간에 흔들리지 않게 날짜만 비교한다.
  final days = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
  if (days >= 7) return AvatarMood.asleep;
  if (days >= 3) return AvatarMood.sleepy;
  return AvatarMood.normal;
}

enum AvatarAction { idle, walk, run }

/// 러닝 중 동작. 일시정지 idle, 페이스가 없거나 9'00" 보다 느리면 walk, 아니면 run.
AvatarAction actionFor({
  required bool paused,
  required double? currentPaceSecPerKm,
}) {
  if (paused) return AvatarAction.idle;
  if (currentPaceSecPerKm == null || currentPaceSecPerKm > _runPaceSecPerKm) {
    return AvatarAction.walk;
  }
  return AvatarAction.run;
}
