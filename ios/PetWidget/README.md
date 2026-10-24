# iOS 홈 화면 위젯 (F29)

`PetWidget.swift` 는 앱이 그려 App Group(`group.com.dhkim1522.runmagochi`)에 둔 그림 `pet_image` 를 보여 주는 작은 위젯이다. Android 와 같은 그림을 쓴다(`lib/widget/`).

## Xcode 에서 연결하기 (한 번만)

1. `open ios/Runner.xcworkspace` → File → New → Target → **Widget Extension**. 이름 `PetWidget`, "Include Live Activity"·"Include Configuration App Intent" 는 끈다.
2. Xcode 가 만든 기본 Swift 파일을 지우고 이 폴더의 `PetWidget.swift` 를 대상에 추가한다.
3. **Runner** 와 **PetWidget** 두 타깃 모두 Signing & Capabilities → `+ Capability` → **App Groups** → `group.com.dhkim1522.runmagochi`.
4. PetWidget 타깃의 Bundle Identifier 는 `com.dhkim1522.runmagochi.PetWidget`.
5. `fvm flutter run --release -d <iPhone>`.

## 주의

- 무료 Apple ID(Personal Team)는 App Group·확장 앱 ID 가 막힐 수 있다. 안 되면 위젯 확장 없이 앱만 설치하고(앱은 위젯 없이 정상 동작), 유료 개발자 계정(페이즈 10) 뒤에 켠다.
- 앱 쪽 코드(`HomeWidgetPublisher`)는 위젯이 없어도 실패해도 로그만 남긴다.
