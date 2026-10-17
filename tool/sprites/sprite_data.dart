// 도트 캐릭터를 데이터로 정의하는 형식.
//
// 프레임 하나는 문자열 줄 목록이다. 한 글자가 한 픽셀이고, 팔레트에서 색을 찾는다.
// '.' 은 투명. 줄 너비는 모두 같아야 하고, 프레임은 32×32 안에 들어가야 한다.
// 렌더러가 프레임을 가로 가운데, 맨 아랫줄이 y=29(발끝 기준점)에 오도록 놓는다.

/// 팔레트: 글자 → 0xAARRGGBB.
typedef Palette = Map<String, int>;

const int spriteSize = 32;

/// 발끝(맨 아래 불투명 줄)이 놓이는 y.
const int footY = 29;

class SpriteFrame {
  const SpriteFrame(this.rows);

  final List<String> rows;

  int get width => rows.isEmpty ? 0 : rows.first.length;
  int get height => rows.length;
}

/// 프레임 검사. 문제가 있으면 설명 목록을 돌려준다(없으면 빈 목록).
List<String> validateFrame(String name, SpriteFrame f, Palette palette) {
  final problems = <String>[];
  if (f.height == 0) return ['$name: 빈 프레임'];
  if (f.height > footY + 1) problems.add('$name: 높이 ${f.height} 가 ${footY + 1} 보다 크다');
  if (f.width > spriteSize) problems.add('$name: 너비 ${f.width} 가 $spriteSize 보다 크다');
  if ((spriteSize - f.width).isOdd) problems.add('$name: 너비 ${f.width} 는 가운데 정렬을 위해 짝수여야 한다');
  for (var y = 0; y < f.height; y++) {
    final row = f.rows[y];
    if (row.length != f.width) {
      problems.add('$name: ${y + 1}번째 줄 너비 ${row.length} (기대 ${f.width})');
    }
    for (final ch in row.split('')) {
      if (ch != '.' && !palette.containsKey(ch)) {
        problems.add('$name: ${y + 1}번째 줄에 팔레트에 없는 글자 "$ch"');
      }
    }
  }
  return problems;
}

/// 32×32 캔버스에 놓았을 때 (x, y) 의 색. 투명이면 null.
int? pixelAt(SpriteFrame f, Palette palette, int x, int y) {
  final left = (spriteSize - f.width) ~/ 2;
  final top = footY + 1 - f.height;
  final fx = x - left;
  final fy = y - top;
  if (fx < 0 || fy < 0 || fx >= f.width || fy >= f.height) return null;
  final ch = f.rows[fy][fx];
  if (ch == '.') return null;
  return palette[ch];
}
