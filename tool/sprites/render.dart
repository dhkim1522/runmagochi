// 스프라이트 시트·미리보기를 메모리에서 그리는 순수 로직.
// tool/render_sprites.dart(파일 저장)와 test/tool/sprite_render_sync_test.dart(PNG 동기 검사)가 함께 쓴다.
import 'package:image/image.dart' as img;

import 'pet_art.dart';
import 'pets.dart';
import 'sprite_data.dart';

const int _scale = 8;
const int _gap = 16;
const int _groupGap = 48;
const int _bg = 0xFFFFF7ED; // cream

/// 저장소 루트 기준 경로 → 시트 이미지. 모든 종류 × 단계 × 동작(몸), 표정 × 동작(얼굴).
Map<String, img.Image> allSheets() {
  final out = <String, img.Image>{};
  for (final pet in pets) {
    for (var s = 0; s < pet.stages.length; s++) {
      for (final a in petActions) {
        out['assets/sprites/${pet.name}/body/stage${s + 1}_$a.png'] = sheet(
          bodyFrames(pet.stages[s], a),
        );
      }
    }
    for (final m in petMoods) {
      for (final a in petActions) {
        out['assets/sprites/${pet.name}/face/${m}_$a.png'] = sheet(
          faceFrames(pet, m, a),
        );
      }
    }
  }
  return out;
}

img.Image sheet(List<SpriteFrame> frames) {
  final im = img.Image(
    width: frames.length * spriteSize,
    height: spriteSize,
    numChannels: 4,
  );
  for (var i = 0; i < frames.length; i++) {
    drawFrame(im, frames[i], i * spriteSize, 0, 1);
  }
  return im;
}

void drawFrame(img.Image im, SpriteFrame f, int ox, int oy, int scale) {
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

img.Image preview(PetKind pet) {
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
        drawFrame(im, bodies[i], colX[c], oy, _scale);
        drawFrame(im, faces[i], colX[c], oy, _scale);
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
      drawFrame(im, body, colX[c], oy, _scale);
      drawFrame(im, face, colX[c], oy, _scale);
      c++;
    }
  }
  return im;
}

img.Color _color(int argb) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);
