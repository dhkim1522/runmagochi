// 페이즈 6 작업 1: 캐릭터 후보 a·b·c (병아리 1~4단계 idle·run, 표정 normal).
import 'package:flutter_test/flutter_test.dart';

import '../../tool/sprites/candidates/candidates.dart';
import '../../tool/sprites/pet_art.dart';
import '../../tool/sprites/sprite_data.dart';

void main() {
  test('후보는 a·b·c 셋이고 각각 4단계다', () {
    expect(candidates.map((c) => c.id), ['a', 'b', 'c']);
    for (final c in candidates) {
      expect(c.kind.stages, hasLength(4), reason: c.id);
    }
  });

  for (final c in candidates) {
    bool opaque(SpriteFrame f, int x, int y) =>
        pixelAt(f, c.palette, x, y) != null;

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

    Set<String> chars(int s) => {
      for (final a in candidateActions)
        for (final f in c.body(s, a))
          for (final r in f.rows) ...r.split(''),
    };

    group('후보 ${c.id}', () {
      test('body·face 프레임이 검사를 통과하고 idle 2·run 4 프레임이다', () {
        for (final a in candidateActions) {
          final faces = c.face(a);
          expect(faces, hasLength(petActionFrames[a]), reason: '${c.id} $a');
          for (var i = 0; i < faces.length; i++) {
            expect(
              validateFrame('${c.id} face $a #$i', faces[i], c.palette),
              isEmpty,
            );
          }
          for (var s = 0; s < 4; s++) {
            final frames = c.body(s, a);
            expect(frames, hasLength(petActionFrames[a]));
            for (var i = 0; i < frames.length; i++) {
              final name = '${c.id} s${s + 1} $a #$i';
              expect(validateFrame(name, frames[i], c.palette), isEmpty);
              expect(topY(frames[i]), isNot(-1), reason: '$name 빈 프레임');
            }
          }
        }
      });

      test('발끝: idle 은 y=29, 달리기는 y=29 또는 공중 y=28', () {
        for (var s = 0; s < 4; s++) {
          for (final f in c.body(s, 'idle')) {
            expect(bottomY(f), footY, reason: '${c.id} s${s + 1} idle');
          }
          final run = c.body(s, 'run').map(bottomY).toList();
          expect(run, everyElement(anyOf(footY, footY - 1)));
          expect(run, contains(footY - 1), reason: '${c.id} s${s + 1} 공중');
        }
      });

      test('1~4단계로 갈수록 키가 커진다', () {
        final tops = [
          for (var s = 0; s < 4; s++) topY(c.body(s, 'idle').first),
        ];
        for (var s = 1; s < 4; s++) {
          expect(tops[s], lessThanOrEqualTo(tops[s - 1]), reason: '$tops');
        }
        expect(tops[3], lessThan(tops[0]), reason: '$tops');
      });

      test('idle 2·run 4 프레임이 서로 다르다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in candidateActions) {
            final keys = [for (final f in c.body(s, a)) f.rows.join('\n')];
            expect(
              keys.toSet(),
              hasLength(keys.length),
              reason: '${c.id} s${s + 1} $a',
            );
          }
        }
      });

      test('face 는 4단계 모두 몸 위에 있고 머리와 같이 움직인다', () {
        for (var s = 0; s < 4; s++) {
          for (final a in candidateActions) {
            expect(
              [
                for (final p in posesFor(c.kind.stages[s], a, c.poses))
                  p.headDy,
              ],
              headOffsets(a, c.poses),
              reason: '${c.id} s${s + 1} $a',
            );
            final bodies = c.body(s, a);
            final faces = c.face(a);
            for (var i = 0; i < bodies.length; i++) {
              for (var y = 0; y < spriteSize; y++) {
                for (var x = 0; x < spriteSize; x++) {
                  if (!opaque(faces[i], x, y)) continue;
                  expect(
                    opaque(bodies[i], x, y),
                    isTrue,
                    reason: '${c.id} s${s + 1} $a #$i ($x,$y)',
                  );
                }
              }
            }
          }
        }
      });

      test('장비: 단계마다 하나씩 는다(결정 0013)', () {
        // r 러닝화, a 손목·헤어 밴드, d·e 완주 메달.
        final s1 = chars(0), s2 = chars(1), s3 = chars(2), s4 = chars(3);
        expect(s1.intersection({'r', 'a', 'd', 'e'}), isEmpty);
        expect(
          s2.contains('r') && !s2.contains('a') && !s2.contains('e'),
          isTrue,
        );
        expect(s3.containsAll({'r', 'a'}) && !s3.contains('e'), isTrue);
        expect(s4.containsAll({'r', 'a', 'd', 'e'}), isTrue);
        expect(c.kind.stages[2].body.rows.join().contains('a'), isFalse);
        expect(c.kind.stages[3].body.rows.join().contains('a'), isTrue);
      });
    });
  }
}
