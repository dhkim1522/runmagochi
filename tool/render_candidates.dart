// 캐릭터 그림체 후보 a·b·c 미리보기를 그린다(페이즈 6 작업 1, 투표용).
// 사용: fvm dart run tool/render_candidates.dart (저장소 루트에서)
// 결과:
//   design/candidates/character/<a|b|c>/preview.png — 8배. 줄 = 단계 1~4, 칸 = idle 2 · run 4
//   design/candidates/character/<a|b|c>/run.gif — 8배, 2~4단계 달리기를 나란히, 10fps 반복
//   design/candidates/character/compare.png — 세 후보를 한 장에. 줄마다 왼쪽에 후보 글자와
//     실제 크기(1배·2배), 오른쪽에 8배 1~4단계 idle 과 4단계 달리기 4프레임
import 'dart:io';

import 'package:image/image.dart' as img;

import 'sprites/candidates/candidates.dart';
import 'sprites/pet_art.dart';
import 'sprites/render.dart';
import 'sprites/sprite_data.dart';

const String _out = 'design/candidates/character';
const int _scale = 8;
const int _tile = spriteSize * _scale;
const int _gap = 16;
const int _groupGap = 48;
const int _ink = 0xFF431407;

void main() {
  final problems = <String>[];
  for (final c in candidates) {
    for (final a in candidateActions) {
      for (var s = 0; s < c.kind.stages.length; s++) {
        final frames = c.body(s, a);
        for (var i = 0; i < frames.length; i++) {
          problems.addAll(
            validateFrame('${c.id} s${s + 1} $a #$i', frames[i], c.palette),
          );
        }
      }
      final faces = c.face(a);
      for (var i = 0; i < faces.length; i++) {
        problems.addAll(
          validateFrame('${c.id} face $a #$i', faces[i], c.palette),
        );
      }
    }
  }
  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exitCode = 1;
    return;
  }

  for (final c in candidates) {
    _save('$_out/${c.id}/preview.png', img.encodePng(_preview(c)));
    _save('$_out/${c.id}/run.gif', _runGif(c));
  }
  _save('$_out/compare.png', img.encodePng(_compare()));
  stdout.writeln('후보 ${candidates.length}개: $_out');
}

/// body 위에 face 를 겹쳐 그린다.
void _drawPet(
  img.Image im,
  Candidate c,
  int stage,
  String action,
  int i,
  int ox,
  int oy,
  int scale,
) {
  drawFrame(im, c.body(stage, action)[i], ox, oy, scale, palette: c.palette);
  drawFrame(im, c.face(action)[i], ox, oy, scale, palette: c.palette);
}

img.Image _canvas(int width, int height) {
  final im = img.Image(width: width, height: height);
  img.fill(im, color: _color(previewBg));
  return im;
}

/// 칸 x 좌표: idle 2 + run 4, 동작 사이는 넓게.
List<int> _actionCols(int x0) {
  final xs = <int>[];
  var x = x0;
  for (final a in candidateActions) {
    for (var i = 0; i < petActionFrames[a]!; i++) {
      xs.add(x);
      x += _tile + _gap;
    }
    x += _groupGap - _gap;
  }
  return xs;
}

img.Image _preview(Candidate c) {
  final cols = _actionCols(_gap);
  final width = cols.last + _tile + _gap;
  final rows = c.kind.stages.length;
  final im = _canvas(width, rows * (_tile + _gap) + _gap);
  for (var s = 0; s < rows; s++) {
    var col = 0;
    for (final a in candidateActions) {
      for (var i = 0; i < petActionFrames[a]!; i++) {
        _drawPet(
          im,
          c,
          s,
          a,
          i,
          cols[col++],
          _gap + s * (_tile + _gap),
          _scale,
        );
      }
    }
  }
  return im;
}

/// 2~4단계 달리기를 나란히. 프레임마다 0.1초(10fps), 끝없이 반복.
List<int> _runGif(Candidate c) {
  const stages = [1, 2, 3];
  final width = stages.length * (_tile + _gap) + _gap;
  final height = _tile + _gap * 2;
  final frames = petActionFrames['run']!;
  final rgb = <img.Image>[];
  for (var i = 0; i < frames; i++) {
    final im = _canvas(width, height);
    for (var k = 0; k < stages.length; k++) {
      _drawPet(
        im,
        c,
        stages[k],
        'run',
        i,
        _gap + k * (_tile + _gap),
        _gap,
        _scale,
      );
    }
    rgb.add(im);
  }
  // 색이 적어 팔레트 이미지로 바로 만든다(양자화·디더링 없이 색 그대로).
  final colors = <int>{};
  for (final im in rgb) {
    for (final p in im) {
      colors.add((p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt());
    }
  }
  final list = colors.toList();
  if (list.length > 256) throw StateError('GIF 색이 256개를 넘는다: ${list.length}');
  final index = {for (var i = 0; i < list.length; i++) list[i]: i};
  final enc = img.GifEncoder(repeat: 0);
  for (final im in rgb) {
    final pal = img.PaletteUint8(256, 3);
    for (var i = 0; i < list.length; i++) {
      pal.setRgb(
        i,
        (list[i] >> 16) & 0xFF,
        (list[i] >> 8) & 0xFF,
        list[i] & 0xFF,
      );
    }
    final out = img.Image(
      width: im.width,
      height: im.height,
      numChannels: 1,
      palette: pal,
    );
    for (final p in im) {
      final key = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
      out.setPixelIndex(p.x, p.y, index[key]!);
    }
    enc.addFrame(out, duration: 10);
  }
  return enc.finish()!;
}

const Map<String, List<String>> _glyphs = {
  'a': ['.##.', '...#', '.###', '#..#', '.###'],
  'b': ['#...', '#...', '###.', '#..#', '###.'],
  'c': ['....', '.###', '#...', '#...', '.###'],
};

img.Image _compare() {
  const labelScale = 12;
  const small = 2 * spriteSize; // 2배 칸
  final left = _gap + 4 * small + 3 * 4 + _groupGap;
  final idleX = [for (var s = 0; s < 4; s++) left + s * (_tile + _gap)];
  final runX0 = idleX.last + _tile + _groupGap;
  final runX = [for (var i = 0; i < 4; i++) runX0 + i * (_tile + _gap)];
  final width = runX.last + _tile + _gap;
  final rowH = _tile + _gap;
  final im = _canvas(width, candidates.length * rowH + _gap);
  for (var r = 0; r < candidates.length; r++) {
    final c = candidates[r];
    final oy = _gap + r * rowH;
    // 후보 글자.
    final glyph = _glyphs[c.id]!;
    for (var y = 0; y < glyph.length; y++) {
      for (var x = 0; x < glyph[y].length; x++) {
        if (glyph[y][x] != '#') continue;
        img.fillRect(
          im,
          x1: _gap + x * labelScale,
          y1: oy + y * labelScale,
          x2: _gap + (x + 1) * labelScale - 1,
          y2: oy + (y + 1) * labelScale - 1,
          color: _color(_ink),
        );
      }
    }
    // 실제 크기: 2배, 그 아래 1배.
    final smallY = oy + 5 * labelScale + _gap;
    for (var s = 0; s < 4; s++) {
      _drawPet(im, c, s, 'idle', 0, _gap + s * (small + 4), smallY, 2);
      _drawPet(
        im,
        c,
        s,
        'idle',
        0,
        _gap + s * (spriteSize + 4),
        smallY + small + _gap,
        1,
      );
    }
    for (var s = 0; s < 4; s++) {
      _drawPet(im, c, s, 'idle', 0, idleX[s], oy, _scale);
    }
    for (var i = 0; i < 4; i++) {
      _drawPet(im, c, 3, 'run', i, runX[i], oy, _scale);
    }
  }
  return im;
}

void _save(String path, List<int> bytes) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
}

img.Color _color(int argb) => img.ColorRgba8(
  (argb >> 16) & 0xFF,
  (argb >> 8) & 0xFF,
  argb & 0xFF,
  (argb >> 24) & 0xFF,
);
