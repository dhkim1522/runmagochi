import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/domain/growth_rules.dart' show distanceReachesGoal;
import '../../core/format.dart';
import '../../profile/app/providers.dart';
import '../data/location_source.dart' show LocationServiceOffException;
import '../data/run_progress_notifier.dart';
import '../data/run_repository.dart';
import '../domain/location_sample.dart';
import '../domain/run_engine.dart';
import '../domain/run_goal.dart';
import '../domain/run_summary.dart';
import '../domain/run_trim.dart';
import 'providers.dart';
import 'run_guard.dart';
import 'voice_guide.dart';

const Duration _flushInterval = Duration(seconds: 10);
const Duration _tickInterval = Duration(seconds: 1);

/// 탈것 의심 안내(음성·러닝 알림 문구)를 다시 켜고, 신호 끊김을 다시 읽는 최소 간격.
/// 문턱 언저리 버스나 터널 입구에서 상태가 오가도 안내가 되풀이되지 않게 한다.
const Duration noticeDebounce = Duration(seconds: 60);

/// 거리만 바뀐 러닝 알림 갱신 사이의 최소 간격.
const Duration _progressMinInterval = Duration(seconds: 3);
const int _progressTimeStepSeconds = 15;

/// 위치 스트림이 오류나 종료로 끊긴 뒤 다시 구독하기까지 기다리는 시간.
const Duration _resubscribeInterval = Duration(seconds: 5);

const String _locationErrorMessage = '위치 신호를 받지 못하고 있어요';

/// 기기의 위치 서비스(GPS)가 꺼져 위치 스트림이 끊겼을 때의 문구. 러닝 화면은 이
/// 카드 하나만 보이고 신호 끊김 말풍선은 숨긴다.
const String locationServiceOffMessage = '위치 서비스가 꺼져 있어요. 켜면 이어서 기록해요';
const String _saveErrorMessage = '기록 저장에 실패했어요. 자동으로 다시 시도해요';
const String _endErrorMessage = '러닝 저장에 실패했어요. 다시 종료해 주세요';
const String _autoEndTitle = '러닝을 자동으로 마쳤어요';

/// 탈것 의심·신호 끊김으로 끝낸 러닝의 알림 (결정 0033).
const String _quitTitle = '한참 못 달려서 러닝을 마쳤어요';
const String _quitBody = '기록은 안전하게 저장했어요';
const String _shortRunAutoEndTitle = '러닝을 마쳤어요';
const String shortRunMessage = '1km 미만은 기록하지 않아요';
const String _goalReachedTitle = '목표 달성!';

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
    this.goal,
    this.goalReached = false,
    this.discardedShortRun = false,
  });

  final RunSnapshot snapshot;
  final String? runId;
  final RunSummary? lastSummary;

  /// 화면에 보일 마지막 오류 문구.
  final String? lastError;

  /// 기기의 위치 서비스(GPS)가 꺼져 위치를 받지 못하고 있다.
  bool get locationServiceOff => lastError == locationServiceOffMessage;

  /// 진행 중 칼로리 표시에 쓰는 체중(kg). 시작·복구 때 읽고 종료 때 다시 읽는다.
  final double weightKg;

  /// [lastSummary] 가 종료를 잊어 자동으로 끝낸 러닝이다 (결정 0016).
  final bool autoEnded;

  /// [lastSummary] 러닝의 저장소 id. 끝부분 잘라내기에 쓴다.
  final String? lastRunId;

  /// 진행 중 러닝의 오늘 목표. 러닝 중·복원 때만 채우고 목표 없는 옛 러닝은 null.
  final RunGoal? goal;

  /// 목표에 닿았다(거리 목표는 기록 거리, 시간 목표는 움직인 시간). 목표가 없으면 항상 false.
  final bool goalReached;

  /// 방금 끝낸 러닝이 [minSavedDistanceM] 미만이라 저장하지 않고 지웠다(결정 0027).
  /// 이때 [lastSummary]·[lastRunId] 는 비어 있다. 다음 러닝을 시작하면 지워진다.
  final bool discardedShortRun;
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

  /// 위치 서비스(GPS)가 꺼져 구독이 끊겼다. 켜진 것을 확인한 뒤에만 다시
  /// 구독한다. 꺼진 채 구독하면 geolocator 가 위치를 켜라는 시스템 창을 띄운다.
  bool _locationOff = false;

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

  /// [_pendingSummary] 가 자동 종료로 만든 요약이면 그 이유.
  AutoEndReason? _pendingAutoEnd;

  double _weightKg = defaultWeightKg;

  /// 러닝 알림에 마지막으로 띄운 상태·거리 표기·시각.
  RunState? _progressState;
  bool _progressVehicleNotice = false;
  String? _progressKm;
  int? _progressTimeStep;
  bool _progressReached = false;
  DateTime? _progressShownAt;

  /// 띄워 둔 종료 예고의 끝날 시각. 예고가 없으면 null.
  DateTime? _endWarningDeadline;

  /// 진행 중 러닝의 목표.
  RunGoal? _goal;

  /// 목표 달성을 이미 알렸거나(복원 포함) 알릴 필요가 없다.
  bool _goalReached = false;

  /// 엔진 사건(구간·자동 일시정지·재개)을 음성 안내로 옮기는 구독.
  StreamSubscription<RunEvent>? _voiceSubscription;

  /// 음성으로 안내한 마지막 1km 구간 번호. 같은 구간은 두 번 읽지 않는다.
  int _spokenSplits = 0;

  /// 러닝 알림 본문에 탈것 의심 문구를 보이는 중과 마지막으로 켠 시각.
  /// 다시 켜기는 [noticeDebounce] 에 한 번만 한다.
  bool _vehicleNotice = false;
  DateTime? _vehicleNoticeOnAt;

  /// 지금 탈것 의심 구간을 음성으로 안내했다. 풀릴 때 "다시 기록해요" 를 읽는다.
  bool _vehicleAnnounced = false;

  /// 마지막으로 신호 끊김을 읽은 시각과, 지금 끊김을 읽었는지.
  DateTime? _signalSpokenAt;
  bool _signalAnnounced = false;

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
    final actionSub = ref
        .read(runNotificationActionsProvider)
        .listen(_onNotificationAction, onError: (Object _) {});
    ref.onDispose(() {
      lifecycleSub.cancel();
      actionSub.cancel();
      _stopTimers();
      _subscription?.cancel();
      _voiceSubscription?.cancel();
    });
    return const RunViewState(snapshot: _idleSnapshot);
  }

  /// 알림 버튼. 기록 중·스스로 풀리는 멈춤(자동 일시정지·탈것 의심·신호
  /// 끊김)이면 일시정지, 일시정지·스스로 풀리는 멈춤이면 재개한다. 러닝이 없거나 상태에 맞지 않는 버튼은 무시하고, 오류는 밖으로
  /// 내지 않는다.
  void _onNotificationAction(String actionId) {
    try {
      if (_engine == null || _ending) return;
      final runState = _engine!.snapshot.state;
      final autoStopped = autoStoppedStates.contains(runState);
      if (actionId == LocalRunProgressNotifier.pauseActionId &&
          (runState == RunState.recording || autoStopped)) {
        pause();
      } else if (actionId == LocalRunProgressNotifier.resumeActionId &&
          (runState == RunState.paused || autoStopped)) {
        resume();
      }
    } catch (_) {}
  }

  /// [goal] 은 홈에서 고른 오늘 목표. 이전 러닝의 lastSummary·lastError 는 지운다.
  Future<void> start({required RunGoal goal}) async {
    _requireNoRun();
    _starting = true;
    try {
      final clock = ref.read(clockProvider);
      final runId = await _repository.createActiveRun(clock(), goal: goal);
      _weightKg = await _readWeight();
      final engine = RunEngine(clock: clock)..start();
      _engine = engine;
      _runId = runId;
      _goal = goal;
      _goalReached = false;
      _locationOff = false;
      _resetNotices();
      _cancelAutoEndNotice();
      _listenVoice(engine, spokenSplits: 0);
      _speak(const VoiceStart());
      _subscribe();
      _startFlushTimer();
      _startTick();
      state = RunViewState(
        snapshot: engine.snapshot,
        runId: runId,
        weightKg: _weightKg,
        goal: goal,
      );
      _updateProgress(engine.snapshot);
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
    _resubscribe();
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
        final stoppedAt = engine.pausedAt;
        summary = engine.end(weightKg: _weightKg);
        if (auto != null) {
          summary = _endAt(
            summary,
            auto.endAt,
            trim: wasRecording,
            stoppedAt: stoppedAt,
          );
        }
        _pendingSummary = summary;
        _pendingAutoEnd = auto?.reason;
        _publish();
      }
      // 1km 미만은 저장하지 않고 진행 중 러닝을 지운다. 최종 기록 거리(잘라낸 뒤)로 정한다.
      final discard = summary.distanceM < minSavedDistanceM;
      try {
        if (discard) {
          await _repository.discardActiveRun(runId);
        } else {
          await _repository.completeRun(runId, summary);
        }
      } catch (_) {
        state = _copyState(lastError: _endErrorMessage);
        rethrow;
      }
      final autoEndReason = _pendingAutoEnd;
      final autoEnded = autoEndReason != null;
      _engine = null;
      _runId = null;
      _goal = null;
      _goalReached = false;
      _stopVoice();
      _cancelProgress();
      _cancelRunScopedAlerts();
      _pendingSummary = null;
      _pendingAutoEnd = null;
      _flushClosed = false;
      state = RunViewState(
        snapshot: _idleSnapshot,
        lastSummary: discard ? null : summary,
        autoEnded: autoEnded,
        lastRunId: discard ? null : runId,
        discardedShortRun: discard,
      );
      if (autoEndReason != null) {
        _notifyAutoEnd(summary, autoEndReason, discarded: discard);
      }
      return summary;
    } finally {
      _ending = false;
    }
  }

  /// 복구한 러닝이 있으면 true, 상태 paused. 위치 구독은 resume 때 한다.
  /// 복구한 러닝은 사용자 일시정지로 보고 복구 시각부터 1시간 규칙을 센다.
  ///
  /// 복구한 러닝이 시작 6시간을 넘었으면 묻지 않고 끝내고 false 를 돌려준다
  /// (상태 autoEnded, lastSummary 에 요약). 자동 종료 저장이 실패하면 러닝을
  /// 남기고 true 를 돌려준다.
  Future<bool> restoreIfAny() async {
    _requireNoRun();
    // 앞선 프로세스가 죽으면서 남긴 종료 예고 알림은 이 러닝과 상관없다.
    try {
      unawaited(
        ref
            .read(runProgressNotifierProvider)
            .cancelEndWarning()
            .catchError((Object e) => debugPrint('알림: 종료 예고 취소 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 종료 예고 취소 실패 $e');
    }
    final active = await _repository.findActiveRun();
    if (active == null) return false;
    final engine = _engine = RunEngine(
      clock: ref.read(clockProvider),
      startedAt: active.startedAt,
      restoredSegments: active.segments,
      restoredMovingTime: active.movingTime,
    );
    _runId = active.id;
    _goal = active.goal;
    _locationOff = false;
    _resetNotices();
    // 이미 넘긴 목표는 알리지 않는다(사용자가 이미 알았거나 앱이 죽어 있었다).
    final goal = active.goal;
    _goalReached = goal != null && _reaches(goal, engine.snapshot);
    // 복원 전에 지난 구간은 이미 안내했거나 앱이 죽어 있었다. 이후 구간부터 읽는다.
    _listenVoice(engine, spokenSplits: engine.snapshot.splits.length);
    _weightKg = await _readWeight();
    _publish();
    final decision = checkAutoEnd(
      now: ref.read(clockProvider)(),
      startedAt: active.startedAt,
      state: engine.state,
      pausedAt: engine.pausedAt,
      stateSince: engine.stateSince,
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
    _startTick();
    return true;
  }

  /// 자동 종료 조건을 넘었으면 끝내기 시작하고 true.
  bool _checkAutoEnd() {
    final engine = _engine;
    if (engine == null || _ending || _pendingSummary != null) return false;
    final runState = engine.state;
    if (!activeRunStates.contains(runState)) return false;
    final now = ref.read(clockProvider)();
    final decision = checkAutoEnd(
      now: now,
      startedAt: engine.startedAt!,
      state: runState,
      pausedAt: engine.pausedAt,
      stateSince: engine.stateSince,
      lastPointAt: engine.lastPointAt,
      recordingSince: engine.recordingSince,
      vehicleTime: engine.vehicleTime(now),
      vehicleEndAt: engine.firstVehicleAt,
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
  /// 다시 계산한다.
  ///
  /// 일시정지·자동 일시정지·탈것 의심·신호 끊김 중에 끝낸 요약은 움직인 시간이
  /// 기록이 멈춘 시각([stoppedAt])에서 이미 멈춰 있다. [endAt] 뒤에 점이 없으면
  /// 끝 시각만 바꾼다(잘라내기는 일시정지 시간까지 움직인 시간에서 뺀다). 있으면
  /// 마지막 구간이 [stoppedAt] 까지 기록된 것으로 보고 잘라낸다. 멈춘 뒤
  /// 제자리에서 받아들인 점이 있으면 그 점까지 기록된 것으로 보고, 그 점·거리는
  /// 버리고 움직인 시간은 그대로 둔다. 탈것 의심 합계로 끝내면 [endAt](첫 의심
  /// 구간 전 정상 점)이 [stoppedAt] 보다 앞일 수 있고, 그 사이 구간을 잘라낸다.
  RunSummary _endAt(
    RunSummary summary,
    DateTime endAt, {
    required bool trim,
    required DateTime? stoppedAt,
  }) {
    if (!endAt.isBefore(summary.endedAt)) return summary;
    if (trim) return trimRunEnd(summary, endAt, weightKg: _weightKg);
    final last = summary.segments.lastOrNull;
    final lastAt = last?.last.time;
    final afterEnd = lastAt != null && lastAt.isAfter(endAt);
    final stopped = stoppedAt == null || stoppedAt.isBefore(endAt)
        ? endAt
        : stoppedAt;
    final DateTime recordedEnd;
    var extra = Duration.zero;
    if (afterEnd) {
      final recordedFrom = last!.first.time.isAfter(stopped)
          ? last.first.time
          : stopped;
      if (lastAt.isAfter(recordedFrom)) {
        extra = lastAt.difference(recordedFrom);
      }
      recordedEnd = lastAt.isAfter(stopped) ? lastAt : stopped;
    } else {
      recordedEnd = endAt;
    }
    final asRecorded = RunSummary(
      startedAt: summary.startedAt,
      endedAt: recordedEnd,
      distanceM: summary.distanceM,
      movingTime: summary.movingTime + extra,
      avgPaceSecPerKm: summary.avgPaceSecPerKm,
      calories: summary.calories,
      name: summary.name,
      splits: summary.splits,
      points: summary.points,
      segments: summary.segments,
    );
    if (!afterEnd) return asRecorded;
    return trimRunEnd(asRecorded, endAt, weightKg: _weightKg);
  }

  /// 알림 실패는 러닝 저장과 상관없으므로 버린다.
  /// 저장하지 않은([discarded]) 러닝은 기록을 저장했다고 알리지 않는다.
  void _notifyAutoEnd(
    RunSummary summary,
    AutoEndReason reason, {
    required bool discarded,
  }) {
    // 탈것 의심·신호 끊김은 한참 달리지 못해 끝낸 것이다 (결정 0033).
    final quit =
        reason == AutoEndReason.vehicle || reason == AutoEndReason.signalLost;
    try {
      unawaited(
        ref
            .read(instantNotifierProvider)
            .showNow(
              title: discarded
                  ? _shortRunAutoEndTitle
                  : quit
                  ? _quitTitle
                  : _autoEndTitle,
              body: discarded
                  ? shortRunMessage
                  : quit
                  ? _quitBody
                  : '${formatKm(summary.distanceM)}km 기록을 저장했어요. '
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
          onError: (Object e) {
            _locationOff = e is LocationServiceOffException;
            state = _copyState(
              lastError: _locationOff
                  ? locationServiceOffMessage
                  : _locationErrorMessage,
            );
            _dropSubscription();
          },
          onDone: _dropSubscription,
        );
  }

  /// 위치를 받아야 하는 상태. 자동 일시정지·탈것 의심·신호 끊김은 점을 봐야 풀린다.
  bool get _needsLocation {
    final runState = _engine?.state;
    return runState == RunState.recording ||
        autoStoppedStates.contains(runState);
  }

  /// 오류나 종료로 끊긴 구독을 버린다. 기록·자동 일시정지 중이면 잠시 뒤 다시
  /// 구독하고, 일시정지 중이면 resume 이 다시 구독한다.
  void _dropSubscription() {
    unawaited(_subscription?.cancel().catchError((Object _) {}));
    _subscription = null;
    if (!_needsLocation) return;
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
        _resubscribe();
      }
    });
  }

  /// 끊긴 구독을 다시 한다. 위치 서비스가 꺼져 끊겼으면 켜진 것을 확인한
  /// 뒤에만 구독하고, 아직 꺼져 있으면 [_resubscribeInterval] 뒤 다시 확인한다.
  /// 확인이 실패하면 켜진 것으로 보고 구독한다.
  void _resubscribe() {
    if (!_locationOff) {
      _subscribe();
      return;
    }
    unawaited(_resubscribeWhenServiceOn());
  }

  Future<void> _resubscribeWhenServiceOn() async {
    final engine = _engine;
    bool on;
    try {
      on = await ref.read(locationSourceProvider).isServiceEnabled();
    } catch (_) {
      on = true;
    }
    // 기다리는 동안 일시정지·종료했거나 이미 구독했으면 할 일이 없다.
    if (!ref.mounted ||
        _engine != engine ||
        _ending ||
        _subscription != null ||
        !_needsLocation) {
      return;
    }
    if (!_isForeground) {
      _resubscribePending = true;
      return;
    }
    if (on) {
      _locationOff = false;
      _subscribe();
    } else {
      _resubscribePending = true;
      if (_resubscribeTimer == null) _scheduleResubscribe();
    }
  }

  void _onLifecycleChanged(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    if (_checkAutoEnd()) return;
    if (!_resubscribePending || _subscription != null) return;
    if (!_needsLocation) return;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _resubscribePending = false;
    _resubscribe();
  }

  void _onSample(LocationSample sample) {
    final engine = _engine;
    if (engine == null) return;
    final before = engine.state;
    engine.addSample(sample);
    final appended = engine.lastAppended;
    if (appended.isEmpty) {
      // 자동 일시정지·탈것 의심 중 점은 풀림 판정에 쓰인다. 위치 신호는 살아 있다.
      // 기록 중 점이 탈것 의심으로 바꿨으면 바뀐 상태를 알린다.
      if (engine.state != before || autoStoppedStates.contains(before)) {
        _publish(clearLocationError: true);
      }
      return;
    }
    // 한 번에 넣은 점은 모두 같은 구간이다(자동 재개면 새 구간).
    final segmentIndex = engine.segmentIndex;
    for (final s in appended) {
      _buffer.add((segmentIndex, s));
    }
    _publish(clearLocationError: true);
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
      if (_checkAutoEnd()) return;
      final now = ref.read(clockProvider)();
      _engine?.autoPauseIfStill(now);
      _engine?.signalLostIfSilent(now);
      _publish();
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

  /// 기록이 [goal] 에 닿았는가. 시간 목표는 엔진의 움직인 시간(일시정지·자동 일시정지 제외)이다.
  bool _reaches(RunGoal goal, RunSnapshot snapshot) => switch (goal) {
    DistanceGoal(:final meters) => distanceReachesGoal(
      snapshot.distanceM,
      meters,
    ),
    // 자동 일시정지가 되돌려도 남는 시간으로 판정해, 알린 뒤 끝 판정이 미달이 되지 않게 한다.
    TimeGoal(:final time) => _engine!.confirmedMovingTime >= time,
  };

  /// [clearLocationError] 면 위치 스트림 오류 문구를 지운다. 다른 오류는 둔다.
  void _publish({bool clearLocationError = false}) {
    final engine = _engine;
    if (engine == null) return;
    final clear =
        clearLocationError &&
        (state.lastError == _locationErrorMessage ||
            state.lastError == locationServiceOffMessage);
    final snapshot = engine.snapshot;
    final goal = _goal;
    final reachedNow =
        goal != null && !_goalReached && _reaches(goal, snapshot);
    if (reachedNow) _goalReached = true;
    state = _copyState(snapshot: snapshot, runId: _runId, clearError: clear);
    if (reachedNow) {
      _notifyGoalReached(goal);
      // 같은 경계에서 닿은 구간 안내(엔진 사건, 비동기 전달)를 먼저 읽도록
      // 한 박자 미룬다.
      scheduleMicrotask(() => _speak(VoiceGoalReached(goal)));
    }
    _syncVehicleNotice(snapshot.state);
    _updateProgress(snapshot);
    _syncEndWarning(engine);
  }

  /// 탈것 의심이면 러닝 알림 문구를 켜고 음성으로 안내한다. 다시 켜기는 마지막으로
  /// 켠 뒤 [noticeDebounce] 가 지나야 한다(문턱 언저리에서 오가도 되풀이하지 않는다).
  /// 의심이 아니면 바로 끈다(문구가 제목과 어긋나지 않게).
  void _syncVehicleNotice(RunState runState) {
    if (runState != RunState.vehicle) {
      _vehicleNotice = false;
      return;
    }
    if (_vehicleNotice) return;
    final now = ref.read(clockProvider)();
    final onAt = _vehicleNoticeOnAt;
    if (onAt != null && now.difference(onAt) < noticeDebounce) return;
    _vehicleNotice = true;
    _vehicleNoticeOnAt = now;
    _vehicleAnnounced = true;
    _speak(const VoiceVehicle());
  }

  void _resetNotices() {
    _vehicleNotice = false;
    _vehicleNoticeOnAt = null;
    _vehicleAnnounced = false;
    _signalSpokenAt = null;
    _signalAnnounced = false;
  }

  /// 오래 멈춤 예고 구간에 들어가면 종료 예고를 한 번 띄우고, 구간을 벗어나면
  /// (재개·일시정지 상태 바뀜·종료) 지운다. 알림 실패는 러닝과 상관없으므로 버린다.
  void _syncEndWarning(RunEngine engine) {
    final deadline = _ending || _pendingSummary != null
        ? null
        : autoEndWarningDeadline(
            now: ref.read(clockProvider)(),
            state: engine.state,
            stateSince: engine.stateSince,
            config: ref.read(runGuardConfigProvider),
          );
    if (deadline == _endWarningDeadline) return;
    final shown = _endWarningDeadline != null;
    _endWarningDeadline = deadline;
    final notifier = ref.read(runProgressNotifierProvider);
    try {
      if (deadline == null) {
        if (shown) {
          unawaited(
            notifier.cancelEndWarning().catchError(
              (Object e) => debugPrint('알림: 종료 예고 취소 실패 $e'),
            ),
          );
        }
      } else {
        if (!shown) {
          final left = deadline.difference(ref.read(clockProvider)());
          _speak(
            VoiceEndWarning(
              (left.inMilliseconds / 1000).ceil(),
              paused: engine.state == RunState.paused,
              signalLost: engine.state == RunState.signalLost,
            ),
          );
        }
        unawaited(
          notifier
              .showEndWarning(
                deadline,
                paused: engine.state == RunState.paused,
                signalLost: engine.state == RunState.signalLost,
              )
              .catchError((Object e) => debugPrint('알림: 종료 예고 실패 $e')),
        );
      }
    } catch (e) {
      debugPrint('알림: 종료 예고 실패 $e');
    }
  }

  /// 러닝 알림을 갱신한다. 상태가 바뀌면 바로, 기록 중 거리만 바뀌면 화면
  /// 거리(10m 단위)가 바뀌었고 마지막 갱신에서 3초가 지났을 때만 띄운다.
  /// 시간 목표는 남은 시간이 15초 단계를 넘거나 달성 여부가 바뀔 때도 같은 간격으로 띄운다.
  /// 알림 실패는 러닝과 상관없으므로 버린다.
  void _updateProgress(RunSnapshot snapshot) {
    if (!activeRunStates.contains(snapshot.state)) return;
    final now = ref.read(clockProvider)();
    final km = formatKm(snapshot.distanceM);
    final goal = _goal;
    // 달성한 뒤에는 15초 단계가 알림 갱신을 일으키지 않게 키에서 뺀다.
    final timeStep = goal is TimeGoal && !_goalReached
        ? (goal.time - snapshot.movingTime).inSeconds ~/
              _progressTimeStepSeconds
        : null;
    final stateChanged =
        snapshot.state != _progressState ||
        _vehicleNotice != _progressVehicleNotice;
    final shownAt = _progressShownAt;
    if (!stateChanged) {
      if (km == _progressKm &&
          timeStep == _progressTimeStep &&
          _goalReached == _progressReached) {
        return;
      }
      if (shownAt != null && now.difference(shownAt) < _progressMinInterval) {
        return;
      }
    }
    _progressState = snapshot.state;
    _progressVehicleNotice = _vehicleNotice;
    _progressKm = km;
    _progressTimeStep = timeStep;
    _progressReached = _goalReached;
    _progressShownAt = now;
    try {
      unawaited(
        ref
            .read(runProgressNotifierProvider)
            .show(
              runProgressContent(
                state: snapshot.state,
                distanceM: snapshot.distanceM,
                movingTime: snapshot.movingTime,
                goal: _goal,
                goalReached: _goalReached,
                vehicleNotice: _vehicleNotice,
              ),
            )
            .catchError((Object e) => debugPrint('알림: 러닝 진행 알림 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 러닝 진행 알림 실패 $e');
    }
  }

  /// 러닝이 끝나면 그 러닝의 목표 달성 알림이 알림창에 남지 않게 지운다.
  /// 종료 예고는 상태 발행(`_syncEndWarning`)이 이미 지웠다. 자동 종료 알림은
  /// 끝난 뒤에 알리는 것이라 지우지 않는다.
  /// 이전 러닝의 자동 종료 알림을 지운다. 러닝 사이에는 남겨 두고 새 러닝을
  /// 시작할 때만 부른다. 실패해도 러닝은 그대로 시작한다.
  void _cancelAutoEndNotice() {
    try {
      unawaited(
        ref
            .read(instantNotifierProvider)
            .cancelAutoEnd()
            .catchError((Object e) => debugPrint('알림: 자동 종료 알림 취소 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 자동 종료 알림 취소 실패 $e');
    }
  }

  void _cancelRunScopedAlerts() {
    _endWarningDeadline = null;
    try {
      unawaited(
        ref
            .read(instantNotifierProvider)
            .cancelGoalReached()
            .catchError((Object e) => debugPrint('알림: 목표 달성 알림 취소 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 목표 달성 알림 취소 실패 $e');
    }
  }

  void _cancelProgress() {
    _progressState = null;
    _progressVehicleNotice = false;
    _progressKm = null;
    _progressTimeStep = null;
    _progressReached = false;
    _progressShownAt = null;
    try {
      unawaited(
        ref
            .read(runProgressNotifierProvider)
            .cancel()
            .catchError((Object e) => debugPrint('알림: 러닝 진행 알림 취소 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 러닝 진행 알림 취소 실패 $e');
    }
  }

  /// 엔진 사건을 듣는다. [spokenSplits] 까지의 구간은 이미 안내한 것으로 본다.
  void _listenVoice(RunEngine engine, {required int spokenSplits}) {
    _voiceSubscription?.cancel();
    _spokenSplits = spokenSplits;
    _voiceSubscription = engine.events.listen((event) {
      switch (event) {
        case SplitCompleted(:final split):
          _speakSplit(engine, split);
        case StateChanged(from: RunState.recording, to: RunState.autoPaused):
          _speak(const VoiceAutoPaused());
        case StateChanged(from: RunState.autoPaused, to: RunState.recording):
          _speak(const VoiceAutoResumed());
        // 신호 끊김은 60초에 한 번 읽고, 읽은 끊김이 풀릴 때만 "다시 기록해요".
        case StateChanged(:final from, to: RunState.signalLost):
          if (from == RunState.vehicle) _vehicleAnnounced = false;
          final now = ref.read(clockProvider)();
          final spokenAt = _signalSpokenAt;
          _signalAnnounced =
              spokenAt == null || now.difference(spokenAt) >= noticeDebounce;
          if (_signalAnnounced) {
            _signalSpokenAt = now;
            _speak(const VoiceSignalLost());
          }
        // 탈것 의심 안내는 상태 발행(`_syncVehicleNotice`)이 60초에 한 번 읽는다.
        // 풀림은 그 구간을 안내했을 때만 읽는다.
        case StateChanged(from: RunState.vehicle, :final to):
          if (to == RunState.recording && _vehicleAnnounced) {
            _speak(const VoiceAutoResumed());
          }
          _vehicleAnnounced = false;
        case StateChanged(from: RunState.signalLost, :final to):
          if (to == RunState.recording && _signalAnnounced) {
            _speak(const VoiceAutoResumed());
          }
          _signalAnnounced = false;
        case StateChanged() || RunEnded():
          break;
      }
    });
  }

  void _stopVoice() {
    _voiceSubscription?.cancel();
    _voiceSubscription = null;
  }

  /// [split] 까지의 누적 움직인 시간과 평균 페이스를 읽는다.
  /// 각 구간은 1km 이므로 누적 시간은 구간 시간의 합, 평균 페이스는 그 시간을
  /// 구간 번호(km)로 나눈 값이다.
  void _speakSplit(RunEngine engine, Split split) {
    if (split.index <= _spokenSplits) return;
    _spokenSplits = split.index;
    var elapsed = Duration.zero;
    for (final s in engine.snapshot.splits) {
      if (s.index <= split.index) elapsed += s.duration;
    }
    _speak(
      VoiceSplit(
        km: split.index,
        elapsed: elapsed,
        avgPaceSecPerKm:
            elapsed.inMicroseconds /
            Duration.microsecondsPerSecond /
            split.index,
      ),
    );
  }

  /// 음성 안내 실패(꺼짐 포함)는 러닝과 상관없다. [VoiceGuide.say] 가 던지지 않는다.
  void _speak(VoiceEvent event) {
    try {
      unawaited(ref.read(voiceGuideProvider).say(event));
    } catch (e) {
      debugPrint('음성 안내 실패: $e');
    }
  }

  /// 알림 실패는 러닝과 상관없으므로 버린다.
  void _notifyGoalReached(RunGoal goal) {
    final label = switch (goal) {
      DistanceGoal(:final meters) => '${formatTargetKm(meters)}km',
      TimeGoal(:final time) => '${time.inMinutes}분',
    };
    try {
      unawaited(
        ref
            .read(instantNotifierProvider)
            .showGoalReached(
              title: _goalReachedTitle,
              body: '$label 목표를 채웠어요. 종료할 때까지 기록은 이어져요',
            )
            .catchError((Object e) => debugPrint('알림: 목표 달성 알림 실패 $e')),
      );
    } catch (e) {
      debugPrint('알림: 목표 달성 알림 실패 $e');
    }
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
      goal: _goal,
      goalReached: _goalReached,
      discardedShortRun: state.discardedShortRun,
    );
  }
}
