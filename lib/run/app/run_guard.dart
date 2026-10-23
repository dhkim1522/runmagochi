// 러닝 자동 종료 규칙 (결정 0016·0020·0033).

import '../domain/run_engine.dart';

/// 자동 일시정지가 이 시간 이어지면 예고한다 (결정 0020).
const Duration autoEndStill = Duration(minutes: 5);

/// 사용자 일시정지가 이 시간 이어지면 예고한다 (결정 0020).
const Duration autoEndPaused = Duration(hours: 1);

/// 예고한 뒤 이 시간이 지나도 그대로면 끝낸다 (결정 0020).
const Duration autoEndWarning = Duration(seconds: 30);

/// 이번 러닝의 탈것 의심 시간이 모두 합해 이만큼이면 끝낸다 (결정 0033).
const Duration autoEndVehicle = Duration(minutes: 2);

/// 시작부터 이 시간이 지나면 어느 상태든 끝낸다.
const Duration autoEndMax = Duration(hours: 6);

/// 자동 종료 기준 시간. 테스트·E2E 에서 provider 로 줄인다.
class RunGuardConfig {
  const RunGuardConfig({
    this.still = autoEndStill,
    this.paused = autoEndPaused,
    this.warning = autoEndWarning,
    this.max = autoEndMax,
    this.vehicle = autoEndVehicle,
  });

  final Duration still;
  final Duration paused;
  final Duration warning;
  final Duration max;
  final Duration vehicle;
}

/// [still] 자동 일시정지, [paused] 사용자 일시정지, [signalLost] 신호 끊김이
/// 오래 이어짐, [vehicle] 탈것 의심 합계, [maxDuration] 시작부터 상한.
enum AutoEndReason { still, paused, maxDuration, vehicle, signalLost }

class AutoEndDecision {
  const AutoEndDecision(this.reason, this.endAt);

  final AutoEndReason reason;

  /// 러닝의 끝 시각으로 삼을 시각. 이 뒤의 기록은 잘라낸다.
  final DateTime endAt;
}

/// [state] 에서 예고를 시작하기까지의 시간. 오래 멈춤 규칙이 없는 상태면 null.
/// 신호 끊김은 자동 일시정지와 같은 시간이다 (결정 0033).
Duration? _stillLimit(RunState state, RunGuardConfig config) => switch (state) {
  RunState.autoPaused || RunState.signalLost => config.still,
  RunState.paused => config.paused,
  _ => null,
};

/// 계속하면 null, 끝내야 하면 끝 시각을 담은 결정. 위에서부터 본다.
///
/// - 탈것 의심 중이고 이번 러닝의 의심 시간 합 [vehicleTime] 이 `vehicle` 이상이면
///   [AutoEndReason.vehicle] 로 첫 의심 구간 전 마지막 정상 점 [vehicleEndAt]
///   (없으면 [pausedAt]) 에 끝낸다.
/// - 자동 일시정지·신호 끊김이고 `now − stateSince ≥ still + warning` 이면
///   [AutoEndReason.still]·[AutoEndReason.signalLost], 사용자 일시정지이고
///   `≥ paused + warning` 이면 [AutoEndReason.paused] 로 [pausedAt](기록이 멈춘
///   시각)에 끝낸다.
/// - `now − startedAt ≥ max` 면 끝낸다. 점이 있으면 마지막 활동 시각
///   ([lastPointAt] 과 [recordingSince] 중 늦은 쪽), 없으면 [now] 에 끝낸다.
AutoEndDecision? checkAutoEnd({
  required DateTime now,
  required DateTime startedAt,
  required RunState state,
  required DateTime? pausedAt,
  required DateTime? stateSince,
  required DateTime? lastPointAt,
  required DateTime? recordingSince,
  Duration vehicleTime = Duration.zero,
  DateTime? vehicleEndAt,
  RunGuardConfig config = const RunGuardConfig(),
}) {
  if (state == RunState.vehicle && vehicleTime >= config.vehicle) {
    return AutoEndDecision(
      AutoEndReason.vehicle,
      vehicleEndAt ?? pausedAt ?? stateSince ?? startedAt,
    );
  }
  final limit = _stillLimit(state, config);
  if (limit != null &&
      stateSince != null &&
      now.difference(stateSince) >= limit + config.warning) {
    return AutoEndDecision(switch (state) {
      RunState.autoPaused => AutoEndReason.still,
      RunState.signalLost => AutoEndReason.signalLost,
      _ => AutoEndReason.paused,
    }, pausedAt ?? stateSince);
  }
  if (now.difference(startedAt) >= config.max) {
    final activity = _latest(lastPointAt, recordingSince) ?? startedAt;
    return AutoEndDecision(
      AutoEndReason.maxDuration,
      lastPointAt == null ? now : activity,
    );
  }
  return null;
}

/// 오래 멈춤 규칙의 예고 구간(`limit ≤ now − stateSince < limit + warning`)
/// 이면 끝날 시각(`stateSince + limit + warning`), 아니면 null.
DateTime? autoEndWarningDeadline({
  required DateTime now,
  required RunState state,
  required DateTime? stateSince,
  RunGuardConfig config = const RunGuardConfig(),
}) {
  final limit = _stillLimit(state, config);
  if (limit == null || stateSince == null) return null;
  final stopped = now.difference(stateSince);
  if (stopped < limit || stopped >= limit + config.warning) return null;
  return stateSince.add(limit + config.warning);
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// 디버그 빌드의 `--dart-define` 초 값으로 만든 설정. 모두 비면 null.
/// 숫자가 아니거나 0 이하인 값은 기본값을 쓴다.
RunGuardConfig? runGuardConfigFromSeconds({
  String stillSec = '',
  String pausedSec = '',
  String warningSec = '',
  String maxSec = '',
  String vehicleSec = '',
}) {
  if ([
    stillSec,
    pausedSec,
    warningSec,
    maxSec,
    vehicleSec,
  ].every((s) => s.isEmpty)) {
    return null;
  }
  Duration parse(String s, Duration fallback) {
    final n = int.tryParse(s);
    return n == null || n <= 0 ? fallback : Duration(seconds: n);
  }

  return RunGuardConfig(
    still: parse(stillSec, autoEndStill),
    paused: parse(pausedSec, autoEndPaused),
    warning: parse(warningSec, autoEndWarning),
    max: parse(maxSec, autoEndMax),
    vehicle: parse(vehicleSec, autoEndVehicle),
  );
}
