import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/ui/sprite_sheet.dart';
import 'package:runmagochi/shop/domain/catalog.dart';

void main() {
  void expectSheet(String path, AvatarAction a) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path 없음');
    final image = img.decodePng(file.readAsBytesSync())!;
    expect(image.width, frameCount(a) * spriteFramePx, reason: path);
    expect(image.height, spriteFramePx, reason: path);
  }

  test('동작별 프레임 수와 fps', () {
    expect(frameCount(AvatarAction.idle), 2);
    expect(frameCount(AvatarAction.walk), 4);
    expect(frameCount(AvatarAction.run), 4);
    expect(fps(AvatarAction.idle), 4);
    expect(fps(AvatarAction.walk), 6);
    expect(fps(AvatarAction.run), 10);
  });

  test('시트 경로 규칙', () {
    expect(
      bodySheet(AvatarKind.jelly, 1, AvatarAction.run),
      'assets/sprites/jelly/body/stage1_run.png',
    );
    expect(
      faceSheet(AvatarKind.acorn, AvatarMood.sleepy, AvatarAction.idle),
      'assets/sprites/acorn/face/sleepy_idle.png',
    );
    expect(spriteLayerOrder.first, 'body');
  });

  test('모든 body 시트가 (프레임 수 × 32) × 32 이다', () {
    for (final k in AvatarKind.values) {
      for (var stage = 1; stage <= 4; stage++) {
        for (final a in AvatarAction.values) {
          expectSheet(bodySheet(k, stage, a), a);
        }
      }
    }
  });

  test('아이템 시트 경로 규칙', () {
    expect(
      itemSheet(AvatarKind.chick, itemById('cap')!, AvatarAction.walk),
      'assets/sprites/chick/hat/cap_walk.png',
    );
    expect(
      itemSheet(AvatarKind.acorn, itemById('flower_pin')!, AvatarAction.idle),
      'assets/sprites/acorn/accessory/flower_pin_idle.png',
    );
  });

  test('모든 아이템 시트(6개 × 3종 × 3동작)가 (프레임 수 × 32) × 32 이다', () {
    var n = 0;
    for (final k in AvatarKind.values) {
      for (final item in catalog) {
        for (final a in AvatarAction.values) {
          expectSheet(itemSheet(k, item, a), a);
          n++;
        }
      }
    }
    expect(n, 6 * 3 * 3);
  });

  test('모든 face 시트가 (프레임 수 × 32) × 32 이다', () {
    for (final k in AvatarKind.values) {
      for (final m in AvatarMood.values) {
        for (final a in AvatarAction.values) {
          expectSheet(faceSheet(k, m, a), a);
        }
      }
    }
  });
}
