import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/drift_run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

LocationSample sample(DateTime t, double lat, double lng) => LocationSample(
  time: t,
  latitude: lat,
  longitude: lng,
  accuracy: 5,
  speed: 3,
);

RunSummary summary(
  DateTime start, {
  double distanceM = 1000,
  List<LocationSample>? points,
  List<Split> splits = const [],
}) => RunSummary(
  startedAt: start,
  endedAt: start.add(const Duration(minutes: 6)),
  distanceM: distanceM,
  movingTime: const Duration(minutes: 5),
  avgPaceSecPerKm: distanceM == 0 ? null : 300,
  calories: 67.3,
  name: '테스트 러닝',
  splits: splits,
  points: points ?? const [],
);

void main() {
  late AppDatabase db;
  late DriftRunRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftRunRepository(db);
  });
  tearDown(() => db.close());

  test('createActiveRun 후 findActiveRun이 같은 id와 점을 돌려준다', () async {
    final start = DateTime(2026, 1, 5, 9);
    final id = await repo.createActiveRun(start);
    final p = [
      sample(start.add(const Duration(seconds: 1)), 37.5, 127.0),
      sample(start.add(const Duration(seconds: 2)), 37.51, 127.01),
    ];
    await repo.appendPoints(
      id,
      segmentIndex: 0,
      points: p,
      movingTime: const Duration(seconds: 2),
    );
    final active = await repo.findActiveRun();
    expect(active!.id, id);
    expect(active.startedAt, start);
    expect(active.segments, hasLength(1));
    expect(active.segments.single.map((e) => e.latitude), [37.5, 37.51]);
    expect(active.segments.single.first.time, p.first.time);
    expect(active.segments.single.first.speed, 3);
    expect(active.segments.single.first.time.isUtc, isFalse);
  });

  test('2구간 러닝이 구간 구조 그대로 복원된다', () async {
    final start = DateTime(2026, 1, 5, 9);
    final id = await repo.createActiveRun(start);
    DateTime t(int s) => start.add(Duration(seconds: s));
    // 구간 1을 먼저 저장해도 구간 번호 오름차순, 구간 안은 시간순이어야 한다.
    await repo.appendPoints(
      id,
      segmentIndex: 1,
      points: [sample(t(21), 3, 3), sample(t(20), 2, 2)],
      movingTime: const Duration(seconds: 10),
    );
    await repo.appendPoints(
      id,
      segmentIndex: 0,
      points: [sample(t(2), 1, 1), sample(t(1), 0, 0)],
      movingTime: const Duration(seconds: 12),
    );
    final active = (await repo.findActiveRun())!;
    expect(active.segments, hasLength(2));
    expect(active.segments[0].map((e) => e.latitude), [0, 1]);
    expect(active.segments[1].map((e) => e.latitude), [2, 3]);
  });

  test('movingTime은 appendPoints 호출마다 갱신되고 빈 점 목록에서도 저장된다', () async {
    final id = await repo.createActiveRun(DateTime(2026, 1, 5, 9));
    await repo.appendPoints(
      id,
      segmentIndex: 0,
      points: [sample(DateTime(2026, 1, 5, 9, 0, 1), 1, 1)],
      movingTime: const Duration(seconds: 10),
    );
    expect(
      (await repo.findActiveRun())!.movingTime,
      const Duration(seconds: 10),
    );
    await repo.appendPoints(
      id,
      segmentIndex: 0,
      points: const [],
      movingTime: const Duration(seconds: 25),
    );
    expect(
      (await repo.findActiveRun())!.movingTime,
      const Duration(seconds: 25),
    );
  });

  test('점 없는 진행 중 러닝은 빈 구간 목록을 돌려준다', () async {
    final id = await repo.createActiveRun(DateTime(2026, 1, 5, 9));
    final active = (await repo.findActiveRun())!;
    expect(active.id, id);
    expect(active.segments, isEmpty);
    expect(active.movingTime, Duration.zero);
  });

  test('진행 중 러닝이 없으면 findActiveRun은 null', () async {
    expect(await repo.findActiveRun(), isNull);
  });

  test(
    'completeRun 후 findActiveRun은 null, RunPoints는 0행, route 점 수 = 원본 점 수',
    () async {
      final start = DateTime(2026, 1, 5, 9);
      final id = await repo.createActiveRun(start);
      final pts = [
        for (var i = 0; i < 5; i++)
          sample(start.add(Duration(seconds: i)), 37.5 + i * 0.001, 127.0),
      ];
      await repo.appendPoints(
        id,
        segmentIndex: 0,
        points: pts,
        movingTime: const Duration(seconds: 4),
      );
      await repo.completeRun(
        id,
        summary(
          start,
          points: pts,
          splits: const [
            Split(index: 0, distanceM: 1000, duration: Duration(minutes: 5)),
          ],
        ),
      );
      expect(await repo.findActiveRun(), isNull);
      expect(await db.select(db.runPoints).get(), isEmpty);
      final detail = (await repo.getRun(id))!;
      expect(detail.route, hasLength(5));
      expect(detail.route.first.$1, closeTo(37.5, 1e-5));
      expect(detail.splits, hasLength(1));
      expect(detail.splits.single.duration, const Duration(minutes: 5));
      expect(detail.calories, 67.3);
      expect(detail.run.name, '테스트 러닝');
      expect(detail.run.movingTime, const Duration(minutes: 5));
    },
  );

  test('거리 0 요약도 저장된다', () async {
    final start = DateTime(2026, 1, 5, 9);
    final id = await repo.createActiveRun(start);
    await repo.completeRun(id, summary(start, distanceM: 0));
    final detail = (await repo.getRun(id))!;
    expect(detail.run.distanceM, 0);
    expect(detail.run.avgPaceSecPerKm, isNull);
    expect(detail.route, isEmpty);
    expect(await repo.listRuns(), hasLength(1));
  });

  test('listRuns는 최신순이고 진행 중·삭제된 러닝은 제외한다', () async {
    final a = await repo.createActiveRun(DateTime(2026, 1, 1, 9));
    await repo.completeRun(a, summary(DateTime(2026, 1, 1, 9)));
    final b = await repo.createActiveRun(DateTime(2026, 1, 3, 9));
    await repo.completeRun(b, summary(DateTime(2026, 1, 3, 9)));
    final c = await repo.createActiveRun(DateTime(2026, 1, 2, 9));
    await repo.completeRun(c, summary(DateTime(2026, 1, 2, 9)));
    final d = await repo.createActiveRun(DateTime(2026, 1, 4, 9));
    await repo.completeRun(d, summary(DateTime(2026, 1, 4, 9)));
    await (db.update(db.runs)..where((r) => r.id.equals(d))).write(
      RunsCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );
    await repo.createActiveRun(DateTime(2026, 1, 5, 9));
    expect((await repo.listRuns()).map((r) => r.id), [b, c, a]);
  });

  test('weeklyTotal은 월요일 0시부터', () async {
    // 2026-01-05 는 월요일.
    final sunday = DateTime(2026, 1, 4, 23);
    final monday = DateTime(2026, 1, 5, 0, 30);
    final id1 = await repo.createActiveRun(sunday);
    await repo.completeRun(id1, summary(sunday, distanceM: 3000));
    final id2 = await repo.createActiveRun(monday);
    await repo.completeRun(id2, summary(monday, distanceM: 2000));

    final (dist, count) = await repo.weeklyTotal(DateTime(2026, 1, 8, 12));
    expect(dist, 2000);
    expect(count, 1);

    final (prevDist, prevCount) = await repo.weeklyTotal(
      DateTime(2026, 1, 4, 23, 30),
    );
    expect(prevDist, 3000);
    expect(prevCount, 1);
  });

  test('weeklyTotal은 다음 주 월요일 0시 이후 러닝을 포함하지 않는다', () async {
    final nextMonday = DateTime(2026, 1, 12, 0, 0, 1);
    final id = await repo.createActiveRun(nextMonday);
    await repo.completeRun(id, summary(nextMonday, distanceM: 1000));
    final (dist, count) = await repo.weeklyTotal(DateTime(2026, 1, 8));
    expect((dist, count), (0.0, 0));
  });
}
