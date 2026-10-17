---
name: e2e
description: Android 에뮬레이터에서 실제 앱을 띄워 페이즈 계획의 E2E 시나리오를 확인한다. 에뮬레이터가 없으면 설치를 묻고 준비한다. /phase 의 자동 검증 단계가 마지막에 부르며, 사용자가 직접 실행해도 된다.
argument-hint: "[페이즈 번호]"
---

# e2e

> 단위·위젯 테스트는 GPS, 기기 DB, 알림, 이미지 로딩을 가짜로 바꿔 돈다. 이 스킬은 에뮬레이터에서 실제 플러그인이 맞물려 도는지 사람 대신 눈으로 확인한다. 모든 출력은 한국어로 짧게 쓴다.

## 규칙

- macOS·Windows 공통으로 동작한다. 셸은 bash(Windows 는 Git Bash)를 쓴다.
- 설치는 사용자 확인 뒤에만 한다. 다운로드 크기를 함께 알린다.
- 앱 화면은 스크린샷으로 확인하고, 시나리오 결과를 판단한 근거 스크린샷을 남긴다.
- 실패해도 코드를 고치지 않는다. 결과만 보고한다. 고치는 일은 호출한 쪽(`/phase`)이 한다.
- 이 스킬이 띄운 에뮬레이터만 끝에 끈다. 이미 실행 중이던 에뮬레이터는 그대로 둔다.

## 인자

`$ARGUMENTS` 의 숫자가 페이즈 번호다. 없으면 `docs/roadmap.md` "현재 위치" 의 페이즈.

## 1. 시나리오 읽기

`docs/plans/phase-<번호>.md` 의 "완료 기준" 에서 에뮬레이터가 필요한 항목(에뮬레이터·가상 러닝·E2E 가 들어간 항목)을 시나리오로 쓴다. 해당 항목이 없으면 "E2E 시나리오 없음" 을 알리고 끝낸다.

## 2. 도구 찾기

- **SDK 위치**: `ANDROID_HOME` → `ANDROID_SDK_ROOT` → macOS `~/Library/Android/sdk`, Windows `$LOCALAPPDATA/Android/Sdk` 순서로 찾는다.
- **도구 경로** (Windows 는 `.exe`·`.bat` 를 붙인다)
  - `adb`: `<SDK>/platform-tools/adb`
  - `emulator`: `<SDK>/emulator/emulator`
  - `sdkmanager`·`avdmanager`: `<SDK>/cmdline-tools/latest/bin/`
- **JDK**: sdkmanager·avdmanager 는 `JAVA_HOME` 이 필요하다. 비어 있으면 `fvm flutter doctor -v` 의 Java 경로를 쓴다.
- **CPU 종류**: macOS Apple Silicon(`uname -m` 이 `arm64`) 은 `arm64-v8a`, 그 밖에는 `x86_64`.

## 3. 에뮬레이터 확인

1. `adb devices` 에 `emulator-` 로 시작하는 기기가 `device` 상태면 그것을 쓴다(이미 실행 중). 4번으로 간다.
2. 준비 상태를 확인한다.
   - emulator 패키지: `<SDK>/emulator/emulator` 파일
   - 시스템 이미지: `<SDK>/system-images/android-37.0/google_apis/<CPU>/` 폴더
   - AVD: `emulator -list-avds` 에 `runmagochi` 가 있는지
   - 가속: `emulator -accel-check` 결과
3. 모두 있으면 4번으로 간다.
4. 빠진 것이 있으면 `AskUserQuestion` 으로 설치를 묻는다.
   - 빠진 항목과 대략 크기를 보여준다: emulator 약 0.5GB, 시스템 이미지 약 1.5GB(압축 해제 후 약 6GB).
   - 선택지: "설치 (추천)" / "건너뛰기". 건너뛰면 시나리오를 모두 "건너뜀(에뮬레이터 없음)" 으로 보고하고 끝낸다.
5. 설치
   - `sdkmanager --install "emulator" "system-images;android-37.0;google_apis;<CPU>"`
     - 새 sdkmanager 는 `/` 형식(`system-images/android-37.0/google_apis/<CPU>`)도 받는다. 하나가 "not found" 면 다른 형식으로 다시 시도한다.
     - PowerShell 에서는 `;` 가 명령 구분자라 패키지 이름이 잘린다. bash 에서 따옴표로 감싸 실행한다.
   - 라이선스: `yes | sdkmanager --licenses`
   - AVD: `echo no | avdmanager create avd -n runmagochi -k "system-images;android-37.0;google_apis;<CPU>" -d pixel_7`
6. 가속이 안 되면(`-accel-check` 실패) 멈추고 OS별 안내를 보여준다.
   - Windows: "Windows 하이퍼바이저 플랫폼" 기능 켜기(관리자 권한 필요, 재부팅)
   - macOS: 별도 설치 없음. Intel Mac 은 Hypervisor.framework 지원 여부 확인

## 4. 에뮬레이터 실행

1. 실행 중이 아니면 백그라운드로 띄운다: `emulator -avd runmagochi -no-snapshot-save -no-boot-anim -gpu auto`
2. 부팅을 기다린다: `adb wait-for-device` 뒤 `adb shell getprop sys.boot_completed` 가 `1` 이 될 때까지 확인(최대 5분).
3. 위치를 켠다: `adb shell cmd location set-location-enabled true`. 정확한 위치를 위해 `adb shell settings put secure location_mode 3` 도 실행한다.

## 5. 앱 설치

1. `fvm flutter build apk --debug`
2. `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
3. 권한을 미리 준다(실패해도 계속한다).
   - `adb shell pm grant com.dhkim1522.runmagochi android.permission.ACCESS_FINE_LOCATION`
   - `adb shell pm grant com.dhkim1522.runmagochi android.permission.ACCESS_COARSE_LOCATION`
   - `adb shell pm grant com.dhkim1522.runmagochi android.permission.POST_NOTIFICATIONS`
4. 실행: `adb shell monkey -p com.dhkim1522.runmagochi -c android.intent.category.LAUNCHER 1`

## 6. 시나리오 진행

화면 조작은 아래 방법으로 한다.

- **화면 보기**: `adb exec-out screencap -p > <작업 폴더>/<순번>-<설명>.png` 후 Read 로 이미지를 본다. 작업 폴더는 세션 임시 폴더(scratchpad)에 `e2e-phase<번호>/` 로 만든다.
- **요소 찾기**: `adb shell uiautomator dump /sdcard/ui.xml && adb exec-out cat /sdcard/ui.xml` 에서 문구(`text`·`content-desc`)의 `bounds` 를 찾아 가운데 좌표를 쓴다. Flutter 위젯 문구는 접근성 정보로 나온다.
- **탭**: `adb shell input tap <x> <y>`
- **길게 누르기**(예: 종료 버튼): `adb shell input swipe <x> <y> <x> <y> 2000`
- **가상 러닝**: `fvm dart run tool/fake_run.dart --minutes <분> --speed <m/s> --adb <adb 경로>` 를 백그라운드로 돌린다. 앱에서 시작 버튼을 누르고 카운트다운이 끝난 뒤 시작한다.
- **시스템 창**(권한·배터리 안내 등)이 뜨면 허용하고 계속한다. 그 사실을 결과에 적는다.

시나리오마다 기대 결과를 스크린샷으로 확인하고 통과·실패를 정한다. 숫자가 있으면(거리, 경험치, 레벨) 화면 값과 기대 값을 함께 적는다.

## 7. 정리와 보고

1. 이 스킬이 띄운 에뮬레이터면 `adb emu kill` 로 끈다.
2. 결과를 표로 보여준다.

```
| 시나리오 | 결과 | 근거 |
| --- | --- | --- |
| <완료 기준 항목> | 통과 / 실패 / 건너뜀 | <스크린샷 경로, 화면 값> |
```

3. 실패가 있으면 재현 단계와 스크린샷 경로를 적는다.
4. 호출한 쪽이 `/phase` 면 이 표를 그대로 돌려준다. `/phase` 는 통과한 항목을 계획 파일에 체크하고, 실패는 4번(실행)으로 돌아가 고친다.
