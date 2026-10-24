import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'stage_scene.dart';
import 'stage_weather.dart';

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
    paintClouds(px, v, ParkPalette.of(v.brightness).cloud, _clouds);
  }

  /// [clouds] 를 [color] 로 그린다. 먼 풍경 띠 위 하늘에만, 말풍선 자리는 비운다.
  static void paintClouds(
    StagePixels px,
    StageView v,
    Color color,
    List<(double, double, List<(int, int)>)> clouds,
  ) {
    // 먼 풍경 띠(지평선 위 12칸) 위까지가 구름이 뜰 하늘.
    final sky = v.yh - _ParkFar.band;
    final bubbleRows = ((bubbleClear - v.originY) / v.artPx).ceil();
    for (final (fx, fy, shape) in clouds) {
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

/// 날씨 무대 색(F25, 결정 0037). 낮은 라이트, 밤·다크 테마는 다크를 쓴다.
@immutable
class WeatherPalette {
  const WeatherPalette({
    required this.overcastSky,
    required this.rainSky,
    required this.snowSky,
    required this.cloud,
    required this.rainCloud,
    required this.rain,
    required this.snow,
    required this.star,
    required this.moon,
  });

  /// 흐린 하늘.
  final Color overcastSky;

  /// 비 오는 하늘.
  final Color rainSky;

  /// 눈 오는 하늘.
  final Color snowSky;

  /// 흐림·눈 구름.
  final Color cloud;

  /// 비구름.
  final Color rainCloud;

  /// 빗줄기.
  final Color rain;

  /// 눈송이(공원 꽃 흰색과 다르다).
  final Color snow;

  /// 별.
  final Color star;

  /// 달.
  final Color moon;

  static const light = WeatherPalette(
    overcastSky: Color(0xFFDCE3D6),
    rainSky: Color(0xFFC8D0C6),
    snowSky: Color(0xFFE9EEEA),
    cloud: Color(0xFFF1F4EE),
    rainCloud: Color(0xFFB4BDB2),
    rain: Color(0xFF8FA5B8),
    snow: Color(0xFFFAFDFF),
    star: Color(0xFFFFFCE8),
    moon: Color(0xFFFFF4C2),
  );

  static const dark = WeatherPalette(
    overcastSky: Color(0xFF1A2219),
    rainSky: Color(0xFF151C15),
    snowSky: Color(0xFF222B22),
    cloud: Color(0xFF2B3429),
    rainCloud: Color(0xFF242C23),
    rain: Color(0xFF5E7488),
    snow: Color(0xFFDCE6DE),
    star: Color(0xFFE6EDD2),
    moon: Color(0xFFF3EDC4),
  );

  static WeatherPalette of(Brightness b) => b == Brightness.dark ? dark : light;
}

/// 날씨에 맞는 공원 무대. 맑은 낮은 [parkScene] 그대로다. 같은 날씨는 같은 객체라
/// 그려 둔 그림을 다시 쓴다. 밤 색(다크 토큰)은 무대 배경(StageBackdrop)이 고른다.
StageScene parkSceneFor(StageWeather w) => switch ((w.condition, w.night)) {
  (WeatherCondition.clear, false) => parkScene,
  (WeatherCondition.clear, true) => _clearNight,
  (WeatherCondition.cloudy, false) => _cloudyDay,
  (WeatherCondition.cloudy, true) => _cloudyNight,
  (WeatherCondition.rain, false) => _rainDay,
  (WeatherCondition.rain, true) => _rainNight,
  (WeatherCondition.snow, false) => _snowDay,
  (WeatherCondition.snow, true) => _snowNight,
};

const _clearNight = StageScene(
  name: 'park-clear-night',
  sky: _WeatherSky(WeatherCondition.clear, night: true),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
);
const _cloudyDay = StageScene(
  name: 'park-cloudy',
  sky: _WeatherSky(WeatherCondition.cloudy),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
);
const _cloudyNight = StageScene(
  name: 'park-cloudy-night',
  sky: _WeatherSky(WeatherCondition.cloudy, night: true),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
);
const _rainDay = StageScene(
  name: 'park-rain',
  sky: _WeatherSky(WeatherCondition.rain),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
  overlay: _Rain(),
);
const _rainNight = StageScene(
  name: 'park-rain-night',
  sky: _WeatherSky(WeatherCondition.rain, night: true),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
  overlay: _Rain(),
);
const _snowDay = StageScene(
  name: 'park-snow',
  sky: _WeatherSky(WeatherCondition.snow),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
  overlay: _Snow(),
);
const _snowNight = StageScene(
  name: 'park-snow-night',
  sky: _WeatherSky(WeatherCondition.snow, night: true),
  far: _ParkFar(),
  ground: _ParkGround(),
  roadside: _ParkRoadside(),
  overlay: _Snow(),
);

/// 1 날씨 하늘: 맑은 밤은 별·달, 흐림·비·눈은 잿빛 하늘에 구름을 더 많이.
class _WeatherSky extends StageLayer {
  const _WeatherSky(this.condition, {this.night = false});

  final WeatherCondition condition;
  final bool night;

  static const _many = [
    (0.16, 0.28, _ParkSky._big),
    (0.50, 0.20, _ParkSky._medium),
    (0.80, 0.60, _ParkSky._big),
    (0.36, 0.56, _ParkSky._medium),
    (0.64, 0.80, _ParkSky._small),
  ];

  /// 별 자리: (가로 폭 대비, 세로 하늘 대비).
  static const _stars = [
    (0.08, 0.20),
    (0.30, 0.12),
    (0.44, 0.40),
    (0.60, 0.70),
    (0.86, 0.78),
    (0.22, 0.62),
    (0.70, 0.30),
    (0.92, 0.45),
    (0.52, 0.85),
    (0.12, 0.82),
  ];

  @override
  void paintStill(StagePixels px, StageView v) {
    final p = WeatherPalette.of(v.brightness);
    switch (condition) {
      case WeatherCondition.clear:
        px.fill(v.colors.stageSky);
        if (!v.detail) return;
        if (!night) {
          _ParkSky.paintClouds(
            px,
            v,
            ParkPalette.of(v.brightness).cloud,
            _ParkSky._clouds,
          );
          return;
        }
        _paintNight(px, v, p);
      case WeatherCondition.cloudy:
        px.fill(p.overcastSky);
        if (v.detail) _ParkSky.paintClouds(px, v, p.cloud, _many);
      case WeatherCondition.rain:
        px.fill(p.rainSky);
        if (v.detail) _ParkSky.paintClouds(px, v, p.rainCloud, _many);
      case WeatherCondition.snow:
        px.fill(p.snowSky);
        if (v.detail) _ParkSky.paintClouds(px, v, p.cloud, _many);
    }
  }

  void _paintNight(StagePixels px, StageView v, WeatherPalette p) {
    final sky = v.yh - _ParkFar.band;
    final bubbleRows = ((_ParkSky.bubbleClear - v.originY) / v.artPx).ceil();
    for (final (fx, fy) in _stars) {
      final x = (v.cols * fx).round();
      final y = (sky * fy).round();
      if (y < 1 || y > sky - 2) continue;
      if (x > v.cx && y < bubbleRows) continue;
      px.span(x, x, y, p.star);
    }
    // 달: 왼쪽 위(말풍선은 오른쪽).
    final mx = (v.cols * 0.2).roundToDouble();
    final my = math.max(4.0, (sky * 0.3).roundToDouble());
    if (my + 3 < sky - 2) {
      px.disc(mx, my, 3, p.moon, yMin: 0, yMax: (sky - 2).toDouble());
    }
  }
}

/// 칸 (gx, gy) 마다 정해진 작은 수. 비·눈을 격자처럼 줄 세우지 않고 흩뜨린다.
int _scatter(int gx, int gy) {
  var h = gx * 73856093 ^ gy * 19349663;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h ^ (h >> 16)) & 0x7fffffff;
}

/// 5 비: 무대를 칸으로 나눠 칸마다 짧은 빗줄기(2칸) 하나를 흩뿌린다. 멈춰 있다(배터리).
class _Rain extends StageLayer {
  const _Rain();

  static const _cw = 9, _ch = 7;

  @override
  void paintStill(StagePixels px, StageView v) {
    final c = WeatherPalette.of(v.brightness).rain;
    for (var gy = 0; gy * _ch < v.rows; gy++) {
      for (var gx = 0; gx * _cw < v.cols; gx++) {
        final h = _scatter(gx, gy);
        final x = gx * _cw + h % _cw;
        final y = gy * _ch + (h ~/ _cw) % (_ch - 1);
        px.span(x, x, y, c);
        px.span(x, x, y + 1, c);
      }
    }
  }
}

/// 5 눈: 칸마다 눈송이 하나(1칸, 셋에 하나는 2×2)를 흩뿌린다. 멈춰 있다.
class _Snow extends StageLayer {
  const _Snow();

  static const _cw = 10, _ch = 6;

  @override
  void paintStill(StagePixels px, StageView v) {
    final c = WeatherPalette.of(v.brightness).snow;
    for (var gy = 0; gy * _ch < v.rows; gy++) {
      for (var gx = 0; gx * _cw < v.cols; gx++) {
        final h = _scatter(gx + 101, gy + 7);
        final x = gx * _cw + h % (_cw - 1);
        final y = gy * _ch + (h ~/ _cw) % (_ch - 1);
        px.span(x, x, y, c);
        if (h % 3 == 0) {
          px.span(x + 1, x + 1, y, c);
          px.span(x, x + 1, y + 1, c);
        }
      }
    }
  }
}
