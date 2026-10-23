import 'dart:async';

import '../../core/clock.dart';
import 'geo.dart';
import 'location_sample.dart';
import 'run_summary.dart';

const double _maxAccuracyM = 20;
const double _maxSpeedMps = 7;

/// 탈것으로 의심하는 평균 속도: 시속 22km (초속 6.1m, 1km 2분 44초, 결정 0033).
const double vehicleSpeedMps = 22 / 3.6;

/// 탈것 의심을 판정하는 창. 창 첫 점과 마지막 점 사이 직선 거리 ÷ 시간이
/// [vehicleSpeedMps] 를 넘으면 탈것 의심이다.
const Duration vehicleWindow = Duration(seconds: 30);

/// 기록 중 마지막 받아들인 점에서 이만큼(m) 안의 점은 받아들이지 않는다(거리에
/// 넣지 않는다). 위치 스트림은 거리 거름 없이 1초마다 점을 주고, 이 거름은 엔진이
/// 한다. 멈춰 서도 점이 와서 신호 끊김과 멈춤을 구별한다 (결정 0033).
const double minMoveM = 3;

/// 정확도 거름을 통과한 점이 이만큼 없으면 신호 끊김이다 (결정 0033).
const Duration signalLostAfter = Duration(seconds: 30);
const Duration _currentPaceWindow = Duration(seconds: 30);
const double _minPaceDistanceM = 10;
const Duration _staleSampleTolerance = Duration(seconds: 2);
const double _splitM = 1000;
const double _minLastSplitM = 1;

/// 마지막 움직인 점 뒤 이만큼 지나면 자동 일시정지한다 (결정 0020).
const Duration autoPauseStill = Duration(seconds: 10);

/// 직전 움직인 점에서 이만큼(m) 이상 떨어진 점이 움직인 점이다.
const double autoPauseStillM = 5;

/// 자동 재개를 판정하는 창. 창 안 첫 점과 마지막 점을 잰다.
const Duration autoResumeWindow = Duration(seconds: 10);

/// 창 안 첫 점과 마지막 점이 이만큼(m) 이상 떨어지면 움직임이다.
const double autoResumeMoveM = 10;

/// 창에 이만큼 점이 있어야 움직임으로 본다.
const int autoResumeMinPoints = 3;

/// [paused] 는 사용자 일시정지, [autoPaused] 는 멈춰서 된 자동 일시정지다.
/// [vehicle] 은 탈것 의심, [signalLost] 는 신호 끊김이다(결정 0033). 둘 다
/// 자동 일시정지처럼 시간·거리를 멈추고 스스로 풀린다.
enum RunState {
  idle,
  recording,
  paused,
  autoPaused,
  vehicle,
  signalLost,
  ended,
}

/// 위치를 받으며 스스로 풀리는 멈춤 상태. 사용자가 재개·일시정지할 수 있다.
const Set<RunState> autoStoppedStates = {
  RunState.autoPaused,
  RunState.vehicle,
  RunState.signalLost,
};

/// 끝나지 않은 러닝 상태(시작 뒤, 종료 전).
const Set<RunState> activeRunStates = {
  RunState.recording,
  RunState.paused,
  ...autoStoppedStates,
};

sealed class RunEvent {}

class StateChanged extends RunEvent {
  StateChanged(this.from, this.to);

  final RunState from;
  final RunState to;
}

class SplitCompleted extends RunEvent {
  SplitCompleted(this.split);

  final Split split;
}

class RunEnded extends RunEvent {
  RunEnded(this.summary);

  final RunSummary summary;
}

class RunSnapshot {
  const RunSnapshot({
    required this.state,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    required this.currentPaceSecPerKm,
    required this.splits,
  });

  final RunState state;
  final double distanceM;
  final Duration movingTime;

  /// 거리 10m 미만이면 null.
  final double? avgPaceSecPerKm;

  /// 최근 30초 구간 거리 10m 미만이면 null.
  final double? currentPaceSecPerKm;
  final List<Split> splits;
}

class RunEngine {
  /// [startedAt] 을 주면 복원 모드다. `paused` 로 시작하고 [restoredSegments]
  /// 로 거리를 다시 계산한다. [restoredMovingTime] 을 주면 그 값이 움직인
  /// 시간이고, 없으면 구간마다 (마지막 점 − 첫 점 시각) 의 합이다.
  RunEngine({
    required this._clock,
    this._startedAt,
    List<List<LocationSample>> restoredSegments = const [],
    Duration? restoredMovingTime,
  }) {
    if (_startedAt == null) {
      if (restoredSegments.isNotEmpty || restoredMovingTime != null) {
        throw ArgumentError('복원에는 startedAt 이 필요하다.');
      }
      return;
    }
    for (final segment in restoredSegments) {
      if (segment.isEmpty) continue;
      _segmentPending = true;
      segment.forEach(_append);
    }
    _movingBase = restoredMovingTime ?? _sampleMovingTime;
    _state = RunState.paused;
    _stateSince = _clock();
    _pausedAt = _lastAccepted?.time ?? _startedAt;
  }

  final Clock _clock;
  final _events = StreamController<RunEvent>.broadcast();

  DateTime? _startedAt;
  RunState _state = RunState.idle;

  /// 채택한 점. 빈 구간은 없다.
  final List<List<LocationSample>> _segments = [];

  /// `start`·`resume` 뒤 첫 점이 채택되면 새 구간을 만든다.
  bool _segmentPending = true;

  /// 현재 구간 각 점까지의 구간 안 누적 거리(m).
  List<double> _segmentCumulativeM = [];
  double _distanceM = 0;
  LocationSample? _lastAccepted;

  /// 정확도 거름을 통과한 최근 원시 점. 탈것 의심 평균 속도를 잰다. 맨 앞 점은
  /// 창 시작([vehicleWindow] 전) 이전의 가장 늦은 점이다. 사용자 일시정지·재개와
  /// 신호 끊김에 비우고, 멈춤·움직임·탈것 의심 전이에는 남긴다.
  final List<LocationSample> _speedWindow = [];

  /// 마지막 받아들인 점에서 [vehicleSpeedMps] 보다 빨리 멀어지고 있는 점.
  /// 탈것 의심이 되면 버리고, 다시 느린 점이 오면 그 점과 함께 받아들인다.
  final List<LocationSample> _held = [];

  /// 점을 미루기 시작한 순간의 마지막 받아들인 점 시각(이번 기록 구간 시작보다
  /// 앞이면 시작). 미루는 동안 움직인 시간은 여기서 멈추고, 미룬 점을 받아들이면
  /// 그 시간을 더하고 버리면 함께 버린다. 미룬 점이 없으면 null.
  DateTime? _holdFrom;

  /// 정확도 거름을 통과한 마지막 점의 시각. 없으면 위치를 받기 시작한 시각.
  DateTime? _lastSignalAt;

  /// 끝난 탈것 의심 구간 시간의 합.
  Duration _vehicleBase = Duration.zero;

  /// 첫 탈것 의심 구간이 시작되기 전 마지막 정상 점의 시각.
  DateTime? _firstVehicleAt;

  Duration _movingBase = Duration.zero;
  DateTime? _recordingSince;
  DateTime? _stateSince;
  DateTime? _pausedAt;

  /// 이번 기록 구간의 마지막 움직인 점. 없으면 첫 받아들인 점이 기준이다.
  LocationSample? _moveAnchor;

  /// 마지막 움직인 점의 시각. 없으면 기록 구간 시작 시각.
  DateTime? _movedAt;

  /// 자동 일시정지 중 정확도 거름을 통과한 최근 [autoResumeWindow] 의 점.
  final List<LocationSample> _resumeWindow = [];
  List<LocationSample> _lastAppended = const [];

  /// 구간마다 (마지막 점 − 첫 점 시각) 의 합. 구간 기록 시간의 기준이다.
  Duration _sampleMovingTime = Duration.zero;

  /// 완료한 1km 구간.
  final List<Split> _splits = [];

  /// 마지막 1km 경계를 지난 시점의 [_sampleMovingTime].
  Duration _lastBoundaryTime = Duration.zero;

  Stream<RunEvent> get events => _events.stream;

  /// 다음에 채택될 점이 받을 구간 번호.
  int get segmentIndex =>
      _segmentPending ? _segments.length : _segments.length - 1;

  RunState get state => _state;

  /// 시작 시각. 시작 전이면 null.
  DateTime? get startedAt => _startedAt;

  /// 이번 기록 구간을 시작·재개한 시각. 기록 중이 아니면 null.
  DateTime? get recordingSince => _recordingSince;

  /// 지금 상태에 들어온 시각. 시작 전이면 null.
  DateTime? get stateSince => _stateSince;

  /// 기록이 멈춘 시각. 자동 일시정지에서 사용자 일시정지로 바뀌어도 처음
  /// 값을 유지한다. 복원한 러닝은 마지막 점(없으면 시작) 시각. 기록 중이면 null.
  DateTime? get pausedAt => _pausedAt;

  /// 마지막 [addSample] 호출이 구간에 넣은 점. 자동 재개면 여러 개다.
  List<LocationSample> get lastAppended => _lastAppended;

  /// 마지막으로 받아들인 점(복원한 점 포함)의 시각. 없으면 null.
  DateTime? get lastPointAt => _lastAccepted?.time;

  /// 정확도 거름을 통과한 마지막 점의 시각. 위치를 받기 시작한 뒤 점이 없으면
  /// 그 시각(시작·재개). 복원한 뒤 재개 전이면 null.
  DateTime? get lastSignalAt => _lastSignalAt;

  /// 이번 러닝에서 탈것 의심 상태였던 시간의 합. 지금 의심 중이면 [now] 까지 센다.
  Duration vehicleTime(DateTime now) {
    if (_state != RunState.vehicle) return _vehicleBase;
    final since = _stateSince!;
    return _vehicleBase +
        (now.isAfter(since) ? now.difference(since) : Duration.zero);
  }

  /// 첫 탈것 의심 구간이 시작되기 전 마지막 정상 점의 시각(받아들인 점이 없었으면
  /// 그 기록 구간을 시작·재개한 시각). 의심한 적이 없으면 null.
  DateTime? get firstVehicleAt => _firstVehicleAt;

  /// 받아들이기를 미룬 빠른 점([vehicleSpeedMps] 초과로 멀어지는 점)의 수.
  int get heldCount => _held.length;

  List<List<LocationSample>> get segments => List.unmodifiable([
    for (final segment in _segments) List<LocationSample>.unmodifiable(segment),
  ]);

  RunSnapshot get snapshot {
    final movingTime = _movingTime();
    return RunSnapshot(
      state: _state,
      distanceM: _distanceM,
      movingTime: movingTime,
      avgPaceSecPerKm: _pace(movingTime, _distanceM),
      currentPaceSecPerKm: _currentPace(),
      splits: List.unmodifiable(_splits),
    );
  }

  /// 자동 일시정지가 되돌려도 남는 움직인 시간. 기록 중이면 마지막으로 움직인
  /// 시각까지만 센다(서 있던 10초 창은 자동 일시정지 때 빠진다). 기록 중이 아니면
  /// [snapshot] 의 움직인 시간과 같다. 시간 목표 달성은 이 값으로 판정한다.
  Duration get confirmedMovingTime {
    final since = _recordingSince;
    if (since == null) return _movingBase;
    final now = _recordedUntil(_clock());
    var movedAt = _movedAt ?? since;
    if (movedAt.isBefore(since)) movedAt = since;
    if (movedAt.isAfter(now)) movedAt = now;
    return _movingBase + movedAt.difference(since);
  }

  void start() {
    _startedAt = _transition(RunState.idle, RunState.recording);
  }

  /// 기록 중이나 자동 일시정지·탈것 의심·신호 끊김 중에 사용자 일시정지한다.
  /// 받아들이기를 미룬 점은 버린다.
  void pause() {
    _transition(
      autoStoppedStates.contains(_state) ? _state : RunState.recording,
      RunState.paused,
    );
  }

  /// 사용자 일시정지나 자동 일시정지·탈것 의심·신호 끊김에서 재개한다.
  void resume() {
    _transition(
      autoStoppedStates.contains(_state) ? _state : RunState.paused,
      RunState.recording,
    );
  }

  /// 기록 중이고 마지막 움직인 점(없으면 기록 구간 시작) 뒤 [autoPauseStill]
  /// 이 지났으면 그 시각으로 자동 일시정지하고 true. 받아들이기를 미룬 빠른 점이
  /// [autoPauseStill] 안에 왔으면 움직이는 중이므로 하지 않는다(탈것 의심이 맡는다).
  /// 미룬 점은 버린다.
  bool autoPauseIfStill(DateTime now) {
    if (_state != RunState.recording) return false;
    final heldAt = _held.lastOrNull?.time;
    if (heldAt != null && now.difference(heldAt) < autoPauseStill) {
      return false;
    }
    final movedAt = _stillSince();
    if (now.difference(movedAt) < autoPauseStill) return false;
    _transition(
      RunState.recording,
      RunState.autoPaused,
      at: movedAt,
      auto: true,
    );
    return true;
  }

  /// 기록 중·자동 일시정지·탈것 의심 중 정확도 거름을 통과한 점이
  /// [signalLostAfter] 동안 없으면 신호 끊김으로 바꾸고 true (결정 0033).
  ///
  /// 점이 끊겨도 [autoPauseStill] 에 먼저 자동 일시정지한다(거리 거름 때문에
  /// 멈춰 서도 점이 오지 않을 수 있다). 그 뒤에도 점이 없으면 이것이 자동
  /// 일시정지를 바꾼다. 기록 중이면 마지막 움직인 점, 아니면 마지막 점(지금 상태에
  /// 들어온 시각보다 앞이면 그 시각)으로 바꾼다. 기록이 멈춘 시각([pausedAt])은
  /// 처음 멈춘 시각을 그대로 둔다.
  bool signalLostIfSilent(DateTime now) {
    final from = _state;
    if (from != RunState.recording &&
        from != RunState.autoPaused &&
        from != RunState.vehicle) {
      return false;
    }
    final lastSignal = _lastSignalAt ?? _stateSince!;
    if (now.difference(lastSignal) < signalLostAfter) return false;
    final DateTime at;
    if (from == RunState.recording) {
      at = _stillSince();
    } else {
      final since = _stateSince!;
      at = lastSignal.isAfter(since) ? lastSignal : since;
    }
    _transition(from, RunState.signalLost, at: at, auto: true);
    return true;
  }

  /// 기록 중 마지막 움직인 시각. 이번 기록 구간 시작보다 앞이면 시작 시각.
  DateTime _stillSince() {
    final since = _recordingSince!;
    final movedAt = _movedAt!;
    return movedAt.isBefore(since) ? since : movedAt;
  }

  /// 끝나지 않은 러닝([activeRunStates])을 끝낸다. 남은 거리가 1m
  /// 이상이면 마지막 구간으로 넣고 `RunEnded` 를 낸 뒤 `ended` 로 바꾸고
  /// 이벤트 스트림을 닫는다. `clock()` 은 한 번만 읽는다. 받아들이기를 미룬 점은
  /// 넣지 않는다.
  RunSummary end({double weightKg = defaultWeightKg}) {
    if (!activeRunStates.contains(_state)) {
      throw StateError('Cannot go from $_state to ${RunState.ended}');
    }
    final remainingM = _distanceM - _splits.length * _splitM;
    final splits = List<Split>.unmodifiable([
      ..._splits,
      if (remainingM >= _minLastSplitM)
        Split(
          index: _splits.length + 1,
          distanceM: remainingM,
          duration: _sampleMovingTime - _lastBoundaryTime,
        ),
    ]);
    final startedAt = _startedAt!;
    final now = _clock();
    final movingTime = _movingTime(now);
    final summary = RunSummary(
      startedAt: startedAt,
      endedAt: now,
      distanceM: _distanceM,
      movingTime: movingTime,
      avgPaceSecPerKm: _pace(movingTime, _distanceM),
      calories: estimateCalories(_distanceM, weightKg: weightKg),
      name: autoRunName(startedAt),
      splits: splits,
      points: List.unmodifiable([for (final s in _segments) ...s]),
      segments: segments,
    );
    _events.add(RunEnded(summary));
    _transition(_state, RunState.ended, at: now);
    _events.close();
    return summary;
  }

  /// 채택하면 true. 넣은 점은 [lastAppended] 이고 여러 개일 수 있다.
  ///
  /// - 기록 중: 최근 [vehicleWindow] 평균 속도가 [vehicleSpeedMps] 를 넘으면
  ///   마지막 받아들인 점(정상 점) 시각으로 탈것 의심으로 바꾼다. 마지막 받아들인
  ///   점에서 그보다 빨리 멀어지는 점은 받아들이기를 미루고, 느린 점이 오면 함께
  ///   받아들인다(의심이 되면 버린다).
  /// - 자동 일시정지: 점을 창에 모으고, 움직임이면 창의 첫 점 시각으로 재개해
  ///   창의 점을 새 구간에 넣는다.
  /// - 탈것 의심: 평균 속도가 [vehicleSpeedMps] 이하로 내려오면 그 점 시각으로
  ///   재개하고 그 점부터 새 구간에 넣는다.
  /// - 신호 끊김: 점이 오면 그 점 시각으로 재개하고 그 점부터 새 구간에 넣는다.
  ///   끊기기 전 마지막 점과의 거리는 더하지 않는다.
  bool addSample(LocationSample s) {
    _lastAppended = const [];
    if (s.accuracy > _maxAccuracyM) return false;
    switch (_state) {
      case RunState.autoPaused:
        _track(s);
        return _collectWhileStill(s);
      case RunState.vehicle:
        _track(s);
        return _leaveVehicleIfSlow(s);
      case RunState.signalLost:
        return _recoverSignal(s);
      case RunState.recording:
        if (s.time.isBefore(_recordingSince!.subtract(_staleSampleTolerance))) {
          return false;
        }
        _track(s);
        if (_enterVehicleIfFast()) return false;
        _lastAppended = _offer(s);
        return _lastAppended.isNotEmpty;
      case RunState.idle || RunState.paused || RunState.ended:
        return false;
    }
  }

  /// 최근 평균 속도가 [vehicleSpeedMps] 를 넘으면 탈것 의심으로 바꾸고 true.
  /// 바꾸는 시각은 마지막 받아들인 점이고, 이번 기록 구간에 받아들인 점이 없으면
  /// 구간을 시작·재개한 시각이다. 미룬 점은 버린다.
  bool _enterVehicleIfFast() {
    final speed = _windowSpeed();
    if (speed == null || speed <= vehicleSpeedMps) return false;
    final since = _recordingSince!;
    final last = _lastAccepted?.time;
    final at = last == null || last.isBefore(since) ? since : last;
    _transition(RunState.recording, RunState.vehicle, at: at, auto: true);
    _firstVehicleAt ??= at;
    return true;
  }

  /// 탈것 의심 중 평균 속도가 [vehicleSpeedMps] 이하로 내려오면 [s] 시각으로
  /// 재개하고 [s] 를 새 구간 첫 점으로 받아들인다.
  bool _leaveVehicleIfSlow(LocationSample s) {
    if (!s.time.isAfter(_stateSince!)) return false;
    final speed = _windowSpeed();
    if (speed == null || speed > vehicleSpeedMps) return false;
    _transition(RunState.vehicle, RunState.recording, at: s.time, auto: true);
    _lastAppended = _offer(s);
    return _lastAppended.isNotEmpty;
  }

  /// 신호 끊김 중 점이 오면 그 시각으로 재개하고 새 구간 첫 점으로 받아들인다.
  bool _recoverSignal(LocationSample s) {
    final last = _lastAccepted?.time;
    if (!s.time.isAfter(_stateSince!) ||
        (last != null && !s.time.isAfter(last))) {
      return false;
    }
    _transition(
      RunState.signalLost,
      RunState.recording,
      at: s.time,
      auto: true,
    );
    _track(s);
    _lastAppended = _offer(s);
    return _lastAppended.isNotEmpty;
  }

  /// 정확도 거름을 통과한 점을 신호와 평균 속도 창에 넣는다. 거리와는 무관하다.
  void _track(LocationSample s) {
    final lastSignal = _lastSignalAt;
    if (lastSignal == null || s.time.isAfter(lastSignal)) {
      _lastSignalAt = s.time;
    }
    final window = _speedWindow;
    if (window.isNotEmpty && !s.time.isAfter(window.last.time)) return;
    window.add(s);
    final boundary = s.time.subtract(vehicleWindow);
    while (window.length >= 2 && !window[1].time.isAfter(boundary)) {
      window.removeAt(0);
    }
  }

  /// 창이 [vehicleWindow] 이상이면 창 첫 점과 마지막 점 사이 직선 거리 ÷ 시간
  /// (m/s). 창이 짧으면 null. 제자리 흔들림이나 굽은 길에 부풀지 않게 직선 거리를 쓴다.
  double? _windowSpeed() {
    final window = _speedWindow;
    if (window.length < 2) return null;
    final span = window.last.time.difference(window.first.time);
    if (span < vehicleWindow) return null;
    return _distance(window.first, window.last) /
        (span.inMicroseconds / Duration.microsecondsPerSecond);
  }

  /// 기록 중 점 [s] 를 받아들이거나 미룬다. 받아들인 점(미뤘던 점 포함)을 돌려준다.
  ///
  /// 이번 구간에 점이 있고 마지막 받아들인 점에서 [s] 까지 평균 속도가
  /// [vehicleSpeedMps] 를 넘으면 미룬다. 아니면 미룬 점과 [s] 를 차례로 튀는 값
  /// 거름에 걸러 받아들인다. 미룬 지 [vehicleWindow] 가 지나도 탈것 의심이 아니면
  /// 의심할 근거가 없으므로 받아들인다.
  List<LocationSample> _offer(LocationSample s) {
    final ref = _lastAccepted;
    final held = _held;
    if (!_segmentPending && ref != null) {
      final dt = s.time.difference(ref.time);
      if (dt > Duration.zero &&
          _distance(ref, s) /
                  (dt.inMicroseconds / Duration.microsecondsPerSecond) >
              vehicleSpeedMps) {
        if (held.isEmpty) {
          final since = _recordingSince!;
          _holdFrom = ref.time.isBefore(since) ? since : ref.time;
        }
        if (held.isEmpty || s.time.isAfter(held.last.time)) held.add(s);
        if (s.time.difference(held.first.time) < vehicleWindow) {
          return const [];
        }
        final points = List.of(held);
        _clearHeld();
        return [
          for (final p in points)
            if (_accept(p)) p,
        ];
      }
    }
    final points = [...held, s];
    _clearHeld();
    return [
      for (final p in points)
        if (_accept(p)) p,
    ];
  }

  /// 움직임이면 재개하고 창의 점을 차례로 받아들인다. 하나라도 넣으면 true.
  bool _collectWhileStill(LocationSample s) {
    final window = _resumeWindow;
    final lastAt = _lastAccepted?.time;
    if (!s.time.isAfter(window.isEmpty ? _stateSince! : window.last.time) ||
        (lastAt != null && !s.time.isAfter(lastAt))) {
      return false;
    }
    window
      ..add(s)
      ..removeWhere((p) => s.time.difference(p.time) > autoResumeWindow);
    if (window.length < autoResumeMinPoints ||
        _distance(window.first, window.last) < autoResumeMoveM) {
      return false;
    }
    final points = List.of(window);
    _transition(
      RunState.autoPaused,
      RunState.recording,
      at: points.first.time,
      auto: true,
    );
    _lastAppended = [for (final p in points) ..._offer(p)];
    return _lastAppended.isNotEmpty;
  }

  /// 정확도·오래된 점 거름을 통과한 기록 중 점을 튀는 값 거름에 걸러
  /// 받아들이면 true. 움직인 점이면 [_movedAt] 을 옮긴다.
  bool _accept(LocationSample s) {
    final last = _lastAccepted;
    if (last != null) {
      final dt = s.time.difference(last.time);
      if (dt <= Duration.zero) return false;
      if (!_segmentPending) {
        final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
        final d = _distance(last, s);
        // 좌표 계산 오차(1mm 미만)로 3m 이동이 3m 아래로 재지는 것은 받아들인다.
        if (d / seconds > _maxSpeedMps || d < minMoveM - 0.001) return false;
      }
    }
    _append(s);
    final anchor = _moveAnchor;
    if (anchor == null) {
      _moveAnchor = s;
    } else if (_distance(anchor, s) >= autoPauseStillM) {
      _moveAnchor = s;
      _movedAt = s.time;
    }
    return true;
  }

  void _append(LocationSample s) {
    if (_segmentPending) {
      _segments.add([]);
      _segmentCumulativeM = [];
      _segmentPending = false;
    }
    final segment = _segments.last;
    final d = segment.isEmpty ? 0.0 : _advance(segment.last, s);
    _segmentCumulativeM.add(
      (_segmentCumulativeM.isEmpty ? 0.0 : _segmentCumulativeM.last) + d,
    );
    segment.add(s);
    _lastAccepted = s;
  }

  /// 같은 구간의 [prev] 에서 [s] 까지 거리·시간을 더하고 그 거리를 돌려준다.
  /// 1km 경계를 지나면 두 점 사이를 선형 보간한 시각으로 구간을 닫는다.
  /// 기록 중에 지난 경계만 `SplitCompleted` 를 낸다 (복원 중에는 내지 않는다).
  double _advance(LocationSample prev, LocationSample s) {
    final d = _distance(prev, s);
    final dt = s.time.difference(prev.time);
    while (d > 0 && _distanceM + d >= (_splits.length + 1) * _splitM) {
      final fraction = ((_splits.length + 1) * _splitM - _distanceM) / d;
      final boundaryTime =
          _sampleMovingTime +
          Duration(microseconds: (dt.inMicroseconds * fraction).round());
      final split = Split(
        index: _splits.length + 1,
        distanceM: _splitM,
        duration: boundaryTime - _lastBoundaryTime,
      );
      _splits.add(split);
      _lastBoundaryTime = boundaryTime;
      if (_state == RunState.recording) _events.add(SplitCompleted(split));
    }
    _distanceM += d;
    _sampleMovingTime += dt;
    return d;
  }

  /// 전이 시각([at], 없으면 `clock()`)을 돌려준다. [auto] 는 멈춤·움직임·
  /// 탈것 의심·신호 끊김으로 바뀐 전이다. 위치를 계속 받으므로 평균 속도 창을
  /// 비우지 않는다(신호 끊김은 끊긴 사이가 평균에 들어가지 않게 비운다).
  /// 기록 중을 벗어나면 받아들이기를 미룬 점을 버린다.
  DateTime _transition(
    RunState from,
    RunState to, {
    DateTime? at,
    bool auto = false,
  }) {
    if (_state != from) {
      throw StateError('Cannot go from $_state to $to');
    }
    final now = at ?? _clock();
    if (!auto || to == RunState.signalLost) _speedWindow.clear();
    if (!auto && to == RunState.recording) _lastSignalAt = now;
    final recordedUntil = _recordedUntil(now);
    _clearHeld();
    if (from == RunState.vehicle) {
      final since = _stateSince!;
      if (now.isAfter(since)) _vehicleBase += now.difference(since);
    }
    _resumeWindow.clear();
    if (from == RunState.recording) {
      _movingBase += recordedUntil.difference(_recordingSince!);
      _recordingSince = null;
      _pausedAt = now;
    }
    if (to == RunState.recording) {
      _recordingSince = now;
      _segmentPending = true;
      _pausedAt = null;
      _moveAnchor = null;
      _movedAt = now;
    }
    _state = to;
    _stateSince = now;
    _events.add(StateChanged(from, to));
    return now;
  }

  Duration _movingTime([DateTime? at]) {
    final since = _recordingSince;
    return since == null
        ? _movingBase
        : _movingBase + _recordedUntil(at ?? _clock()).difference(since);
  }

  /// 움직인 시간을 [at] 까지 센다. 점을 미루는 중이면 미루기 시작한 시각까지다.
  DateTime _recordedUntil(DateTime at) {
    final hold = _holdFrom;
    return hold != null && hold.isBefore(at) ? hold : at;
  }

  void _clearHeld() {
    _held.clear();
    _holdFrom = null;
  }

  /// 현재 구간에서 `clock()` 까지 최근 30초 창의 시간 ÷ 거리.
  /// 창 시간은 창 안 첫 점 시각부터 `clock()` 까지다. 기록 중이 아니면 null.
  double? _currentPace() {
    if (_state != RunState.recording || _segmentPending) return null;
    final now = _clock();
    final points = _segments.last;
    final windowStart = now.subtract(_currentPaceWindow);
    final first = points.indexWhere((p) => !p.time.isBefore(windowStart));
    if (first == -1) return null;
    return _pace(
      now.difference(points[first].time),
      _segmentCumulativeM.last - _segmentCumulativeM[first],
    );
  }

  static double? _pace(Duration time, double distanceM) {
    if (distanceM < _minPaceDistanceM) return null;
    return time.inMicroseconds /
        Duration.microsecondsPerSecond /
        (distanceM / 1000);
  }

  static double _distance(LocationSample a, LocationSample b) =>
      haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);
}
