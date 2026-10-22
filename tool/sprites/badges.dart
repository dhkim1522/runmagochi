// 배지 그림(페이즈 6 작업 6). id 는 lib/achievement/domain/badges.dart 의 badgeCatalog 와
// 같은 순서다. 24×24 투명 배경 한 장씩, 앱은 2배(48 논리 px)로 그린다.
//
// 12개가 같은 둥근 메달 테두리([badgeMedal])를 쓴다. 테두리 색은 등급([BadgeTier]),
// 안쪽 바탕의 문양은 배지 뜻을 따른다. 그림체는 펫과 같다: 진한 외곽선 o, 빛은 왼쪽 위,
// 3단 명암. 메달 테두리는 바깥 2줄이 볼록(왼쪽 위 밝음), 안쪽 1줄이 오목(왼쪽 위 어두움)이다.
import 'sprite_data.dart';

const int badgeSize = 24;

/// 메달 안쪽 바탕 글자. 문양은 이 칸에만 그린다.
const String badgeField = 'f';

/// 테두리 등급. 보상 코인을 따른다: 50 파랑, 100 동, 150·200 은, 300 금.
enum BadgeTier { blue, bronze, silver, gold }

/// 등급별 테두리 3단 명암(하이라이트 '1', 기본 '2', 그림자 '3').
const Map<BadgeTier, (int, int, int)> badgeTierTones = {
  BadgeTier.blue: (0xFF93C5FD, 0xFF60A5FA, 0xFF2563EB),
  BadgeTier.bronze: (0xFFF5C08F, 0xFFD98E4A, 0xFFA0592A),
  BadgeTier.silver: (0xFFF8FAFC, 0xFFCBD5E1, 0xFF8796AB),
  BadgeTier.gold: (0xFFFEF08A, 0xFFFACC15, 0xFFC88A04),
};

/// 등급과 상관없는 색. 문양은 펫 팔레트와 같은 계열의 색을 쓴다.
const Palette badgeBasePalette = {
  'o': 0xFF431407, // 외곽선 (ink), 숫자
  'f': 0xFFFFF7ED, // 메달 바탕 (cream)
  'w': 0xFFFFFFFF, // 반짝임, 신발 끈·밑창, 눈
  'i': 0xFFFDBA74, // 주황 하이라이트
  'r': 0xFFF97316, // 주황 (primary)
  'R': 0xFFC2410C, // 주황 그림자
  'e': 0xFFFCA5A5, // 빨강 하이라이트
  'd': 0xFFEF4444, // 빨강
  'D': 0xFFB91C1C, // 빨강 그림자
  'y': 0xFFFEF08A, // 노랑 하이라이트
  'Y': 0xFFFACC15, // 노랑 (트로피·해)
  'z': 0xFFD99A06, // 노랑 그림자
  'h': 0xFF86EFAC, // 초록 하이라이트
  'g': 0xFF22C55E, // 초록
  'G': 0xFF15803D, // 초록 그림자
  'l': 0xFFE2E8F0, // 눈 덮인 봉우리 그림자
  'u': 0xFF94A3B8, // 길 밝은 쪽
  'U': 0xFF64748B, // 길
  'k': 0xFF92400E, // 깃대
  's': 0xFFBAE6FD, // 물 하이라이트
  'S': 0xFF38BDF8, // 물
};

/// 등급 하나의 팔레트: 공통 색 + 테두리 3색.
Palette badgePalette(BadgeTier tier) {
  final (light, base, shadow) = badgeTierTones[tier]!;
  return {...badgeBasePalette, '1': light, '2': base, '3': shadow};
}

/// 메달 테두리. '1'·'2'·'3' 은 등급 색, 'f' 는 문양을 그리는 바탕.
const List<String> badgeMedal = [
  '.........oooooo.........',
  '......ooo111111ooo......',
  '.....o111111111122o.....',
  '....o11113333331122o....',
  '...o11133ffffff32222o...',
  '..o1113ffffffffff2222o..',
  '.o1113ffffffffffff2223o.',
  '.o113ffffffffffffff233o.',
  '.o113ffffffffffffff133o.',
  'o113ffffffffffffffff133o',
  'o113ffffffffffffffff133o',
  'o113ffffffffffffffff133o',
  'o113ffffffffffffffff133o',
  'o113ffffffffffffffff133o',
  'o113ffffffffffffffff133o',
  '.o113ffffffffffffff133o.',
  '.o112ffffffffffffff133o.',
  '.o1222ffffffffffff1333o.',
  '..o2222ffffffffff1333o..',
  '...o22221ffffff11333o...',
  '....o22331111113333o....',
  '.....o223333333333o.....',
  '......ooo333333ooo......',
  '.........oooooo.........',
];

/// 배지 하나. 문양 [emblem] 의 왼쪽 위가 ([x], [y]) 다.
class BadgeArt {
  const BadgeArt({
    required this.id,
    required this.tier,
    required this.x,
    required this.y,
    required this.emblem,
  });

  final String id;
  final BadgeTier tier;
  final int x;
  final int y;

  /// '.' 은 바탕을 그대로 둔다.
  final List<String> emblem;
}

final List<BadgeArt> badges = [
  // 첫 러닝: 오른쪽을 보는 러닝화(primary 주황), 흰 끈·밑창.
  BadgeArt(
    id: 'first_run',
    tier: BadgeTier.blue,
    x: 5,
    y: 7,
    emblem: [
      '.oooo.........',
      'oiirro........',
      'oirrwRo.......',
      'oirrrwRo......',
      'oirrrrwRooo...',
      'oirrrrrwrrrRo.',
      'oirrrrrrrrrrRo',
      'oRRRRRRRRRRRRo',
      'owwwwwwwwwwwwo',
      '.oooooooooooo.',
    ],
  ),
  // 첫 목표 달성: 깃대에 단 빨간 깃발.
  BadgeArt(
    id: 'first_goal',
    tier: BadgeTier.blue,
    x: 6,
    y: 5,
    emblem: [
      '.oo.........',
      'oyzo........',
      '.ooooooooo..',
      '.okoeedddddo',
      '.okoeddddddo',
      '.okoedddddDo',
      '.okoeddddDDo',
      '.okoddDDDDo.',
      '.okooooooo..',
      '.oko........',
      '.oko........',
      '.oko........',
      'oooooo......',
    ],
  ),
  // 한 번에 5·10·21km: 거리 숫자와 지평선까지 뻗은 길(잔디 사이 회색 길, 흰 가운데 선).
  BadgeArt(
    id: 'dist_5k',
    tier: BadgeTier.bronze,
    x: 4,
    y: 5,
    emblem: [
      '................',
      '.....ooooo......',
      '.....oo.........',
      '.....oooo.......',
      '........oo......',
      '.....oo.oo......',
      '......ooo.......',
      '................',
      'oooooooooooooooo',
      'hhhhhhouUohhhhhh',
      '.ggggouwwUogggg.',
      '.gggouUUUUUoggg.',
      '..gouUUwwUUUog..',
      '...uUUUUUUUUU...',
      '.....UUwwUU.....',
    ],
  ),
  BadgeArt(
    id: 'dist_10k',
    tier: BadgeTier.silver,
    x: 4,
    y: 5,
    emblem: [
      '................',
      '....oo..ooo.....',
      '...ooo.oo.oo....',
      '....oo.oo.oo....',
      '....oo.oo.oo....',
      '....oo.oo.oo....',
      '....oo..ooo.....',
      '................',
      'oooooooooooooooo',
      'hhhhhhouUohhhhhh',
      '.ggggouwwUogggg.',
      '.gggouUUUUUoggg.',
      '..gouUUwwUUUog..',
      '...uUUUUUUUUU...',
      '.....UUwwUU.....',
    ],
  ),
  BadgeArt(
    id: 'dist_half',
    tier: BadgeTier.gold,
    x: 4,
    y: 5,
    emblem: [
      '................',
      '....ooo...oo....',
      '...oo.oo.ooo....',
      '......oo..oo....',
      '....ooo...oo....',
      '...oo.....oo....',
      '...ooooo..oo....',
      '................',
      'oooooooooooooooo',
      'hhhhhhouUohhhhhh',
      '.ggggouwwUogggg.',
      '.gggouUUUUUoggg.',
      '..gouUUwwUUUog..',
      '...uUUUUUUUUU...',
      '.....UUwwUU.....',
    ],
  ),
  // 누적 50·100·300km: 눈 덮인 산. 등급은 테두리 색(동·은·금)으로 구분한다.
  for (final (id, tier) in [
    ('total_50', BadgeTier.bronze),
    ('total_100', BadgeTier.silver),
    ('total_300', BadgeTier.gold),
  ])
    BadgeArt(id: id, tier: tier, x: 4, y: 5, emblem: _mountain),
  // 목표 달성 10·30번: 트로피.
  BadgeArt(id: 'goals_10', tier: BadgeTier.bronze, x: 6, y: 6, emblem: _trophy),
  BadgeArt(id: 'goals_30', tier: BadgeTier.silver, x: 6, y: 6, emblem: _trophy),
  // 3일 연속: 불꽃.
  BadgeArt(
    id: 'streak_3',
    tier: BadgeTier.blue,
    x: 6,
    y: 5,
    emblem: [
      '.....o......',
      '....odo.....',
      '....oddo....',
      '...odrdo.o..',
      '...odrrdoodo',
      '..odrryrrrdo',
      '..odryyrrrdo',
      '.odrryyyyrDo',
      '.odryywyyrDo',
      '.odrywwwyrDo',
      '.oDrywwwyRDo',
      '..oDryyyRDo.',
      '...oDDDDDo..',
      '....ooooo...',
    ],
  ),
  // 새벽 러너: 바다 위로 떠오르는 해.
  BadgeArt(
    id: 'dawn',
    tier: BadgeTier.blue,
    x: 4,
    y: 6,
    emblem: [
      '.......rr.......',
      '...r...rr...r...',
      '....r......r....',
      '......oooo......',
      '.....oyyYYo.....',
      '.rr.oyYYYYzo.rr.',
      '....oyYYYYzo....',
      'oooooooooooooooo',
      'SSSSSSSSSSSSSSSS',
      '.SsswSSSSSSssSS.',
      '.SSSSSSSSSSSSSS.',
      '..SSSSssSSSSSS..',
      '...SSSSSSSSSS...',
      '.....SSSSSS.....',
    ],
  ),
];

const List<String> _mountain = [
  '.......oo.......',
  '......owlo......',
  '.....owwllo.....',
  '....owwwlllo....',
  '...ohgwgGlGlo...',
  '..ohggggGGGGGo..',
  '.ohgggggGGGGGGo.',
  'ohggggggGGGGGGGo',
  'hgggggggGGGGGGGG',
  'ggggggggGGGGGGGG',
  '.gggggggGGGGGGG.',
  '.gggggggGGGGGGG.',
  '..ggggggGGGGGG..',
  '...gggggGGGGG...',
  '.....gggGGG.....',
];

const List<String> _trophy = [
  '..oooooooo..',
  'oooyYYYYzooo',
  'o.owYYYYzo.o',
  'o.oyYYYYzo.o',
  '.ooyYYYYzoo.',
  '...oyYYzo...',
  '....oYzo....',
  '.....oo.....',
  '....oyzo....',
  '...oyYYzo...',
  '..oooooooo..',
];

/// 메달 테두리에 문양을 얹은 24줄.
List<String> badgeRows(BadgeArt b) {
  final g = [for (final r in badgeMedal) r.split('')];
  for (var y = 0; y < b.emblem.length; y++) {
    for (var x = 0; x < b.emblem[y].length; x++) {
      final ch = b.emblem[y][x];
      if (ch == '.') continue;
      final gy = b.y + y, gx = b.x + x;
      if (gy < 0 || gy >= badgeSize || gx < 0 || gx >= badgeSize) continue;
      g[gy][gx] = ch;
    }
  }
  return [for (final r in g) r.join()];
}

/// 배지 검사. 문제가 있으면 설명 목록(없으면 빈 목록).
List<String> validateBadge(BadgeArt b) {
  final problems = <String>[];
  final palette = badgePalette(b.tier);
  final w = b.emblem.isEmpty ? 0 : b.emblem.first.length;
  for (var y = 0; y < b.emblem.length; y++) {
    final row = b.emblem[y];
    if (row.length != w) {
      problems.add('${b.id}: 문양 ${y + 1}번째 줄 너비 ${row.length} (기대 $w)');
    }
    for (var x = 0; x < row.length; x++) {
      final ch = row[x];
      if (ch == '.') continue;
      if (!palette.containsKey(ch)) {
        problems.add('${b.id}: 문양 ${y + 1}번째 줄에 팔레트에 없는 글자 "$ch"');
      }
      final gy = b.y + y, gx = b.x + x;
      final inField =
          gy >= 0 &&
          gy < badgeSize &&
          gx >= 0 &&
          gx < badgeSize &&
          badgeMedal[gy][gx] == badgeField;
      if (!inField) problems.add('${b.id}: 문양 ($gx, $gy) 가 메달 바탕 밖이다');
    }
  }
  return problems;
}
