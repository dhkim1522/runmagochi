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
  }) : _initial = initial ?? snap(RunState.idle);

  final bool restore;
  final RunSnapshot _initial;
  final String? error;
  final Object? startError;
  Object? endError;
  final List<String> calls = [];

  @override
  RunViewState build() => RunViewState(snapshot: _initial, lastError: error);

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

  @override
  Future<List<RunListItem>> listRuns() async => runs;

  @override
  Future<RunDetail?> getRun(String id) async => details[id];

  @override
  Future<(double, int)> weeklyTotal(DateTime now) async => total;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
