import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
import 'package:runmagochi/run/app/app_lifecycle.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/app/run_controller.dart';
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

import '../ui/fakes.dart' show FakeRunProgressNotifier, FakeSpeaker;

const _lat0 = 37.5;
const _lng0 = 127.0;
const _runId = 'run-1';
final _t0 = DateTime(2026, 10, 21, 7);

double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

LocationSample _sample(DateTime time, double meters) => LocationSample(
  time: time,
  latitude: _northOf(meters),
  longitude: _lng0,
  accuracy: 5,
);

class _Repo implements RunRepository {
  ActiveRun? activeRun;
  final completed = <(String, RunSummary)>[];
  final discarded = <String>[];

  @override
  Future<RunGoal?> lastGoal() async => null;
  @override
  Future<String> createActiveRun(
    DateTime startedAt, {
    required RunGoal goal,
  }) async => _runId;
  @override
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  }) async {}
  @override
  Future<ActiveRun?> findActiveRun() async => activeRun;
  @override
  Future<void> completeRun(String runId, RunSummary summary) async {
    completed.add((runId, summary));
  }

  @override
  Future<void> discardActiveRun(String runId) async {
    discarded.add(runId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Profile implements ProfileRepository {
  @override
  Future<double?> weightKg() async => null;
  @override
  Future<bool> voiceGuide() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Location implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();
  @override
  Stream<LocationSample> watch() => controller.stream;

  @override
  Future<bool> isServiceEnabled() async => true;
}

class _Lifecycle implements AppLifecycle {
  @override
  AppLifecycleState current = AppLifecycleState.resumed;
  @override
  Stream<AppLifecycleState> get changes => const Stream.empty();
}

class _Instant implements InstantNotifier {
  var goalCancelled = 0;
  @override
  Future<void> cancelGoalReached() async => goalCancelled++;

  final shown = <(String, String)>[];
  @override
  Future<void> showNow({required String title, required String body}) async {
    shown.add((title, body));
  }

  @override
  Future<void> showGoalReached({required String title, required String body}) =>
      showNow(title: title, body: body);
}

class _Env {
  _Env(this.async);
  final FakeAsync async;
  final repo = _Repo();
  final location = _Location();
  final instant = _Instant();
  final progress = FakeRunProgressNotifier();
  late final ProviderContainer container;

  RunController get controller =>
      container.read(runControllerProvider.notifier);
  RunViewState get view => container.read(runControllerProvider);

  void sampleAt(Duration at, double meters) {
    async.elapse(at - async.elapsed);
    location.controller.add(_sample(_t0.add(at), meters));
    async.flushMicrotasks();
  }

  /// 3m/s 로 [steps] 초 달린다(거리 = steps × 3m).
  void runSteps(int steps) {
    controller.start(goal: DistanceGoal(3000));
    async.flushMicrotasks();
    for (var i = 1; i <= steps; i++) {
      sampleAt(Duration(seconds: i), i * 3.0);
    }
  }
}

void _run(void Function(_Env env) body, {ActiveRun? activeRun}) {
  fakeAsync((async) {
    final env = _Env(async);
    env.repo.activeRun = activeRun;
    env.container = ProviderContainer(
      overrides: [
        speakerProvider.overrideWithValue(FakeSpeaker()),
        runRepositoryProvider.overrideWithValue(env.repo),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        runProgressNotifierProvider.overrideWithValue(env.progress),
        locationSourceProvider.overrideWithValue(env.location),
        appLifecycleProvider.overrideWithValue(_Lifecycle()),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(env.instant),
      ],
    );
    env.container.read(runControllerProvider.notifier);
    body(env);
    env.container.dispose();
    async.flushMicrotasks();
    expect(async.pendingTimers, isEmpty);
  });
}

void main() {
  test('999m 에서 끝내면 저장하지 않고 진행 중 러닝을 지운다', () {
    _run((env) {
      env.runSteps(334); // 첫 점은 거리에 안 들어가 999m
      env.controller.end();
      env.async.flushMicrotasks();

      expect(env.repo.completed, isEmpty);
      expect(env.repo.discarded, [_runId]);
      final view = env.view;
      expect(view.discardedShortRun, isTrue);
      expect(view.lastSummary, isNull);
      expect(view.lastRunId, isNull);
      expect(view.runId, isNull);
      expect(view.snapshot.state, RunState.idle);
      expect(env.progress.cancels, 1);
    });
  });

  test('1000m 이상이면 저장한다', () {
    _run((env) {
      env.runSteps(335); // 1002m
      env.controller.end();
      env.async.flushMicrotasks();

      expect(env.repo.discarded, isEmpty);
      expect(env.repo.completed.single.$1, _runId);
      expect(env.view.discardedShortRun, isFalse);
      expect(env.view.lastSummary, isNotNull);
    });
  });

  test('새 러닝을 시작하면 버렸다는 표시가 사라진다', () {
    _run((env) {
      env.runSteps(10);
      env.controller.end();
      env.async.flushMicrotasks();
      expect(env.view.discardedShortRun, isTrue);

      env.controller.start(goal: DistanceGoal(3000));
      env.async.flushMicrotasks();
      expect(env.view.discardedShortRun, isFalse);
    });
  });

  test('오래 멈춰 자동 종료된 0.5km 러닝은 저장하지 않고 짧은 러닝 알림을 띄운다', () {
    _run((env) {
      env.runSteps(168); // 501m
      env.async.elapse(const Duration(minutes: 6));
      env.async.flushMicrotasks();

      expect(env.repo.completed, isEmpty);
      expect(env.repo.discarded, [_runId]);
      expect(env.view.discardedShortRun, isTrue);
      expect(env.view.autoEnded, isTrue);
      expect(env.instant.shown, [('러닝을 마쳤어요', '1km 미만은 기록하지 않아요')]);
    });
  });

  test('복원한 0.3km 러닝을 끝내면 저장하지 않는다', () {
    final startedAt = _t0.subtract(const Duration(minutes: 10));
    final active = ActiveRun(
      id: _runId,
      startedAt: startedAt,
      segments: [
        for (var i = 0; i < 1; i++)
          [
            for (var k = 0; k <= 3; k++)
              _sample(startedAt.add(Duration(seconds: 40 * k)), k * 100.0),
          ],
      ],
      movingTime: const Duration(seconds: 120),
    );
    _run(activeRun: active, (env) {
      bool? restored;
      env.controller.restoreIfAny().then((r) => restored = r);
      env.async.flushMicrotasks();
      expect(restored, isTrue);

      env.controller.end();
      env.async.flushMicrotasks();

      expect(env.repo.completed, isEmpty);
      expect(env.repo.discarded, [_runId]);
      expect(env.view.discardedShortRun, isTrue);
    });
  });

  test('복원 때 6시간이 지나 바로 끝나는 짧은 러닝도 저장하지 않는다', () {
    final startedAt = _t0.subtract(const Duration(hours: 7));
    final active = ActiveRun(
      id: _runId,
      startedAt: startedAt,
      segments: [
        [
          _sample(startedAt, 0),
          _sample(startedAt.add(const Duration(seconds: 60)), 100),
        ],
      ],
      movingTime: const Duration(seconds: 60),
    );
    _run(activeRun: active, (env) {
      bool? restored;
      env.controller.restoreIfAny().then((r) => restored = r);
      env.async.flushMicrotasks();

      expect(restored, isFalse);
      expect(env.repo.completed, isEmpty);
      expect(env.repo.discarded, [_runId]);
      expect(env.view.discardedShortRun, isTrue);
    });
  });
}
