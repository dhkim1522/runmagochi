# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 4 보상 완료** (`docs/plans/phase-4.md`, 결정 0019·0020·0021). 아이템·가격·자동 결정은 2026-10-21 확인, 실기기 확인(알림·자동 일시정지 기준값·빠른 이동 자동 종료)은 페이즈 8
  - 러닝 알림(F20): 거리·시간·목표 진행 실시간 표시, 일시정지·재개 버튼
  - 자동 일시정지·재개(F4), 자동 일시정지 5분·사용자 일시정지 1시간 뒤 30초 예고 종료
  - 코인(F9): 거리 코인 + 목표 달성 코인, 요약 코인 줄, 홈 코인 칩, 코인 내역(DB v5, 백업 v5)
  - 상점·꾸미기(F10·F11): 모자·소품 6종 구매·장착·벗기, 하단 탭 4개
  - 테스트 672건, 분석 0, 디버그 APK 성공, 에뮬레이터 E2E 통과(빠른 이동 자동 종료만 에뮬레이터 한계)
  - 스크린샷 `design/mockups/phase-4-screens/`, 아이템 미리보기 `design/character/items.png`
- **페이즈 3.5 오늘 목표와 보상 규칙 완료** (`docs/plans/phase-3.5.md`, 결정 0018). 빠른 이동 자동 종료 실기기 확인만 페이즈 8
- **페이즈 1~3**: 구현 완료, 실기기 확인은 페이즈 8 에서 Android·iPhone 함께(결정 0017·0022)
- 로드맵: 5 확장 → 6 디자인 완성(6-1 캐릭터, 6-2 UI) → 7 산출물 정리 → 8 iOS 확장·실기기 확인 → 9 동시 출시 (결정 0022)

## 다음 할 일

1. **`/phase 5` (확장)**: 자동 일시정지는 페이즈 4 에서 했으므로 범위에서 빠진다. 페이스 그래프·월·년 통계, 시간 목표·레이스, 음성 안내, 건강 연동, 업적·배지, 요약 공유 카드, 이름 후보 상표 검색.
2. 디자인 다듬기(톤앤매너·공통 컴포넌트·캐릭터·아이템 그림·코인 색)는 페이즈 6 에서 한다.

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac: `brew install fvm`(4.3.2) → `fvm install` 완료, `fvm flutter test` 통과.
  - 회사 Mac 에 Xcode 가 없다. 페이즈 8 전에 App Store 에서 설치한다(Apple ID 로그인 필요).
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
