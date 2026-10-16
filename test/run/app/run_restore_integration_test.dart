import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/drift_run_repository.dart';
import 'package:runmagochi/run/data/location_source.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

final _t0 = DateTime(2026, 10, 17, 7);

/// 자오선을 따라 [meters] 만큼 북쪽으로 간 위도.
double _northOf(double meters) => 37.5 + meters / 6371000 * 180 / math.pi;

class _FakeLocationSource implements LocationSource {
  final controller = StreamController<LocationSample>.broadcast();

  @override
  Stream<LocationSample> watch() => controller.stream;
}

/// 실제 DB 위에서 러닝을 하다 앱이 죽고, 새 컨트롤러로 복원한다.
class _Harness {
  _Harness(this.async) {
    _open();
  }

  final FakeAsync async;
  final db = AppDatabase(NativeDatabase.memory());
  late final repository = DriftRunRepository(db);
  late _FakeLocationSource location;
  late ProviderContainer container;
  double _meters = 0;

  DateTime clock() => _t0.add(async.elapsed);

  void _open() {
    location = _FakeLocationSource();
    container = ProviderContainer(
      overrides: [
        runRepositoryProvider.overrideWithValue(repository),
        locationSourceProvider.overrideWithValue(location),
        clockProvider.overrideWithValue(clock),
      ],
    );
  }

  RunSnapshot get snapshot => container.read(runControllerProvider).snapshot;

  /// 1초마다 3m 씩 [count] 번 점을 보낸다. geolocator 처럼 UTC 이고 시계보다
  /// 300ms 늦은 시각이다.
  void step(int count) {
    for (var i = 0; i < count; i++) {
      async.elapse(const Duration(seconds: 1));
      _meters += 3;
      location.controller.add(
        LocationSample(
          time: clock().subtract(const Duration(milliseconds: 300)).toUtc(),
          latitude: _northOf(_meters),
          longitude: 127.0,
          accuracy: 5,
        ),
      );
      async.flushMicrotasks();
    }
  }

  /// 일시정지 동안 움직인 거리. 기록에 들어가면 안 된다.
  void moveWhilePaused(double meters) => _meters += meters;

  /// 컨테이너를 버리고 새로 만든다. 메모리의 버퍼는 사라지고 DB 만 남는다.
  void crash() {
    container.dispose();
    async.flushMicrotasks();
    _open();
  }

  void close() {
    container.dispose();
    async.flushMicrotasks();
    db.close();
    async.flushMicrotasks();
  }
}

void main() {
  /// 2구간(200초 → 30초 일시정지 → 250초)을 달린다.
  void runTwoSegments(_Harness h) {
    final controller = h.container.read(runControllerProvider.notifier);
    controller.start();
    h.async.flushMicrotasks();
    h.step(200);
    controller.pause();
    h.async.elapse(const Duration(seconds: 30));
    controller.resume();
    h.moveWhilePaused(500);
    h.step(250);
  }

  bool restore(_Harness h) {
    bool? restored;
    h.container
        .read(runControllerProvider.notifier)
        .restoreIfAny()
        .then((r) => restored = r);
    h.async.flushMicrotasks();
    return restored!;
  }

  /// 복원 뒤 재개하면 새 점을 받는다. 첫 점은 새 구간의 시작이라 거리 0.
  void expectResumeAcceptsPoints(_Harness h) {
    final restored = h.snapshot;
    h.container.read(runControllerProvider.notifier).resume();
    h.step(5);
    expect(h.snapshot.state, RunState.recording);
    expect(h.snapshot.distanceM, closeTo(restored.distanceM + 12, 0.1));
  }

  test('일시정지 중에 죽으면 거리·구간 기록·움직인 시간이 그대로 복원된다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      runTwoSegments(h);
      h.container.read(runControllerProvider.notifier).pause();
      async.flushMicrotasks();
      final before = h.snapshot;

      h.crash();
      expect(restore(h), isTrue);

      final after = h.snapshot;
      expect(after.state, RunState.paused);
      expect(after.distanceM, closeTo(before.distanceM, 1e-6));
      expect(after.movingTime, before.movingTime);
      expect(after.splits, hasLength(before.splits.length));
      expect(after.splits, isNotEmpty);
      for (var i = 0; i < after.splits.length; i++) {
        expect(after.splits[i].duration, before.splits[i].duration);
      }

      expectResumeAcceptsPoints(h);
      h.close();
    });
  });

  test('기록 중에 죽으면 마지막 10초 안의 점만 잃고 움직인 시간 차이는 10초 이하다', () {
    fakeAsync((async) {
      final h = _Harness(async);
      runTwoSegments(h);
      // 마지막 저장 뒤 몇 초 더 달린 상태에서 죽는다.
      h.step(7);
      final before = h.snapshot;
      expect(before.state, RunState.recording);

      h.crash();
      expect(restore(h), isTrue);

      final after = h.snapshot;
      expect(after.state, RunState.paused);
      final lostM = before.distanceM - after.distanceM;
      // 1초에 3m 씩이므로 10초면 30m.
      expect(lostM, inInclusiveRange(0, 30 + 0.1));
      final lostTime = before.movingTime - after.movingTime;
      expect(lostTime, greaterThanOrEqualTo(Duration.zero));
      expect(lostTime, lessThanOrEqualTo(const Duration(seconds: 10)));
      expect(
        after.splits.length,
        inInclusiveRange(before.splits.length - 1, before.splits.length),
      );
      for (var i = 0; i < after.splits.length; i++) {
        expect(after.splits[i].duration, before.splits[i].duration);
      }

      expectResumeAcceptsPoints(h);
      h.close();
    });
  });
}
