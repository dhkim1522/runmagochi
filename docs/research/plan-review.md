# 기획·기술 스택 검토

> NRC 분석에서 가져온 기능·기술 스택이 이 앱(로컬 우선, 1인 개발, 아바타 성장)에 맞는지 검토한 결과. 2026-10-16 기준. 반영 여부는 페이즈 질의에서 정한다.

## 결론

- **아바타 성장(F7·F8)은 페이즈 1에 남기고, 나머지 NRC식 범위를 줄인다.**
  - 아바타가 없으면 이 앱은 기능이 적은 NRC가 된다.
  - 삭제: 소셜(F13)
  - 후속: 런별 목표, 상점, 업적, 음성, 건강 연동
  - 화면은 10개에서 6개로, 하단 탭은 3개로 줄인다.
- **Flutter는 유지하고 Flame은 뺀다.** 도트 스프라이트는 일반 위젯으로 충분하다.
- **위치는 geolocator(무료)로 간다.**
  - flutter_background_geolocation 은 iOS·Android 모두 릴리스 빌드에 유료 라이선스가 필요하다. 앱당 $399부터다.
  - Android 는 앱이 화면에 보일 때 포그라운드 서비스를 시작하면 백그라운드 위치 권한 없이 기록할 수 있다.
- **페이즈 1에서는 지도 대신 경로 선만 그린다.**
  - google_maps_flutter 는 API 키와 Google Cloud 설정이 필요하다.
  - 지도를 넣을 때는 MapLibre 나 flutter_map 에 OpenFreeMap 타일을 쓴다.
- **GPS 점을 원본 그대로 쌓으면 약 1년 안에 Android 자동 백업 한도 25MB를 넘는다.** 넘으면 백업 전체가 멈춘다.
  - 러닝이 끝나면 경로를 압축해 저장한다.
  - 파일 내보내기를 주 백업 수단으로 삼는다.

## 기능 검토

| ID/항목 | 권고 | 근거 |
|---|---|---|
| F1 시작·일시정지·재개·종료 | 유지 | 핵심 기능 |
| F2 실시간 지표 | 유지 | 현재 페이스는 GPS 오차로 흔들리므로 평균 페이스를 크게 보여준다 |
| F3 지도·1km 구간 | 축소 | 구간 기록은 유지. 러닝 중·일시정지 화면의 지도는 빼고, 요약 화면에 경로 선만 그린다 |
| F4 자동 일시정지 | 후속 | 정지 판정 오작동이 기록 정확도 검증을 흐린다. 페이즈 1은 수동 일시정지만 |
| F5 기록 관리 | 축소 | 목록, 상세(경로 선·구간 표), 주간 합계만. 페이스 그래프와 월·년 통계는 후속 |
| F6 목표 | 축소 | 주간 목표는 유지. 런별 목표와 목표 선택 화면(2번)은 후속 |
| F7 경험치·레벨·외형 | 유지 | 앱의 차별점. 레벨과 성장 단계를 한 축으로 합친다 |
| F8 함께 달리는 아바타 | 축소 | 스프라이트 반복 재생만. 페이스에 따라 걷기·달리기 동작을 바꾼다 |
| F9~F11 코인·상점·꾸미기 | 후속 | 결정 0003. 꾸미기 대비로 스프라이트 레이어 규격만 먼저 정한다 |
| F12 백업 | 축소 | 파일 내보내기·가져오기가 주 수단. OS 백업은 보조 |
| F13 소셜 | 삭제 | 서버가 필요해 로컬 우선과 충돌. 서버 도입 시 재검토 |
| F14 음성 안내 | 후속 | 서버 없이 구현 가능. 페이즈 2 후보 |
| F15 건강 연동 | 후속 | Health Connect 는 Play 정책 신고가 필요하다(미확인) |
| 보상 화면(6번) | 통합 | 경험치 획득과 레벨업 연출을 요약 화면에 합친다 |
| 업적 화면(10번) | 후속 | 배지가 코인과 묶여 있다. 페이즈 1은 홈에 주간 연속 달성 주수만 |
| 러닝 중 좌우 밀기, 잠금 토글 | 축소 | 한 화면에 일시정지 버튼만. 잠금은 후속 |
| 기록 삭제·끝부분 잘라내기 | 추가 | 종료를 잊거나 GPS 오류로 경험치가 부풀려지는 것을 바로잡는다 |
| 기록 신뢰성 (권한·배터리 안내, 강제 종료 후 복구) | 추가 | 명세에만 있고 요구사항·화면 목록에 없다 |
| 아바타 상태 반응과 로컬 알림 | 추가 | 다마고치의 본질. 며칠 쉬면 졸린 표정 정도로, 벌점은 없다. 주간 목표 잔여 알림은 로컬 알림 |
| 수동 기록 입력 | 결정 필요 | 게임 규칙에만 있다. 러닝머신 사용자를 받을지 정해야 한다 |

### 화면 구성

MVP 화면 6개: 홈, 러닝 중, 일시정지, 요약(보상 포함), 기록, 아바타. 하단 탭은 러닝·기록·아바타 3개다. 첫 실행·권한 안내·설정 화면도 개발 범위에 넣는다. 설정에는 체중 입력과 내보내기·가져오기가 들어간다.

### 게임 규칙

- 레벨(경험치)과 성장 단계(누적 거리)가 따로 움직인다. 레벨이 외형에 영향을 주지 않아 의미가 약하므로, 성장 단계를 레벨 구간으로 정한다.
- 하루 상한(경험치 300)은 장거리 러닝을 깎는다. 페이즈 1에서는 상한을 빼고 속도 검사만 남긴다.
- 연속 러닝 일수 보상은 입문자에게 매일 달리기를 유도해 부상 위험이 있다. 주간 연속 달성으로 통일한다.

### 기록 엔진 명세의 공백

- 상태도의 '움직임 감지 시 재개'가 자동 일시정지와 사용자 일시정지를 구분하지 않는다. 사용자가 멈춘 경우 움직임으로 재개되면 안 된다.
- 정확도 20m 초과 점 버림 기준은 도심이나 iOS 시작 직후에 점이 대량으로 버려질 수 있다(미확인). 실측으로 확인한다.
- 구간별 고도 변화는 GPS 고도 오차가 커서 페이즈 1에서 뺀다.

## 기술 스택 검토

| 영역 | 현재 | 권고 | 핵심 근거와 trade-off |
|---|---|---|---|
| 프레임워크 | Flutter 추천 | Flutter 확정 | Expo 백그라운드 위치는 '항상 허용' 권한을 요구한다. 위치 플러그인이 실측에서 실패하면 플랫폼 채널로 네이티브 코드를 써야 한다 |
| 아바타 렌더링 | flame | 페이즈 1 제외 | 스프라이트 시트를 Ticker 로 넘기는 위젯 수십 줄로 충분하다. 미니게임을 만들 때 다시 도입한다 |
| 위치 | geolocator | 유지 | 무료, 활발히 유지보수 중. 화면 꺼짐 기록을 실기기로 확인해야 한다. 제조사 배터리 정책(dontkillmyapp) 안내와 중단 복구가 필수다 |
| 지도 | google_maps_flutter | 페이즈 1은 경로 선만 | 키·계정 불필요, 오프라인 동작. 후속에 maplibre_gl 또는 flutter_map + OpenFreeMap. 배경 지도가 없으면 시각적 매력이 떨어진다 |
| 로컬 DB | drift | 유지 | 마이그레이션·타입 안전 쿼리로 서버 동기화에 맞다. Isar·Hive 안정판은 수년째 정체. 코드 생성이 필요하다 |
| 상태 관리 | riverpod | 유지 (코드 생성 없이) | 엔진 이벤트 스트림 연결에 좋다. 화면 6개 규모면 ValueNotifier 로도 된다 |
| 백업 | OS 백업 + 파일 | 파일 내보내기 주 수단 + 경로 압축 저장 | Android 자동 백업 25MB 한도. 30분 러닝 약 180KB, 주 3회면 연 28MB(추정). 압축 시 러닝 1회 약 10KB(추정). 원본 점을 버리면 재계산이 불가하다 |

### 확인이 필요한 항목

- geolocator README 는 Android 10 이상 백그라운드 업데이트에 `ACCESS_BACKGROUND_LOCATION` 이 필요하다고 적고 있다. 포그라운드 서비스만으로 화면 꺼짐 기록이 되는지 실기기 확인이 필요하다.
- iOS 는 geolocator 가 Info.plist 에 Always 설명 키를 요구한다. 넣지 않으려면 `BYPASS_PERMISSION_LOCATION_ALWAYS` 를 설정한다.
- iOS 17 이상에서 '앱 사용 중' 권한으로 백그라운드 기록을 유지하는 데 `CLBackgroundActivitySession` 이 필요한지는 미확인이다.
- Android 14 이상을 타깃으로 하면 Play Console 에 포그라운드 서비스 유형을 신고해야 한다.

## 문서 불일치

- product.md F13(소셜)은 서버가 필요해 결정 0001과 충돌한다.
- product.md 의 '위치 기록은 기기 밖으로 나가지 않는다'는 OS 백업(Google Drive·iCloud 업로드), 지도 타일 요청과 모순된다.
- architecture.md 의 google_maps_flutter 는 API 키와 Google Cloud 프로젝트에 의존한다.
- .gitignore 의 `google-services.json`·`GoogleService-Info.plist` 는 Firebase 전제의 흔적이다.
- architecture.md 의 'UUID, createdAt·updatedAt' 원칙이 데이터 모델과 맞지 않는다. RunPoint·Split·Inventory·UserBadge 에 id·시각 필드가 없고, 동기화용 삭제 표시(deletedAt)도 없다.
- README 첫 문단이 코인·꾸미기를 핵심으로 소개한다. 결정 0003이 반영되지 않았다.
- product.md 목표 '4주 동안 주 2회 이상 달리는 사용자 30%'는 서버·분석 도구 없이 측정할 수 없다.
- game-rules.md 의 '수동 입력 기록'은 요구사항·화면 목록에 없다.
- run-engine.md 의 'iOS 는 앱 사용 중 권한으로 충분'은 geolocator 의 Always 키 요구와 충돌할 수 있다.
- screens.md 의 UX 원칙('좌우로 밀어 컨트롤' 등)이 페이즈 1 범위와 맞는지 재검토가 필요하다.

## 출처

- [flutter_background_geolocation (pub.dev)](https://pub.dev/packages/flutter_background_geolocation), [GitHub](https://github.com/transistorsoft/flutter_background_geolocation), [가격](https://shop.transistorsoft.com/)
- [geolocator](https://pub.dev/packages/geolocator)
- [Android 포그라운드 서비스 유형](https://developer.android.com/develop/background-work/services/fgs/service-types), [Play 위치 권한 정책](https://support.google.com/googleplay/android-developer/answer/9799150), [Android 자동 백업](https://developer.android.com/identity/data/autobackup)
- [dontkillmyapp](https://dontkillmyapp.com/)
- [Expo Location](https://docs.expo.dev/versions/latest/sdk/location/)
- [OSM 타일 정책](https://operations.osmfoundation.org/policies/tiles/), [OpenFreeMap](https://openfreemap.org/), [Google Maps 가격](https://developers.google.com/maps/billing-and-pricing/pricing)
- [flutter_map](https://pub.dev/packages/flutter_map), [maplibre_gl](https://pub.dev/packages/maplibre_gl)
- [drift](https://pub.dev/packages/drift), [sqflite](https://pub.dev/packages/sqflite), [isar](https://pub.dev/packages/isar), [isar_community](https://pub.dev/packages/isar_community), [hive](https://pub.dev/packages/hive), [hive_ce](https://pub.dev/packages/hive_ce)
- [flame](https://pub.dev/packages/flame), [Flame 위젯](https://docs.flame-engine.org/latest/flame/other/widgets.html)
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)
- [Apple 개발자 포럼 757691](https://developer.apple.com/forums/thread/757691)
- [Compose Multiplatform 1.8.0](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released-compose-multiplatform-for-ios-is-stable-and-production-ready/) (검색 결과로만 확인)
