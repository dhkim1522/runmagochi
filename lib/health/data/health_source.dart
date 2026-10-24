import '../domain/health_workout.dart';

/// 건강 앱(Apple 건강·Health Connect)에서 러닝 운동을 읽는 곳. 테스트는 가짜로 바꾼다.
abstract interface class HealthSource {
  /// 이 기기에서 건강 앱을 쓸 수 있는가(Health Connect 미설치·미지원이면 false).
  Future<bool> isAvailable();

  /// 운동 읽기 권한이 있는가. iOS 는 읽기 허용 여부를 알려 주지 않아 true 로 본다.
  Future<bool> hasPermission();

  /// 운동 읽기 권한을 요청한다. 허용하면 true.
  Future<bool> requestPermission();

  /// [since] 이후 시작한 러닝 운동. 달리기가 아닌 운동도 [HealthWorkout.isRunning] 으로 구분해 준다.
  Future<List<HealthWorkout>> readRunningWorkouts(DateTime since);
}

/// 건강 앱을 아직 읽지 않는 구현(`health` 패키지 없음). 늘 "쓸 수 없음"이라 설정에서
/// 켜면 이 기기에서는 쓸 수 없다고 안내한다.
///
/// `health` 13.x 가 요구하는 device_info_plus 13 이 iOS 26 SDK 의 API 를 써서 Xcode 16.4 로는
/// iOS 를 빌드할 수 없다. Xcode 를 올린 뒤 `docs/pending/plugin_health_source.dart.txt` 의
/// `PluginHealthSource` 를 이 파일로 옮기고 pubspec 에 `health: ^13.3.2` 를 더한다
/// (결정 0038). 그때까지 건강 연동의 나머지(들이기·설정·저장)는 모두 동작한다.
class UnavailableHealthSource implements HealthSource {
  const UnavailableHealthSource();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<HealthWorkout>> readRunningWorkouts(DateTime since) async =>
      const [];
}
