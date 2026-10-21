// 병아리: 1 알 → 2 껍데기를 쓴 아기 병아리 → 3 병아리 → 4 마라토너 병아리.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용). 부리는 body 에 있다.
import 'pet_art.dart';

const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', 'pp........pp'],
    'sleepy': ['.kkkk..kkkk.', '..kk....kk..', 'pp........pp'],
    'asleep': ['.k..k..k..k.', '..kk....kk..', 'pp........pp'],
  },
);

final chick = PetKind(
  name: 'chick',
  face: _face,
  // 아이템: 모자 챙은 y=18(껍데기·머리 위), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 18),
  accessoryAnchor: (x: 16, y: 20),
  stages: [
    // 1 알: 발이 없어 통통 튄다.
    const StageArt(
      body: Art(15, [
        '....oooooo....',
        '...oyyyyyyo...',
        '..oywwyyyyyo..',
        '.oywyyyyyyyyo.',
        '.oyyyyyyyyyyo.',
        'oyyyyyyyyyyyyo',
        'oyyyyyyyyyyyyo',
        'oyyyyyyyyyyyyo',
        'oyyyyyyyyyyyyo',
        'oyyyyyyyyyyyyo',
        'oYyyyyyyyyyyYo',
        'oYooYYooYYooYo',
        'oYYYYYYYYYYYYo',
        '.oYYYYYYYYYYo.',
        '..oooooooooo..',
      ]),
      squashRow: 23,
      hops: true,
      tiltRows: 3,
    ),
    // 2 껍데기를 쓴 아기 병아리 + 러닝화
    StageArt(
      body: const Art(11, [
        '......oooo......',
        '....ooyyyyoo....',
        '...oywwyyyyyo...',
        '..oywyyyyyyyyo..',
        '.oyyyyyyyyyyyyo.',
        'oyyoyyoyyoyyoyyo',
        'ooomoomoomoomooo',
        'ommmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmo',
        'ommmmmbbbbmmmmmo',
        'oMmmmmmbbmmmmmMo',
        'oMmmmmmmmmmmmmMo',
        '.oMMmmmmmmmmMMo.',
        '..ooMMMMMMMMoo..',
        '....oooooooo....',
      ]),
      squashRow: 24,
      arm: Limb(6, 22, armRows('m')),
      foot: const Limb(9, 0, shoeFoot),
    ),
    // 3 병아리 + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(11, [
        '..........mm......',
        '.........mm.......',
        '....oooooooooo....',
        '...ommmmmmmmmmo...',
        '..ommhhmmmmmmmmo..',
        '.ommhmmmmmmmmmmmo.',
        '.ommmmmmmmmmmmmmo.',
        'ommmmmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmmmo',
        'ommmmmmbbbbmmmmmmo',
        'oMmmmmmmbbmmmmmmMo',
        'oMMmmmmmmmmmmmmMMo',
        '.oMMmmmmmmmmmmMMo.',
        '..ooMMMMMMMMMMoo..',
        '....oooooooooo....',
      ]),
      squashRow: 24,
      arm: Limb(5, 22, armRows('m', band: true)),
      foot: const Limb(9, 0, shoeFoot),
    ),
    // 4 마라토너 병아리: + 헤어밴드 + 완주 메달
    StageArt(
      body: const Art(10, [
        '...........mm.......',
        '..........mm........',
        '.....oooooooooo.....',
        '...oommmmmmmmmmoo...',
        '..ommhhmmmmmmmmmmo..',
        '.ommhmmmmmmmmmmmmmo.',
        '.ommmmmmmmmmmmmmmmo.',
        'ommmmmmmmmmmmmmmmmmo',
        'oaaaaaaaaaaaaaaaaaao',
        'ommmmmmmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmmmmmo',
        'ommmmmmmmmmmmmmmmmmo',
        'ommmmmmmbbbbmmmmmmmo',
        'oMmmmmmmmbbmmmmmmmMo',
        'oMmmmmmmdmmdmmmmmmMo',
        '.oMMmmmmEeeEmmmmMMo.',
        '..ooMMMMEeeEMMMMoo..',
        '....oooooEEooooo....',
      ]),
      squashRow: 24,
      arm: Limb(4, 22, armRows('m', band: true)),
      foot: const Limb(8, 0, shoeFoot),
    ),
  ],
);
