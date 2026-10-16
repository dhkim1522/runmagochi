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
    List<LocationSample> restoredPoints = const [],
  }) {
    if (restoredPoints.isEmpty) return;
    for (final p in restoredPoints) {
      _append(p, continuesSegment: _points.isNotEmpty);
    }
    _movingBase = restoredPoints.last.time.difference(
      restoredPoints.first.time,
    );
    _state = RunState.paused;
  }

  final Clock _clock;
  final _events = StreamController<RunEvent>.broadcast();

  // Task 4 의 요약(RunSummary.startedAt)에서 쓴다.
  DateTime? _startedAt;
  RunState _state = RunState.idle;

  final List<LocationSample> _points = [];

  /// `_points[i]` 까지의 누적 거리(m).
  final List<double> _cumulativeM = [];

  /// 현재 구간의 첫 점 인덱스.
  int _segmentStart = 0;
  bool _segmentPending = true;

  Duration _movingBase = Duration.zero;
  DateTime? _recordingSince;

  Stream<RunEvent> get events => _events.stream;

  List<LocationSample> get acceptedPoints => List.unmodifiable(_points);

  RunSnapshot get snapshot {
    final distanceM = _cumulativeM.isEmpty ? 0.0 : _cumulativeM.last;
    final movingTime = _movingTime();
    return RunSnapshot(
      state: _state,
      distanceM: distanceM,
      movingTime: movingTime,
      avgPaceSecPerKm: _pace(movingTime, distanceM),
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
    if (_points.isNotEmpty) {
      final last = _points.last;
      final dt = s.time.difference(last.time);
      if (dt <= Duration.zero) return false;
      if (!_segmentPending) {
        final seconds = dt.inMicroseconds / Duration.microsecondsPerSecond;
        if (_distance(last, s) / seconds > _maxSpeedMps) return false;
      }
    }
    _append(s, continuesSegment: !_segmentPending);
    _segmentPending = false;
    return true;
  }

  void _append(LocationSample s, {required bool continuesSegment}) {
    if (!continuesSegment) _segmentStart = _points.length;
    final base = _cumulativeM.isEmpty ? 0.0 : _cumulativeM.last;
    _cumulativeM.add(
      continuesSegment ? base + _distance(_points.last, s) : base,
    );
    _points.add(s);
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
      _segmentPending = true;
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

  double? _currentPace() {
    if (_points.isEmpty) return null;
    final last = _points.length - 1;
    final windowStart = _points[last].time.subtract(_currentPaceWindow);
    var first = _segmentStart;
    while (_points[first].time.isBefore(windowStart)) {
      first++;
    }
    return _pace(
      _points[last].time.difference(_points[first].time),
      _cumulativeM[last] - _cumulativeM[first],
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
