import '../../avatar/domain/growth_rules.dart';
import '../../run/data/run_repository.dart';
import '../../run/domain/run_summary.dart';

/// 개인 기록 모음. 기록이 없는 항목은 null.
class PersonalRecords {
  const PersonalRecords({
    this.longestDistanceM,
    this.longestTime,
    this.bestKm,
    this.bestFiveKm,
  });

  /// 한 번에 달린 가장 긴 거리(미터). 값은 러닝 거리 그대로다.
  final double? longestDistanceM;

  /// 한 번에 달린 가장 긴 움직인 시간.
  final Duration? longestTime;

  /// 최고 1km: 빠른 구간을 뺀 온전한 1km 구간 중 가장 짧은 시간.
  final Duration? bestKm;

  /// 최고 5km: 연속한 온전한 1km 구간 5개 합 중 가장 짧은 시간.
  final Duration? bestFiveKm;
}

bool _isFullSplit(Split s) => s.distanceM >= 1000;

/// 지운 러닝을 뺀 [runs] 로 개인 기록을 구한다. 지운 러닝은 부르는 쪽에서 걸러 넘긴다.
///
/// - 최고 1km: 1km 이상 구간 중 빠른 구간([isFastSplit])을 뺀 가장 짧은 시간.
/// - 최고 5km: 한 러닝 안에서 번호가 이어지는 온전한 1km 구간 5개의 합이 가장 짧은 값.
///   창 안에 빠른 구간이 하나라도 있으면 그 창은 건너뛴다.
PersonalRecords recordsFor(List<RunDetail> runs) {
  double? longestDistance;
  Duration? longestTime;
  Duration? bestKm;
  Duration? bestFive;

  for (final d in runs) {
    final r = d.run;
    if (longestDistance == null || r.distanceM > longestDistance) {
      longestDistance = r.distanceM;
    }
    if (longestTime == null || r.movingTime > longestTime) {
      longestTime = r.movingTime;
    }

    final splits = [...d.splits]..sort((a, b) => a.index.compareTo(b.index));
    for (final s in splits) {
      if (_isFullSplit(s) && !isFastSplit(s)) {
        if (bestKm == null || s.duration < bestKm) bestKm = s.duration;
      }
    }
    for (var i = 0; i + 5 <= splits.length; i++) {
      final window = splits.sublist(i, i + 5);
      var valid = true;
      var sum = Duration.zero;
      for (var j = 0; j < window.length; j++) {
        final s = window[j];
        if (!_isFullSplit(s) ||
            isFastSplit(s) ||
            (j > 0 && s.index != window[j - 1].index + 1)) {
          valid = false;
          break;
        }
        sum += s.duration;
      }
      if (valid && (bestFive == null || sum < bestFive)) bestFive = sum;
    }
  }

  return PersonalRecords(
    longestDistanceM: longestDistance,
    longestTime: longestTime,
    bestKm: bestKm,
    bestFiveKm: bestFive,
  );
}
