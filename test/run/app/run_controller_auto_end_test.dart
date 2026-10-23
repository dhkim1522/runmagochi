import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
import 'package:runmagochi/run/app/app_lifecycle.dart';
import 'package:runmagochi/run/app/providers.dart';
import '../ui/fakes.dart' show FakeRunProgressNotifier, FakeSpeaker;
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
const _quitTitle = '한참 못 달려서 러닝을 마쳤어요';
const _quitBody = '기록은 안전하게 저장했어요';
final _t0 = DateTime(2026, 10, 18, 7);

/// 1km 미만은 저장하지 않으므로(결정 0027) 저장을 확인하는 러닝은 먼저 330초를
/// 3m/s 로 달려 990m 를 쌓고 시작한다.
const _warm = Duration(seconds: 330);
const _warmM = 990.0;

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
  final discarded = <String>[];

  @override
  Future<void> discardActiveRun(String runId) async {
    discarded.add(runId);
  }

  @override
  Future<List<RunDetail>> listRunDetails() => throw UnimplementedError();

  ActiveRun? activeRun;
  Object? completeError;
  final completed = <(String, RunSummary)>[];

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
  Future<bool> voiceGuide() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Location implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();
  bool get isListened => controller.hasListener;
  @override
  Stream<LocationSample> watch() => controller.stream;

  @override
  Future<bool> isServiceEnabled() async => true;
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
  var goalCancelled = 0;
  @override
  Future<void> cancelGoalReached() async => goalCancelled++;

  final shown = <(String, String)>[];
  bool fails = false;

  @override
  Future<void> showNow({required String title, required String body}) async {
    if (fails) throw StateError('알림 실패');
    shown.add((title, body));
  }

  @override
  Future<void> showGoalReached({required String title, required String body}) =>
      showNow(title: title, body: body);
}

class _Env {
  _Env(this.async);
  final FakeAsync async;
  late final ProviderContainer container;
  final repo = _Repo();
  final location = _Location();
  final lifecycle = _Lifecycle();
  final notifier = _Notifier();
  final progress = FakeRunProgressNotifier();

  RunController get controller =>
      container.read(runControllerProvider.notifier);
  RunViewState get view => container.read(runControllerProvider);

  /// [at] 시각(시작 기준)에 [meters] 지점의 점을 보낸다.
  void sampleAt(Duration at, double meters) {
    async.elapse(at - async.elapsed);
    location.controller.add(_sample(_t0.add(at), meters));
    async.flushMicrotasks();
  }

  /// 1km 를 넘기는 앞 달리기(_warm 초, 3m/s) 뒤의 시각·지점으로 점을 보낸다.
  /// [at]·[meters] 는 앞 달리기가 없던 때의 값이다.
  void tailAt(Duration at, double meters) =>
      sampleAt(at + _warm, meters + _warmM);
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
        speakerProvider.overrideWithValue(FakeSpeaker()),
        runRepositoryProvider.overrideWithValue(env.repo),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        runProgressNotifierProvider.overrideWithValue(env.progress),
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
  /// 시작 뒤 1~335초에 3m 씩 점 335개(1,005m). 마지막 점은 335초.
  void runFiveSamples(_Env env) {
    env.controller.start(goal: DistanceGoal(3000));
    env.async.flushMicrotasks();
    for (var i = 1; i <= 335; i++) {
      env.sampleAt(Duration(seconds: i), i * 3.0);
    }
  }

  const lastPointOffset = Duration(seconds: 335);
  final lastPoint = _t0.add(lastPointOffset);
  final fiveDistance = [
    for (var i = 1; i < 335; i++) _dist(i * 3.0, (i + 1) * 3.0),
  ].reduce((a, b) => a + b);

  /// 시작 기준 [at] 까지 흐르게 한다.
  void elapseTo(_Env env, Duration at) =>
      env.async.elapse(at - env.async.elapsed);

  /// 마지막 점 자리에 선 채 [at] 까지 흐르게 한다. 자동 일시정지(마지막 점 뒤
  /// 10초) 뒤부터 15초마다 같은 자리 점이 와서 신호 끊김(30초)이 되지 않는다.
  void stillTo(_Env env, Duration at) {
    for (
      var t = lastPointOffset + const Duration(seconds: 15);
      t <= at;
      t += const Duration(seconds: 15)
    ) {
      if (t > env.async.elapsed) env.sampleAt(t, 1005);
    }
    elapseTo(env, at);
  }

  // 5초 점 뒤 10초(15초 틱)에 자동 일시정지하고, 멈춘 시각은 5초 점이다.
  group('자동 일시정지 5분', () {
    test('4분 59초엔 예고 없음, 5분에 예고 1회, 5분 29초 계속, 5분 30초에 멈춘 시각으로 끝낸다', () {
      _run((env) {
        runFiveSamples(env);
        stillTo(env, lastPointOffset + const Duration(minutes: 4, seconds: 59));
        expect(env.view.snapshot.state, RunState.autoPaused);
        expect(env.progress.warnings, isEmpty);

        stillTo(env, lastPointOffset + const Duration(minutes: 5));
        final deadline = lastPoint.add(const Duration(minutes: 5, seconds: 30));
        expect(env.progress.warnings, [deadline]);
        expect(env.progress.warningPaused, [false]);

        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 29));
        expect(env.progress.warnings, hasLength(1));
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.autoPaused);

        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 30));

        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.points, hasLength(335));
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.view.snapshot.state, RunState.idle);
        expect(env.progress.warnings, hasLength(1));
        expect(env.progress.warningCancels, 1);
        expect(env.notifier.shown, [(_title, '1.00km 기록을 저장했어요. 요약에서 확인하세요.')]);
      });
    });

    test('예고 중 움직이면 예고를 지우고 이어 간다', () {
      _run((env) {
        runFiveSamples(env);
        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 5));
        expect(env.progress.warnings, hasLength(1));

        // 10m 넘게 움직인 점 3개로 자동 재개한다.
        final from = env.async.elapsed;
        for (var i = 1; i <= 3; i++) {
          env.sampleAt(from + Duration(seconds: i), 1005.0 + i * 6);
        }
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.progress.warningCancels, 1);

        for (var i = 4; i <= 40; i++) {
          env.sampleAt(from + Duration(seconds: i), 1005.0 + i * 6);
        }
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.progress.warnings, hasLength(1));
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('예고 중 재개를 누르면 예고를 지우고 이어 간다', () {
      _run((env) {
        runFiveSamples(env);
        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 5));
        expect(env.progress.warnings, hasLength(1));

        env.controller.resume();
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.progress.warningCancels, 1);

        env.async.elapse(const Duration(minutes: 1));
        expect(env.repo.completed, isEmpty);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('멈춘 뒤 제자리에서 받은 점은 끝낼 때 잘라낸다', () {
      _run((env) {
        runFiveSamples(env);
        // 6~14초 점은 5m 안에서 흔들려 받아들이지만 움직임은 아니다.
        for (var i = 6; i <= 14; i++) {
          env.tailAt(Duration(seconds: i), i.isEven ? 16.0 : 15.0);
        }
        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 30));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.points, hasLength(335));
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        // 움직인 시간은 멈춘 시각에서 이미 멈춰 있다.
        expect(summary.movingTime, lastPointOffset);
      });
    });

    test('3분 뒤 사용자 일시정지로 바꾸면 거기서 1시간을 세고 처음 멈춘 시각으로 끝낸다', () {
      _run((env) {
        runFiveSamples(env);
        final switchAt = lastPointOffset + const Duration(minutes: 3);
        stillTo(env, switchAt);
        env.controller.pause();
        expect(env.view.snapshot.state, RunState.paused);

        stillTo(env, switchAt + const Duration(minutes: 59, seconds: 59));
        expect(env.repo.completed, isEmpty);
        expect(env.progress.warnings, isEmpty);

        stillTo(env, switchAt + const Duration(hours: 1));
        expect(env.progress.warnings, [
          _t0.add(switchAt + const Duration(hours: 1, seconds: 30)),
        ]);
        expect(env.progress.warningPaused, [true]);
        stillTo(env, switchAt + const Duration(hours: 1, seconds: 30));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.notifier.shown.single.$1, _title);
      });
    });

    test('예고 중 사용자 일시정지로 바꾸면 예고를 지우고 1시간을 다시 센다', () {
      _run((env) {
        runFiveSamples(env);
        stillTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 5));
        expect(env.progress.warnings, hasLength(1));

        env.controller.pause();
        expect(env.progress.warningCancels, 1);
        env.async.elapse(const Duration(minutes: 30));
        expect(env.repo.completed, isEmpty);
        expect(env.progress.warnings, hasLength(1));
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });
  });

  group('사용자 일시정지 1시간', () {
    test('1시간에 예고하고 1시간 30초에 일시정지한 시각으로 끝낸다', () {
      _run((env) {
        runFiveSamples(env);
        env.controller.pause();
        elapseTo(
          env,
          lastPointOffset + const Duration(minutes: 59, seconds: 59),
        );
        expect(env.view.snapshot.state, RunState.paused);
        expect(env.progress.warnings, isEmpty);

        elapseTo(env, lastPointOffset + const Duration(hours: 1));
        expect(env.progress.warnings, [
          lastPoint.add(const Duration(hours: 1, seconds: 30)),
        ]);
        elapseTo(env, lastPointOffset + const Duration(hours: 1, seconds: 29));
        expect(env.repo.completed, isEmpty);

        elapseTo(env, lastPointOffset + const Duration(hours: 1, seconds: 30));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.progress.warningCancels, 1);
        expect(env.notifier.shown.single.$1, _title);
      });
    });

    test('30분이 지나도 끝내지 않는다', () {
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
  });

  test('일시정지 중에도 시작부터 상한이면 끝내고 끝 시각은 마지막 점', () {
    _run(config: const RunGuardConfig(max: Duration(minutes: 30)), (env) {
      runFiveSamples(env);
      env.async.elapse(const Duration(seconds: 5));
      env.controller.pause();
      elapseTo(env, const Duration(minutes: 29, seconds: 59));
      expect(env.repo.completed, isEmpty);

      env.async.elapse(const Duration(seconds: 1));
      final summary = env.repo.completed.single.$2;
      expect(summary.endedAt, lastPoint);
      expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
      // 일시정지까지 움직인 시간은 그대로 둔다.
      expect(summary.movingTime, lastPointOffset + const Duration(seconds: 5));
      expect(env.view.autoEnded, isTrue);
      expect(env.notifier.shown.single.$1, _title);
    });
  });

  test('계속 점이 들어와도 시작 6시간이면 끝낸다', () {
    _run(config: const RunGuardConfig(max: Duration(seconds: 340)), (env) {
      env.controller.start(goal: DistanceGoal(3000));
      env.async.flushMicrotasks();
      for (var i = 1; i <= 339; i++) {
        env.sampleAt(Duration(seconds: i), i * 3.0);
      }
      env.async.elapse(const Duration(seconds: 1));
      final summary = env.repo.completed.single.$2;
      expect(summary.endedAt, _t0.add(const Duration(seconds: 339)));
      expect(summary.points, hasLength(339));
    });
  });

  test('provider 로 줄인 기준을 따른다', () {
    const config = RunGuardConfig(
      still: Duration(seconds: 20),
      warning: Duration(seconds: 5),
    );
    _run(config: config, (env) {
      runFiveSamples(env);
      elapseTo(env, lastPointOffset + const Duration(seconds: 20));
      expect(env.progress.warnings, [
        lastPoint.add(const Duration(seconds: 25)),
      ]);
      elapseTo(env, lastPointOffset + const Duration(seconds: 24));
      expect(env.repo.completed, isEmpty);
      elapseTo(env, lastPointOffset + const Duration(seconds: 25));
      expect(env.repo.completed.single.$2.endedAt, lastPoint);
    });
  });

  test('화면으로 돌아올 때도 판정한다', () {
    const config = RunGuardConfig(
      still: Duration(seconds: 11),
      warning: Duration(milliseconds: 500),
    );
    _run(config: config, (env) {
      runFiveSamples(env);
      // 15초 틱에 자동 일시정지, 16초 틱에 예고. 17초 틱 전에 화면 복귀로 판정한다.
      env.async.elapse(
        lastPointOffset +
            const Duration(seconds: 11, milliseconds: 600) -
            env.async.elapsed,
      );
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
      env.progress.fails = true;
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

  group('탈것 의심 (결정 0033)', () {
    /// 앞 달리기 뒤 지금 위치(_warmM 기준 m). runFiveSamples 의 마지막 점은
    /// 뒤 5초, 15m 다.
    late double pos;

    /// 뒤 [from]~[until]초(포함)에 매초 초속 [speed] 로 간 점을 보낸다.
    void feed(_Env env, int from, int until, double speed) {
      for (var i = from; i <= until; i++) {
        pos += speed;
        env.tailAt(Duration(seconds: i), pos);
      }
    }

    void startRun(_Env env) {
      runFiveSamples(env);
      pos = 15;
    }

    test('시속 18km 로 이어 달리면 끝내지 않고 모두 기록한다', () {
      _run((env) {
        startRun(env);
        feed(env, 6, 300, 5);
        expect(env.repo.completed, isEmpty);
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.view.snapshot.distanceM, closeTo(fiveDistance + 295 * 5, 1));
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('의심 합계 2분이면 끝내고 끝 시각은 의심 전 마지막 정상 점', () {
      _run((env) {
        startRun(env);
        // 초속 7m: 뒤 29초 점에서 최근 30초 평균이 시속 22km 를 넘는다.
        feed(env, 6, 28, 7);
        expect(env.view.snapshot.state, RunState.recording);
        feed(env, 29, 29, 7);
        expect(env.view.snapshot.state, RunState.vehicle);
        // 의심은 마지막 정상 점(뒤 5초)부터 센다. 뒤 124초까지 1분 59초.
        feed(env, 30, 124, 7);
        expect(env.repo.completed, isEmpty);
        feed(env, 125, 126, 7);
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.points, hasLength(335));
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.notifier.shown, [(_quitTitle, _quitBody)]);
      });
    });

    test('의심 구간은 합해서 세고, 사이에 달린 기록도 첫 의심 전에서 끊는다', () {
      _run((env) {
        startRun(env);
        feed(env, 6, 65, 7);
        expect(env.view.snapshot.state, RunState.vehicle);
        // 내려서 달리면 뒤 72초 점에서 풀린다(의심 67초).
        feed(env, 66, 125, 3);
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.view.snapshot.distanceM, greaterThan(fiveDistance + 100));
        // 다시 타면 뒤 125초 점부터 의심하고 합이 2분이 되는 뒤 178초에 끝낸다.
        feed(env, 126, 176, 7);
        expect(env.repo.completed, isEmpty);
        feed(env, 177, 180, 7);
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.movingTime, lastPointOffset);
        expect(env.notifier.shown.single.$1, _quitTitle);
      });
    });

    test('1km 미만이면 저장하지 않는다', () {
      _run((env) {
        env.controller.start(goal: DistanceGoal(3000));
        env.async.flushMicrotasks();
        pos = 0;
        for (var i = 1; i <= 100; i++) {
          pos += 3;
          env.sampleAt(Duration(seconds: i), pos);
        }
        for (var i = 101; i <= 260; i++) {
          pos += 7;
          env.sampleAt(Duration(seconds: i), pos);
        }
        expect(env.repo.completed, isEmpty);
        expect(env.repo.discarded, [_runId]);
        expect(env.notifier.shown, [('러닝을 마쳤어요', '1km 미만은 기록하지 않아요')]);
      });
    });

    test('1km 를 넘겼어도 첫 의심 전으로 잘라 1km 미만이 되면 저장하지 않는다', () {
      _run((env) {
        env.controller.start(goal: DistanceGoal(3000));
        env.async.flushMicrotasks();
        pos = 0;
        void go(int from, int until, double speed) {
          for (var i = from; i <= until; i++) {
            pos += speed;
            env.sampleAt(Duration(seconds: i), pos);
          }
        }

        go(1, 270, 3); // 810m, 마지막 정상 점 270초
        go(271, 320, 7); // 294초에 의심
        go(321, 470, 3); // 풀린 뒤 달리기
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.view.snapshot.distanceM, greaterThan(1000));
        go(471, 560, 7); // 다시 의심, 합계 2분에 끝낸다
        expect(env.repo.completed, isEmpty);
        expect(env.repo.discarded, [_runId]);
        expect(env.view.discardedShortRun, isTrue);
        expect(env.notifier.shown, [('러닝을 마쳤어요', '1km 미만은 기록하지 않아요')]);
      });
    });

    test('provider 로 줄인 기준을 따른다', () {
      _run(config: const RunGuardConfig(vehicle: Duration(seconds: 30)), (env) {
        startRun(env);
        feed(env, 6, 34, 7);
        expect(env.repo.completed, isEmpty);
        feed(env, 35, 37, 7);
        expect(env.repo.completed.single.$2.endedAt, lastPoint);
      });
    });

    test('탈것 의심 중 점이 끊기면 신호 끊김으로 5분 30초에 끝낸다', () {
      _run((env) {
        startRun(env);
        feed(env, 6, 40, 7);
        expect(env.view.snapshot.state, RunState.vehicle);
        final lastAt = lastPointOffset + const Duration(seconds: 35);
        elapseTo(env, lastAt + const Duration(seconds: 30));
        expect(env.view.snapshot.state, RunState.signalLost);
        elapseTo(env, lastAt + const Duration(minutes: 5, seconds: 29));
        expect(env.repo.completed, isEmpty);
        elapseTo(env, lastAt + const Duration(minutes: 5, seconds: 30));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(env.notifier.shown, [(_quitTitle, _quitBody)]);
      });
    });
  });

  group('신호 끊김 (결정 0033)', () {
    test('점이 30초 없으면 신호 끊김, 5분에 예고, 5분 30초에 마지막 점으로 끝낸다', () {
      _run((env) {
        runFiveSamples(env);
        elapseTo(env, lastPointOffset + const Duration(seconds: 29));
        expect(env.view.snapshot.state, RunState.autoPaused);
        elapseTo(env, lastPointOffset + const Duration(seconds: 30));
        expect(env.view.snapshot.state, RunState.signalLost);

        elapseTo(
          env,
          lastPointOffset + const Duration(minutes: 4, seconds: 59),
        );
        expect(env.progress.warnings, isEmpty);
        elapseTo(env, lastPointOffset + const Duration(minutes: 5));
        expect(env.progress.warnings, [
          lastPoint.add(const Duration(minutes: 5, seconds: 30)),
        ]);
        expect(env.progress.warningSignalLost, [true]);
        elapseTo(
          env,
          lastPointOffset + const Duration(minutes: 5, seconds: 29),
        );
        expect(env.repo.completed, isEmpty);

        elapseTo(
          env,
          lastPointOffset + const Duration(minutes: 5, seconds: 30),
        );
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, lastPoint);
        expect(summary.distanceM, closeTo(fiveDistance, 1e-9));
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.progress.warningCancels, 1);
        expect(env.notifier.shown, [(_quitTitle, _quitBody)]);
      });
    });

    test('점이 다시 오면 이어 기록하고 끊긴 사이 거리는 더하지 않는다', () {
      _run((env) {
        runFiveSamples(env);
        elapseTo(env, lastPointOffset + const Duration(minutes: 2));
        expect(env.view.snapshot.state, RunState.signalLost);
        // 터널을 지나 300m 앞에서 점이 다시 온다.
        for (var i = 1; i <= 20; i++) {
          env.tailAt(
            const Duration(minutes: 2) + Duration(seconds: 5 + i),
            15.0 + 300 + i * 3,
          );
        }
        expect(env.view.snapshot.state, RunState.recording);
        expect(
          env.view.snapshot.distanceM,
          closeTo(fiveDistance + _dist(318, 375), 1e-6),
        );
        env.controller.end();
        env.async.flushMicrotasks();
        final summary = env.repo.completed.single.$2;
        expect(summary.segments, hasLength(2));
      });
    });

    test('신호 끊김 예고 중 점이 오면 예고를 지운다', () {
      _run((env) {
        runFiveSamples(env);
        elapseTo(env, lastPointOffset + const Duration(minutes: 5, seconds: 5));
        expect(env.progress.warnings, hasLength(1));
        env.tailAt(const Duration(minutes: 5, seconds: 10), 20);
        expect(env.view.snapshot.state, RunState.recording);
        expect(env.progress.warningCancels, 1);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });
  });

  group('복원', () {
    // 마지막 점은 시작 400초 뒤(1,200m).
    const lastPointOffset = Duration(seconds: 400);
    ActiveRun active(DateTime startedAt) => ActiveRun(
      id: _runId,
      startedAt: startedAt,
      segments: [
        [
          for (var i = 0; i <= 400; i++)
            _sample(startedAt.add(Duration(seconds: i)), i * 3.0),
        ],
      ],
      movingTime: lastPointOffset,
    );

    test('마지막 점 뒤 30분이어도 6시간 전이면 그대로 복원한다', () {
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

    test('복원하면 앞 프로세스가 남긴 종료 예고 알림을 지운다', () {
      final startedAt = _t0.subtract(const Duration(minutes: 30));
      _run(activeRun: active(startedAt), (env) {
        env.controller.restoreIfAny();
        env.async.flushMicrotasks();
        expect(env.progress.warningCancels, 1);
        env.controller.end();
        env.async.flushMicrotasks();
      });
    });

    test('복원한 러닝은 사용자 일시정지로 열려 복원 시각부터 1시간 규칙을 따른다', () {
      final startedAt = _t0.subtract(const Duration(minutes: 30));
      _run(activeRun: active(startedAt), (env) {
        env.controller.restoreIfAny();
        env.async.flushMicrotasks();
        expect(env.view.snapshot.state, RunState.paused);

        env.async.elapse(const Duration(minutes: 59, seconds: 59));
        expect(env.progress.warnings, isEmpty);
        env.async.elapse(const Duration(seconds: 1));
        expect(env.progress.warnings, [
          _t0.add(const Duration(hours: 1, seconds: 30)),
        ]);
        env.async.elapse(const Duration(seconds: 30));
        final summary = env.repo.completed.single.$2;
        expect(summary.endedAt, startedAt.add(lastPointOffset));
        expect(summary.movingTime, lastPointOffset);
        expect(env.view.autoEnded, isTrue);
        expect(env.notifier.shown.single.$1, _title);
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
        expect(summary.movingTime, lastPointOffset);
        expect(
          summary.distanceM,
          closeTo(
            [
              for (var i = 0; i < 400; i++) _dist(i * 3.0, (i + 1) * 3.0),
            ].reduce((a, b) => a + b),
            1e-9,
          ),
        );
        expect(env.view.autoEnded, isTrue);
        expect(env.view.lastSummary, same(summary));
        expect(env.view.runId, isNull);
        expect(env.notifier.shown.single.$1, _title);
      });
    });
  });
}
