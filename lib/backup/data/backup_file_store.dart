import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// 백업 파일을 사용자가 고른 위치에 저장하고 읽는다. file_picker 는 이 뒤에 둔다 (결정 0014).
abstract interface class BackupFileStore {
  /// 저장 위치를 고르게 하고 [bytes] 를 [fileName] 으로 저장한다. 사용자가 취소하면 false.
  Future<bool> save(String fileName, Uint8List bytes);

  /// JSON 파일을 고르게 하고 내용을 UTF-8 문자열로 돌려준다. 취소하면 null.
  Future<String?> pickJson();
}

/// file_picker 구현. Android 는 저장소 접근 틀(SAF)을 써서 별도 권한이 필요 없다.
class FilePickerBackupFileStore implements BackupFileStore {
  const FilePickerBackupFileStore();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
    );
    return uri != null;
  }

  @override
  Future<String?> pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }
}
