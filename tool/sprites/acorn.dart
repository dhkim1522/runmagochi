// 도토리: 1 작은 도토리 → 2 도토리 → 3 큰 도토리 → 4 마라토너 도토리.
// 그림체는 말랑 클레이(페이즈 6 후보 a, 병아리와 같음): 몸은 3단 명암(하이라이트 t·
// 기본 n·그림자 N), 모자도 3단(x·C·c)에 c 비늘 무늬. 빛은 왼쪽 위.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용, 병아리와 같은 눈).
// 모자 아랫줄(테)은 모든 단계에서 y=17 이다(모자 기준점).
import 'pet_art.dart';

// 눈은 병아리와 같다. 입은 눈 사이 아래 y=22 한 줄.
const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', 'pp...kk...pp'],
    'sleepy': ['.kkk....kkk.', '..wk....wk..', 'pp...kk...pp'],
    'asleep': ['.k..k..k..k.', '..kk....kk..', 'pp...kk...pp'],
  },
);

final acorn = PetKind(
  name: 'acorn',
  face: _face,
  // 아이템: 모자 챙은 y=17(도토리 모자 아랫줄), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 17),
  accessoryAnchor: (x: 16, y: 20),
  stages: [
    // 1 작은 도토리: 작은 발로 걷는다.
    StageArt(
      body: const Art(12, [
        '.......oo.......',
        '......oxco......',
        '...oooooooooo...',
        '..oxxxCCCCCCco..',
        '.oxxCCcCCcCCcco.',
        'occcccccccccccco',
        '.otnnnnnnnnnnNo.',
        '.otnnnnnnnnnnNo.',
        '.onnnnnnnnnnnNo.',
        '.onnnnnnnnnnnNo.',
        '.onnnnnnnnnnnNo.',
        '.oNnnnnnnnnnNNo.',
        '..oNnnnnnnnNNo..',
        '..oNNnnnnnNNNo..',
        '...oNNNNNNNNo...',
        '....ooNNNNoo....',
        '......oooo......',
      ]),
      squashRow: 24,
      arm: Limb(7, 21, clayArmRows('t', 'n', 'N')),
      foot: const Limb(13, 0, nubFoot),
    ),
    // 2 도토리 + 러닝화
    StageArt(
      body: const Art(11, [
        '........oo........',
        '.......oxco.......',
        '....oooooooooo....',
        '..ooxxxCCCCCCcoo..',
        '.oxxCCcCCcCCcCcco.',
        'oxCCcCCcCCcCCcCcco',
        'occcccccccccccccco',
        '.otnnnnnnnnnnnnNo.',
        '.otnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnNo.',
        '.oNnnnnnnnnnnnNNo.',
        '..oNnnnnnnnnnNNo..',
        '...oNNNnnnnNNNo...',
        '....oooooooooo....',
      ]),
      squashRow: 24,
      arm: Limb(6, 21, clayArmRows('t', 'n', 'N')),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 3 큰 도토리 + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(10, [
        '.........oo.........',
        '........oxco........',
        '.....oooooooooo.....',
        '...ooxxxCCCCCCcoo...',
        '..oxxCCcCCcCCcCCco..',
        '.oxCCcCCcCCcCCcCcco.',
        'oxCCcCCcCCcCCcCCccco',
        'occcccccccccccccccco',
        '.otnnnnnnnnnnnnnnNo.',
        '.otnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnNo.',
        '.oNnnnnnnnnnnnnnNNo.',
        '..oNnnnnnnnnnnnNNo..',
        '...oNNNnnnnnnNNNo...',
        '....oooooooooooo....',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('t', 'n', 'N', band: true)),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 4 마라토너 도토리: + 헤어밴드(모자 바로 아래 y=18) + 완주 메달.
    // 메달은 목 아래 가로 끈(y=25)에 매단다. 입 바로 아래 세로 끈은 입처럼 보인다.
    StageArt(
      body: const Art(9, [
        '..........oo..........',
        '.........oxco.........',
        '......oooooooooo......',
        '....ooxxxCCCCCCcoo....',
        '...oxxCCcCCcCCcCCco...',
        '..oxCCcCCcCCcCCcCcco..',
        '.oxCCcCCcCCcCCcCCccco.',
        'oxCCcCCcCCcCCcCCcCccco',
        'occcccccccccccccccccco',
        '.oAAAAAAAaaaaaaaaaaao.',
        '.otnnnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnnnNo.',
        '.onnnnnnnnnnnnnnnnnNo.',
        '.oNnnnnnnnnnnnnnnnNNo.',
        '..oddddddddddddddDDo..',
        '...ooooooEweEoooooo...',
        '.........EeeE.........',
        '..........EE..........',
      ]),
      squashRow: 24,
      arm: Limb(4, 21, clayArmRows('t', 'n', 'N', band: true)),
      foot: const Limb(8, 0, clayShoeFoot),
    ),
  ],
);
