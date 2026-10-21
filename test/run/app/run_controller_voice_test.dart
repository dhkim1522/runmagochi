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
  bool voice = true;
  @override
  Future<double?> weightKg() async => null;
  @override
  Future<bool> voiceGuide() async => voice;
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

class _Notifier implements InstantNotifier {
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

void _run(
  void Function(
    FakeAsync async,
    ProviderContainer container,
    FakeSpeaker speaker,
    _Profile profile,
    void Function(Duration at, double meters) sampleAt,
  )
  body, {
  ActiveRun? activeRun,
}) {
  fakeAsync((async) {
    final repo = _Repo()..activeRun = activeRun;
    final location = _Location();
    final speaker = FakeSpeaker();
    final profile = _Profile();
    final container = ProviderContainer(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(profile),
        runProgressNotifierProvider.overrideWithValue(
          FakeRunProgressNotifier(),
        ),
        locationSourceProvider.overrideWithValue(location),
        appLifecycleProvider.overrideWithValue(_Lifecycle()),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(_Notifier()),
        speakerProvider.overrideWithValue(speaker),
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

    body(async, container, speaker, profile, sampleAt);
    container.dispose();
    async.flushMicrotasks();
  });
}

void main() {
  test('시작 때 한 번, 1km 마다 한 번씩, 같은 구간은 두 번 읽지 않는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      expect(speaker.spoken, ['러닝을 시작해요']);

      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 301), 1000);
      expect(speaker.spoken.length, 2);
      expect(speaker.spoken[1], startsWith('1킬로미터. 시간 5분'));
      expect(speaker.spoken[1], contains('평균 페이스 5분'));

      // 같은 구간 안에서 더 달려도 새 안내는 없다.
      sampleAt(const Duration(seconds: 401), 1300);
      async.elapse(const Duration(seconds: 3));
      expect(speaker.spoken.length, 2);

      sampleAt(const Duration(seconds: 601), 2000);
      expect(speaker.spoken.length, 3);
      expect(speaker.spoken[2], startsWith('2킬로미터. 시간 '));
    });
  });

  test('목표 거리를 채우면 한 번 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(1000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 301), 1005);
      sampleAt(const Duration(seconds: 401), 1300);
      async.elapse(const Duration(seconds: 3));
      expect(speaker.spoken.where((s) => s.startsWith('목표')), [
        '목표 1킬로미터를 채웠어요',
      ]);
    });
  });

  test('시간 목표를 채우면 한 번 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const TimeGoal(Duration(minutes: 30)));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(minutes: 30, seconds: 3), 3020);
      sampleAt(const Duration(minutes: 30, seconds: 8), 3030);
      expect(speaker.spoken.where((s) => s.startsWith('목표')), ['목표 30분을 채웠어요']);
    });
  });

  test('자동 일시정지·재개와 종료 예고를 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 11), 30);
      async.elapse(const Duration(seconds: 30));
      expect(speaker.spoken.last, '일시정지했어요');

      // 5분 멈춤 뒤 종료 예고(30초 전)는 한 번만.
      async.elapse(const Duration(minutes: 5, seconds: 5));
      expect(speaker.spoken.last, '움직이지 않으면 30초 뒤 러닝을 마쳐요');
      final count = speaker.spoken.length;
      async.elapse(const Duration(seconds: 10));
      expect(speaker.spoken.length, count);
    });
  });

  test('자동 재개를 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 11), 30);
      sampleAt(const Duration(seconds: 25), 30);
      expect(speaker.spoken.last, '일시정지했어요');
      // 10초 창 안에서 10m 이상 움직이면 재개한다.
      for (var i = 1; i <= 15; i++) {
        sampleAt(Duration(seconds: 25 + i), 30 + i * 4.0);
      }
      expect(speaker.spoken.where((s) => s == '다시 기록해요'), hasLength(1));
      expect(speaker.spoken.where((s) => s == '일시정지했어요'), hasLength(1));
    });
  });

  test('음성 안내를 끄면 읽지 않고 러닝은 계속된다', () {
    _run((async, container, speaker, profile, sampleAt) {
      profile.voice = false;
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 301), 1000);
      expect(speaker.spoken, isEmpty);
      expect(
        container.read(runControllerProvider).snapshot.distanceM,
        greaterThan(990),
      );
    });
  });

  test('읽기가 실패해도 러닝은 멈추지 않는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      speaker.fails = true;
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: const DistanceGoal(1000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 301), 1005);
      final view = container.read(runControllerProvider);
      expect(view.snapshot.distanceM, greaterThan(1000));
      expect(view.goalReached, isTrue);
      expect(view.lastError, isNull);
      late RunSummary summary;
      controller.end().then((v) => summary = v);
      async.flushMicrotasks();
      expect(summary.distanceM, greaterThan(1000));
    });
  });

  test('복원한 러닝은 지난 안내를 다시 읽지 않고 이후 구간부터 읽는다', () {
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
      (async, container, speaker, profile, sampleAt) {
        final controller = container.read(runControllerProvider.notifier);
        controller.restoreIfAny();
        async.flushMicrotasks();
        expect(speaker.spoken, isEmpty);

        controller.resume();
        async.flushMicrotasks();
        expect(speaker.spoken, isEmpty);

        // 복원 뒤 새로 닿은 4km 경계부터 읽는다.
        sampleAt(const Duration(seconds: 1), 3200);
        sampleAt(const Duration(seconds: 200), 4050);
        expect(speaker.spoken, hasLength(1));
        expect(speaker.spoken.single, startsWith('4킬로미터. 시간 '));
      },
    );
  });
}
