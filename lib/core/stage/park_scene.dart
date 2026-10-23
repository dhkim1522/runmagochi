import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'stage_scene.dart';

/// 기본 무대 배경 "공원 산책로"(작업 25, 관문 3 에서 고른 안 2): 모래빛 흙길이 펫 뒤
/// 소실점으로 좁아지고, 길 위 자갈·풀잎·작은 꽃 점, 길가 둥근 나무·덤불, 지평선의 두 겹
/// 나무 줄. 수치·색은 `design/mockups/phase-6/stage-background/gen.py` 의 park 와 같다.
///
/// 하늘·풀밭·풀잎은 무대 토큰(`AppColors` 의 `stageSky`·`stageGround`·`stageGroundLine`)을
/// 쓰고, 이 배경만의 색은 [ParkPalette] 에 둔다(`docs/design/tokens.json` 의 `stageScene.park`).
const StageScene parkScene = StageScene(
  name: 'park',
  sky: _ParkSky(),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
);

/// 공원 산책로 색(라이트·다크). 연두 `primary` 는 배경에 쓰지 않는다.
@immutable
class ParkPalette {
  const ParkPalette({
    required this.path,
    required this.edge,
    required this.pebble,
    required this.pebbleHi,
    required this.canopy,
    required this.canopyHi,
    required this.trunk,
    required this.far,
    required this.far2,
    required this.flower,
    required this.cloud,
  });

  /// 흙길.
  final Color path;

  /// 길 가장자리.
  final Color edge;

  /// 자갈.
  final Color pebble;

  /// 밝은 자갈.
  final Color pebbleHi;

  /// 나무·덤불 잎.
  final Color canopy;

  /// 잎 밝은 덧칠.
  final Color canopyHi;

  /// 나무 줄기.
  final Color trunk;

  /// 지평선 앞 나무 줄.
  final Color far;

  /// 지평선 뒤 나무 줄.
  final Color far2;

  /// 작은 꽃.
  final Color flower;

  /// 하늘 구름(라이트는 하늘보다 옅게, 다크는 하늘보다 살짝 밝게).
  final Color cloud;

  static const light = ParkPalette(
    path: Color(0xFFEBE0C6),
    edge: Color(0xFFDCCCA8),
    pebble: Color(0xFFD2C199),
    pebbleHi: Color(0xFFF6F0DF),
    canopy: Color(0xFFA9D07F),
    canopyHi: Color(0xFFBEDE98),
    trunk: Color(0xFFA88B66),
    far: Color(0xFFBFE09A),
    far2: Color(0xFFD1E9B2),
    flower: Color(0xFFFFFFFF),
    cloud: Color(0xFFF4FBE8),
  );

  static const dark = ParkPalette(
    path: Color(0xFF3A3427),
    edge: Color(0xFF4A4331),
    pebble: Color(0xFF50483A),
    pebbleHi: Color(0xFF463F2F),
    canopy: Color(0xFF2E4A22),
    canopyHi: Color(0xFF3A5B2B),
    trunk: Color(0xFF4B3C29),
    far: Color(0xFF263E1C),
    far2: Color(0xFF22361A),
    flower: Color(0xFFC9D3BE),
    cloud: Color(0xFF263620),
  );

  static ParkPalette of(Brightness b) => b == Brightness.dark ? dark : light;

  /// 이름 → 색(tokens.json 과 맞춰 보는 테스트용).
  Map<String, Color> get asMap => {
    'path': path,
    'edge': edge,
    'pebble': pebble,
    'pebbleHi': pebbleHi,
    'canopy': canopy,
    'canopyHi': canopyHi,
    'trunk': trunk,
    'far': far,
    'far2': far2,
    'flower': flower,
    'cloud': cloud,
  };
}

/// 1 하늘: 단색 `stageSky` 위 도트 구름 2~3개(멈춤). 오른쪽 위는 말풍선 자리라 비우고,
/// 먼 풍경 띠 위 2칸까지만 둔다. 작은 무대(길가 물체를 그리지 않는 배율)는 구름도 뺀다.
/// 나중에 날씨 겹이 이 겹을 통째로 바꾼다.
class _ParkSky extends StageLayer {
  const _ParkSky();

  /// 말풍선 자리: 무대 위에서 이 높이(화면 px)까지 가운데 오른쪽은 비운다.
  /// 말풍선(위 여백 16 + 글자 2배 높이 68)보다 넉넉하다.
  static const double bubbleClear = 96;

  /// 구름 모양: 줄마다 (왼쪽 칸, 오른쪽 칸), 양끝 포함.
  static const _big = [(6, 10), (3, 13), (1, 16), (0, 17), (2, 15)];
  static const _medium = [(4, 7), (2, 11), (0, 13), (1, 12)];
  static const _small = [(3, 6), (1, 8), (0, 8)];

  /// (가로 위치: 폭 대비, 세로 위치: 하늘 높이 대비, 모양).
  static const _clouds = [
    (0.20, 0.30, _big),
    (0.78, 0.62, _medium),
    (0.40, 0.52, _small),
  ];

  @override
  void paintStill(StagePixels px, StageView v) {
    px.fill(v.colors.stageSky);
    if (!v.detail) return;
    final color = ParkPalette.of(v.brightness).cloud;
    // 먼 풍경 띠(지평선 위 12칸) 위까지가 구름이 뜰 하늘.
    final sky = v.yh - _ParkFar.band;
    final bubbleRows = ((bubbleClear - v.originY) / v.artPx).ceil();
    for (final (fx, fy, shape) in _clouds) {
      final w = shape.map((r) => r.$2).reduce(math.max) + 1;
      final h = shape.length;
      final x0 = (v.cols * fx - w / 2).round();
      final y0 = (sky * fy - h / 2).round();
      if (y0 < 1 || y0 + h > sky - 2) continue;
      if (x0 + w > v.cx && y0 < bubbleRows) continue;
      for (var r = 0; r < h; r++) {
        final (a, b) = shape[r];
        px.span(x0 + a, x0 + b, y0 + r, color);
      }
    }
  }
}

/// 2 먼 풍경: 지평선 위 12칸 띠에 두 겹 나무 줄(뒤 far2, 앞 far). 멈춰 있다.
class _ParkFar extends StageLayer {
  const _ParkFar();

  static const int band = 12;

  @override
  void paintStill(StagePixels px, StageView v) {
    final p = ParkPalette.of(v.brightness);
    final top = v.yh - band;
    final yMin = top.toDouble(), yMax = v.yh.toDouble();
    // 시안 폭 88칸의 왼쪽 끝에 맞춘 무늬를 무대 폭만큼 잇는다.
    final x0 = v.cx - 44;
    for (var i = -((x0 + 8) / 7).ceil(); -2 + 7 * i + x0 < v.cols + 8; i++) {
      final r = 3.4 + (i * 37 % 5) * 0.45;
      px.disc(
        x0 - 2 + 7 * i + 0.5,
        top + band - 1.2,
        r + 0.8,
        p.far2,
        yMin: yMin,
        yMax: yMax,
      );
    }
    for (var i = -((x0 + 8) / 6).ceil(); 1 + 6 * i + x0 < v.cols + 8; i++) {
      final r = 2.4 + (i * 53 % 4) * 0.5;
      px.disc(
        x0 + 1 + 6 * i + 0.5,
        top + band - 0.2,
        r,
        p.far,
        yMin: yMin,
        yMax: yMax,
      );
    }
  }
}

/// 3 땅·길: 풀밭 위 흙길(반폭 0.85)과 가장자리(0.93). 길 위 자갈·풀잎·꽃 점이 흐른다.
class _ParkGround extends StageLayer {
  const _ParkGround();

  /// (가로 X, 시작 깊이, 크기, 색 이름) — gen.py 의 park stamps.
  static const _stamps = [
    (-0.55, 0.1, 0.05, 'pebble'),
    (0.42, 0.6, 0.07, 'pebble'),
    (-0.2, 1.05, 0.05, 'pebbleHi'),
    (0.65, 1.4, 0.05, 'pebble'),
    (0.1, 1.75, 0.04, 'pebble'),
    (-0.7, 1.55, 0.06, 'pebbleHi'),
    (-1.3, 0.3, 0.06, 'tuft'),
    (1.25, 0.9, 0.06, 'tuft'),
    (-1.15, 1.3, 0.05, 'flower'),
    (1.4, 1.8, 0.06, 'tuft'),
    (1.05, 0.2, 0.05, 'flower'),
    (-1.6, 1.0, 0.06, 'tuft'),
  ];

  @override
  void paintStill(StagePixels px, StageView v) {
    final p = ParkPalette.of(v.brightness);
    for (var y = v.yh < 0 ? 0 : v.yh; y < v.rows; y++) {
      // 행 y 에서 지평선까지 칸 수 = k/z. 반폭은 X·k/z.
      final d = y + 0.5 - v.yh;
      px.span(0, v.cols - 1, y, v.colors.stageGround);
      px.band(y, v.cx, 0.93 * d, p.edge);
      px.band(y, v.cx, 0.85 * d, p.path);
    }
  }

  @override
  void paintFlow(StagePixels px, StageView v, double t) {
    final p = ParkPalette.of(v.brightness);
    const period = 2.0;
    for (final (x, z0, s, key) in _stamps) {
      final col = switch (key) {
        'pebble' => p.pebble,
        'pebbleHi' => p.pebbleHi,
        'flower' => p.flower,
        _ => v.colors.stageGroundLine,
      };
      for (var n = -1; n <= 8; n++) {
        final z = z0 + n * period + t;
        if (!(z > 0.9 && z < 5.5)) continue;
        final xc = v.sx(x, z), yc = v.yh + v.k / z;
        final size = math.max(1, (s * v.k / z).round());
        final x0 = (xc - size / 2).round(), y0 = (yc - size / 2).round();
        px.square(x0, y0, size, col, yMin: v.yh);
        if (key == 'flower' && yc - size / 2 - 1 >= v.yh) {
          px.span((xc - 0.5).round(), (xc - 0.5).round(), y0 - 1, col);
        }
      }
    }
  }
}

/// 4 앞 장식: 길가 둥근 나무(±1.7, 2칸마다 좌우 엇갈림)와 덤불(±1.15). 먼 것부터 그린다.
class _ParkRoadside extends StageLayer {
  const _ParkRoadside();

  static const double _zMin = 0.85, _zMax = 14, _period = 2;

  @override
  void paintFlow(StagePixels px, StageView v, double t) {
    if (!v.detail) return;
    final p = ParkPalette.of(v.brightness);
    final objs = <(double, int, bool)>[]; // (깊이, 쪽, 나무인가)
    for (var n = -1; n <= (_zMax / _period).floor() + 1; n++) {
      for (final (side, z0, tree) in const [
        (-1, 0.0, true),
        (1, 1.0, true),
        (1, 0.45, false),
        (-1, 1.5, false),
      ]) {
        final z = z0 + n * _period + t;
        if (z > _zMin && z < _zMax) objs.add((z, side, tree));
      }
    }
    objs.sort((a, b) => b.$1.compareTo(a.$1));
    final k = v.k;
    for (final (z, side, tree) in objs) {
      final gy = v.sy(0, z);
      if (tree) {
        final x = 1.7 * side;
        px.vspan(v.sx(x, z), 0.11 * k / z / 2, v.sy(0.8, z), gy, p.trunk);
        px.disc(v.sx(x, z), v.sy(1.05, z), 0.42 * k / z, p.canopy);
        if (0.42 * k / z >= 2.5) {
          px.disc(v.sx(x - 0.12, z), v.sy(1.17, z), 0.2 * k / z, p.canopyHi);
        }
      } else {
        final x = 1.15 * side;
        px.disc(v.sx(x, z), v.sy(0.06, z), 0.2 * k / z, p.canopy, yMax: gy);
        if (0.2 * k / z >= 2) {
          px.disc(
            v.sx(x - 0.06, z),
            v.sy(0.12, z),
            0.08 * k / z,
            p.canopyHi,
            yMax: gy,
          );
        }
      }
    }
  }
}
