import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/sprites/render.dart';

// 스프라이트·배지 데이터(tool/sprites/*.dart)를 고치고 PNG 를 다시 만들지 않으면 실패한다.
void main() {
  const hint = '`fvm dart run tool/render_sprites.dart` 를 실행해 PNG 를 다시 만드세요';

  void expectSynced(Map<String, img.Image> pngs) {
    expect(pngs, isNotEmpty);
    for (final e in pngs.entries) {
      final file = File(e.key);
      expect(file.existsSync(), isTrue, reason: '${e.key} 없음. $hint');
      final disk = img.decodePng(file.readAsBytesSync())!;
      final mem = e.value;
      expect(
        [disk.width, disk.height],
        [mem.width, mem.height],
        reason: '${e.key} 크기가 다름. $hint',
      );
      var diff = 0;
      for (var y = 0; y < mem.height; y++) {
        for (var x = 0; x < mem.width; x++) {
          final a = disk.getPixel(x, y), b = mem.getPixel(x, y);
          if (a.r != b.r || a.g != b.g || a.b != b.b || a.a != b.a) diff++;
        }
      }
      expect(diff, 0, reason: '${e.key} 픽셀 $diff개가 데이터와 다름. $hint');
    }
  }

  test('커밋된 스프라이트 PNG 가 데이터에서 그린 결과와 픽셀까지 같다', () {
    expectSynced(allSheets());
  });

  test('커밋된 배지 PNG 가 데이터에서 그린 결과와 픽셀까지 같다', () {
    final pngs = badgeImages();
    expect(pngs, hasLength(12));
    expectSynced(pngs);
  });
}
