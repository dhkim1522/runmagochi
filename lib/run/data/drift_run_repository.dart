import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/location_sample.dart';
import '../domain/polyline_codec.dart';
import '../domain/run_summary.dart';
import 'app_database.dart';
import 'run_repository.dart';

const _active = 'active';
const _completed = 'completed';

class DriftRunRepository implements RunRepository {
  DriftRunRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  // DB에는 UTC 로 저장하고 읽을 때 현지 시각으로 돌려준다.
  DateTime _now() => DateTime.now().toUtc();

  @override
  Future<String> createActiveRun(DateTime startedAt) async {
    final id = _uuid.v4();
    final now = _now();
    await _db
        .into(_db.runs)
        .insert(
          RunsCompanion.insert(
            id: id,
            startedAt: startedAt.toUtc(),
            status: _active,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  @override
  Future<void> appendPoints(
    String runId, {
    required int segmentIndex,
    required List<LocationSample> points,
    required Duration movingTime,
  }) {
    return _db.transaction(() async {
      final now = _now();
      await _db.batch((b) {
        b.insertAll(_db.runPoints, [
          for (final p in points)
            RunPointsCompanion.insert(
              id: _uuid.v4(),
              runId: runId,
              segment: segmentIndex,
              time: p.time.toUtc(),
              latitude: p.latitude,
              longitude: p.longitude,
              accuracy: p.accuracy,
              speed: Value(p.speed),
              createdAt: now,
              updatedAt: now,
            ),
        ]);
      });
      await (_db.update(_db.runs)..where((r) => r.id.equals(runId))).write(
        RunsCompanion(
          movingTimeS: Value(movingTime.inSeconds),
          updatedAt: Value(now),
        ),
      );
    });
  }

  @override
  Future<ActiveRun?> findActiveRun() async {
    final run =
        await (_db.select(_db.runs)
              ..where((r) => r.status.equals(_active) & r.deletedAt.isNull())
              ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (run == null) return null;
    final rows =
        await (_db.select(_db.runPoints)
              ..where((p) => p.runId.equals(run.id) & p.deletedAt.isNull())
              ..orderBy([
                (p) => OrderingTerm.asc(p.segment),
                (p) => OrderingTerm.asc(p.time),
              ]))
            .get();
    final bySegment = <int, List<LocationSample>>{};
    for (final row in rows) {
      bySegment
          .putIfAbsent(row.segment, () => [])
          .add(
            LocationSample(
              time: row.time.toLocal(),
              latitude: row.latitude,
              longitude: row.longitude,
              accuracy: row.accuracy,
              speed: row.speed,
            ),
          );
    }
    return ActiveRun(
      id: run.id,
      startedAt: run.startedAt.toLocal(),
      segments: bySegment.values.toList(),
      movingTime: Duration(seconds: run.movingTimeS),
    );
  }

  @override
  Future<void> completeRun(String runId, RunSummary summary) {
    return _db.transaction(() async {
      final now = _now();
      await (_db.update(_db.runs)..where((r) => r.id.equals(runId))).write(
        RunsCompanion(
          status: const Value(_completed),
          startedAt: Value(summary.startedAt.toUtc()),
          endedAt: Value(summary.endedAt.toUtc()),
          distanceM: Value(summary.distanceM),
          movingTimeS: Value(summary.movingTime.inSeconds),
          avgPaceSecPerKm: Value(summary.avgPaceSecPerKm),
          calories: Value(summary.calories),
          name: Value(summary.name),
          encodedRoute: Value(
            encodePolyline([
              for (final p in summary.points) (p.latitude, p.longitude),
            ]),
          ),
          updatedAt: Value(now),
        ),
      );
      await _db.batch((b) {
        b.insertAll(_db.splits, [
          for (final s in summary.splits)
            SplitsCompanion.insert(
              id: _uuid.v4(),
              runId: runId,
              idx: s.index,
              distanceM: s.distanceM,
              durationMs: s.duration.inMilliseconds,
              createdAt: now,
              updatedAt: now,
            ),
        ]);
      });
      await (_db.delete(
        _db.runPoints,
      )..where((p) => p.runId.equals(runId))).go();
    });
  }

  RunListItem _toItem(Run r) => RunListItem(
    id: r.id,
    name: r.name,
    startedAt: r.startedAt.toLocal(),
    distanceM: r.distanceM,
    movingTime: Duration(seconds: r.movingTimeS),
    avgPaceSecPerKm: r.avgPaceSecPerKm,
  );

  @override
  Future<List<RunListItem>> listRuns() async {
    final rows =
        await (_db.select(_db.runs)
              ..where((r) => r.status.equals(_completed) & r.deletedAt.isNull())
              ..orderBy([(r) => OrderingTerm.desc(r.startedAt)]))
            .get();
    return rows.map(_toItem).toList();
  }

  @override
  Future<RunDetail?> getRun(String id) async {
    final run = await (_db.select(
      _db.runs,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (run == null) return null;
    final splitRows =
        await (_db.select(_db.splits)
              ..where((s) => s.runId.equals(id) & s.deletedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.idx)]))
            .get();
    final encoded = run.encodedRoute;
    return RunDetail(
      run: _toItem(run),
      calories: run.calories,
      route: encoded == null ? const [] : decodePolyline(encoded),
      splits: [
        for (final s in splitRows)
          Split(
            index: s.idx,
            distanceM: s.distanceM,
            duration: Duration(milliseconds: s.durationMs),
          ),
      ],
    );
  }

  @override
  Future<(double distanceM, int count)> weeklyTotal(DateTime now) async {
    final local = now.toLocal();
    // DateTime 생성자의 day 연산으로 월요일 0시를 구한다 (일광절약 시간 영향 없음).
    final monday = DateTime(
      local.year,
      local.month,
      local.day - (local.weekday - 1),
    );
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    final rows =
        await (_db.select(_db.runs)..where(
              (r) =>
                  r.status.equals(_completed) &
                  r.deletedAt.isNull() &
                  r.startedAt.isBiggerOrEqualValue(monday.toUtc()) &
                  r.startedAt.isSmallerThanValue(nextMonday.toUtc()),
            ))
            .get();
    return (rows.fold<double>(0, (sum, r) => sum + r.distanceM), rows.length);
  }
}
