import 'package:flutter/material.dart' show ThemeMode;
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

  test('음성 안내는 행이 없어도 기본으로 켜져 있고 끄고 켤 수 있다', () async {
    expect(await repo.voiceGuide(), isTrue);
    expect(await db.select(db.profiles).get(), isEmpty);
    await repo.setVoiceGuide(false);
    expect(await repo.voiceGuide(), isFalse);
    await repo.setVoiceGuide(true);
    expect(await repo.voiceGuide(), isTrue);
    expect(await db.select(db.profiles).get(), hasLength(1));
  });

  test('쉬는 날 알림은 행이 없어도 켜져 있고 끄고 켤 수 있다', () async {
    expect(await repo.reminder(), isTrue);
    expect(await db.select(db.profiles).get(), isEmpty);
    await repo.setReminder(false);
    expect(await repo.reminder(), isFalse);
    await repo.setReminder(true);
    expect(await repo.reminder(), isTrue);
  });

  test('건강 앱 연동은 행이 없어도 꺼져 있고 켜고 끌 수 있다', () async {
    expect(await repo.health(), isFalse);
    expect(await db.select(db.profiles).get(), isEmpty);
    await repo.setHealth(true);
    expect(await repo.health(), isTrue);
    await repo.setHealth(false);
    expect(await repo.health(), isFalse);
  });

  test('화면 모드는 행이 없어도 시스템이고 바꾸면 저장된다', () async {
    expect(await repo.themeMode(), ThemeMode.system);
    expect(await db.select(db.profiles).get(), isEmpty);
    await repo.setThemeMode(ThemeMode.dark);
    expect(await repo.themeMode(), ThemeMode.dark);
    await repo.setThemeMode(ThemeMode.light);
    expect(await repo.themeMode(), ThemeMode.light);
    await repo.setWeightKg(60);
    expect(await repo.themeMode(), ThemeMode.light);
  });

  test('음성 안내를 바꿔도 체중·첫 실행 표시는 그대로다', () async {
    await repo.setWeightKg(70);
    await repo.markOnboarded();
    await repo.setVoiceGuide(false);
    expect(await repo.weightKg(), 70);
    expect(await repo.isOnboarded(), isTrue);
    await repo.setWeightKg(71);
    expect(await repo.voiceGuide(), isFalse);
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
