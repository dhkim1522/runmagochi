import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../core/week.dart';
import '../domain/location_sample.dart';
import '../domain/polyline_codec.dart';
import '../domain/run_summary.dart';
import 'app_database.dart';
import 'run_repository.dart';

const _active = 'active';
const _completed = 'completed';

class DriftRunRepository implements RunRepository {
  /// [now] 는 행 시각(updatedAt 등)에 쓴다. 테스트에서만 바꾼다.
  DriftRunRepository(this._db, {Clock? now}) : _clock = now ?? DateTime.now;

  final AppDatabase _db;
  final Clock _clock;
  final _uuid = const Uuid();

  // DB에는 UTC 로 저장하고 읽을 때 현지 시각으로 돌려준다.
  DateTime _now() => _clock().toUtc();

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
      final updated =
          await (_db.update(
            _db.runs,
          )..where((r) => r.id.equals(runId) & r.status.equals(_active))).write(
            RunsCompanion(
              movingTimeS: Value(movingTime.inSeconds),
              updatedAt: Value(now),
            ),
          );
      if (updated == 0) {
        throw StateError('진행 중인 러닝이 아니다: $runId');
      }
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
    // 엔진은 구간을 순서로만 이어 붙인다. 번호가 비면 구간이 섞인다.
    final segmentNumbers = bySegment.keys.toList();
    for (var i = 0; i < segmentNumbers.length; i++) {
      if (segmentNumbers[i] != i) {
        throw StateError('구간 번호가 0부터 이어지지 않는다: $segmentNumbers');
      }
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
      final updated =
          await (_db.update(
            _db.runs,
          )..where((r) => r.id.equals(runId) & r.status.equals(_active))).write(
            RunsCompanion(
              status: const Value(_completed),
              startedAt: Value(summary.startedAt.toUtc()),
              endedAt: Value(summary.endedAt.toUtc()),
              distanceM: Value(summary.distanceM),
              movingTimeS: Value(summary.movingTime.inSeconds),
              avgPaceSecPerKm: Value(summary.avgPaceSecPerKm),
              calories: Value(summary.calories),
              name: Value(summary.name),
              encodedRoute: Value(_encodeRoute(summary)),
              updatedAt: Value(now),
            ),
          );
      if (updated == 0) {
        throw StateError('진행 중인 러닝이 아니다: $runId');
      }
      await _insertSplits(runId, summary.splits, now);
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
    final run =
        await (_db.select(_db.runs)..where(
              (r) =>
                  r.id.equals(id) &
                  r.status.equals(_completed) &
                  r.deletedAt.isNull(),
            ))
            .getSingleOrNull();
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
    final monday = weekStartOf(now);
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

  @override
  Future<void> deleteRun(String id) {
    return _db.transaction(() async {
      final run = await (_db.select(
        _db.runs,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (run == null || run.status != _completed) {
        throw StateError('완료된 러닝이 아니다: $id');
      }
      if (run.deletedAt != null) return;
      final now = _now();
      await (_db.update(_db.runs)..where((r) => r.id.equals(id))).write(
        RunsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (_db.update(_db.splits)
            ..where((s) => s.runId.equals(id) & s.deletedAt.isNull()))
          .write(SplitsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    });
  }

  @override
  Future<void> replaceCompletedRun(String runId, RunSummary summary) {
    return _db.transaction(() async {
      final now = _now();
      final updated =
          await (_db.update(_db.runs)..where(
                (r) =>
                    r.id.equals(runId) &
                    r.status.equals(_completed) &
                    r.deletedAt.isNull(),
              ))
              .write(
                RunsCompanion(
                  endedAt: Value(summary.endedAt.toUtc()),
                  distanceM: Value(summary.distanceM),
                  movingTimeS: Value(summary.movingTime.inSeconds),
                  avgPaceSecPerKm: Value(summary.avgPaceSecPerKm),
                  calories: Value(summary.calories),
                  encodedRoute: Value(_encodeRoute(summary)),
                  updatedAt: Value(now),
                ),
              );
      if (updated == 0) {
        throw StateError('완료된 러닝이 아니다: $runId');
      }
      await (_db.update(_db.splits)
            ..where((s) => s.runId.equals(runId) & s.deletedAt.isNull()))
          .write(SplitsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
      await _insertSplits(runId, summary.splits, now);
    });
  }

  @override
  Future<Map<String, DateTime>> deletedRunStarts(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.runs)..where(
              (r) =>
                  r.id.isIn(ids) &
                  r.status.equals(_completed) &
                  r.deletedAt.isNotNull(),
            ))
            .get();
    return {for (final r in rows) r.id: r.startedAt.toLocal()};
  }

  @override
  Future<Map<String, DateTime>> completedRunRevisions() async {
    final rows = await (_db.select(
      _db.runs,
    )..where((r) => r.status.equals(_completed) & r.deletedAt.isNull())).get();
    return {for (final r in rows) r.id: r.updatedAt.toLocal()};
  }

  String _encodeRoute(RunSummary summary) => encodePolyline([
    for (final p in summary.points) (p.latitude, p.longitude),
  ]);

  Future<void> _insertSplits(String runId, List<Split> splits, DateTime now) {
    return _db.batch((b) {
      b.insertAll(_db.splits, [
        for (final s in splits)
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
  }
}
