import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/app_database.dart';

void main() {
  test('스키마 1 DB 를 열면 새 테이블이 생기고 러닝이 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE run_points (
  id TEXT NOT NULL, run_id TEXT NOT NULL REFERENCES runs (id),
  segment INTEGER NOT NULL, time TEXT NOT NULL, latitude REAL NOT NULL,
  longitude REAL NOT NULL, accuracy REAL NOT NULL, speed REAL NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE splits (
  id TEXT NOT NULL, run_id TEXT NOT NULL REFERENCES runs (id),
  idx INTEGER NOT NULL, distance_m REAL NOT NULL, duration_ms INTEGER NOT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
INSERT INTO runs (id, started_at, status, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 1;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final runs = await db.select(db.runs).get();
    expect(runs.map((r) => r.id), ['r1']);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['avatars', 'weekly_goals', 'xp_txns']));
    expect(await db.select(db.avatars).get(), isEmpty);
    expect(names, contains('profiles'));
  });

  test('스키마 2 DB 를 열면 profiles 가 생기고 기존 행이 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE avatars (
  id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'default',
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE xp_txns (
  id TEXT NOT NULL, amount INTEGER NOT NULL, reason TEXT NOT NULL,
  run_id TEXT NULL REFERENCES runs (id), week_start TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id), UNIQUE (run_id, reason), UNIQUE (week_start, reason));
INSERT INTO runs (id, started_at, status, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO avatars (id, name, kind, created_at, updated_at)
VALUES ('a1', '러니', 'chick',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO xp_txns (id, amount, reason, run_id, created_at, updated_at)
VALUES ('x1', 30, 'distance', 'r1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 2;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    expect((await db.select(db.runs).get()).map((r) => r.id), ['r1']);
    expect((await db.select(db.avatars).get()).map((a) => a.kind), ['chick']);
    expect((await db.select(db.xpTxns).get()).map((x) => x.amount), [30]);
    expect(await db.select(db.profiles).get(), isEmpty);
  });

  test('스키마 3 DB 를 열면 goal_m 이 생기고 기존 러닝은 목표 null 로 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE avatars (
  id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'default',
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
INSERT INTO runs (id, started_at, status, distance_m, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed', 4200,
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 3;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final runs = await db.select(db.runs).get();
    expect(runs.map((r) => r.id), ['r1']);
    expect(runs.single.distanceM, 4200);
    expect(runs.single.goalM, isNull);
  });

  test('스키마 4 DB 를 열면 코인 테이블·장착 열이 생기고 러닝·경험치가 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, goal_m REAL NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE avatars (
  id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'default',
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE xp_txns (
  id TEXT NOT NULL, amount INTEGER NOT NULL, reason TEXT NOT NULL,
  run_id TEXT NULL REFERENCES runs (id), week_start TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id), UNIQUE (run_id, reason), UNIQUE (week_start, reason));
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
INSERT INTO runs (id, started_at, status, distance_m, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed', 4200,
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO avatars (id, name, kind, created_at, updated_at)
VALUES ('a1', '러니', 'chick',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO xp_txns (id, amount, reason, run_id, created_at, updated_at)
VALUES ('x1', 30, 'distance', 'r1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 4;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    expect((await db.select(db.runs).get()).map((r) => r.id), ['r1']);
    expect((await db.select(db.xpTxns).get()).map((x) => x.amount), [30]);
    expect(await db.select(db.coinTxns).get(), isEmpty);
    expect(await db.select(db.ownedItems).get(), isEmpty);
    final avatar = (await db.select(db.avatars).get()).single;
    expect(avatar.kind, 'chick');
    expect(avatar.hatItemId, isNull);
    expect(avatar.accessoryItemId, isNull);
  });

  test('스키마 5 DB 를 열면 시간 목표·배지·음성 안내가 생기고 기존 데이터가 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, goal_m REAL NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE avatars (
  id TEXT NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT 'default',
  hat_item_id TEXT NULL, accessory_item_id TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE xp_txns (
  id TEXT NOT NULL, amount INTEGER NOT NULL, reason TEXT NOT NULL,
  run_id TEXT NULL REFERENCES runs (id), week_start TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id), UNIQUE (run_id, reason), UNIQUE (week_start, reason));
CREATE TABLE coin_txns (
  id TEXT NOT NULL, amount INTEGER NOT NULL, reason TEXT NOT NULL,
  run_id TEXT NULL REFERENCES runs (id), item_id TEXT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id), UNIQUE (run_id, reason));
CREATE TABLE owned_items (
  id TEXT NOT NULL, item_id TEXT NOT NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id), UNIQUE (item_id));
INSERT INTO runs (id, started_at, status, distance_m, goal_m, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed', 5200, 5000,
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO avatars (id, name, kind, hat_item_id, created_at, updated_at)
VALUES ('a1', '러니', 'chick', 'hat-1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO profiles (id, weight_kg, created_at, updated_at)
VALUES ('p1', 62.5, '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO xp_txns (id, amount, reason, run_id, created_at, updated_at)
VALUES ('x1', 30, 'distance', 'r1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO coin_txns (id, amount, reason, run_id, created_at, updated_at)
VALUES ('c1', 52, 'distance', 'r1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
INSERT INTO owned_items (id, item_id, created_at, updated_at)
VALUES ('o1', 'hat-1',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 5;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final run = (await db.select(db.runs).get()).single;
    expect(run.distanceM, 5200);
    expect(run.goalM, 5000);
    expect(run.goalSec, isNull);
    expect((await db.select(db.xpTxns).get()).single.amount, 30);
    expect((await db.select(db.coinTxns).get()).single.amount, 52);
    expect((await db.select(db.ownedItems).get()).single.itemId, 'hat-1');
    expect((await db.select(db.avatars).get()).single.hatItemId, 'hat-1');
    final profile = (await db.select(db.profiles).get()).single;
    expect(profile.weightKg, 62.5);
    expect(profile.voiceGuide, isTrue);
    expect(await db.select(db.badges).get(), isEmpty);
  });

  test('스키마 6 DB 를 열면 프로필 화면 모드는 시스템이고 값이 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, goal_m REAL NULL, goal_sec INTEGER NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  voice_guide INTEGER NOT NULL DEFAULT 1 CHECK (voice_guide IN (0, 1)),
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
INSERT INTO profiles (id, weight_kg, voice_guide, created_at, updated_at)
VALUES ('p1', 62.5, 0, '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 6;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final profile = (await db.select(db.profiles).get()).single;
    expect(profile.weightKg, 62.5);
    expect(profile.voiceGuide, isFalse);
    expect(profile.themeMode, 'system');
  });

  test('스키마 7 DB 를 열면 쉬는 날 알림은 켜져 있고 값이 남는다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, goal_m REAL NULL, goal_sec INTEGER NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  voice_guide INTEGER NOT NULL DEFAULT 1 CHECK (voice_guide IN (0, 1)),
  theme_mode TEXT NOT NULL DEFAULT 'system',
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
INSERT INTO profiles (id, weight_kg, voice_guide, theme_mode, created_at, updated_at)
VALUES ('p1', 62.5, 0, 'dark', '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
PRAGMA user_version = 7;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);

    final profile = (await db.select(db.profiles).get()).single;
    expect(profile.themeMode, 'dark');
    expect(profile.voiceGuide, isFalse);
    expect(profile.reminder, isTrue);
    expect(profile.health, isFalse);
  });

  test('스키마 8 DB 를 열면 기존 러닝은 앱 기록(source app)이다', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE runs (
  id TEXT NOT NULL, started_at TEXT NOT NULL, ended_at TEXT NULL,
  status TEXT NOT NULL, distance_m REAL NOT NULL DEFAULT 0,
  moving_time_s INTEGER NOT NULL DEFAULT 0, avg_pace_sec_per_km REAL NULL,
  calories REAL NOT NULL DEFAULT 0, name TEXT NOT NULL DEFAULT '',
  encoded_route TEXT NULL, goal_m REAL NULL, goal_sec INTEGER NULL,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  deleted_at TEXT NULL, PRIMARY KEY (id));
INSERT INTO runs (id, started_at, status, created_at, updated_at)
VALUES ('r1', '2026-10-01T00:00:00.000Z', 'completed',
  '2026-10-01T00:00:00.000Z', '2026-10-01T00:00:00.000Z');
CREATE TABLE profiles (
  id TEXT NOT NULL, weight_kg REAL NULL, onboarded_at TEXT NULL,
  voice_guide INTEGER NOT NULL DEFAULT 1 CHECK (voice_guide IN (0, 1)),
  theme_mode TEXT NOT NULL DEFAULT 'system',
  reminder INTEGER NOT NULL DEFAULT 1 CHECK (reminder IN (0, 1)),
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NULL,
  PRIMARY KEY (id));
PRAGMA user_version = 8;
''');
      },
    );
    final db = AppDatabase(executor);
    addTearDown(db.close);
    expect((await db.select(db.runs).get()).single.source, 'app');
    expect(await db.select(db.profiles).get(), isEmpty);
  });
}
