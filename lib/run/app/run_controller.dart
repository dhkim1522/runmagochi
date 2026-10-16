import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/run_repository.dart';
import '../domain/location_sample.dart';
import '../domain/run_engine.dart';
import '../domain/run_summary.dart';
import 'providers.dart';

const Duration _flushInterval = Duration(seconds: 10);
const Duration _tickInterval = Duration(seconds: 1);

const RunSnapshot _idleSnapshot = RunSnapshot(
  state: RunState.idle,
  distanceM: 0,
  movingTime: Duration.zero,
  avgPaceSecPerKm: null,
  currentPaceSecPerKm: null,
  splits: [],
);

class RunViewState {
  const RunViewState({
    required this.snapshot,
    this.runId,
    this.lastSummary,
    this.lastError,
  });

  final RunSnapshot snapshot;
  final String? runId;
  final RunSummary? lastSummary;

  /// 마지막 위치 스트림 오류 메시지.
  final String? lastError;
}

class RunController extends Notifier<RunViewState> {
  RunEngine? _engine;
  String? _runId;
  StreamSubscription<LocationSample>? _subscription;
  Timer? _flushTimer;
  Timer? _tickTimer;

  /// 아직 저장하지 않은 채택 점과 그 구간 번호.
  final List<(int, LocationSample)> _buffer = [];

  /// 저장을 한 번에 하나씩 순서대로 하도록 잇는 꼬리.
  Future<void> _flushQueue = Future.value();

  RunRepository get _repository => ref.read(runRepositoryProvider);

  @override
  RunViewState build() {
    ref.onDispose(() {
      _stopTimers();
      _subscription?.cancel();
    });
    return const RunViewState(snapshot: _idleSnapshot);
  }

  Future<void> start() async {
    final clock = ref.read(clockProvider);
    final runId = await _repository.createActiveRun(clock());
    final engine = RunEngine(clock: clock)..start();
    _engine = engine;
    _runId = runId;
    _subscribe();
    _startFlushTimer();
    _startTick();
    _publish();
  }

  void pause() {
    _requireEngine().pause();
    _publish();
    unawaited(_flush());
  }

  void resume() {
    _requireEngine().resume();
    _subscribe();
    _startTick();
    _publish();
  }

  Future<RunSummary> end() async {
    final engine = _requireEngine();
    final runId = _runId!;
    _stopTimers();
    // cancel 을 부른 뒤로는 점이 오지 않으므로 해제 완료를 기다리지 않는다.
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _flush();
    final summary = engine.end();
    await _repository.completeRun(runId, summary);
    _engine = null;
    _runId = null;
    state = RunViewState(snapshot: _idleSnapshot, lastSummary: summary);
    return summary;
  }

  /// 복구한 러닝이 있으면 true, 상태 paused. 위치 구독은 resume 때 한다.
  Future<bool> restoreIfAny() async {
    final active = await _repository.findActiveRun();
    if (active == null) return false;
    _engine = RunEngine(
      clock: ref.read(clockProvider),
      startedAt: active.startedAt,
      restoredSegments: active.segments,
      restoredMovingTime: active.movingTime,
    );
    _runId = active.id;
    _startFlushTimer();
    _publish();
    return true;
  }

  RunEngine _requireEngine() => _engine ?? (throw StateError('진행 중인 러닝이 없다.'));

  void _subscribe() {
    _subscription ??= ref
        .read(locationSourceProvider)
        .watch()
        .listen(
          _onSample,
          onError: (Object error) {
            state = _copyState(lastError: error.toString());
          },
        );
  }

  void _onSample(LocationSample sample) {
    final engine = _engine;
    if (engine == null) return;
    final segmentIndex = engine.segmentIndex;
    if (engine.addSample(sample)) {
      _buffer.add((segmentIndex, sample));
      _publish();
    }
  }

  void _startFlushTimer() {
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => _flush());
  }

  void _startTick() {
    _tickTimer ??= Timer.periodic(_tickInterval, (_) => _publish());
  }

  void _stopTimers() {
    _flushTimer?.cancel();
    _tickTimer?.cancel();
    _flushTimer = null;
    _tickTimer = null;
  }

  /// 앞선 저장이 끝난 뒤 버퍼를 저장한다. 앞선 저장의 실패는 그 호출자가 받는다.
  Future<void> _flush() {
    return _flushQueue = _flushQueue.then(
      (_) => _writeBuffer(),
      onError: (Object _) => _writeBuffer(),
    );
  }

  /// 구간 번호 오름차순으로 구간마다 appendPoints 한다. 버퍼가 비어도 움직인
  /// 시간을 저장한다. 저장에 성공한 점만 버퍼에서 뺀다.
  Future<void> _writeBuffer() async {
    final engine = _engine;
    final runId = _runId;
    if (engine == null || runId == null) return;
    final movingTime = engine.snapshot.movingTime;
    if (_buffer.isEmpty) {
      await _repository.appendPoints(
        runId,
        segmentIndex: engine.segmentIndex,
        points: const [],
        movingTime: movingTime,
      );
      return;
    }
    final pending = List.of(_buffer);
    final segmentIndexes = {for (final (i, _) in pending) i}.toList()..sort();
    for (final segmentIndex in segmentIndexes) {
      final points = [
        for (final (i, s) in pending)
          if (i == segmentIndex) s,
      ];
      await _repository.appendPoints(
        runId,
        segmentIndex: segmentIndex,
        points: points,
        movingTime: movingTime,
      );
      // 버퍼는 구간 번호 순으로 쌓이므로 저장한 점은 항상 맨 앞에 있다.
      _buffer.removeRange(0, points.length);
    }
  }

  void _publish() {
    final engine = _engine;
    if (engine == null) return;
    state = _copyState(snapshot: engine.snapshot, runId: _runId);
  }

  RunViewState _copyState({
    RunSnapshot? snapshot,
    String? runId,
    String? lastError,
  }) {
    return RunViewState(
      snapshot: snapshot ?? state.snapshot,
      runId: runId ?? state.runId,
      lastSummary: state.lastSummary,
      lastError: lastError ?? state.lastError,
    );
  }
}
