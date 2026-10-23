# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 7 완료** (`docs/plans/phase-7.md`, 작업 1~5, 자동 확인 통과). 실기기 사람 확인은 **페이즈 9 실기기 테스트와 개선**으로 분리(결정 0035). 순서 7 → 8 산출물 정리 → 9 실기기 테스트·개선 → 10 출시(1.0). 다음은 `/phase 8`(계획부터). 실측 안내 `docs/field-test.md`. Android 실기기는 가족 폰을 빌려 로드맵 기준 그대로 실측(사용자 결정 2026-10-23)
  - 작업 1: 탈것 의심 뒤 위치 끄기 결함은 재현 안 됨(회귀 테스트만 추가). 작업 4: 버전 0.4.0+4, 베타 안내문 갱신. **회사 Mac 에 릴리스 서명 키가 없어** 지인 베타 APK 는 집 PC 에서 빌드(`docs/beta.md`)
  - iPhone 설치: 2026-10-23 최신 main 릴리스 설치(임시 worktree `~/personal/runmagochi-merge-check` 를 main 에 맞춤). 무료 서명 만료 약 10-30, 재설치는 `docs/ios.md`
- **페이즈 6 완료** (관문 3 승인 2026-10-23, 화면설계서 7판. `docs/plans/phase-6.md` 작업 1~32, 상태 `완료`). 다음은 페이즈 7
  - 작업 32(단계별 몸집 폭 고정, 결정 0034, 관문 3 이후 의견): 단계가 오를수록 가로로 두꺼워져 살찌는 느낌이라 2단계 이후 몸 폭을 고정하고 키·외관·장비로 성장. 몸 폭 1~4단계 병아리 14·16·18·18, 젤리 16·18·18·18, 도토리 모자 16·18·18·18, 키 2~4단계 19·20·21, 3·4단계 폭÷키 0.90·0.86. 비교 페이지 https://claude.ai/artifact/MSpfvYySwKaH7YXt3AuHiG 3판(`design/mockups/phase-6/growth-compare.html`). 아이템 그림·기준점·모자 폭 24칸 그대로라 모자가 3·4단계 머리보다 양옆 3칸씩 크다. 에셋 카탈로그 아티팩트는 새 그림으로 갱신(3판), 화면설계서 캐릭터 그림은 옛 모양(아이템 에셋 검토 때 다시 찍음)
  - 관문 1 A 말랑 클레이, 관문 2 c · 캔버스(연두, 사각 무대, 결정 0029). 작업 1~19 완료, 자동 확인·E2E 6개 통과, 최종 리뷰 Ready with minors(수정 b9ce74e~4e4a7b2, 테스트 1231 통과)
  - 산출물 아티팩트: 화면설계서 https://claude.ai/artifact/456dWcNyLn1vbUsjV9FLVc (원본 `design/screens/`), 디자인 시스템 https://claude.ai/artifact/FPihTBfX2CJserHVwUQ514 , 에셋 카탈로그 https://claude.ai/artifact/ECbG2Fh4TXQwcr5fNUWCXA , UI 비교 https://claude.ai/artifact/F5MsvhPE9fAXw5YtCwe3Xc
  - 작업 29(관문 3 결정 3건): 경로 범례 보라 제거(연두 한 계열 3단, `천천히`·`보통`·`빠르게`·`빠른 이동 · 제외`), 라이트 스플래시 타일 `primary-edge` 테두리, 안드로이드 알림 작은 아이콘 `ic_stat_chick`(병아리 실루엣). 화면설계서는 6판(2026-10-23)으로 경로 화면(16·17·18·19·25·43)과 알림(36·38·39b~39e)을 다시 찍어 갱신, 디자인 시스템 아티팩트 13판. 알림 37(목표 달성)·39(종료 예고)와 iOS 52 는 이전 컷이라 이전 아이콘·옛 경로색 그대로
  - 작업 30(라이트 경로색 단계 구분): 라이트 보통·빠름이 둘 다 어두운 초록이라 구분이 약해 `#659325`(연두)·`#066B0E`(초록)·`#003647`(청록)으로 교체, 다크 값 그대로. 색각 이상 포함 서로 CIEDE2000 15.6 이상, 빠름은 ink 와도 20.5(색각 13.3). 화면설계서 7판(경로 화면 16 긴 화면·19·25 만 다시 찍음, 이 촬영으로 앱 기록에 3.04km·2.20km 러닝이 늘었다), 디자인 시스템 아티팩트 14판
  - 작업 31(버튼 진한 테두리 제거, 관문 3 이후 의견, 비교 C 안 https://claude.ai/artifact/Cpm6JZRHtx4z1sqzL2x12p): 연두 버튼·선택 칩의 `primary-edge` 2px, 흰 보조 버튼 `line-strong` 2px 를 없애고 `elevation-float`(라이트 `0 3 8 -3 ink14%`+`0 1 2 ink8%`, 다크 `0 2 4 -1 #000 20%`)로 띄움. 선택 칩은 체크 아이콘 추가, 보조 버튼(길게 눌러 종료 포함)은 `line` 1px 머리카락 선. `primary-edge` 는 고른 카드 윤곽·경로 시작 점·스플래시 타일에만 남음. 디자인 시스템 아티팩트 15판. 화면설계서는 옛 테두리 그대로(재촬영은 사용자 결정 대기)
  - 디자인 시스템 아티팩트 16판(개요 정리): README 를 색·글꼴·간격·모서리·그림자 요약 한 화면 반으로 줄이고, 페이지가 `# 제목`을 세리프(`--cds-font-voice`)로 그려 궁서체처럼 보이던 제목 줄을 뺌. 자세한 규칙 원천은 `docs/design/design-system.md`
  - 관문 3 고칠 점 반영: 화면 모드 설정, 목표 한 줄+시트, 다크 얇은 테두리, 공원 길 배경, 어뷰징·위치 처리(결정 0033), E2E 로 찾은 결함 8개 수정
  - iOS: 회사 Mac(Xcode 16.4)으로 iPhone 16 Pro(iOS 27.0.1)에 릴리스 설치. 무료 서명이라 10-29 무렵 재설치(`docs/ios.md`). 서명 팀은 저장소에 커밋하지 않는다. 임시 작업 폴더 `~/personal/runmagochi-merge-check`(서명 팀 넣은 pbxproj, 재설치용)
  - 확장 백로그에 로그인·서버(F22, 결정 0032)
- **페이즈 5 확장 완료**. 아이폰 음성 안내 확인만 페이즈 7
- **페이즈 1~4 완료**. 실기기 확인은 페이즈 7 에서 Android·iPhone 함께(결정 0017·0026)
- 로드맵: 6 디자인 완성 → 7 iOS 확장·본인 iPhone 실기기 확인 → 8 산출물 정리 → 9 출시(써 본 뒤 결정) (결정 0026)

## 다음 할 일

0. **페이즈 9 실측**(산출물 정리 뒤): `docs/field-test.md` 대로 iPhone 30분 러닝 3회·확인 항목, 가족 폰 Android 실측, 집 PC 에서 릴리스 서명 베타 APK 빌드·지인 배포. 결과는 `docs/plans/phase-7.md` 에 옮긴다. 아래 1번은 이 작업에 포함
1. **페이즈 7 시작** (`/phase 7`): iOS 확장·본인 iPhone 실기기 확인. Android 기준 결정 필요. `distanceFilter 0` 배터리, 첫 구독 위치 켜기 창 확인 포함
2. **아이템 에셋 현재 그림으로 확정**(사용자 결정 2026-10-23, 페이즈 7 먼저). 알려진 아쉬움은 출시 전(페이즈 9~10)에 다시 본다: 모자 3종이 버섯·우산처럼 넓고(캡·비니 모양 차이 작음, 새 몸집보다 양옆 3칸 큼), 선글라스 단조, 헤드폰 빨강 튐, 꽃 핀과 머리 장식 겹침. 상점이 늘 아이템 하나를 미리 입혀 맨 캐릭터를 못 봄. 다시 할 때는 Claude Design 캔버스(https://claude.ai/artifact/FxKS7MR2twYmmE3k6SzNhe)에서
3. 화면설계서 잔여 정리: 캐릭터 그림이 작업 32 이전 모양(넓은 2~4단계). 알림 37(목표 달성)·39(종료 예고)는 옛 아이콘, iOS 52 는 옛 경로색 (재촬영) + 작업 31(버튼 진한 테두리 제거) 반영 전체 재촬영. 사용자 결정(2026-10-23): 문서가 앞으로도 고쳐질 것이라 아이템 에셋 검토 때 한꺼번에 다시 찍는다. 그때까지 설계서 버튼은 옛 테두리 모양
4. 앱 결함 후보(미확인): 탈것 의심 뒤 위치를 끄면 GPS 꺼짐 카드 대신 신호 끊김 말풍선이 뜸
5. iPhone 재설치: 사용자가 기기를 다시 연결하면 최신 main 빌드로(`docs/ios.md`, 임시 worktree `~/personal/runmagochi-merge-check`). 무료 서명 만료 10-29 무렵
6. 확장 백로그: F23 라이브 액티비티, F24 땀·숨 동작, F25 배경 아이템·날씨, 워치(F15 앞당김 결정 필요), 걸음 센서 탈것 구별. 정리 후보: 임시 worktree, 잠긴 agent worktree `.claude/worktrees/agent-aeb6a8b960c270fef`

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
