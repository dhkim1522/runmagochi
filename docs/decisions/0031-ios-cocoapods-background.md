# 0031 iOS 는 CocoaPods 로 빌드하고 백그라운드 위치·소리를 켠다

- 상태: 채택
- 날짜: 2026-10-22

## 배경

- 결정 0030 으로 iOS 빌드와 iPhone 설치를 페이즈 6 과 나란히 시작했다.
- Flutter 3.47 은 iOS 플러그인을 Swift Package Manager(SwiftPM)로 가져오는 것이 기본이다. `flutter_tts` 는 SwiftPM 을 지원하지 않아 CocoaPods 와 섞여 쓰인다.
- `permission_handler` 는 켠 권한만 코드에 넣는다. SwiftPM 에서는 빌드를 시작한 폴더에서 앱의 `Info.plist` 를 찾아 권한을 정하는데, Xcode 앱에서 실행하면 폴더를 찾지 못해 모든 권한이 빠지고 위치 권한이 늘 거부로 보고된다. CocoaPods 에서는 `Podfile` 에 적은 값을 그대로 쓴다.
- `geolocator` 는 iOS 기본 설정에서 백그라운드 위치를 끈다. 명세(`docs/specs/run-engine.md`)는 화면을 꺼도 기록이 이어져야 하고, 음성 안내도 화면이 꺼진 채 읽어야 한다.

## 결정

- 이 앱은 iOS 를 **CocoaPods 로만 빌드**한다(`pubspec.yaml` 의 `flutter: config: enable-swift-package-manager: false`). `permission_handler` 권한은 `ios/Podfile` 에서 '앱 사용 중' 위치와 알림만 켠다.
- `Info.plist` 에 '앱 사용 중'과 '항상' 위치 설명을 모두 넣는다. 앱은 '앱 사용 중'만 요청하지만 `geolocator` 코드에 '항상' 요청이 들어 있어 설명 키가 없으면 App Store 업로드 때 경고가 난다. 명세의 `BYPASS_PERMISSION_LOCATION_ALWAYS` 대신 이 방법을 쓴다.
- `UIBackgroundModes` 에 `location`(화면 꺼짐 기록)과 `audio`(화면 꺼짐 음성 안내)를 넣는다. 위치 스트림은 iOS 에서 `AppleSettings` 로 백그라운드 위치를 켜고, 자동 멈춤을 끄고, 활동 유형을 운동(fitness)으로 둔다.
- `CLBackgroundActivitySession` 은 쓰지 않는다. 이 세션은 iOS 17 의 새 위치 API(`CLLocationUpdate`)용이고, `geolocator` 는 기존 `CLLocationManager` 에 `allowsBackgroundLocationUpdates` 를 켜는 방식이라 '앱 사용 중' 권한으로도 화면에 있을 때 시작한 기록이 이어진다. 실기기에서 화면 꺼짐 기록으로 확인한다.
- 화면 크기는 iPhone 만 지원한다(`TARGETED_DEVICE_FAMILY = 1`). iPad 는 iPhone 호환 모드로 열린다.

## 결과

- Xcode 에서 실행해도 `flutter run` 과 같은 권한으로 빌드된다.
- Flutter 가 CocoaPods 지원을 끝내면 SwiftPM 으로 옮기고, 그때 `permission_handler` 의 `PERMISSION_HANDLER_INFO_PLIST` 설정을 다시 본다.
- `audio` 백그라운드 모드는 음성 안내용이다. 앱 심사에서 이유를 물으면 러닝 중 음성 안내라고 답한다.
