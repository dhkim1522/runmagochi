import 'dart:async';

import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/run_controller.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

RunSnapshot snap(
  RunState state, {
  double distanceM = 0,
  Duration movingTime = Duration.zero,
  double? avg,
  double? current,
}) => RunSnapshot(
  state: state,
  distanceM: distanceM,
  movingTime: movingTime,
  avgPaceSecPerKm: avg,
  currentPaceSecPerKm: current,
  splits: const [],
);

class FakeController extends RunController {
  FakeController({
    this.restore = false,
    RunSnapshot? initial,
    this.error,
    this.startError,
    this.endError,
    this.initialSummary,
  }) : _initial = initial ?? snap(RunState.idle);

  final bool restore;
  final RunSnapshot _initial;
  final String? error;
  final Object? startError;
  final RunSummary? initialSummary;
  Object? endError;
  final List<String> calls = [];

  @override
  RunViewState build() => RunViewState(
    snapshot: _initial,
    lastError: error,
    lastSummary: initialSummary,
  );

  @override
  Future<void> start() async {
    calls.add('start');
    await Future<void>.delayed(Duration.zero);
    if (startError != null) throw startError!;
    state = RunViewState(
      snapshot: snap(RunState.recording, distanceM: 1230),
      runId: 'r',
    );
  }

  @override
  void pause() {
    calls.add('pause');
    state = RunViewState(
      snapshot: snap(RunState.paused, distanceM: 1230),
      runId: 'r',
      lastError: state.lastError,
    );
  }

  @override
  void resume() {
    calls.add('resume');
    state = RunViewState(
      snapshot: snap(RunState.recording, distanceM: 1230),
      runId: 'r',
      lastError: state.lastError,
    );
  }

  @override
  Future<RunSummary> end() async {
    calls.add('end');
    if (endError != null) throw endError!;
    final summary = RunSummary(
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
      distanceM: 0,
      movingTime: Duration.zero,
      avgPaceSecPerKm: null,
      calories: 0,
      name: 'x',
      splits: const [],
      points: const [],
    );
    state = RunViewState(snapshot: snap(RunState.idle), lastSummary: summary);
    return summary;
  }

  @override
  Future<bool> restoreIfAny() async {
    calls.add('restore');
    if (restore) {
      state = RunViewState(
        snapshot: snap(RunState.paused, distanceM: 500),
        runId: 'r',
      );
    }
    return restore;
  }
}

class FakeGate implements PermissionGate {
  FakeGate(this.result);
  GateResult result;
  int checks = 0;

  @override
  Future<GateResult> check() async {
    checks++;
    return result;
  }

  @override
  Future<GateResult> requestLocation() async => result;

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  void dismissBatteryGuide() {}
}

class FakeRepo implements RunRepository {
  FakeRepo(this.total, {this.runs = const [], this.details = const {}});
  (double, int) total;
  List<RunListItem> runs;
  Map<String, RunDetail> details;

  /// 지정하면 weeklyTotal 이 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdWeekly;

  @override
  Future<List<RunListItem>> listRuns() async => runs;

  @override
  Future<RunDetail?> getRun(String id) async => details[id];

  @override
  Future<(double, int)> weeklyTotal(DateTime now) async {
    await holdWeekly?.future;
    return total;
  }

  /// 지정하면 deleteRun 이 이 오류를 던진다.
  Object? deleteError;
  final List<String> deleted = [];

  /// 목록·상세에서 빼고 주간 합계에서 그 거리와 1회를 뺀다.
  @override
  Future<void> deleteRun(String id) async {
    if (deleteError != null) throw deleteError!;
    deleted.add(id);
    final item = runs.where((r) => r.id == id).firstOrNull;
    runs = runs.where((r) => r.id != id).toList();
    details = {...details}..remove(id);
    if (item != null) total = (total.$1 - item.distanceM, total.$2 - 1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeGrowthService implements GrowthService {
  FakeGrowthService(this.state);
  GrowthState state;
  int syncs = 0;
  int loads = 0;

  /// 지정하면 load 가 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdLoad;
  final List<double> targets = [];

  /// 지정하면 다음 sync 한 번만 이 값을 돌려주고 비운다.
  GrowthGain? syncGain;

  /// 지정하면 다음 setWeeklyTarget 한 번만 이 값을 돌려준다.
  GrowthGain? targetGain;

  /// true 면 sync 가 실패한다.
  bool syncFails = false;

  @override
  Future<GrowthGain> sync() async {
    syncs++;
    if (syncFails) throw StateError('sync failed');
    final g = syncGain;
    syncGain = null; // 실제 서비스처럼 한 번 받으면 소모된다.
    return g ??
        const GrowthGain(
          distanceXp: 0,
          goalBonusXp: 0,
          levelBefore: 1,
          levelAfter: 1,
          stageBefore: 1,
          stageAfter: 1,
        );
  }

  @override
  Future<GrowthState> load() async {
    loads++;
    final hold = holdLoad;
    if (hold != null) await hold.future;
    return state;
  }

  final List<(String, DateTime)> removed = [];

  @override
  Future<void> runRemoved(String runId, DateTime runStartedAt) async {
    removed.add((runId, runStartedAt));
  }

  @override
  Future<GrowthGain> setWeeklyTarget(double targetM) async {
    targets.add(targetM);
    final g = targetGain;
    targetGain = null;
    return g ?? await sync();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

GrowthState growthState({
  int level = 3,
  int xpIntoLevel = 58,
  double weekTargetM = 10000,
  double weekDistanceM = 6200,
  bool weekAchieved = false,
  int streakWeeks = 0,
  AvatarKind kind = AvatarKind.chick,
}) => GrowthState(
  kind: kind,
  name: '러니',
  totalXp: 25 * level * (level - 1) + xpIntoLevel,
  level: LevelProgress(
    level: level,
    xpIntoLevel: xpIntoLevel,
    xpForNext: 50 * level,
  ),
  stage: 1,
  xpToNextStage: 100,
  mood: AvatarMood.normal,
  weekTargetM: weekTargetM,
  weekDistanceM: weekDistanceM,
  weekAchieved: weekAchieved,
  streakWeeks: streakWeeks,
  totalDistanceM: 0,
  runCount: 0,
);
