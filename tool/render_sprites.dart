// 펫 스프라이트 시트와 미리보기를 그린다(작업 9).
// 사용: fvm dart run tool/render_sprites.dart (저장소 루트에서)
// 결과:
//   assets/sprites/<kind>/body/stage<n>_<action>.png
//   assets/sprites/<kind>/face/<mood>_<action>.png
//   assets/sprites/<kind>/<hat|accessory>/<id>_<action>.png
//   design/character/<kind>.png — 8배 미리보기. 줄 = 단계 1~4(normal 표정을 겹침),
//   칸 = idle 2 · walk 4 · run 4. 마지막 줄 = 표정(normal·sleepy·asleep) × 단계 1·4.
//   design/character/items.png — 8배 아이템 미리보기. 줄 = 아이템 없음 + 아이템 6개,
//   칸 = 종류 3 × 단계 1~4 (idle 첫 프레임).
//   assets/badges/<배지 id>.png — 24×24 배지(페이즈 6 작업 6).
//   design/character/badges.png — 8배 배지 미리보기. 위 = 받은 모습, 아래 = 못 받은 모습.
// 그리기 로직은 tool/sprites/render.dart (동기 검사 테스트와 공유).
import 'dart:io';

import 'package:image/image.dart' as img;

import 'sprites/badges.dart';
import 'sprites/items.dart';
import 'sprites/pet_art.dart';
import 'sprites/pets.dart';
import 'sprites/render.dart';
import 'sprites/sprite_data.dart';

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
    for (final item in items) {
      for (final a in petActions) {
        final frames = itemFrames(pet, item, a);
        for (var i = 0; i < frames.length; i++) {
          problems.addAll(
            validateFrame(
              '${pet.name} ${item.id} $a #$i',
              frames[i],
              petPalette,
            ),
          );
        }
      }
    }
  }
  for (final b in badges) {
    problems.addAll(validateBadge(b));
  }
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
    return;
  }

  final sheets = allSheets();
  sheets.forEach(_save);
  for (final pet in pets) {
    _save('design/character/${pet.name}.png', preview(pet));
  }
  _save('design/character/items.png', itemsPreview());
  final badgePngs = badgeImages();
  badgePngs.forEach(_save);
  _save('design/character/badges.png', badgesPreview());
  stdout.writeln(
    '시트 ${sheets.length}개, 배지 ${badgePngs.length}개, 미리보기 ${pets.length + 2}개',
  );
}

void _save(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
}
