import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 이미지 파일을 OS 공유 창으로 보낸다. 테스트는 가짜로 바꾼다.
abstract interface class Sharer {
  Future<void> shareImage(String path, {String? text});
}

/// share_plus 로 시스템 공유 창을 연다.
class SharePlusSharer implements Sharer {
  const SharePlusSharer();

  @override
  Future<void> shareImage(String path, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}

final sharerProvider = Provider<Sharer>((_) => const SharePlusSharer());

/// 공유 이미지를 쓸 임시 폴더. 테스트는 다른 폴더로 바꾼다.
final shareTempDirProvider = Provider<Future<Directory> Function()>(
  (_) => getTemporaryDirectory,
);
