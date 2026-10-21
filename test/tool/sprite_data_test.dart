import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/shop/domain/catalog.dart';

import '../../tool/sprites/items.dart';
import '../../tool/sprites/pet_art.dart';
import '../../tool/sprites/pets.dart';
import '../../tool/sprites/sprite_data.dart';

void main() {
  bool opaque(SpriteFrame f, int x, int y) =>
      pixelAt(f, petPalette, x, y) != null;

  String charAt(SpriteFrame f, int x, int y) {
    final left = (spriteSize - f.width) ~/ 2;
    final top = footY + 1 - f.height;
    final fx = x - left;
    final fy = y - top;
    if (fx < 0 || fy < 0 || fx >= f.width || fy >= f.height) return '.';
    return f.rows[fy][fx];
  }

  int bottomY(SpriteFrame f) {
    for (var y = spriteSize - 1; y >= 0; y--) {
      for (var x = 0; x < spriteSize; x++) {
        if (opaque(f, x, y)) return y;
      }
    }
    return -1;
  }

  int topY(SpriteFrame f) {
    for (var y = 0; y < spriteSize; y++) {
      for (var x = 0; x < spriteSize; x++) {
        if (opaque(f, x, y)) return y;
      }
    }
    return -1;
  }

  Set<String> chars(StageArt s) => {
    for (final a in petActions)
      for (final f in bodyFrames(s, a))
        for (final r in f.rows) ...r.split(''),
  };

  test('종류는 chick·jelly·acorn 셋이고 각각 4단계다', () {
    expect(pets.map((p) => p.name), ['chick', 'jelly', 'acorn']);
    for (final p in pets) {
      expect(p.stages, hasLength(4), reason: p.name);
    }
  });

  test('아이템 그림은 상점 목록과 id·부위가 같다', () {
    expect(
      [for (final i in items) (i.id, i.slot)],
      [for (final i in catalog) (i.id, i.slot.name)],
    );
  });

  for (final pet in pets) {
    group('${pet.name} 아이템', () {
      test('모든 아이템 프레임이 검사를 통과하고 프레임 수가 맞다', () {
        for (final item in items) {
          for (final a in petActions) {
            final frames = itemFrames(pet, item, a);
            expect(frames, hasLength(petActionFrames[a]));
            for (var i = 0; i < frames.length; i++) {
              final name = '${pet.name} ${item.id} $a #$i';
              expect(validateFrame(name, frames[i], petPalette), isEmpty);
              expect(frames[i].width, spriteSize, reason: name);
              expect(frames[i].height, footY + 1, reason: name);
              expect(topY(frames[i]), isNot(-1), reason: '$name 빈 프레임');
            }
          }
        }
      });

      test('프레임마다 아이템 세로 이동이 face 세로 이동과 같다', () {
        final face0 = topY(faceFrames(pet, 'normal', 'idle').first);
        for (final item in items) {
          final item0 = topY(itemFrames(pet, item, 'idle').first);
          for (final a in petActions) {
            final faces = faceFrames(pet, 'normal', a);
            final frames = itemFrames(pet, item, a);
            for (var i = 0; i < frames.length; i++) {
              expect(
                topY(frames[i]) - item0,
                topY(faces[i]) - face0,
                reason: '${pet.name} ${item.id} $a #$i',
              );
            }
          }
        }
      });

      test('모자는 face 픽셀을 가리지 않는다', () {
        for (final item in items.where((i) => i.slot == 'hat')) {
          for (final a in petActions) {
            final frames = itemFrames(pet, item, a);
            for (final m in petMoods) {
              final faces = faceFrames(pet, m, a);
              for (var i = 0; i < frames.length; i++) {
                for (var y = 0; y < spriteSize; y++) {
                  for (var x = 0; x < spriteSize; x++) {
                    final ch = charAt(faces[i], x, y);
                    if (ch == '.' || ch == sleepZ) continue;
                    expect(
                      opaque(frames[i], x, y),
                      isFalse,
                      reason: '${pet.name} ${item.id} $a #$i $m ($x,$y)',
                    );
                  }
                }
              }
            }
          }
        }
      });
    });

    group(pet.name, () {
      test('모든 body·face 프레임이 검사를 통과하고 프레임 수가 맞다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            final frames = bodyFrames(pet.stages[s], a);
            expect(frames, hasLength(petActionFrames[a]));
            for (var i = 0; i < frames.length; i++) {
              expect(
                validateFrame(
                  '${pet.name} s${s + 1} $a #$i',
                  frames[i],
                  petPalette,
                ),
                isEmpty,
              );
            }
          }
        }
        for (final m in petMoods) {
          for (final a in petActions) {
            final frames = faceFrames(pet, m, a);
            expect(frames, hasLength(petActionFrames[a]));
            for (var i = 0; i < frames.length; i++) {
              expect(
                validateFrame('${pet.name} $m $a #$i', frames[i], petPalette),
                isEmpty,
              );
            }
          }
        }
      });

      test('4단계 모두 머리 오프셋이 face 와 같다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            expect(
              [for (final p in posesFor(pet.stages[s], a)) p.headDy],
              headOffsets(a),
              reason: '${pet.name} s${s + 1} $a',
            );
          }
        }
      });

      test('face 픽셀(z 제외)은 모두 4단계 body 의 불투명 픽셀 위에 있다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            final bodies = bodyFrames(pet.stages[s], a);
            for (final m in petMoods) {
              final faces = faceFrames(pet, m, a);
              for (var i = 0; i < bodies.length; i++) {
                for (var y = 0; y < spriteSize; y++) {
                  for (var x = 0; x < spriteSize; x++) {
                    final ch = charAt(faces[i], x, y);
                    if (ch == '.' || ch == sleepZ) continue;
                    expect(
                      opaque(bodies[i], x, y),
                      isTrue,
                      reason: '${pet.name} s${s + 1} $a #$i $m ($x,$y)',
                    );
                  }
                }
              }
            }
          }
        }
      });

      test('잠든 z 는 body 와 겹치지 않는다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            final bodies = bodyFrames(pet.stages[s], a);
            final faces = faceFrames(pet, 'asleep', a);
            for (var i = 0; i < bodies.length; i++) {
              for (var y = 0; y < spriteSize; y++) {
                for (var x = 0; x < spriteSize; x++) {
                  if (charAt(faces[i], x, y) != sleepZ) continue;
                  expect(
                    opaque(bodies[i], x, y),
                    isFalse,
                    reason: '${pet.name} s${s + 1} $a #$i ($x,$y)',
                  );
                }
              }
            }
          }
        }
      });

      test('각 동작의 body 프레임끼리 서로 다르다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            final keys = bodyFrames(
              pet.stages[s],
              a,
            ).map((f) => f.rows.join('\n')).toList();
            expect(
              keys.toSet(),
              hasLength(keys.length),
              reason: '${pet.name} s${s + 1} $a',
            );
          }
        }
      });

      test('발끝: idle 은 y=29, 걷기·달리기는 y=29 또는 공중 y=28', () {
        for (var s = 0; s < 4; s++) {
          for (final a in petActions) {
            final frames = bodyFrames(pet.stages[s], a);
            for (var i = 0; i < frames.length; i++) {
              final b = bottomY(frames[i]);
              final reason = '${pet.name} s${s + 1} $a #$i';
              if (a == 'idle') {
                expect(b, footY, reason: reason);
              } else {
                expect(b, anyOf(footY, footY - 1), reason: reason);
              }
            }
            if (a == 'run') {
              final bottoms = bodyFrames(pet.stages[s], a).map(bottomY);
              expect(
                bottoms,
                contains(footY - 1),
                reason: '${pet.name} s${s + 1} 달리기 공중 프레임',
              );
            }
          }
        }
      });

      test('펫 러너 장비: 단계마다 하나씩 는다(결정 0013)', () {
        // r 러닝화, a 손목·헤어 밴드, d·e 완주 메달.
        final s1 = chars(pet.stages[0]);
        final s2 = chars(pet.stages[1]);
        final s3 = chars(pet.stages[2]);
        final s4 = chars(pet.stages[3]);
        expect(s1.intersection({'r', 'a', 'd', 'e'}), isEmpty);
        expect(
          s2.contains('r') && !s2.contains('a') && !s2.contains('e'),
          isTrue,
        );
        expect(s3.containsAll({'r', 'a'}) && !s3.contains('e'), isTrue);
        expect(s4.containsAll({'r', 'a', 'd', 'e'}), isTrue);
        // 헤어밴드는 4단계 기본 그림에만 있다.
        expect(pet.stages[2].body.rows.join().contains('a'), isFalse);
        expect(pet.stages[3].body.rows.join().contains('a'), isTrue);
      });
    });
  }
}
