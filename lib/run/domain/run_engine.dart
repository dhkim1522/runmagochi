import 'dart:async';

import '../../core/clock.dart';
import 'geo.dart';
import 'location_sample.dart';
import 'run_summary.dart';

const double _maxAccuracyM = 20;
const double _maxSpeedMps = 7;
const Duration _currentPaceWindow = Duration(seconds: 30);
const double _minPaceDistanceM = 10;

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
  RunEngine({
    required this._clock,
    this._startedAt,
    List<List<LocationSample>> restoredSegments = const [],
  }) {
    if (restoredSegments.isEmpty) return;
    for (final segment in restoredSegments) {
      _openSegment();
      segment.forEach(_append);
      if (segment.isNotEmpty) {
        _movingBase += segment.last.time.difference(segment.first.time);
      }
    }
    _state = RunState.paused;
  }

  final Clock _clock;
  final _events = StreamController<RunEvent>.broadcast();

  // Task 4 의 요약(RunSummary.startedAt)에서 쓴다.
  DateTime? _startedAt;
  RunState _state = RunState.idle;

  /// 채택한 점. `start`·`resume` 마다 새 구간을 연다.
  final List<List<LocationSample>> _segments = [];

  /// 현재 구간 각 점까지의 구간 안 누적 거리(m).
  List<double> _segmentCumulativeM = [];
  double _distanceM = 0;
  LocationSample? _lastAccepted;

  Duration _movingBase = Duration.zero;
  DateTime? _recordingSince;

  Stream<RunEvent> get events => _events.stream;

  /// 현재 구간 번호. start 에서 0, resume 마다 1씩 오른다.
  int get segmentIndex => _segments.isEmpty ? 0 : _segments.length - 1;

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
    _transition(RunState.idle, RunState.recording);
    _startedAt ??= _clock();
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
    final last = _lastAccepted;
    if (last != null) {
      final dt = s.time.difference(last.time);
      if (dt <= Duration.zero) return false;
      if (_segments.last.isNotEmpty) {
        final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
        if (_distance(last, s) / seconds > _maxSpeedMps) return false;
      }
    }
    _append(s);
    return true;
  }

  void _openSegment() {
    _segments.add([]);
    _segmentCumulativeM = [];
  }

  void _append(LocationSample s) {
    final segment = _segments.last;
    final d = segment.isEmpty ? 0.0 : _distance(segment.last, s);
    _distanceM += d;
    _segmentCumulativeM.add(
      (_segmentCumulativeM.isEmpty ? 0.0 : _segmentCumulativeM.last) + d,
    );
    segment.add(s);
    _lastAccepted = s;
  }

  void _transition(RunState from, RunState to) {
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
      _openSegment();
    }
    _state = to;
    _events.add(StateChanged(from, to));
  }

  Duration _movingTime() {
    final since = _recordingSince;
    return since == null
        ? _movingBase
        : _movingBase + _clock().difference(since);
  }

  /// 현재 구간에서 최근 30초 창의 시간 ÷ 거리. 기록 중이 아니면 null.
  double? _currentPace() {
    if (_state != RunState.recording) return null;
    final points = _segments.last;
    if (points.isEmpty) return null;
    final last = points.length - 1;
    final windowStart = points[last].time.subtract(_currentPaceWindow);
    var first = 0;
    while (points[first].time.isBefore(windowStart)) {
      first++;
    }
    return _pace(
      points[last].time.difference(points[first].time),
      _segmentCumulativeM[last] - _segmentCumulativeM[first],
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
