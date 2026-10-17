import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../run/data/app_database.dart';
import 'growth_repository.dart';

const _defaultName = '러니';
const _defaultTargetM = 10000.0;
const _distance = 'distance';
const _weeklyGoal = 'weeklyGoal';

class DriftGrowthRepository implements GrowthRepository {
  DriftGrowthRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  DateTime _now() => DateTime.now().toUtc();

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parse(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  @override
  Future<String> avatarName() {
    return _db.transaction(() async {
      final row =
          await (_db.select(_db.avatars)
                ..where((a) => a.deletedAt.isNull())
                ..limit(1))
              .getSingleOrNull();
      if (row != null) return row.name;
      final now = _now();
      await _db
          .into(_db.avatars)
          .insert(
            AvatarsCompanion.insert(
              id: _uuid.v4(),
              name: _defaultName,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return _defaultName;
    });
  }

  @override
  Future<int> totalXp() async {
    final sum = _db.xpTxns.amount.sum();
    final row =
        await (_db.selectOnly(_db.xpTxns)
              ..addColumns([sum])
              ..where(_db.xpTxns.deletedAt.isNull()))
            .getSingle();
    return row.read(sum) ?? 0;
  }

  @override
  Future<Set<String>> runIdsWithDistanceXp() async {
    final rows =
        await (_db.select(_db.xpTxns)..where(
              (t) =>
                  t.reason.equals(_distance) &
                  t.runId.isNotNull() &
                  t.deletedAt.isNull(),
            ))
            .get();
    return {for (final r in rows) r.runId!};
  }

  @override
  Future<void> addDistanceXp(String runId, int amount) async {
    final now = _now();
    await _db
        .into(_db.xpTxns)
        .insert(
          XpTxnsCompanion.insert(
            id: _uuid.v4(),
            amount: amount,
            reason: _distance,
            runId: Value(runId),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<WeeklyGoal?> _goalRow(String key) {
    return (_db.select(_db.weeklyGoals)
          ..where((g) => g.weekStart.equals(key) & g.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<double> _inheritedTarget(String key) async {
    final row =
        await (_db.select(_db.weeklyGoals)
              ..where(
                (g) =>
                    g.weekStart.isSmallerOrEqualValue(key) &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => OrderingTerm.desc(g.weekStart)])
              ..limit(1))
            .getSingleOrNull();
    return row?.targetM ?? _defaultTargetM;
  }

  @override
  Future<double> weeklyTarget(DateTime weekStart) =>
      _inheritedTarget(_key(weekStart));

  @override
  Future<void> setWeeklyTarget(DateTime weekStart, double targetM) {
    return _db.transaction(() async {
      final key = _key(weekStart);
      final now = _now();
      final row = await _goalRow(key);
      if (row == null) {
        await _db
            .into(_db.weeklyGoals)
            .insert(
              WeeklyGoalsCompanion.insert(
                id: _uuid.v4(),
                weekStart: key,
                targetM: targetM,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_db.update(
          _db.weeklyGoals,
        )..where((g) => g.id.equals(row.id))).write(
          WeeklyGoalsCompanion(targetM: Value(targetM), updatedAt: Value(now)),
        );
      }
    });
  }

  @override
  Future<bool> isWeekAchieved(DateTime weekStart) async {
    final row = await _goalRow(_key(weekStart));
    return row?.achievedAt != null;
  }

  @override
  Future<void> markWeekAchieved(DateTime weekStart, DateTime at, int bonusXp) {
    return _db.transaction(() async {
      final key = _key(weekStart);
      final now = _now();
      final row = await _goalRow(key);
      if (row?.achievedAt != null) return;
      if (row == null) {
        final target = await _inheritedTarget(key);
        await _db
            .into(_db.weeklyGoals)
            .insert(
              WeeklyGoalsCompanion.insert(
                id: _uuid.v4(),
                weekStart: key,
                targetM: target,
                achievedAt: Value(at.toUtc()),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_db.update(
          _db.weeklyGoals,
        )..where((g) => g.id.equals(row.id))).write(
          WeeklyGoalsCompanion(
            achievedAt: Value(at.toUtc()),
            updatedAt: Value(now),
          ),
        );
      }
      await _db
          .into(_db.xpTxns)
          .insert(
            XpTxnsCompanion.insert(
              id: _uuid.v4(),
              amount: bonusXp,
              reason: _weeklyGoal,
              weekStart: Value(key),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  @override
  Future<List<DateTime>> achievedWeeks() async {
    final rows =
        await (_db.select(_db.weeklyGoals)
              ..where((g) => g.achievedAt.isNotNull() & g.deletedAt.isNull())
              ..orderBy([(g) => OrderingTerm.desc(g.weekStart)]))
            .get();
    return [for (final r in rows) _parse(r.weekStart)];
  }
}
