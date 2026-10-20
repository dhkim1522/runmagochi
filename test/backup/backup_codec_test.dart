import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/backup/domain/backup_codec.dart';

void main() {
  final data = BackupData(
    exportedAt: DateTime.utc(2026, 10, 18),
    tables: {
      for (final n in BackupCodec.tableNames) n: <Map<String, Object?>>[],
      'avatars': [
        {'id': 'a', 'name': '러니', 'deletedAt': null, 'x': 1.5},
      ],
    },
  );

  test('encode 후 decode 하면 같은 값이다', () {
    final back = BackupCodec.decode(BackupCodec.encode(data));
    expect(back.exportedAt, data.exportedAt);
    expect(back.schemaVersion, 4);
    expect(back.tables, data.tables);
  });

  test('schemaVersion 3 은 받고 2 와 5 는 거부한다', () {
    String withSchema(int v) {
      final m = jsonDecode(BackupCodec.encode(data)) as Map<String, dynamic>;
      m['schemaVersion'] = v;
      return jsonEncode(m);
    }

    expect(BackupCodec.decode(withSchema(3)).schemaVersion, 3);
    for (final v in [2, 5]) {
      expect(
        () => BackupCodec.decode(withSchema(v)),
        throwsA(isA<BackupFormatException>()),
      );
    }
  });

  test('이상한 입력은 BackupFormatException', () {
    for (final s in ['', 'null', '{}', '{"format":"runmagochi-backup"}']) {
      expect(
        () => BackupCodec.decode(s),
        throwsA(isA<BackupFormatException>()),
        reason: s,
      );
    }
  });
}
