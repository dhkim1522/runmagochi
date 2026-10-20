import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../profile/app/providers.dart';
import '../data/run_repository.dart';
import '../domain/location_sample.dart';
import '../domain/run_engine.dart';
import '../domain/run_summary.dart';
import '../domain/run_trim.dart';
import 'providers.dart';
import 'run_guard.dart';

const Duration _flushInterval = Duration(seconds: 10);
const Duration _tickInterval = Duration(seconds: 1);

/// 위치 스트림이 오류나 종료로 끊긴 뒤 다시 구독하기까지 기다리는 시간.
const Duration _resubscribeInterval = Duration(seconds: 5);

const String _locationErrorMessage = '위치 신호를 받지 못하고 있어요';
const String _saveErrorMessage = '기록 저장에 실패했어요. 자동으로 다시 시도해요';
const String _endErrorMessage = '러닝 저장에 실패했어요. 다시 종료해 주세요';
const String _autoEndTitle = '러닝을 자동으로 마쳤어요';

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
    this.weightKg = defaultWeightKg,
    this.autoEnded = false,
    this.lastRunId,
    this.goalM,
  });

  final RunSnapshot snapshot;
  final String? runId;
  final RunSummary? lastSummary;

  /// 화면에 보일 마지막 오류 문구.
  final String? lastError;

  /// 진행 중 칼로리 표시에 쓰는 체중(kg). 시작·복구 때 읽고 종료 때 다시 읽는다.
  final double weightKg;

  /// [lastSummary] 가 종료를 잊어 자동으로 끝낸 러닝이다 (결정 0016).
  final bool autoEnded;

  /// [lastSummary] 러닝의 저장소 id. 끝부분 잘라내기에 쓴다.
  final String? lastRunId;

  /// 진행 중 러닝의 오늘 목표(m). 러닝 중·복원 때만 채우고 목표 없는 옛 러닝은 null.
  final double? goalM;
}

class RunController extends Notifier<RunViewState> {
  RunEngine? _engine;
  String? _runId;
  StreamSubscription<LocationSample>? _subscription;
  Timer? _flushTimer;
  Timer? _tickTimer;

  /// 끊긴 위치 구독을 다시 하려고 기다리는 타이머.
  Timer? _resubscribeTimer;

  /// 끊긴 구독을 앱이 화면에 있을 때 다시 해야 한다.
  bool _resubscribePending = false;

  /// 아직 저장하지 않은 채택 점과 그 구간 번호.
  final List<(int, LocationSample)> _buffer = [];

  /// 저장을 한 번에 하나씩 순서대로 하도록 잇는 꼬리.
  Future<void> _flushQueue = Future.value();

  /// createActiveRun 을 기다리는 중.
  bool _starting = false;

  /// end 가 진행 중.
  bool _ending = false;

  /// end 의 마지막 저장이 끝났다. 이후 저장은 하지 않는다.
  bool _flushClosed = false;

  /// completeRun 이 실패해 남은 요약. end 를 다시 부르면 이것으로 completeRun 만 한다.
  RunSummary? _pendingSummary;

  /// [_pendingSummary] 가 자동 종료로 만든 요약이다.
  bool _pendingAutoEnd = false;

  double _weightKg = defaultWeightKg;

  /// 진행 중 러닝의 목표(m).
  double? _goalM;

  /// 저장된 체중. 없거나 읽지 못하면 기본 체중.
  Future<double> _readWeight() async {
    try {
      return await ref.read(profileRepositoryProvider).weightKg() ??
          defaultWeightKg;
    } catch (_) {
      return defaultWeightKg;
    }
  }

  RunRepository get _repository => ref.read(runRepositoryProvider);

  @override
  RunViewState build() {
    final lifecycle = ref.read(appLifecycleProvider);
    final lifecycleSub = lifecycle.changes.listen(_onLifecycleChanged);
    ref.onDispose(() {
      lifecycleSub.cancel();
      _stopTimers();
      _subscription?.cancel();
    });
    return const RunViewState(snapshot: _idleSnapshot);
  }

  /// [goalM] 은 홈에서 고른 오늘 목표(m). 이전 러닝의 lastSummary·lastError 는 지운다.
  Future<void> start({required double goalM}) async {
    _requireNoRun();
    _starting = true;
    try {
      final clock = ref.read(clockProvider);
      final runId = await _repository.createActiveRun(clock(), goalM: goalM);
      _weightKg = await _readWeight();
      final engine = RunEngine(clock: clock)..start();
      _engine = engine;
      _runId = runId;
      _goalM = goalM;
      _subscribe();
      _startFlushTimer();
      _startTick();
      state = RunViewState(
        snapshot: engine.snapshot,
        runId: runId,
        weightKg: _weightKg,
        goalM: goalM,
      );
    } finally {
      _starting = false;
    }
  }

  void pause() {
    _requireNotEnding();
    _requireEngine().pause();
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _resubscribePending = false;
    _publish();
    unawaited(_flushReportingError());
  }

  void resume() {
    _requireNotEnding();
    _requireEngine().resume();
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _resubscribePending = false;
    _subscribe();
    _startFlushTimer();
    _startTick();
    _publish();
  }

  /// 저장이나 completeRun 이 실패하면 lastError 에 남기고 다시 던진다.
  /// 마지막 저장이 실패하면 러닝은 그대로 남아 resume 이나 end 를 다시 부를 수
  /// 있다. completeRun 이 실패하면 상태는 ended 가 되고, 다시 부르면 남은
  /// 요약으로 completeRun 만 다시 한다.
  Future<RunSummary> end() => _finish(null);

  /// 잘라내기가 진행 중.
  bool _trimming = false;

  /// 방금 끝낸 러닝([RunViewState.lastSummary])의 끝을 [newEnd] 로 앞당겨
  /// 저장소에 바꿔 저장하고 lastSummary 를 바꾼 요약으로 바꾼다. 원본 점이
  /// 메모리에 있는 동안(다음 러닝을 시작하기 전)만 된다. 체중은 종료 때 읽은
  /// 값을 쓴다. 경험치는 바꾸지 않는다(`trimLastRun` 이 한다).
  ///
  /// 끝낸 러닝이 없거나 러닝 중이거나 잘라내는 중이면 [StateError], [newEnd]
  /// 가 시작 앞이거나 끝 뒤면 [ArgumentError]. 저장이 실패하면 그대로 던지고
  /// lastSummary 는 바뀌지 않는다.
  Future<(String runId, RunSummary summary)> trimLastSummary(
    DateTime newEnd,
  ) async {
    final summary = state.lastSummary;
    final runId = state.lastRunId;
    if (summary == null || runId == null || _runId != null || _starting) {
      throw StateError('잘라낼 수 있는 끝낸 러닝이 없다.');
    }
    if (_trimming) throw StateError('이미 잘라내는 중이다.');
    _trimming = true;
    try {
      final trimmed = trimRunEnd(summary, newEnd, weightKg: _weightKg);
      await _repository.replaceCompletedRun(runId, trimmed);
      // 그 사이 새 러닝을 시작했으면 상태를 덮어쓰지 않는다.
      if (state.lastRunId == runId) {
        state = _copyState(lastSummary: trimmed);
      }
      return (runId, trimmed);
    } finally {
      _trimming = false;
    }
  }

  /// [auto] 가 있으면 끝 시각을 [AutoEndDecision.endAt] 으로 당기고, 저장에
  /// 성공하면 autoEnded 로 표시하고 알림을 띄운다.
  Future<RunSummary> _finish(AutoEndDecision? auto) async {
    _requireNotEnding();
    final engine = _requireEngine();
    final runId = _runId!;
    _ending = true;
    try {
      var summary = _pendingSummary;
      if (summary == null) {
        _stopTimers();
        // cancel 을 부른 뒤로는 점이 오지 않으므로 해제 완료를 기다리지 않는다.
        unawaited(_subscription?.cancel().catchError((Object _) {}));
        _subscription = null;
        try {
          await _flush();
        } catch (_) {
          state = _copyState(lastError: _endErrorMessage);
          rethrow;
        }
        _flushClosed = true;
        // 설정에서 체중을 바꿨을 수 있으므로 종료 때 다시 읽는다.
        _weightKg = await _readWeight();
        final wasRecording = engine.state == RunState.recording;
        summary = engine.end(weightKg: _weightKg);
        if (auto != null) {
          summary = _endAt(summary, auto.endAt, trim: wasRecording);
        }
        _pendingSummary = summary;
        _pendingAutoEnd = auto != null;
        _publish();
      }
      try {
        await _repository.completeRun(runId, summary);
      } catch (_) {
        state = _copyState(lastError: _endErrorMessage);
        rethrow;
      }
      final autoEnded = _pendingAutoEnd;
      _engine = null;
      _runId = null;
      _goalM = null;
      _pendingSummary = null;
      _pendingAutoEnd = false;
      _flushClosed = false;
      state = RunViewState(
        snapshot: _idleSnapshot,
        lastSummary: summary,
        autoEnded: autoEnded,
        lastRunId: runId,
      );
      if (autoEnded) _notifyAutoEnd(summary);
      return summary;
    } finally {
      _ending = false;
    }
  }

  /// 복구한 러닝이 있으면 true, 상태 paused. 위치 구독은 resume 때 한다.
  ///
  /// 복구한 러닝이 시작 6시간을 넘었으면 묻지 않고 끝내고 false 를 돌려준다
  /// (상태 autoEnded, lastSummary 에 요약). 일시정지 여부를 저장하지 않아
  /// 20분 규칙은 적용하지 않는다. 자동 종료 저장이 실패하면 러닝을 남기고
  /// true 를 돌려준다.
  Future<bool> restoreIfAny() async {
    _requireNoRun();
    final active = await _repository.findActiveRun();
    if (active == null) return false;
    final engine = _engine = RunEngine(
      clock: ref.read(clockProvider),
      startedAt: active.startedAt,
      restoredSegments: active.segments,
      restoredMovingTime: active.movingTime,
    );
    _runId = active.id;
    _goalM = active.goalM;
    _weightKg = await _readWeight();
    _publish();
    final decision = checkAutoEnd(
      now: ref.read(clockProvider)(),
      startedAt: active.startedAt,
      // 일시정지 여부를 저장하지 않으므로 6시간 상한만 본다.
      recording: false,
      lastPointAt: engine.lastPointAt,
      recordingSince: null,
      config: ref.read(runGuardConfigProvider),
    );
    if (decision != null) {
      try {
        await _finish(decision);
        return false;
      } catch (_) {
        // 실패 문구는 lastError 에 남았다. 사용자가 다시 끝낼 수 있게 둔다.
      }
    }
    _startFlushTimer();
    return true;
  }

  /// 자동 종료 조건을 넘었으면 끝내기 시작하고 true.
  bool _checkAutoEnd() {
    final engine = _engine;
    if (engine == null || _ending || _pendingSummary != null) return false;
    final runState = engine.state;
    if (runState != RunState.recording && runState != RunState.paused) {
      return false;
    }
    final decision = checkAutoEnd(
      now: ref.read(clockProvider)(),
      startedAt: engine.startedAt!,
      recording: runState == RunState.recording,
      lastPointAt: engine.lastPointAt,
      recordingSince: engine.recordingSince,
      config: ref.read(runGuardConfigProvider),
    );
    if (decision == null) return false;
    unawaited(_autoEnd(decision));
    return true;
  }

  Future<void> _autoEnd(AutoEndDecision decision) async {
    try {
      await _finish(decision);
    } catch (_) {
      // 마지막 저장이 실패해 러닝이 남았으면 틱마다 다시 시도한다.
      // completeRun 이 실패했으면(ended) 사용자가 다시 끝낸다.
      if (_engine != null && _pendingSummary == null) {
        _startFlushTimer();
        _startTick();
      }
    }
  }

  /// [summary] 의 끝을 [endAt] 으로 당긴다. 기록 중에 끝낸 요약은 잘라내기로
  /// 다시 계산한다. 일시정지 중에 끝낸 요약은 [endAt] 뒤에 점이 없고 움직인
  /// 시간도 멈춰 있으므로 끝 시각만 바꾼다(잘라내기는 일시정지 시간까지
  /// 움직인 시간에서 뺀다).
  RunSummary _endAt(RunSummary summary, DateTime endAt, {required bool trim}) {
    if (!endAt.isBefore(summary.endedAt)) return summary;
    if (trim) return trimRunEnd(summary, endAt, weightKg: _weightKg);
    return RunSummary(
      startedAt: summary.startedAt,
      endedAt: endAt,
      distanceM: summary.distanceM,
      movingTime: summary.movingTime,
      avgPaceSecPerKm: summary.avgPaceSecPerKm,
      calories: summary.calories,
      name: summary.name,
      splits: summary.splits,
      points: summary.points,
      segments: summary.segments,
    );
  }

  /// 알림 실패는 러닝 저장과 상관없으므로 버린다.
  void _notifyAutoEnd(RunSummary summary) {
    try {
      unawaited(
        ref
            .read(instantNotifierProvider)
            .showNow(
              title: _autoEndTitle,
              body:
                  '${formatKm(summary.distanceM)}km 기록을 저장했어요. '
                  '요약에서 확인하세요.',
            )
            .catchError((Object e) => debugPrint('알림: 자동 종료 알림 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 자동 종료 알림 실패 $e');
    }
  }

  void _requireNoRun() {
    if (_starting || _runId != null) {
      throw StateError('이미 진행 중인 러닝이 있다.');
    }
  }

  void _requireNotEnding() {
    if (_ending) throw StateError('러닝을 끝내는 중이다.');
  }

  RunEngine _requireEngine() => _engine ?? (throw StateError('진행 중인 러닝이 없다.'));

  void _subscribe() {
    if (_subscription != null) return;
    _subscription = ref
        .read(locationSourceProvider)
        .watch()
        .listen(
          _onSample,
          onError: (Object _) {
            state = _copyState(lastError: _locationErrorMessage);
            _dropSubscription();
          },
          onDone: _dropSubscription,
        );
  }

  /// 오류나 종료로 끊긴 구독을 버린다. 기록 중이면 잠시 뒤 다시 구독하고,
  /// 일시정지 중이면 resume 이 다시 구독한다.
  void _dropSubscription() {
    unawaited(_subscription?.cancel().catchError((Object _) {}));
    _subscription = null;
    if (_engine?.snapshot.state != RunState.recording) return;
    _resubscribePending = true;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    if (_isForeground) _scheduleResubscribe();
  }

  bool get _isForeground =>
      ref.read(appLifecycleProvider).current == AppLifecycleState.resumed;

  void _scheduleResubscribe() {
    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(_resubscribeInterval, () {
      _resubscribeTimer = null;
      // 백그라운드에서는 안드로이드가 위치 포그라운드 서비스 시작을 거부한다.
      // 구독하지 않고 대기 표시만 남겨 화면으로 돌아올 때 구독한다.
      if (_isForeground) {
        _resubscribePending = false;
        _subscribe();
      }
    });
  }

  void _onLifecycleChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    if (_checkAutoEnd()) return;
    if (!_resubscribePending || _subscription != null) return;
    if (_engine?.snapshot.state != RunState.recording) return;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _resubscribePending = false;
    _subscribe();
  }

  void _onSample(LocationSample sample) {
    final engine = _engine;
    if (engine == null) return;
    final segmentIndex = engine.segmentIndex;
    if (engine.addSample(sample)) {
      _buffer.add((segmentIndex, sample));
      _publish(clearLocationError: true);
    }
  }

  void _startFlushTimer() {
    // 실패한 점은 버퍼에 남아 다음 저장 때 다시 저장한다.
    _flushTimer ??= Timer.periodic(
      _flushInterval,
      (_) => _flushReportingError(),
    );
  }

  void _startTick() {
    _tickTimer ??= Timer.periodic(_tickInterval, (_) {
      if (!_checkAutoEnd()) _publish();
    });
  }

  void _stopTimers() {
    _flushTimer?.cancel();
    _tickTimer?.cancel();
    _resubscribeTimer?.cancel();
    _flushTimer = null;
    _tickTimer = null;
    _resubscribeTimer = null;
    _resubscribePending = false;
  }

  /// 저장 실패를 lastError 에 남긴다. 실패한 점은 버퍼에 남는다.
  Future<void> _flushReportingError() {
    return _flush().catchError((Object _) {
      state = _copyState(lastError: _saveErrorMessage);
    });
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
    if (engine == null || runId == null || _flushClosed) return;
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

  /// [clearLocationError] 면 위치 스트림 오류 문구를 지운다. 다른 오류는 둔다.
  void _publish({bool clearLocationError = false}) {
    final engine = _engine;
    if (engine == null) return;
    final clear =
        clearLocationError && state.lastError == _locationErrorMessage;
    state = _copyState(
      snapshot: engine.snapshot,
      runId: _runId,
      clearError: clear,
    );
  }

  RunViewState _copyState({
    RunSnapshot? snapshot,
    String? runId,
    RunSummary? lastSummary,
    String? lastError,
    bool clearError = false,
  }) {
    return RunViewState(
      snapshot: snapshot ?? state.snapshot,
      runId: runId ?? state.runId,
      lastSummary: lastSummary ?? state.lastSummary,
      lastError: clearError ? null : lastError ?? state.lastError,
      weightKg: _weightKg,
      autoEnded: state.autoEnded,
      lastRunId: state.lastRunId,
      goalM: _goalM,
    );
  }
}
