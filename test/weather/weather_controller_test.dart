import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/providers.dart' show clockProvider;
import 'package:runmagochi/weather/app/weather_controller.dart';
import 'package:runmagochi/weather/data/coarse_location.dart';
import 'package:runmagochi/weather/data/weather_source.dart';
import 'package:runmagochi/core/stage/stage_weather.dart';

class _Location implements CoarseLocation {
  (double, double)? at = (37.5, 127.0);
  int asks = 0;

  @override
  Future<(double, double)?> lastKnown() async {
    asks++;
    return at;
  }
}

class _Source implements WeatherSource {
  StageWeather next = const StageWeather(WeatherCondition.rain);
  bool fail = false;
  int fetches = 0;

  @override
  Future<StageWeather> fetch(double latitude, double longitude) async {
    fetches++;
    if (fail) throw const WeatherException('down');
    return next;
  }
}

void main() {
  late _Location location;
  late _Source source;
  late DateTime now;

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        coarseLocationProvider.overrideWithValue(location),
        weatherSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    location = _Location();
    source = _Source();
    now = DateTime(2026, 10, 24, 9);
  });

  test('처음에는 맑은 낮이고, 받아 오면 그 날씨가 된다', () async {
    final c = container();
    expect(c.read(stageWeatherProvider), StageWeather.clearDay);
    await c.read(stageWeatherProvider.notifier).refreshIfStale();
    expect(c.read(stageWeatherProvider).condition, WeatherCondition.rain);
  });

  test('30분 안에는 다시 받지 않고, 지나면 다시 받는다', () async {
    final c = container();
    final n = c.read(stageWeatherProvider.notifier);
    await n.refreshIfStale();
    now = now.add(const Duration(minutes: 29));
    await n.refreshIfStale();
    expect(source.fetches, 1);
    now = now.add(const Duration(minutes: 2));
    source.next = const StageWeather(WeatherCondition.snow, night: true);
    await n.refreshIfStale();
    expect(source.fetches, 2);
    expect(c.read(stageWeatherProvider), source.next);
  });

  test('위치를 모르면 받지 않고 기본(맑은 낮)을 둔다', () async {
    location.at = null;
    final c = container();
    await c.read(stageWeatherProvider.notifier).refreshIfStale();
    expect(source.fetches, 0);
    expect(c.read(stageWeatherProvider), StageWeather.clearDay);
  });

  test('받기에 실패하면 지금 날씨를 그대로 두고 던지지 않는다', () async {
    final c = container();
    final n = c.read(stageWeatherProvider.notifier);
    await n.refreshIfStale();
    source.fail = true;
    now = now.add(const Duration(hours: 1));
    await n.refreshIfStale();
    expect(c.read(stageWeatherProvider).condition, WeatherCondition.rain);
  });
}
