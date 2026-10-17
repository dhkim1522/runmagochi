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
  });
}
