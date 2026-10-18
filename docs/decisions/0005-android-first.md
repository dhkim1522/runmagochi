# 0005 Android 먼저, iOS는 페이즈 3

- 상태: 대체됨 (결정 0014)
- 날짜: 2026-10-16

## 배경

- 개발은 회사 Mac과 집 Windows PC에서 한다. iOS 빌드와 시뮬레이터는 Mac에서만 동작한다.
- iPhone 지인 베타(TestFlight)에는 Apple 개발자 계정(연 $99)이 필요하다. Android는 APK 파일을 직접 전달하면 비용 없이 배포된다.
- 테스트 기기로 iPhone과 Android 휴대폰(가족 기기)을 모두 쓸 수 있다.

## 결정

페이즈 1~2는 Android로만 개발·검증한다. iOS 대응과 TestFlight 배포는 페이즈 3에서 시작하고, 그때 개발자 계정을 구입한다.

## 결과

- Windows PC에서도 페이즈 1~2 작업이 모두 가능하다.
- iOS 고유 문제(백그라운드 위치 권한, `CLBackgroundActivitySession` 필요 여부)는 페이즈 3에서 발견된다. Flutter 공통 코드로 작성해 수정 범위를 줄인다.
- 페이즈 3 이전에 iPhone으로 확인하고 싶으면, Mac의 Xcode에서 무료 Apple ID로 본인 iPhone에 설치할 수 있다. 설치한 앱은 7일마다 만료된다.
