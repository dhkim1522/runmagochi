# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 4 보상 구현 진행 중** (`docs/plans/phase-4.md`, 결정 0019·0020). 작업 1~10 완료, 문서 현행화(작업 11) 완료. 다음은 검증과 에뮬레이터 E2E
  - 러닝 알림(F20): 거리·시간·목표 진행 실시간 표시, 일시정지·재개 버튼(결정 0021)
  - 자동 일시정지·재개, 5분(자동)·1시간(사용자) 멈춤 뒤 30초 예고 종료
  - 코인: 거리 코인 + 목표 달성 코인, 요약 코인 줄, 홈 코인 칩, 코인 내역 화면(DB v5, 백업 v5)
  - 상점: 모자·소품 6종 구매·장착·벗기, 하단 탭 4개
  - 스크린샷 `design/mockups/phase-4-screens/` 는 E2E 때 채운다
- **페이즈 3.5 오늘 목표와 보상 규칙 완료** (`docs/plans/phase-3.5.md`, 결정 0018). 디자인·수치는 2026-10-21 확정, 빠른 이동 자동 종료 실기기 확인만 페이즈 7
  - 홈에서 오늘 목표(3·5·10km·직접 3~42km)를 고르고 시작, 기본값은 지난번 목표
  - 러닝 중 목표 진행 막대, 목표에 닿으면 알림·진동 한 번, 기록은 계속
  - 보상: 거리 경험치 + 목표 달성 보너스(목표 1km당 5). 요약에 달성·미달 구분
  - 주간 목표·연속 달성·금요일 알림 제거, 첫 실행 2장
  - 러닝 삭제는 경험치를 무르지 않음, 잘라내기는 다시 판정
  - 시속 30km 초과가 30초(점 시각 기준) 이어지면 자동 종료
  - 무활동 자동 종료는 결정 0020 이 정한다
  - 자동 진행 중 정한 것(기본 목표 3km, 10m 반올림 판정 등)은 2026-10-21 모두 확인
  - 테스트 557건, 분석 0, 디버그 APK 성공, 에뮬레이터 E2E 통과(빠른 이동 자동 종료만 에뮬레이터 한계로 미확인)
  - 구현 화면 스크린샷: `design/mockups/phase-3.5-screens/`
  - 와이어프레임 홈·목표 직접 입력·보상·업적을 결정 0018 규칙으로 맞춤(`design/wireframes/`). 편집용 claude.ai 캔버스는 예전 그대로
- **페이즈 1~3**: 구현 완료, 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017)
- 로드맵: 3.5 → 4 보상 → 5 확장 → 6 디자인 완성(6-1 캐릭터, 6-2 UI) → 7 iOS 확장·실기기 확인 → 8 동시 출시

## 다음 할 일

1. **`/phase 4` 이어서**: 전체 테스트·분석·APK 검증, `/e2e 4` 에뮬레이터 확인과 스크린샷, 이 파일 전체 갱신. 끝나면 페이즈 5.

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac: `brew install fvm`(4.3.2) → `fvm install` 완료, `fvm flutter test` 542건 통과(2026-10-20).
  - 회사 Mac 에 Xcode 가 없다. 페이즈 7 전에 App Store 에서 설치한다(Apple ID 로그인 필요).
  - 회사 Mac Android SDK 에는 Android 37 이미지와 `runmagochi` AVD 가 없다. `/e2e` 가 설치를 묻는다(약 2GB). 에뮬레이터는 시속 30km 이상 가상 점을 위치 서비스가 걸러 빠른 이동 확인이 안 된다.
- 회사 Mac: `~/personal/` 아래에서 git·gh 가 개인 계정(dhkim1522)으로 자동 전환된다.
- 집 Windows
  - Claude Code 개인 계정 로그인, 개인 SSH 키를 GitHub에 등록한 뒤 이 저장소를 clone한다. 저장소 안에서 `git config user.email dhkim1522@naver.com` 을 설정한다.
  - Flutter SDK와 Android SDK platform 37 이 필요하다. 첫 실행 때 `/kickoff`.
  - 집 PC 설치 위치(2026-10-17): Flutter `C:\src\flutter`(stable 3.47.7), JDK `Microsoft.OpenJDK.17`(winget), Android SDK `%LOCALAPPDATA%\Android\Sdk`. 사용자 환경 변수 `JAVA_HOME`·`ANDROID_HOME`·PATH 등록함.
  - Android Studio 없이 cmdline-tools 로 설치했다. 새 sdkmanager 는 `platforms/android-37.0`, `build-tools/36.0.0`, `ndk/28.2.13676358` 처럼 `/` 형식을 쓴다. NDK 는 Gradle 자동 설치가 실패하므로 직접 설치한다.
  - FVM 은 `dart pub global activate fvm` 으로 설치했다. Git Bash 는 `fvm.bat` 을 확장자 없이 못 찾으므로 `~/bin/fvm` 래퍼(`exec "$LOCALAPPDATA/Pub/Cache/bin/fvm.bat" "$@"`)를 둔다. 개발자 모드를 켜야 `fvm use` 가 링크를 만든다.
  - Aseprite(pixel-plugin 용)는 미설치. 페이즈 2 스프라이트 작업 전에 구매·설치하고 `/pixel-plugin:pixel-setup`.
- 상태 표시줄은 Mac·Windows 공용 설정 하나로 동작한다. Windows 는 Git for Windows 만 있으면 되고 `jq` 나 `settings.local.json` 은 필요 없다.
- 에뮬레이터 확인은 `/e2e [페이즈]` 로 한다. 수동으로는 `fvm dart run tool/fake_run.dart --minutes 5`, 에뮬레이터 위치 설정에서 "Location Accuracy" 를 켜야 위치가 들어온다.
