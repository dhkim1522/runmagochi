# 화면설계서 촬영 도구

`design/screens/` 컷을 다시 찍을 때 쓰는 스크립트. 2026-10-24 페이즈 8 작업 3 에서 만들었다. 앱 코드(`lib/`)는 건드리지 않는다.

| 파일 | 하는 일 |
| --- | --- |
| `cap`, `cap.py` | Android 에뮬레이터 조작·촬영: `shot`(저장), `tap`(화면 글자로 누르기), `swipe`, `hold`(길게 누르기), `long`(끌어내리며 찍어 이어 붙임), `importdemo`(설정 › 가져오기), `crop`, `web` |
| `demo_mode.sh` | 상태 표시줄을 9:41·와이파이·배터리만 남김. `demo_mode.sh off` 로 해제. 알림창을 열었다 닫은 뒤에는 다시 실행 |
| `make_demo_backups.py` | 예시 백업(`demo-base.json`: 러닝 33회, Lv.9, 코인 315, 배지 9)을 병아리·젤리·도토리 3개로 만든다 |
| `ring_run.py` | 에뮬레이터 가상 GPS 로 고리 경로를 1초마다 보냄. 속도 변화·멈춤·탈것 흉내·신호 끊김 옵션 |
| `vm_ui.dart` | iOS 시뮬레이터 앱에 Dart VM 서비스로 탭·길게 누르기·끌기를 넣음(`flutter run --debug` 로 띄운 앱) |
| `make_web.py` | `design/screens/*.png` → `web/` 390px 사본과 무대 조각 |

## 준비

```
python3 -m venv .venv && .venv/bin/pip install pillow numpy   # 저장소 .venv (fonttools 와 같이 씀)
fvm flutter build apk --release                                # 릴리스(DEBUG 띠 없음)
adb install -r build/app/outputs/flutter-apk/app-release.apk
tool/capture/demo_mode.sh
python3 tool/capture/make_demo_backups.py /tmp && adb push /tmp/demo-*.json /sdcard/Download/
```

## 순서 요약

1. 새로 설치(`pm clear`)한 상태에서 첫 실행·권한 컷(01~05b, 10, 07), 설정 › 가져오기로 예시 데이터를 넣고 홈·목표 시트·기록·아바타·업적·상점·설정 컷.
2. `ring_run.py` 로 러닝(메모: `--stop-at` 자동 일시정지, `--burst-*` 탈것 의심, `--silent-after` 신호 끊김)을 돌리며 `cap shot`, 알림창 컷은 `cmd statusbar expand-notifications` 뒤 `cap shot` → `cap crop`.
3. 긴 화면은 `cap long 이름 --footer N`(고정 버튼·탭바 높이). 다크는 설정 › 다크 로 바꿔 같은 컷.
4. 종료 예고 알림(39)은 릴리스가 자동 종료 기준을 못 줄이므로 `--dart-define=RUN_STILL_END_SEC=40 --dart-define=RUN_END_WARNING_SEC=30` 디버그 빌드로.
5. iPhone: `flutter build ios --simulator --debug` → `simctl install` → 앱 폴더(`simctl get_app_container … data`)의 `Documents/runmagochi.sqlite` 에 Android 앱 DB 를 복사 → `flutter run -d <기기> --debug` 로 띄워 VM 서비스 주소를 얻고 `dart tool/capture/vm_ui.dart <주소> banner|tap|hold|swipe` + `simctl io screenshot`. 위치는 `simctl location start --speed=4 <위도,경도 …>`.
6. `make_web.py` 로 사본을 만들고 `design/screens/index.html` 의 컷 설명 숫자를 맞춘다.

## 알려진 한계

- 종료 예고 39d·39e 는 이번에 다시 찍지 못해 10-23 컷을 그대로 둠(작은 아이콘은 반영된 뒤 촬영).
- 앱 DB 컬럼은 snake_case(`hat_item_id`)다. 시스템 알림창 안내 문구는 기기 언어(영어)로 나온다.
