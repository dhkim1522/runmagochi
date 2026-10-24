import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/stage/park_scene.dart';
import 'package:runmagochi/core/stage/stage_weather.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';

Future<Set<int>> _paint(
  WidgetTester tester, {
  StageWeather? weather,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget stage = PetStage(
    height: 300,
    scale: 8,
    pet: const SizedBox.square(dimension: 256),
  );
  if (weather != null) {
    stage = StageWeatherScope(weather: weather, child: stage);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme() : appLightTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
          child: Center(child: stage),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byType(StageBackdrop),
          matching: find.byType(RepaintBoundary),
        )
        .first,
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

int _v(Color c) => c.toARGB32();

void main() {
  const l = WeatherPalette.light;
  const d = WeatherPalette.dark;

  testWidgets('날씨가 없으면(기본) 지금 공원 무대와 같다', (tester) async {
    final painted = await _paint(tester);
    expect(painted, contains(_v(AppColors.light.stageSky)));
    expect(painted, contains(_v(ParkPalette.light.cloud)));
    expect(painted, isNot(contains(_v(l.overcastSky))));
  });

  testWidgets('흐림: 잿빛 하늘과 회색 구름', (tester) async {
    final painted = await _paint(
      tester,
      weather: const StageWeather(WeatherCondition.cloudy),
    );
    expect(painted, containsAll([_v(l.overcastSky), _v(l.cloud)]));
    expect(painted, isNot(contains(_v(AppColors.light.stageSky))));
  });

  testWidgets('비: 어두운 하늘·비구름에 빗줄기', (tester) async {
    final painted = await _paint(
      tester,
      weather: const StageWeather(WeatherCondition.rain),
    );
    expect(painted, containsAll([_v(l.rainSky), _v(l.rainCloud), _v(l.rain)]));
  });

  testWidgets('눈: 옅은 하늘에 눈송이', (tester) async {
    final painted = await _paint(
      tester,
      weather: const StageWeather(WeatherCondition.snow),
    );
    expect(painted, containsAll([_v(l.snowSky), _v(l.snow)]));
  });

  testWidgets('밤(맑음): 라이트 테마여도 밤 무대에 별과 달', (tester) async {
    final painted = await _paint(
      tester,
      weather: const StageWeather(WeatherCondition.clear, night: true),
    );
    expect(painted, contains(_v(AppColors.dark.stageSky)));
    expect(painted, contains(_v(ParkPalette.dark.path)));
    expect(painted, containsAll([_v(d.star), _v(d.moon)]));
    expect(painted, isNot(contains(_v(ParkPalette.light.path))));
  });

  testWidgets('밤에 비: 어두운 비 하늘과 빗줄기', (tester) async {
    final painted = await _paint(
      tester,
      weather: const StageWeather(WeatherCondition.rain, night: true),
    );
    expect(painted, containsAll([_v(d.rainSky), _v(d.rain)]));
  });

  testWidgets('다크 테마 낮의 눈은 어두운 눈 하늘', (tester) async {
    final painted = await _paint(
      tester,
      dark: true,
      weather: const StageWeather(WeatherCondition.snow),
    );
    expect(painted, containsAll([_v(d.snowSky), _v(d.snow)]));
  });

  test('같은 날씨는 같은 무대(그려 둔 그림을 다시 쓴다)', () {
    for (final c in WeatherCondition.values) {
      for (final n in [false, true]) {
        final w = StageWeather(c, night: n);
        expect(identical(parkSceneFor(w), parkSceneFor(w)), isTrue);
      }
    }
    expect(identical(parkSceneFor(StageWeather.clearDay), parkScene), isTrue);
  });
}
