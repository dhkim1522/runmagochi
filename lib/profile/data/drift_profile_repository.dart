import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../run/data/app_database.dart';
import 'profile_repository.dart';

class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  DateTime _now() => DateTime.now().toUtc();

  Future<Profile?> _row() =>
      (_db.select(_db.profiles)
            ..where((p) => p.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  /// 행이 없으면 만들고 [change] 로 고친다. 트랜잭션 안에서 읽고 쓴다.
  Future<void> _write(ProfilesCompanion Function(Profile? row) change) {
    return _db.transaction(() async {
      final row = await _row();
      final now = _now();
      if (row == null) {
        final c = change(null);
        await _db
            .into(_db.profiles)
            .insert(
              ProfilesCompanion.insert(
                id: _uuid.v4(),
                weightKg: c.weightKg,
                onboardedAt: c.onboardedAt,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (_db.update(_db.profiles)..where((p) => p.id.equals(row.id)))
            .write(change(row).copyWith(updatedAt: Value(now)));
      }
    });
  }

  @override
  Future<double?> weightKg() async => (await _row())?.weightKg;

  @override
  Future<void> setWeightKg(double? kg) =>
      _write((_) => ProfilesCompanion(weightKg: Value(kg)));

  @override
  Future<bool> isOnboarded() async => (await _row())?.onboardedAt != null;

  @override
  Future<void> markOnboarded() => _write(
    (row) => ProfilesCompanion(onboardedAt: Value(row?.onboardedAt ?? _now())),
  );
}
