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
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

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
  Future<double?> lastGoalM() async => null;
  @override
  Future<String> createActiveRun(
    DateTime startedAt, {
    required double goalM,
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
  int cancels = 0;
  bool fails = false;

  @override
  Future<void> show(RunProgressContent content) async {
    if (fails) throw StateError('알림 실패');
    shown.add(content);
  }

  @override
  Future<void> cancel() async {
    if (fails) throw StateError('알림 실패');
    cancels++;
  }
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
    final progress = _Progress()..fails = fails;
    final container = ProviderContainer(
      overrides: [
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
      container.read(runControllerProvider.notifier).start(goalM: 5000);
      async.flushMicrotasks();
      expect(progress.shown, hasLength(1));
      expect(progress.shown.single.title, '러닝 중 · 0.00km');
      expect(progress.shown.single.action, RunProgressAction.pause);
    });
  });

  test('틱마다 다시 띄우지 않고, 거리가 10m 단위로 바뀌면 3초 간격으로 갱신한다', () {
    _run((async, container, progress, sampleAt) {
      container.read(runControllerProvider.notifier).start(goalM: 5000);
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
      controller.start(goalM: 5000);
      async.flushMicrotasks();
      controller.pause();
      async.flushMicrotasks();
      expect(progress.shown.last.action, RunProgressAction.resume);
      expect(progress.shown.last.title, startsWith('일시정지 · 0.00km'));
      controller.resume();
      async.flushMicrotasks();
      expect(progress.shown.last.action, RunProgressAction.pause);
      expect(progress.shown, hasLength(3));
    });
  });

  test('끝내면 알림을 지운다', () {
    _run((async, container, progress, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goalM: 5000);
      async.flushMicrotasks();
      controller.end();
      async.flushMicrotasks();
      expect(progress.cancels, 1);
    });
  });

  test('알림이 실패해도 러닝은 계속된다', () {
    _run(fails: true, (async, container, progress, sampleAt) {
      final controller = container.read(runControllerProvider.notifier);
      controller.start(goalM: 5000);
      async.flushMicrotasks();
      sampleAt(const Duration(seconds: 1), 0);
      sampleAt(const Duration(seconds: 10), 30);
      controller.pause();
      controller.resume();
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).runId, 'run-1');
      controller.end();
      async.flushMicrotasks();
      expect(container.read(runControllerProvider).lastSummary, isNotNull);
    });
  });
}
