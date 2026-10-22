// 캐릭터 콘셉트 미리보기를 그린다.
// 사용: fvm dart run tool/render_concepts.dart
// 결과: design/character/concepts.png (안마다 한 줄: 1단계, 4단계, 8배 확대).
// 그림은 실제 펫 데이터(tool/sprites/<kind>.dart)에서 가져온다(tool/sprites/concepts.dart).
import 'dart:io';

import 'package:image/image.dart' as img;

import 'sprites/concepts.dart';
import 'sprites/sprite_data.dart';

const int _scale = 8;
const int _gap = 24;
const int _bg = 0xFFFFF7ED; // cream

void main() {
  final problems = <String>[];
  concepts.forEach((name, frames) {
    for (var i = 0; i < frames.length; i++) {
      problems.addAll(
        validateFrame('$name-${i + 1}', frames[i], conceptPalette),
      );
    }
  });
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
    return;
  }

  final tile = spriteSize * _scale;
  final cols = concepts.values.first.length;
  final rows = concepts.length;
  final canvas = img.Image(
    width: cols * tile + (cols + 1) * _gap,
    height: rows * tile + (rows + 1) * _gap,
  );
  img.fill(canvas, color: _color(_bg));

  var r = 0;
  concepts.forEach((name, frames) {
    for (var c = 0; c < frames.length; c++) {
      final ox = _gap + c * (tile + _gap);
      final oy = _gap + r * (tile + _gap);
      for (var y = 0; y < spriteSize; y++) {
        for (var x = 0; x < spriteSize; x++) {
          final argb = pixelAt(frames[c], conceptPalette, x, y);
          if (argb == null) continue;
          img.fillRect(
            canvas,
            x1: ox + x * _scale,
            y1: oy + y * _scale,
            x2: ox + (x + 1) * _scale - 1,
            y2: oy + (y + 1) * _scale - 1,
            color: _color(argb),
          );
        }
      }
    }
    r++;
  });

  final out = File('design/character/concepts.png');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('${out.path} (${concepts.keys.join(', ')})');
}

img.Color _color(int argb) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);
