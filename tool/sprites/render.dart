// 스프라이트 시트·미리보기를 메모리에서 그리는 순수 로직.
// tool/render_sprites.dart(파일 저장)와 test/tool/sprite_render_sync_test.dart(PNG 동기 검사)가 함께 쓴다.
import 'package:image/image.dart' as img;

import 'badges.dart';
import 'egg.dart';
import 'items.dart';
import 'pet_art.dart';
import 'pets.dart';
import 'sprite_data.dart';

const int _scale = 8;
const int _gap = 16;
const int _groupGap = 48;

/// 미리보기 바탕색(cream).
const int previewBg = 0xFFFFF7ED;

/// 저장소 루트 기준 경로 → 시트 이미지. 모든 종류 × 단계 × 동작(몸), 표정 × 동작(얼굴),
/// 아이템 × 동작(모자·소품).
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
    for (final item in items) {
      for (final a in petActions) {
        out['assets/sprites/${pet.name}/${item.slot}/${item.id}_$a.png'] =
            sheet(itemFrames(pet, item, a));
      }
    }
  }
  // 부화 연출 알(F33).
  out['assets/sprites/egg/hatch.png'] = sheet(hatchFrames);
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

void drawFrame(
  img.Image im,
  SpriteFrame f,
  int ox,
  int oy,
  int scale, {
  Palette palette = petPalette,
}) {
  for (var y = 0; y < spriteSize; y++) {
    for (var x = 0; x < spriteSize; x++) {
      final argb = pixelAt(f, palette, x, y);
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
  img.fill(im, color: _color(previewBg));

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

/// 아이템 미리보기. 줄 = 아이템 없음 + 아이템 6개, 칸 = 종류 3 × 단계 1~4 (idle 첫 프레임).
img.Image itemsPreview() {
  final tile = spriteSize * _scale;
  final cols = <(PetKind, int)>[
    for (final pet in pets)
      for (var s = 0; s < pet.stages.length; s++) (pet, s),
  ];
  final colX = <int>[];
  var x = _gap;
  for (var c = 0; c < cols.length; c++) {
    if (c > 0 && cols[c].$1 != cols[c - 1].$1) x += _groupGap - _gap;
    colX.add(x);
    x += tile + _gap;
  }
  final width = x + _gap;
  final rows = <ItemArt?>[null, ...items];
  final height = rows.length * (tile + _gap) + _gap;
  final im = img.Image(width: width, height: height);
  img.fill(im, color: _color(previewBg));
  for (var r = 0; r < rows.length; r++) {
    final oy = _gap + r * (tile + _gap);
    for (var c = 0; c < cols.length; c++) {
      final (pet, s) = cols[c];
      drawFrame(
        im,
        bodyFrames(pet.stages[s], 'idle').first,
        colX[c],
        oy,
        _scale,
      );
      drawFrame(
        im,
        faceFrames(pet, 'normal', 'idle').first,
        colX[c],
        oy,
        _scale,
      );
      final item = rows[r];
      if (item != null) {
        drawFrame(im, itemFrames(pet, item, 'idle').first, colX[c], oy, _scale);
      }
    }
  }
  return im;
}

/// 배지 PNG(24×24). 저장소 루트 기준 경로 → 이미지.
Map<String, img.Image> badgeImages() => {
  for (final b in badges) 'assets/badges/${b.id}.png': badgeImage(b),
};

img.Image badgeImage(BadgeArt b) {
  final im = img.Image(width: badgeSize, height: badgeSize, numChannels: 4);
  _drawBadge(im, b, 0, 0, 1);
  return im;
}

/// 못 받은 배지 모습: 앱의 BadgeImage 와 같은 흑백 행렬(Rec. 709 밝기)에 투명도 0.45.
int _locked(int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final l = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);
  final a = (((argb >> 24) & 0xFF) * 0.45).round();
  return (a << 24) | (l << 16) | (l << 8) | l;
}

void _drawBadge(
  img.Image im,
  BadgeArt b,
  int ox,
  int oy,
  int scale, {
  bool locked = false,
}) {
  final palette = badgePalette(b.tier);
  final rows = badgeRows(b);
  for (var y = 0; y < badgeSize; y++) {
    for (var x = 0; x < badgeSize; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      final argb = palette[ch]!;
      final c = locked ? _locked(argb) : argb;
      img.fillRect(
        im,
        x1: ox + x * scale,
        y1: oy + y * scale,
        x2: ox + (x + 1) * scale - 1,
        y2: oy + (y + 1) * scale - 1,
        color: _color(c),
      );
    }
  }
}

/// 배지 미리보기(8배). 위 두 줄 = 받은 배지 12개(목록 순서, 한 줄 6개),
/// 아래 두 줄 = 같은 배지의 못 받은 모습(회색·투명도 0.45).
img.Image badgesPreview() {
  const cols = 6;
  final tile = badgeSize * _scale;
  final rowsPerSet = (badges.length + cols - 1) ~/ cols;
  final width = cols * (tile + _gap) + _gap;
  final height = rowsPerSet * 2 * (tile + _gap) + _gap + (_groupGap - _gap);
  final im = img.Image(width: width, height: height);
  img.fill(im, color: _color(previewBg));
  for (final locked in [false, true]) {
    for (var i = 0; i < badges.length; i++) {
      final r = i ~/ cols + (locked ? rowsPerSet : 0);
      final ox = _gap + (i % cols) * (tile + _gap);
      final oy = _gap + r * (tile + _gap) + (locked ? _groupGap - _gap : 0);
      _drawBadge(im, badges[i], ox, oy, _scale, locked: locked);
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
