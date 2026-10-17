# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 1 기록 코어 구현 완료, 실측 대기**
  - 러닝 시작·일시정지·종료, 화면 꺼짐 기록, 강제 종료 후 복구, 요약·기록 화면, 권한·배터리 안내
  - 테스트 151건 통과, 에뮬레이터에서 화면 꺼짐 기록(거리 오차 -1.7%)과 복구 확인
  - 진행 상태와 구현 중 결정은 `docs/plans/phase-1.md`
- 디자인은 와이어프레임 수준이다. 아바타 자리는 비어 있다(페이즈 2).

## 다음 할 일

1. **실기기 실측** (`docs/plans/phase-1.md` "사람 확인")
   - Android 기기에 APK 설치: `flutter build apk --debug` 후 `build/app/outputs/flutter-apk/app-debug.apk`
   - 실제 30분 러닝 3회, 기록 누락 없는지
   - 트랙 400m × 10바퀴 거리 오차 5% 이내인지
   - 화면 끄고 주머니에 넣은 채 기록이 이어지는지
   - "실측 때 함께 볼 것" 3가지도 확인
2. 실측을 마치면 `/phase` 를 실행해 결과를 입력한다. 통과하면 페이즈 2(아바타 성장)로 넘어간다.
   - 실측 전에 페이즈 2를 먼저 하려면 `/phase 2`

## 환경 메모

- 회사 Mac: `~/personal/` 아래에서 git·gh 가 개인 계정(dhkim1522)으로 자동 전환된다.
- 집 Windows
  - Claude Code 개인 계정 로그인, 개인 SSH 키를 GitHub에 등록한 뒤 이 저장소를 clone한다. 저장소 안에서 `git config user.email dhkim1522@naver.com` 을 설정한다.
  - Flutter SDK와 Android SDK platform 37 이 필요하다. 첫 실행 때 `/kickoff`.
- 상태 표시줄은 Mac·Windows 공용 설정 하나로 동작한다. Windows 는 Git for Windows 만 있으면 되고 `jq` 나 `settings.local.json` 은 필요 없다.
- 에뮬레이터 가상 러닝: `dart run tool/fake_run.dart --minutes 5`. 에뮬레이터 위치 설정에서 "Location Accuracy" 를 켜야 위치가 들어온다.
