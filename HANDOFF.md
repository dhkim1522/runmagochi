# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 2.5 기본 디자인 구현 완료, 사람 확인 대기** (`docs/plans/phase-2.5.md`)
  - 디자인 시스템 "말랑 클레이"(`docs/design/`), 화면 시안(`design/mockups/`), 앱 6개 화면·권한·탭바 적용, 번들 글꼴(Jua·Noto Sans KR)
  - 캐릭터 3종(병아리·젤리·도토리) 무작위 고정, 펫 러너(단계마다 러닝 장비), 실제 도트 스프라이트(`design/character/`)
  - 테스트 337건, 분석 0, 디버그 APK 성공, 에뮬레이터 E2E 통과(다크 모드 포함)
- **페이즈 1·2**: 구현 완료, 실기기 확인이 남아 있다.
- 시장조사(`docs/research/market.md`)와 결정 0010~0013(디자인 2단계, 캐릭터 무작위 고정, 러닝 중심 포지션, 펫 러너)을 반영했다. 로드맵은 1 → 2 → 2.5 → 3 → 4 → 5 → 6 디자인 완성 → 7 출시.

## 다음 할 일

1. **실기기 확인** — Android 기기에 `fvm flutter build apk --debug` 의 `build/app/outputs/flutter-apk/app-debug.apk` 설치
   - 페이즈 1: 실제 30분 러닝 3회 기록 누락 없음, 트랙 400m × 10바퀴 거리 오차 5% 이내, 화면 끄고 주머니에 넣은 채 기록 유지, "실측 때 함께 볼 것" 3가지
   - 페이즈 2: 실제 러닝 1회로 경험치 획득부터 레벨업 연출까지, 금요일 18:00 주간 목표 알림 도착
   - 페이즈 2.5: 최종 모습(글꼴 굵기, 다크 모드에서 짙은 색 캐릭터 윤곽, 1px 손목 밴드가 보이는지)
2. 지인 베타에서 아바타 때문에 다시 달리고 싶은지 의견을 모은다.
3. 확인을 마치면 `/phase 1`, `/phase 2`, `/phase 2.5` 로 결과를 입력한다. 통과하면 페이즈 3(완성도·iOS). 페이즈 3 착수 전에 경쟁 앱을 다시 확인한다(결정 0012).

## 환경 메모

- **Flutter 버전은 `.fvmrc`(3.47.7)로 고정한다** (결정 0008). 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
  - 회사 Mac에서 할 일: `dart pub global activate fvm`(또는 `brew install fvm`) → 저장소에서 `fvm install` → `fvm flutter test` 통과 확인. Mac 에서 바뀐 `pubspec.lock` 이 있으면 커밋한다.
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
