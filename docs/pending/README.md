# 보류 중인 작업

## 건강 앱 연동(F15) 켜기

들이기·설정·저장·테스트는 모두 끝났고, 건강 앱을 실제로 읽는 한 파일만 `health` 패키지를 기다린다(결정 0038).

1. Xcode 를 iOS 26 SDK 이상으로 올린다(iPhone 이 iOS 27 이라 어차피 필요하다, 결정 0030).
2. `pubspec.yaml` 에 `health: ^13.3.2` 를 더하고 `fvm flutter pub get`.
3. `android/app/build.gradle.kts` 의 `minSdk = flutter.minSdkVersion` 을 `26` 으로(health 가 Android 8.0 이상을 요구).
4. `plugin_health_source.dart.txt` 의 `PluginHealthSource` 를 `lib/health/data/health_source.dart` 로 옮기고(`UnavailableHealthSource` 대신), `lib/health/app/providers.dart` 의 `healthSourceProvider` 를 `PluginHealthSource()` 로 바꾼다. `import 'package:flutter/foundation.dart'` 와 `import 'package:health/health.dart'` 를 더한다.
5. iOS: `ios/Runner/Runner.entitlements`(HealthKit)를 Xcode Runner 타깃 Signing & Capabilities → HealthKit 으로 연결. 무료 Apple ID 로 서명이 안 되면 유료 계정(페이즈 10) 뒤에 켠다.
6. `fvm flutter test`, 실제 폰에서 워치 러닝이 들어오는지 확인.
