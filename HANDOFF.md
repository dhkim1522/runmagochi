# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 4 보상 구현 완료, 사람 확인 대기** (`docs/plans/phase-4.md`, 결정 0019·0020·0021)
  - 러닝 알림(F20): 거리·시간·목표 진행 실시간 표시, 일시정지·재개 버튼
  - 자동 일시정지·재개(F4), 자동 일시정지 5분·사용자 일시정지 1시간 뒤 30초 예고 종료
  - 코인(F9): 거리 코인 + 목표 달성 코인, 요약 코인 줄, 홈 코인 칩, 코인 내역(DB v5, 백업 v5)
  - 상점·꾸미기(F10·F11): 모자·소품 6종 구매·장착·벗기, 하단 탭 4개
  - 테스트 672건, 분석 0, 디버그 APK 성공, 에뮬레이터 E2E 통과(빠른 이동 자동 종료만 에뮬레이터 한계)
  - 스크린샷 `design/mockups/phase-4-screens/`, 아이템 미리보기 `design/character/items.png`
- **페이즈 3.5 오늘 목표와 보상 규칙 완료** (`docs/plans/phase-3.5.md`, 결정 0018). 빠른 이동 자동 종료 실기기 확인만 페이즈 7
- **페이즈 1~3**: 구현 완료, 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017)
- 로드맵: 4 보상 → 5 확장 → 6 디자인 완성(6-1 캐릭터, 6-2 UI) → 7 iOS 확장·실기기 확인 → 8 동시 출시

## 다음 할 일

1. **페이즈 4 사람 확인** (`docs/plans/phase-4.md` "사람 확인", "자동 결정")
   - 상점·코인 표시·아이템 그림 디자인 승인, 코인 색 하나로 정하기(요약·칩 파랑, 내역 초록)
   - 아이템 목록·가격 승인
   - 자동 결정 확인: 빠른 이동 중 자동 일시정지 안 함, 제자리 GPS 흔들림 기준은 페이즈 7 조정, 음수 잔액 허용, F11-2 분리
2. **로드맵 변경 결정 대기**: 페이즈 6 다음에 "산출물 정리" 페이즈를 넣고 iOS 확장·출시를 한 칸씩 미루는 안(PRD·시나리오·화면설계·디자인·아키텍처·ERD·시퀀스, API 명세 제외, 다음 프로젝트용 플레이북)
3. 확인 뒤 `/phase 4` 로 완료 판정, 이어서 `/phase 5`

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
