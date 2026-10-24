import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/app_database.dart';

/// `docs/data-model.md` 의 ERD 가 실제 DB 와 어긋나지 않는지 본다.
void main() {
  final doc = File('docs/data-model.md').readAsStringSync();
  final erd = RegExp(
    r'```mermaid\s+erDiagram(.*?)```',
    dotAll: true,
  ).firstMatch(doc)!.group(1)!;

  // `Name {` 으로 시작하는 엔티티 블록과 그 안의 열 이름.
  final entities = <String, Set<String>>{};
  for (final m in RegExp(
    r'^\s{4}(\w+) \{\n(.*?)^\s{4}\}',
    multiLine: true,
    dotAll: true,
  ).allMatches(erd)) {
    entities[m.group(1)!] = {
      for (final line in m.group(2)!.trim().split('\n'))
        line.trim().split(RegExp(r'\s+'))[1],
    };
  }

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  String camel(String snake) => snake.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );

  test('ERD 엔티티 이름이 DB 테이블과 같다', () {
    final tables = {
      for (final t in db.allTables)
        // `runs` → `Runs`
        t.actualTableName[0].toUpperCase() +
            camel(t.actualTableName).substring(1),
    };
    expect(entities.keys.toSet(), tables);
    expect(tables.length, 10);
  });

  test('ERD 에 적은 열이 모두 실제 열이고 공통 필드 외에는 빠진 열이 없다', () {
    const common = {'createdAt', 'updatedAt', 'deletedAt'};
    for (final t in db.allTables) {
      final name =
          t.actualTableName[0].toUpperCase() +
          camel(t.actualTableName).substring(1);
      final real = {for (final c in t.$columns) camel(c.name)};
      expect(entities[name]!, real.difference(common), reason: name);
    }
  });

  test('문서의 스키마 판이 코드와 같다', () {
    expect(db.schemaVersion, 8);
    expect(doc, contains('스키마 8판'));
  });
}
