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
    expect(back.schemaVersion, 8);
    expect(back.tables, data.tables);
  });

  test('schemaVersion 3~8 은 받고 2 와 9 는 거부한다', () {
    String withSchema(int v) {
      final m = jsonDecode(BackupCodec.encode(data)) as Map<String, dynamic>;
      m['schemaVersion'] = v;
      return jsonEncode(m);
    }

    for (final v in [3, 4, 5, 6, 7, 8]) {
      expect(BackupCodec.decode(withSchema(v)).schemaVersion, v);
    }
    for (final v in [2, 9]) {
      expect(
        () => BackupCodec.decode(withSchema(v)),
        throwsA(isA<BackupFormatException>()),
      );
    }
  });

  test('5 미만 파일은 코인·보유 테이블 없이도 읽고 빈 목록으로 채운다', () {
    final m = jsonDecode(BackupCodec.encode(data)) as Map<String, dynamic>;
    m['schemaVersion'] = 4;
    (m['tables'] as Map).remove('coinTxns');
    (m['tables'] as Map).remove('ownedItems');
    final back = BackupCodec.decode(jsonEncode(m));
    expect(back.tables['coinTxns'], isEmpty);
    expect(back.tables['ownedItems'], isEmpty);
  });

  test('6 미만 파일은 배지 테이블 없이 읽고 프로필에 음성 안내 true 를 채운다', () {
    final m = jsonDecode(BackupCodec.encode(data)) as Map<String, dynamic>;
    m['schemaVersion'] = 5;
    (m['tables'] as Map).remove('badges');
    (m['tables'] as Map)['profiles'] = [
      {'id': 'p', 'weightKg': 60.0},
    ];
    final back = BackupCodec.decode(jsonEncode(m));
    expect(back.tables['badges'], isEmpty);
    expect(back.tables['profiles']!.single['voiceGuide'], true);
  });

  test('7 미만 파일은 프로필에 화면 모드 system 을 채운다', () {
    final m = jsonDecode(BackupCodec.encode(data)) as Map<String, dynamic>;
    m['schemaVersion'] = 6;
    (m['tables'] as Map)['profiles'] = [
      {'id': 'p', 'weightKg': 60.0, 'voiceGuide': false},
    ];
    final back = BackupCodec.decode(jsonEncode(m));
    expect(back.tables['profiles']!.single['themeMode'], 'system');
    expect(back.tables['profiles']!.single['voiceGuide'], false);
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
