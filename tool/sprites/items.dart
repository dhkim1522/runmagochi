// 상점 아이템 그림(작업 8, 페이즈 6 작업 5 말랑 클레이). id·부위는 lib/shop/domain/catalog.dart 와 같다.
// 그림 한 장을 종류의 기준점(PetKind.hatAnchor·accessoryAnchor)에 가운데 맞춰 놓고,
// face 처럼 headOffsets 로 움직인다. 앱은 단계 없이 `<kind>/<slot>/<id>_<action>.png`
// 를 읽으므로 4단계·3종이 같은 그림을 쓴다. 그래서 가장 큰 4단계 머리에 맞춘다.
//   - 모자: 기준점 y = 챙 맨 아랫줄(r=0). 챙부터 위로 7줄(r=-6..0)은 3종 4단계 머리
//     (가장 넓은 젤리·도토리 x=5..26)를 모두 덮는다. 그 위로 솟은 병아리 볏·젤리 잎·
//     도토리 꼭지는 모자 밖으로 보인다. 눈(y=20)을 가리지 않는다.
//   - 소품: 기준점 y = 눈 윗줄(y=20).
// 그림체는 몸과 같다: 진한 외곽선 o, 빛은 왼쪽 위, 3단 명암(색 글자는 pet_art.dart 팔레트).
import 'pet_art.dart';

const List<ItemArt> items = [
  // 러닝 캡: 왼쪽 위가 밝은 둥근 정수리(H·T·W), 가운데 흰 로고, 진한 챙(U).
  ItemArt(
    id: 'cap',
    slot: 'hat',
    top: -7,
    rows: [
      '......oooooooooooo......',
      '....ooHHHTTTTTTTTWoo....',
      '...oHHTTTTTTTTTTTTWWo...',
      '..oHHTTTTTTwwTTTTTTTWo..',
      '..oHTTTTTTTTTTTTTTTTWo..',
      '.oTTTTTTTTTTTTTTTTTTTWo.',
      'oWWWWWWWWWWWWWWWWWWWWUUo',
      '.oooUUUUUUUUUUUUUUUUooo.',
      '....oooooooooooooooo....',
    ],
  ),
  // 비니: 방울 + 골이 진 접단(v·V). 젤리 잎·병아리 볏은 방울 양옆으로 나온다.
  ItemArt(
    id: 'beanie',
    slot: 'hat',
    top: -10,
    rows: [
      '..........oooo..........',
      '.........oIwwvo.........',
      '.........oIvvVo.........',
      '......oooooooooooo......',
      '....ooIIvvvvvvvvVVoo....',
      '...oIIvvvvvvvvvvvvVVo...',
      '..oIvvvvvvvvvvvvvvvvVo..',
      '..oIvvvvvvvvvvvvvvvvVo..',
      '.oVvVvVvVvVvVvVvVvVvVVo.',
      '.oVvVvVvVvVvVvVvVvVvVVo.',
      '.oooooooooooooooooooooo.',
    ],
  ),
  // 밀짚모자: 가장 넓은 챙(28칸), 빨간 띠, 결(s·S).
  ItemArt(
    id: 'straw_hat',
    slot: 'hat',
    top: -7,
    rows: [
      '........oooooooooooo........',
      '......ooFFFsssssssSSoo......',
      '.....oFFssssssssssssSSo.....',
      '....oFsssssssssssssssSSo....',
      '....oddddddddddddddddDDo....',
      '.ooFsSsSsSsSsSsSsSsSsSsSSoo.',
      'oFsSsSsSsSsSsSsSsSsSsSsSsSSo',
      '.oooooooooooooooooooooooooo.',
    ],
  ),
  // 선글라스: 눈 두 쌍(x=12·13, 18·19)을 덮는 알, 왼쪽 위 반짝임(w·J).
  ItemArt(
    id: 'sunglasses',
    slot: 'accessory',
    top: -1,
    rows: [
      '..oooooooooooo..',
      '.ooJwLLooJwLLoo.',
      '..oLLLJooLLLJo..',
      '...oooo..oooo...',
    ],
  ),
  // 헤드폰: 머리 위 띠(X·u·Z) + 양옆 귀덮개(Q·R·d). 쿠션(Z)이 1단계 머리 옆에 닿고
  // 바깥 껍데기는 4단계 머리 밖으로 나온다.
  ItemArt(
    id: 'headphones',
    slot: 'accessory',
    top: -8,
    rows: [
      '.......oooooooooo.......',
      '.....ooXXuuuuuuuuoo.....',
      '....oXuoooooooooouZo....',
      '...oXuo..........oZZo...',
      '..oXuo............oZZo..',
      '..oXuo............oZZo..',
      '..oXuo............oZZo..',
      '.ooooo............ooooo.',
      'oQRZZo............oZZQRo',
      'oRRZZo............oZZRRo',
      'oRdZZo............oZZRdo',
      '.ooooo............ooooo.',
    ],
  ),
  // 꽃 머리핀: 머리 오른쪽 위, 꽃잎 네 장(P·f·K)과 노란 꽃술.
  ItemArt(
    id: 'flower_pin',
    slot: 'accessory',
    top: -8,
    rows: [
      '............oo..oo..',
      '...........oPfooPfo.',
      '...........ofKeefKo.',
      '............oeEEeo..',
      '...........oPfeEfKo.',
      '...........ofKooKKo.',
      '............oo..oo..',
    ],
  ),
];
