# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 6 디자인 완성 실행 중** (`docs/plans/phase-6.md`, 2026-10-22 계획 승인)
  - 캐릭터는 코드 도트로 그린다(Aseprite·생성 AI 안 씀). Impeccable·Taste Skill 을 이 PC 에 켰다(`--scope local`)
  - 관문 3개: 1 캐릭터 투표(작업 2), 2 UI 방향 선택(작업 9), 3 출시 품질 승인. 관문에서 멈추고 사용자에게 묻는다
  - 진행: 작업 1 완료(후보 a 클레이 다듬기·b 큰 머리 다마고치·c 플랫 마스코트, `design/candidates/character/compare.png`, 결정 0028). 관문 1 결과 A 말랑 클레이. 작업 3 병아리 다시 그리기 진행
- **페이즈 5 확장 완료** (`docs/plans/phase-5.md`). 아이폰 음성 안내 확인만 페이즈 7
- **페이즈 1~4 완료**. 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017·0026)
- 로드맵: 6 디자인 완성 → 7 iOS 확장·본인 iPhone 실기기 확인 → 8 산출물 정리 → 9 출시(써 본 뒤 결정) (결정 0026)

## 다음 할 일

1. **`/phase 6` 이어서**: 계획 파일에서 체크되지 않은 첫 작업부터. 진행 기록은 `.superpowers/sdd/phase-6/progress.md`(이 PC 에만 있음, 없으면 `git log` 로 판단)

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac: `brew install fvm`(4.3.2) → `fvm install` 완료, `fvm flutter test` 통과.
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
