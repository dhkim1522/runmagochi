// 앱 아이콘·스플래시(페이즈 6 작업 16)를 메모리에서 그리는 순수 로직.
// tool/render_app_icon.dart(파일 저장)와 test/tool/app_icon_*_test.dart 가 함께 쓴다.
//
// 그림: 사각 무대(하늘 + 땅 띠, 결정 0029) 위에 선 병아리 3단계(idle 첫 프레임, normal 표정).
// 도트는 정수 배율로 키우고(흐림 없음), 발끝 한 칸이 땅 윗선 아래로 묻힌다(앱 무대와 같음).
// 색은 docs/design/tokens.json 에서 읽는다(theme.dart 와 같은지는 theme_test 가 본다).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'chick.dart';
import 'pet_art.dart';
import 'sprite_data.dart';

/// 아이콘·스플래시에 쓰는 토큰 색(0xAARRGGBB). 무대 색은 라이트 값 하나만 쓴다
/// (런처 아이콘은 다크 모드에서도 바뀌지 않는다).
class IconColors {
  const IconColors({
    required this.sky,
    required this.ground,
    required this.groundLine,
    required this.backgroundLight,
    required this.backgroundDark,
  });

  final int sky;
  final int ground;
  final int groundLine;
  final int backgroundLight;
  final int backgroundDark;
}

IconColors loadIconColors([String path = 'docs/design/tokens.json']) {
  final tokens =
      (jsonDecode(File(path).readAsStringSync())
              as Map<String, dynamic>)['color']['tokens']
          as List<dynamic>;
  int hex(String name, String mode) {
    final v =
        tokens.firstWhere((t) => t['name'] == name)['value'][mode] as String;
    return 0xFF000000 | int.parse(v.substring(1), radix: 16);
  }

  return IconColors(
    sky: hex('stage-sky', 'light'),
    ground: hex('stage-ground', 'light'),
    groundLine: hex('stage-ground-line', 'light'),
    backgroundLight: hex('background', 'light'),
    backgroundDark: hex('background', 'dark'),
  );
}

const String _res = 'android/app/src/main/res';
const String _xcassets = 'ios/Runner/Assets.xcassets';
const Map<String, double> _densities = {
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// 적응형 아이콘 층 크기(dp)와 병아리 배율(dp 당 도트). 병아리(22×20 도트)가
/// 44dp 가 되어 가운데 66dp 안전 영역 원에 들어가고, 보이는 72dp 의 60% 쯤을 채운다.
const int _adaptiveDp = 108;
const int _adaptiveScale = 2;

/// 스플래시 타일 크기(dp)·병아리 배율·모서리(radius-xl, 마스코트 판 카드).
const int _splashDp = 144;
const int _splashScale = 4;
const double _splashRadius = 28;

/// 병아리가 아이콘 폭에서 차지하길 바라는 비율과 넘지 않을 비율(적응형과 같은 비율).
const double _targetFill = 0.61;
const double _maxFill = 0.8;

// --- 마스코트 -----------------------------------------------------------------

/// 32×32 캔버스의 병아리 색(투명은 null). 몸(팔·발 포함) 위에 표정을 겹친다.
final List<List<int?>> _mascot = () {
  final stage = chick.stages[2];
  final body = bodyFrames(stage, 'idle').first;
  final face = faceFrames(chick, 'normal', 'idle').first;
  return [
    for (var y = 0; y < spriteSize; y++)
      [
        for (var x = 0; x < spriteSize; x++)
          pixelAt(face, petPalette, x, y) ?? pixelAt(body, petPalette, x, y),
      ],
  ];
}();

/// 병아리의 불투명 범위(도트 좌표). left·top 포함, right·bottom 제외.
final ({int left, int top, int right, int bottom}) _box = () {
  var l = spriteSize, t = spriteSize, r = 0, b = 0;
  for (var y = 0; y < spriteSize; y++) {
    for (var x = 0; x < spriteSize; x++) {
      if (_mascot[y][x] == null) continue;
      l = math.min(l, x);
      t = math.min(t, y);
      r = math.max(r, x + 1);
      b = math.max(b, y + 1);
    }
  }
  return (left: l, top: t, right: r, bottom: b);
}();

int get _boxW => _box.right - _box.left;
int get _boxH => _box.bottom - _box.top;

// --- 그리기 ------------------------------------------------------------------

/// [size]×[size] 캔버스에 병아리를 [scale] 배로 가운데 놓고 그린다.
/// [stage] 면 하늘·땅 띠를 깔고, [mascot] 이면 병아리를 그린다.
img.Image _scene({
  required IconColors c,
  required int size,
  required int scale,
  bool stage = true,
  bool mascot = true,
  int channels = 4,
}) {
  final im = img.Image(width: size, height: size, numChannels: channels);
  final ox = (size - _boxW * scale) ~/ 2 - _box.left * scale;
  final oy = (size - _boxH * scale) ~/ 2 - _box.top * scale;
  if (stage) {
    // 땅 윗선은 발끝 줄(y=footY) 위끝: 발끝 한 칸이 땅에 묻힌다.
    final groundTop = oy + footY * scale;
    final line = math.max(1, scale ~/ 2);
    _fill(im, 0, 0, size, groundTop, c.sky);
    _fill(im, 0, groundTop, size, size, c.ground);
    _fill(im, 0, groundTop, size, groundTop + line, c.groundLine);
  }
  if (mascot) {
    for (var y = 0; y < spriteSize; y++) {
      for (var x = 0; x < spriteSize; x++) {
        final argb = _mascot[y][x];
        if (argb == null) continue;
        _fill(
          im,
          ox + x * scale,
          oy + y * scale,
          ox + (x + 1) * scale,
          oy + (y + 1) * scale,
          argb,
        );
      }
    }
  }
  return im;
}

/// [x0, x1)×[y0, y1) 를 [argb] 로 칠한다(섞지 않고 덮어쓴다).
void _fill(img.Image im, int x0, int y0, int x1, int y1, int argb) {
  final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
  final a = (argb >> 24) & 0xFF;
  for (var y = math.max(0, y0); y < math.min(im.height, y1); y++) {
    for (var x = math.max(0, x0); x < math.min(im.width, x1); x++) {
      im.setPixelRgba(x, y, r, g, b, a);
    }
  }
}

/// 둥근 모서리 밖을 투명하게 깎는다. 모서리 픽셀은 4×4 표본으로 덮인 비율만큼 알파를 준다.
void roundCorners(img.Image im, double radius) {
  final w = im.width, h = im.height;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var inside = 0;
      for (var sy = 0; sy < 4; sy++) {
        for (var sx = 0; sx < 4; sx++) {
          final px = x + (sx + 0.5) / 4, py = y + (sy + 0.5) / 4;
          final cx = px.clamp(radius, w - radius),
              cy = py.clamp(radius, h - radius);
          final dx = px - cx, dy = py - cy;
          if (dx * dx + dy * dy <= radius * radius) inside++;
        }
      }
      if (inside == 16) continue;
      final p = im.getPixel(x, y);
      p.a = (p.a * inside / 16).round();
    }
  }
}

/// [size] 에 맞는 정수 배율: 병아리 폭이 [_targetFill] 에 가장 가깝고 [_maxFill] 을 넘지
/// 않는 값. 1배도 들어가지 않으면 null.
int? _fitScale(int size) {
  int? best;
  for (var s = 1; math.max(_boxW, _boxH) * s <= size * _maxFill; s++) {
    if (best == null ||
        (_boxW * s / size - _targetFill).abs() <
            (_boxW * best / size - _targetFill).abs()) {
      best = s;
    }
  }
  return best;
}

/// 꽉 찬 무대 아이콘. 1배도 들어가지 않는 작은 크기(iOS 20px)는 두 배로 그려 평균으로 줄인다.
img.Image _fullIcon(IconColors c, int size, {int channels = 4}) {
  final s = _fitScale(size);
  if (s != null) return _scene(c: c, size: size, scale: s, channels: channels);
  final big = _fullIcon(c, size * 2, channels: channels);
  return img.copyResize(
    big,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}

// --- 출력 --------------------------------------------------------------------

/// 저장소 루트 기준 경로 → 이미지. Android 런처(옛 방식·적응형), 스플래시 그림,
/// iOS AppIcon(Contents.json 의 모든 크기, 알파 없음), iOS LaunchImage.
Map<String, img.Image> appIconImages(IconColors c) {
  final out = <String, img.Image>{};
  for (final MapEntry(key: d, value: k) in _densities.entries) {
    final legacy = (48 * k).round();
    // 옛 방식(API 26 미만) 아이콘: 스플래시 타일과 같은 비율의 둥근 사각형.
    final icon = _fullIcon(c, legacy);
    roundCorners(icon, legacy * _splashRadius / _splashDp);
    out['$_res/mipmap-$d/ic_launcher.png'] = icon;

    final layer = (_adaptiveDp * k).round();
    final scale = (_adaptiveScale * k).round();
    out['$_res/mipmap-$d/ic_launcher_foreground.png'] = _scene(
      c: c,
      size: layer,
      scale: scale,
      stage: false,
    );
    out['$_res/mipmap-$d/ic_launcher_background.png'] = _scene(
      c: c,
      size: layer,
      scale: scale,
      mascot: false,
    );
    out['$_res/drawable-$d/splash.png'] = _splash(c, k);
  }

  const appIcon = '$_xcassets/AppIcon.appiconset';
  final images =
      (jsonDecode(File('$appIcon/Contents.json').readAsStringSync())
              as Map<String, dynamic>)['images']
          as List<dynamic>;
  for (final e in images) {
    final pt = double.parse((e['size'] as String).split('x').first);
    final scale = int.parse((e['scale'] as String).replaceAll('x', ''));
    out['$appIcon/${e['filename']}'] = _fullIcon(
      c,
      (pt * scale).round(),
      channels: 3,
    );
  }

  const launch = '$_xcassets/LaunchImage.imageset';
  out['$launch/LaunchImage.png'] = _splash(c, 1);
  out['$launch/LaunchImage@2x.png'] = _splash(c, 2);
  out['$launch/LaunchImage@3x.png'] = _splash(c, 3);
  return out;
}

/// 스플래시 가운데 그림: 둥근 사각 무대 타일([_splashDp]dp)에 선 병아리.
/// 라이트·다크 모두 같은 그림이고 바탕색만 다르다.
img.Image _splash(IconColors c, double k) {
  final im = _scene(
    c: c,
    size: (_splashDp * k).round(),
    scale: (_splashScale * k).round(),
  );
  roundCorners(im, _splashRadius * k);
  return im;
}

/// 저장소 루트 기준 경로 → 글자 파일. 적응형 아이콘 XML, 스플래시 바탕색(Android 라이트·다크,
/// iOS 이름 붙은 색).
Map<String, String> appIconTexts(IconColors c) => {
  '$_res/mipmap-anydpi-v26/ic_launcher.xml': '''
<?xml version="1.0" encoding="utf-8"?>
<!-- tool/render_app_icon.dart 가 만든 파일. 직접 고치지 않는다. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''',
  '$_res/values/colors.xml': _colorsXml(c.backgroundLight, '라이트'),
  '$_res/values-night/colors.xml': _colorsXml(c.backgroundDark, '다크'),
  '$_xcassets/LaunchBackground.colorset/Contents.json':
      '${const JsonEncoder.withIndent('  ').convert({
        'colors': [
          {'color': _iosColor(c.backgroundLight), 'idiom': 'universal'},
          {
            'appearances': [
              {'appearance': 'luminosity', 'value': 'dark'},
            ],
            'color': _iosColor(c.backgroundDark),
            'idiom': 'universal',
          },
        ],
        'info': {'author': 'xcode', 'version': 1},
      })}\n',
};

String _hex(int argb) =>
    (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

String _colorsXml(int argb, String mode) =>
    '''
<?xml version="1.0" encoding="utf-8"?>
<!-- tool/render_app_icon.dart 가 만든 파일. 직접 고치지 않는다. -->
<resources>
    <!-- 스플래시 바탕: background 토큰($mode) -->
    <color name="splash_background">#${_hex(argb)}</color>
</resources>
''';

Map<String, Object> _iosColor(int argb) => {
  'color-space': 'srgb',
  'components': {
    'alpha': '1.000',
    'red': '0x${_hex(argb).substring(0, 2)}',
    'green': '0x${_hex(argb).substring(2, 4)}',
    'blue': '0x${_hex(argb).substring(4, 6)}',
  },
};
