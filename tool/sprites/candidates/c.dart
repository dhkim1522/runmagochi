// 후보 c "플랫 마스코트"(무드보드 design/references/b·c): 검은 외곽선 대신 몸색의 어두운 색
// 테두리, 명암 없는 단순한 도형, 선으로 그린 웃는 눈(^ ^), 막대 팔다리.
// 눈은 x=11~13, 18~20, y=18·19, 볼 y=20, 부리는 body 의 x=15·16, y=20.
// 그림 줄은 둥근 실루엣 생성(테두리 두께 1)을 바탕으로 손질했다.
import '../pet_art.dart';
import '../sprite_data.dart';
import 'candidate.dart';

const Palette _palette = {
  'o': 0xFFE0952A, // 몸 테두리 (몸색보다 어둡게)
  'm': 0xFFFFD75E, // 병아리
  'k': 0xFF5B3A1E, // 눈·팔다리 선
  'p': 0xFFFFAFA3, // 볼
  'b': 0xFFFF8A3D, // 부리
  'y': 0xFFFFEFD5, // 알·껍데기
  'Y': 0xFFD9A35F, // 알 테두리
  'r': 0xFFF97316, // 러닝화 (primary)
  'R': 0xFFC2410C, // 러닝화 밑창
  'a': 0xFF2563EB, // 헤어밴드·손목 밴드 (accent)
  'A': 0xFF1E40AF, // 헤어밴드 테두리
  'd': 0xFFEF4444, // 메달 끈
  'D': 0xFFB91C1C, // 메달 끈 테두리
  'e': 0xFFFFE27A, // 메달
  'E': 0xFFC27C0E, // 메달 테두리
  'w': 0xFFFFFFFF, // 메달 반짝임
};

const _face = FaceArt(
  x: 10,
  y: 18,
  moods: {
    'normal': ['..k......k..', '.k.k....k.k.', 'pp........pp'],
  },
);

// 막대 팔: 몸 옆에서 비스듬히 내려온다. 밴드는 손끝.
List<String> _arm({bool band = false}) => ['..k', '.k.', band ? 'a..' : 'k..'];

// 막대 다리 + 납작한 러닝화(발끝이 바깥쪽).
const List<String> _foot = ['..k.', '..k.', '..k.', 'rrrr', 'RRRR'];

// 다리를 크게 든다: 든 발은 몸 뒤로 2px 올라가 무릎을 든 것처럼 보인다.
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
      Pose(footL: (0, 1), footR: (2, 0), armL: 2, armR: -2),
      Pose(k: -1, lift: 1, footR: (1, 0), armL: 1, armR: -1),
      Pose(footR: (0, 1), footL: (2, 0), armL: -2, armR: 2),
      Pose(k: -1, lift: 1, footL: (1, 0), armL: -1, armR: 1),
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

final candidateC = Candidate(
  id: 'c',
  title: '플랫 마스코트',
  palette: _palette,
  poses: _poses,
  kind: PetKind(
    name: 'chick',
    face: _face,
    hatAnchor: (x: 16, y: 16),
    accessoryAnchor: (x: 16, y: 18),
    stages: [
      // 1 알
      const StageArt(
        body: Art(13, [
          '.....YYYY.....',
          '...YYyyyyYY...',
          '..YyyyyyyyyY..',
          '..YyyyyyyyyY..',
          '.YyyyyyyyyyyY.',
          '.YyyyyyyyyyyY.',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          'YyyyyyyyyyyyyY',
          '.YyyyyyyyyyyY.',
          '..YYyyyyyyYY..',
          '....YYYYYY....',
        ]),
        squashRow: 21,
        hops: true,
        tiltRows: 3,
      ),
      // 2 껍데기를 쓴 아기 병아리 + 러닝화
      StageArt(
        body: const Art(10, [
          '.....YYYYYY.....',
          '...YYyyyyyyYY...',
          '..YyyyyyyyyyyY..',
          '.YyyYyyyYyyyYyY.',
          '.oyYmYyYmYyYmYY.',
          'omYmmmYmmmYmmmYo',
          'ommmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmo',
          'ommmmmmbbmmmmmmo',
          '.ommmmmmmmmmmmo.',
          '.ommmmmmmmmmmmo.',
          '..oommmmmmmmoo..',
          '....oooooooo....',
        ]),
        squashRow: 21,
        arm: Limb(6, 19, _arm()),
        foot: const Limb(11, 0, _foot),
      ),
      // 3 병아리 + 러닝화 + 손목 밴드
      StageArt(
        body: const Art(7, [
          '..........o.......',
          '.........o........',
          '.....oooooooo.....',
          '...oommmmmmmmoo...',
          '..ommmmmmmmmmmmo..',
          '.ommmmmmmmmmmmmmo.',
          '.ommmmmmmmmmmmmmo.',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmo',
          'ommmmmmmbbmmmmmmmo',
          '.ommmmmmmmmmmmmmo.',
          '.ommmmmmmmmmmmmmo.',
          '..oommmmmmmmmmoo..',
          '....oooooooooo....',
        ]),
        squashRow: 21,
        arm: Limb(5, 19, _arm(band: true)),
        foot: const Limb(11, 0, _foot),
      ),
      // 4 마라토너 병아리: + 헤어밴드 + 완주 메달
      StageArt(
        body: const Art(5, [
          '...........o........',
          '..........o.........',
          '......oooooooo......',
          '....oommmmmmmmoo....',
          '...ommmmmmmmmmmmo...',
          '..ommmmmmmmmmmmmmo..',
          '.ommmmmmmmmmmmmmmmo.',
          '.ommmmmmmmmmmmmmmmo.',
          'ommmmmmmmmmmmmmmmmmo',
          'AaaaaaaaaaaaaaaaaaaA',
          'AaaaaaaaaaaaaaaaaaaA',
          'ommmmmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmmmo',
          'ommmmmmmmmmmmmmmmmmo',
          '.ommmmmmmbbmmmmmmmo.',
          '.ommmmmmmmmmmmmmmmo.',
          '..DddddddddddddddD..',
          '...oommmmEEmmmmoo...',
          '.....oooEweEooo.....',
          '........EeeE........',
          '.........EE.........',
        ]),
        squashRow: 21,
        arm: Limb(4, 19, _arm(band: true)),
        foot: const Limb(11, 0, _foot),
      ),
    ],
  ),
);
