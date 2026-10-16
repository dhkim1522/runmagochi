# 0004 Flutter 채택

- 상태: 채택
- 날짜: 2026-10-16

## 배경

1인 개발로 Android·iOS를 함께 지원해야 하고, 도트 아바타를 두 플랫폼에서 똑같이 선명하게 그려야 한다. 서버 없이 백그라운드 GPS 기록이 안정적이어야 한다.

## 결정

Flutter로 개발한다. 게임 엔진(Flame)은 쓰지 않는다.

## 근거

- 자체 렌더링이라 도트 그림이 `FilterQuality.none` 으로 두 플랫폼에서 똑같이 선명하다.
- 스프라이트 애니메이션은 시트의 프레임을 넘기는 일반 위젯으로 충분하다.
- React Native(Expo)의 백그라운드 위치는 Android·iOS 모두 '항상 허용' 권한을 요구한다. Flutter의 geolocator 는 Android 포그라운드 서비스로 '앱 사용 중' 권한만으로 기록할 수 있다.
- 유료 위치 라이브러리(flutter_background_geolocation, 앱당 $399부터) 없이 무료 geolocator 로 시작한다.

## 결과

- geolocator 가 실기기에서 화면 꺼짐 기록에 실패하면 플랫폼 채널로 네이티브 코드를 직접 써야 한다.
- 미니게임처럼 게임 엔진이 필요한 기능을 만들 때 Flame 도입을 다시 검토한다.
- 검토 상세는 [기획·기술 스택 검토](../research/plan-review.md).
