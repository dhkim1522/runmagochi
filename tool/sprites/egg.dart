// 부화 연출 알 (F33, 결정 0037): 가만히 → 왼쪽·오른쪽 기울기 → 금 1 → 금 2 → 깨짐.
// 펫 시트와 같은 32칸 캔버스, 발 줄(y=29)에 알 밑이 닿는다. 색은 병아리 1단계 알과 같은
// 크림 껍데기(q·y·Y)에 외곽선 o, 깨질 때 반짝임 w·l.
import 'sprite_data.dart';

/// 캔버스 폭·높이(발 줄까지). 프레임은 모두 같은 크기라 가운데·바닥 정렬이 그대로다.
const int _w = 32;
const int _h = 30;

/// 알 왼쪽 위 자리(캔버스 기준).
const int _ex = 9;
const int _ey = 15;

const List<String> _egg = [
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
];

class _Canvas {
  final List<List<String>> _px = [
    for (var y = 0; y < _h; y++) List.filled(_w, '.'),
  ];

  void set(int x, int y, String c) {
    if (x < 0 || y < 0 || x >= _w || y >= _h) return;
    _px[y][x] = c;
  }

  /// [rows] 를 (x, y) 에 찍는다. 투명('.')은 건너뛴다.
  void stamp(List<String> rows, int x, int y) {
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final ch = rows[r][c];
        if (ch != '.') set(x + c, y + r, ch);
      }
    }
  }

  SpriteFrame frame() => SpriteFrame([for (final r in _px) r.join()]);
}

/// 윗부분 [rows] 줄을 [dx] 칸 밀어 기울어진 알.
List<String> _lean(int dx, {int rows = 5}) => [
  for (var i = 0; i < _egg.length; i++)
    if (i < rows) _shift(_egg[i], dx) else _egg[i],
];

String _shift(String row, int dx) {
  if (dx == 0) return row;
  final dots = '.' * dx.abs();
  return dx > 0
      ? dots + row.substring(0, row.length - dx)
      : row.substring(-dx) + dots;
}

/// 금: 알 안쪽 좌표(알 기준 x, y). 1은 꼭대기에서 내려오는 지그재그, 2는 옆으로 퍼진다.
const List<(int, int)> _crack1 = [(7, 1), (6, 2), (7, 3), (6, 4), (7, 5)];
const List<(int, int)> _crack2 = [
  ..._crack1,
  (5, 5),
  (4, 6),
  (3, 7),
  (2, 6),
  (8, 6),
  (9, 5),
  (10, 6),
  (11, 7),
];

SpriteFrame _eggFrame(List<String> rows, {List<(int, int)> crack = const []}) {
  final c = _Canvas()..stamp(rows, _ex, _ey);
  for (final (x, y) in crack) {
    c.set(_ex + x, _ey + y, 'o');
  }
  return c.frame();
}

/// 깨진 알: 아래 껍데기(들쭉날쭉한 윗선)와 위로 튀는 껍데기 두 조각, 반짝임.
SpriteFrame _burst() {
  final c = _Canvas();
  // 아래 껍데기: 알의 7번째 줄부터, 윗선은 톱니(이 사이에 외곽선을 둘러 막는다).
  c.stamp(_egg.sublist(7), _ex, _ey + 7);
  c.stamp(['.o....o....o..', 'oyo..oyo..oyYo'], _ex, _ey + 5);
  const teeth = 'oyo..oyo..oyYo';
  for (var x = 0; x < teeth.length; x++) {
    if (teeth[x] == '.') c.set(_ex + x, _ey + 7, 'o');
  }
  // 위 껍데기 두 조각: 왼쪽은 왼쪽 위로, 오른쪽은 오른쪽 위로.
  c.stamp(['..ooo', '.oqqy', 'oqyyo', 'ooo..'], _ex - 4, _ey - 6);
  c.stamp(['ooo..', 'yyYo.', 'oyyYo', '..ooo'], _ex + 13, _ey - 5);
  // 반짝임. 펫 그림처럼 위 5줄(말풍선 자리)은 비운다.
  for (final (x, y, ch) in const [
    (7, 8, 'w'),
    (24, 7, 'w'),
    (4, 13, 'l'),
    (27, 12, 'l'),
    (15, 6, 'l'),
    (16, 5, 'w'),
    (2, 9, 'w'),
    (29, 8, 'l'),
  ]) {
    c.set(x, y, ch);
  }
  return c.frame();
}

/// 부화 시트 프레임(왼쪽부터): 0 가만히, 1 왼쪽, 2 오른쪽, 3 금 1, 4 금 2, 5 깨짐.
final List<SpriteFrame> hatchFrames = [
  _eggFrame(_egg),
  _eggFrame(_lean(-1)),
  _eggFrame(_lean(1)),
  _eggFrame(_egg, crack: _crack1),
  _eggFrame(_egg, crack: _crack2),
  _burst(),
];
