// 도토리: 1 작은 도토리 → 2 도토리 → 3 큰 도토리 → 4 마라토너 도토리.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용). 모자는 눈 위에 고정.
import 'pet_art.dart';

const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', '.p...kk...p.'],
    'sleepy': ['.kkkk..kkkk.', '..kk....kk..', '.p...kk...p.'],
    'asleep': ['.k..k..k..k.', '..kk....kk..', '.p...kk...p.'],
  },
);

final acorn = PetKind(
  name: 'acorn',
  face: _face,
  // 아이템: 모자 챙은 y=17(도토리 모자 아랫줄), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 17),
  accessoryAnchor: (x: 16, y: 20),
  stages: [
    // 1 작은 도토리
    StageArt(
      body: const Art(14, [
        '......cc......',
        '...oooooooo...',
        '.ooCCCCCCCCoo.',
        'oCcCcCcCcCcCco',
        'occcccccccccco',
        '.onnnnnnnnnno.',
        '.onnnnnnnnnno.',
        '.onnnnnnnnnno.',
        '.onnnnnnnnnno.',
        '.onnnnnnnnnno.',
        '.oNnnnnnnnnNo.',
        '..oNnnnnnnNo..',
        '..oNNnnnnNNo..',
        '...oNNNNNNo...',
        '....oooooo....',
      ]),
      squashRow: 23,
      arm: Limb(8, 22, armRows('n')),
      foot: const Limb(13, 0, nubFoot),
    ),
    // 2 도토리 + 러닝화
    StageArt(
      body: const Art(12, [
        '.......cc.......',
        '....oooooooo....',
        '..ooCCCCCCCCoo..',
        '.oCCCCCCCCCCCCo.',
        'oCcCcCcCcCcCcCco',
        'occcccccccccccco',
        '.onnnnnnnnnnnno.',
        '.onnnnnnnnnnnno.',
        '.onnnnnnnnnnnno.',
        '.onnnnnnnnnnnno.',
        '.onnnnnnnnnnnno.',
        '.onnnnnnnnnnnno.',
        '.oNnnnnnnnnnnNo.',
        '..oNnnnnnnnnNo..',
        '...oNNNNNNNNo...',
        '....oooooooo....',
      ]),
      squashRow: 23,
      arm: Limb(7, 22, armRows('n')),
      foot: const Limb(9, 0, shoeFoot),
    ),
    // 3 큰 도토리 + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(11, [
        '........cc........',
        '.....oooooooo.....',
        '...ooCCCCCCCCoo...',
        '..oCCCCCCCCCCCCo..',
        '.oCcCcCcCcCcCcCco.',
        'oCcCcCcCcCcCcCcCco',
        'occcccccccccccccco',
        '.onnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnno.',
        '.oNnnnnnnnnnnnNo.',
        '..oNnnnnnnnnnNo..',
        '...oNNNNNNNNNNo...',
        '.....oooooooo.....',
      ]),
      squashRow: 23,
      arm: Limb(6, 22, armRows('n', band: true)),
      foot: const Limb(9, 0, shoeFoot),
    ),
    // 4 마라토너 도토리: + 헤어밴드 + 완주 메달
    StageArt(
      body: const Art(10, [
        '.........cc.........',
        '......oooooooo......',
        '....ooCCCCCCCCoo....',
        '...oCCCCCCCCCCCCo...',
        '..oCcCcCcCcCcCcCco..',
        '.oCcCcCcCcCcCcCcCco.',
        'oCcCcCcCcCcCcCcCcCco',
        'occcccccccccccccccco',
        '.oaaaaaaaaaaaaaaaao.',
        '.onnnnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnnnno.',
        '.onnnnnnnnnnnnnnnno.',
        '.oNnnnnndnndnnnnnNo.',
        '.oNNnnnnEeeEnnnnNNo.',
        '..ooNNNNEeeENNNNoo..',
        '....oooooEEooooo....',
      ]),
      squashRow: 23,
      arm: Limb(5, 22, armRows('n', band: true)),
      foot: const Limb(8, 0, shoeFoot),
    ),
  ],
);
