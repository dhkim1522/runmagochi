import '../../core/stage/stage_weather.dart';

/// WMO 날씨 코드(Open-Meteo `weather_code`)를 무대 날씨로. 모르는 코드는 맑음.
/// 0·1 맑음, 2·3·안개 흐림, 이슬비·비·소나기·뇌우 비, 눈·눈 소나기 눈.
WeatherCondition conditionForWmo(int code) => switch (code) {
  0 || 1 => WeatherCondition.clear,
  2 || 3 || 45 || 48 => WeatherCondition.cloudy,
  >= 51 && <= 67 || >= 80 && <= 82 || >= 95 && <= 99 => WeatherCondition.rain,
  >= 71 && <= 77 || 85 || 86 => WeatherCondition.snow,
  _ => WeatherCondition.clear,
};
