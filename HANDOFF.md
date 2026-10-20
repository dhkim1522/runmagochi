# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 3 완성도(Android) 구현 완료** (`docs/plans/phase-3.md`)
  - 첫 실행(캐릭터 소개·이름·주간 목표 3~20km), 설정(체중·목표·이름·백업·라이선스), 백업 내보내기·가져오기(JSON, 전체 바꾸기, 결정 0015)
  - 러닝 삭제(경험치 무르기), 끝부분 잘라내기, 종료를 잊은 러닝 자동 종료(20분 무점·6시간), 경험치에서 뺀 빠른 구간 표시 (결정 0016)
  - 테스트 542건, 분석 0, 디버그·릴리스 APK 성공, 에뮬레이터 E2E 통과
- **페이즈 1~3 실기기 확인과 지인 베타는 페이즈 7 에서 한다** (결정 0017)
- 로드맵: 4 보상 → 5 확장 → 6 디자인 완성 → 7 iOS 확장·실기기 확인 → 8 Android·iOS 동시 출시 (결정 0017)

## 다음 할 일

1. **`/phase 4` (보상)**: 코인 지급·내역, 상점, 꾸미기, 부위별 아이템 스프라이트. 완료 기준은 러닝 1회로 코인 수령부터 구매·장착까지.
2. 페이즈 5·6 도 Android 기준으로 진행한다. 새 패키지는 iOS 도 지원하는 것만 쓴다.
3. 페이즈 7 에서 할 실기기 확인 항목은 각 `docs/plans/phase-*.md` 의 "사람 확인" 에 모여 있다.
   - Android: 릴리스 APK(`fvm flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`), 서명 키는 `docs/beta.md` 1번
   - iPhone: 무료 Apple ID 로 Xcode 에서 본인 iPhone 에 직접 설치. 7일마다 다시 설치한다

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac: `brew install fvm`(4.3.2) → `fvm install` 완료, `fvm flutter test` 542건 통과(2026-10-20).
  - 회사 Mac 에 Xcode 가 없다. 페이즈 7 전에 App Store 에서 설치한다(Apple ID 로그인 필요).
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
