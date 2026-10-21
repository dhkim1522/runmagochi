import 'dart:async';

import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/run_controller.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/domain/catalog.dart';

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
    this.initialGoalM,
    this.initialGoalReached = false,
  }) : _initial = initial ?? snap(RunState.idle);

  final bool restore;
  final RunSnapshot _initial;
  final String? error;
  final Object? startError;
  final RunSummary? initialSummary;
  final double? initialGoalM;
  final bool initialGoalReached;
  Object? endError;
  final List<String> calls = [];

  /// start 로 받은 목표들.
  final List<RunGoal> startGoals = [];

  @override
  RunViewState build() => RunViewState(
    snapshot: _initial,
    lastError: error,
    lastSummary: initialSummary,
    goal: initialGoalM == null ? null : DistanceGoal(initialGoalM!),
    goalReached: initialGoalReached,
  );

  /// 목표 달성 상태로 바꾼다(거리는 그대로).
  void reachGoal() => state = RunViewState(
    snapshot: state.snapshot,
    runId: state.runId,
    goal: state.goal,
    goalReached: true,
  );

  @override
  Future<void> start({required RunGoal goal}) async {
    calls.add('start');
    startGoals.add(goal);
    await Future<void>.delayed(Duration.zero);
    if (startError != null) throw startError!;
    state = RunViewState(
      snapshot: snap(RunState.recording, distanceM: 1230),
      runId: 'r',
      goal: goal,
    );
  }

  @override
  void pause() {
    calls.add('pause');
    state = RunViewState(
      snapshot: snap(RunState.paused, distanceM: 1230),
      runId: 'r',
      lastError: state.lastError,
      goal: state.goal,
      goalReached: state.goalReached,
    );
  }

  @override
  void resume() {
    calls.add('resume');
    state = RunViewState(
      snapshot: snap(RunState.recording, distanceM: 1230),
      runId: 'r',
      lastError: state.lastError,
      goal: state.goal,
      goalReached: state.goalReached,
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
    state = RunViewState(
      snapshot: snap(RunState.idle),
      lastSummary: summary,
      lastRunId: 'r',
    );
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

  /// 가장 최근에 시작한 러닝의 목표(m). null 이면 없다.
  double? lastGoalM;

  /// 지정하면 lastGoal 이 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdLastGoal;

  @override
  Future<RunGoal?> lastGoal() async {
    await holdLastGoal?.future;
    final m = lastGoalM;
    return m == null ? null : DistanceGoal(m);
  }

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

/// 예약 알림 취소 호출을 세는 가짜. [fail] 이면 실패한다.
class FakeNotificationScheduler implements NotificationScheduler {
  int cancels = 0;
  bool fail = false;

  @override
  Future<void> cancelScheduled() async {
    cancels++;
    if (fail) throw StateError('취소 실패');
  }
}

class FakeGrowthService implements GrowthService {
  FakeGrowthService(this.state);
  GrowthState state;
  int syncs = 0;
  int loads = 0;

  /// 지정하면 load 가 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdLoad;

  /// 지정하면 다음 sync 한 번만 이 값을 돌려주고 비운다.
  GrowthGain? syncGain;

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

  final List<(String, DateTime)> revised = [];

  /// runRevised 가 돌려줄 변화. 없으면 빈 변화(레벨 1 그대로).
  GrowthGain? revisedGain;

  @override
  Future<GrowthGain> runRevised(String runId, DateTime runStartedAt) async {
    revised.add((runId, runStartedAt));
    return revisedGain ??
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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

GrowthState growthState({
  int level = 3,
  int xpIntoLevel = 58,
  AvatarKind kind = AvatarKind.chick,
  String name = '러니',
}) => GrowthState(
  kind: kind,
  name: name,
  totalXp: 25 * level * (level - 1) + xpIntoLevel,
  level: LevelProgress(
    level: level,
    xpIntoLevel: xpIntoLevel,
    xpForNext: 50 * level,
  ),
  stage: 1,
  xpToNextStage: 100,
  mood: AvatarMood.normal,
  totalDistanceM: 0,
  runCount: 0,
);

/// 프로필 저장소 가짜. 기본은 첫 실행을 마친 상태다(홈부터 보인다).
class FakeProfile implements ProfileRepository {
  FakeProfile({this.onboarded = true});
  bool onboarded;
  int marks = 0;
  double? weight;

  /// true 면 markOnboarded 가 실패한다.
  bool markFails = false;

  bool voice = true;

  @override
  Future<bool> voiceGuide() async => voice;

  @override
  Future<void> setVoiceGuide(bool on) async => voice = on;

  @override
  Future<bool> isOnboarded() async => onboarded;

  @override
  Future<void> markOnboarded() async {
    if (markFails) throw StateError('mark failed');
    marks++;
    onboarded = true;
  }

  @override
  Future<double?> weightKg() async => weight;

  @override
  Future<void> setWeightKg(double? kg) async => weight = kg;
}

/// 러닝 진행 알림 기록용 가짜.
class FakeRunProgressNotifier implements RunProgressNotifier {
  final shown = <RunProgressContent>[];
  int cancels = 0;

  /// 띄운 종료 예고의 끝날 시각.
  final warnings = <DateTime>[];

  /// [warnings] 와 같은 순서로, 사용자 일시정지 문구로 띄웠는지.
  final warningPaused = <bool>[];
  int warningCancels = 0;
  bool fails = false;

  @override
  Future<void> show(RunProgressContent content) async {
    if (fails) throw StateError('알림 실패');
    shown.add(content);
  }

  @override
  Future<void> cancel() async {
    if (fails) throw StateError('알림 실패');
    cancels++;
  }

  @override
  Future<void> showEndWarning(DateTime deadline, {required bool paused}) async {
    if (fails) throw StateError('알림 실패');
    warnings.add(deadline);
    warningPaused.add(paused);
  }

  @override
  Future<void> cancelEndWarning() async {
    if (fails) throw StateError('알림 실패');
    warningCancels++;
  }
}

/// 상점 저장소 가짜. 구매·장착이 실제처럼 잔액·보유·장착을 바꾼다.
class FakeShop implements ShopRepository {
  FakeShop([
    this.entries = const [],
    this.bal = 0,
    this.equippedNow = const Equipped(),
    Set<String>? owned,
  ]) : owned = owned ?? {};
  final List<CoinEntry> entries;
  int bal;
  Equipped equippedNow;
  final Set<String> owned;

  /// purchase 로 불린 (id, 가격) 목록.
  final List<(String, int)> purchases = [];

  /// 지정하면 purchase 가 이 Completer 가 끝날 때까지 기다린다.
  Completer<void>? holdPurchase;

  @override
  Future<int> balance() async => bal;
  @override
  Future<List<CoinEntry>> coinHistory() async => entries;
  @override
  Future<Set<String>> ownedItemIds() async => {...owned};
  @override
  Future<void> purchase(String itemId, int price) async {
    purchases.add((itemId, price));
    await holdPurchase?.future;
    if (owned.contains(itemId)) throw const AlreadyOwned();
    if (bal < price) throw const InsufficientCoins();
    bal -= price;
    owned.add(itemId);
  }

  @override
  Future<Equipped> equipped() async => equippedNow;
  @override
  Future<void> equip(ItemSlot slot, String? itemId) async {
    if (itemId != null && !owned.contains(itemId)) throw const NotOwned();
    equippedNow = Equipped(
      hatItemId: slot == ItemSlot.hat ? itemId : equippedNow.hatItemId,
      accessoryItemId: slot == ItemSlot.accessory
          ? itemId
          : equippedNow.accessoryItemId,
    );
  }
}
