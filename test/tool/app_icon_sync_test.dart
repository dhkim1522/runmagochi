import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/sprites/app_icon.dart';

// 아이콘 그리기(tool/sprites/app_icon.dart)나 토큰 색을 고치고 리소스를 다시 만들지 않으면 실패한다.
void main() {
  const hint =
      '`fvm dart run tool/render_app_icon.dart` 를 실행해 아이콘·스플래시를 다시 만드세요';
  final colors = loadIconColors();

  test('커밋된 아이콘·스플래시 PNG 가 그린 결과와 픽셀까지 같다', () {
    final pngs = appIconImages(colors);
    expect(pngs, isNotEmpty);
    for (final e in pngs.entries) {
      final file = File(e.key);
      expect(file.existsSync(), isTrue, reason: '${e.key} 없음. $hint');
      final disk = img.decodePng(file.readAsBytesSync())!;
      final mem = e.value;
      expect(
        [disk.width, disk.height, disk.numChannels],
        [mem.width, mem.height, mem.numChannels],
        reason: '${e.key} 크기·채널이 다름. $hint',
      );
      var diff = 0;
      for (var y = 0; y < mem.height; y++) {
        for (var x = 0; x < mem.width; x++) {
          final a = disk.getPixel(x, y), b = mem.getPixel(x, y);
          if (a.r != b.r || a.g != b.g || a.b != b.b || a.a != b.a) diff++;
        }
      }
      expect(diff, 0, reason: '${e.key} 픽셀 $diff개가 다름. $hint');
    }
  });

  test('커밋된 아이콘·스플래시 글자 파일이 만든 결과와 같다', () {
    for (final e in appIconTexts(colors).entries) {
      final file = File(e.key);
      expect(file.existsSync(), isTrue, reason: '${e.key} 없음. $hint');
      expect(file.readAsStringSync(), e.value, reason: '${e.key} 다름. $hint');
    }
  });
}
