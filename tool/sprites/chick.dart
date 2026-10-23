// 병아리: 1 알 → 2 껍데기를 쓴 아기 병아리 → 3 병아리 → 4 마라토너 병아리.
// 그림체는 말랑 클레이(페이즈 6 후보 a, 후보 코드는 작업 18 에서 지움): 3단 명암
// (하이라이트 l·기본 m·그림자 M, 알은 q·y·Y), 빛은 왼쪽 위.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용). 부리는 body 에 있다.
// 몸집(결정 0034): 2단계 16칸, 3·4단계 18칸으로 폭을 고정하고 성장은 볏·명암·볼터치·장비로 보인다.
import 'pet_art.dart';

// 눈: 2×2 에 왼쪽 위 반짝임. 졸린 눈은 바깥으로 처진 눈꺼풀이 윗줄을 덮고
// 반짝임은 아랫줄로 내려온다. 잠든 눈은 눈 자리 가운데의 ∪ 곡선.
const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', 'pp........pp'],
    'sleepy': ['.kkk....kkk.', '..wk....wk..', 'pp........pp'],
    'asleep': ['.k..k..k..k.', '..kk....kk..', 'pp........pp'],
  },
);

final chick = PetKind(
  name: 'chick',
  face: _face,
  // 아이템: 모자 챙은 y=18(껍데기·머리 위), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 18),
  accessoryAnchor: (x: 16, y: 20),
  // 모자 위로 나오는 볏: 4단계 볏과 같은 자리(y=9·10).
  hatSprout: (x: 15, top: -9, rows: ['.oo', 'olo']),
  stages: [
    // 1 알: 발이 없어 통통 튄다.
    const StageArt(
      body: Art(15, [
        '....oooooo....',
        '...oqqyyyyo...',
        '..oqqyyyyyYo..',
        '.oqyyyyyyyyYo.',
        '.oyyyyyyyyyYo.',
        'oyyyyyyyyyyyYo',
        'oyyyyyyyyyyyYo',
        'oyyyyyyyyyyyYo',
        'oyyyyyyyyyyYYo',
        'oyyyyyyyyyyYYo',
        'oYyyyyyyyyyYYo',
        'oYYyyyyyyyYYYo',
        '.oYYYyyyyYYYo.',
        '..ooYYYYYYoo..',
        '....oooooo....',
      ]),
      squashRow: 23,
      hops: true,
      tiltRows: 3,
    ),
    // 2 아기 병아리: 3단계보다 2칸 좁은 몸(16칸), 알 껍데기 모자, 큰 볼터치(y=23 까지 2줄),
    // 밝은 배 + 러닝화.
    StageArt(
      body: const Art(11, [
        '.....oooooo.....',
        '...ooqqyyyyoo...',
        '..oqqyyyyyyyYo..',
        '.oqyyyyyyyyyyYo.',
        '.oyyyyyyyyyyyYo.',
        'oyyyoyyyoyyyoyYo',
        'ooyoloyomoyomoYo',
        'ololllollmommmoo',
        'ollllmmmmmmmmmMo',
        'olllmmmmmmmmmmMo',
        'ollmmmmmmmmmmmMo',
        'ommmmmbbbbmmmmMo',
        'omppmmmBBmmmppMo',
        'oMmmmmllllmmmMMo',
        '.oMMmmmllmmmMMo.',
        '..oooooooooooo..',
      ]),
      squashRow: 24,
      arm: Limb(6, 21, clayArmRows('l', 'm', 'M')),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 3 병아리(18칸) + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(10, [
        '.........oo.......',
        '........olo.......',
        '.....ooooloooo....',
        '...oollllmmmmoo...',
        '..olllmmmmmmmmMo..',
        '.ollmmmmmmmmmmmMo.',
        '.olmmmmmmmmmmmmMo.',
        'olmmmmmmmmmmmmmmMo',
        'olmmmmmmmmmmmmmmMo',
        'ommmmmmmmmmmmmmmMo',
        'ommmmmmmmmmmmmmmMo',
        'ommmmmmmmmmmmmmmMo',
        'ommmmmmbbbbmmmmmMo',
        'ommmmmmmBBmmmmmMMo',
        'oMmmmmmmmmmmmmmMMo',
        '.oMMmmmmmmmmmMMMo.',
        '..oooooooooooooo..',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('l', 'm', 'M', band: true)),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 4 마라토너 병아리: 3단계와 같은 몸집(18칸). 볏이 세 줄로 자라고(y=9~11),
    // + 헤어밴드(y=17·18) + 완주 메달(끈 y=25). 그림자가 짙어 단단해 보인다.
    StageArt(
      body: const Art(9, [
        '.........oo.......',
        '........olo.......',
        '......oolloo......',
        '.....oollmlmoo....',
        '...oollllmmmmoo...',
        '..olllmmmmmmmmMo..',
        '.ollmmmmmmmmmmmMo.',
        '.olmmmmmmmmmmmMMo.',
        'oAAAAAAAaaaaaaaaao',
        'oaaaaaaaaaaaaaaaao',
        'ommmmmmmmmmmmmmMMo',
        'ommmmmmmmmmmmmmMMo',
        'ommmmmmmmmmmmmmMMo',
        'ommmmmmbbbbmmmmMMo',
        'oMmmmmmmBBmmmmmMMo',
        'oMMmmmmmmmmmmmMMMo',
        '.oddddddddddddDDo.',
        '..oooooEweEooooo..',
        '.......EeeE.......',
        '........EE........',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('l', 'm', 'M', band: true)),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
  ],
);
