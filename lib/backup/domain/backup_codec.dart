import 'dart:convert';

/// 백업 파일을 읽을 수 없을 때 던진다. [message] 는 화면에 그대로 보여 줄 수 있는 한국어 문장이다.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

/// 백업 한 벌. [tables] 는 테이블 이름 → 행 목록이고, 행은 drift 의 JSON 모양
/// (DateTime 은 ISO-8601 문자열, 나머지는 숫자·문자열·null)이다.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.tables,
    this.schemaVersion = BackupCodec.currentSchemaVersion,
  });

  final DateTime exportedAt;
  final int schemaVersion;
  final Map<String, List<Map<String, Object?>>> tables;
}

/// [BackupData] 와 JSON 문자열을 서로 바꾼다. 순수 함수만 있다.
///
/// schemaVersion 3(러닝에 목표가 없다)·4(코인·보유·장착이 없다)·5(시간 목표·배지·음성 안내가 없다)·6(화면 모드가 없다)·7 을 받는다. DB 스키마가 바뀌면 [currentSchemaVersion] 을 올리고,
/// 이전 버전 파일을 읽을 수 있게 [decode] 에 변환 단계를 더한다.
abstract final class BackupCodec {
  static const format = 'runmagochi-backup';
  static const version = 1;
  static const currentSchemaVersion = 7;

  /// 백업에 담는 테이블. RunPoints 는 담지 않는다.
  static const tableNames = [
    'runs',
    'splits',
    'avatars',
    'weeklyGoals',
    'xpTxns',
    'profiles',
    'coinTxns',
    'ownedItems',
    'badges',
  ];

  /// 5 미만 파일에는 없어 빈 목록으로 채우는 테이블.
  static const _addedInV5 = ['coinTxns', 'ownedItems'];

  /// 6 미만 파일에는 없어 빈 목록으로 채우는 테이블.
  static const _addedInV6 = ['badges'];

  static const _unreadable = '백업 파일을 읽을 수 없어요';

  static String encode(BackupData data) => jsonEncode({
    'format': format,
    'version': version,
    'schemaVersion': data.schemaVersion,
    'exportedAt': data.exportedAt.toUtc().toIso8601String(),
    'tables': data.tables,
  });

  static BackupData decode(String json) {
    final Object? root;
    try {
      root = jsonDecode(json);
    } on FormatException {
      throw const BackupFormatException('$_unreadable. 파일이 손상된 것 같아요');
    }
    if (root is! Map<String, dynamic> || root['format'] != format) {
      throw const BackupFormatException('$_unreadable. 런마고치 백업 파일이 아니에요');
    }
    final v = root['version'];
    if (v is! int || v != version) {
      throw const BackupFormatException(
        '$_unreadable. 지원하지 않는 백업 파일 버전이에요. 앱을 최신으로 업데이트해 주세요',
      );
    }
    final s = root['schemaVersion'];
    if (s is! int || (s < 3 || s > currentSchemaVersion)) {
      throw const BackupFormatException('$_unreadable. 다른 버전 앱에서 만든 백업 파일이에요');
    }
    final exported = root['exportedAt'];
    final exportedAt = exported is String ? DateTime.tryParse(exported) : null;
    if (exportedAt == null) {
      throw const BackupFormatException('$_unreadable. 내보낸 시각이 없어요');
    }
    final raw = root['tables'];
    if (raw is! Map<String, dynamic>) {
      throw const BackupFormatException('$_unreadable. 데이터가 비어 있어요');
    }
    final tables = <String, List<Map<String, Object?>>>{};
    for (final name in tableNames) {
      final missing =
          (s < 5 && _addedInV5.contains(name)) ||
          (s < 6 && _addedInV6.contains(name));
      final rows = missing ? const [] : raw[name];
      if (rows is! List) {
        throw BackupFormatException('$_unreadable. $name 데이터가 없어요');
      }
      tables[name] = [
        for (final row in rows)
          if (row is Map<String, dynamic>)
            row
          else
            throw BackupFormatException('$_unreadable. $name 데이터가 잘못됐어요'),
      ];
    }
    if (s < 6) {
      // 음성 안내 열이 없던 파일의 프로필은 기본값(켬)으로 채운다.
      tables['profiles'] = [
        for (final row in tables['profiles']!) {...row, 'voiceGuide': true},
      ];
    }
    if (s < 7) {
      // 화면 모드 열이 없던 파일의 프로필은 기본값(시스템)으로 채운다.
      tables['profiles'] = [
        for (final row in tables['profiles']!) {...row, 'themeMode': 'system'},
      ];
    }
    return BackupData(exportedAt: exportedAt, schemaVersion: s, tables: tables);
  }
}
