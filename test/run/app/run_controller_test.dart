import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/providers.dart';
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
  ActiveRun? activeRun;

  /// 주면 appendPoints 가 이 완료를 기다린다.
  Completer<void>? appendGate;

  /// 주면 다음 appendPoints 한 번이 이 오류를 던진다.
  Object? appendError;
  final appendCalls = <_AppendCall>[];
  final completed = <(String, RunSummary)>[];

  /// 저장소 호출 순서.
  final log = <String>[];

  @override
  Future<String> createActiveRun(DateTime startedAt) async {
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
  Future<ActiveRun?> findActiveRun() async => activeRun;

  @override
  Future<void> completeRun(String runId, RunSummary summary) async {
    log.add('completeRun');
    completed.add((runId, summary));
  }

  @override
  Future<List<RunListItem>> listRuns() => throw UnimplementedError();

  @override
  Future<RunDetail?> getRun(String id) => throw UnimplementedError();

  @override
  Future<(double, int)> weeklyTotal(DateTime now) => throw UnimplementedError();
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
}) {
  fakeAsync((async) {
    final repository = _FakeRunRepository()..activeRun = activeRun;
    final location = _FakeLocationSource();
    final container = ProviderContainer(
      overrides: [
        runRepositoryProvider.overrideWithValue(repository),
        locationSourceProvider.overrideWithValue(location),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
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
  });
}

void main() {
  /// 1초를 보내고 그 시각에 [meters] 지점의 점을 보낸다.
  void stepTo(FakeAsync async, _FakeLocationSource location, double meters) {
    async.elapse(const Duration(seconds: 1));
    location.controller.add(_sample(_t0.add(async.elapsed), meters));
    async.flushMicrotasks();
  }

  test('start → 점 5개 → 10초 경과 → appendPoints 1회, 점 5개', () {
    _run((async, controller, container, repository, location) {
      controller.start();
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
      controller.start();
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
      controller.start();
      async.flushMicrotasks();
      for (var i = 1; i <= 2; i++) {
        stepTo(async, location, i * 3.0);
      }

      RunSummary? summary;
      controller.end().then((s) => summary = s);
      async.flushMicrotasks();

      expect(summary, isNotNull);
      expect(repository.completed.single.$1, _runId);
      expect(repository.completed.single.$2, same(summary));
      expect(summary!.points, hasLength(2));
      expect(repository.appendCalls.single.points, hasLength(2));
      expect(repository.log, [
        'createActiveRun',
        'appendPoints',
        'completeRun',
      ]);
      expect(location.isListened, isFalse);

      final state = container.read(runControllerProvider);
      expect(state.runId, isNull);
      expect(state.lastSummary, same(summary));
      expect(state.snapshot.state, RunState.idle);
    });
  });

  test('end 후 30초가 지나도 appendPoints 를 더 부르지 않는다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();
      stepTo(async, location, 3);
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
      controller.start();
      async.flushMicrotasks();
      stepTo(async, location, 3);
      final gate = repository.appendGate = Completer<void>();
      async.elapse(const Duration(seconds: 9));
      expect(repository.log, ['createActiveRun', 'appendPoints']);

      controller.end();
      async.flushMicrotasks();
      expect(repository.log, ['createActiveRun', 'appendPoints']);
      expect(repository.completed, isEmpty);

      gate.complete();
      async.flushMicrotasks();
      expect(repository.log, [
        'createActiveRun',
        'appendPoints',
        'appendPoints',
        'completeRun',
      ]);
      expect(repository.appendCalls[0].points, hasLength(1));
      expect(repository.appendCalls[1].points, isEmpty);
    });
  });

  test('러닝이 이미 있으면 start 는 StateError', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();

      Object? error;
      controller.start().catchError((Object e) => error = e);
      async.flushMicrotasks();

      expect(error, isA<StateError>());
      expect(repository.log, ['createActiveRun']);
      expect(location.listenCount, 1);
    });
  });

  test('start 는 이전 러닝의 lastSummary 를 지운다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();
      controller.end();
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).lastSummary, isNotNull);

      controller.start();
      async.flushMicrotasks();

      final state = container.read(runControllerProvider);
      expect(state.runId, _runId);
      expect(state.lastSummary, isNull);
      expect(state.lastError, isNull);
    });
  });

  test('주기 저장 실패는 lastError 에 남기고 점은 다음 저장 때 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();
      stepTo(async, location, 3);
      repository.appendError = StateError('디스크 가득');

      async.elapse(const Duration(seconds: 9));

      expect(repository.appendCalls, isEmpty);
      expect(
        container.read(runControllerProvider).lastError,
        contains('디스크 가득'),
      );

      async.elapse(const Duration(seconds: 10));

      final call = repository.appendCalls.single;
      expect(call.segmentIndex, 0);
      expect(call.points, hasLength(1));
      expect(call.movingTime, const Duration(seconds: 20));
    });
  });

  test('점이 없어도 10초마다 움직인 시간을 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 10));

      final call = repository.appendCalls.single;
      expect(call.points, isEmpty);
      expect(call.movingTime, const Duration(seconds: 10));
    });
  });

  test('resume 뒤 점은 새 구간 번호로 저장한다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
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
      controller.start();
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 3));

      final state = container.read(runControllerProvider);
      expect(state.runId, _runId);
      expect(state.snapshot.state, RunState.recording);
      expect(state.snapshot.movingTime, const Duration(seconds: 3));
    });
  });

  test('위치 스트림 오류는 lastError 에 남기고 기록은 이어간다', () {
    _run((async, controller, container, repository, location) {
      controller.start();
      async.flushMicrotasks();
      stepTo(async, location, 3);

      location.controller.addError(Exception('GPS 꺼짐'));
      async.flushMicrotasks();
      stepTo(async, location, 6);

      final state = container.read(runControllerProvider);
      expect(state.lastError, contains('GPS 꺼짐'));
      expect(state.snapshot.state, RunState.recording);
      expect(state.snapshot.distanceM, closeTo(3, 0.01));
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
