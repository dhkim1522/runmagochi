import 'package:drift/drift.dart';

import '../../run/data/app_database.dart';
import '../domain/backup_codec.dart';
import 'backup_repository.dart';

class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db);

  final AppDatabase _db;

  static final _ser = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  @override
  Future<String> exportJson(DateTime now) async {
    List<Map<String, Object?>> rows(Iterable<DataClass> l) => [
      for (final d in l) d.toJson(serializer: _ser).cast<String, Object?>(),
    ];
    // 모든 읽기를 한 트랜잭션에서 해 한 시점의 스냅샷을 만든다.
    final tables = await _db.transaction(() async {
      final active = await (_db.select(
        _db.runs,
      )..where((r) => r.status.equals('active'))).get();
      final activeIds = [for (final r in active) r.id];

      final runs = await (_db.select(
        _db.runs,
      )..where((r) => r.status.equals('active').not())).get();
      final splits = await (_db.select(
        _db.splits,
      )..where((s) => s.runId.isNotIn(activeIds))).get();
      final xp = await (_db.select(
        _db.xpTxns,
      )..where((x) => x.runId.isNull() | x.runId.isNotIn(activeIds))).get();
      final coins = await (_db.select(
        _db.coinTxns,
      )..where((x) => x.runId.isNull() | x.runId.isNotIn(activeIds))).get();
      final owned = await _db.select(_db.ownedItems).get();
      final avatars = await _db.select(_db.avatars).get();
      final goals = await _db.select(_db.weeklyGoals).get();
      final profiles = await _db.select(_db.profiles).get();
      return {
        'runs': rows(runs),
        'splits': rows(splits),
        'avatars': rows(avatars),
        'weeklyGoals': rows(goals),
        'xpTxns': rows(xp),
        'profiles': rows(profiles),
        'coinTxns': rows(coins),
        'ownedItems': rows(owned),
      };
    });
    return BackupCodec.encode(BackupData(exportedAt: now, tables: tables));
  }

  @override
  Future<void> importJson(String json) async {
    final data = BackupCodec.decode(json);
    // 행 모양까지 먼저 확인해 DB 쓰기 전에 실패하게 한다.
    final List<Run> runs;
    final List<SplitRow> splits;
    final List<Avatar> avatars;
    final List<WeeklyGoal> goals;
    final List<XpTxn> xp;
    final List<Profile> profiles;
    final List<CoinTxn> coins;
    final List<OwnedItem> owned;
    try {
      List<T> parse<T>(String t, T Function(Map<String, dynamic>) f) => [
        for (final r in data.tables[t]!) f(r),
      ];
      runs = parse('runs', (j) => Run.fromJson(j, serializer: _ser));
      splits = parse('splits', (j) => SplitRow.fromJson(j, serializer: _ser));
      avatars = parse('avatars', (j) => Avatar.fromJson(j, serializer: _ser));
      goals = parse(
        'weeklyGoals',
        (j) => WeeklyGoal.fromJson(j, serializer: _ser),
      );
      xp = parse('xpTxns', (j) => XpTxn.fromJson(j, serializer: _ser));
      profiles = parse(
        'profiles',
        (j) => Profile.fromJson(j, serializer: _ser),
      );
      coins = parse('coinTxns', (j) => CoinTxn.fromJson(j, serializer: _ser));
      owned = parse(
        'ownedItems',
        (j) => OwnedItem.fromJson(j, serializer: _ser),
      );
    } on Object {
      throw const BackupFormatException('백업 파일을 읽을 수 없어요. 데이터가 잘못됐어요');
    }
    // 내보내기는 진행 중 러닝을 담지 않는다. 손으로 만든 파일이면 되살아나지 않게 막는다.
    if (runs.any((r) => r.status == 'active')) {
      throw const BackupFormatException('백업 파일을 읽을 수 없어요. 진행 중 러닝이 들어 있어요');
    }

    await _db.transaction(() async {
      // 자식 먼저 지운다.
      await _db.delete(_db.runPoints).go();
      await _db.delete(_db.splits).go();
      await _db.delete(_db.xpTxns).go();
      await _db.delete(_db.coinTxns).go();
      await _db.delete(_db.ownedItems).go();
      await _db.delete(_db.weeklyGoals).go();
      await _db.delete(_db.avatars).go();
      await _db.delete(_db.profiles).go();
      await _db.delete(_db.runs).go();
      // 부모 먼저 넣는다.
      for (final r in runs) {
        await _db.into(_db.runs).insert(r);
      }
      for (final r in splits) {
        await _db.into(_db.splits).insert(r);
      }
      for (final r in avatars) {
        await _db.into(_db.avatars).insert(r);
      }
      for (final r in goals) {
        await _db.into(_db.weeklyGoals).insert(r);
      }
      for (final r in xp) {
        await _db.into(_db.xpTxns).insert(r);
      }
      for (final r in profiles) {
        await _db.into(_db.profiles).insert(r);
      }
      for (final r in coins) {
        await _db.into(_db.coinTxns).insert(r);
      }
      for (final r in owned) {
        await _db.into(_db.ownedItems).insert(r);
      }
    });
  }
}
