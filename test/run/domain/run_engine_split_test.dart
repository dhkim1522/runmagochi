import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

const _lat0 = 37.5;
const _lng0 = 127.0;

/// 자오선을 따라 [meters] 만큼 북쪽으로 간 위도.
double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

void main() {
  late DateTime now;
  late RunEngine engine;
  final t0 = DateTime(2026, 10, 16, 19);

  LocationSample at(int sec, double meters) => LocationSample(
    time: t0.add(Duration(seconds: sec)),
    latitude: _northOf(meters),
    longitude: _lng0,
    accuracy: 5,
  );

  /// [fromSec] 부터 초속 [mps] 로 [seconds] 초 동안 1초마다 점을 넣는다.
  void runAt(int fromSec, double fromM, int seconds, double mps) {
    for (var i = 0; i <= seconds; i++) {
      now = t0.add(Duration(seconds: fromSec + i));
      engine.addSample(at(fromSec + i, fromM + mps * i));
    }
  }

  setUp(() {
    now = t0;
    engine = RunEngine(clock: () => now);
  });

  test('1km 경계 보간', () {
    engine.start();
    engine.addSample(at(0, 0));
    engine.addSample(at(300, 900));
    engine.addSample(at(400, 1100));
    final split = engine.snapshot.splits.single;
    expect(split.index, 1);
    expect(split.distanceM, 1000);
    expect(split.duration, const Duration(seconds: 350));
  });

  test('2.5km 러닝은 구간 3개, 마지막 500m', () {
    engine.start();
    runAt(0, 0, 1000, 2.5); // 400초/km
    final summary = engine.end();
    expect(summary.splits.map((s) => s.index), [1, 2, 3]);
    expect(summary.splits[0].distanceM, 1000);
    expect(summary.splits[1].distanceM, 1000);
    expect(summary.splits[2].distanceM, closeTo(500, 1e-6));
    for (final s in summary.splits) {
      expect(s.paceSecPerKm, closeTo(400, 1e-3));
    }
    expect(summary.splits[2].duration, const Duration(seconds: 200));
  });

  test('SplitCompleted 이벤트가 경계마다 1번', () async {
    final splits = <int>[];
    final sub = engine.events.listen((e) {
      if (e is SplitCompleted) splits.add(e.split.index);
    });
    engine.start();
    runAt(0, 0, 1000, 2.5);
    await Future<void>.delayed(Duration.zero);
    expect(splits, [1, 2]);
    await sub.cancel();
  });

  test('snapshot.splits 는 완료된 1km 구간만 담는다', () {
    engine.start();
    runAt(0, 0, 600, 2.5); // 1500m
    expect(engine.snapshot.splits, hasLength(1));
    expect(engine.snapshot.splits.single.distanceM, 1000);
  });

  test('구간 사이 거리·시간은 구간 기록에 넣지 않는다', () {
    engine.start();
    runAt(0, 0, 200, 2.5); // 500m, 200초
    engine.pause();
    now = t0.add(const Duration(seconds: 1000));
    engine.resume();
    // 3km 떨어진 곳에서 재개. 500m 더 달리면 1km.
    runAt(1000, 3000, 240, 2.5); // 600m, 240초
    final split = engine.snapshot.splits.single;
    expect(split.duration, const Duration(seconds: 400));
    expect(engine.snapshot.distanceM, closeTo(1100, 1e-6));
  });

  test('거리 0으로 종료하면 splits 빈 목록, avgPace null', () {
    engine.start();
    now = now.add(const Duration(seconds: 30));
    final summary = engine.end();
    expect(summary.splits, isEmpty);
    expect(summary.avgPaceSecPerKm, isNull);
    expect(summary.distanceM, 0);
    expect(summary.points, isEmpty);
  });

  test('end 는 요약을 만들고 RunEnded 뒤 ended 로 바꾸고 스트림을 닫는다', () async {
    final events = expectLater(
      engine.events,
      emitsInOrder([
        isA<StateChanged>(),
        isA<SplitCompleted>(),
        isA<StateChanged>().having((e) => e.to, 'to', RunState.paused),
        isA<RunEnded>(),
        isA<StateChanged>()
            .having((e) => e.from, 'from', RunState.paused)
            .having((e) => e.to, 'to', RunState.ended),
        emitsDone,
      ]),
    );
    engine.start();
    runAt(0, 0, 600, 2.5); // 1500m, 600초
    engine.pause();
    now = now.add(const Duration(seconds: 100));
    final summary = engine.end();

    expect(engine.snapshot.state, RunState.ended);
    expect(summary.startedAt, t0);
    expect(summary.endedAt, t0.add(const Duration(seconds: 700)));
    expect(summary.distanceM, closeTo(1500, 1e-6));
    expect(summary.movingTime, const Duration(seconds: 600));
    expect(summary.avgPaceSecPerKm, closeTo(400, 1e-3));
    expect(summary.calories, closeTo(estimateCalories(1500), 1e-6));
    expect(summary.name, '금요일 저녁 러닝');
    expect(summary.splits.map((s) => s.distanceM), [1000, closeTo(500, 1e-6)]);
    expect(summary.points, hasLength(601));
    expect(engine.end, throwsStateError);
    await events;
  });

  test('end 는 기록 중에도 되고, 점을 구간 순서대로 펼친다', () {
    engine.start();
    runAt(0, 0, 10, 2);
    engine.pause();
    now = t0.add(const Duration(seconds: 100));
    engine.resume();
    runAt(100, 500, 5, 2);
    final summary = engine.end();
    expect(engine.snapshot.state, RunState.ended);
    expect(summary.points, [...engine.segments[0], ...engine.segments[1]]);
    expect(summary.splits.single.duration, const Duration(seconds: 15));
  });

  test('남은 거리가 1m 미만이면 마지막 구간을 넣지 않는다', () {
    engine.start();
    engine.addSample(at(0, 0));
    engine.addSample(at(400, 1000.0004));
    final summary = engine.end();
    expect(summary.distanceM, closeTo(1000.0004, 1e-6));
    expect(summary.splits, hasLength(1));
    expect(summary.splits.single.distanceM, 1000);
  });

  test('end 는 clock() 을 한 번 읽어 endedAt·movingTime 에 같이 쓴다', () {
    // 읽을 때마다 1초씩 가는 시계.
    var reads = 0;
    final ticking = RunEngine(clock: () => t0.add(Duration(seconds: reads++)));
    ticking.start();
    final startedAt = t0;
    final summary = ticking.end();
    expect(summary.startedAt, startedAt);
    expect(summary.movingTime, summary.endedAt.difference(startedAt));
  });

  test('idle 에서 end 는 StateError', () {
    expect(engine.end, throwsStateError);
  });

  test('복원한 엔진의 구간은 실시간 기록과 같고 SplitCompleted 를 내지 않는다', () async {
    engine.start();
    runAt(0, 0, 300, 2.5); // 750m
    engine.pause();
    now = t0.add(const Duration(seconds: 500));
    engine.resume();
    runAt(500, 2000, 500, 3); // 1500m
    final live = engine.snapshot.splits;
    expect(live, hasLength(2));

    final restored = RunEngine(
      clock: () => now,
      startedAt: t0,
      restoredSegments: engine.segments,
    );
    var emitted = 0;
    final sub = restored.events.listen((e) {
      if (e is SplitCompleted) emitted++;
    });
    expect(_describe(restored.snapshot.splits), _describe(live));

    // 복원 뒤 이어 달려도 같은 경로로 다음 경계를 찾는다.
    now = t0.add(const Duration(seconds: 1100));
    restored.resume();
    for (var i = 0; i <= 400; i++) {
      now = t0.add(Duration(seconds: 1100 + i));
      restored.addSample(at(1100 + i, 4000 + 2.5 * i)); // 1000m 더
    }
    await Future<void>.delayed(Duration.zero);
    expect(restored.snapshot.splits, hasLength(3));
    expect(emitted, 1);
    await sub.cancel();
  });
}

List<(int, double, Duration)> _describe(List<Split> splits) => [
  for (final s in splits)
    (s.index, (s.distanceM * 1e6).roundToDouble() / 1e6, s.duration),
];
