import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/domain/run_trim.dart';

const _lat0 = 37.5;
final _t0 = DateTime(2026, 10, 16, 19);

double _northOf(double meters) => _lat0 + meters / 6371000 * 180 / math.pi;

DateTime _at(int sec) => _t0.add(Duration(seconds: sec));

/// 초속 3m 로 [fromSec]~[toSec] 초 동안 1초마다 점을 넣는다. 거리는 시각에 비례한다.
void _record(
  RunEngine e,
  void Function(DateTime) setNow,
  int fromSec,
  int toSec,
) {
  for (var s = fromSec; s <= toSec; s++) {
    setNow(_at(s));
    e.addSample(
      LocationSample(
        time: _at(s),
        latitude: _northOf(3.0 * s),
        longitude: 127,
        accuracy: 5,
      ),
    );
  }
}

/// [pauses] 는 (정지 시작 초, 재개 초) 목록. [endSec] 에 끝낸다.
RunSummary _run(int endSec, {List<(int, int)> pauses = const []}) {
  var now = _t0;
  final e = RunEngine(clock: () => now);
  e.start();
  var from = 0;
  for (final (pauseAt, resumeAt) in pauses) {
    _record(e, (t) => now = t, from, pauseAt);
    now = _at(pauseAt);
    e.pause();
    now = _at(resumeAt);
    e.resume();
    from = resumeAt;
  }
  _record(e, (t) => now = t, from, endSec);
  now = _at(endSec);
  return e.end();
}

void main() {
  test('끝 시각 뒤 점이 사라지고 처음부터 계산한 값과 같다', () {
    final original = _run(600);
    final trimmed = trimRunEnd(original, _at(400));
    final fresh = _run(400);

    expect(trimmed.points.last.time, _at(400));
    expect(trimmed.points.length, fresh.points.length);
    expect(trimmed.endedAt, _at(400));
    expect(trimmed.startedAt, original.startedAt);
    expect(trimmed.name, original.name);
    expect(trimmed.distanceM, fresh.distanceM);
    expect(trimmed.movingTime, fresh.movingTime);
    expect(trimmed.avgPaceSecPerKm, fresh.avgPaceSecPerKm);
    expect(trimmed.calories, fresh.calories);
    expect(trimmed.splits.length, fresh.splits.length);
    for (var i = 0; i < fresh.splits.length; i++) {
      expect(trimmed.splits[i].distanceM, fresh.splits[i].distanceM);
      expect(trimmed.splits[i].duration, fresh.splits[i].duration);
    }
    expect(trimmed.segments.length, 1);
  });

  test('체중을 넘기면 칼로리에 반영한다', () {
    final trimmed = trimRunEnd(_run(600), _at(400), weightKg: 80);
    expect(trimmed.calories, estimateCalories(trimmed.distanceM, weightKg: 80));
  });

  test('일시정지 구간이 있어도 맞다 (기록 중에 자름)', () {
    final original = _run(500, pauses: [(200, 260)]);
    expect(original.movingTime, const Duration(seconds: 440));
    final trimmed = trimRunEnd(original, _at(400));
    final fresh = _run(400, pauses: [(200, 260)]);

    expect(trimmed.segments.length, 2);
    expect(trimmed.distanceM, fresh.distanceM);
    expect(trimmed.movingTime, const Duration(seconds: 340));
    expect(trimmed.movingTime, fresh.movingTime);
    expect(trimmed.splits.length, fresh.splits.length);
  });

  test('일시정지 사이에 자르면 뒤 구간이 통째로 사라지고 정지 시간은 세지 않는다', () {
    final original = _run(500, pauses: [(200, 260)]);
    final trimmed = trimRunEnd(original, _at(230));

    expect(trimmed.segments.length, 1);
    expect(trimmed.points.last.time, _at(200));
    expect(trimmed.movingTime, const Duration(seconds: 200));
    expect(trimmed.endedAt, _at(230));
  });

  test('끝 시각이 시작보다 앞이거나 원래 끝보다 뒤면 거부한다', () {
    final original = _run(600);
    expect(() => trimRunEnd(original, _at(-1)), throwsA(isA<ArgumentError>()));
    expect(() => trimRunEnd(original, _at(601)), throwsA(isA<ArgumentError>()));
  });

  test('원래 끝으로 자르면 같은 결과다', () {
    final original = _run(600, pauses: [(200, 260)]);
    final trimmed = trimRunEnd(original, original.endedAt);
    expect(trimmed.distanceM, original.distanceM);
    expect(trimmed.movingTime, original.movingTime);
    expect(trimmed.points.length, original.points.length);
    expect(trimmed.splits.length, original.splits.length);
  });

  test('시작 시각으로 자르면 움직인 시간이 음수가 되지 않는다', () {
    final trimmed = trimRunEnd(_run(600), _t0);
    expect(trimmed.movingTime.isNegative, isFalse);
    expect(trimmed.distanceM, 0);
    expect(trimmed.avgPaceSecPerKm, isNull);
  });
}
