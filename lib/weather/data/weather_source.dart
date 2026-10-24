import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/stage/stage_weather.dart';
import '../domain/wmo.dart';

class WeatherException implements Exception {
  const WeatherException(this.message);
  final String message;

  @override
  String toString() => 'WeatherException: $message';
}

/// 현재 날씨를 받는 곳. 테스트는 가짜로 바꾼다.
abstract interface class WeatherSource {
  Future<StageWeather> fetch(double latitude, double longitude);
}

/// Open-Meteo 현재 날씨(무료, API 키 없음). 위치는 소수 첫째 자리(약 10km)로
/// 뭉뚱그려 보낸다. 러닝 기록과 상관없이 무대 배경에만 쓴다.
class OpenMeteoWeatherSource implements WeatherSource {
  OpenMeteoWeatherSource([http.Client? client])
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  @override
  Future<StageWeather> fetch(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(1),
      'longitude': longitude.toStringAsFixed(1),
      'current': 'weather_code,is_day',
    });
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) {
      throw WeatherException('HTTP ${res.statusCode}');
    }
    final Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      throw const WeatherException('JSON 아님');
    }
    if (json case {
      'current': {'weather_code': final num code, 'is_day': final num isDay},
    }) {
      return StageWeather(conditionForWmo(code.toInt()), night: isDay == 0);
    }
    throw const WeatherException('current 없음');
  }
}
