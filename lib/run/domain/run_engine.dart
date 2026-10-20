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
    }
    _movingBase = restoredMovingTime ?? _sampleMovingTime;
    _state = RunState.paused;
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
  /// 일시정지·재개하면 비운다.
  LocationSample? _lastRaw;
  DateTime? _fastSince;
  DateTime? _fastLastAt;
  DateTime? _lastAcceptedBeforeFast;

  Duration _movingBase = Duration.zero;
  DateTime? _recordingSince;

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

  void start() {
    _startedAt = _transition(RunState.idle, RunState.recording);
  }

  void pause() {
    _transition(RunState.recording, RunState.paused);
  }

  void resume() {
    _transition(RunState.paused, RunState.recording);
  }

  /// 기록 중이나 일시정지 중에 끝낸다. 남은 거리가 1m 이상이면 마지막
  /// 구간으로 넣고 `RunEnded` 를 낸 뒤 `ended` 로 바꾸고 이벤트 스트림을
  /// 닫는다. `clock()` 은 한 번만 읽는다.
  RunSummary end({double weightKg = defaultWeightKg}) {
    if (_state != RunState.recording && _state != RunState.paused) {
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

  /// 채택하면 true.
  bool addSample(LocationSample s) {
    if (_state != RunState.recording) return false;
    if (s.accuracy > _maxAccuracyM) return false;
    if (s.time.isBefore(_recordingSince!.subtract(_staleSampleTolerance))) {
      return false;
    }
    _trackFast(s);
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

  /// 전이 시각([at], 없으면 `clock()`)을 돌려준다.
  DateTime _transition(RunState from, RunState to, {DateTime? at}) {
    if (_state != from) {
      throw StateError('Cannot go from $_state to $to');
    }
    final now = at ?? _clock();
    _lastRaw = null;
    _resetFast();
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
