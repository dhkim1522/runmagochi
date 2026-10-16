# 0006 페이즈 1 패키지와 권한 범위

- 상태: 채택
- 날짜: 2026-10-16

## 배경

페이즈 1에서 위치 기록, 로컬 저장, 상태 관리가 필요하다. 권한 요청은 최소로 유지해야 한다.

## 결정

- 권한 요청에 `permission_handler`, 기록 식별자 생성에 `uuid` 를 추가한다.
- GPS 경로 압축은 외부 패키지 없이 직접 구현한다.
- 배터리 최적화 예외는 권한 요청 없이 설정 화면 안내로 처리한다.
- 상태 관리는 코드 생성 없이 `flutter_riverpod` 만 쓴다.

## 근거

- 위치·알림 권한을 한 패키지로 같은 방식으로 요청할 수 있다.
- 경로 압축은 규칙이 단순해 직접 구현이 의존성 추가보다 가볍다.
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 는 스토어 심사 부담이 있어 매니페스트에 넣지 않는다. `ACCESS_BACKGROUND_LOCATION` 도 넣지 않는다. 근거는 [기록 엔진 명세](../specs/run-engine.md)의 백그라운드 절이다.

## 결과

- 매니페스트 권한은 다음 6개다.
  - 정밀 위치 `ACCESS_FINE_LOCATION`
  - 대략 위치 `ACCESS_COARSE_LOCATION`
  - 포그라운드 서비스 `FOREGROUND_SERVICE`
  - 포그라운드 서비스(위치) `FOREGROUND_SERVICE_LOCATION`
  - 알림 `POST_NOTIFICATIONS`
  - 화면 꺼짐 중 기록 유지 `WAKE_LOCK`: geolocator 포그라운드 서비스가 wake lock 을 잡는다. 없으면 위치 점을 하나도 받지 못한다.
- 배터리 최적화 상태는 `runmagochi/battery` MethodChannel 로 Android `PowerManager` 에서 읽는다. 추가 권한이 필요 없다.
- `permission_handler` 14 는 compileSdk 37 을 요구한다. 빌드하는 PC 마다 Android SDK 37 플랫폼을 설치해야 한다.
- 안내 화면 문구는 실기기 검증 후 정한다.
