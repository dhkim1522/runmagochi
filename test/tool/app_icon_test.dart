import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/sprites/app_icon.dart';
import '../../tool/sprites/pet_art.dart';

// 앱 아이콘·스플래시(페이즈 6 작업 16): 도구 출력의 크기·여백·색 규칙.
void main() {
  final colors = loadIconColors();
  final pngs = appIconImages(colors);
  final texts = appIconTexts(colors);

  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  bool opaque(img.Image im, int x, int y) => im.getPixel(x, y).a > 0;

  test('바탕색은 tokens.json 의 background·stage 값이다', () {
    final tokens =
        (jsonDecode(File('docs/design/tokens.json').readAsStringSync())
                as Map<String, dynamic>)['color']['tokens']
            as List<dynamic>;
    String hex(String name, String mode) =>
        (tokens.firstWhere((t) => t['name'] == name)['value'][mode] as String)
            .toUpperCase();
    String argb(int v) =>
        '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    expect(argb(colors.backgroundLight), hex('background', 'light'));
    expect(argb(colors.backgroundDark), hex('background', 'dark'));
    expect(argb(colors.sky), hex('stage-sky', 'light'));
    expect(argb(colors.ground), hex('stage-ground', 'light'));
    expect(argb(colors.groundLine), hex('stage-ground-line', 'light'));

    expect(
      texts['$res/values/colors.xml'],
      contains(hex('background', 'light')),
    );
    expect(
      texts['$res/values-night/colors.xml'],
      contains(hex('background', 'dark')),
    );
  });

  test('Android 런처 아이콘은 48·72·96·144·192 px 다', () {
    final sizes = [
      for (final d in densities.keys)
        pngs['$res/mipmap-$d/ic_launcher.png']!.width,
    ];
    expect(sizes, [48, 72, 96, 144, 192]);
    for (final d in densities.keys) {
      final im = pngs['$res/mipmap-$d/ic_launcher.png']!;
      expect(im.height, im.width);
    }
  });

  test('적응형 아이콘 전경·배경은 108dp 이고 배경은 빈틈없이 칠해진다', () {
    for (final MapEntry(key: d, value: k) in densities.entries) {
      final size = (108 * k).round();
      final fg = pngs['$res/mipmap-$d/ic_launcher_foreground.png']!;
      final bg = pngs['$res/mipmap-$d/ic_launcher_background.png']!;
      expect(
        [fg.width, fg.height, bg.width, bg.height],
        [size, size, size, size],
      );
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          expect(bg.getPixel(x, y).a, 255, reason: '$d 배경 ($x,$y) 투명');
        }
      }
    }
    final xml = texts['$res/mipmap-anydpi-v26/ic_launcher.xml']!;
    expect(xml, contains('@mipmap/ic_launcher_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
  });

  test('적응형 전경 그림은 가운데 66dp 원(안전 영역, 66%) 안에 있고 너무 작지 않다', () {
    for (final MapEntry(key: d, value: k) in densities.entries) {
      final fg = pngs['$res/mipmap-$d/ic_launcher_foreground.png']!;
      final c = fg.width / 2;
      final r = fg.width * 66 / 108 / 2;
      var minX = fg.width, maxX = -1, minY = fg.height, maxY = -1;
      for (var y = 0; y < fg.height; y++) {
        for (var x = 0; x < fg.width; x++) {
          if (!opaque(fg, x, y)) continue;
          // 픽셀의 가장 먼 모서리까지 원 안이어야 한다.
          final dx = math.max((x - c).abs(), (x + 1 - c).abs());
          final dy = math.max((y - c).abs(), (y + 1 - c).abs());
          expect(
            dx * dx + dy * dy <= r * r,
            isTrue,
            reason: '$d 전경 ($x,$y) 가 안전 영역 밖',
          );
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
        }
      }
      // 보이는 72dp 의 절반 이상을 병아리가 차지한다(48px 런처에서도 읽히게).
      final visible = 72 * k;
      expect(maxX - minX + 1, greaterThanOrEqualTo(visible * 0.5), reason: d);
      expect(maxY - minY + 1, greaterThanOrEqualTo(visible * 0.5), reason: d);
    }
  });

  test('적응형 전경은 펫 팔레트 색만 쓴다(정수 배율, 흐림 없음)', () {
    final allowed = {for (final v in petPalette.values) v & 0xFFFFFF};
    for (final d in densities.keys) {
      final fg = pngs['$res/mipmap-$d/ic_launcher_foreground.png']!;
      for (final p in fg) {
        if (p.a == 0) continue;
        expect(p.a, 255, reason: '$d 반투명 픽셀');
        final rgb = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
        expect(allowed, contains(rgb), reason: '$d 팔레트 밖 색 $rgb');
      }
    }
  });

  test('iOS AppIcon 은 Contents.json 의 모든 크기를 알파 없이 채운다(1024 포함)', () {
    const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final images =
        (jsonDecode(File('$dir/Contents.json').readAsStringSync())
                as Map<String, dynamic>)['images']
            as List<dynamic>;
    final seen = <int>{};
    for (final e in images) {
      final pt = double.parse((e['size'] as String).split('x').first);
      final scale = int.parse((e['scale'] as String).replaceAll('x', ''));
      final px = (pt * scale).round();
      final im = pngs['$dir/${e['filename']}'];
      expect(im, isNotNull, reason: '${e['filename']} 없음');
      expect([im!.width, im.height], [px, px], reason: '${e['filename']}');
      expect(im.numChannels, 3, reason: '${e['filename']} 에 알파 채널');
      seen.add(px);
    }
    expect(seen, contains(1024));
  });

  test('스플래시 그림: Android 144dp 타일, iOS LaunchImage 1x·2x·3x', () {
    for (final MapEntry(key: d, value: k) in densities.entries) {
      final im = pngs['$res/drawable-$d/splash.png']!;
      expect([im.width, im.height], [(144 * k).round(), (144 * k).round()]);
      // 둥근 모서리 바깥은 투명, 가운데는 불투명.
      expect(im.getPixel(0, 0).a, 0, reason: d);
      expect(im.getPixel(im.width ~/ 2, im.height ~/ 2).a, 255, reason: d);
    }
    const ios = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    expect(
      [
        pngs['$ios/LaunchImage.png']!.width,
        pngs['$ios/LaunchImage@2x.png']!.width,
        pngs['$ios/LaunchImage@3x.png']!.width,
      ],
      [144, 288, 432],
    );
    final colorset =
        jsonDecode(
              texts['ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json']!,
            )
            as Map<String, dynamic>;
    expect(colorset['colors'], hasLength(2)); // 라이트·다크
  });

  test('스플래시 리소스가 생성한 바탕색·그림을 가리킨다(라이트·다크, Android 12 이상, iOS)', () {
    String read(String p) => File(p).readAsStringSync();
    for (final d in ['drawable', 'drawable-v21']) {
      final xml = read('$res/$d/launch_background.xml');
      expect(xml, contains('@color/splash_background'), reason: d);
      expect(xml, contains('@drawable/splash'), reason: d);
    }
    for (final v in ['values-v31', 'values-night-v31']) {
      final xml = read('$res/$v/styles.xml');
      expect(
        xml,
        contains(
          '"android:windowSplashScreenBackground">@color/splash_background<',
        ),
        reason: v,
      );
      expect(xml, contains('windowSplashScreenAnimatedIcon'), reason: v);
    }
    final storyboard = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    expect(
      storyboard,
      contains('<color key="backgroundColor" name="LaunchBackground"/>'),
    );
    expect(
      storyboard,
      contains('<image name="LaunchImage" width="144" height="144"/>'),
    );
  });

  test('Android 앱 이름은 런마고치다', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:label="런마고치"'));
  });
}
