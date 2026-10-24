import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart' show clockProvider;
import '../data/coarse_location.dart';
import '../data/weather_source.dart';
import '../../core/stage/stage_weather.dart';

final coarseLocationProvider = Provider<CoarseLocation>(
  (_) => const GeolocatorCoarseLocation(),
);

final weatherSourceProvider = Provider<WeatherSource>(
  (_) => OpenMeteoWeatherSource(),
);

/// 무대 날씨 (F25). 처음에는 맑은 낮이고, [StageWeatherController.refreshIfStale] 로
/// 받아 온다. 앱을 열 때·화면으로 돌아올 때 부른다.
final stageWeatherProvider =
    NotifierProvider<StageWeatherController, StageWeather>(
      StageWeatherController.new,
    );

class StageWeatherController extends Notifier<StageWeather> {
  /// 이 시간 안에 받은 날씨는 다시 받지 않는다.
  static const freshFor = Duration(minutes: 30);

  DateTime? _fetchedAt;
  bool _busy = false;

  @override
  StageWeather build() => StageWeather.clearDay;

  /// 받은 지 [freshFor] 가 지났으면 다시 받는다. 위치를 모르거나 실패하면 지금 날씨를
  /// 그대로 둔다. 어떤 실패도 던지지 않는다.
  Future<void> refreshIfStale() async {
    if (_busy) return;
    final now = ref.read(clockProvider)();
    final last = _fetchedAt;
    if (last != null && now.difference(last) < freshFor) return;
    _busy = true;
    try {
      final at = await ref.read(coarseLocationProvider).lastKnown();
      if (at == null) return;
      final weather = await ref.read(weatherSourceProvider).fetch(at.$1, at.$2);
      _fetchedAt = now;
      state = weather;
    } catch (e) {
      debugPrint('날씨: 받기 실패 $e');
    } finally {
      _busy = false;
    }
  }
}
