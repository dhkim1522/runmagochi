import 'package:flutter/material.dart' show ThemeMode;

/// 프로필 저장소. 행은 하나이고 처음 쓸 때 만든다.
abstract interface class ProfileRepository {
  /// 체중(kg). 입력하지 않았으면 null.
  Future<double?> weightKg();

  /// 체중을 저장한다. null 이면 지운다.
  Future<void> setWeightKg(double? kg);

  /// 러닝 중 음성 안내를 켰는지. 행이 없으면 기본값 true.
  Future<bool> voiceGuide();

  /// 음성 안내를 켜거나 끈다.
  Future<void> setVoiceGuide(bool on);

  /// 쉬는 날 캐릭터 알림(F27)을 켰는지. 행이 없으면 기본값 true.
  Future<bool> reminder();

  /// 쉬는 날 알림을 켜거나 끈다.
  Future<void> setReminder(bool on);

  /// 화면 모드. 행이 없으면 기본값 시스템.
  Future<ThemeMode> themeMode();

  /// 화면 모드를 바꾼다.
  Future<void> setThemeMode(ThemeMode mode);

  /// 첫 실행 안내를 마쳤는지.
  Future<bool> isOnboarded();

  /// 첫 실행 안내를 마쳤다고 표시한다. 이미 표시했으면 시각을 바꾸지 않는다.
  Future<void> markOnboarded();
}
