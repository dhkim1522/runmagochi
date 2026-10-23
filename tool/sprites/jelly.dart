// 젤리: 1 새싹 젤리 → 2 어린 젤리 → 3 젤리 → 4 마라토너 젤리.
// 그림체는 말랑 클레이(페이즈 6 후보 a, 병아리와 같음): 3단 명암(하이라이트 i·기본 b·
// 그림자 B), 빛은 왼쪽 위. 반들반들한 젤리라 왼쪽 위에 반짝임(h)을 둔다.
// 눈은 모든 단계에서 x=12·13, 18·19, y=20·21 (face 공용, 병아리와 같은 눈).
// 몸집(결정 0034): 2~4단계 폭 18칸 고정. 키는 머리·잎 줄만큼만 자라고(19·20·21),
// 성장은 잎 크기·반짝임·볼터치·장비로 보인다.
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

final jelly = PetKind(
  name: 'jelly',
  face: _face,
  // 아이템: 모자 챙은 y=18(머리 위), 소품은 눈 윗줄 y=20 기준.
  hatAnchor: (x: 16, y: 18),
  accessoryAnchor: (x: 16, y: 20),
  // 모자 위로 나오는 잎 두 장: 4단계 잎 모양을 1줄 올려(y=8~10) 모자 꼭대기(y=11)에 얹는다.
  hatSprout: (
    x: 10,
    top: -10,
    rows: ['.oo......oo.', 'oGGo....oGGo', 'oGggo..oggGo'],
  ),
  stages: [
    // 1 새싹 젤리: 작은 발로 걷는다.
    StageArt(
      body: const Art(12, [
        '....oo....oo....',
        '...oGGo..oGGo...',
        '....oGgoogGo....',
        '....oooooooo....',
        '..ooiiiibbbboo..',
        '.oiiihbbbbbbbBo.',
        '.oiihbbbbbbbbBo.',
        'oiibbbbbbbbbbbBo',
        'oibbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbBBo',
        'oBbbbbbbbbbbbBBo',
        '.oBBbbbbbbbbBBo.',
        '..ooBBBBBBBBoo..',
        '....oooooooo....',
      ]),
      squashRow: 24,
      arm: Limb(6, 21, clayArmRows('i', 'b', 'B')),
      foot: const Limb(12, 0, nubFoot),
    ),
    // 2 어린 젤리: 작은 새싹 잎, 큰 볼터치(y=23 까지 2줄), 연한 왼쪽 + 러닝화
    StageArt(
      body: const Art(11, [
        '.....oo....oo.....',
        '....oGgo..ogGo....',
        '.....ooggggoo.....',
        '.....oooooooo.....',
        '...ooiiiiiibboo...',
        '..oiiiihbbbbbbBo..',
        '.oiiihbbbbbbbbbBo.',
        '.oiibbbbbbbbbbbBo.',
        'oiibbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'obbppbbbbbbbbppbBo',
        'oBbbbbbbbbbbbbbBBo',
        '.oBBbbbbbbbbbbBBo.',
        '..oooooooooooooo..',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('i', 'b', 'B')),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 3 젤리: 2단계 폭 그대로 머리를 1줄 높이고(윗선 y=14) 잎 3줄 + 러닝화 + 손목 밴드
    StageArt(
      body: const Art(10, [
        '....oo......oo....',
        '...oGGo....oGGo...',
        '...oGggo..oggGo...',
        '....oooggggooo....',
        '..ooiiiiibbbbboo..',
        '.oiiihhbbbbbbbbBo.',
        '.oihhbbbbbbbbbbBo.',
        'oiihbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'oBbbbbbbbbbbbbbBBo',
        '.oBBbbbbbbbbbbBBo.',
        '..oooooooooooooo..',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('i', 'b', 'B', band: true)),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
    // 4 마라토너 젤리: 잎 4줄(y=9~12), 반짝임 하나 더 + 헤어밴드 + 완주 메달.
    // 메달은 목 아래 가로 끈(y=25)에 매단다. 입 바로 아래 세로 끈은 입처럼 보인다.
    StageArt(
      body: const Art(9, [
        '....oo......oo....',
        '...oGGo....oGGo...',
        '...oGggo..oggGo...',
        '...oGgggoogggGo...',
        '....oooggggooo....',
        '..ooiiiiibbbbboo..',
        '.oiiihhbbbbbbbbBo.',
        '.oihhbbbbbbbbbbBo.',
        'oAAAAAAAaaaaaaaaao',
        'oaaaaaaaaaaaaaaaao',
        'oihbbbbbbbbbbbbbBo',
        'oibbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbbBo',
        'obbbbbbbbbbbbbbBBo',
        'oBbbbbbbbbbbbbbBBo',
        '.oddddddddddddDDo.',
        '..oooooEweEooooo..',
        '.......EeeE.......',
        '........EE........',
      ]),
      squashRow: 24,
      arm: Limb(5, 21, clayArmRows('i', 'b', 'B', band: true)),
      foot: const Limb(9, 0, clayShoeFoot),
    ),
  ],
);
