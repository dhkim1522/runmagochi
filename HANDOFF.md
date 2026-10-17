# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 2 아바타 성장 구현 완료, 사람 확인 대기** (작업 11개 중 10개)
  - 경험치·레벨·외형 4단계·표정, 홈 주간 목표 막대(탭해서 수정)·연속 달성 주수, 러닝 중 걷기·달리기 아바타, 요약 화면 경험치·레벨업 연출, 아바타 탭, 금요일 18:00 주간 목표 알림
  - 테스트 230건 통과, 분석 경고 0, 디버그 APK 빌드 성공
  - 스프라이트는 같은 규격(32×32)의 임시 그림이다. 페이즈 2.5 에서 코드로 그린 도트로 바꾼다
  - 진행 상태와 구현 중 결정은 `docs/plans/phase-2.md`
- **페이즈 1 기록 코어**: 구현 완료, 실기기 실측이 아직 남아 있다(`docs/plans/phase-1.md`).
- 전체 UI 디자인은 와이어프레임 수준이다(페이즈 3).

## 다음 할 일

1. **실기기 확인** — Android 기기에 APK 설치: `fvm flutter build apk --debug` 후 `build/app/outputs/flutter-apk/app-debug.apk`
   - 페이즈 1 (`docs/plans/phase-1.md` "사람 확인"): 실제 30분 러닝 3회 기록 누락 없음, 트랙 400m × 10바퀴 거리 오차 5% 이내, 화면 끄고 주머니에 넣은 채 기록 유지, "실측 때 함께 볼 것" 3가지
   - 페이즈 2 (`docs/plans/phase-2.md` "사람 확인"): 실제 러닝 1회로 경험치 획득부터 레벨업 연출까지(레벨 1에서 5km 이상이면 레벨업), 금요일 18:00 주간 목표 알림 도착
   - 에뮬레이터 E2E(`/e2e 2`)는 집 Windows 에서 5개 모두 통과(2026-10-17). 이 PC에 에뮬레이터·AVD `runmagochi` 설치됨. E2E 에서 찾은 위치 복구 버그·경험치 반올림·목표 변경 레벨업 알림은 고쳤다
2. **페이즈 2.5 기본 디자인** (`docs/roadmap.md`, 결정 0010): `/phase 2.5` 로 시작한다. 무료 수단만 쓴다
   - Claude Design System·Design 캔버스로 디자인 시스템과 화면 6개 시안 → 승인 → Flutter 적용
   - 캐릭터는 Claude 가 코드로 도트를 찍어 콘셉트 2~3안 → 고른 안으로 4단계·표정·동작(페이즈 2 작업 11 대체)
   - 출시 수준 다듬기(캐릭터·배경·아이템·아이콘, 유료 수단 검토)는 페이즈 6 디자인 완성에서 한다
3. 지인 베타에서 아바타 때문에 다시 달리고 싶은지 의견을 모은다(디자인 적용 뒤).
4. 확인을 마치면 `/phase 1`, `/phase 2` 로 결과를 입력한다.

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
