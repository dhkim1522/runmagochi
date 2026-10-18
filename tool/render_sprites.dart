// 펫 스프라이트 시트와 미리보기를 그린다(작업 9).
// 사용: fvm dart run tool/render_sprites.dart (저장소 루트에서)
// 결과:
//   assets/sprites/<kind>/body/stage<n>_<action>.png
//   assets/sprites/<kind>/face/<mood>_<action>.png
//   design/character/<kind>.png — 8배 미리보기. 줄 = 단계 1~4(normal 표정을 겹침),
//   칸 = idle 2 · walk 4 · run 4. 마지막 줄 = 표정(normal·sleepy·asleep) × 단계 1·4.
import 'dart:io';

import 'package:image/image.dart' as img;

import 'sprites/pet_art.dart';
import 'sprites/pets.dart';
import 'sprites/sprite_data.dart';

const int _scale = 8;
const int _gap = 16;
const int _groupGap = 48;
const int _bg = 0xFFFFF7ED; // cream

void main() {
  final problems = <String>[];
  for (final pet in pets) {
    for (var s = 0; s < pet.stages.length; s++) {
      for (final a in petActions) {
        final frames = bodyFrames(pet.stages[s], a);
        for (var i = 0; i < frames.length; i++) {
          problems.addAll(
            validateFrame(
              '${pet.name} s${s + 1} $a #$i',
              frames[i],
              petPalette,
            ),
          );
        }
      }
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
    return;
  }

  var sheets = 0;
  for (final pet in pets) {
    for (var s = 0; s < pet.stages.length; s++) {
      for (final a in petActions) {
        _save(
          'assets/sprites/${pet.name}/body/stage${s + 1}_$a.png',
          _sheet(bodyFrames(pet.stages[s], a)),
        );
        sheets++;
      }
    }
    for (final m in petMoods) {
      for (final a in petActions) {
        _save(
          'assets/sprites/${pet.name}/face/${m}_$a.png',
          _sheet(faceFrames(pet, m, a)),
        );
        sheets++;
      }
    }
    _save('design/character/${pet.name}.png', _preview(pet));
  }
  stdout.writeln('시트 $sheets개, 미리보기 ${pets.length}개');
}

img.Image _sheet(List<SpriteFrame> frames) {
  final im = img.Image(
    width: frames.length * spriteSize,
    height: spriteSize,
    numChannels: 4,
  );
  for (var i = 0; i < frames.length; i++) {
    _draw(im, frames[i], i * spriteSize, 0, 1);
  }
  return im;
}

void _draw(img.Image im, SpriteFrame f, int ox, int oy, int scale) {
  for (var y = 0; y < spriteSize; y++) {
    for (var x = 0; x < spriteSize; x++) {
      final argb = pixelAt(f, petPalette, x, y);
      if (argb == null) continue;
      img.fillRect(
        im,
        x1: ox + x * scale,
        y1: oy + y * scale,
        x2: ox + (x + 1) * scale - 1,
        y2: oy + (y + 1) * scale - 1,
        color: _color(argb),
      );
    }
  }
}

img.Image _preview(PetKind pet) {
  final tile = spriteSize * _scale;
  // 칸: idle 2 + walk 4 + run 4, 동작 사이는 넓게 띄운다.
  final colX = <int>[];
  var x = _gap;
  for (final a in petActions) {
    for (var i = 0; i < petActionFrames[a]!; i++) {
      colX.add(x);
      x += tile + _gap;
    }
    x += _groupGap - _gap;
  }
  final width = x - _groupGap + _gap * 2;
  final rows = pet.stages.length + 1;
  final height = rows * (tile + _gap) + _gap;
  final im = img.Image(width: width, height: height);
  img.fill(im, color: _color(_bg));

  for (var s = 0; s < pet.stages.length; s++) {
    var c = 0;
    for (final a in petActions) {
      final bodies = bodyFrames(pet.stages[s], a);
      final faces = faceFrames(pet, 'normal', a);
      for (var i = 0; i < bodies.length; i++) {
        final oy = _gap + s * (tile + _gap);
        _draw(im, bodies[i], colX[c], oy, _scale);
        _draw(im, faces[i], colX[c], oy, _scale);
        c++;
      }
    }
  }
  // 표정 줄: 단계 1·4 idle 첫 프레임에 세 표정.
  final oy = _gap + pet.stages.length * (tile + _gap);
  var c = 0;
  for (final m in petMoods) {
    for (final s in [0, 3]) {
      final body = bodyFrames(pet.stages[s], 'idle').first;
      final face = faceFrames(pet, m, 'idle').first;
      _draw(im, body, colX[c], oy, _scale);
      _draw(im, face, colX[c], oy, _scale);
      c++;
    }
  }
  return im;
}

void _save(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
}

img.Color _color(int argb) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);
