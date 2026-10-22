# iOS 빌드와 iPhone 설치

iOS 는 Mac 에서만 빌드한다. 무료 Apple ID 로 본인 iPhone 에 직접 설치해 쓴다 (결정 0030). App Store·TestFlight 는 유료 개발자 계정이 필요해 페이즈 9 에서 정한다.

## 준비물

- Mac: Xcode 16.4, CocoaPods(Homebrew), FVM 의 Flutter 3.47.7
- Xcode 의 iOS 플랫폼 구성요소. 없으면 빌드가 "iOS 18.5 is not installed" 로 멈춘다. 한 번만 받는다(약 9GB).

  ```
  xcodebuild -downloadPlatform iOS
  ```

- iPhone 과 USB 케이블, Apple ID(무료)

## 빌드 확인

```
fvm flutter pub get
fvm flutter build ios --no-codesign --debug
fvm flutter build ios --no-codesign --release
```

서명 없이 빌드만 되는지 본다. 기기에 올리려면 아래 서명 설정이 필요하다.

시뮬레이터는 서명 없이 띄울 수 있다(위 `-downloadPlatform` 이 iOS 시뮬레이터도 받는다). 위치는 `xcrun simctl location <기기 id> set 37.5260,126.9240` 으로 준다.

```
open -a Simulator
fvm flutter run -d "iPhone 16 Pro"
```

## iPhone 에 설치하기 (무료 Apple ID)

1. **Apple ID 등록**: Xcode → Settings(⌘,) → Accounts → 왼쪽 아래 `+` → Apple ID 로 로그인한다. 목록에 `<이름> (Personal Team)` 이 생긴다.
2. **팀 고르기**: `open ios/Runner.xcworkspace` 로 연다(`.xcodeproj` 가 아니다). 왼쪽 Runner 프로젝트 → TARGETS 의 Runner → Signing & Capabilities 에서
   - `Automatically manage signing` 을 켠 채로 둔다.
   - Team 에서 `<이름> (Personal Team)` 을 고른다.
   - Bundle Identifier 는 `com.dhkim1522.runmagochi` 그대로 둔다. "is not available" 오류가 나면 다른 사람이 쓰는 이름이니 `com.dhkim1522.runmagochi.dev` 처럼 바꾼다.
   - 팀을 고르면 Xcode 가 `ios/Runner.xcodeproj/project.pbxproj` 에 `DEVELOPMENT_TEAM` 을 적는다. 팀 ID 는 비밀이 아니라 커밋해도 된다.
3. **iPhone 연결**: USB 로 연결하고 iPhone 에서 "이 컴퓨터를 신뢰" 를 누른다.
4. **개발자 모드 켜기**: iPhone 설정 → 개인정보 보호 및 보안 → 맨 아래 개발자 모드 → 켬 → 재시동 → 다시 켜진 뒤 뜨는 창에서 켜기. 메뉴가 안 보이면 Xcode 를 연 채로 iPhone 을 다시 꽂는다.
5. **기기 준비 기다리기**: Xcode → Window → Devices and Simulators 에서 iPhone 을 고르고 준비(Preparing)가 끝날 때까지 기다린다. 처음에는 몇 분 걸린다.
6. **설치·실행**: 저장소 폴더에서

   ```
   fvm flutter devices                 # iPhone 의 id 확인
   fvm flutter run --release -d <id>
   ```

   - `--release` 로 설치해야 Mac 과 연결을 끊고 홈 화면에서 앱을 열 수 있다. 디버그 빌드는 Mac 에서 실행할 때만 열린다.
   - Xcode 로 설치해도 된다. 위쪽 기기 목록에서 iPhone 을 고르고, Product → Scheme → Edit Scheme → Run → Build Configuration 을 Release 로 바꾼 뒤 Product → Run(⌘R).
7. **개발자 신뢰**: 처음 열 때 "신뢰하지 않는 개발자" 창이 뜨면 iPhone 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱의 `Apple Development: <Apple ID>` → 신뢰.
8. **권한**: 처음 러닝 시작 때 위치('앱을 사용하는 동안' 허용, 정확한 위치 켬)와 알림을 허용한다.

### 7일마다 다시 설치

- 무료 Apple ID 로 만든 설치본은 7일 뒤 열리지 않는다. 6번 명령으로 다시 설치하면 된다.
- 같은 Bundle Identifier 로 덮어 설치하므로 기록은 남는다. 앱을 지우면 기록이 사라지니, 지우기 전에 설정 → 백업으로 파일을 저장한다.
- 무료 계정은 기기당 직접 설치 앱 3개, 7일에 새 Bundle Identifier 10개까지다.

### 설치가 안 될 때

- **iPhone iOS 가 Xcode 보다 새 버전**: Xcode 16.4 는 iOS 18.5 SDK 다. 2026-10-22 에 연결된 iPhone 16 Pro 는 iOS 27.0.1 이다. Xcode 가 이 iPhone 을 실행 대상으로 보여 주기는 했지만, 서명·설치는 아직 해 보지 않았다. Xcode 가 기기를 준비하지 못하거나 "iOS 27.0 is not supported" 류 오류가 나면 Xcode 를 새로 올려야 하고, 새 Xcode 가 macOS 업데이트를 요구할 수 있다(결정 0030).
- **Xcode 앱에서 빌드하면 오류**: 먼저 `fvm flutter pub get` 또는 6번 명령을 한 번 실행해 `ios/Flutter/Generated.xcconfig` 와 `ios/Pods` 를 만든다.
- **위치 권한이 늘 거부로 나옴**: `ios/Podfile` 의 `PERMISSION_LOCATION_WHENINUSE=1` 이 있는지, `pubspec.yaml` 에서 Swift Package Manager 를 끈 설정이 남아 있는지 본다 (결정 0031).

## 설정한 것과 이유

| 항목 | 위치 | 값 | 이유 |
|---|---|---|---|
| 앱 이름 | `Info.plist` `CFBundleDisplayName` | 런마고치 | 홈 화면 이름 |
| Bundle Identifier | `project.pbxproj` | `com.dhkim1522.runmagochi` | Android `applicationId` 와 같게 |
| 서명 | `project.pbxproj` | Automatic, 팀 비움 | 사용자가 Xcode 에서 자기 팀을 고른다 |
| 지원 기기 | `TARGETED_DEVICE_FAMILY` | 1 (iPhone) | iPad 화면은 만들지 않는다. iPad 는 iPhone 호환 모드로 열려 공유 창 위치 지정이 필요 없다 |
| 최소 iOS | `Podfile`, `IPHONEOS_DEPLOYMENT_TARGET` | 15.0 | Flutter 3.47 최소값. file_picker 는 14 이상 |
| 의존성 관리 | `pubspec.yaml` `flutter.config` | Swift Package Manager 끔 → CocoaPods | permission_handler 권한 스위치를 Podfile 로 고정 (결정 0031) |
| 권한 스위치 | `Podfile` `GCC_PREPROCESSOR_DEFINITIONS` | `PERMISSION_LOCATION_WHENINUSE=1`, `PERMISSION_NOTIFICATIONS=1` | permission_handler 는 켠 권한만 코드에 넣고 나머지는 늘 거부로 답한다 |
| 위치 설명 | `NSLocationWhenInUseUsageDescription` | "러닝 경로와 거리를 기록하려고 위치를 사용해요. 위치는 이 기기에만 저장돼요." | 앱이 요청하는 권한 |
| 위치 설명(항상) | `NSLocationAlwaysAndWhenInUseUsageDescription` | "러닝 중 화면을 끄거나 다른 앱을 써도 경로와 거리를 이어서 기록하려고 위치를 사용해요. 위치는 이 기기에만 저장돼요." | 요청하지 않지만 geolocator 코드에 '항상' 요청이 있어 키가 필요하다 |
| 사진 추가 설명 | `NSPhotoLibraryAddUsageDescription` | "공유 창에서 러닝 카드를 사진 앱에 저장하려고 사진 추가 권한을 사용해요." | 공유 창의 "이미지 저장" 은 이 키가 없으면 앱이 죽는다 |
| 한국어 시스템 화면 | `CFBundleLocalizations` | `ko` | 공유 창·파일 선택 창 같은 시스템 화면을 한국어로 띄운다 |
| 백그라운드 모드 | `UIBackgroundModes` | `location`, `audio` | 화면을 꺼도 위치 기록과 음성 안내가 이어진다 |
| 위치 스트림 | `lib/run/data/geolocator_location_source.dart` | `AppleSettings`: 백그라운드 허용, 자동 멈춤 끔, 운동 유형, 상태 막대 위치 표시 | 기본 설정은 iOS 백그라운드 위치를 끈다. 자동 멈춤이 켜지면 쉬는 동안 멈춘 위치가 백그라운드에서 다시 켜지지 않는다 |
| 알림 연결 | `AppDelegate.swift` | `UNUserNotificationCenter` delegate, 버튼용 엔진 플러그인 등록 | flutter_local_notifications 설치 안내대로 |
| 러닝 알림 | `lib/run/data/run_progress_notifier.dart` | iOS 는 소리·배너 없이 알림 목록에만(passive), 버튼 묶음 | 3초마다 같은 번호로 덮어쓰므로 그대로 두면 매번 소리·배너가 난다 |
| 알림 버튼 | `lib/core/local_notifications.dart` | 일시정지·재개 묶음(category) 3개 | iOS 는 초기화 때 등록한 묶음으로만 버튼을 붙인다. 알림을 길게 누르면 보인다 |
| 배터리 채널 | `AppDelegate.swift` `runmagochi/battery` | 늘 "예외 상태" 로 답함 | iOS 에는 앱별 배터리 최적화 예외가 없다. 채널이 없으면 권한 확인이 오류로 멈춘다 |
| 음성 안내 소리 | `lib/run/data/tts_speaker.dart` (이미 있음) | 재생 범주, 다른 앱 소리 줄이기·섞기, 음성 모드 | 음악을 끄지 않고 줄였다가 다 읽으면 되돌린다 |

### 플러그인별 iOS 요구사항

- **geolocator**: 위치 설명 키, 백그라운드 모드 `location`, iOS 용 `AppleSettings`. `CLBackgroundActivitySession` 은 쓰지 않는다(결정 0031).
- **permission_handler**: Podfile 권한 스위치. 알림 권한은 Info.plist 키가 필요 없다.
- **flutter_local_notifications**: AppDelegate 설정, 버튼 묶음 등록. 로컬 알림이라 푸시 알림 기능(유료 계정 필요)은 켜지 않는다.
- **flutter_tts**: 권한 필요 없음. 백그라운드에서 읽으려고 `audio` 모드를 켰다. 오디오 세션은 앱 코드가 정한다.
- **share_plus**: 권한 필요 없음. 사진 앱 저장용 설명 키만 넣었다. iPhone 전용이라 iPad 위치 지정은 필요 없다.
- **file_picker**: 백업 저장·불러오기는 파일 앱 선택 창을 쓰므로 권한이 필요 없다.
- **path_provider**, **drift**(sqlite3): 설정 필요 없음.

## iPhone 에서 확인할 것

빌드만으로는 확인할 수 없어 페이즈 7 실기기 확인 때 본다.

- 화면을 끈 채 30분 기록이 끊기지 않는지, 상태 막대에 위치 사용 표시가 뜨는지 (`CLBackgroundActivitySession` 없이 되는지)
- 화면이 꺼진 채 음성 안내가 나오고, 음악이 줄었다가 돌아오는지
- 러닝 알림이 소리 없이 바뀌고, 길게 눌러 일시정지·재개가 되는지
- 종료 예고 알림이 소리와 함께 뜨고 재개 버튼이 되는지
- 공유 창에서 "이미지 저장" 이 되는지, 백업 저장·불러오기가 파일 앱으로 되는지
- 시작 직후 정확도 20m 초과 점이 너무 많이 버려지지 않는지 (`docs/specs/run-engine.md`)
