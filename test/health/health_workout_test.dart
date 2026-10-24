import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/health/domain/health_workout.dart';

HealthWorkout w({
  String id = 'w1',
  DateTime? start,
  Duration dur = const Duration(minutes: 30),
  double? distanceM = 5000,
  double? kcal = 320,
  bool running = true,
  bool fromApp = false,
}) => HealthWorkout(
  id: id,
  startedAt: start ?? DateTime(2026, 10, 20, 7),
  endedAt: (start ?? DateTime(2026, 10, 20, 7)).add(dur),
  distanceM: distanceM,
  energyKcal: kcal,
  isRunning: running,
  writtenByThisApp: fromApp,
);

void main() {
  group('importableWorkouts', () {
    test('이 앱이 쓴 운동·러닝이 아닌 운동·거리 없는 운동·1km 미만은 뺀다', () {
      final out = importableWorkouts([
        w(id: 'ok'),
        w(id: 'mine', fromApp: true),
        w(id: 'walk', running: false),
        w(id: 'nodist', distanceM: null),
        w(id: 'short', distanceM: 900),
      ], alreadyImported: const {});
      expect(out.map((e) => e.id), ['ok']);
    });

    test('이미 들인 운동은 다시 들이지 않는다', () {
      final out = importableWorkouts(
        [w(id: 'a'), w(id: 'b')],
        alreadyImported: {'a'},
      );
      expect(out.map((e) => e.id), ['b']);
    });

    test('오래된 것부터', () {
      final out = importableWorkouts([
        w(id: 'late', start: DateTime(2026, 10, 22)),
        w(id: 'early', start: DateTime(2026, 10, 20)),
      ], alreadyImported: const {});
      expect(out.map((e) => e.id), ['early', 'late']);
    });
  });

  group('summaryOf', () {
    test('거리·시간·평균 페이스·칼로리와 건강 앱 이름', () {
      final s = summaryOf(w());
      expect(s.distanceM, 5000);
      expect(s.movingTime, const Duration(minutes: 30));
      expect(s.avgPaceSecPerKm, closeTo(360, 0.01));
      expect(s.calories, 320);
      expect(s.points, isEmpty);
      expect(s.name, '화요일 아침 러닝');
    });

    test('1km 구간을 평균 페이스로 나눈다(마지막은 남은 거리)', () {
      final s = summaryOf(w(distanceM: 2500, dur: const Duration(minutes: 15)));
      expect(s.splits.map((e) => e.distanceM), [1000, 1000, 500]);
      expect(s.splits.map((e) => e.paceSecPerKm.round()), [360, 360, 360]);
    });

    test('칼로리가 없으면 0', () {
      expect(summaryOf(w(kcal: null)).calories, 0);
    });
  });

  test('sourceOf / healthIdOf 는 서로 되돌린다', () {
    expect(healthSourceOf('w1'), 'health:w1');
    expect(healthIdOf('health:w1'), 'w1');
    expect(healthIdOf('app'), isNull);
  });
}
