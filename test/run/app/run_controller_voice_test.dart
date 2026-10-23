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
import 'package:runmagochi/run/domain/run_engine.dart';
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
}

void _run(
  void Function(
    FakeAsync async,
    ProviderContainer container,
    FakeSpeaker speaker,
    _Profile profile,
    void Function(Duration at, double meters, {bool jump}) sampleAt,
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

    /// 앞 점부터 5초마다 사이 점을 채워 [at] 에 [meters] 점을 보낸다. [jump] 면
    /// 사이를 채우지 않는다(점이 끊긴 사이).
    void sampleAt(Duration at, double meters, {bool jump = false}) {
      final from = lastMeters;
      if (from != null && !jump) {
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
      expect(speaker.spoken, [
        '러닝을 시작해요',
        startsWith('1킬로미터. 시간 '),
        '목표 1킬로미터를 채웠어요',
      ]);
    });
  });

  test('1km 경계에서 목표를 채우면 구간 안내 다음에 목표 안내를 끊김 없이 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      speaker.speakTime = const Duration(seconds: 2);
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(1000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 301), 1005);
      async.elapse(const Duration(seconds: 6));
      expect(speaker.spoken, [
        '러닝을 시작해요',
        startsWith('1킬로미터. 시간 '),
        '목표 1킬로미터를 채웠어요',
      ]);
      expect(speaker.cutOff, isEmpty);
    });
  });

  test('자동 일시정지·신호 끊김 안내 다음 종료 예고도 끊기지 않는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      speaker.speakTime = const Duration(seconds: 2);
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 11), 30);
      async.elapse(const Duration(minutes: 5, seconds: 30));
      // 점이 끊겼으므로 30초에 신호 끊김이 되고, 5분 뒤 신호 끊김 예고를 읽는다.
      expect(speaker.spoken, [
        '러닝을 시작해요',
        '일시정지했어요',
        '신호가 끊겼어요. 밖으로 나오면 다시 찾을게요',
        '신호가 오래 끊겨 30초 뒤 러닝을 마쳐요',
      ]);
      expect(speaker.cutOff, isEmpty);
    });
  });

  test('사용자 일시정지·재개는 말하지 않고, 길어지면 재개 안내로 종료 예고를 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 6), 15);
      controller.pause();
      async.flushMicrotasks();
      controller.resume();
      async.flushMicrotasks();
      expect(speaker.spoken, ['러닝을 시작해요']);

      controller.pause();
      async.elapse(const Duration(hours: 1, seconds: 5));
      expect(speaker.spoken, ['러닝을 시작해요', '일시정지가 길어 러닝을 마쳐요. 30초 안에 재개를 누르세요']);
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
      // 제자리 점이 5초마다 와서 신호는 살아 있다.
      sampleAt(const Duration(seconds: 305), 30);
      expect(speaker.spoken.last, '일시정지했어요');

      // 5분 멈춤 뒤 종료 예고(30초 전)는 한 번만.
      sampleAt(const Duration(seconds: 320), 30);
      expect(speaker.spoken.last, '움직이지 않으면 30초 뒤 러닝을 마쳐요');
      final count = speaker.spoken.length;
      async.elapse(const Duration(seconds: 10));
      expect(speaker.spoken.length, count);
    });
  });

  test('탈것 의심과 풀림을 읽는다 (결정 0033)', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 61), 180);
      // 초속 7m 로 1분.
      sampleAt(const Duration(seconds: 121), 600);
      expect(speaker.spoken, ['러닝을 시작해요', '너무 빨라서 이 구간은 기록에서 뺄게요']);
      // 내려서 초속 3m 로 달리면 풀린다.
      sampleAt(const Duration(seconds: 201), 840);
      expect(speaker.spoken, ['러닝을 시작해요', '너무 빨라서 이 구간은 기록에서 뺄게요', '다시 기록해요']);
    });
  });

  test('탈것 의심 안내는 다시 켜기가 60초에 한 번이다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      const vehicle = '너무 빨라서 이 구간은 기록에서 뺄게요';
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 61), 180);
      // 버스 40초 → 내려서 10초 → 다시 버스. 두 번째 의심은 첫 안내 60초 안이다.
      sampleAt(const Duration(seconds: 101), 460);
      sampleAt(const Duration(seconds: 111), 490);
      sampleAt(const Duration(seconds: 141), 700);
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.vehicle,
      );
      expect(speaker.spoken.where((l) => l == vehicle), hasLength(1));
      expect(speaker.spoken.where((l) => l == '다시 기록해요'), hasLength(1));
      // 첫 안내 60초가 지나도 의심 중이면 한 번 더 안내한다.
      sampleAt(const Duration(seconds: 161), 840);
      expect(speaker.spoken.where((l) => l == vehicle), hasLength(2));
    });
  });

  test('신호 끊김 안내는 60초에 한 번만 읽는다', () {
    _run((async, container, speaker, profile, sampleAt) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: const DistanceGoal(5000));
      async.flushMicrotasks();
      const lost = '신호가 끊겼어요. 밖으로 나오면 다시 찾을게요';
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 61), 180);
      // 터널 입구: 40초 끊김 → 5초 이어짐 → 40초 끊김.
      async.elapse(const Duration(seconds: 40));
      sampleAt(const Duration(seconds: 101), 300, jump: true);
      sampleAt(const Duration(seconds: 106), 315);
      async.elapse(const Duration(seconds: 40));
      expect(
        container.read(runControllerProvider).snapshot.state,
        RunState.signalLost,
      );
      expect(speaker.spoken.where((l) => l == lost), hasLength(1));
      expect(speaker.spoken.where((l) => l == '다시 기록해요'), hasLength(1));
      // 60초가 지난 뒤 다시 끊기면 읽는다.
      sampleAt(const Duration(seconds: 150), 400, jump: true);
      sampleAt(const Duration(seconds: 155), 415);
      async.elapse(const Duration(seconds: 40));
      expect(speaker.spoken.where((l) => l == lost), hasLength(2));
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
