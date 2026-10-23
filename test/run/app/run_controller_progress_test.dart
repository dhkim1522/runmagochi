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
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import '../ui/fakes.dart' show FakeSpeaker;

const _lat0 = 37.5;
const _lng0 = 127.0;
final _t0 = DateTime(2026, 10, 21, 7);

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
  Future<void> discardActiveRun(String runId) async {}
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

  @override
  Future<void> showNow({required String title, required String body}) async {}
  @override
  Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {}
}

class _Progress implements RunProgressNotifier {
  final shown = <RunProgressContent>[];

  /// [shown] 과 같은 순서로, 띄운 때(시작 기준).
  final shownAt = <Duration>[];
  Duration Function() now = () => Duration.zero;
  int cancels = 0;
  bool fails = false;

  @override
  Future<void> show(RunProgressContent content) async {
    if (fails) throw StateError('알림 실패');
    shown.add(content);
    shownAt.add(now());
  }

  @override
  Future<void> cancel() async {
    if (fails) throw StateError('알림 실패');
    cancels++;
  }

  @override
  Future<void> showEndWarning(
    DateTime deadline, {
    required bool paused,
    bool signalLost = false,
  }) async {}

  @override
  Future<void> cancelEndWarning() async {}
}

void _run(
  void Function(
    FakeAsync async,
    ProviderContainer container,
    _Progress progress,
    void Function(Duration at, double meters) sampleAt,
  )
  body, {
  bool fails = false,
}) {
  fakeAsync((async) {
    final location = _Location();
    final progress = _Progress()
      ..fails = fails
      ..now = () => async.elapsed;
    final container = ProviderContainer(
      overrides: [
        speakerProvider.overrideWithValue(FakeSpeaker()),
        runRepositoryProvider.overrideWithValue(_Repo()),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        locationSourceProvider.overrideWithValue(location),
        appLifecycleProvider.overrideWithValue(_Lifecycle()),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(_Instant()),
        runProgressNotifierProvider.overrideWithValue(progress),
      ],
    );
    container.read(runControllerProvider.notifier);
    void sampleAt(Duration at, double meters) {
      async.elapse(at - async.elapsed);
      location.controller.add(_sample(_t0.add(at), meters));
      async.flushMicrotasks();
    }

    body(async, container, progress, sampleAt);
    container.dispose();
    async.flushMicrotasks();
  });
}

void main() {
  test('시작하면 바로 알림을 띄운다', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      expect(progress.shown, hasLength(1));
      expect(progress.shown.single.title, '러닝 중 · 0.00km');
      expect(progress.shown.single.actions, [RunProgressAction.pause]);
    });
  });

  test('시간 목표로 시작하면 알림 본문이 남은 시간이다', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const TimeGoal(Duration(minutes: 30)));
      async.flushMicrotasks();
      expect(progress.shown.single.body, '목표 30분까지 30:00');
    });
  });

  test('틱마다 다시 띄우지 않고, 거리가 10m 단위로 바뀌면 3초 간격으로 갱신한다', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(progress.shown, hasLength(1));

      sampleAt(const Duration(seconds: 2), 0);
      sampleAt(const Duration(seconds: 4), 12);
      expect(progress.shown, hasLength(2)); // 0초 뒤 4초가 지나 바로 갱신
      expect(progress.shown.last.title, '러닝 중 · 0.01km');

      sampleAt(const Duration(seconds: 5), 18); // 마지막 갱신에서 1초
      expect(progress.shown, hasLength(2));
      async.elapse(const Duration(seconds: 3)); // 7초 틱이 반영한다
      expect(progress.shown, hasLength(3));
      expect(progress.shown.last.title, '러닝 중 · 0.02km');

      async.elapse(const Duration(seconds: 6)); // 거리가 그대로면 안 띄운다
      expect(progress.shown, hasLength(3));

      async.elapse(const Duration(seconds: 1)); // 5초 점 뒤 10초에 멈춤
      expect(progress.shown, hasLength(4));
      expect(progress.shown.last.title, '멈춰서 일시정지했어요 · 0.02km');
    });
  });

  test('일시정지·재개는 3초 안이어도 바로 띄운다', () {
    _run((async, container, progress, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      controller.pause();
      async.flushMicrotasks();
      expect(progress.shown.last.actions, [RunProgressAction.resume]);
      expect(progress.shown.last.title, startsWith('일시정지 · 0.00km'));
      controller.resume();
      async.flushMicrotasks();
      expect(progress.shown.last.actions, [RunProgressAction.pause]);
      expect(progress.shown, hasLength(3));
    });
  });

  test('시간 목표는 GPS 점이 없어도 남은 시간이 15초 단계를 넘으면 갱신한다', () {
    _run((async, container, progress, sampleAt) {
      // 남은 시간이 움직인 시간 9초에 1800초 아래로 내려가 15초 단계가 바뀐다.
      container
          .read(runControllerProvider.notifier)
          .start(goal: const TimeGoal(Duration(seconds: 1808)));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      for (var s = 2; s <= 5; s++) {
        sampleAt(Duration(seconds: s), (s - 1) * 4.0);
      }
      // 이후 점이 없다. 자동 일시정지(10초) 전까지 틱만 흐른다.
      async.elapse(const Duration(seconds: 7));
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.recording,
      );
      expect(
        progress.shown.last.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 9)),
      );
      expect(progress.shown.last.body, startsWith('목표 30분까지 29:5'));
    });
  });

  test('시간 목표를 달성하면 거리 표시가 그대로여도 알림이 달성 문구로 바뀐다', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const TimeGoal(Duration(seconds: 30)));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      for (var s = 2; s <= 25; s++) {
        sampleAt(Duration(seconds: s), (s - 1) * 4.0);
      }
      expect(progress.shown.last.body, startsWith('목표 0분까지'));
      expect(container.read(runControllerProvider).goalReached, isFalse);
      // 거리 화면 값(0.10km)이 같은 점으로 30초를 채운다.
      sampleAt(const Duration(seconds: 31), 102);
      expect(container.read(runControllerProvider).goalReached, isTrue);
      expect(progress.shown.last.body, '목표 0분 달성!');
    });
  });

  test('탈것 의심 문구는 풀리면 바로 끄고, 다시 켜기는 60초에 한 번이다 (결정 0033)', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      var m = 0.0;
      void move(int from, int until, double speed) {
        for (var i = from; i <= until; i++) {
          m += speed;
          sampleAt(Duration(seconds: i), m);
        }
      }

      const notice = '혹시 뭘 타셨나요? 이 구간은 기록에서 뺄게요';
      move(1, 60, 3);
      move(61, 100, 7); // 84초에 의심
      move(101, 110, 3); // 107초에 풀림
      move(111, 150, 7); // 133초에 다시 의심, 첫 안내 60초 안
      final changes = <(int, bool)>[];
      for (final (i, c) in progress.shown.indexed) {
        final on = c.body == notice;
        if (i == 0 || on != (progress.shown[i - 1].body == notice)) {
          changes.add((progress.shownAt[i].inSeconds, on));
        }
        // 문구는 탈것 의심(일시정지 제목)일 때만 보인다.
        if (on) expect(c.title, startsWith('일시정지'), reason: '$i');
      }
      expect(changes, [(0, false), (84, true), (107, false), (144, true)]);
      // 다시 의심했지만 아직 켜지 못한 동안은 일시정지 제목에 목표 본문.
      final waiting = [
        for (final (i, c) in progress.shown.indexed)
          if (progress.shownAt[i].inSeconds >= 133 &&
              progress.shownAt[i].inSeconds < 144)
            c,
      ];
      expect(waiting, isNotEmpty);
      for (final c in waiting) {
        expect(c.title, startsWith('일시정지'));
        expect(c.body, startsWith('목표 5km까지'));
        expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
      }
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.vehicle,
      );
    });
  });

  test('끝내면 알림을 지운다', () {
    _run((async, container, progress, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      controller.end();
      async.flushMicrotasks();
      expect(progress.cancels, 1);
    });
  });

  test('알림이 실패해도 러닝은 계속된다', () {
    _run(fails: true, (async, container, progress, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 10), 30);
      controller.pause();
      controller.resume();
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).runId, 'run-1');
      controller.end();
      async.flushMicrotasks();
      // 1km 미만이라 저장하지 않고 지운다. 알림이 실패해도 끝낸다.
      final view = container.read(runControllerProvider);
      expect(view.runId, isNull);
      expect(view.discardedShortRun, isTrue);
    });
  });

  test('시간 목표를 달성한 뒤에는 15초 단계가 바뀌어도 알림을 다시 띄우지 않는다', () {
    _run((async, container, progress, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const TimeGoal(Duration(seconds: 30)));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      for (var s = 2; s <= 25; s++) {
        sampleAt(Duration(seconds: s), (s - 1) * 4.0);
      }
      sampleAt(const Duration(seconds: 31), 102);
      expect(container.read(runControllerProvider).goalReached, isTrue);
      expect(progress.shown.last.body, '목표 0분 달성!');

      // 달성 뒤 초속 1m 로 계속 달리면 움직인 시간이 늘어 15초 단계가 세 번 바뀌지만,
      // 알림은 화면 거리(10m 단위)가 바뀔 때만 갱신한다. 45m 를 가면 거리 표시는 4~5번 바뀐다.
      final shownAfterReach = progress.shown.length;
      for (var s = 32; s <= 76; s++) {
        sampleAt(Duration(seconds: s), 102.0 + (s - 31));
      }
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.recording,
      );
      expect(progress.shown.length - shownAfterReach, lessThanOrEqualTo(5));
    });
  });
}
