# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 6 관문 3 고칠 점 대기** (`docs/plans/phase-6.md` 작업 20~29 완료, 상태 `실행`)
  - 관문 1 A 말랑 클레이, 관문 2 c · 캔버스(연두, 사각 무대, 결정 0029). 작업 1~19 완료, 자동 확인·E2E 6개 통과, 최종 리뷰 Ready with minors(수정 b9ce74e~4e4a7b2, 테스트 1231 통과)
  - 산출물 아티팩트: 화면설계서 https://claude.ai/artifact/456dWcNyLn1vbUsjV9FLVc (원본 `design/screens/`), 디자인 시스템 https://claude.ai/artifact/FPihTBfX2CJserHVwUQ514 , 에셋 카탈로그 https://claude.ai/artifact/ECbG2Fh4TXQwcr5fNUWCXA , UI 비교 https://claude.ai/artifact/F5MsvhPE9fAXw5YtCwe3Xc
  - 작업 29(관문 3 결정 3건): 경로 범례 보라 제거(연두 한 계열 3단, `천천히`·`보통`·`빠르게`·`빠른 이동 · 제외`), 라이트 스플래시 타일 `primary-edge` 테두리, 안드로이드 알림 작은 아이콘 `ic_stat_chick`(병아리 실루엣). 화면설계서 스크린샷은 사용자가 다시 찍는다
  - 관문 3 고칠 점 반영: 화면 모드 설정, 목표 한 줄+시트, 다크 얇은 테두리, 공원 길 배경, 어뷰징·위치 처리(결정 0033), E2E 로 찾은 결함 8개 수정
  - iOS: 회사 Mac(Xcode 16.4)으로 iPhone 16 Pro(iOS 27.0.1)에 릴리스 설치. 무료 서명이라 10-29 무렵 재설치(`docs/ios.md`). 서명 팀은 저장소에 커밋하지 않는다. 임시 작업 폴더 `~/personal/runmagochi-merge-check`(서명 팀 넣은 pbxproj, 재설치용)
  - 확장 백로그에 로그인·서버(F22, 결정 0032)
- **페이즈 5 확장 완료**. 아이폰 음성 안내 확인만 페이즈 7
- **페이즈 1~4 완료**. 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017·0026)
- 로드맵: 6 디자인 완성 → 7 iOS 확장·본인 iPhone 실기기 확인 → 8 산출물 정리 → 9 출시(써 본 뒤 결정) (결정 0026)

## 다음 할 일

1. **관문 3 다시** (작업 20~29 완료, 화면설계서 4판 https://claude.ai/artifact/456dWcNyLn1vbUsjV9FLVc). 사용자가 승인하면 `/phase 6` 이 완료 판정
2. 판단 남은 것: 1단계 알 모자, 첫 실행 1쪽 빈 하늘, 스프라이트 움직임 줄이기, **아이템 에셋 검토(사용자: 아직 예쁘지 않음, Claude Design 캔버스에서 별도)**
3. 앱 결함 후보(미확인): 러닝 끝부분(탈것 의심 뒤)에 위치를 끄면 GPS 꺼짐 카드 대신 신호 끊김 말풍선이 뜸, 상점은 늘 아이템 하나를 미리보기로 입혀 맨 캐릭터를 못 봄
4. iPhone 재설치: 사용자가 기기를 다시 연결하면 최신 main 빌드로(`docs/ios.md`, 임시 worktree `~/personal/runmagochi-merge-check`). 무료 서명 만료 10-29 무렵
5. 확장 백로그: F23 라이브 액티비티, F24 땀·숨 동작, F25 배경 아이템·날씨, 워치(F15 앞당김 결정 필요), 걸음 센서 탈것 구별. 실기기 확인은 페이즈 7

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac: `brew install fvm`(4.3.2) → `fvm install` 완료, `fvm flutter test` 통과.
  - 회사 Mac: Xcode 16.4·CocoaPods 1.17.0 설치함(2026-10-22). iOS 시뮬레이터 iPhone 16 Pro(iOS 18.6).
  - 회사 Mac: Android 37 이미지는 없고 android-36 이미지로 `runmagochi` AVD 를 만들었다. API 36 은 `am start -n com.dhkim1522.runmagochi/.MainActivity` 로 실행한다. JAVA_HOME 은 Android Studio 의 jbr. 에뮬레이터는 시속 30km 이상 가상 점을 위치 서비스가 걸러 빠른 이동 확인이 안 된다.
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
