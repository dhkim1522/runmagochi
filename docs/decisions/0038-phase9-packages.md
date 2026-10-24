# 0038 페이즈 9 신규 기능에 쓰는 패키지

- 상태: 채택
- 날짜: 2026-10-24

## 배경

결정 0037 의 신규 기능 가운데 일부는 지금 패키지로 만들 수 없다. 새로 들이는 패키지를 한곳에 적는다. 기능을 만들 때마다 이 표에 더한다.

## 결정

| 패키지 | 기능 | 이유 | 대안 |
| --- | --- | --- | --- |
| `timezone` ^0.11.2 | 쉬는 날 알림(F27) 예약 | `flutter_local_notifications` 의 예약 API 가 `TZDateTime` 을 받는다. 이미 그 패키지의 간접 의존성이라 크기가 늘지 않는다. 시간대 자료는 읽지 않고 UTC 로 바꿔 예약한다 | `flutter_timezone` 으로 기기 시간대를 읽는 방법은 패키지가 하나 더 늘고, 같은 순간을 예약하는 데는 필요 없다 |
| `http` ^1.6.0 | 날씨 배경(F25) | Open-Meteo 현재 날씨 한 번 받기. 이미 간접 의존성이다. 키가 없는 무료 API 라 서버·비밀값이 필요 없다(결정 0001) | `dio` 는 기능이 많고 크다. 요청 하나에는 필요 없다 |
| `home_widget` ^0.10.0 | 홈 화면 위젯(F29) | Android AppWidget·iOS WidgetKit 이 앱과 값·파일을 나누는 표준 방법. 앱이 위젯 카드를 PNG 로 그려 보내면 두 플랫폼이 같은 그림을 보인다(글꼴·도트·날씨 무대를 네이티브로 다시 그리지 않는다) | 위젯마다 Kotlin·SwiftUI 로 화면을 따로 그리면 그림이 둘이 되고 날씨·장비 표현이 어긋난다 |
| `health` ^13.3.2 (**아직 넣지 않음**) | 건강 앱 연동(F15) | Apple 건강(HealthKit)·Health Connect 를 한 인터페이스로 읽는다. 읽기만 한다. Android 최소 버전이 24 → 26 으로 오른다(사용자 승인 2026-10-24) | 플랫폼 채널을 직접 쓰면 두 OS 코드를 따로 유지해야 한다 |

## 결과

- 예약 알림은 정확한 알람 권한 없이 느슨한 예약(`inexactAllowWhileIdle`)을 쓴다. 몇 분 늦을 수 있다.
- 앱을 열 때 예전 버전의 예약 알림을 모두 지운 뒤 쉬는 날 알림을 다시 예약한다.
- 날씨는 이미 받은 위치 권한의 마지막 위치를 소수 첫째 자리(약 10km)로 뭉뚱그려 Open-Meteo 에 보낸다. 권한을 새로 묻지 않고, 권한·인터넷이 없으면 맑은 낮으로 그린다. 30분 안에는 다시 받지 않는다. Android 릴리스에 인터넷 권한을 더했다. 개인정보 처리방침(페이즈 10)에 적는다.
- 홈 화면 위젯은 앱이 열려 있거나 성장·장착·날씨가 바뀔 때 그림을 다시 보낸다(앱을 한 번도 안 열면 앱 아이콘). Android 는 에뮬레이터 홈 화면에서 확인했다. iOS 는 Widget Extension 타깃과 App Group 이 필요해 소스(`ios/PetWidget/`)만 두고 Xcode 연결은 사람 확인으로 남겼다(무료 Apple ID 제약).
- **`health` 패키지는 지금 넣지 않았다.** 13.x 가 요구하는 `device_info_plus 13` 이 iOS 26 SDK 의 API(`isiOSAppOnVision`)를 써서 이 Mac 의 Xcode 16.4(iOS 18.5 SDK)로는 iOS 를 빌드할 수 없고, 낮추면 `share_plus 13`(공유 카드)과 충돌한다. 사용자가 Xcode 를 올린 뒤 iOS·Android 모두 켜기로 했다(2026-10-24). 그때까지 건강 읽기는 `UnavailableHealthSource`(늘 "쓸 수 없음")이고 설정에서 켜면 "Health Connect 를 설치해 주세요" 안내가 뜬다. 켜는 방법은 `docs/pending/README.md`.
- 건강 앱 운동(WORKOUT 중 달리기)은 러닝 기록 한 건(`Runs.source = health:<운동 id>`)으로 들여 경험치·코인·배지·통계를 그대로 쓴다. 경로 점이 없어 경로는 비고, 1km 구간은 평균 페이스로 고르게 나눈다. 1km 미만·이 앱이 쓴 운동·이미 들인 운동(지운 기록 포함)은 들이지 않는다. 처음 켜면 최근 30일, 이후는 마지막으로 들인 러닝 하루 전부터 읽는다.
- iOS HealthKit 은 `ios/Runner/Runner.entitlements`(HealthKit 권한)가 필요하다. 무료 Apple ID 에서는 서명이 막힐 수 있어 파일만 두고 Xcode 타깃에 연결하지 않았다. 연결은 사람 확인(페이즈 9, 안 되면 페이즈 10 유료 계정 뒤). Android 는 Health Connect 권한(`READ_EXERCISE`·`READ_DISTANCE`)을 선언했다.
