import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/profile/data/drift_profile_repository.dart';
import 'package:runmagochi/run/data/app_database.dart';

void main() {
  late AppDatabase db;
  late DriftProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftProfileRepository(db);
  });
  tearDown(() => db.close());

  test('행이 없으면 체중 null, 첫 실행 미완료이고 읽기는 행을 만들지 않는다', () async {
    expect(await repo.weightKg(), isNull);
    expect(await repo.isOnboarded(), isFalse);
    expect(await db.select(db.profiles).get(), isEmpty);
  });

  test('체중을 저장하고 읽고 지울 수 있다', () async {
    await repo.setWeightKg(58.5);
    expect(await repo.weightKg(), 58.5);
    await repo.setWeightKg(60);
    expect(await repo.weightKg(), 60);
    await repo.setWeightKg(null);
    expect(await repo.weightKg(), isNull);
    expect(await db.select(db.profiles).get(), hasLength(1));
  });

  test('첫 실행 완료 표시는 체중을 건드리지 않고 한 행만 쓴다', () async {
    await repo.setWeightKg(70);
    await repo.markOnboarded();
    await repo.markOnboarded();
    expect(await repo.isOnboarded(), isTrue);
    expect(await repo.weightKg(), 70);
    expect(await db.select(db.profiles).get(), hasLength(1));
  });

  test('완료 표시만 먼저 해도 행이 만들어진다', () async {
    await repo.markOnboarded();
    expect(await repo.isOnboarded(), isTrue);
    expect(await repo.weightKg(), isNull);
  });

  test('삭제 표시된 행은 없는 것으로 본다', () async {
    await repo.setWeightKg(70);
    await repo.markOnboarded();
    await db
        .update(db.profiles)
        .write(ProfilesCompanion(deletedAt: Value(DateTime.now().toUtc())));
    expect(await repo.weightKg(), isNull);
    expect(await repo.isOnboarded(), isFalse);
  });
}
