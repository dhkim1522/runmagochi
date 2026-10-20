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
import 'package:runmagochi/run/app/run_guard.dart';
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/geo.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

const _lat0 = 37.5;
const _lng0 = 127.0;
const _runId = 'run-1';
const _title = '러닝을 자동으로 마쳤어요';
const _fastTitle = '빠른 이동이 감지돼 러닝을 마쳤어요';
final _t0 = DateTime(2026, 10, 18, 7);

double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

LocationSample _sample(DateTime time, double meters) => LocationSample(
  time: time,
  latitude: _northOf(meters),
  longitude: _lng0,
  accuracy: 5,
);

double _dist(double a, double b) =>
    haversineMeters(_northOf(a), _lng0, _northOf(b), _lng0);

class _Repo implements RunRepository {
  ActiveRun? activeRun;
  Object? completeError;
  final completed = <(String, RunSummary)>[];

  @override
  Future<double?> lastGoalM() async => null;

  @override
  Future<String> createActiveRun(
    DateTime startedAt, {
    required double goalM,
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
    final error = completeError;
    if (error != null) {
      completeError = null;
      throw error;
    }
    completed.add((runId, summary));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Profile implements ProfileRepository {
  @override
  Future<double?> weightKg() async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Location implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();
  bool get isListened => controller.hasListener;
  @override
  Stream<LocationSample> watch() => controller.stream;
}

class _Lifecycle implements AppLifecycle {
  @override
  AppLifecycleState current = AppLifecycleState.resumed;
  final _changes = StreamController<AppLifecycleState>.broadcast(sync: true);
  @override
  Stream<AppLifecycleState> get changes => _changes.stream;
  void set(AppLifecycleState s) {
    current = s;
    _changes.add(s);
  }
}

class _Notifier implements InstantNotifier {
  final shown = <(String, String)>[];
  bool fails = false;

  @override
  Future<void> showNow({required String title, required String body}) async {
    if (fails) throw StateError('알림 실패');
    shown.add((title, body));
  }
}

class _Env {
  _Env(this.async);
  final FakeAsync async;
  late final ProviderContainer container;
  final repo = _Repo();
  final location = _Location();
  final lifecycle = _Lifecycle();
  final notifier = _Notifier();

  RunController get controller =>
      container.read(runControllerProvider.notifier);
  RunViewState get view => container.read(runControllerProvider);

  /// [at] 시각(시작 기준)에 [meters] 지점의 점을 보낸다.
  void sampleAt(Duration at, double meters) {
    async.elapse(at - async.elapsed);
    location.controller.add(_sample(_t0.add(at), meters));
    async.flushMicrotasks();
  }
}

void _run(
  void Function(_Env env) body, {
  ActiveRun? activeRun,
  RunGuardConfig? config,
}) {
  fakeAsync((async) {
    final env = _Env(async);
    env.repo.activeRun = activeRun;
    final container = env.container = ProviderContainer(
      overrides: [
        runRepositoryProvider.overrideWithValue(env.repo),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        locationSourceProvider.overrideWithValue(env.location),
        appLifecycleProvider.overrideWithValue(env.lifecycle),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(env.notifier),
        if (config != null) runGuardConfigProvider.overrideWithValue(config),
      ],
    );
    container.read(runControllerProvider.notifier);
    body(env);
    container.dispose();
    async.flushMicrotasks();
    expect(async.pendingTimers, isEmpty);
    expect(env.location.isListened, isFalse);
  });
}

void main() {
  /// 시작 뒤 1~5초에 3m 씩 점 5개.
  void runFiveSamples(_Env env) {
    env.controller.start(goalM: 3000);
    env.async.flushMicrotasks();
    for (var i = 1; i <= 5; i++) {
      env.sampleAt(Duration(seconds: i), i * 3.0);
    }
  }

  const lastPointOffset = Duration(seconds: 5);
  final lastPoint = _t0.add(lastPointOffset);
  final fiveDistance = [
    for (var i = 1; i < 5; i++) _dist(i * 3.0, (i + 1) * 3.0),
  ].reduce((a, b) => a + b);

  test('기록 중 마지막 점 뒤 19분 59초엔 계속, 20분엔 마지막 점으로 끝낸다', () {
    _run((env) {
      runFiveSamples(env);
      env.async.elapse(
        lastPointOffset +
            const Duration(minutes: 19, seconds: 59) -
            env.async.elapsed,
      );
      expect(env.view.snapshot.state, RunState.recording);
      expect(env.repo.completed, isEmpty);

      env.async.elapse(const Duration(seconds: 1));
      final (runId, summary) = env.repo.completed.single;
      expect(runId, _runId);
      expect(summary.endedAt, lastPoint);
      expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
      expect(summary.points, hasLength(5));
      // 잘라낸 20분은 움직인 시간에서 빠진다.
      expect(summary.movingTime, const Duration(seconds: 5));
      expect(env.view.autoEnded, isTrue);
      expect(env.view.lastSummary, same(summary));
      expect(env.view.snapshot.state, RunState.idle);
      expect(env.view.runId, isNull);
      expect(env.notifier.shown, [(_title, '0.01km 기록을 저장했어요. 요약에서 확인하세요.')]);
    });
  });

  test('일시정지 중에는 30분이 지나도 끝내지 않는다', () {
    _run((env) {
      runFiveSamples(env);
      env.controller.pause();
      env.async.elapse(const Duration(minutes: 30));
      expect(env.view.snapshot.state, RunState.paused);
      expect(env.repo.completed, isEmpty);
      expect(env.notifier.shown, isEmpty);
      env.controller.end();
      env.async.flushMicrotasks();
    });
  });

  test('재개하면 20분을 재개 시각부터 다시 센다', () {
    _run((env) {
      runFiveSamples(env);
      env.controller.pause();
      env.async.elapse(const Duration(minutes: 30));
      env.controller.resume();
      final resumedAt = _t0.add(env.async.elapsed);
      env.async.elapse(const Duration(minutes: 19, seconds: 59));
      expect(env.repo.completed, isEmpty);

      env.async.elapse(const Duration(seconds: 1));
      final summary = env.repo.completed.single.$2;
      expect(summary.endedAt, resumedAt);
      expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
      // 일시정지 전 움직인 시간만 남는다.
      expect(summary.movingTime, const Duration(seconds: 5));
    });
  });

  test('일시정지 중에도 시작 6시간이면 끝내고 끝 시각은 마지막 점', () {
    _run((env) {
      runFiveSamples(env);
      env.async.elapse(const Duration(seconds: 5));
      env.controller.pause();
      env.async.elapse(
        const Duration(hours: 5, minutes: 59, seconds: 59) - env.async.elapsed,
      );
      expect(env.repo.completed, isEmpty);

      env.async.elapse(const Duration(seconds: 1));
      final summary = env.repo.completed.single.$2;
      expect(summary.endedAt, lastPoint);
      expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
      // 일시정지까지 움직인 시간은 그대로 둔다.
      expect(summary.movingTime, const Duration(seconds: 10));
      expect(env.view.autoEnded, isTrue);
      expect(env.notifier.shown.single.$1, _title);
    });
  });

  test('계속 점이 들어와도 시작 6시간이면 끝낸다', () {
    _run(config: const RunGuardConfig(max: Duration(seconds: 30)), (env) {
      env.controller.start(goalM: 3000);
      env.async.flushMicrotasks();
      for (var i = 1; i <= 29; i++) {
        env.sampleAt(Duration(seconds: i), i * 3.0);
      }
      env.async.elapse(const Duration(seconds: 1));
      final summary = env.repo.completed.single.$2;
      expect(summary.endedAt, _t0.add(const Duration(seconds: 29)));
      expect(summary.points, hasLength(29));
    });
  });

  test('provider 로 줄인 기준을 따른다', () {
    _run(config: const RunGuardConfig(idle: Duration(seconds: 30)), (env) {
      runFiveSamples(env);
      env.async.elapse(const Duration(seconds: 29));
      expect(env.repo.completed, isEmpty);
      env.async.elapse(const Duration(seconds: 1));
      expect(env.repo.completed.single.$2.endedAt, lastPoint);
    });
  });

  test('화면으로 돌아올 때도 판정한다', () {
    _run(config: const RunGuardConfig(idle: Duration(milliseconds: 1500)), (
      env,
    ) {
      runFiveSamples(env);
      // 다음 틱(1초 단위) 전에 화면 복귀로 판정한다.
      env.async.elapse(const Duration(milliseconds: 1600));
      expect(env.repo.completed, isEmpty);
      env.lifecycle.set(AppLifecycleState.resumed);
      env.async.flushMicrotasks();
      expect(env.repo.completed.single.$2.endedAt, lastPoint);
    });
  });

  test('저장이 실패하면 lastError, 다시 end 하면 자동 종료로 저장하고 알린다', () {
    _run((env) {
      runFiveSamples(env);
      env.repo.completeError = StateError('db');
      env.async.elapse(const Duration(minutes: 20));
      expect(env.repo.completed, isEmpty);
      expect(env.view.snapshot.state, RunState.ended);
      expect(env.view.lastError, isNotNull);
      expect(env.notifier.shown, isEmpty);

      env.controller.end();
      env.async.flushMicrotasks();
      expect(env.repo.completed.single.$2.endedAt, lastPoint);
      expect(env.view.autoEnded, isTrue);
      expect(env.notifier.shown, hasLength(1));
    });
  });

  test('알림이 실패해도 러닝은 저장된다', () {
    _run((env) {
      env.notifier.fails = true;
      runFiveSamples(env);
      env.async.elapse(const Duration(minutes: 20));
      expect(env.repo.completed, hasLength(1));
      expect(env.view.autoEnded, isTrue);
    });
  });

  test('직접 끝낸 러닝은 autoEnded 가 아니고 알리지 않는다', () {
    _run((env) {
      runFiveSamples(env);
      env.controller.end();
      env.async.flushMicrotasks();
      expect(env.view.autoEnded, isFalse);
      expect(env.notifier.shown, isEmpty);
    });
  });

  group('빠른 이동', () {
    /// 시작 뒤 1~5초 3m/s, 6초부터 [fastUntil]초까지 10m/s 점. 5초 점이 15m.
    void feedFast(_Env env, int fastUntil) {
      runFiveSamples(env);
      for (var i = 6; i <= fastUntil; i++) {
        env.sampleAt(Duration(seconds: i), 15.0 + (i - 5) * 10);
      }
    }

    test('초속 10m 점이 30초 이어지면 끝내고 끝 시각은 빨라지기 전 마지막 점', () {
      _run((env) {
        // 6초 점부터 시작해 35초 점이 29초째.
        feedFast(env, 35);
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);

        // 36초 점이 오면 점 시각 차이가 30초.
        env.sampleAt(const Duration(seconds: 36), 15.0 + 31 * 10);
        env.async.elapse(const Duration(seconds: 1));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        // 빠른 구간은 거리에 들어가지 않는다.
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.points, hasLength(5));
        expect(env.view.autoEnded, isTrue);
        expect(env.notifier.shown, [
          (_fastTitle, '0.01km 기록을 저장했어요. 요약에서 확인하세요.'),
        ]);
      });
    });

    test('튀는 값 하나 뒤 점이 60초 없어도 끝내지 않는다', () {
      _run((env) {
        feedFast(env, 6);
        env.async.elapse(const Duration(seconds: 60));
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('튀는 값 두 개 뒤 정확도 거름에 걸린 점만 60초 와도 끝내지 않는다', () {
      _run((env) {
        feedFast(env, 7);
        for (var i = 8; i <= 67; i++) {
          env.async.elapse(Duration(seconds: i) - env.async.elapsed);
          env.location.controller.add(
            LocationSample(
              time: _t0.add(Duration(seconds: i)),
              latitude: _northOf(500.0 + i * 10),
              longitude: _lng0,
              accuracy: 50,
            ),
          );
          env.async.flushMicrotasks();
        }
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('빠른 점 2개 뒤 초속 3m 점이 오면 다시 0부터 센다', () {
      _run((env) {
        feedFast(env, 7);
        // 7초 점은 35m. 3m/s 점으로 연속이 끊긴다.
        env.sampleAt(const Duration(seconds: 8), 38);
        for (var i = 9; i <= 70; i++) {
          env.sampleAt(Duration(seconds: i), 38.0 + (i - 8) * 3);
        }
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('일시정지 중에는 세지 않고 재개하면 0부터 센다', () {
      _run((env) {
        feedFast(env, 7);
        env.controller.pause();
        env.async.elapse(const Duration(minutes: 2));
        expect(env.view.snapshot.state, RunState.paused);
        expect(env.repo.completed, isEmpty);

        env.controller.resume();
        env.async.elapse(const Duration(seconds: 29));
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('provider 로 줄인 기준을 따른다', () {
      _run(config: const RunGuardConfig(fast: Duration(seconds: 3)), (env) {
        feedFast(env, 8);
        env.async.elapse(const Duration(seconds: 1));
        expect(env.repo.completed, isEmpty);
        env.sampleAt(const Duration(seconds: 9), 15.0 + 40);
        env.async.elapse(const Duration(seconds: 1));
        expect(env.repo.completed.single.$2.endedAt, lastPoint);
      });
    });
  });

  group('복원', () {
    // 마지막 점은 시작 4초 뒤.
    const lastPointOffset = Duration(seconds: 4);
    ActiveRun active(DateTime startedAt) => ActiveRun(
      id: _runId,
      startedAt: startedAt,
      segments: [
        [
          _sample(startedAt, 0),
          _sample(startedAt.add(const Duration(seconds: 2)), 4),
          _sample(startedAt.add(lastPointOffset), 8),
        ],
      ],
      movingTime: const Duration(seconds: 4),
    );

    test('마지막 점 뒤 30분이어도 6시간 전이면 그대로 복원한다 (20분 규칙 미적용)', () {
      final startedAt = _t0.subtract(
        lastPointOffset + const Duration(minutes: 30),
      );
      _run(activeRun: active(startedAt), (env) {
        bool? restored;
        env.controller.restoreIfAny().then((r) => restored = r);
        env.async.flushMicrotasks();

        expect(restored, isTrue);
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.paused);
        expect(env.view.autoEnded, isFalse);
        expect(env.notifier.shown, isEmpty);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('시작 5시간 59분 59초면 그대로 복원한다', () {
      final startedAt = _t0.subtract(
        const Duration(hours: 5, minutes: 59, seconds: 59),
      );
      _run(activeRun: active(startedAt), (env) {
        bool? restored;
        env.controller.restoreIfAny().then((r) => restored = r);
        env.async.flushMicrotasks();

        expect(restored, isTrue);
        expect(env.repo.completed, isEmpty);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('시작 6시간이 지났으면 묻지 않고 마지막 점으로 끝낸다', () {
      final startedAt = _t0.subtract(const Duration(hours: 6));
      _run(activeRun: active(startedAt), (env) {
        bool? restored;
        env.controller.restoreIfAny().then((r) => restored = r);
        env.async.flushMicrotasks();

        expect(restored, isFalse);
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, startedAt.add(lastPointOffset));
        expect(summary.movingTime, const Duration(seconds: 4));
        expect(summary.distanceM, closeTo(_dist(0, 4) + _dist(4, 8), 1e-9));
        expect(env.view.autoEnded, isTrue);
        expect(env.view.lastSummary, same(summary));
        expect(env.view.runId, isNull);
        expect(env.notifier.shown.single.$1, _title);
      });
    });
  });
}
