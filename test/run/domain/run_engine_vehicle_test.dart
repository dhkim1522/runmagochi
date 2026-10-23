import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/geo.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

// 탈것 의심·신호 끊김 (결정 0033).

const _lat0 = 37.5;
const _lng0 = 127.0;

double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

double _dist(double a, double b) =>
    haversineMeters(_northOf(a), _lng0, _northOf(b), _lng0);

void main() {
  final t0 = DateTime(2026, 10, 23, 7);
  late DateTime now;
  late RunEngine engine;

  /// 지금 위치(북쪽 m).
  var pos = 0.0;

  DateTime sec(int s, [int ms = 0]) =>
      t0.add(Duration(seconds: s, milliseconds: ms));

  LocationSample north(int s, double meters, {double accuracy = 5}) =>
      LocationSample(
        time: sec(s),
        latitude: _northOf(meters),
        longitude: _lng0,
        accuracy: accuracy,
      );

  /// [from] 초부터 [until] 초까지(포함) 매초 초속 [speed] 로 움직인 점을 넣고
  /// 매초 자동 일시정지·신호 끊김을 판정한다. [from] 초 점은 지금 위치에서
  /// [speed] 만큼 간 곳이다.
  void move(int from, int until, double speed) {
    for (var s = from; s <= until; s++) {
      now = sec(s);
      pos += speed;
      engine.addSample(north(s, pos));
      engine.autoPauseIfStill(now);
      engine.signalLostIfSilent(now);
    }
  }

  /// [from] 초부터 [until] 초까지 점 없이 매초 판정한다.
  void silent(int from, int until) {
    for (var s = from; s <= until; s++) {
      now = sec(s);
      engine.autoPauseIfStill(now);
      engine.signalLostIfSilent(now);
    }
  }

  /// [a]m 부터 [b]m 까지 [step]m 간격 점 사이 거리의 합.
  double along(double a, double b, double step) {
    var total = 0.0;
    for (var m = a; m < b - 1e-9; m += step) {
      total += _dist(m, m + step);
    }
    return total;
  }

  setUp(() {
    now = t0;
    pos = 0;
    engine = RunEngine(clock: () => now)..start();
    // 0초 점은 0m.
    engine.addSample(north(0, 0));
  });

  group('탈것 의심', () {
    test('시속 18km(초속 5m)로 이어 달리면 모두 기록한다', () {
      move(1, 59, 3);
      move(60, 299, 5);
      expect(engine.state, RunState.recording);
      expect(engine.heldCount, 0);
      expect(engine.vehicleTime(now), Duration.zero);
      expect(
        engine.snapshot.distanceM,
        closeTo(along(0, 177, 3) + along(177, 1377, 5), 1e-6),
      );
      expect(engine.segments, hasLength(1));
    });

    test('시속 24km 40초는 뺀 구간이 되고 마지막 정상 점부터 의심한다', () async {
      final events = <RunEvent>[];
      engine.events.listen(events.add);
      move(1, 59, 3); // 59초 점 177m
      // 초속 6.67m 점은 튀는 값 거름(초속 7m) 안이지만 받아들이기를 미룬다.
      move(60, 84, 6.67);
      expect(engine.state, RunState.recording);
      expect(engine.heldCount, 25);
      expect(engine.snapshot.distanceM, closeTo(along(0, 177, 3), 1e-6));
      // 85초에 최근 30초(55~85초) 평균이 시속 22km 를 넘는다.
      move(85, 85, 6.67);
      expect(engine.state, RunState.vehicle);
      expect(engine.heldCount, 0);
      expect(engine.stateSince, sec(59));
      expect(engine.pausedAt, sec(59));
      expect(engine.firstVehicleAt, sec(59));
      expect(engine.snapshot.movingTime, const Duration(seconds: 59));
      move(86, 99, 6.67);
      expect(engine.state, RunState.vehicle);
      expect(engine.snapshot.distanceM, closeTo(along(0, 177, 3), 1e-6));

      // 내려서 다시 달리면 평균이 내려와 104초 점부터 새 구간으로 기록한다.
      move(100, 103, 3);
      expect(engine.state, RunState.vehicle);
      move(104, 104, 3);
      expect(engine.state, RunState.recording);
      final resumedAt = pos;
      expect(engine.recordingSince, sec(104));
      expect(engine.vehicleTime(now), const Duration(seconds: 45));
      move(105, 160, 3);
      expect(engine.state, RunState.recording);
      expect(engine.segments, hasLength(2));
      expect(engine.segments[1].first.time, sec(104));
      expect(
        engine.snapshot.distanceM,
        closeTo(along(0, 177, 3) + along(resumedAt, pos, 3), 1e-6),
      );
      expect(
        engine.snapshot.movingTime,
        const Duration(seconds: 59 + 160 - 104),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        events.whereType<StateChanged>().map((e) => (e.from, e.to)),
        containsAllInOrder([
          (RunState.recording, RunState.vehicle),
          (RunState.vehicle, RunState.recording),
        ]),
      );
    });

    test('시속 30km 는 튀는 값으로 버리고 30초 평균으로 의심한다', () {
      move(1, 59, 3);
      move(60, 120, 8.33);
      expect(engine.state, RunState.vehicle);
      expect(engine.firstVehicleAt, sec(59));
      expect(engine.snapshot.distanceM, closeTo(along(0, 177, 3), 1e-6));
    });

    test('의심 시간은 구간마다 더하고 첫 의심 구간의 정상 점을 기억한다', () {
      move(1, 59, 3);
      move(60, 99, 7);
      move(100, 140, 3);
      expect(engine.state, RunState.recording);
      final first = engine.vehicleTime(now);
      // 59초(마지막 정상 점)부터 평균이 내려온 106초 점까지.
      expect(first, const Duration(seconds: 106 - 59));
      expect(engine.recordingSince, sec(106));
      move(141, 200, 7);
      expect(engine.state, RunState.vehicle);
      expect(engine.firstVehicleAt, sec(59));
      expect(
        engine.vehicleTime(now),
        first + now.difference(engine.stateSince!),
      );
    });

    test('제자리 흔들림(정확도 15m, 4~8m)은 의심하지 않는다', () {
      move(1, 59, 3);
      silent(60, 70);
      expect(engine.state, RunState.autoPaused);
      const offsets = <double>[6, 0, 7, 2, 8, 3, -1, 5, 0];
      for (var s = 71; s <= 200; s++) {
        now = sec(s);
        engine.addSample(
          north(s, pos + offsets[s % offsets.length], accuracy: 15),
        );
        engine.autoPauseIfStill(now);
        engine.signalLostIfSilent(now);
      }
      expect(engine.state, RunState.autoPaused);
      expect(engine.vehicleTime(now), Duration.zero);
    });

    test('튀는 점 하나는 다음 느린 점과 함께 받아들이거나 거른다', () {
      move(1, 10, 3); // 30m
      now = sec(11);
      // 직전 받아들인 점에서 초속 8m: 미룬다.
      expect(engine.addSample(north(11, 38)), isFalse);
      expect(engine.heldCount, 1);
      now = sec(12);
      // 30m 에서 2초에 6m: 미룬 점(튀는 값 거름에 걸림)을 거르고 받아들인다.
      expect(engine.addSample(north(12, 36)), isTrue);
      expect(engine.lastAppended.map((p) => p.time), [sec(12)]);
      expect(engine.heldCount, 0);
      expect(engine.snapshot.distanceM, closeTo(along(0, 36, 3), 1e-6));
    });

    test('잠깐 빨라진 점은 느려지면 함께 받아들인다', () {
      move(1, 10, 3); // 30m
      move(11, 15, 6.5); // 62.5m, 미룬다
      expect(engine.heldCount, 5);
      expect(engine.snapshot.distanceM, closeTo(along(0, 30, 3), 1e-6));
      move(16, 16, 3);
      expect(engine.heldCount, 0);
      expect(engine.lastAppended, hasLength(6));
      expect(engine.snapshot.distanceM, closeTo(_dist(0, 65.5), 1e-6));
    });

    test('미룬 점이 오는 동안은 자동 일시정지하지 않는다', () {
      move(1, 10, 3);
      move(11, 25, 6.67);
      expect(engine.state, RunState.recording);
      // 마지막 미룬 점(25초) 뒤 10초에 자동 일시정지하고 미룬 점은 버린다.
      silent(26, 34);
      expect(engine.state, RunState.recording);
      silent(35, 35);
      expect(engine.state, RunState.autoPaused);
      expect(engine.pausedAt, sec(10));
      expect(engine.heldCount, 0);
    });

    test('탈것 의심 중에는 자동 일시정지하지 않는다', () {
      move(1, 59, 3);
      move(60, 120, 7);
      expect(engine.state, RunState.vehicle);
      expect(engine.autoPauseIfStill(sec(200)), isFalse);
      expect(engine.state, RunState.vehicle);
    });

    test('사용자 일시정지는 의심을 멈추고, 재개하면 평균을 새로 잰다', () {
      move(1, 59, 3);
      move(60, 100, 7);
      expect(engine.state, RunState.vehicle);
      now = sec(110);
      engine.pause();
      expect(engine.state, RunState.paused);
      expect(engine.pausedAt, sec(59));
      final total = engine.vehicleTime(now);
      expect(total, const Duration(seconds: 110 - 59));
      now = sec(200);
      expect(engine.vehicleTime(now), total);
      engine.resume();
      // 재개 뒤 첫 점은 새 구간이고 30초 창이 찰 때까지는 의심하지 않는다.
      pos += 1000;
      move(201, 229, 7);
      expect(engine.state, RunState.recording);
      move(230, 235, 7);
      expect(engine.state, RunState.vehicle);
      expect(engine.firstVehicleAt, sec(59));
    });

    test('탈것 의심 중 재개를 누르면 기록 중이 된다', () {
      move(1, 59, 3);
      move(60, 100, 7);
      now = sec(101);
      engine.resume();
      expect(engine.state, RunState.recording);
      expect(engine.vehicleTime(now), const Duration(seconds: 101 - 59));
    });

    test('뺀 구간은 구간으로 나뉘어 복원해도 거리·움직인 시간이 같다', () {
      move(1, 59, 3);
      move(60, 99, 6.67);
      move(100, 160, 3);
      final restored = RunEngine(
        clock: () => now,
        startedAt: t0,
        restoredSegments: engine.segments,
      );
      expect(restored.snapshot.distanceM, engine.snapshot.distanceM);
      expect(restored.snapshot.movingTime, engine.snapshot.movingTime);
    });

    test('미루는 동안 움직인 시간은 멈추고, 받아들이면 그 시간을 더한다', () {
      move(1, 10, 3);
      move(11, 15, 6.5);
      expect(engine.heldCount, 5);
      expect(engine.snapshot.movingTime, const Duration(seconds: 10));
      now = sec(15, 500);
      expect(engine.snapshot.movingTime, const Duration(seconds: 10));
      move(16, 16, 3);
      expect(engine.heldCount, 0);
      expect(engine.snapshot.movingTime, const Duration(seconds: 16));
    });

    test('탈것 의심이 되어도 움직인 시간은 뒤로 뛰지 않는다', () {
      move(1, 59, 3);
      var last = engine.snapshot.movingTime;
      for (var s = 60; s <= 100; s++) {
        move(s, s, 6.67);
        final t = engine.snapshot.movingTime;
        expect(t, greaterThanOrEqualTo(last), reason: '$s초');
        expect(t, const Duration(seconds: 59), reason: '$s초');
        last = t;
      }
      expect(engine.state, RunState.vehicle);
    });

    test('미루는 중 사용자 일시정지·종료는 미룬 점과 그 시간을 함께 버린다', () {
      move(1, 10, 3);
      move(11, 15, 6.67);
      now = sec(16);
      engine.pause();
      expect(engine.pausedAt, sec(16));
      expect(engine.snapshot.movingTime, const Duration(seconds: 10));
      expect(engine.segments.single, hasLength(11));

      now = sec(30);
      engine.resume();
      pos += 100;
      move(31, 40, 3);
      move(41, 45, 6.67);
      now = sec(46);
      final summary = engine.end();
      expect(summary.movingTime, const Duration(seconds: 10 + 40 - 30));
    });

    test('끝내면 미룬 점은 넣지 않는다', () {
      move(1, 10, 3);
      move(11, 15, 6.67);
      final summary = engine.end();
      expect(summary.points, hasLength(11));
    });
  });

  group('최소 이동 3m (거리 거름은 엔진이 한다)', () {
    test('3m 안의 점은 거리에 넣지 않지만 신호로 센다', () {
      move(1, 59, 3);
      for (var s = 60; s <= 400; s++) {
        now = sec(s);
        expect(engine.addSample(north(s, pos + (s.isEven ? 1 : 0))), isFalse);
        engine.autoPauseIfStill(now);
        engine.signalLostIfSilent(now);
        expect(engine.state, isNot(RunState.signalLost), reason: '$s초');
      }
      expect(engine.state, RunState.autoPaused);
      expect(engine.segments.single, hasLength(60));
      expect(engine.snapshot.distanceM, closeTo(along(0, 177, 3), 1e-6));
    });

    test('기록 중 2m 씩 오는 점은 3m 를 넘을 때 받아들여 거리는 그대로 쌓인다', () {
      move(1, 60, 2);
      expect(engine.state, RunState.recording);
      expect(engine.segments.single, hasLength(31));
      expect(engine.snapshot.distanceM, closeTo(_dist(0, 120), 1e-6));
    });
  });

  group('신호 끊김', () {
    test('점이 30초 없으면 10초에 자동 일시정지한 뒤 30초에 신호 끊김이 된다', () {
      // 초속 3m 라 5m 넘게 움직인 마지막 점은 58초(174m), 마지막 점은 59초.
      move(1, 59, 3);
      silent(60, 67);
      expect(engine.state, RunState.recording);
      silent(68, 68);
      expect(engine.state, RunState.autoPaused);
      silent(69, 88);
      expect(engine.state, RunState.autoPaused);
      silent(89, 89);
      expect(engine.state, RunState.signalLost);
      // 끊김은 마지막 점부터, 기록이 멈춘 시각은 처음 멈춘 58초 그대로다.
      expect(engine.stateSince, sec(59));
      expect(engine.pausedAt, sec(58));
      expect(engine.snapshot.movingTime, const Duration(seconds: 58));
    });

    test('점이 다시 오면 풀리고 끊긴 사이 거리는 더하지 않는다', () {
      move(1, 59, 3);
      silent(60, 119);
      expect(engine.state, RunState.signalLost);
      // 터널을 지나 300m 떨어진 곳에서 점이 온다.
      pos += 300;
      now = sec(120);
      expect(engine.addSample(north(120, pos)), isTrue);
      expect(engine.state, RunState.recording);
      expect(engine.recordingSince, sec(120));
      final resumedAt = pos;
      move(121, 150, 3);
      expect(engine.segments, hasLength(2));
      expect(
        engine.snapshot.distanceM,
        closeTo(along(0, 177, 3) + along(resumedAt, pos, 3), 1e-6),
      );
      expect(
        engine.snapshot.movingTime,
        const Duration(seconds: 58 + 150 - 120),
      );
    });

    test('정확도 거름에 걸린 점은 신호로 보지 않는다', () {
      move(1, 59, 3);
      for (var s = 60; s <= 90; s++) {
        now = sec(s);
        engine.addSample(north(s, pos, accuracy: 60));
        engine.autoPauseIfStill(now);
        engine.signalLostIfSilent(now);
      }
      expect(engine.state, RunState.signalLost);
      now = sec(91);
      expect(engine.addSample(north(91, pos + 500, accuracy: 80)), isFalse);
      expect(engine.state, RunState.signalLost);
    });

    test('멈춰서 제자리 점이 오면 자동 일시정지를 유지한다', () {
      move(1, 59, 3);
      for (var s = 60; s <= 400; s++) {
        now = sec(s);
        if (s % 20 == 0) engine.addSample(north(s, pos));
        engine.autoPauseIfStill(now);
        engine.signalLostIfSilent(now);
      }
      expect(engine.state, RunState.autoPaused);
    });

    test('탈것 의심 중 점이 끊기면 신호 끊김이 되고 의심 시간은 마지막 점까지다', () {
      move(1, 59, 3);
      move(60, 100, 7);
      expect(engine.state, RunState.vehicle);
      silent(101, 130);
      expect(engine.state, RunState.signalLost);
      expect(engine.stateSince, sec(100));
      expect(engine.pausedAt, sec(59));
      expect(engine.vehicleTime(now), const Duration(seconds: 100 - 59));
      // 점이 오면 평균을 새로 재므로 바로 의심하지 않는다.
      pos += 2000;
      move(131, 140, 3);
      expect(engine.state, RunState.recording);
    });

    test('사용자 일시정지 중에는 신호 끊김이 되지 않고, 신호 끊김에서 일시정지할 수 있다', () {
      move(1, 59, 3);
      now = sec(60);
      engine.pause();
      expect(engine.signalLostIfSilent(sec(500)), isFalse);
      expect(engine.state, RunState.paused);
      now = sec(500);
      engine.resume();
      silent(501, 530);
      expect(engine.state, RunState.signalLost);
      expect(engine.stateSince, sec(500));
      now = sec(540);
      engine.pause();
      expect(engine.state, RunState.paused);
      expect(engine.pausedAt, sec(500));
      expect(engine.stateSince, sec(540));
    });

    test('신호 끊김 중 재개를 누르면 기록 중이 되고 30초를 새로 센다', () {
      move(1, 59, 3);
      silent(60, 90);
      expect(engine.state, RunState.signalLost);
      now = sec(100);
      engine.resume();
      expect(engine.state, RunState.recording);
      expect(engine.lastSignalAt, sec(100));
      silent(101, 129);
      expect(engine.state, RunState.autoPaused);
      silent(130, 130);
      expect(engine.state, RunState.signalLost);
    });
  });
}
