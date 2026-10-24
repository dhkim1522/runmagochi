import 'package:flutter/widgets.dart';

/// 무대에 그리는 날씨 (F25, 결정 0037).
enum WeatherCondition { clear, cloudy, rain, snow }

/// 날씨와 낮밤. 기본은 맑은 낮(인터넷·위치가 없을 때).
@immutable
class StageWeather {
  const StageWeather(this.condition, {this.night = false});

  static const clearDay = StageWeather(WeatherCondition.clear);

  final WeatherCondition condition;

  /// 해가 진 뒤면 밤 하늘(별·달)과 어두운 무대로 그린다.
  final bool night;

  @override
  bool operator ==(Object other) =>
      other is StageWeather &&
      other.condition == condition &&
      other.night == night;

  @override
  int get hashCode => Object.hash(condition, night);

  @override
  String toString() => 'StageWeather($condition, night: $night)';
}

/// 아래 무대(`PetStage`)들이 그릴 날씨. 없으면 맑은 낮이다. 앱이 받은 날씨를 위에 둔다.
/// 공유 카드처럼 날씨와 상관없어야 하는 곳은 [StageWeather.clearDay] 로 다시 감싼다.
class StageWeatherScope extends InheritedWidget {
  const StageWeatherScope({
    super.key,
    required this.weather,
    required super.child,
  });

  final StageWeather weather;

  static StageWeather of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<StageWeatherScope>()
          ?.weather ??
      StageWeather.clearDay;

  @override
  bool updateShouldNotify(StageWeatherScope old) => old.weather != weather;
}
