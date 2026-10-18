import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../run/data/app_database.dart';
import '../domain/growth_rules.dart';
import 'growth_repository.dart';

const _defaultName = '러니';
const _defaultTargetM = 10000.0;
const _distance = 'distance';
const _weeklyGoal = 'weeklyGoal';

class DriftGrowthRepository implements GrowthRepository {
  DriftGrowthRepository(this._db, {Random? random})
    : _random = random ?? Random();

  final AppDatabase _db;
  final Random _random;
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

  AvatarKind _pickKind() =>
      AvatarKind.values[_random.nextInt(AvatarKind.values.length)];

  /// 아바타 행을 돌려준다. 없으면 만들고, 종류가 모르는 값이면 한 번 정해 저장한다.
  /// 반드시 트랜잭션 안에서 부른다.
  Future<(Avatar, AvatarKind)> _ensureAvatar() async {
    final row =
        await (_db.select(_db.avatars)
              ..where((a) => a.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      final now = _now();
      final kind = _pickKind();
      final id = _uuid.v4();
      await _db
          .into(_db.avatars)
          .insert(
            AvatarsCompanion.insert(
              id: id,
              name: _defaultName,
              kind: Value(kind.name),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final created = await (_db.select(
        _db.avatars,
      )..where((a) => a.id.equals(id))).getSingle();
      return (created, kind);
    }
    for (final k in AvatarKind.values) {
      if (k.name == row.kind) return (row, k);
    }
    final kind = _pickKind();
    await (_db.update(_db.avatars)..where((a) => a.id.equals(row.id))).write(
      AvatarsCompanion(kind: Value(kind.name), updatedAt: Value(_now())),
    );
    return (row, kind);
  }

  @override
  Future<String> avatarName() =>
      _db.transaction(() async => (await _ensureAvatar()).$1.name);

  @override
  Future<AvatarKind> avatarKind() =>
      _db.transaction(() async => (await _ensureAvatar()).$2);

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

  /// (runId, reason) 또는 (weekStart, reason) 로 찾은 경험치 행. 무른 행도 돌려준다.
  /// 두 키가 유일하므로 무른 행을 지우지 않고 다시 살려 쓴다.
  Future<XpTxn?> _xpRow(String reason, {String? runId, String? weekStart}) {
    return (_db.select(_db.xpTxns)..where(
          (t) =>
              t.reason.equals(reason) &
              (runId != null
                  ? t.runId.equals(runId)
                  : t.weekStart.equals(weekStart!)),
        ))
        .getSingleOrNull();
  }

  /// 행이 없으면 넣고, 무른 행이면 [amount] 로 살리고, 살아 있으면 둔다.
  /// 반드시 트랜잭션 안에서 부른다.
  Future<void> _grantXp(
    String reason,
    int amount, {
    String? runId,
    String? weekStart,
  }) async {
    final now = _now();
    final row = await _xpRow(reason, runId: runId, weekStart: weekStart);
    if (row == null) {
      await _db
          .into(_db.xpTxns)
          .insert(
            XpTxnsCompanion.insert(
              id: _uuid.v4(),
              amount: amount,
              reason: reason,
              runId: Value(runId),
              weekStart: Value(weekStart),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else if (row.deletedAt != null) {
      await (_db.update(_db.xpTxns)..where((t) => t.id.equals(row.id))).write(
        XpTxnsCompanion(
          amount: Value(amount),
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// 살아 있는 행에 삭제 표시를 한다. 반드시 트랜잭션 안에서 부른다.
  Future<void> _revokeXp(String reason, {String? runId, String? weekStart}) {
    final now = _now();
    return (_db.update(_db.xpTxns)..where(
          (t) =>
              t.reason.equals(reason) &
              t.deletedAt.isNull() &
              (runId != null
                  ? t.runId.equals(runId)
                  : t.weekStart.equals(weekStart!)),
        ))
        .write(XpTxnsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  @override
  Future<void> addDistanceXp(String runId, int amount) =>
      _db.transaction(() => _grantXp(_distance, amount, runId: runId));

  @override
  Future<void> revokeDistanceXp(String runId) =>
      _db.transaction(() => _revokeXp(_distance, runId: runId));

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
      await _grantXp(_weeklyGoal, bonusXp, weekStart: key);
    });
  }

  @override
  Future<void> unmarkWeekAchieved(DateTime weekStart) {
    return _db.transaction(() async {
      final key = _key(weekStart);
      final row = await _goalRow(key);
      if (row?.achievedAt == null) return;
      await (_db.update(
        _db.weeklyGoals,
      )..where((g) => g.id.equals(row!.id))).write(
        WeeklyGoalsCompanion(
          achievedAt: const Value(null),
          updatedAt: Value(_now()),
        ),
      );
      await _revokeXp(_weeklyGoal, weekStart: key);
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
