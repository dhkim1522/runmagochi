import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/clock.dart';
import '../../run/data/app_database.dart';
import '../domain/avatar_name.dart';
import '../domain/growth_rules.dart';
import 'growth_repository.dart';

const _defaultName = '러니';
const _distance = 'distance';
const _runGoal = 'runGoal';

class DriftGrowthRepository implements GrowthRepository {
  /// [now] 는 행 시각(updatedAt 등)에 쓴다. 테스트에서만 바꾼다.
  DriftGrowthRepository(this._db, {Random? random, Clock? now})
    : _random = random ?? Random(),
      _clock = now ?? DateTime.now;

  final AppDatabase _db;
  final Random _random;
  final Clock _clock;
  final _uuid = const Uuid();

  DateTime _now() => _clock().toUtc();

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
  Future<void> setAvatarName(String name) async {
    final error = validateAvatarName(name);
    if (error != null) throw ArgumentError.value(name, 'name', error);
    await _db.transaction(() async {
      final (row, _) = await _ensureAvatar();
      await (_db.update(_db.avatars)..where((a) => a.id.equals(row.id))).write(
        AvatarsCompanion(name: Value(name.trim()), updatedAt: Value(_now())),
      );
    });
  }

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

  @override
  Future<Map<String, DateTime>> distanceXpUpdatedAts() async {
    final rows =
        await (_db.select(_db.xpTxns)..where(
              (t) =>
                  t.reason.equals(_distance) &
                  t.runId.isNotNull() &
                  t.deletedAt.isNull(),
            ))
            .get();
    return {for (final r in rows) r.runId!: r.updatedAt.toLocal()};
  }

  /// (runId, reason) 로 찾은 경험치 행. 무른 행도 돌려준다.
  /// 키가 유일하므로 무른 행을 지우지 않고 다시 살려 쓴다.
  Future<XpTxn?> _xpRow(String reason, String runId) {
    return (_db.select(_db.xpTxns)
          ..where((t) => t.reason.equals(reason) & t.runId.equals(runId)))
        .getSingleOrNull();
  }

  /// 행이 없으면 넣고, 있으면(무른 행은 살려서) [amount] 로 맞춘다.
  /// 반드시 트랜잭션 안에서 부른다.
  Future<void> _setXp(String reason, int amount, String runId) async {
    final now = _now();
    final row = await _xpRow(reason, runId);
    if (row == null) {
      await _db
          .into(_db.xpTxns)
          .insert(
            XpTxnsCompanion.insert(
              id: _uuid.v4(),
              amount: amount,
              reason: reason,
              runId: Value(runId),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
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
  Future<void> _revokeXp(String reason, String runId) {
    final now = _now();
    return (_db.update(_db.xpTxns)..where(
          (t) =>
              t.reason.equals(reason) &
              t.deletedAt.isNull() &
              t.runId.equals(runId),
        ))
        .write(XpTxnsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  @override
  Future<int> runGoalXp(String runId) async {
    final row = await _xpRow(_runGoal, runId);
    return row == null || row.deletedAt != null ? 0 : row.amount;
  }

  @override
  Future<void> setRunXp(
    String runId, {
    required int distanceXp,
    required int goalBonusXp,
  }) => _db.transaction(() async {
    await _setXp(_distance, distanceXp, runId);
    if (goalBonusXp > 0) {
      await _setXp(_runGoal, goalBonusXp, runId);
    } else {
      await _revokeXp(_runGoal, runId);
    }
  });

  @override
  Future<void> revokeRunXp(String runId) => _db.transaction(() async {
    await _revokeXp(_distance, runId);
    await _revokeXp(_runGoal, runId);
  });
}
