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

  test('자세표는 머리를 올리기만 한다(k ≤ 0, 눌림은 squashRow 줄을 지운다)', () {
    for (final set in [petPoses.walker, petPoses.hopper]) {
      for (final e in set.entries) {
        for (final p in e.value) {
          expect(p.k, lessThanOrEqualTo(0), reason: e.key);
        }
      }
    }
  });

  group('말랑 클레이 그림체(페이즈 6 후보 a, 3종 공통)', () {
    // 종류 → 단계별 3단 명암(하이라이트·기본·그림자). 도토리는 모자도 3단이다.
    const tones = <String, List<List<String>>>{
      'chick': [
        ['q', 'y', 'Y'],
        ['l', 'm', 'M'],
        ['l', 'm', 'M'],
        ['l', 'm', 'M'],
      ],
      'jelly': [
        ['i', 'b', 'B'],
        ['i', 'b', 'B'],
        ['i', 'b', 'B'],
        ['i', 'b', 'B'],
      ],
      'acorn': [
        ['t', 'n', 'N', 'x', 'C', 'c'],
        ['t', 'n', 'N', 'x', 'C', 'c'],
        ['t', 'n', 'N', 'x', 'C', 'c'],
        ['t', 'n', 'N', 'x', 'C', 'c'],
      ],
    };

    test('몸은 단계마다 3단 명암(하이라이트·기본·그림자)이다', () {
      expect(tones.keys, [for (final p in pets) p.name]);
      for (final pet in pets) {
        for (var s = 0; s < 4; s++) {
          expect(
            pet.stages[s].body.rows.join().split('').toSet(),
            containsAll(tones[pet.name]![s]),
            reason: '${pet.name} s${s + 1}',
          );
        }
      }
    });

    test('기본 그림은 줄 너비가 모두 같고 짝수다', () {
      for (final pet in pets) {
        for (var s = 0; s < 4; s++) {
          final rows = pet.stages[s].body.rows;
          final w = rows.first.length;
          expect(w.isEven, isTrue, reason: '${pet.name} s${s + 1}');
          for (var y = 0; y < rows.length; y++) {
            expect(rows[y].length, w, reason: '${pet.name} s${s + 1} 줄 $y');
          }
        }
      }
    });

    for (final pet in pets) {
      test('${pet.name} 4단계 메달 끈은 목 아래 가로줄 y=25 에만 있고 메달은 그 아래다', () {
        // 입 바로 아래 세로 끈은 입처럼 보여서 쓰지 않는다.
        for (final a in petActions) {
          final frames = bodyFrames(pet.stages[3], a);
          final poses = posesFor(pet.stages[3], a);
          for (var i = 0; i < frames.length; i++) {
            final strapY = 25 - poses[i].lift;
            final reason = '${pet.name} $a #$i';
            var strap = 0;
            for (var y = 0; y < spriteSize; y++) {
              for (var x = 0; x < spriteSize; x++) {
                final ch = charAt(frames[i], x, y);
                if (ch == 'd' || ch == 'D') {
                  expect(y, strapY, reason: '$reason ($x,$y)');
                  strap++;
                }
                if (ch == 'e') expect(y, greaterThan(strapY), reason: reason);
              }
            }
            expect(strap, greaterThanOrEqualTo(12), reason: reason);
          }
        }
      });
    }

    List<(int, int)> facePixels(
      PetKind pet,
      String mood,
      bool Function(String, int, int) want,
    ) {
      final f = faceFrames(pet, mood, 'idle').first;
      return [
        for (var y = 0; y < spriteSize; y++)
          for (var x = 0; x < spriteSize; x++)
            if (want(charAt(f, x, y), x, y)) (x, y),
      ];
    }

    bool eyeRow(int y) => y == 20 || y == 21;

    for (final pet in pets) {
      test('${pet.name} 표정 세 가지의 눈은 normal 눈 자리(y=20·21) 둘레, 볼·입은 같은 자리다', () {
        final cheeks = facePixels(pet, 'normal', (c, _, _) => c == 'p');
        expect(cheeks, isNotEmpty);
        // 입(젤리·도토리)은 눈 줄 밖의 k. 병아리는 부리가 body 에 있어 없다.
        final mouth = facePixels(
          pet,
          'normal',
          (c, _, y) => c == 'k' && !eyeRow(y),
        );
        for (final m in petMoods) {
          expect(facePixels(pet, m, (c, _, _) => c == 'p'), cheeks, reason: m);
          expect(
            facePixels(pet, m, (c, _, y) => c == 'k' && !eyeRow(y)),
            mouth,
            reason: m,
          );
          final eyes = facePixels(
            pet,
            m,
            (c, _, y) => (c == 'k' || c == 'w') && eyeRow(y),
          );
          expect(eyes, isNotEmpty, reason: m);
          for (final (x, y) in eyes) {
            expect(
              (x >= 11 && x <= 14) || (x >= 17 && x <= 20),
              isTrue,
              reason: '${pet.name} $m ($x,$y)',
            );
          }
          expect(
            facePixels(pet, m, (c, _, y) => c == 'w' && !eyeRow(y)),
            isEmpty,
            reason: m,
          );
        }
      });
    }

    test('3종의 눈(y=20·21)은 표정마다 병아리와 같다', () {
      final chick = pets.first;
      for (final m in petMoods) {
        bool eye(String c, int _, int y) => (c == 'k' || c == 'w') && eyeRow(y);
        final want = facePixels(chick, m, eye);
        for (final pet in pets.skip(1)) {
          expect(facePixels(pet, m, eye), want, reason: '${pet.name} $m');
        }
      }
    });

    test('졸린 눈꺼풀은 바깥으로 처진다(안쪽 x=14·17 이 비어 화난 눈이 아니다)', () {
      for (final pet in pets) {
        final lids = facePixels(
          pet,
          'sleepy',
          (c, x, y) => c == 'k' && y == 20,
        );
        expect(lids, isNotEmpty, reason: pet.name);
        for (final (x, _) in lids) {
          expect(x, isNot(anyOf(14, 17)), reason: '${pet.name} x=$x');
        }
      }
    });
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

      // 아이템 그림은 단계를 가리지 않고 한 장이라(파일 이름에 단계가 없다) 가장 큰
      // 4단계 머리에 맞춘다. 챙 줄과 그 위의 몸은 단계와 상관없이 모두 모자에 덮이고,
      // 모자 위로 보이는 병아리 볏·젤리 잎·도토리 꼭지는 종류의 hatSprout 그림이다.
      // 그래서 4단계 모두 모자 위 모습이 같다(1단계도 잎·볏이 모자 밖으로 나온다).
      test('모자는 4단계 모두 챙 줄과 그 위의 몸을 덮는다', () {
        for (final item in items.where((i) => i.slot == 'hat')) {
          for (var s = 0; s < 4; s++) {
            for (final a in petActions) {
              final bodies = bodyFrames(pet.stages[s], a);
              final frames = itemFrames(pet, item, a);
              final dys = headOffsets(a);
              for (var i = 0; i < frames.length; i++) {
                final brim = pet.hatAnchor.y + dys[i];
                for (var y = 0; y <= brim; y++) {
                  for (var x = 0; x < spriteSize; x++) {
                    if (!opaque(bodies[i], x, y)) continue;
                    expect(
                      opaque(frames[i], x, y),
                      isTrue,
                      reason: '${pet.name} s${s + 1} ${item.id} $a #$i ($x,$y)',
                    );
                  }
                }
              }
            }
          }
        }
      });

      test('헤드폰 귀덮개는 4단계 모두 머리 옆에 붙고 머리 밖으로 나온다', () {
        // 팔(날개)을 뺀 기본 그림의 머리 폭과 idle 첫 프레임으로 잰다.
        final phones = itemFrames(
          pet,
          items.firstWhere((i) => i.id == 'headphones'),
          'idle',
        ).first;
        for (var s = 0; s < 4; s++) {
          final art = pet.stages[s].body;
          final left = (spriteSize - art.rows.first.length) ~/ 2;
          // 귀덮개 줄: 눈 윗줄부터 3줄.
          for (var y = 20; y < 23; y++) {
            final row = art.rows[y - art.top];
            final body = [
              for (var c = 0; c < row.length; c++)
                if (row[c] != '.') left + c,
            ];
            final xs = [
              for (var x = 0; x < spriteSize; x++)
                if (body.contains(x) || opaque(phones, x, y)) x,
            ];
            final reason = '${pet.name} s${s + 1} y=$y';
            expect(xs.last - xs.first + 1, xs.length, reason: '$reason 뜸');
            expect(xs.first, lessThan(body.first), reason: reason);
            expect(xs.last, greaterThan(body.last), reason: reason);
          }
        }
      });

      test('선글라스 알은 눈(normal)을 모두 덮는다', () {
        final glasses = items.firstWhere((i) => i.id == 'sunglasses');
        for (final a in petActions) {
          final frames = itemFrames(pet, glasses, a);
          final faces = faceFrames(pet, 'normal', a);
          for (var i = 0; i < frames.length; i++) {
            for (var y = 0; y < spriteSize; y++) {
              for (var x = 0; x < spriteSize; x++) {
                final ch = charAt(faces[i], x, y);
                if (ch != 'k' && ch != 'w') continue;
                if (y != 20 + headOffsets(a)[i] &&
                    y != 21 + headOffsets(a)[i]) {
                  continue;
                }
                expect(
                  opaque(frames[i], x, y),
                  isTrue,
                  reason: '${pet.name} $a #$i ($x,$y)',
                );
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

      test('4단계 헤어밴드는 눈 위 두 줄이다(한 줄은 모자 테처럼 보인다)', () {
        final art = pet.stages[3].body;
        final bandYs = [
          for (var r = 0; r < art.rows.length; r++)
            if (art.rows[r].contains('a') || art.rows[r].contains('A'))
              art.top + r,
        ];
        expect(bandYs, hasLength(2), reason: pet.name);
        expect(bandYs.last - bandYs.first, 1, reason: pet.name);
        expect(bandYs.last, lessThan(20), reason: pet.name);
      });
    });
  }

  test('젤리 잎은 단계마다 좌우 대칭이다', () {
    final jelly = pets.firstWhere((p) => p.name == 'jelly');
    for (var s = 0; s < 4; s++) {
      for (final row in jelly.stages[s].body.rows) {
        if (!row.contains('g') && !row.contains('G')) continue;
        expect(row, row.split('').reversed.join(), reason: 'jelly s${s + 1}');
      }
    }
  });
}
