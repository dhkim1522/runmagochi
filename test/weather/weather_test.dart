import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runmagochi/weather/data/weather_source.dart';
import 'package:runmagochi/core/stage/stage_weather.dart';
import 'package:runmagochi/weather/domain/wmo.dart';

void main() {
  group('WMO 날씨 코드 → 무대 날씨', () {
    test('맑음·흐림·비·눈', () {
      for (final c in [0, 1]) {
        expect(conditionForWmo(c), WeatherCondition.clear, reason: '$c');
      }
      for (final c in [2, 3, 45, 48]) {
        expect(conditionForWmo(c), WeatherCondition.cloudy, reason: '$c');
      }
      for (final c in [
        51,
        53,
        55,
        56,
        57,
        61,
        63,
        65,
        66,
        67,
        80,
        81,
        82,
        95,
        96,
        99,
      ]) {
        expect(conditionForWmo(c), WeatherCondition.rain, reason: '$c');
      }
      for (final c in [71, 73, 75, 77, 85, 86]) {
        expect(conditionForWmo(c), WeatherCondition.snow, reason: '$c');
      }
    });

    test('모르는 코드는 맑음', () {
      expect(conditionForWmo(1234), WeatherCondition.clear);
    });
  });

  group('OpenMeteoWeatherSource', () {
    test('현재 날씨 코드와 낮밤을 읽고, 위치는 소수 첫째 자리로 뭉뚱그려 보낸다', () async {
      late Uri asked;
      final client = MockClient((req) async {
        asked = req.url;
        return http.Response(
          jsonEncode({
            'current': {'weather_code': 63, 'is_day': 0},
          }),
          200,
        );
      });
      final w = await OpenMeteoWeatherSource(client).fetch(37.5665, 126.9780);
      expect(w, const StageWeather(WeatherCondition.rain, night: true));
      expect(asked.host, 'api.open-meteo.com');
      expect(asked.queryParameters['latitude'], '37.6');
      expect(asked.queryParameters['longitude'], '127.0');
      expect(asked.queryParameters['current'], 'weather_code,is_day');
    });

    test('응답이 실패하거나 모양이 틀리면 던진다', () async {
      final bad = OpenMeteoWeatherSource(
        MockClient((_) async => http.Response('oops', 500)),
      );
      await expectLater(bad.fetch(37, 127), throwsA(isA<WeatherException>()));
      final odd = OpenMeteoWeatherSource(
        MockClient((_) async => http.Response('{"current":{}}', 200)),
      );
      await expectLater(odd.fetch(37, 127), throwsA(isA<WeatherException>()));
    });
  });
}
