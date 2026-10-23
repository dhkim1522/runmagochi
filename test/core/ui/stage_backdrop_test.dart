import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/stage/park_scene.dart';
import 'package:runmagochi/core/stage/stage_scene.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/core/ui/stage_backdrop.dart';

/// 390 폭 화면에 [child] 를 그린다(무대 폭 350 = 시안).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme() : appLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

/// 펫 자리 상자. 다시 만들어질 때마다 [builds] 를 센다.
int builds = 0;
Widget _pet(int scale) => Builder(
  builder: (_) {
    builds++;
    return SizedBox.square(key: const Key('pet'), dimension: 32.0 * scale);
  },
);

/// 무대 배경(펫 빼고)을 그려 칠해진 불투명 색 모음을 돌려준다.
Future<Set<int>> _colors(WidgetTester tester, {int index = 0}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byType(StageBackdrop),
          matching: find.byType(RepaintBoundary),
        )
        .at(index),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  });
  final out = <int>{};
  for (var i = 0; i < bytes!.lengthInBytes; i += 4) {
    if (bytes.getUint8(i + 3) != 255) continue;
    out.add(
      0xFF000000 |
          bytes.getUint8(i) << 16 |
          bytes.getUint8(i + 1) << 8 |
          bytes.getUint8(i + 2),
    );
  }
  return out;
}

StageBackdropState _state(WidgetTester tester) =>
    tester.state<StageBackdropState>(find.byType(StageBackdrop));

void main() {
  test('투시 격자: 시안 홈(350×300, 8배)·러닝 중(350×260, 6배)', () {
    final home = StageView.forPet(
      size: const Size(350, 300),
      scale: 8,
      feetFromBottom: Stage.groundHeight - Stage.footSink,
      colors: AppColors.light,
      brightness: Brightness.light,
    );
    // 배경 도트 4px, 88칸(좌우 1px 잘림), 지평선은 발끝 위 13 스프라이트 줄.
    expect(home.artPx, 4);
    expect(home.cols, 88);
    expect(home.originX, -1);
    expect(home.k, 38);
    expect(home.yh, 75 - 38);
    // 발끝 깊이에서 길(반폭 0.85)이 펫 발(가운데 ±10 스프라이트 칸)보다 넓다.
    const feetZ = 38 / (38 - 12);
    expect(0.85 * home.k / feetZ * 4, greaterThan(10 * 8));
    final run = StageView.forPet(
      size: const Size(350, 260),
      scale: 6,
      feetFromBottom: Stage.groundHeightCompact - Stage.footSink,
      colors: AppColors.dark,
      brightness: Brightness.dark,
    );
    expect(run.artPx, 4);
    expect(run.k, 28);
    expect(run.sx(0, 5), run.cx);
    expect(run.sy(0, 1), run.rows);
    expect(run.sy(1, 3), run.yh);
    expect(
      [for (var s = 1; s <= 8; s++) StageView.artPxFor(s)],
      [1, 1, 2, 2, 3, 4, 4, 4],
    );
  });

  test('공원 산책로는 네 겹이고 흐름 32장·0.5칸/초(4초 한 바퀴)', () {
    expect(parkScene.layers, hasLength(4));
    expect(parkScene.layers.toSet(), hasLength(4));
    expect(parkScene.stepsPerPeriod, 32);
    expect(parkScene.stepAt(0), 0);
    expect(parkScene.stepAt(1), 8);
    expect(parkScene.stepAt(4), 0);
    expect(parkScene.offsetAt(16), 1);
  });

  test('tokens.json stageScene.park 가 ParkPalette 와 같다(라이트·다크)', () {
    final json =
        jsonDecode(File('docs/design/tokens.json').readAsStringSync())
            as Map<String, dynamic>;
    final park = ((json['stageScene'] as Map)['park'] as Map)['tokens'] as List;
    final light = ParkPalette.light.asMap, dark = ParkPalette.dark.asMap;
    final names = <String>{};
    for (final t in park.cast<Map<String, dynamic>>()) {
      final name = (t['name'] as String).replaceFirst('park-', '');
      final camel = name.replaceAllMapped(
        RegExp('-([a-z])'),
        (m) => m[1]!.toUpperCase(),
      );
      names.add(camel);
      final v = t['value'] as Map<String, dynamic>;
      Color hex(String s) => Color(int.parse('FF${s.substring(1)}', radix: 16));
      expect(hex(v['light'] as String), light[camel], reason: camel);
      expect(hex(v['dark'] as String), dark[camel], reason: camel);
    }
    expect(names, light.keys.toSet());
  });

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('PetStage 에 공원 산책로 네 겹이 깔린다($name)', (tester) async {
      await _pump(
        tester,
        PetStage(height: 300, scale: 8, pet: _pet(8)),
        dark: dark,
      );
      final w = tester.widget<StageBackdrop>(find.byType(StageBackdrop));
      expect(w.scene, same(parkScene));
      expect(w.moving, isFalse);
      expect(w.feetFromBottom, Stage.groundHeight - Stage.footSink);
      final c = dark ? AppColors.dark : AppColors.light;
      final p = dark ? ParkPalette.dark : ParkPalette.light;
      final painted = await _colors(tester);
      int v(Color x) => x.toARGB32();
      // 1 하늘, 2 먼 풍경 두 겹, 3 풀밭·길·가장자리·풀잎·자갈, 4 나무 잎·줄기·덤불.
      expect(painted, contains(v(c.stageSky)), reason: '하늘');
      expect(painted, containsAll([v(p.far), v(p.far2)]), reason: '먼 풍경');
      expect(
        painted,
        containsAll([v(c.stageGround), v(p.path), v(p.edge), v(p.pebble)]),
        reason: '땅·길',
      );
      expect(
        painted,
        containsAll([v(p.canopy), v(p.canopyHi), v(p.trunk)]),
        reason: '앞 장식',
      );
      // 연두 primary 는 배경에 쓰지 않는다.
      expect(painted, isNot(contains(v(c.primary))));
      // 다른 테마 색이 섞이지 않는다.
      final other = dark ? ParkPalette.light : ParkPalette.dark;
      expect(painted, isNot(contains(v(other.path))));
    });
  }

  testWidgets('위쪽은 하늘로 비어 있다(말풍선 자리): 무대 위 1/4 은 하늘색뿐', (tester) async {
    await _pump(tester, PetStage(height: 300, scale: 8, pet: _pet(8)));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(
        of: find.byType(StageBackdrop),
        matching: find.byType(RepaintBoundary),
      ),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return d!;
    });
    final sky = AppColors.light.stageSky;
    for (var y = 0; y < 75; y += 5) {
      for (var x = 0; x < 350; x += 7) {
        final i = (y * 350 + x) * 4;
        expect(
          [bytes!.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2)],
          [(sky.r * 255).round(), (sky.g * 255).round(), (sky.b * 255).round()],
          reason: '($x, $y)',
        );
      }
    }
  });

  testWidgets('러닝 중(moving)이면 길이 흐르고 펫은 다시 만들지 않는다', (tester) async {
    await _pump(
      tester,
      PetStage(
        height: 260,
        scale: 6,
        groundHeight: Stage.groundHeightCompact,
        moving: true,
        pet: _pet(6),
      ),
    );
    final before = await _colorsImage(tester);
    builds = 0;
    expect(_state(tester).flowing, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_state(tester).step, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    final after = await _colorsImage(tester);
    expect(after, isNot(before), reason: '무늬가 움직였다');
    expect(builds, 0);
  });

  testWidgets('멈춘 무대(moving 꺼짐)는 흐르지 않는다', (tester) async {
    await _pump(tester, PetStage(height: 300, scale: 8, pet: _pet(8)));
    expect(_state(tester).flowing, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(tester).step, 0);
  });

  testWidgets('애니메이션 줄이기면 러닝 중이어도 0번 장에 멈춘다', (tester) async {
    await _pump(
      tester,
      PetStage(
        height: 260,
        scale: 6,
        groundHeight: Stage.groundHeightCompact,
        moving: true,
        pet: _pet(6),
      ),
      reduced: true,
    );
    expect(_state(tester).flowing, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(tester).step, 0);
  });

  testWidgets('일시정지(moving 이 꺼짐)면 그 자리에 멈추고, 다시 켜면 이어서 흐른다', (tester) async {
    Widget stage(bool moving) => PetStage(
      height: 260,
      scale: 6,
      groundHeight: Stage.groundHeightCompact,
      moving: moving,
      pet: _pet(6),
    );
    await _pump(tester, stage(true));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    final paused = _state(tester).step;
    expect(paused, greaterThan(0));
    await _pump(tester, stage(false));
    expect(_state(tester).flowing, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(tester).step, paused);
    await _pump(tester, stage(true));
    expect(_state(tester).flowing, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_state(tester).step, greaterThan(paused));
  });

  testWidgets('발끝 위치는 그대로(무대 아래에서 땅 높이 − 8)', (tester) async {
    for (final (scale, ground) in [
      (8, Stage.groundHeight),
      (6, Stage.groundHeightCompact),
      (3, Stage.groundHeightMini),
    ]) {
      await _pump(
        tester,
        PetStage(
          height: 300,
          scale: scale,
          groundHeight: ground,
          moving: scale == 6,
          pet: _pet(scale),
        ),
      );
      final stage = tester.getRect(find.byType(PetStage));
      final pet = tester.getRect(find.byKey(const Key('pet')));
      final foot = pet.bottom - spriteFootGapRows * scale;
      expect(stage.bottom - foot, ground - Stage.footSink);
    }
  });

  for (final (w, h, scale, ground) in [
    (64.0, 72.0, 2, Stage.groundHeightMini),
    (140.0, 120.0, 3, Stage.groundHeightMini),
    (350.0, 40.0, 1, Stage.groundHeightCompact),
    (350.0, 120.0, 4, Stage.groundHeightCompact),
    (2.0, 2.0, 1, Stage.groundHeightMini),
  ]) {
    testWidgets('작은 무대 $w×$h($scale배)도 그려지고 예외가 없다', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: w,
          height: h,
          child: PetStage(
            scale: scale,
            groundHeight: ground,
            radius: Radii.sm,
            pet: _pet(scale),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (w < 10) return;
      final painted = await _colors(tester);
      expect(painted, contains(AppColors.light.stageSky.toARGB32()));
      // 2배 카드 무대는 길가 물체를 그리지 않는다(작아서 알아볼 수 없다).
      if (scale < StageView.detailMinScale) {
        expect(painted, isNot(contains(ParkPalette.light.trunk.toARGB32())));
      }
    });
  }
}

/// 무대 배경 픽셀 전체(비교용).
Future<List<int>> _colorsImage(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(
      of: find.byType(StageBackdrop),
      matching: find.byType(RepaintBoundary),
    ),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final d = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return d!;
  });
  return bytes!.buffer.asUint8List().toList();
}
