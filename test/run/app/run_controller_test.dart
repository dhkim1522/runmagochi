import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/profile_repository.dart';
import 'package:runmagochi/run/app/app_lifecycle.dart';
import 'package:runmagochi/run/app/providers.dart';
import '../ui/fakes.dart' show FakeRunProgressNotifier, FakeSpeaker;
import 'package:runmagochi/run/app/run_controller.dart';
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/geo.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

const _lat0 = 37.5;
const _lng0 = 127.0;
const _runId = 'run-1';
const _saveError = '기록 저장에 실패했어요. 자동으로 다시 시도해요';
const _endError = '러닝 저장에 실패했어요. 다시 종료해 주세요';
const _locationError = '위치 신호를 받지 못하고 있어요';
final _t0 = DateTime(2026, 10, 17, 7);

/// 자오선을 따라 [meters] 만큼 북쪽으로 간 위도.
double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

LocationSample _sample(DateTime time, double meters) => LocationSample(
  time: time,
  latitude: _northOf(meters),
  longitude: _lng0,
  accuracy: 5,
);

class _AppendCall {
  _AppendCall(this.runId, this.segmentIndex, this.points, this.movingTime);

  final String runId;
  final int segmentIndex;
  final List<LocationSample> points;
  final Duration movingTime;
}

class _FakeRunRepository implements RunRepository {
  @override
  Future<List<RunDetail>> listRunDetails() => throw UnimplementedError();

  ActiveRun? activeRun;

  /// 주면 appendPoints 가 이 완료를 기다린다.
  Completer<void>? appendGate;

  /// 주면 다음 appendPoints 한 번이 이 오류를 던진다.
  Object? appendError;

  /// 주면 다음 completeRun 한 번이 이 오류를 던진다.
  Object? completeError;
  final appendCalls = <_AppendCall>[];
  final completed = <(String, RunSummary)>[];

  /// 저장소 호출 순서.
  final log = <String>[];

  @override
  Future<RunGoal?> lastGoal() async => null;

  @override
  Future<String> createActiveRun(
    DateTime startedAt, {
    required RunGoal goal,
  }) async {
    log.add('createActiveRun');
    return _runId;
  }

  @override
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  }) async {
    log.add('appendPoints');
    await appendGate?.future;
    final error = appendError;
    if (error != null) {
      appendError = null;
      throw error;
    }
    appendCalls.add(
      _AppendCall(runId, segmentIndex, List.of(points), movingTime),
    );
  }

  @override
  Future<ActiveRun?> findActiveRun() async {
    log.add('findActiveRun');
    return activeRun;
  }

  @override
  Future<void> completeRun(String runId, RunSummary summary) async {
    log.add('completeRun');
    final error = completeError;
    if (error != null) {
      completeError = null;
      throw error;
    }
    completed.add((runId, summary));
  }

  final discarded = <String>[];

  @override
  Future<void> discardActiveRun(String runId) async {
    log.add('discardActiveRun');
    discarded.add(runId);
  }

  @override
  Future<List<RunListItem>> listRuns() => throw UnimplementedError();

  @override
  Future<RunDetail?> getRun(String id) => throw UnimplementedError();

  @override
  Future<(double, int)> weeklyTotal(DateTime now) => throw UnimplementedError();

  @override
  Future<void> deleteRun(String id) => throw UnimplementedError();

  @override
  Future<void> replaceCompletedRun(String runId, RunSummary summary) =>
      throw UnimplementedError();

  @override
  Future<Set<String>> existingRunIds(Set<String> ids) =>
      throw UnimplementedError();

  @override
  Future<Map<String, DateTime>> completedRunRevisions() =>
      throw UnimplementedError();
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.weight);
  double? weight;
  @override
  Future<double?> weightKg() async => weight;
  @override
  Future<void> setWeightKg(double? kg) async => weight = kg;
  bool voice = true;
  @override
  Future<bool> voiceGuide() async => voice;
  @override
  Future<void> setVoiceGuide(bool on) async => voice = on;
  @override
  Future<ThemeMode> themeMode() async => ThemeMode.system;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
  @override
  Future<bool> isOnboarded() async => false;
  @override
  Future<void> markOnboarded() async {}
}

class _FakeLocationSource implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();
  int listenCount = 0;

  bool get isListened => controller.hasListener;

  @override
  Stream<LocationSample> watch() {
    listenCount++;
    return controller.stream;
  }
}

class _FakeAppLifecycle implements AppLifecycle {
  @override
  AppLifecycleState current = AppLifecycleState.resumed;
  final _changes = StreamController<AppLifecycleState>.broadcast(sync: true);

  @override
  Stream<AppLifecycleState> get changes => _changes.stream;

  void set(AppLifecycleState state) {
    current = state;
    _changes.add(state);
  }
}

/// 현재 _run 이 쓰는 앱 생명주기. 기본은 화면에 있는 상태.
late _FakeAppLifecycle _lifecycle;

class _NoopInstant implements InstantNotifier {
  @override
  Future<void> showNow({required String title, required String body}) async {}
  @override
  Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelGoalReached() async {}
}

/// fake_async 시간과 같이 가는 시계로 컨테이너를 만들어 [body] 를 돌린다.
void _run(
  void Function(
    FakeAsync async,
    RunController controller,
    ProviderContainer container,
    _FakeRunRepository repository,
    _FakeLocationSource location,
  )
  body, {
  ActiveRun? activeRun,
  double? weightKg,
}) {
  fakeAsync((async) {
    final repository = _FakeRunRepository()..activeRun = activeRun;
    final location = _FakeLocationSource();
    final lifecycle = _lifecycle = _FakeAppLifecycle();
    final container = ProviderContainer(
      overrides: [
        runRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(
          _FakeProfileRepository(weightKg),
        ),
        runProgressNotifierProvider.overrideWithValue(
          FakeRunProgressNotifier(),
        ),
        locationSourceProvider.overrideWithValue(location),
        appLifecycleProvider.overrideWithValue(lifecycle),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        speakerProvider.overrideWithValue(FakeSpeaker()),
        instantNotifierProvider.overrideWithValue(_NoopInstant()),
      ],
    );
    body(
      async,
      container.read(runControllerProvider.notifier),
      container,
      repository,
      location,
    );
    container.dispose();
    async.flushMicrotasks();
    expect(async.pendingTimers, isEmpty);
    expect(location.isListened, isFalse);
  });
}

void main() {
  _weightTests();

  /// 3m/s 로 335초 달려 1km 를 넘기고(1km 미만은 저장하지 않는다), 주기 저장이 한 번
  /// 돈 뒤 저장소 호출 기록을 비운다. 끝난 시각은 시작 후 340초다.
  void runKm(
    FakeAsync async,
    _FakeLocationSource location,
    _FakeRunRepository repository,
  ) {
    for (var i = 1; i <= 335; i++) {
      async.elapse(const Duration(seconds: 1));
      location.controller.add(_sample(_t0.add(async.elapsed), i * 3.0));
      async.flushMicrotasks();
    }
    async.elapse(const Duration(seconds: 5));
    repository.log.clear();
    repository.appendCalls.clear();
  }

  /// 1초를 보내고 그 시각에 [meters] 지점의 점을 보낸다.
  void stepTo(FakeAsync async, _FakeLocationSource location, double meters) {
    async.elapse(const Duration(seconds: 1));
    location.controller.add(_sample(_t0.add(async.elapsed), meters));
    async.flushMicrotasks();
  }

  test('start → 점 5개 → 10초 경과 → appendPoints 1회, 점 5개', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      for (var i = 1; i <= 5; i++) {
        stepTo(async, location, i * 3.0);
      }
      async.elapse(const Duration(seconds: 4));
      expect(repository.appendCalls, isEmpty);

      async.elapse(const Duration(seconds: 1));
      final call = repository.appendCalls.single;
      expect(call.runId, _runId);
      expect(call.segmentIndex, 0);
      expect(call.points, hasLength(5));
      expect(call.movingTime, const Duration(seconds: 10));
    });
  });

  test('pause 시 버퍼를 즉시 저장하고 위치 구독은 유지한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      for (var i = 1; i <= 3; i++) {
        stepTo(async, location, i * 3.0);
      }

      controller.pause();
      async.flushMicrotasks();

      final call = repository.appendCalls.single;
      expect(call.points, hasLength(3));
      expect(call.movingTime, const Duration(seconds: 3));
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.paused,
      );
      expect(location.isListened, isTrue);
    });
  });

  test('end 후 completeRun 호출, 위치 구독 해제, 버퍼는 completeRun 전에 저장', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      for (var i = 1; i <= 335; i++) {
        stepTo(async, location, i * 3.0);
      }
      final savedBefore = repository.appendCalls.fold<int>(
        0,
        (n, c) => n + c.points.length,
      );

      RunSummary? summary;
      controller.end().then((s) => summary = s);
      async.flushMicrotasks();

      expect(summary, isNotNull);
      expect(repository.completed.single.$1, _runId);
      expect(repository.completed.single.$2, same(summary));
      expect(summary!.points, hasLength(335));
      // 끝낼 때 남은 점까지 모두 completeRun 전에 저장한다.
      final saved = repository.appendCalls.fold<int>(
        0,
        (n, c) => n + c.points.length,
      );
      expect(saved, 335);
      expect(saved, greaterThan(savedBefore));
      expect(repository.log.last, 'completeRun');
      expect(repository.log.where((e) => e == 'completeRun'), hasLength(1));
      expect(repository.log[repository.log.length - 2], 'appendPoints');
      expect(location.isListened, isFalse);
      expect(async.pendingTimers, isEmpty);

      final state = container.read(runControllerProvider);
      expect(state.runId, isNull);
      expect(state.lastSummary, same(summary));
      expect(state.snapshot.state, RunState.idle);
    });
  });

  test('end 후 30초가 지나도 appendPoints 를 더 부르지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      runKm(async, location, repository);
      controller.end();
      async.flushMicrotasks();
      final calls = repository.appendCalls.length;

      async.elapse(const Duration(seconds: 30));

      expect(repository.appendCalls, hasLength(calls));
      expect(repository.log.last, 'completeRun');
    });
  });

  test('end 는 진행 중인 주기 저장이 끝난 뒤 completeRun 한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      runKm(async, location, repository);
      stepTo(async, location, 1008); // 진행 중인 저장이 들고 갈 점 1개
      final gate = repository.appendGate = Completer<void>();
      async.elapse(const Duration(seconds: 9));
      expect(repository.log, ['appendPoints']);

      controller.end();
      async.flushMicrotasks();
      expect(repository.log, ['appendPoints']);
      expect(repository.completed, isEmpty);

      gate.complete();
      async.flushMicrotasks();
      expect(repository.log, ['appendPoints', 'appendPoints', 'completeRun']);
      expect(repository.appendCalls[0].points, hasLength(1));
      expect(repository.appendCalls[1].points, isEmpty);
    });
  });

  test('러닝이 이미 있으면 start 는 StateError', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      Object? error;
      controller
          .start(goal: DistanceGoal(3000))
          .catchError((Object e) => error = e);
      async.flushMicrotasks();

      expect(error, isA<StateError>());
      expect(repository.log, ['createActiveRun']);
      expect(location.listenCount, 1);
    });
  });

  test('start 는 이전 러닝의 lastSummary 를 지운다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      runKm(async, location, repository);
      controller.end();
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).lastSummary, isNotNull);

      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      final state = container.read(runControllerProvider);
      expect(state.runId, _runId);
      expect(state.lastSummary, isNull);
      expect(state.lastError, isNull);
    });
  });

  test('주기 저장 실패는 lastError 에 남기고 점은 다음 저장 때 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);
      stepTo(async, location, 9);
      repository.appendError = StateError('디스크 가득');

      async.elapse(const Duration(seconds: 8));

      expect(repository.appendCalls, isEmpty);
      expect(container.read(runControllerProvider).lastError, _saveError);

      // 새 점이 채택돼도 저장 오류는 지우지 않는다.
      stepTo(async, location, 15);
      expect(container.read(runControllerProvider).lastError, _saveError);

      async.elapse(const Duration(seconds: 9));

      final call = repository.appendCalls.single;
      expect(call.segmentIndex, 0);
      expect(call.points, hasLength(3));
      expect(call.movingTime, const Duration(seconds: 20));
    });
  });

  test('start 두 번을 연달아 부르면 러닝은 하나만 만들고 두 번째는 StateError', () {
    _run((async, controller, container, repository, location) {
      Object? error;
      controller.start(goal: DistanceGoal(3000));
      controller
          .start(goal: DistanceGoal(3000))
          .catchError((Object e) => error = e);
      async.flushMicrotasks();

      expect(error, isA<StateError>());
      expect(repository.log, ['createActiveRun']);
      expect(location.listenCount, 1);
    });
  });

  test('end 가 저장하는 동안 resume 은 StateError, end 뒤 구독·타이머가 없다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      runKm(async, location, repository);
      controller.pause();
      async.flushMicrotasks();
      final gate = repository.appendGate = Completer<void>();

      controller.end();
      async.flushMicrotasks();
      expect(controller.resume, throwsStateError);

      gate.complete();
      async.flushMicrotasks();
      expect(repository.log.last, 'completeRun');
      expect(location.isListened, isFalse);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test(
    'end 가 저장하는 동안 pause·end 는 StateError, completeRun 뒤 appendPoints 없음',
    () {
      _run((async, controller, container, repository, location) {
        controller.start(goal: DistanceGoal(3000));
        async.flushMicrotasks();
        runKm(async, location, repository);
        final gate = repository.appendGate = Completer<void>();

        controller.end();
        async.flushMicrotasks();
        expect(controller.pause, throwsStateError);
        Object? error;
        controller.end().then<void>((_) {}, onError: (Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isA<StateError>());

        gate.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        expect(repository.log, ['appendPoints', 'completeRun']);
      });
    },
  );

  test(
    'completeRun 이 실패하면 lastError 에 남기고 end 를 다시 부르면 completeRun 만 다시 한다',
    () {
      _run((async, controller, container, repository, location) {
        controller.start(goal: DistanceGoal(3000));
        async.flushMicrotasks();
        runKm(async, location, repository);
        repository.completeError = StateError('쓰기 실패');

        Object? error;
        controller.end().then<void>((_) {}, onError: (Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isA<StateError>());
        final failed = container.read(runControllerProvider);
        expect(failed.lastError, _endError);
        // 엔진은 이미 끝났으므로 재개할 수 없다. 화면은 종료만 남긴다.
        expect(failed.snapshot.state, RunState.ended);
        expect(controller.pause, throwsStateError);
        expect(controller.resume, throwsStateError);

        RunSummary? summary;
        controller.end().then((s) => summary = s);
        async.flushMicrotasks();

        expect(summary, isNotNull);
        expect(summary!.points, hasLength(335));
        expect(repository.log, ['appendPoints', 'completeRun', 'completeRun']);
        final state = container.read(runControllerProvider);
        expect(state.runId, isNull);
        expect(state.lastSummary, same(summary));
      });
    },
  );

  test('pause 저장 실패는 lastError 에 남기고 점은 다음 저장 때 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);
      repository.appendError = StateError('디스크 가득');

      controller.pause();
      async.flushMicrotasks();

      expect(repository.appendCalls, isEmpty);
      expect(container.read(runControllerProvider).lastError, _saveError);

      async.elapse(const Duration(seconds: 9));
      expect(repository.appendCalls.single.points, hasLength(1));
    });
  });

  test('end 의 저장이 실패하면 lastError 에 남기고 resume 하면 구독·주기 저장을 다시 한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);
      controller.pause();
      async.flushMicrotasks();
      repository.appendError = StateError('디스크 가득');

      Object? error;
      controller.end().then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();

      expect(error, isA<StateError>());
      final failed = container.read(runControllerProvider);
      expect(failed.lastError, _endError);
      expect(failed.snapshot.state, RunState.paused);
      expect(location.isListened, isFalse);
      expect(async.pendingTimers, isEmpty);

      controller.resume();
      expect(location.isListened, isTrue);
      stepTo(async, location, 6);
      stepTo(async, location, 12);
      final before = repository.appendCalls.length;
      async.elapse(const Duration(seconds: 9));

      final saved = repository.appendCalls.skip(before).toList();
      expect(saved, isNotEmpty);
      expect(saved.first.segmentIndex, 1);
      expect(saved.first.points, hasLength(2));
      expect(
        container.read(runControllerProvider).snapshot.movingTime,
        const Duration(seconds: 12),
      );
    });
  });

  test('점이 없어도 10초마다 움직인 시간을 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 10));

      final call = repository.appendCalls.single;
      expect(call.points, isEmpty);
      expect(call.movingTime, const Duration(seconds: 10));
    });
  });

  test('resume 뒤 점은 새 구간 번호로 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);
      stepTo(async, location, 6);
      controller.pause();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      controller.resume();
      stepTo(async, location, 9);
      stepTo(async, location, 12);

      async.elapse(const Duration(seconds: 7));

      expect(location.listenCount, 1);
      final withPoints = repository.appendCalls
          .where((c) => c.points.isNotEmpty)
          .toList();
      expect([for (final c in withPoints) c.segmentIndex], [0, 1]);
      expect(withPoints[1].points, hasLength(2));
    });
  });

  test('1초마다 snapshot 을 새로 낸다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 3));

      final state = container.read(runControllerProvider);
      expect(state.runId, _runId);
      expect(state.snapshot.state, RunState.recording);
      expect(state.snapshot.movingTime, const Duration(seconds: 3));
    });
  });

  test('멈추면 틱에서 자동 일시정지하고 구독을 유지하며, 움직이면 창의 점을 새 구간으로 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      for (var i = 1; i <= 3; i++) {
        stepTo(async, location, i * 6.0); // 1·2·3초, 6m 씩
      }

      async.elapse(const Duration(seconds: 10)); // 마지막 움직인 점 3초 + 10초
      final paused = container.read(runControllerProvider).snapshot;
      expect(paused.state, RunState.autoPaused);
      expect(paused.movingTime, const Duration(seconds: 3));
      expect(location.isListened, isTrue);

      for (var i = 1; i <= 3; i++) {
        stepTo(async, location, 18 + i * 6.0); // 14·15·16초
      }
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.recording,
      );
      async.elapse(const Duration(seconds: 4)); // 20초 주기 저장

      final withPoints = repository.appendCalls
          .where((c) => c.points.isNotEmpty)
          .toList();
      expect([for (final c in withPoints) c.segmentIndex], [0, 1]);
      expect(withPoints[0].points, hasLength(3));
      expect(withPoints[1].points.map((p) => p.time), [
        _t0.add(const Duration(seconds: 14)),
        _t0.add(const Duration(seconds: 15)),
        _t0.add(const Duration(seconds: 16)),
      ]);
      expect(location.listenCount, 1);
    });
  });

  test('자동 일시정지 중 위치 스트림이 끊기면 다시 구독한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.autoPaused,
      );
      location.controller.addError(Exception('gps'));
      async.flushMicrotasks();
      expect(location.isListened, isFalse);

      async.elapse(const Duration(seconds: 5));

      expect(location.listenCount, 2);
      expect(location.isListened, isTrue);
    });
  });

  test('위치 스트림 오류는 lastError 에 남기고, 재시도 뒤 점이 오면 오류를 지운다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);

      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).lastError, _locationError);
      expect(location.listenCount, 1);

      async.elapse(const Duration(seconds: 5));
      expect(location.listenCount, 2);
      expect(container.read(runControllerProvider).lastError, _locationError);

      stepTo(async, location, 6);

      final state = container.read(runControllerProvider);
      expect(state.lastError, isNull);
      expect(state.snapshot.state, RunState.recording);
      expect(state.snapshot.distanceM, closeTo(3, 0.01));
    });
  });

  test('재시도 구독이 또 실패하면 5초마다 계속 다시 구독한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));

      expect(location.listenCount, 3);
    });
  });

  test('오류 뒤 pause → resume 하면 바로 다시 구독하고 점을 받는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();

      controller.pause();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);

      controller.resume();
      expect(location.listenCount, 2);
      stepTo(async, location, 3);
      stepTo(async, location, 6);

      final state = container.read(runControllerProvider);
      expect(state.lastError, isNull);
      expect(state.snapshot.distanceM, closeTo(3, 0.01));
    });
  });

  test('위치 스트림이 끝나도 기록 중이면 다시 구독한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);

      // 닫은 스트림은 다시 구독해도 곧바로 done 이 오지만, 재시도는 계속된다.
      location.controller.close();
      async.flushMicrotasks();
      expect(location.listenCount, 1);

      async.elapse(const Duration(seconds: 5));
      expect(location.listenCount, 2);
    });
  });

  test('백그라운드에서 끊기면 구독하지 않다가, 화면으로 돌아오면 바로 구독한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      stepTo(async, location, 3);

      _lifecycle.set(AppLifecycleState.paused);
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);
      expect(container.read(runControllerProvider).lastError, _locationError);

      _lifecycle.set(AppLifecycleState.inactive);
      async.elapse(const Duration(seconds: 10));
      expect(location.listenCount, 1);

      _lifecycle.set(AppLifecycleState.resumed);
      expect(location.listenCount, 2);
      stepTo(async, location, 6);
      final state = container.read(runControllerProvider);
      expect(state.lastError, isNull);
      // 끊긴 사이 신호 끊김이 됐고(결정 0033), 점이 오면 그 점부터 이어 기록한다.
      expect(state.snapshot.state, RunState.recording);
    });
  });

  test('재시도 시각에 백그라운드면 구독하지 않고, 돌아오면 바로 구독한다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 2));
      _lifecycle.set(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);

      _lifecycle.set(AppLifecycleState.resumed);
      expect(location.listenCount, 2);
    });
  });

  test('구독이 살아 있으면 화면으로 돌아와도 다시 구독하지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();

      _lifecycle.set(AppLifecycleState.paused);
      _lifecycle.set(AppLifecycleState.resumed);
      expect(location.listenCount, 1);
    });
  });

  test('사용자가 일시정지한 동안 화면으로 돌아와도 구독하지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      _lifecycle.set(AppLifecycleState.paused);
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      controller.pause();
      async.flushMicrotasks();

      _lifecycle.set(AppLifecycleState.resumed);
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);
    });
  });

  test('end 뒤에 화면으로 돌아와도 구독하지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      _lifecycle.set(AppLifecycleState.paused);
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      controller.end();
      async.flushMicrotasks();

      _lifecycle.set(AppLifecycleState.resumed);
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);
    });
  });

  test('pause·end 뒤에는 재시도 타이머가 돌지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();

      controller.pause();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 1);

      controller.resume();
      expect(location.listenCount, 2);
      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      controller.end();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(location.listenCount, 2);
    });
  });

  group('restoreIfAny', () {
    // 앱이 죽기 전, 10분 전에 시작한 러닝.
    final startedAt = _t0.subtract(const Duration(minutes: 10));
    final restoredPoints = [
      _sample(startedAt, 0),
      _sample(startedAt.add(const Duration(seconds: 2)), 4),
      _sample(startedAt.add(const Duration(seconds: 4)), 8),
    ];
    final activeRun = ActiveRun(
      id: _runId,
      startedAt: startedAt,
      segments: [restoredPoints],
      movingTime: const Duration(seconds: 4),
    );

    test('findActiveRun 이 점 3개를 주면 true, 상태 paused, 거리 복원', () {
      _run(activeRun: activeRun, (
        async,
        controller,
        container,
        repository,
        location,
      ) {
        bool? restored;
        controller.restoreIfAny().then((r) => restored = r);
        async.flushMicrotasks();

        expect(restored, isTrue);
        final state = container.read(runControllerProvider);
        expect(state.runId, _runId);
        expect(state.snapshot.state, RunState.paused);
        expect(
          state.snapshot.distanceM,
          closeTo(
            haversineMeters(_northOf(0), _lng0, _northOf(4), _lng0) +
                haversineMeters(_northOf(4), _lng0, _northOf(8), _lng0),
            1e-9,
          ),
        );
        expect(state.snapshot.movingTime, const Duration(seconds: 4));
        expect(location.listenCount, 0);

        async.elapse(const Duration(seconds: 10));
        final call = repository.appendCalls.single;
        expect(call.points, isEmpty);
        expect(call.movingTime, const Duration(seconds: 4));
      });
    });

    test('복원 후 resume 하면 위치를 구독하고 점은 다음 구간 번호로 저장한다', () {
      _run(activeRun: activeRun, (
        async,
        controller,
        container,
        repository,
        location,
      ) {
        controller.restoreIfAny();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        controller.resume();
        expect(location.listenCount, 1);
        stepTo(async, location, 20);
        controller.pause();
        async.flushMicrotasks();

        final call = repository.appendCalls.last;
        expect(call.segmentIndex, 1);
        expect(call.points, hasLength(1));
      });
    });

    test('러닝이 이미 있으면 StateError', () {
      _run(activeRun: activeRun, (
        async,
        controller,
        container,
        repository,
        location,
      ) {
        controller.start(goal: DistanceGoal(3000));
        async.flushMicrotasks();

        Object? error;
        controller.restoreIfAny().then<void>(
          (_) {},
          onError: (Object e) => error = e,
        );
        async.flushMicrotasks();

        expect(error, isA<StateError>());
        expect(repository.log, ['createActiveRun']);
      });
    });

    test('활성 러닝이 없으면 false', () {
      _run((async, controller, container, repository, location) {
        bool? restored;
        controller.restoreIfAny().then((r) => restored = r);
        async.flushMicrotasks();

        expect(restored, isFalse);
        expect(container.read(runControllerProvider).runId, isNull);
        async.elapse(const Duration(seconds: 30));
        expect(repository.appendCalls, isEmpty);
      });
    });
  });
}

void _weightTests() {
  for (final (weight, basis) in [(70.0, 70.0), (null, 65.0)]) {
    test('종료 칼로리는 체중 ${weight ?? '없음'} → ${basis}kg 기준', () {
      _run(weightKg: weight, (
        async,
        controller,
        container,
        repository,
        location,
      ) {
        controller.start(goal: DistanceGoal(3000));
        async.flushMicrotasks();
        for (var i = 1; i <= 200; i++) {
          async.elapse(const Duration(seconds: 1));
          location.controller.add(_sample(_t0.add(async.elapsed), i * 3.0));
          async.flushMicrotasks();
        }
        // 진행 중 표시도 같은 체중을 쓴다.
        expect(container.read(runControllerProvider).weightKg, basis);
        RunSummary? summary;
        controller.end().then((s) => summary = s);
        async.flushMicrotasks();
        expect(summary!.distanceM, greaterThan(500));
        expect(
          summary!.calories,
          closeTo(basis * summary!.distanceM / 1000 * 1.036, 1e-9),
        );
      });
    });
  }
}
