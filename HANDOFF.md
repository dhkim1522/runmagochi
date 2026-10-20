# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 3.5 오늘 목표와 보상 규칙 구현 완료, 사람 확인 대기** (`docs/plans/phase-3.5.md`, 결정 0018)
  - 홈에서 오늘 목표(3·5·10km·직접 3~100km)를 고르고 시작, 기본값은 지난번 목표
  - 러닝 중 목표 진행 막대, 목표에 닿으면 알림·진동 한 번, 기록은 계속
  - 보상: 거리 경험치 + 목표 달성 보너스(목표 1km당 5). 요약에 달성·미달 구분
  - 주간 목표·연속 달성·금요일 알림 제거, 첫 실행 2장
  - 러닝 삭제는 경험치를 무르지 않음, 잘라내기는 다시 판정
  - 시속 30km 초과가 30초(점 시각 기준) 이어지면 자동 종료
  - 테스트 557건, 분석 0, 디버그 APK 성공, 에뮬레이터 E2E 통과(빠른 이동 자동 종료만 에뮬레이터 한계로 미확인)
  - 구현 화면 스크린샷: `design/mockups/phase-3.5-screens/`
- **페이즈 1~3**: 구현 완료, 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017)
- 로드맵: 3.5 → 4 보상 → 5 확장 → 6 디자인 완성(6-1 캐릭터, 6-2 UI) → 7 iOS 확장·실기기 확인 → 8 동시 출시

## 다음 할 일

1. **확인할 것** (자동 진행 중 임의로 정한 것, 아래 "확인 필요" 참고)
2. **디자인 확인**: `design/mockups/phase-3.5-screens/` 의 홈·러닝 중·요약 화면. 바꿀 점이 있으면 `/phase 3.5` 에 알려 준다.
3. **`/phase 4` (보상)**: 코인 계획은 결정 0018 구조(거리 보상 + 목표 달성 보너스)를 따른다. 아이템 스프라이트는 6-1 에서 다시 그리므로 최소 개수.

## 확인 필요 (2026-10-20 자동 진행 중 정함)

- 달성 보너스 수치: 목표 1km당 경험치 5 (초안)
- 직접 입력 범위 3~100km, 처음 기본 목표 3km
- 첫 실행을 2장으로 줄임(주간 목표 장 삭제), 주간 알림 대신 다른 알림은 없음
- 목표 달성 판정은 거리를 10m 로 반올림해 비교(화면 "5.00km" 면 5km 달성)
- 빠른 이동 30초는 점 시각 차이로 잼(튀는 점 하나로 끝나지 않게)
- 목표 달성 알림은 별도 알림 채널 "목표 달성"
- `timezone`·`flutter_timezone` 패키지 제거(예약 알림이 없어짐)
- E2E 는 기존 AVD `nrc_pixel`(Android 36)로 함. 앱은 확인 뒤 지웠다
- 새 홈·러닝 중·요약 화면은 시안 없이 기존 디자인 시스템으로 구현

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
