import 'dart:async';

import '../../core/clock.dart';
import 'geo.dart';
import 'location_sample.dart';
import 'run_summary.dart';

const double _maxAccuracyM = 20;
const double _maxSpeedMps = 7;

/// 빠른 이동으로 보는 속도: 시속 30km (초속 8.33m).
const double fastSpeedMps = 30 / 3.6;
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
enum RunState { idle, recording, paused, autoPaused, ended }

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

  /// 정확도 거름을 통과한 직전 원시 점. 빠른 이동 속도를 잰다.
  /// 사용자 일시정지·재개하면 비우고, 멈춤·움직임 전이에는 남긴다.
  LocationSample? _lastRaw;
  DateTime? _fastSince;
  DateTime? _fastLastAt;
  DateTime? _lastAcceptedBeforeFast;

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

  /// 빠른 이동(시속 30km 초과)이 이어지기 시작한 시각, 곧 그 연속의 첫 빠른
  /// 점의 시각. 빠른 이동 중이 아니면 null.
  DateTime? get fastSince => _fastSince;

  /// 이 연속의 가장 최근 빠른 점의 시각. 빠른 이동 시간은 [fastSince] 부터
  /// 이 시각까지로 재며 벽시계는 쓰지 않는다. 빠른 이동 중이 아니면 null.
  DateTime? get fastLastAt => _fastLastAt;

  /// [fastSince] 를 잡은 순간 마지막으로 받아들인 점의 시각. 없으면 null.
  DateTime? get lastAcceptedBeforeFast => _lastAcceptedBeforeFast;

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
    final now = _clock();
    var movedAt = _movedAt ?? since;
    if (movedAt.isBefore(since)) movedAt = since;
    if (movedAt.isAfter(now)) movedAt = now;
    return _movingBase + movedAt.difference(since);
  }

  void start() {
    _startedAt = _transition(RunState.idle, RunState.recording);
  }

  /// 기록 중이나 자동 일시정지 중에 사용자 일시정지한다.
  void pause() {
    _transition(
      _state == RunState.autoPaused ? RunState.autoPaused : RunState.recording,
      RunState.paused,
    );
  }

  /// 사용자 일시정지나 자동 일시정지에서 재개한다.
  void resume() {
    _transition(
      _state == RunState.autoPaused ? RunState.autoPaused : RunState.paused,
      RunState.recording,
    );
  }

  /// 기록 중이고 마지막 움직인 점(없으면 기록 구간 시작) 뒤 [autoPauseStill]
  /// 이 지났으면 그 시각으로 자동 일시정지하고 true. 마지막 빠른 점 뒤
  /// [autoPauseStill] 이 지나기 전에는 멈춘 것이 아니므로 하지 않는다(빠른
  /// 이동 자동 종료가 맡는다).
  bool autoPauseIfStill(DateTime now) {
    if (_state != RunState.recording) return false;
    final fastLastAt = _fastLastAt;
    if (fastLastAt != null && now.difference(fastLastAt) < autoPauseStill) {
      return false;
    }
    final since = _recordingSince!;
    final movedAt = _movedAt!.isBefore(since) ? since : _movedAt!;
    if (now.difference(movedAt) < autoPauseStill) return false;
    _transition(
      RunState.recording,
      RunState.autoPaused,
      at: movedAt,
      auto: true,
    );
    return true;
  }

  /// 기록 중이나 일시정지·자동 일시정지 중에 끝낸다. 남은 거리가 1m
  /// 이상이면 마지막 구간으로 넣고 `RunEnded` 를 낸 뒤 `ended` 로 바꾸고
  /// 이벤트 스트림을 닫는다. `clock()` 은 한 번만 읽는다.
  RunSummary end({double weightKg = defaultWeightKg}) {
    if (_state != RunState.recording &&
        _state != RunState.paused &&
        _state != RunState.autoPaused) {
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

  /// 채택하면 true. 자동 일시정지 중에는 점을 창에 모으고, 움직임이면 창의
  /// 첫 점 시각으로 재개해 창의 점을 새 구간에 넣는다. 넣은 점은 [lastAppended].
  /// 빠른 이동은 자동 일시정지 중에도 잰다.
  bool addSample(LocationSample s) {
    _lastAppended = const [];
    if (s.accuracy > _maxAccuracyM) return false;
    if (_state == RunState.autoPaused) {
      _trackFast(s);
      return _collectWhileStill(s);
    }
    if (_state != RunState.recording) return false;
    if (s.time.isBefore(_recordingSince!.subtract(_staleSampleTolerance))) {
      return false;
    }
    _trackFast(s);
    if (!_accept(s)) return false;
    _lastAppended = [s];
    return true;
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
    _lastAppended = [
      for (final p in points)
        if (_accept(p)) p,
    ];
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
        if (_distance(last, s) / seconds > _maxSpeedMps) return false;
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

  /// 직전 원시 점과의 속도로 빠른 이동 연속을 갱신한다. 거리 계산과 무관하다.
  void _trackFast(LocationSample s) {
    final prev = _lastRaw;
    if (prev != null) {
      final dt = s.time.difference(prev.time);
      if (dt <= Duration.zero) return;
      final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
      if (_distance(prev, s) / seconds > fastSpeedMps) {
        _fastLastAt = s.time;
        if (_fastSince == null) {
          _fastSince = s.time;
          _lastAcceptedBeforeFast = _lastAccepted?.time;
        }
      } else {
        _resetFast();
      }
    }
    _lastRaw = s;
  }

  void _resetFast() {
    _fastSince = null;
    _fastLastAt = null;
    _lastAcceptedBeforeFast = null;
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

  /// 전이 시각([at], 없으면 `clock()`)을 돌려준다. [auto] 는 멈춤·움직임으로
  /// 바뀐 전이다. 위치를 계속 받으므로 빠른 이동 연속을 비우지 않는다.
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
    if (!auto) {
      _lastRaw = null;
      _resetFast();
    }
    _resumeWindow.clear();
    if (from == RunState.recording) {
      _movingBase += now.difference(_recordingSince!);
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
        : _movingBase + (at ?? _clock()).difference(since);
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
