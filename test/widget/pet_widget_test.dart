import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/stage/stage_weather.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/weather/app/weather_controller.dart';
import 'package:runmagochi/widget/pet_widget_card.dart';
import 'package:runmagochi/widget/pet_widget_sync.dart';

import '../run/ui/fakes.dart';

class _Publisher implements PetWidgetPublisher {
  final published = <Uint8List>[];

  @override
  Future<void> publish(Uint8List png) async => published.add(png);
}

class _Weather extends StageWeatherController {
  @override
  StageWeather build() => StageWeather.clearDay;

  void set(StageWeather w) => state = w;

  @override
  Future<void> refreshIfStale() async {}
}

void main() {
  testWidgets('위젯 카드: 무대 위 캐릭터와 이름·레벨·다음 레벨까지 거리', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        home: const Center(
          child: PetWidgetCard(
            kind: AvatarKind.jelly,
            stage: 2,
            mood: AvatarMood.normal,
            name: '말랑이',
            level: 9,
            kmToNextLevel: 3.5,
            weather: StageWeather(WeatherCondition.rain),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PetWidgetCard)), petWidgetSize);
    expect(find.text('말랑이 Lv.9'), findsOneWidget);
    expect(find.text('다음 레벨까지 3.5km'), findsOneWidget);
    expect(
      tester
          .widget<StageWeatherScope>(
            find.descendant(
              of: find.byType(PetWidgetCard),
              matching: find.byType(StageWeatherScope),
            ),
          )
          .weather
          .condition,
      WeatherCondition.rain,
    );
  });

  group('PetWidgetSync', () {
    late _Publisher publisher;
    late _Weather weather;
    late List<PetWidgetCard> rendered;
    late FakeGrowthService growth;

    Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petWidgetEnabledProvider.overrideWithValue(enabled),
            petWidgetPublisherProvider.overrideWithValue(publisher),
            petWidgetRendererProvider.overrideWithValue((context, card) async {
              rendered.add(card);
              return Uint8List.fromList([1, 2, 3]);
            }),
            growthServiceProvider.overrideWithValue(growth),
            shopRepositoryProvider.overrideWithValue(FakeShop()),
            stageWeatherProvider.overrideWith(() => weather),
          ],
          child: MaterialApp(
            theme: appLightTheme(),
            home: const PetWidgetSync(child: SizedBox()),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    setUp(() {
      publisher = _Publisher();
      weather = _Weather();
      rendered = [];
      growth = FakeGrowthService(growthState(name: '말랑이', level: 4));
    });

    testWidgets('성장 상태를 읽으면 카드를 그려 위젯으로 보낸다', (tester) async {
      await pump(tester);
      expect(publisher.published, hasLength(1));
      expect(rendered.single.name, '말랑이');
      expect(rendered.single.level, 4);
    });

    testWidgets('날씨가 바뀌면 다시 그린다', (tester) async {
      await pump(tester);
      weather.set(const StageWeather(WeatherCondition.snow));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(publisher.published, hasLength(2));
      expect(rendered.last.weather.condition, WeatherCondition.snow);
    });

    testWidgets('위젯을 쓸 수 없는 기기(테스트·웹)에서는 아무것도 하지 않는다', (tester) async {
      await pump(tester, enabled: false);
      expect(publisher.published, isEmpty);
      expect(rendered, isEmpty);
    });
  });
}
