// 후보 b "큰 머리 다마고치": 머리(몸 전체)를 크게, 눈을 크게(반짝임 포함), 굵은 2px 외곽선,
// 색 수를 줄임(몸은 기본·그림자 두 색). 빛은 왼쪽 위.
// 눈은 x=9~12, 19~22, y=16~19 (4×4), 볼 y=20, 부리는 body 의 x=14~17, y=19~20.
// 그림 줄은 둥근 실루엣 생성(외곽선 두께 2, 오른쪽·아래 그림자)을 바탕으로 손질했다.
import '../pet_art.dart';
import '../sprite_data.dart';
import 'candidate.dart';

const Palette _palette = {
  'o': 0xFF2B1810, // 외곽선 (굵게)
  'k': 0xFF2B1810, // 눈
  'w': 0xFFFFFFFF, // 눈 반짝임, 알 하이라이트
  'p': 0xFFFF9AA8, // 볼
  'y': 0xFFFFF0DB, // 알
  'Y': 0xFFF5C992, // 알 그림자
  'm': 0xFFFFD43B, // 병아리
  'M': 0xFFF2A516, // 병아리 그림자
  'b': 0xFFFF8A3D, // 부리
  'r': 0xFFF97316, // 러닝화 (primary)
  'a': 0xFF2563EB, // 헤어밴드·손목 밴드 (accent)
  'd': 0xFFE11D48, // 메달 끈
  'e': 0xFFFFE9A0, // 메달
  'E': 0xFFE0A526, // 메달 그림자
};

const _face = FaceArt(
  x: 8,
  y: 16,
  moods: {
    'normal': [
      '..kk........kk..',
      '.kwkk......kwkk.',
      '.kkkk......kkkk.',
      '..kk........kk..',
      'pp............pp',
    ],
  },
);

// 작은 팔: 굵은 외곽선이 몸과 갈라 놓아 동글한 혹처럼 보인다.
List<String> _arm({bool band = false}) => [
  '.oo',
  'omm',
  band ? 'oaa' : 'omm',
  '.oo',
];

const List<String> _shoe = ['rrrrrr', 'rrrrwr', 'oooooo'];

// 다마고치처럼 통통 튄다: 뜰 때 머리 2px, 팔을 번갈아 흔들고 발을 번갈아 든다.
// 숨쉬기·달리기 모두 k ≤ 0 (눌림은 squashRow 의 메달 끈을 지운다).
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
      Pose(footR: (1, 0), armL: 1, armR: -1),
      Pose(k: -1, lift: 1, footL: (1, 0), armL: -1, armR: 1),
      Pose(footL: (1, 0), armL: -1, armR: 1),
      Pose(k: -1, lift: 1, footR: (1, 0), armL: 1, armR: -1),
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

final candidateB = Candidate(
  id: 'b',
  title: '큰 머리 다마고치',
  palette: _palette,
  poses: _poses,
  kind: PetKind(
    name: 'chick',
    face: _face,
    hatAnchor: (x: 16, y: 14),
    accessoryAnchor: (x: 16, y: 16),
    stages: [
      // 1 알
      const StageArt(
        body: Art(11, [
          '.......oooooo.......',
          '.....oooooooooo.....',
          '....oooyyyyyYooo....',
          '...ooyywyyyyyyYoo...',
          '..ooyywwyyyyyyyYoo..',
          '.ooyyyyyyyyyyyyyYoo.',
          '.ooyyyyyyyyyyyyyYoo.',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooyyyyyyyyyyyyyyyYoo',
          'ooYyyyyyyyyyyyyyyYoo',
          '.ooYYyyyyyyyyyyYYoo.',
          '..oooYYYYYYYYYYooo..',
          '...oooooooooooooo...',
          '.....oooooooooo.....',
        ]),
        squashRow: 22,
        hops: true,
        tiltRows: 4,
      ),
      // 2 껍데기를 쓴 아기 병아리 + 러닝화
      StageArt(
        body: const Art(9, [
          '......oooooooooo......',
          '....oooooooooooooo....',
          '...oooyyyyyyyyyYooo...',
          '..oooyyyoyyyoyyyoYoo..',
          '.ooomoyomoyomoyomoYoo.',
          '.oommmommmommmommmooo.',
          'oommmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmMoo',
          'oommmmmmmbbbbmmmmmmMoo',
          'oommmmmmmmbbmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmMoo',
          'ooMMmmmmmmmmmmmmmmMMoo',
          '.oooMMMMMMMMMMMMMMooo.',
          '..oooooooooooooooooo..',
          '....oooooooooooooo....',
        ]),
        squashRow: 21,
        arm: Limb(3, 21, _arm()),
        foot: const Limb(9, 0, _shoe),
      ),
      // 3 병아리 + 러닝화 + 손목 밴드
      StageArt(
        body: const Art(7, [
          '............oo..........',
          '...........oo...........',
          '.......oooooooooo.......',
          '.....oooooooooooooo.....',
          '....ooommmmmmmmmMooo....',
          '...oommmmmmmmmmmmmMoo...',
          '..oommmmmmmmmmmmmmmMoo..',
          '.oommmmmmmmmmmmmmmmmMoo.',
          '.oommmmmmmmmmmmmmmmmMoo.',
          'oommmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmbbbbmmmmmmmMoo',
          'oommmmmmmmmbbmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmMoo',
          'ooMMmmmmmmmmmmmmmmmmMMoo',
          '.oooMMMMMMMMMMMMMMMMooo.',
          '..oooooooooooooooooooo..',
          '....oooooooooooooooo....',
        ]),
        squashRow: 21,
        arm: Limb(2, 21, _arm(band: true)),
        foot: const Limb(9, 0, _shoe),
      ),
      // 4 마라토너 병아리: + 헤어밴드 + 완주 메달
      StageArt(
        body: const Art(6, [
          '.............oo...........',
          '............oo............',
          '........oooooooooo........',
          '......oooooooooooooo......',
          '....oooommmmmmmmmMoooo....',
          '...ooommmmmmmmmmmmmMooo...',
          '..oommmmmmmmmmmmmmmmmMoo..',
          '.ooaaaaaaaaaaaaaaaaaaaaoo.',
          '.ooaaaaaaaaaaaaaaaaaaaaoo.',
          'oommmmmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmmmMoo',
          'oommmmmmmmmbbbbmmmmmmmmMoo',
          'oommmmmmmmmmbbmmmmmmmmmMoo',
          'oommmmmmmmmmmmmmmmmmmmmMoo',
          'ooddddddddddddddddddddddoo',
          'ooMMmmmmmmmoeeommmmmmmMMoo',
          '.oooMMMMMMoewEeoMMMMMMooo.',
          '..oooooooooeEEeooooooooo..',
          '....oooooooooooooooooo....',
        ]),
        squashRow: 21,
        arm: Limb(1, 21, _arm(band: true)),
        foot: const Limb(9, 0, _shoe),
      ),
    ],
  ),
);
