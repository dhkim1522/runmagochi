# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 3 완성도(Android) 구현 완료, 사람 확인 대기** (`docs/plans/phase-3.md`)
  - 첫 실행(캐릭터 소개·이름·주간 목표 3~20km), 설정(체중·목표·이름·백업·라이선스), 백업 내보내기·가져오기(JSON, 전체 바꾸기, 결정 0015)
  - 러닝 삭제(경험치 무르기), 끝부분 잘라내기, 종료를 잊은 러닝 자동 종료(20분 무점·6시간), 경험치에서 뺀 빠른 구간 표시 (결정 0016)
  - 잔여 정리: 글자 22 토큰, 탭 키보드 포커스, 홈 로딩 점프, 다크 모드 캐릭터 윤곽
  - 알림 버그 수정: 기기 시간대가 `GMT` 같은 별칭이면 알림 초기화가 실패해 주간 알림·자동 종료 알림이 모두 안 나가던 문제
  - 테스트 542건, 분석 0, 디버그·릴리스 APK 성공, 에뮬레이터 E2E 통과(탭 키보드 이동은 실기기에서)
  - 경쟁 앱 재확인(`docs/research/market.md` 1.5): Android 에 GPS 러닝 + 펫 성장 앱은 여전히 없음
- **페이즈 1·2·2.5**: 구현 완료, 실기기 확인이 남아 있다.
- 로드맵: 3 → 4 보상 → 5 확장 → 6 디자인 완성 → 7 Android 출시 → 8 iOS 확장 (결정 0014)

## 다음 할 일

1. **실기기 확인** — Android 기기에 릴리스 APK(`fvm flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`) 설치. 서명 키를 만들려면 `docs/beta.md` 1번.
   - 페이즈 1: 실제 30분 러닝 3회 기록 누락 없음, 트랙 400m × 10바퀴 거리 오차 5% 이내, 화면 끄고 주머니에 넣은 채 기록 유지
   - 페이즈 2: 실제 러닝으로 경험치·레벨업 연출, 금요일 18:00 주간 목표 알림 도착
   - 페이즈 2.5: 글꼴 굵기, 다크 모드 캐릭터 윤곽(도토리 포함), 1px 손목 밴드
   - 페이즈 3: 첫 실행 흐름, 설정, 블루투스 키보드로 탭 이동, 종료를 잊었을 때 자동 종료·알림, 다른 Android 기기로 백업 복원
2. **지인 베타** — `docs/beta.md` 의 안내문·질문으로 배포하고 의견을 모은다("아바타 때문에 다시 달리고 싶은지" 포함).
3. 결과는 `/phase 1`, `/phase 2`, `/phase 2.5`, `/phase 3` 로 입력한다. 모두 통과하면 `/phase 4` (보상).

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
