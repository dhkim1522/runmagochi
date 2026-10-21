// 상점 아이템 그림(작업 8). id·부위는 lib/shop/domain/catalog.dart 와 같다.
// 그림 한 장을 종류의 기준점(PetKind.hatAnchor·accessoryAnchor)에 가운데 맞춰 놓고,
// face 처럼 headOffsets 로 움직인다. 4단계가 같은 그림을 쓴다.
//   - 모자: 기준점 y = 챙 맨 아랫줄. 눈(y=20)을 가리지 않는다.
//   - 소품: 기준점 y = 눈 윗줄(y=20).
import 'pet_art.dart';

const List<ItemArt> items = [
  // 러닝 캡: 앞으로 튀어나온 챙, 가운데 흰 로고.
  ItemArt(
    id: 'cap',
    slot: 'hat',
    top: -6,
    rows: [
      '......oooooo......',
      '....ooTTTTTToo....',
      '..oTTTTTwwTTTTTo..',
      '..oTTTTTTTTTTTTo..',
      '.ooUUUUUUUUUUUUoo.',
      'oUUUUUUUUUUUUUUUUo',
      '.oooooooooooooooo.',
    ],
  ),
  // 비니: 방울 + 골이 진 접단.
  ItemArt(
    id: 'beanie',
    slot: 'hat',
    top: -9,
    rows: [
      '........oo........',
      '.......owwo.......',
      '.......owwo.......',
      '......oooooo......',
      '....oovvvvvvoo....',
      '...ovvvvvvvvvvo...',
      '..ovvvvvvvvvvvvo..',
      'oVvVvVvVvvVvVvVvVo',
      'oVvVvVvVvvVvVvVvVo',
      'oooooooooooooooooo',
    ],
  ),
  // 밀짚모자: 넓은 챙, 빨간 띠.
  ItemArt(
    id: 'straw_hat',
    slot: 'hat',
    top: -6,
    rows: [
      '........oooooo........',
      '.......osssssSo.......',
      '......osssssssSo......',
      '......oddddddddo......',
      '..oooosSsSsSsSsSoooo..',
      '.osSsSsSsSsSsSsSsSsSo.',
      '..oooooooooooooooooo..',
    ],
  ),
  // 선글라스: 눈 두 쌍(x=12·13, 18·19)을 덮는 알, 반짝임 한 점.
  ItemArt(
    id: 'sunglasses',
    slot: 'accessory',
    top: -1,
    rows: [
      '..oooooooooooo..',
      '.ooLwLLooLwLLoo.',
      '..oLLLLooLLLLo..',
      '...oooo..oooo...',
    ],
  ),
  // 헤드폰: 머리 위 띠 + 양옆 귀덮개.
  ItemArt(
    id: 'headphones',
    slot: 'accessory',
    top: -7,
    rows: [
      '......oooooooo......',
      '....oouuuuuuuuoo....',
      '...ouuoooooooouuo...',
      '..ouoo........oouo..',
      '..ouo..........ouo..',
      '.oooo..........oooo.',
      'oRRRo..........oRRRo',
      'oRRRo..........oRRRo',
      'oRRRo..........oRRRo',
      '.ooo............ooo.',
    ],
  ),
  // 꽃 머리핀: 머리 오른쪽 위.
  ItemArt(
    id: 'flower_pin',
    slot: 'accessory',
    top: -8,
    rows: [
      '...............oo...',
      '..............offo..',
      '............ooffoo..',
      '...........offeeffo.',
      '...........offeeffo.',
      '............ooffoo..',
      '..............offo..',
      '...............oo...',
    ],
  ),
];
