import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../run/data/app_database.dart';
import 'badge_repository.dart';

class DriftBadgeRepository implements BadgeRepository {
  DriftBadgeRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  @override
  Future<List<EarnedBadge>> earned() async {
    final rows =
        await (_db.select(_db.badges)
              ..where((b) => b.deletedAt.isNull())
              ..orderBy([(b) => OrderingTerm.asc(b.earnedAt)]))
            .get();
    return [
      for (final r in rows)
        EarnedBadge(
          badgeId: r.badgeId,
          earnedAt: r.earnedAt.toLocal(),
          runId: r.runId,
        ),
    ];
  }

  @override
  Future<bool> award(
    String badgeId, {
    String? runId,
    required int coins,
    required DateTime at,
  }) {
    return _db.transaction(() async {
      // 무른 행이어도 이미 받은 것으로 본다(유일 키).
      final exists = await (_db.select(
        _db.badges,
      )..where((b) => b.badgeId.equals(badgeId))).getSingleOrNull();
      if (exists != null) return false;
      final now = at.toUtc();
      await _db
          .into(_db.badges)
          .insert(
            BadgesCompanion.insert(
              id: _uuid.v4(),
              badgeId: badgeId,
              runId: Value(runId),
              earnedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      // runId 가 null 이라 (runId, reason) 유일 키와 겹치지 않는다.
      await _db
          .into(_db.coinTxns)
          .insert(
            CoinTxnsCompanion.insert(
              id: _uuid.v4(),
              amount: coins,
              reason: 'badge',
              itemId: Value(badgeId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return true;
    });
  }
}
