# 0008 FVM 으로 Flutter 버전 고정

- 상태: 채택
- 날짜: 2026-10-17

## 배경

- Mac과 Windows PC를 오가며 개발한다. 각 PC의 전역 Flutter 버전이 달랐다.
- Flutter SDK 는 `meta`·`matcher` 같은 일부 패키지 버전을 고정한다. PC가 바뀔 때마다 `pubspec.lock` 이 바뀌었다.
- 새 Flutter 는 빌드할 때 `analysis_options.yaml` 같은 설정 파일을 자동으로 고친다. 렌더링·린트·Gradle 연동도 버전마다 다르다.
- `pubspec.yaml` 의 `sdk: ^3.12.2` 는 최소 버전만 정한다.

## 결정

- [FVM](https://fvm.app) 으로 프로젝트 Flutter 버전을 고정한다. 저장소 루트의 `.fvmrc` 에 버전을 적고 커밋한다.
- 시작 버전은 stable 3.47.7(Dart 3.13.5)이다.
- 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다. 전역 Flutter 는 다른 프로젝트용으로 남겨 둔다.
- `.fvm/` 폴더는 PC별이라 커밋하지 않는다.
- 버전을 올릴 때는 `fvm use <버전>` 으로 `.fvmrc` 를 바꾸고, 테스트 통과와 `pubspec.lock` 변경을 한 커밋에 담는다. 다른 PC는 `fvm install` 로 따라간다.

## 결과

- 두 PC가 같은 Flutter·Dart 로 빌드하고 테스트한다. `pubspec.lock` 이 PC 때문에 바뀌지 않는다.
- 각 PC에 FVM 을 설치해야 한다. Windows 는 FVM 이 심볼릭 링크를 만들기 때문에 개발자 모드가 켜져 있어야 한다.
- dart-flutter 플러그인의 Dart MCP 서버는 전역 `dart` 를 쓴다. 전역 Flutter 버전이 `.fvmrc` 와 다르면 분석 결과가 조금 다를 수 있다.
