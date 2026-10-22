// 후보 a "클레이 다듬기": 지금 병아리 비율 그대로, 3단 명암(하이라이트·기본·그림자),
// 외곽선 정리, 달리기 동작 폭을 키움. 빛은 왼쪽 위.
// 눈은 지금처럼 x=12·13, 18·19, y=20·21 (기준점 그대로).
import '../pet_art.dart';
import '../sprite_data.dart';
import 'candidate.dart';

const Palette _palette = {
  'o': 0xFF431407, // 외곽선 (ink)
  'k': 0xFF431407, // 눈
  'w': 0xFFFFFFFF, // 눈 반짝임, 신발 밑창
  'p': 0xFFFDA4AF, // 볼
  'q': 0xFFFFFBF5, // 알 하이라이트
  'y': 0xFFFFE9CC, // 알 기본
  'Y': 0xFFF2C48D, // 알 그림자
  'l': 0xFFFEF08A, // 병아리 하이라이트
  'm': 0xFFFACC15, // 병아리 기본
  'M': 0xFFD99A06, // 병아리 그림자
  'b': 0xFFFB923C, // 부리
  'B': 0xFFEA580C, // 부리 그림자
  'r': 0xFFF97316, // 러닝화 (primary)
  'R': 0xFFC2410C, // 러닝화 그림자
  'a': 0xFF2563EB, // 헤어밴드·손목 밴드 (accent)
  'A': 0xFF60A5FA, // 밴드 하이라이트
  'd': 0xFFDC2626, // 메달 끈
  'e': 0xFFFDE047, // 메달
  'E': 0xFFA16207, // 메달 테두리
};

const _face = FaceArt(
  x: 10,
  y: 20,
  moods: {
    'normal': ['..wk....wk..', '..kk....kk..', 'pp........pp'],
  },
);

// 날개: 몸 가장자리에 겹쳐 붙는다. 밴드는 아랫부분.
List<String> _wing({bool band = false}) => [
  '.oo',
  'olm',
  'omM',
  band ? 'oaA' : 'oMM',
  '.oo',
];

const List<String> _shoe = ['orwro', 'orrRo', 'ooooo'];

// 숨쉬기·달리기는 머리를 올리기만 한다(k ≤ 0). 눌림(k > 0)은 squashRow 줄을 지워
// 메달 끈이 사라지기 때문이다. 달리기는 뜰 때 2px 오르고, 팔을 ±2 흔들고, 발을 번갈아 든다.
const PoseSet _poses = PoseSet(
  walker: {
    'idle': [Pose(), Pose(k: -1)],
    'walk': [
      Pose(footL: (1, 0)),
      Pose(k: -1, armL: 1, armR: -1),
      Pose(footR: (1, 0)),
      Pose(k: -1, armL: -1, armR: 1),
    ],
    'run': [
      Pose(footL: (0, 1), footR: (1, 0), armL: 2, armR: -2),
      Pose(k: -1, lift: 1, footR: (1, 1), armL: 1, armR: -1),
      Pose(footR: (0, 1), footL: (1, 0), armL: -2, armR: 2),
      Pose(k: -1, lift: 1, footL: (1, 1), armL: -1, armR: 1),
    ],
  },
  hopper: {
    'idle': [Pose(), Pose(k: -1)],
    'walk': [
      Pose(tilt: -1),
      Pose(lift: 1, tilt: -1),
      Pose(tilt: 1),
      Pose(lift: 1, tilt: 1),
    ],
    'run': [
      Pose(tilt: -1),
      Pose(k: -1, lift: 1, tilt: -1),
      Pose(tilt: 1),
      Pose(k: -1, lift: 1, tilt: 1),
    ],
  },
);

final candidateA = Candidate(
  id: 'a',
  title: '클레이 다듬기',
  palette: _palette,
  poses: _poses,
  kind: PetKind(
    name: 'chick',
    face: _face,
    hatAnchor: (x: 16, y: 18),
    accessoryAnchor: (x: 16, y: 20),
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
      // 2 껍데기를 쓴 아기 병아리 + 러닝화
      StageArt(
        body: const Art(11, [
          '.....oooooo.....',
          '...ooqqyyyyoo...',
          '..oqqyyyyyyyYo..',
          '.oqyyyyyyyyyyYo.',
          '.oyyyyyyyyyyyYo.',
          'oyyyoyyyoyyyoyYo',
          'ooyoloyomoyomoYo',
          'ololmmommmommmoo',
          'olmmmmmmmmmmmmMo',
          'olmmmmmmmmmmmmMo',
          'ommmmmmmmmmmmmMo',
          'ommmmmbbbbmmmmMo',
          'ommmmmmBBmmmmMMo',
          'oMmmmmmmmmmmmMMo',
          '.oMMmmmmmmmmMMo.',
          '..oooooooooooo..',
        ]),
        squashRow: 24,
        arm: Limb(6, 21, _wing()),
        foot: const Limb(9, 0, _shoe),
      ),
      // 3 병아리 + 러닝화 + 손목 밴드
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
        arm: Limb(5, 21, _wing(band: true)),
        foot: const Limb(9, 0, _shoe),
      ),
      // 4 마라토너 병아리: + 헤어밴드 + 완주 메달
      StageArt(
        body: const Art(9, [
          '..........oo........',
          '.........olo........',
          '......oooolooo......',
          '....oollllmmmmoo....',
          '...olllmmmmmmmmMo...',
          '..ollmmmmmmmmmmmMo..',
          '.ollmmmmmmmmmmmmmMo.',
          '.olmmmmmmmmmmmmmmMo.',
          'oAAAAAAAaaaaaaaaaaao',
          'oaaaaaaaaaaaaaaaaaao',
          'ommmmmmmmmmmmmmmmmMo',
          'ommmmmmmmmmmmmmmmmMo',
          'ommmmmmmmmmmmmmmmmMo',
          'ommmmmmmbbbbmmmmmmMo',
          'ommmmmmmmBBmmmmmmMMo',
          'oMmmmmmmdEEdmmmmmMMo',
          '.oMMmmmmEweEmmmmMMo.',
          '..ooooooEeeEoooooo..',
          '.........EE.........',
        ]),
        squashRow: 24,
        arm: Limb(4, 21, _wing(band: true)),
        foot: const Limb(8, 0, _shoe),
      ),
    ],
  ),
);
