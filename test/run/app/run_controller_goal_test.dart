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
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

const _lat0 = 37.5;
const _lng0 = 127.0;
final _t0 = DateTime(2026, 10, 18, 7);

double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

LocationSample _sample(DateTime time, double meters) => LocationSample(
  time: time,
  latitude: _northOf(meters),
  longitude: _lng0,
  accuracy: 5,
);

class _Repo implements RunRepository {
  @override
  Future<List<RunDetail>> listRunDetails() => throw UnimplementedError();

  ActiveRun? activeRun;

  @override
  Future<RunGoal?> lastGoal() async => null;

  @override
  Future<String> createActiveRun(
    DateTime startedAt, {
    required RunGoal goal,
  }) async => 'run-1';

  @override
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  }) async {}

  @override
  Future<void> completeRun(String runId, RunSummary summary) async {}

  @override
  Future<ActiveRun?> findActiveRun() async => activeRun;

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

  @override
  Future<void> cancelAutoEnd() async {}
}

void _run(
  void Function(
    FakeAsync async,
    ProviderContainer container,
    _Notifier notifier,
    void Function(Duration at, double meters) sampleAt,
  )
  body, {
  ActiveRun? activeRun,
  bool notifierFails = false,
}) {
  fakeAsync((async) {
    final repo = _Repo()..activeRun = activeRun;
    final location = _Location();
    final notifier = _Notifier()..fails = notifierFails;
    final container = ProviderContainer(
      overrides: [
        speakerProvider.overrideWithValue(FakeSpeaker()),
        runRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        runProgressNotifierProvider.overrideWithValue(
          FakeRunProgressNotifier(),
        ),
        locationSourceProvider.overrideWithValue(location),
        appLifecycleProvider.overrideWithValue(_Lifecycle()),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(notifier),
      ],
    );
    container.read(runControllerProvider.notifier);
    void send(Duration at, double meters) {
      async.elapse(at - async.elapsed);
      location.controller.add(_sample(_t0.add(at), meters));
      async.flushMicrotasks();
    }

    double? lastMeters;
    var lastAt = Duration.zero;

    /// [at] 에 [meters] 지점에 닿는다. 점 사이가 멀면 자동 일시정지되므로
    /// 직전 점부터 5초마다 곧게 이어 달린다.
    void sampleAt(Duration at, double meters) {
      final from = lastMeters;
      if (from != null) {
        const step = Duration(seconds: 5);
        for (var t = lastAt + step; t < at; t += step) {
          final f = (t - lastAt).inMicroseconds / (at - lastAt).inMicroseconds;
          send(t, from + (meters - from) * f);
        }
      }
      send(at, meters);
      lastMeters = meters;
      lastAt = at;
    }

    body(async, container, notifier, sampleAt);
    container.dispose();
    async.flushMicrotasks();
  });
}

void main() {
  test('목표 3km: 2.99km 까지 알림 0회, 3.00km 에서 1회, 더 달려도 1회', () {
    _run((async, container, notifier, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      expect(
        container.read(runControllerProvider).goal,
        const DistanceGoal(3000),
      );
      expect(container.read(runControllerProvider).goalReached, isFalse);

      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 401), 1000);
      sampleAt(const Duration(seconds: 801), 2000);
      sampleAt(const Duration(seconds: 1201), 2990);
      var view = container.read(runControllerProvider);
      expect(view.snapshot.distanceM, lessThan(3000));
      expect(view.goalReached, isFalse);
      expect(notifier.shown, isEmpty);

      sampleAt(const Duration(seconds: 1205), 3005);
      view = container.read(runControllerProvider);
      expect(view.snapshot.distanceM, greaterThanOrEqualTo(3000));
      expect(view.goalReached, isTrue);
      expect(notifier.shown, [('목표 달성!', '3km 목표를 채웠어요. 종료할 때까지 기록은 이어져요')]);

      sampleAt(const Duration(seconds: 1605), 4005);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(runControllerProvider).goalReached, isTrue);
      expect(notifier.shown, hasLength(1));
    });
  });

  test('러닝이 끝나면 목표 달성 알림을 지운다', () {
    _run((async, container, notifier, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 501), 3005);
      expect(notifier.shown, hasLength(1));
      expect(notifier.goalCancelled, 0);
      controller.end();
      async.flushMicrotasks();
      expect(notifier.goalCancelled, 1);
    });
  });

  test('표시 단위(10m) 반올림: 4,995m 이상은 5km 목표를 채우고 4,994m 는 못 채운다', () {
    for (final (meters, reached) in [(4994.0, false), (4995.5, true)]) {
      _run((async, container, notifier, sampleAt) {
        container
            .read(runControllerProvider.notifier)
            .start(goal: DistanceGoal(5000));
        async.flushMicrotasks();
        sampleAt(const Duration(seconds: 1), 0);
        for (var km = 1; km <= 4; km++) {
          sampleAt(Duration(seconds: 1 + km * 400), km * 1000);
        }
        sampleAt(const Duration(seconds: 2001), meters);
        final view = container.read(runControllerProvider);
        expect(view.snapshot.distanceM, lessThan(5000));
        expect(
          view.goalReached,
          reached,
          reason: '${view.snapshot.distanceM} m',
        );
        expect(notifier.shown, hasLength(reached ? 1 : 0));
      });
    }
  });

  test('알림이 실패해도 달성 상태는 바뀌고 오류는 퍼지지 않는다', () {
    _run(notifierFails: true, (async, container, notifier, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(3000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 501), 3005);
      expect(container.read(runControllerProvider).goalReached, isTrue);
    });
  });

  test('복원한 러닝이 이미 목표를 넘었으면 달성 상태이고 알리지 않는다', () {
    final start = _t0.subtract(const Duration(minutes: 30));
    final points = [
      _sample(start, 0),
      _sample(start.add(const Duration(minutes: 10)), 1500),
      _sample(start.add(const Duration(minutes: 20)), 3200),
    ];
    _run(
      activeRun: ActiveRun(
        id: 'run-1',
        startedAt: start,
        segments: [points],
        movingTime: const Duration(minutes: 20),
        goal: const DistanceGoal(3000),
      ),
      (async, container, notifier, sampleAt) {
        container.read(runControllerProvider.notifier).restoreIfAny();
        async.flushMicrotasks();
        final view = container.read(runControllerProvider);
        expect(view.goal, const DistanceGoal(3000));
        expect(view.goalReached, isTrue);
        expect(notifier.shown, isEmpty);
      },
    );
  });

  test('목표 없는 복원 러닝은 목표 행이 없고 알리지 않는다', () {
    final start = _t0.subtract(const Duration(minutes: 30));
    _run(
      activeRun: ActiveRun(
        id: 'run-1',
        startedAt: start,
        segments: [
          [
            _sample(start, 0),
            _sample(start.add(const Duration(minutes: 20)), 3200),
          ],
        ],
        movingTime: const Duration(minutes: 20),
      ),
      (async, container, notifier, sampleAt) {
        container.read(runControllerProvider.notifier).restoreIfAny();
        async.flushMicrotasks();
        final view = container.read(runControllerProvider);
        expect(view.goal, isNull);
        expect(view.goalReached, isFalse);
        expect(notifier.shown, isEmpty);
      },
    );
  });

  group('시간 목표 30분', () {
    const goal = TimeGoal(Duration(minutes: 30));

    test('계속 움직여 30:00 을 넘기면 알림 1회, 끝 판정도 달성', () {
      _run((async, container, notifier, sampleAt) {
        final controller = container.read(runControllerProvider.notifier);
        controller.start(goal: goal);
        async.flushMicrotasks();
        sampleAt(const Duration(seconds: 1), 0);
        sampleAt(const Duration(minutes: 29, seconds: 55), 3000);
        var view = container.read(runControllerProvider);
        expect(view.goalReached, isFalse);
        expect(notifier.shown, isEmpty);

        sampleAt(const Duration(minutes: 30, seconds: 3), 3020);
        view = container.read(runControllerProvider);
        expect(view.goalReached, isTrue);
        expect(notifier.shown, [('목표 달성!', '30분 목표를 채웠어요. 종료할 때까지 기록은 이어져요')]);

        sampleAt(const Duration(minutes: 30, seconds: 8), 3030);
        async.elapse(const Duration(minutes: 1));
        expect(notifier.shown, hasLength(1));
        late RunSummary summary;
        controller.end().then((v) => summary = v);
        async.flushMicrotasks();
        expect(summary.movingTime, greaterThanOrEqualTo(goal.time));
      });
    });

    test('29:55 에 멈추면 30:30 이 지나도 알리지 않고 끝 판정도 미달', () {
      _run((async, container, notifier, sampleAt) {
        final controller = container.read(runControllerProvider.notifier);
        controller.start(goal: goal);
        async.flushMicrotasks();
        sampleAt(const Duration(seconds: 1), 0);
        sampleAt(const Duration(minutes: 29, seconds: 55), 3000);
        async.elapse(const Duration(minutes: 30, seconds: 30) - async.elapsed);
        final view = container.read(runControllerProvider);
        expect(view.goalReached, isFalse);
        expect(notifier.shown, isEmpty);
        late RunSummary summary;
        controller.end().then((v) => summary = v);
        async.flushMicrotasks();
        expect(summary.movingTime, lessThan(goal.time));
      });
    });

    test('사용자 일시정지 시간은 세지 않는다', () {
      _run((async, container, notifier, sampleAt) {
        final controller = container.read(runControllerProvider.notifier);
        controller.start(goal: goal);
        async.flushMicrotasks();
        sampleAt(const Duration(seconds: 1), 0);
        sampleAt(const Duration(minutes: 20), 2000);
        controller.pause();
        async.elapse(const Duration(minutes: 10)); // 벽시계 30분
        controller.resume();
        async.elapse(const Duration(seconds: 3));
        final view = container.read(runControllerProvider);
        expect(view.snapshot.movingTime, lessThan(const Duration(minutes: 21)));
        expect(view.goalReached, isFalse);
        expect(notifier.shown, isEmpty);
      });
    });

    test('자동 일시정지(멈춤) 시간은 세지 않는다', () {
      _run((async, container, notifier, sampleAt) {
        container.read(runControllerProvider.notifier).start(goal: goal);
        async.flushMicrotasks();
        sampleAt(const Duration(seconds: 1), 0);
        sampleAt(const Duration(minutes: 20), 2000);
        async.elapse(const Duration(minutes: 10)); // 점 없이 서 있다
        final view = container.read(runControllerProvider);
        expect(view.snapshot.movingTime, lessThan(const Duration(minutes: 21)));
        expect(view.goalReached, isFalse);
        expect(notifier.shown.where((n) => n.$1 == '목표 달성!'), isEmpty);
      });
    });

    test('복원한 러닝이 이미 30분을 넘었으면 달성 상태이고 알리지 않는다', () {
      final start = _t0.subtract(const Duration(minutes: 50));
      _run(
        activeRun: ActiveRun(
          id: 'run-1',
          startedAt: start,
          segments: [
            [
              _sample(start, 0),
              _sample(start.add(const Duration(minutes: 40)), 4000),
            ],
          ],
          movingTime: const Duration(minutes: 40),
          goal: goal,
        ),
        (async, container, notifier, sampleAt) {
          container.read(runControllerProvider.notifier).restoreIfAny();
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          final view = container.read(runControllerProvider);
          expect(view.goal, goal);
          expect(view.goalReached, isTrue);
          expect(notifier.shown, isEmpty);
        },
      );
    });
  });
}
