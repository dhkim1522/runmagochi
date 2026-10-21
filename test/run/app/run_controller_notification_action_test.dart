import 'dart:async';

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
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

import '../ui/fakes.dart' show FakeRunProgressNotifier, FakeSpeaker;

final _t0 = DateTime(2026, 10, 21, 7);

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
  @override
  Stream<LocationSample> watch() => const Stream.empty();
}

class _Lifecycle implements AppLifecycle {
  @override
  AppLifecycleState current = AppLifecycleState.resumed;
  @override
  Stream<AppLifecycleState> get changes => const Stream.empty();
}

class _Instant implements InstantNotifier {
  @override
  Future<void> showNow({required String title, required String body}) async {}
  @override
  Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {}
}

void _run(
  void Function(
    FakeAsync async,
    ProviderContainer container,
    StreamController<String> actions,
  )
  body,
) {
  fakeAsync((async) {
    final actions = StreamController<String>.broadcast();
    final container = ProviderContainer(
      overrides: [
        speakerProvider.overrideWithValue(FakeSpeaker()),
        runRepositoryProvider.overrideWithValue(_Repo()),
        profileRepositoryProvider.overrideWithValue(_Profile()),
        locationSourceProvider.overrideWithValue(_Location()),
        appLifecycleProvider.overrideWithValue(_Lifecycle()),
        clockProvider.overrideWithValue(() => _t0.add(async.elapsed)),
        instantNotifierProvider.overrideWithValue(_Instant()),
        runProgressNotifierProvider.overrideWithValue(
          FakeRunProgressNotifier(),
        ),
        runNotificationActionsProvider.overrideWithValue(actions.stream),
      ],
    );
    container.read(runControllerProvider.notifier);
    body(async, container, actions);
    container.dispose();
    actions.close();
    async.flushMicrotasks();
  });
}

RunState _state(ProviderContainer c) =>
    c.read(runControllerProvider).snapshot.state;

void _send(FakeAsync async, StreamController<String> a, String id) {
  a.add(id);
  async.flushMicrotasks();
}

void main() {
  test('기록 중 run_pause 는 일시정지, run_resume 은 재개한다', () {
    _run((async, container, actions) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      _send(async, actions, 'run_pause');
      expect(_state(container), RunState.paused);
      _send(async, actions, 'run_resume');
      expect(_state(container), RunState.recording);
    });
  });

  test('자동 일시정지 중 run_resume 은 재개, run_pause 는 사용자 일시정지', () {
    _run((async, container, actions) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10)); // 점이 없어 멈춤
      expect(_state(container), RunState.autoPaused);
      _send(async, actions, 'run_resume');
      expect(_state(container), RunState.recording);
      async.elapse(const Duration(seconds: 10));
      expect(_state(container), RunState.autoPaused);
      _send(async, actions, 'run_pause');
      expect(_state(container), RunState.paused);
    });
  });

  test('러닝이 없으면 버튼을 무시한다', () {
    _run((async, container, actions) {
      _send(async, actions, 'run_pause');
      _send(async, actions, 'run_resume');
      expect(_state(container), RunState.idle);
    });
  });

  test('상태에 맞지 않는 버튼과 모르는 id 는 오류 없이 무시한다', () {
    _run((async, container, actions) {
      container
          .read(runControllerProvider.notifier)
          .start(goal: DistanceGoal(5000));
      async.flushMicrotasks();
      _send(async, actions, 'run_resume'); // 기록 중에 재개
      expect(_state(container), RunState.recording);
      _send(async, actions, 'unknown');
      expect(_state(container), RunState.recording);
      _send(async, actions, 'run_pause');
      _send(async, actions, 'run_pause'); // 일시정지 중에 또 일시정지
      expect(_state(container), RunState.paused);
    });
  });
}
