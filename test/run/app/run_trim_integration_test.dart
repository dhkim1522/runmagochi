import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/profile/data/drift_profile_repository.dart';
import 'package:runmagochi/run/app/app_lifecycle.dart';
import 'package:runmagochi/run/app/providers.dart';
import '../ui/fakes.dart' show FakeRunProgressNotifier;
import 'package:runmagochi/run/app/run_editor.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/drift_run_repository.dart';
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

// 2026-10-17 은 토요일.
final _t0 = DateTime(2026, 10, 17, 7);

double _northOf(double meters) => 37.5 + meters / 6371000 * 180 / math.pi;

class _FakeLocationSource implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();

  @override
  Stream<LocationSample> watch() => controller.stream;
}

class _AlwaysResumed implements AppLifecycle {
  @override
  AppLifecycleState get current => AppLifecycleState.resumed;

  @override
  Stream<AppLifecycleState> get changes => const Stream.empty();
}

/// [failRevise] 면 runRevised 가 실패하는 성장 서비스.
class _FlakyGrowthService extends GrowthService {
  _FlakyGrowthService(super.runs, super.growth, super.clock);

  bool failRevise = false;

  @override
  Future<GrowthGain> runRevised(String runId, DateTime runStartedAt) {
    if (failRevise) return Future.error(Exception('재계산 실패'));
    return super.runRevised(runId, runStartedAt);
  }
}

/// 실제 DB 위에서 러닝을 끝내고 요약 화면처럼 끝부분을 잘라낸다.
/// 행 시각(updatedAt)도 가짜 시계를 따른다.
class _Harness {
  _Harness(this.async) {
    service = _FlakyGrowthService(runs, growth, clock);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        runRepositoryProvider.overrideWithValue(runs),
        growthRepositoryProvider.overrideWithValue(growth),
        profileRepositoryProvider.overrideWithValue(DriftProfileRepository(db)),
        runProgressNotifierProvider.overrideWithValue(
          FakeRunProgressNotifier(),
        ),
        locationSourceProvider.overrideWithValue(location),
        clockProvider.overrideWithValue(clock),
        appLifecycleProvider.overrideWithValue(_AlwaysResumed()),
        growthServiceProvider.overrideWithValue(service),
      ],
    );
  }

  final FakeAsync async;
  final db = AppDatabase(NativeDatabase.memory());
  late final runs = DriftRunRepository(db, now: clock);
  late final growth = DriftGrowthRepository(db, now: clock);
  late final _FlakyGrowthService service;
  final location = _FakeLocationSource();
  late final ProviderContainer container;
  double _meters = 0;

  DateTime clock() => _t0.add(async.elapsed);

  T wait<T>(Future<T> future) {
    late T value;
    Object? error;
    future.then<void>((v) => value = v, onError: (Object e) => error = e);
    async.flushMicrotasks();
    if (error != null) throw error!;
    return value;
  }

  /// 1초마다 3m 씩 [count] 번 점을 보낸다.
  void step(int count) {
    for (var i = 0; i < count; i++) {
      async.elapse(const Duration(seconds: 1));
      _meters += 3;
      location.controller.add(
        LocationSample(
          time: clock().toUtc(),
          latitude: _northOf(_meters),
          longitude: 127.0,
          accuracy: 5,
        ),
      );
      async.flushMicrotasks();
    }
  }

  /// 1200m 를 달리고 [idleAfter] 만큼 서 있다가 끝낸 뒤 sync 한다.
  (RunSummary, GrowthGain) runAndEnd({Duration idleAfter = Duration.zero}) {
    final controller = container.read(runControllerProvider.notifier);
    wait(controller.start(goal: DistanceGoal(3000)));
    step(400);
    async.elapse(idleAfter);
    final summary = wait(controller.end());
    final gain = wait(container.read(growthServiceProvider).sync());
    return (summary, gain);
  }

  void close() {
    container.dispose();
    async.flushMicrotasks();
    db.close();
    async.flushMicrotasks();
  }
}

void main() {
  test('잘라내면 저장된 기록·경험치가 새 거리로 바뀐다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      final (original, gain) = h.runAndEnd();
      final runId = h.container.read(runControllerProvider).lastRunId!;
      expect(original.distanceM, greaterThan(1000));
      expect(gain.distanceXp, 12);
      expect(gain.goalBonusXp, 0);

      // 250초 지점으로 자르면 약 750m 이고 1km 를 채운 구간이 없다.
      final newEnd = _t0.add(const Duration(seconds: 250));
      final (trimmed, revised) = h.wait(
        h.container.read(runEditorProvider).trimLastRun(newEnd, shown: gain),
      );

      expect(trimmed.endedAt, newEnd);
      expect(trimmed.distanceM, lessThan(1000));
      // 1km 를 못 채운 마지막 구간 하나만 남는다.
      expect(trimmed.splits.single.distanceM, lessThan(1000));

      final view = h.container.read(runControllerProvider);
      expect(view.lastSummary, same(trimmed));
      expect(view.lastRunId, runId);

      final detail = h.wait(h.runs.getRun(runId))!;
      expect(detail.run.distanceM, trimmed.distanceM);
      expect(detail.run.movingTime, trimmed.movingTime);
      expect(detail.splits.single.distanceM, trimmed.splits.single.distanceM);
      expect(detail.route.length, trimmed.points.length);
      expect(h.wait(h.runs.weeklyTotal(_t0)).$1, trimmed.distanceM);

      final newXp = distanceXp(trimmed.distanceM, trimmed.splits);
      expect(h.wait(h.growth.totalXp()), newXp);
      expect(revised, isNotNull);
      expect(revised!.distanceXp, newXp);
      expect(revised.goalBonusXp, 0);
      expect(revised.levelBefore, gain.levelBefore);
      expect(revised.levelAfter, levelFor(newXp).level);

      // 같은 끝 시각으로 다시 잘라도 그대로다.
      final (again, revisedAgain) = h.wait(
        h.container.read(runEditorProvider).trimLastRun(newEnd, shown: revised),
      );
      expect(again.distanceM, trimmed.distanceM);
      expect(revisedAgain!.distanceXp, newXp);
      expect(h.wait(h.growth.totalXp()), newXp);
      h.close();
    });
  });

  test('경험치 재계산이 실패하면 null 이고 다음 sync 가 경험치를 고친다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      final (_, gain) = h.runAndEnd();
      expect(gain.goalBonusXp, 0);

      async.elapse(const Duration(seconds: 5));
      h.service.failRevise = true;
      final (trimmed, revised) = h.wait(
        h.container
            .read(runEditorProvider)
            .trimLastRun(_t0.add(const Duration(seconds: 250)), shown: gain),
      );
      expect(revised, isNull);
      expect(h.wait(h.growth.totalXp()), 12); // 아직 예전 값.

      h.service.failRevise = false;
      async.elapse(const Duration(seconds: 5));
      final healed = h.wait(h.service.sync());
      final newXp = distanceXp(trimmed.distanceM, trimmed.splits);
      expect(healed.isEmpty, isTrue);
      expect(h.wait(h.growth.totalXp()), newXp);

      async.elapse(const Duration(seconds: 5));
      final rows = h.wait(h.growth.distanceXpUpdatedAts());
      expect(h.wait(h.service.sync()).isEmpty, isTrue);
      expect(h.wait(h.growth.distanceXpUpdatedAts()), rows);
      expect(h.wait(h.growth.totalXp()), newXp);
      h.close();
    });
  });

  test('보여 줄 성장이 없으면 다시 계산만 하고 null 을 돌려준다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      h.runAndEnd();
      final (trimmed, revised) = h.wait(
        h.container
            .read(runEditorProvider)
            .trimLastRun(_t0.add(const Duration(seconds: 250))),
      );
      expect(revised, isNull);
      expect(
        h.wait(h.growth.totalXp()),
        distanceXp(trimmed.distanceM, trimmed.splits),
      );
      h.close();
    });
  });

  test('끝낸 러닝이 없으면 StateError 이고 잘못된 끝 시각은 ArgumentError 다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      final editor = h.container.read(runEditorProvider);
      expect(() => h.wait(editor.trimLastRun(_t0)), throwsA(isA<StateError>()));
      final (original, _) = h.runAndEnd();
      expect(
        () => h.wait(
          editor.trimLastRun(original.endedAt.add(const Duration(minutes: 1))),
        ),
        throwsA(isA<ArgumentError>()),
      );
      // 저장된 기록은 그대로다.
      final runId = h.container.read(runControllerProvider).lastRunId!;
      expect(h.wait(h.runs.getRun(runId))!.run.distanceM, original.distanceM);
      h.close();
    });
  });
}
