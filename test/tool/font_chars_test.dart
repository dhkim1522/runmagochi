import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// 앱 글꼴(assets/fonts/RunmagochiSans.ttf, Pretendard 서브셋)은 tool/font_chars.txt 의 글자만 남긴 서브셋이다.
// lib 문구에 새 글자를 쓰고 글자 목록·글꼴을 다시 만들지 않으면 실패한다.
void main() {
  const hint = '`tool/subset_fonts.py` 로 글자 목록과 글꼴을 다시 만드세요(실행 방법은 스크립트 맨 위)';
  final listed = File('tool/font_chars.txt')
      .readAsStringSync()
      .runes
      .where((r) => r >= 0x20) // 줄바꿈(Windows 의 CR 포함)은 뺀다.
      .toSet();
  final fontBytes = File('assets/fonts/RunmagochiSans.ttf').readAsBytesSync();
  final font = _Ttf(fontBytes);

  test('lib 의 .dart 파일에 나오는 모든 글자가 font_chars.txt 에 있다', () {
    final missing = <String, Set<String>>{};
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      for (final r in libRunes(f.readAsStringSync())) {
        if (!listed.contains(r)) {
          missing.putIfAbsent(_show(r), () => {}).add(f.path);
        }
      }
    }
    expect(missing, isEmpty, reason: '글자 목록에 없는 글자: $missing. $hint');
  });

  test('KS X 1001 한글 2,350자와 영문·숫자·기호가 font_chars.txt 에 있다', () {
    final hangul = listed.where((r) => r >= 0xAC00 && r <= 0xD7A3);
    expect(hangul.length, greaterThanOrEqualTo(2350));
    // KS X 1001 의 처음·끝 글자와 중간 글자.
    for (final c in ['가', '각', '똑', '뷰', '힝']) {
      expect(listed, contains(c.runes.single), reason: c);
    }
    for (var r = 0x20; r <= 0x7E; r++) {
      expect(listed, contains(r), reason: _show(r));
    }
    // 앱이 쓰거나 붙여 쓸 수 있는 기호. U+2060 은 단어 결합자(lib/core/korean.dart).
    for (final c in [
      '…',
      '·',
      '‘',
      '’',
      '“',
      '”',
      '°',
      '×',
      '−',
      '→',
      '⁠',
      ' ',
    ]) {
      expect(listed, contains(c.runes.single), reason: _show(c.runes.single));
    }
  });

  test('글꼴의 글자표(cmap)가 font_chars.txt 와 같다', () {
    final cmap = font.cmapCodepoints();
    expect(
      listed.difference(cmap).map(_show),
      isEmpty,
      reason: '글꼴에 없는 글자. $hint',
    );
    expect(
      cmap.difference(listed).map(_show),
      isEmpty,
      reason: '글자 목록에 없는데 글꼴에 남은 글자. $hint',
    );
  });

  test('글꼴은 굵기 축(400~800 포함)을 유지하고 4MB 이하다', () {
    final wght = font.axes()['wght'];
    expect(wght, isNotNull, reason: 'fvar wght 축이 없음');
    expect(wght!.$1, lessThanOrEqualTo(400));
    expect(wght.$2, greaterThanOrEqualTo(800));
    expect(fontBytes.length, lessThanOrEqualTo(4 * 1024 * 1024));
  });

  test('서브셋 글꼴은 예약 글꼴 이름(Pretendard)을 쓰지 않고 저작권·라이선스는 남긴다', () {
    // OFL 3조: 고친 글꼴은 Reserved Font Name 을 글꼴 이름으로 쓰지 못한다.
    // 출처를 밝히는 저작권(0)·상표(7)·제작사(8)·디자이너(9)·설명(10)·URL(11·12)·라이선스(13·14)는 둔다.
    const credits = {0, 7, 8, 9, 10, 11, 12, 13, 14};
    final names = font.names();
    for (final (id, text) in names) {
      if (credits.contains(id)) continue;
      expect(text, isNot(contains('Pretendard')), reason: 'name $id: $text');
    }
    Iterable<String> texts(int id) => [
      for (final (i, text) in names)
        if (i == id) text,
    ];
    expect(texts(0), contains(contains('Kil Hyung-jin')));
    expect(texts(13), contains(contains('SIL Open Font License')));
    expect(texts(1), allOf(isNotEmpty, everyElement('Runmagochi Sans')));
  });

  test('다시 만들 원본 전체 글꼴과 라이선스가 tool/fonts 에 있다', () {
    final source = File('tool/fonts/PretendardVariable.ttf');
    expect(source.existsSync(), isTrue);
    expect(
      _Ttf(source.readAsBytesSync()).cmapCodepoints().length,
      greaterThan(14000),
    );
    expect(
      File('tool/fonts/OFL-Pretendard.txt').readAsStringSync(),
      contains('Reserved Font Name Pretendard'),
    );
  });
}

/// 소스 글자들. 줄바꿈 등 제어 문자는 빼고, `\uXXXX`·`\u{X}` 이스케이프는 실제 글자로 더한다.
/// subset_fonts.py 의 lib_chars() 와 같은 규칙이다.
Iterable<int> libRunes(String source) sync* {
  for (final r in source.runes) {
    if (r >= 0x20) yield r;
  }
  for (final m in RegExp(
    r'\\u([0-9a-fA-F]{4})|\\u\{([0-9a-fA-F]{1,6})\}',
  ).allMatches(source)) {
    final r = int.parse(m.group(1) ?? m.group(2)!, radix: 16);
    if (r >= 0x20) yield r;
  }
}

String _show(int r) =>
    'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')} ${String.fromCharCode(r)}';

/// 테스트에 필요한 만큼만 읽는 TrueType 파서(cmap·fvar·name).
class _Ttf {
  _Ttf(Uint8List bytes) : _d = ByteData.sublistView(bytes) {
    final n = _d.getUint16(4);
    for (var i = 0; i < n; i++) {
      final rec = 12 + 16 * i;
      final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
      _tables[tag] = _d.getUint32(rec + 8);
    }
  }

  final ByteData _d;
  final _tables = <String, int>{};

  int _u16(int o) => _d.getUint16(o);
  int _u32(int o) => _d.getUint32(o);
  double _fixed(int o) => _d.getInt32(o) / 65536;

  /// 유니코드 cmap(3,10 형식 12 우선, 없으면 3,1 형식 4)에서 글리프가 있는 글자.
  Set<int> cmapCodepoints() {
    final base = _tables['cmap']!;
    int? sub12, sub4;
    for (var i = 0; i < _u16(base + 2); i++) {
      final rec = base + 4 + 8 * i;
      final sub = base + _u32(rec + 4);
      final (platform, encoding) = (_u16(rec), _u16(rec + 2));
      if (platform == 3 && encoding == 10 && _u16(sub) == 12) sub12 = sub;
      if (platform == 3 && encoding == 1 && _u16(sub) == 4) sub4 = sub;
    }
    final out = <int>{};
    if (sub12 != null) {
      final groups = _u32(sub12 + 12);
      for (var g = 0; g < groups; g++) {
        final o = sub12 + 16 + 12 * g;
        final start = _u32(o), end = _u32(o + 4), glyph = _u32(o + 8);
        for (var c = start; c <= end; c++) {
          if (glyph + (c - start) != 0) out.add(c);
        }
      }
      return out;
    }
    final t = sub4!;
    final segs = _u16(t + 6) ~/ 2;
    final ends = t + 14, starts = ends + 2 * segs + 2;
    final deltas = starts + 2 * segs, ranges = deltas + 2 * segs;
    for (var s = 0; s < segs; s++) {
      final start = _u16(starts + 2 * s), end = _u16(ends + 2 * s);
      final delta = _u16(deltas + 2 * s), range = _u16(ranges + 2 * s);
      for (var c = start; c <= end && c != 0xFFFF; c++) {
        var glyph = 0;
        if (range == 0) {
          glyph = (c + delta) & 0xFFFF;
        } else {
          glyph = _u16(ranges + 2 * s + range + 2 * (c - start));
          if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
        }
        if (glyph != 0) out.add(c);
      }
    }
    return out;
  }

  /// fvar 축 태그 → (최솟값, 최댓값).
  Map<String, (double, double)> axes() {
    final base = _tables['fvar'];
    if (base == null) return {};
    final first = base + _u16(base + 4);
    final count = _u16(base + 8), size = _u16(base + 10);
    return {
      for (var i = 0; i < count; i++)
        String.fromCharCodes([
          for (var k = 0; k < 4; k++) _d.getUint8(first + size * i + k),
        ]): (
          _fixed(first + size * i + 4),
          _fixed(first + size * i + 12),
        ),
    };
  }

  /// name 표의 (nameID, 글자) 목록. Windows·유니코드 플랫폼은 UTF-16BE, Mac 은 Latin-1 로 읽는다.
  List<(int, String)> names() {
    final base = _tables['name']!;
    final count = _u16(base + 2), strings = base + _u16(base + 4);
    final out = <(int, String)>[];
    for (var i = 0; i < count; i++) {
      final rec = base + 6 + 12 * i;
      final platform = _u16(rec), id = _u16(rec + 6);
      final len = _u16(rec + 8), off = strings + _u16(rec + 10);
      final raw = [for (var k = 0; k < len; k++) _d.getUint8(off + k)];
      final text = platform == 1
          ? latin1.decode(raw)
          : String.fromCharCodes([
              for (var k = 0; k + 1 < len; k += 2) raw[k] << 8 | raw[k + 1],
            ]);
      out.add((id, text));
    }
    return out;
  }
}
