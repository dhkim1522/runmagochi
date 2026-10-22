// 앱 아이콘·스플래시를 그린다(페이즈 6 작업 16).
// 사용: fvm dart run tool/render_app_icon.dart [--preview=<폴더>] (저장소 루트에서)
// 결과:
//   android/app/src/main/res/mipmap-<밀도>/ic_launcher.png — 옛 방식 런처 아이콘(48dp)
//   android/app/src/main/res/mipmap-<밀도>/ic_launcher_{foreground,background}.png — 적응형 층(108dp)
//   android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml — 적응형 아이콘
//   android/app/src/main/res/drawable-<밀도>/splash.png — 스플래시 가운데 그림(144dp)
//   android/app/src/main/res/values{,-night}/colors.xml — 스플래시 바탕(background 토큰)
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png — Contents.json 의 모든 크기(알파 없음)
//   ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{,@2x,@3x}.png — 스플래시 그림
//   ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json — 스플래시 바탕(라이트·다크)
// --preview 를 주면 그 폴더에 확인용 그림(런처 크기·마스크, 라이트·다크 스플래시)도 남긴다.
// 그리기 로직은 tool/sprites/app_icon.dart (테스트와 공유).
import 'dart:io';

import 'package:image/image.dart' as img;

import 'sprites/app_icon.dart';

void main(List<String> args) {
  final colors = loadIconColors();
  final pngs = appIconImages(colors);
  pngs.forEach(_save);
  appIconTexts(colors).forEach((path, text) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  });
  stdout.writeln('아이콘·스플래시 PNG ${pngs.length}개');

  final preview = args
      .where((a) => a.startsWith('--preview='))
      .map((a) => a.substring('--preview='.length))
      .firstOrNull;
  if (preview != null) {
    _previews(colors, pngs).forEach((name, im) => _save('$preview/$name', im));
    stdout.writeln('미리보기: $preview');
  }
}

void _save(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
}

const _res = 'android/app/src/main/res';

/// 확인용 그림. 런처가 하듯 적응형 층을 합쳐 보이는 72dp 를 잘라 줄이고 마스크를 씌운다.
Map<String, img.Image> _previews(IconColors c, Map<String, img.Image> pngs) {
  final fg = pngs['$_res/mipmap-xxxhdpi/ic_launcher_foreground.png']!;
  final bg = pngs['$_res/mipmap-xxxhdpi/ic_launcher_background.png']!;
  final layer = img.compositeImage(img.Image.from(bg), fg);
  final inset = layer.width ~/ 6; // 108dp 중 가운데 72dp
  final visible = img.copyCrop(
    layer,
    x: inset,
    y: inset,
    width: layer.width - inset * 2,
    height: layer.width - inset * 2,
  );

  img.Image masked(int size, double radiusRatio) {
    final im = img.copyResize(
      visible,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    roundCorners(im, size * radiusRatio);
    return im;
  }

  img.Image board(int wallpaper) {
    const sizes = [48, 96, 192];
    const gap = 24;
    const zoom = 4;
    final width =
        gap +
        2 * (sizes.fold<int>(0, (a, s) => a + s + gap)) +
        48 * zoom * 2 +
        gap * 2;
    final height = gap * 3 + 192 + 48 * zoom;
    final im = img.Image(width: width, height: height);
    img.fill(im, color: _rgb(wallpaper));
    var x = gap;
    // 위 줄: 원형 마스크 48·96·192, 둥근 사각 마스크 48·96·192 (실제 크기).
    for (final ratio in [0.5, 0.22]) {
      for (final s in sizes) {
        img.compositeImage(im, masked(s, ratio), dstX: x, dstY: gap + 192 - s);
        x += s + gap;
      }
    }
    // 아래 줄: 48px 두 마스크를 4배 nearest 로 키운 것, 옛 방식 48px 아이콘 실제 크기·4배.
    x = gap;
    final y = gap * 2 + 192;
    for (final ratio in [0.5, 0.22]) {
      final big = img.copyResize(
        masked(48, ratio),
        width: 48 * zoom,
        height: 48 * zoom,
        interpolation: img.Interpolation.nearest,
      );
      img.compositeImage(im, big, dstX: x, dstY: y);
      x += 48 * zoom + gap;
    }
    final legacy = pngs['$_res/mipmap-mdpi/ic_launcher.png']!;
    img.compositeImage(im, legacy, dstX: x, dstY: y);
    img.compositeImage(
      im,
      img.copyResize(
        legacy,
        width: 48 * zoom,
        height: 48 * zoom,
        interpolation: img.Interpolation.nearest,
      ),
      dstX: x + 48 + gap,
      dstY: y,
    );
    return im;
  }

  img.Image splash(int background) {
    // xhdpi(2배) 360×780dp 화면.
    final im = img.Image(width: 720, height: 1560);
    img.fill(im, color: _rgb(background));
    final tile = pngs['$_res/drawable-xhdpi/splash.png']!;
    img.compositeImage(
      im,
      tile,
      dstX: (im.width - tile.width) ~/ 2,
      dstY: (im.height - tile.height) ~/ 2,
    );
    return im;
  }

  final ios = img.Image.from(
    pngs['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png']!,
  ).convert(numChannels: 4);
  roundCorners(ios, 1024 * 0.2237);

  return {
    'launcher_light_wallpaper.png': board(0xFFE8E4DC),
    'launcher_dark_wallpaper.png': board(0xFF2B2F36),
    'splash_light.png': splash(c.backgroundLight),
    'splash_dark.png': splash(c.backgroundDark),
    'ios_1024.png': ios,
  };
}

img.Color _rgb(int argb) =>
    img.ColorRgba8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, 255);
