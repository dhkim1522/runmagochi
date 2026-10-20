// 종료를 잊은 러닝 자동 종료 규칙 (결정 0016).

/// 기록 중 이 시간 동안 받아들인 위치 점이 없으면 끝낸다.
const Duration autoEndIdle = Duration(minutes: 20);

/// 시속 30km 를 넘는 빠른 이동이 이 시간 이어지면 끝낸다 (결정 0018).
const Duration autoEndFast = Duration(seconds: 30);

/// 시작부터 이 시간이 지나면 기록 중이든 일시정지 중이든 끝낸다.
const Duration autoEndMax = Duration(hours: 6);

/// 자동 종료 기준 시간. 테스트·E2E 에서 provider 로 줄인다.
class RunGuardConfig {
  const RunGuardConfig({
    this.idle = autoEndIdle,
    this.max = autoEndMax,
    this.fast = autoEndFast,
  });

  final Duration idle;
  final Duration max;
  final Duration fast;
}

enum AutoEndReason { idle, maxDuration, fast }

class AutoEndDecision {
  const AutoEndDecision(this.reason, this.endAt);

  final AutoEndReason reason;

  /// 러닝의 끝 시각으로 삼을 시각. 이 뒤의 기록은 잘라낸다.
  final DateTime endAt;
}

/// 계속하면 null, 끝내야 하면 끝 시각을 담은 결정.
///
/// - 마지막 활동 = [lastPointAt](받아들인 마지막 점)과 [recordingSince]
///   (이번 기록 구간을 시작·재개한 시각) 중 늦은 쪽. 둘 다 없으면 [startedAt].
/// - [recording] 이고 [fastSince] 가 있고 `now − fastSince ≥ fast` 면
///   [beforeFastAt] ?? [recordingSince] ?? [startedAt] 에 끝낸다. 가장 먼저 본다.
/// - [recording] 이고 `now − 마지막 활동 ≥ idle` 이면 마지막 활동 시각에 끝낸다.
///   일시정지 중에는 적용하지 않는다.
/// - `now − startedAt ≥ max` 면 끝낸다. 점이 있으면 마지막 활동 시각, 없으면
///   [now] 에 끝낸다.
AutoEndDecision? checkAutoEnd({
  required DateTime now,
  required DateTime startedAt,
  required bool recording,
  required DateTime? lastPointAt,
  required DateTime? recordingSince,
  DateTime? fastSince,
  DateTime? beforeFastAt,
  RunGuardConfig config = const RunGuardConfig(),
}) {
  if (recording &&
      fastSince != null &&
      now.difference(fastSince) >= config.fast) {
    return AutoEndDecision(
      AutoEndReason.fast,
      beforeFastAt ?? recordingSince ?? startedAt,
    );
  }
  final activity = _latest(lastPointAt, recordingSince) ?? startedAt;
  if (recording && now.difference(activity) >= config.idle) {
    return AutoEndDecision(AutoEndReason.idle, activity);
  }
  if (now.difference(startedAt) >= config.max) {
    return AutoEndDecision(
      AutoEndReason.maxDuration,
      lastPointAt == null ? now : activity,
    );
  }
  return null;
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// 디버그 빌드의 `--dart-define` 초 값으로 만든 설정. 둘 다 비면 null.
/// 숫자가 아니거나 0 이하인 값은 기본값을 쓴다.
RunGuardConfig? runGuardConfigFromSeconds({
  required String idleSec,
  required String maxSec,
  String fastSec = '',
}) {
  if (idleSec.isEmpty && maxSec.isEmpty && fastSec.isEmpty) return null;
  Duration parse(String s, Duration fallback) {
    final n = int.tryParse(s);
    return n == null || n <= 0 ? fallback : Duration(seconds: n);
  }

  return RunGuardConfig(
    idle: parse(idleSec, autoEndIdle),
    max: parse(maxSec, autoEndMax),
    fast: parse(fastSec, autoEndFast),
  );
}
