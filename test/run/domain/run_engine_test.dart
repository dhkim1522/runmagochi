import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/geo.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

const _lat0 = 37.5;
const _lng0 = 127.0;

/// 자오선을 따라 [meters] 만큼 북쪽으로 간 위도.
double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

void main() {
  late DateTime now;
  late RunEngine engine;
  final t0 = DateTime(2026, 10, 17, 7);

  LocationSample at(int sec, double lat, double lng, {double accuracy = 5}) =>
      LocationSample(
        time: t0.add(Duration(seconds: sec)),
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
      );

  setUp(() {
    now = t0;
    engine = RunEngine(clock: () => now);
  });

  test('start 후 2점(동쪽 0.0001도 간격) → distanceM ≈ haversine 값', () {
    engine.start();
    expect(engine.addSample(at(0, _lat0, _lng0)), isTrue);
    expect(engine.addSample(at(2, _lat0, _lng0 + 0.0001)), isTrue);
    expect(
      engine.snapshot.distanceM,
      closeTo(haversineMeters(_lat0, _lng0, _lat0, _lng0 + 0.0001), 1e-9),
    );
  });

  test('정확도 25m 점은 버린다', () {
    engine.start();
    engine.addSample(at(0, _lat0, _lng0));
    expect(
      engine.addSample(at(2, _lat0, _lng0 + 0.0001, accuracy: 25)),
      isFalse,
    );
    expect(engine.snapshot.distanceM, 0);
    expect(engine.acceptedPoints, hasLength(1));
  });

  test('1초 만에 10m 이동한 점은 버린다', () {
    engine.start();
    engine.addSample(at(0, _lat0, _lng0));
    expect(engine.addSample(at(1, _northOf(10), _lng0)), isFalse);
    expect(engine.snapshot.distanceM, 0);
  });

  test('시각이 역행한 점은 버린다', () {
    engine.start();
    engine.addSample(at(10, _lat0, _lng0));
    expect(engine.addSample(at(9, _northOf(3), _lng0)), isFalse);
    expect(engine.addSample(at(10, _northOf(3), _lng0)), isFalse);
    expect(engine.snapshot.distanceM, 0);
    expect(engine.acceptedPoints, hasLength(1));
  });

  test('일시정지 중 점은 무시', () {
    engine.start();
    engine.addSample(at(0, _lat0, _lng0));
    engine.pause();
    expect(engine.addSample(at(2, _northOf(5), _lng0)), isFalse);
    expect(engine.snapshot.distanceM, 0);
    expect(engine.acceptedPoints, hasLength(1));
  });

  test('재개 후 첫 점은 거리를 더하지 않는다', () {
    engine.start();
    engine.addSample(at(0, _lat0, _lng0));
    engine.addSample(at(2, _northOf(5), _lng0)); // 점 A
    final untilA = engine.snapshot.distanceM;
    engine.pause();
    engine.resume();
    expect(engine.addSample(at(60, _northOf(505), _lng0)), isTrue); // 점 B
    expect(engine.snapshot.distanceM, untilA);
    engine.addSample(at(62, _northOf(510), _lng0));
    expect(engine.snapshot.distanceM, closeTo(untilA + 5, 1e-6));
  });

  test('점 없이 60초 경과', () {
    engine.start();
    now = now.add(const Duration(seconds: 60));
    expect(engine.snapshot.movingTime, const Duration(seconds: 60));
    expect(engine.snapshot.avgPaceSecPerKm, isNull);
  });

  test('일시정지 시간은 movingTime에서 빠진다', () {
    engine.start();
    now = now.add(const Duration(seconds: 30));
    engine.pause();
    now = now.add(const Duration(seconds: 20));
    engine.resume();
    now = now.add(const Duration(seconds: 10));
    expect(engine.snapshot.movingTime, const Duration(seconds: 40));
  });

  test('평균 페이스 = movingTime ÷ km', () {
    engine.start();
    for (var i = 0; i <= 360; i++) {
      now = t0.add(Duration(seconds: i));
      engine.addSample(at(i, _northOf(1000 * i / 360), _lng0));
    }
    expect(engine.snapshot.distanceM, closeTo(1000, 1e-6));
    expect(engine.snapshot.movingTime, const Duration(seconds: 360));
    expect(engine.snapshot.avgPaceSecPerKm, closeTo(360.0, 1e-6));
  });

  test('현재 페이스는 최근 30초 점만 쓴다', () {
    engine.start();
    // 60초 동안 초속 2m (페이스 500), 이어서 30초 동안 초속 4m (페이스 250).
    for (var i = 0; i <= 90; i++) {
      final m = i <= 60 ? 2.0 * i : 120 + 4.0 * (i - 60);
      now = t0.add(Duration(seconds: i));
      engine.addSample(at(i, _northOf(m), _lng0));
    }
    expect(engine.snapshot.currentPaceSecPerKm, closeTo(250, 1e-6));
    expect(engine.snapshot.avgPaceSecPerKm, closeTo(375, 1e-6));
  });

  test('상태 이벤트 순서', () async {
    final events = expectLater(
      engine.events,
      emitsInOrder([
        _stateChanged(RunState.idle, RunState.recording),
        _stateChanged(RunState.recording, RunState.paused),
        _stateChanged(RunState.paused, RunState.recording),
      ]),
    );
    engine.start();
    engine.pause();
    engine.resume();
    expect(engine.snapshot.state, RunState.recording);
    await events;
  });

  test('idle에서 pause는 StateError', () {
    expect(engine.pause, throwsStateError);
    expect(engine.resume, throwsStateError);
    engine.start();
    expect(engine.start, throwsStateError);
    expect(engine.resume, throwsStateError);
  });

  test('restoredPoints로 만든 엔진은 paused이고 거리가 같다', () {
    engine.start();
    for (var i = 0; i <= 20; i++) {
      engine.addSample(at(i, _northOf(3.0 * i), _lng0));
    }
    final restored = RunEngine(
      clock: () => now,
      startedAt: t0,
      restoredPoints: engine.acceptedPoints,
    );
    expect(restored.snapshot.state, RunState.paused);
    expect(restored.snapshot.distanceM, engine.snapshot.distanceM);
    expect(restored.snapshot.movingTime, const Duration(seconds: 20));
    expect(restored.acceptedPoints, hasLength(21));
  });
}

Matcher _stateChanged(RunState from, RunState to) => isA<StateChanged>()
    .having((e) => e.from, 'from', from)
    .having((e) => e.to, 'to', to);
