import 'dart:async';

import '../../core/clock.dart';
import 'geo.dart';
import 'location_sample.dart';
import 'run_summary.dart';

const double _maxAccuracyM = 20;
const double _maxSpeedMps = 7;
const Duration _currentPaceWindow = Duration(seconds: 30);
const double _minPaceDistanceM = 10;
const Duration _staleSampleTolerance = Duration(seconds: 2);

enum RunState { idle, recording, paused, ended }

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
      _movingBase += segment.last.time.difference(segment.first.time);
    }
    if (restoredMovingTime != null) _movingBase = restoredMovingTime;
    _state = RunState.paused;
  }

  final Clock _clock;
  final _events = StreamController<RunEvent>.broadcast();

  // Task 4 의 요약(RunSummary.startedAt)에서 쓴다.
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

  Duration _movingBase = Duration.zero;
  DateTime? _recordingSince;

  Stream<RunEvent> get events => _events.stream;

  /// 다음에 채택될 점이 받을 구간 번호.
  int get segmentIndex =>
      _segmentPending ? _segments.length : _segments.length - 1;

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
      splits: const [],
    );
  }

  void start() {
    _startedAt = _transition(RunState.idle, RunState.recording);
  }

  void pause() {
    _transition(RunState.recording, RunState.paused);
  }

  void resume() {
    _transition(RunState.paused, RunState.recording);
  }

  RunSummary end() => throw UnimplementedError('Task 4');

  /// 채택하면 true.
  bool addSample(LocationSample s) {
    if (_state != RunState.recording) return false;
    if (s.accuracy > _maxAccuracyM) return false;
    if (s.time.isBefore(_recordingSince!.subtract(_staleSampleTolerance))) {
      return false;
    }
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
    return true;
  }

  void _append(LocationSample s) {
    if (_segmentPending) {
      _segments.add([]);
      _segmentCumulativeM = [];
      _segmentPending = false;
    }
    final segment = _segments.last;
    final d = segment.isEmpty ? 0.0 : _distance(segment.last, s);
    _distanceM += d;
    _segmentCumulativeM.add(
      (_segmentCumulativeM.isEmpty ? 0.0 : _segmentCumulativeM.last) + d,
    );
    segment.add(s);
    _lastAccepted = s;
  }

  /// 전이 시각(`clock()`)을 돌려준다.
  DateTime _transition(RunState from, RunState to) {
    if (_state != from) {
      throw StateError('Cannot go from $_state to $to');
    }
    final now = _clock();
    if (from == RunState.recording) {
      _movingBase += now.difference(_recordingSince!);
      _recordingSince = null;
    }
    if (to == RunState.recording) {
      _recordingSince = now;
      _segmentPending = true;
    }
    _state = to;
    _events.add(StateChanged(from, to));
    return now;
  }

  Duration _movingTime() {
    final since = _recordingSince;
    return since == null
        ? _movingBase
        : _movingBase + _clock().difference(since);
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
