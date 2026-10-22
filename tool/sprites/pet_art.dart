// 펫 스프라이트(작업 9) 공통: 팔레트, 그림 데이터 형식, 프레임 펼치기.
//
// 종류마다 단계별 기본 그림 한 장(몸 + 장비, 눈 없음)과 표정 그림을 둔다.
// 동작 프레임은 기본 그림을 정해진 자세표(Pose)대로 변형해 만든다.
//   - 숨쉬기·뛰어오름: [StageArt.squashRow] 위쪽(머리)을 위아래로 민다. 머리가
//     움직인 만큼 face 프레임도 같이 움직인다(모든 단계 공통 자세표라 단계끼리 맞는다).
//   - 발: 몸 뒤에 그린다. 든 발은 몸에 가려 접힌 것처럼 보인다.
//   - 팔(날개): 몸 옆에 그리고 위아래로 흔든다.
//   - 공중 프레임: 전체를 1px 올린다(발끝 y=28).
// 결과 프레임은 32×30 캔버스 그대로라(가운데 정렬 오프셋 0, 맨 아랫줄 y=29)
// sprite_data.dart 의 validateFrame·pixelAt 을 그대로 쓴다.
import 'sprite_data.dart';

const List<String> petActions = ['idle', 'walk', 'run'];
const List<String> petMoods = ['normal', 'sleepy', 'asleep'];
const Map<String, int> petActionFrames = {'idle': 2, 'walk': 4, 'run': 4};

/// 잠든 표정의 "z". 몸 밖(머리 위 허공)에 떠 있어도 되는 유일한 face 글자.
const String sleepZ = 'z';

const Palette petPalette = {
  'o': 0xFF431407, // 외곽선 (ink)
  'k': 0xFF431407, // 눈·입
  'w': 0xFFFFFFFF, // 눈 반짝임, 신발 끈
  'h': 0xFFFFEDD5, // 하이라이트 (surface-soft)
  'p': 0xFFFDA4AF, // 볼
  'b': 0xFFFB923C, // 젤리 몸, 병아리 부리
  'B': 0xFFEA580C, // 젤리 그림자
  'g': 0xFF15803D, // 잎
  'G': 0xFF4ADE80, // 잎 밝은 쪽
  'y': 0xFFFFE9CC, // 알 껍데기 (눈 반짝임 흰색이 보이게 바탕 cream 보다 조금 진하게)
  'Y': 0xFFFED7AA, // 알 껍데기 그림자
  'm': 0xFFFACC15, // 병아리 몸
  'M': 0xFFCA8A04, // 병아리 그림자
  'c': 0xFF92400E, // 도토리 모자
  'C': 0xFFB45309, // 도토리 모자 밝은 쪽
  'n': 0xFFF4A261, // 도토리 몸
  'N': 0xFFC2410C, // 도토리 몸 그림자
  'r': 0xFFF97316, // 러닝화 (primary)
  'a': 0xFF2563EB, // 헤어밴드·손목 밴드 (accent)
  'd': 0xFFDC2626, // 메달 끈
  'e': 0xFFFDE047, // 메달
  'E': 0xFFA16207, // 메달 테두리
  'z': 0xFF60A5FA, // 잠든 z
  // 아이템(작업 8, tool/sprites/items.dart)
  'T': 0xFF2DD4BF, // 러닝 캡
  'U': 0xFF0F766E, // 러닝 캡 챙
  'v': 0xFFC4B5FD, // 비니
  'V': 0xFF8B5CF6, // 비니 골
  's': 0xFFFDE68A, // 밀짚
  'S': 0xFFD4A24C, // 밀짚 결
  'L': 0xFF1E293B, // 선글라스 알
  'u': 0xFF94A3B8, // 헤드폰 머리띠
  'R': 0xFFEF4444, // 헤드폰 귀덮개
  'f': 0xFFF472B6, // 꽃잎
};

/// 가운데 정렬 그림. [rows] 첫 줄이 y=[top] 에 놓인다.
class Art {
  const Art(this.top, this.rows);

  final int top;
  final List<String> rows;
}

/// 왼쪽 팔·발 그림. 오른쪽은 좌우를 뒤집어 대칭 위치에 놓는다.
class Limb {
  const Limb(this.x, this.y, this.rows);

  /// 왼쪽 것의 왼쪽 위 좌표. 발은 [y] 를 쓰지 않는다(맨 아랫줄이 y=29).
  final int x;
  final int y;
  final List<String> rows;
}

class StageArt {
  const StageArt({
    required this.body,
    required this.squashRow,
    this.arm,
    this.foot,
    this.hops = false,
    this.tiltRows = 0,
  });

  final Art body;

  /// 숨쉬기·늘이기 때 지우거나 겹치는 줄(y). 이 줄 위가 머리 쪽으로 같이 움직인다.
  /// face 의 모든 줄보다 아래여야 한다.
  final int squashRow;

  final Limb? arm;
  final Limb? foot;

  /// 발이 없어 걷기·달리기를 통통 튀기로 대신한다(병아리 1단계 알).
  final bool hops;

  /// 튈 때 좌우로 기우는 윗부분 줄 수(맨 윗줄부터).
  final int tiltRows;
}

/// 표정 그림. 기분마다 같은 크기의 줄 목록, 왼쪽 위가 ([x], [y]).
class FaceArt {
  const FaceArt({required this.x, required this.y, required this.moods});

  final int x;
  final int y;
  final Map<String, List<String>> moods;
}

/// 아이템 기준점. [x] 는 그림 가로 가운데, [y] 는 그림 위치를 재는 줄([ItemArt.top]).
typedef Anchor = ({int x, int y});

class PetKind {
  const PetKind({
    required this.name,
    required this.stages,
    required this.face,
    required this.hatAnchor,
    required this.accessoryAnchor,
  });

  /// 폴더 이름: chick·jelly·acorn.
  final String name;
  final List<StageArt> stages;
  final FaceArt face;

  /// 모자 챙 맨 아랫줄 자리. 4단계가 같은 자리를 쓴다(face 처럼 머리 위치가 같다).
  final Anchor hatAnchor;

  /// 소품 기준점: 눈 윗줄.
  final Anchor accessoryAnchor;
}

/// 아이템 그림 한 장. 4단계·3종이 같은 그림을 쓰고, 종류의 기준점에 맞춰 놓는다.
class ItemArt {
  const ItemArt({
    required this.id,
    required this.slot,
    required this.top,
    required this.rows,
  });

  /// 상점 목록(lib/shop/domain/catalog.dart)의 id.
  final String id;

  /// 폴더 이름: hat·accessory.
  final String slot;

  /// 첫 줄의 y 를 기준점 y 에서 잰 값(위쪽이 음수).
  final int top;

  /// 가로 길이가 짝수여야 가운데에 맞는다.
  final List<String> rows;
}

/// 한 프레임의 자세.
class Pose {
  const Pose({
    this.k = 0,
    this.lift = 0,
    this.footL = (0, 0),
    this.footR = (0, 0),
    this.armL = 0,
    this.armR = 0,
    this.tilt = 0,
  });

  /// 머리 쪽 이동(+ 아래로 눌림, - 위로 늘어남).
  final int k;

  /// 공중으로 뜬 높이.
  final int lift;

  /// 발: (든 높이, 바깥으로 벌린 칸).
  final (int, int) footL;
  final (int, int) footR;

  /// 팔: 위아래 이동(+ 아래).
  final int armL;
  final int armR;

  /// 윗부분 좌우 기울기(튀는 알).
  final int tilt;

  /// face 가 따라 움직일 세로 오프셋.
  int get headDy => k - lift;
}

const Map<String, List<Pose>> walkerPoses = {
  'idle': [Pose(), Pose(k: 1)],
  'walk': [
    Pose(footL: (1, 0)),
    Pose(k: -1, armL: 1, armR: -1),
    Pose(footR: (1, 0)),
    Pose(k: -1, armL: -1, armR: 1),
  ],
  'run': [
    Pose(footL: (0, 1), footR: (2, -1), armL: 1, armR: -2),
    Pose(k: -1, lift: 1, footL: (2, 0), armR: -1),
    Pose(footR: (0, 1), footL: (2, -1), armL: -2, armR: 1),
    Pose(k: -1, lift: 1, footR: (2, 0), armL: -1),
  ],
};

const Map<String, List<Pose>> hopperPoses = {
  'idle': [Pose(), Pose(k: 1)],
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
};

/// 걷는 단계·튀는 단계의 자세표 한 벌. 기본은 [petPoses].
/// 캐릭터 후보(tool/sprites/candidates/)는 자기 자세표를 넘긴다.
class PoseSet {
  const PoseSet({required this.walker, required this.hopper});

  final Map<String, List<Pose>> walker;
  final Map<String, List<Pose>> hopper;
}

const PoseSet petPoses = PoseSet(walker: walkerPoses, hopper: hopperPoses);

List<Pose> posesFor(StageArt s, String action, [PoseSet set = petPoses]) =>
    (s.hops ? set.hopper : set.walker)[action]!;

/// face 가 쓰는 동작별 머리 오프셋(걷는 단계 기준). 알도 같은 값을 내야 한다.
List<int> headOffsets(String action, [PoseSet set = petPoses]) => [
  for (final p in set.walker[action]!) p.headDy,
];

const int _h = footY + 1; // 캔버스 높이 30 (y=0..29)

typedef _Grid = List<List<String>>;

_Grid _empty() => List.generate(_h, (_) => List.filled(spriteSize, '.'));

void _stamp(_Grid g, List<String> rows, int x0, int y0, {bool under = false}) {
  for (var y = 0; y < rows.length; y++) {
    final gy = y0 + y;
    if (gy < 0 || gy >= _h) continue;
    for (var x = 0; x < rows[y].length; x++) {
      final ch = rows[y][x];
      if (ch == '.') continue;
      final gx = x0 + x;
      if (gx < 0 || gx >= spriteSize) continue;
      if (under && g[gy][gx] != '.') continue;
      g[gy][gx] = ch;
    }
  }
}

List<String> _mirror(List<String> rows) => [
  for (final r in rows) r.split('').reversed.join(),
];

SpriteFrame _toFrame(_Grid g) => SpriteFrame([for (final r in g) r.join()]);

/// 단계 하나, 동작 하나의 body 프레임들.
List<SpriteFrame> bodyFrames(
  StageArt s,
  String action, [
  PoseSet set = petPoses,
]) => [for (final p in posesFor(s, action, set)) _bodyFrame(s, p)];

SpriteFrame _bodyFrame(StageArt s, Pose p) {
  // 1) 기본 몸.
  var body = _empty();
  final art = s.body;
  _stamp(body, art.rows, (spriteSize - art.rows.first.length) ~/ 2, art.top);

  // 2) 튀는 알: 윗부분 기울기.
  if (p.tilt != 0) {
    for (var y = art.top; y < art.top + s.tiltRows; y++) {
      final row = body[y];
      final shifted = List.filled(spriteSize, '.');
      for (var x = 0; x < spriteSize; x++) {
        final nx = x + p.tilt;
        if (nx >= 0 && nx < spriteSize) shifted[nx] = row[x];
      }
      body[y] = shifted;
    }
  }

  // 3) 머리 쪽 눌림(+)·늘어남(-).
  body = _shiftHead(body, s.squashRow, p.k);

  // 4) 발(몸 뒤) → 몸 → 팔(몸 위).
  final g = _empty();
  final foot = s.foot;
  if (foot != null) {
    final w = foot.rows.first.length;
    final h = foot.rows.length;
    final (upL, outL) = p.footL;
    final (upR, outR) = p.footR;
    final lx = foot.x - outL;
    _stamp(g, foot.rows, lx, footY + 1 - h - upL);
    final rx = spriteSize - (foot.x - outR) - w;
    _stamp(g, _mirror(foot.rows), rx, footY + 1 - h - upR);
  }
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < spriteSize; x++) {
      if (body[y][x] != '.') g[y][x] = body[y][x];
    }
  }
  final arm = s.arm;
  if (arm != null) {
    final w = arm.rows.first.length;
    _stamp(g, arm.rows, arm.x, arm.y + p.k + p.armL);
    _stamp(g, _mirror(arm.rows), spriteSize - arm.x - w, arm.y + p.k + p.armR);
  }

  // 5) 공중.
  return _toFrame(_lift(g, p.lift));
}

_Grid _shiftHead(_Grid g, int squashRow, int k) {
  if (k == 0) return g;
  final out = _empty();
  for (var y = 0; y < _h; y++) {
    out[y] = List.of(g[y]);
  }
  if (k > 0) {
    // 머리를 k 줄 내린다: squashRow 위 줄들이 squashRow 까지 덮는다.
    for (var y = squashRow + k - 1; y >= 0; y--) {
      final src = y - k;
      out[y] = src >= 0 ? List.of(g[src]) : List.filled(spriteSize, '.');
    }
  } else {
    // 머리를 -k 줄 올린다: squashRow 줄을 복제해 늘인다.
    final m = -k;
    for (var y = 0; y < squashRow; y++) {
      var src = y + m;
      if (src > squashRow) src = squashRow;
      out[y] = List.of(g[src]);
    }
  }
  return out;
}

_Grid _lift(_Grid g, int lift) {
  if (lift == 0) return g;
  final out = _empty();
  for (var y = 0; y < _h; y++) {
    final src = y + lift;
    if (src < _h) out[y] = List.of(g[src]);
  }
  return out;
}

/// 표정 하나, 동작 하나의 face 프레임들.
List<SpriteFrame> faceFrames(
  PetKind kind,
  String mood,
  String action, [
  PoseSet set = petPoses,
]) {
  final offsets = headOffsets(action, set);
  return [
    for (var i = 0; i < offsets.length; i++)
      _faceFrame(kind.face, mood, offsets[i], i),
  ];
}

SpriteFrame _faceFrame(FaceArt f, String mood, int dy, int frame) {
  final g = _empty();
  _stamp(g, f.moods[mood]!, f.x, f.y + dy);
  if (mood == 'asleep') {
    // 머리 위 허공에 떠오르는 z. 프레임마다 1px 오르내린다.
    _stamp(g, const ['zzzz', '..z.', '.z..', 'zzzz'], 24, 4 - frame % 2);
  }
  return _toFrame(g);
}

/// 아이템 하나, 동작 하나의 프레임들. face 와 같은 [headOffsets] 로 움직인다.
List<SpriteFrame> itemFrames(PetKind kind, ItemArt item, String action) {
  final anchor = item.slot == 'hat' ? kind.hatAnchor : kind.accessoryAnchor;
  final x0 = anchor.x - item.rows.first.length ~/ 2;
  final y0 = anchor.y + item.top;
  return [
    for (final dy in headOffsets(action)) _itemFrame(item.rows, x0, y0 + dy),
  ];
}

SpriteFrame _itemFrame(List<String> rows, int x0, int y0) {
  final g = _empty();
  _stamp(g, rows, x0, y0);
  return _toFrame(g);
}

/// 팔(날개) 그림. [band] 면 손목 밴드(accent)를 두른다.
List<String> armRows(String fill, {bool band = false}) => [
  '.o',
  'o$fill',
  band ? 'oa' : 'o$fill',
  '.o',
];

/// 1단계 발: 몸 아래 작은 발 두 개.
const List<String> nubFoot = ['oo'];

/// 러닝화(primary) 앞모습: 흰 끈 한 점, 진한 밑창.
const List<String> shoeFoot = ['orwro', 'ooooo'];
