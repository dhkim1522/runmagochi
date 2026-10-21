// 젤리: 1 새싹 젤리 → 2 잎이 둘인 젤리 → 3 큰 젤리 → 4 마라토너 젤리.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용).
import 'pet_art.dart';

const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', 'pp...kk...pp'],
    'sleepy': ['.kkkk..kkkk.', '..kk....kk..', 'pp...kk...pp'],
    'asleep': ['.k..k..k..k.', '..kk....kk..', 'pp...kk...pp'],
  },
);

final jelly = PetKind(
  name: 'jelly',
  face: _face,
  // 아이템: 모자 챙은 y=18(머리 위), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 18),
  accessoryAnchor: (x: 16, y: 20),
  stages: [
    // 1 새싹 젤리
    StageArt(
      body: const Art(13, [
        '......gG........',
        '.....gGGg.......',
        '......g.........',
        '....oooooooo....',
        '..oobbbbbbbboo..',
        '.obbhhbbbbbbbbo.',
        '.obhhbbbbbbbbbo.',
        'obbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbo',
        'oBbbbbbbbbbbbbBo',
        'oBbbbbbbbbbbbbBo',
        '.oBBbbbbbbbbBBo.',
        '..ooBBBBBBBBoo..',
        '....oooooooo....',
      ]),
      squashRow: 23,
      arm: Limb(6, 22, armRows('b')),
      foot: const Limb(12, 0, nubFoot),
    ),
    // 2 잎이 둘인 젤리 + 러닝화
    StageArt(
      body: const Art(12, [
        '....gGG....GGg....',
        '.....gGg..gGg.....',
        '.......gggg.......',
        '.....oooooooo.....',
        '...oobbbbbbbboo...',
        '..obbhhbbbbbbbbo..',
        '.obbhhbbbbbbbbbbo.',
        '.obhbbbbbbbbbbbbo.',
        'obbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbo',
        'oBbbbbbbbbbbbbbbBo',
        '.oBBbbbbbbbbbbBBo.',
        '..ooBBBBBBBBBBoo..',
        '....oooooooooo....',
      ]),
      squashRow: 23,
      arm: Limb(5, 22, armRows('b')),
      foot: const Limb(9, 0, shoeFoot),
    ),
    // 3 큰 젤리 + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(11, [
        '.....gGG....GGg.....',
        '......gGg..gGg......',
        '........gggg........',
        '.....oooooooooo.....',
        '...oobbbbbbbbbboo...',
        '..obbhhbbbbbbbbbbo..',
        '.obbhhbbbbbbbbbbbbo.',
        '.obhbbbbbbbbbbbbbbo.',
        'obbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbo',
        'oBbbbbbbbbbbbbbbbbBo',
        '.oBBbbbbbbbbbbbbBBo.',
        '..ooBBBBBBBBBBBBoo..',
        '....oooooooooooo....',
      ]),
      squashRow: 23,
      arm: Limb(4, 22, armRows('b', band: true)),
      foot: const Limb(8, 0, shoeFoot),
    ),
    // 4 마라토너 젤리: + 헤어밴드 + 완주 메달
    StageArt(
      body: const Art(10, [
        '......gGG....GGg......',
        '.......gGg..gGg.......',
        '.........gggg.........',
        '......oooooooooo......',
        '....oobbbbbbbbbboo....',
        '..oobbhhbbbbbbbbbboo..',
        '.obbhhbbbbbbbbbbbbbbo.',
        '.obhbbbbbbbbbbbbbbbbo.',
        'oaaaaaaaaaaaaaaaaaaaao',
        'obbbbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbbbo',
        'obbbbbbbbbbbbbbbbbbbbo',
        'oBbbbbbbbdbbdbbbbbbbBo',
        '.oBBbbbbbEeeEbbbbbBBo.',
        '..ooBBBBBEeeEBBBBBoo..',
        '....ooooooEEoooooo....',
      ]),
      squashRow: 23,
      arm: Limb(3, 22, armRows('b', band: true)),
      foot: const Limb(8, 0, shoeFoot),
    ),
  ],
);
