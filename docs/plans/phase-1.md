# 페이즈 1 구현 계획

- 상태: 실측 대기
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android에서 러닝을 시작·일시정지·종료하고, 화면이 꺼져도 끊기지 않게 기록해 요약·목록으로 보여주는 앱을 만든다.

**Architecture:** 기록 엔진은 Flutter에 의존하지 않는 순수 Dart 모듈로, 위치 점을 받아 거리·페이스·구간을 계산하고 이벤트를 낸다. `RunController`(riverpod)가 위치 스트림, 엔진, 저장소를 연결하고 10초마다 점을 저장한다. 화면은 컨트롤러 상태만 본다. 저장은 `RunRepository` 인터페이스 뒤의 drift(SQLite) 구현이 맡는다.

**Tech Stack:** Flutter 3.44 / Dart 3.12, geolocator, drift + drift_flutter, flutter_riverpod (코드 생성 없음), permission_handler, uuid, fake_async(테스트)

**Spec:** `docs/specs/run-engine.md`, `docs/architecture.md`, `docs/screens.md`, `docs/roadmap.md` 페이즈 1, 와이어프레임 `design/wireframes/png/01-main.png`, `03-inrun.png`, `04-paused.png`, `05-summary.png`, `09-activity.png`

## Global Constraints

- 서버·로그인·지도 API 없음. 네트워크 없이 모든 기능이 동작한다.
- 화면 문구는 한국어. 페이스 표기는 `6'25"` 형식, 값이 없으면 `-'--"`.
- 거리 단위는 내부 미터(double), 화면 km 소수 둘째 자리.
- 모든 DB 테이블에 `id`(UUID 문자열), `createdAt`, `updatedAt`, `deletedAt`(nullable).
- 데이터 접근은 `RunRepository` 인터페이스만 거친다. 화면·컨트롤러는 drift를 직접 import하지 않는다.
- 위치 점 처리 값 (run-engine.md 그대로)
  - 정확도 20m 초과 점 버림
  - 직전 채택 점 대비 초속 7m 초과 점 버림
  - 최소 이동 거리 3m (geolocator `distanceFilter: 3`)
  - 수집 주기 1초 (`intervalDuration: 1초`)
  - 현재 페이스 = 최근 30초 구간
  - 칼로리 = 65kg × 거리(km) × 1.036 (체중 입력은 페이즈 3)
- 위치 점은 10초마다 DB에 저장. 러닝 종료 시 경로를 encoded polyline으로 압축해 Run에 저장하고 RunPoint 행은 삭제한다.
- 주간 합계의 주는 월요일 0시(기기 현지 시각) 시작.
- Android만 빌드·검증한다. iOS 설정은 페이즈 3.
- 테스트는 macOS와 Windows에서 모두 `flutter test` 로 돌아야 한다. 플랫폼 플러그인은 인터페이스 뒤에 두고 테스트에서는 가짜 구현을 쓴다.

## Review Focus

1. **재개 직후 첫 점**: 일시정지 동안 이동한 거리(일시정지 지점과 재개 첫 점 사이)는 거리에 넣지 않는다. 테스트는 Task 3.
2. **GPS 첫 점 지연**: 시작 후 점이 오지 않아도 시간은 흐르고, 페이스는 `null` 로 `-'--"` 표시. 테스트는 Task 3.
3. **아주 짧은 러닝**: 거리 0 또는 10m 미만으로 종료해도 예외 없이 저장되고 페이스는 `null`. 테스트는 Task 4·5.
4. **시각이 역행하는 점**: 직전 채택 점보다 이른 시각의 점은 버린다. 테스트는 Task 3.
5. **기록 중 프로세스 종료**: 다시 열면 마지막 저장분까지의 기록이 일시정지 상태로 복구된다(최대 10초 손실 허용). 테스트는 Task 6.

---

## 파일 구조

```
lib/
  main.dart                         앱 진입, ProviderScope
  app.dart                          MaterialApp, 하단 탭 3개
  core/clock.dart                   typedef Clock
  core/format.dart                  페이스·시간·거리 표기
  run/domain/location_sample.dart   위치 점 값 객체
  run/domain/geo.dart               하버사인 거리
  run/domain/polyline_codec.dart    encoded polyline 인코딩·디코딩
  run/domain/run_engine.dart        상태·필터·거리·페이스·구간·이벤트
  run/domain/run_summary.dart       RunSummary, Split, 자동 이름, 칼로리
  run/data/app_database.dart        drift 테이블·DB
  run/data/run_repository.dart      RunRepository 인터페이스, 조회용 모델
  run/data/drift_run_repository.dart
  run/data/location_source.dart     LocationSource 인터페이스
  run/data/geolocator_location_source.dart
  run/app/run_controller.dart       riverpod Notifier, 저장 주기, 복구
  run/app/providers.dart
  run/ui/home_screen.dart           러닝 탭, 복구 다이얼로그, 카운트다운
  run/ui/in_run_screen.dart         러닝 중·일시정지
  run/ui/summary_screen.dart        요약·상세
  run/ui/route_painter.dart         경로 선
  run/ui/history_screen.dart        기록 탭
  run/ui/permission_screen.dart     위치·알림 권한, 배터리 안내
  avatar/ui/avatar_placeholder.dart 아바타 탭 자리
tool/fake_run.dart                  에뮬레이터 가상 러닝 (adb geo fix)
test/ 는 lib/ 와 같은 구조
```

---

## 작업

- [x] 1. 프로젝트 생성과 Android 설정
- [x] 2. 거리·경로 압축 유틸
- [x] 3. 기록 엔진: 상태·필터·거리·페이스
- [x] 4. 기록 엔진: 구간·요약
- [x] 5. 로컬 DB와 저장소
- [x] 6. 위치 소스와 RunController
- [x] 7. 권한·배터리 안내
- [x] 8. 홈·러닝 중·일시정지 화면과 복구
- [x] 9. 요약·기록 화면
- [x] 10. 에뮬레이터 가상 러닝 도구

### Task 1: 프로젝트 생성과 Android 설정

**Files:**
- Create: 저장소 루트에 Flutter 프로젝트 (`pubspec.yaml`, `lib/`, `android/`, `ios/`, `test/`)
- Modify: `android/app/src/main/AndroidManifest.xml`, `README.md` "빌드·실행", `.gitignore`
- Create: `docs/decisions/0006-phase1-packages.md`
- Test: `test/app_test.dart`

**Interfaces:**
- Produces: `RunmagochiApp` (StatelessWidget, `lib/app.dart`), 하단 탭 라벨 `러닝`, `기록`, `아바타`

- [ ] **Step 1:** 루트에서 `flutter create --org com.dhkim1522 --project-name runmagochi --platforms android,ios .` 실행. 기존 README.md·.gitignore는 덮어쓰지 않고 Flutter 기본 항목만 `.gitignore` 에 합친다.
- [ ] **Step 2:** 의존성 추가: `flutter pub add geolocator drift drift_flutter flutter_riverpod permission_handler uuid` / `flutter pub add --dev drift_dev build_runner fake_async`
- [ ] **Step 3:** 실패하는 테스트 작성 `test/app_test.dart`

```dart
testWidgets('하단 탭 3개가 보인다', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: RunmagochiApp()));
  expect(find.text('러닝'), findsOneWidget);
  expect(find.text('기록'), findsOneWidget);
  expect(find.text('아바타'), findsOneWidget);
});
```

- [ ] **Step 4:** `flutter test test/app_test.dart` → FAIL
- [ ] **Step 5:** `lib/main.dart`, `lib/app.dart` 작성. 탭 본문은 임시 `Text` (Task 8·9에서 교체).
- [ ] **Step 6:** AndroidManifest에 권한 추가: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`. `ACCESS_BACKGROUND_LOCATION`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 는 넣지 않는다.
- [ ] **Step 7:** `flutter test` PASS, `dart analyze` 경고 0, `flutter build apk --debug` 성공
- [ ] **Step 8:** 결정 0006 작성: permission_handler·uuid 추가, 경로 압축은 직접 구현, 배터리 최적화 예외는 권한 요청 없이 설정 화면 안내. README "빌드·실행" 에 `flutter pub get`, `dart run build_runner build`, `flutter run` 기록.
- [ ] **Step 9:** 커밋 `chore: Flutter 프로젝트 생성과 Android 권한 설정`

### Task 2: 거리·경로 압축 유틸

**Files:**
- Create: `lib/core/clock.dart`, `lib/run/domain/location_sample.dart`, `lib/run/domain/geo.dart`, `lib/run/domain/polyline_codec.dart`
- Test: `test/run/domain/geo_test.dart`, `test/run/domain/polyline_codec_test.dart`

**Interfaces:**
- Produces:
  - `typedef Clock = DateTime Function();`
  - `class LocationSample { final DateTime time; final double latitude; final double longitude; final double accuracy; final double? speed; const LocationSample({...}); }`
  - `double haversineMeters(double lat1, double lng1, double lat2, double lng2)`
  - `String encodePolyline(List<(double, double)> points)` / `List<(double, double)> decodePolyline(String encoded)` (정밀도 1e5)

- [ ] **Step 1:** 실패하는 테스트

```dart
test('서울역-시청 직선거리', () {
  final d = haversineMeters(37.5547, 126.9707, 37.5663, 126.9779);
  expect(d, closeTo(1450, 30));
});
test('Google 예제 인코딩', () {
  expect(encodePolyline([(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]),
      '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
});
test('디코딩은 인코딩의 역', () {
  final pts = [(37.52600, 126.92400), (37.52620, 126.92420)];
  expect(decodePolyline(encodePolyline(pts)), pts);
});
test('빈 목록은 빈 문자열', () => expect(encodePolyline([]), ''));
```

- [ ] **Step 2:** `flutter test test/run/domain` → FAIL
- [ ] **Step 3:** 구현. 지구 반지름 6,371,000m. 폴리라인은 Google Encoded Polyline Algorithm.
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 하버사인 거리와 경로 압축`

### Task 3: 기록 엔진 — 상태·필터·거리·페이스

**Files:**
- Create: `lib/run/domain/run_engine.dart`
- Test: `test/run/domain/run_engine_test.dart`

**Interfaces:**
- Consumes: `Clock`, `LocationSample`, `haversineMeters`
- Produces:

```dart
enum RunState { idle, recording, paused, ended }

sealed class RunEvent {}
class StateChanged extends RunEvent { final RunState from; final RunState to; }
class SplitCompleted extends RunEvent { final Split split; }   // Task 4
class RunEnded extends RunEvent { final RunSummary summary; }  // Task 4

class RunSnapshot {
  final RunState state;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;      // 거리 10m 미만이면 null
  final double? currentPaceSecPerKm;  // 최근 30초 구간 거리 10m 미만이면 null
  final List<Split> splits;           // Task 4
}

class RunEngine {
  RunEngine({required Clock clock, DateTime? startedAt, List<LocationSample> restoredPoints = const []});
  Stream<RunEvent> get events;        // broadcast
  RunSnapshot get snapshot;
  List<LocationSample> get acceptedPoints;
  void start();
  void pause();
  void resume();
  RunSummary end();                   // Task 4
  bool addSample(LocationSample s);   // 채택하면 true
}
```

규칙:
- `addSample` 은 `recording` 일 때만 처리한다.
- 정확도 20m 초과, 직전 채택 점보다 이른 시각, 직전 채택 점 대비 초속 7m 초과인 점은 버린다.
- 거리는 같은 구간(segment) 안의 연속 채택 점 사이 하버사인 합이다. `start`·`resume` 직후 첫 채택 점은 새 구간을 시작하고 거리를 더하지 않는다.
- 움직인 시간(`movingTime`)은 `clock()` 기준으로 recording 상태였던 시간의 합이다.
- 상태 전이 외의 호출(예: idle에서 pause)은 `StateError`.
- `restoredPoints` 를 받으면 그 점들로 거리를 다시 계산하고 `paused` 상태로 시작한다. `movingTime` 은 점 시각 기준 구간 합으로 복원한다.

- [ ] **Step 1:** 실패하는 테스트 (가짜 시계 `var now = DateTime(2026,10,17,7); clock: () => now`)
  - `start 후 2점(동쪽 0.0001도 간격) → distanceM ≈ haversine 값`
  - `정확도 25m 점은 버린다` → `addSample == false`, 거리 변화 없음
  - `1초 만에 10m 이동한 점은 버린다`
  - `시각이 역행한 점은 버린다` (Review Focus 4)
  - `일시정지 중 점은 무시`
  - `재개 후 첫 점은 거리를 더하지 않는다`: 점 A 기록 → pause → resume → A에서 500m 떨어진 점 B → `distanceM` 은 A까지의 값 그대로 (Review Focus 1)
  - `점 없이 60초 경과` → `movingTime == 60초`, `avgPaceSecPerKm == null` (Review Focus 2)
  - `일시정지 시간은 movingTime에서 빠진다`: 30초 기록, 20초 일시정지, 10초 기록 → 40초
  - `평균 페이스 = movingTime ÷ km`: 1000m·360초 → 360.0
  - `현재 페이스는 최근 30초 점만 쓴다`
  - `상태 이벤트 순서`: start→pause→resume에서 `StateChanged(idle→recording)`, `(recording→paused)`, `(paused→recording)`
  - `idle에서 pause는 StateError`
  - `restoredPoints로 만든 엔진은 paused이고 거리가 같다`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현 (`end`·구간은 Task 4. 컴파일용으로 `Split`·`RunSummary` 는 Task 4 파일에 먼저 선언만 둔다)
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 기록 엔진 상태와 거리·페이스 계산`

### Task 4: 기록 엔진 — 구간·요약

**Files:**
- Create: `lib/run/domain/run_summary.dart`
- Modify: `lib/run/domain/run_engine.dart`
- Test: `test/run/domain/run_engine_split_test.dart`, `test/run/domain/run_summary_test.dart`

**Interfaces:**
- Produces:

```dart
class Split {
  final int index;            // 1부터
  final double distanceM;     // 마지막 구간만 1000 미만
  final Duration duration;
  double get paceSecPerKm;    // duration ÷ (distanceM/1000)
}

class RunSummary {
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
  final double calories;      // 65 × km × 1.036
  final String name;
  final List<Split> splits;
  final List<LocationSample> points;
}

String autoRunName(DateTime startedAt);   // "금요일 저녁 러닝"
double estimateCalories(double distanceM, {double weightKg = 65});
```

규칙:
- 구간 시간은 점 시각 기준으로 계산한다. 1km 경계를 지나는 두 점 사이에서 선형 보간한 시각을 경계 시각으로 쓴다. 경계마다 `SplitCompleted` 를 낸다.
- `end()` 는 남은 거리를 마지막 구간으로 넣고(거리 0이면 넣지 않음) `RunEnded` 를 낸 뒤 상태를 `ended` 로 바꾼다.
- 자동 이름 시간대: 0~5시 새벽, 5~11시 아침, 11~14시 점심, 14~18시 오후, 18~22시 저녁, 22~24시 밤.

- [ ] **Step 1:** 실패하는 테스트
  - `1km 경계 보간`: 0초 0m, 300초 900m, 400초 1100m 지점의 점 → 1구간 duration 350초
  - `2.5km 러닝은 구간 3개, 마지막 500m`
  - `SplitCompleted 이벤트가 경계마다 1번`
  - `거리 0으로 종료하면 splits 빈 목록, avgPace null` (Review Focus 3)
  - `autoRunName(DateTime(2026,10,16,19))` == `'금요일 저녁 러닝'`, `DateTime(2026,10,17,6)` == `'토요일 아침 러닝'`
  - `estimateCalories(5000)` == `closeTo(336.7, 0.1)`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 기록 엔진 구간과 러닝 요약`

### Task 5: 로컬 DB와 저장소

**Files:**
- Create: `lib/run/data/app_database.dart` (+ 생성 파일 `app_database.g.dart`), `lib/run/data/run_repository.dart`, `lib/run/data/drift_run_repository.dart`
- Test: `test/run/data/drift_run_repository_test.dart`

**Interfaces:**
- Consumes: `LocationSample`, `RunSummary`, `Split`, `encodePolyline`
- Produces:

```dart
class RunListItem { final String id; final String name; final DateTime startedAt;
  final double distanceM; final Duration movingTime; final double? avgPaceSecPerKm; }
class RunDetail { final RunListItem run; final double calories;
  final List<(double, double)> route; final List<Split> splits; }
class ActiveRun { final String id; final DateTime startedAt; final List<LocationSample> points; }

abstract interface class RunRepository {
  Future<String> createActiveRun(DateTime startedAt);
  Future<void> appendPoints(String runId, List<LocationSample> points);
  Future<ActiveRun?> findActiveRun();
  Future<void> completeRun(String runId, RunSummary summary);
  Future<List<RunListItem>> listRuns();                 // 최신순, deletedAt null만
  Future<RunDetail?> getRun(String id);
  Future<(double distanceM, int count)> weeklyTotal(DateTime now);
}
```

테이블:
- `Runs`: id, startedAt, endedAt?, status(`active`|`completed`), distanceM, movingTimeS, avgPaceSecPerKm?, calories, name, encodedRoute?, createdAt, updatedAt, deletedAt?
- `RunPoints`: id, runId, time, latitude, longitude, accuracy, speed?, createdAt, updatedAt, deletedAt?
- `Splits`: id, runId, idx, distanceM, durationMs, createdAt, updatedAt, deletedAt?
- `completeRun` 은 트랜잭션으로 Run 갱신, encodedRoute 저장, Splits 삽입, 해당 RunPoints 행 삭제(물리 삭제)를 한다.

- [ ] **Step 1:** 실패하는 테스트 (`AppDatabase(NativeDatabase.memory())`)
  - `createActiveRun 후 findActiveRun이 같은 id와 점을 돌려준다`
  - `completeRun 후 findActiveRun은 null, RunPoints는 0행, getRun의 route 점 수 = 원본 점 수`
  - `거리 0 요약도 저장된다` (Review Focus 3)
  - `listRuns는 최신순`
  - `weeklyTotal은 월요일 0시부터`: 일요일 23시 러닝은 다음 주 월요일 기준 합계에서 빠진다
- [ ] **Step 2:** `dart run build_runner build` 후 FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS 확인. Windows에서 `NativeDatabase` 가 sqlite3 라이브러리를 못 찾으면 그 사실과 해결법을 README에 적는다.
- [ ] **Step 5:** 커밋 `feat: 러닝 로컬 DB와 저장소`

### Task 6: 위치 소스와 RunController

**Files:**
- Create: `lib/run/data/location_source.dart`, `lib/run/data/geolocator_location_source.dart`, `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`
- Test: `test/run/app/run_controller_test.dart`

**Interfaces:**
- Consumes: `RunEngine`, `RunRepository`, `LocationSample`
- Produces:

```dart
abstract interface class LocationSource { Stream<LocationSample> watch(); }

class RunViewState { final RunSnapshot snapshot; final String? runId; final RunSummary? lastSummary; }

class RunController extends Notifier<RunViewState> {
  Future<void> start();
  void pause();
  void resume();
  Future<RunSummary> end();
  Future<bool> restoreIfAny();   // 복구한 러닝이 있으면 true, 상태 paused
}

final runRepositoryProvider = Provider<RunRepository>(...);
final locationSourceProvider = Provider<LocationSource>(...);
final clockProvider = Provider<Clock>((_) => DateTime.now);
final runControllerProvider = NotifierProvider<RunController, RunViewState>(RunController.new);
```

규칙:
- `GeolocatorLocationSource` 는 `AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 3, intervalDuration: Duration(seconds: 1), foregroundNotificationConfig: ForegroundNotificationConfig(notificationTitle: '러닝 기록 중', notificationText: '화면을 꺼도 기록이 이어집니다', enableWakeLock: true))` 를 쓴다.
- 컨트롤러는 채택된 점을 버퍼에 모아 10초마다, 그리고 pause·end 때 `appendPoints` 한다.
- 화면 갱신용으로 1초마다 snapshot을 새로 낸다.
- pause 중에도 위치 스트림은 유지한다(포그라운드 서비스 유지). end에서 구독을 해제한다.

- [ ] **Step 1:** 실패하는 테스트 (`fake_async`, 가짜 LocationSource·RunRepository·Clock)
  - `start → 점 5개 → 10초 경과 → appendPoints 1회, 점 5개`
  - `pause 시 버퍼를 즉시 저장`
  - `end 후 completeRun 호출, 위치 구독 해제`
  - `findActiveRun이 점 3개를 주면 restoreIfAny는 true, 상태 paused, 거리 복원` (Review Focus 5)
  - `활성 러닝이 없으면 restoreIfAny는 false`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 위치 스트림과 기록 컨트롤러`

### Task 7: 권한·배터리 안내

**Files:**
- Create: `lib/run/ui/permission_screen.dart`, `lib/run/app/permission_gate.dart`
- Test: `test/run/ui/permission_screen_test.dart`

**Interfaces:**
- Produces:

```dart
enum GateResult { ready, needsLocation, locationDeniedForever, needsBatteryGuide }
abstract interface class PermissionGate {
  Future<GateResult> check();
  Future<GateResult> requestLocation();     // 정밀 위치 + 알림 권한
  Future<void> openBatterySettings();        // 앱 설정 화면 열기
}
final permissionGateProvider = Provider<PermissionGate>(...);
```

규칙:
- 시작 버튼을 누를 때 `check()` 가 `ready` 가 아니면 안내 화면을 띄운다.
- 위치 안내 문구: "러닝 경로와 거리를 기록하려면 위치 권한이 필요합니다. 위치는 이 기기에만 저장됩니다."
- 배터리 안내: 배터리 최적화가 켜져 있으면 1회 안내하고 "설정 열기"·"나중에" 버튼을 둔다. "나중에"를 누르면 이후 시작을 막지 않는다.
- 영구 거부면 "설정에서 위치 권한을 허용해 주세요"와 설정 열기 버튼.

- [ ] **Step 1:** 실패하는 위젯 테스트 (가짜 PermissionGate)
  - `needsLocation이면 안내 문구와 '권한 허용' 버튼`
  - `locationDeniedForever면 '설정 열기' 버튼`
  - `needsBatteryGuide에서 '나중에'를 누르면 ready로 진행`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현 (실제 구현은 permission_handler `Permission.locationWhenInUse`, `Permission.notification`, `Permission.ignoreBatteryOptimizations.status` 조회만)
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 위치 권한과 배터리 최적화 안내`

### Task 8: 홈·러닝 중·일시정지 화면과 복구

**Files:**
- Create: `lib/core/format.dart`, `lib/run/ui/home_screen.dart`, `lib/run/ui/in_run_screen.dart`, `lib/avatar/ui/avatar_placeholder.dart`
- Modify: `lib/app.dart`
- Test: `test/core/format_test.dart`, `test/run/ui/home_screen_test.dart`, `test/run/ui/in_run_screen_test.dart`

**Interfaces:**
- Consumes: `runControllerProvider`, `permissionGateProvider`, `RunRepository.weeklyTotal`
- Produces: `String formatPace(double? secPerKm)` → `6'25"` / `-'--"`, `String formatDuration(Duration d)` → `18:42` 또는 `1:02:05`, `String formatKm(double meters)` → `2.91`

화면 (와이어프레임 01, 03, 04 기준, 지도 없음):
- 홈: 이번 주 거리 합계, 아바타 자리(빈 상자 "아바타는 다음 업데이트에서 만나요"), 시작 버튼. 시작 → 권한 확인 → 3초 카운트다운(3, 2, 1) → 러닝 중.
- 러닝 중: 상단 평균 페이스·현재 페이스·시간, 가운데 거리(가장 크게), 일시정지 버튼.
- 일시정지: 거리·평균 페이스·시간·칼로리, 재개 버튼, 종료 버튼은 1.5초 길게 눌러야 동작.
- 앱 시작 시 `restoreIfAny()` 가 true면 다이얼로그 "기록 중이던 러닝이 있어요" + "이어서 기록"(일시정지 화면으로) / "종료하고 저장"(요약으로).

- [ ] **Step 1:** 실패하는 테스트
  - `formatPace(385) == "6'25\""`, `formatPace(null) == "-'--\""`, `formatDuration(Duration(minutes: 62, seconds: 5)) == '1:02:05'`
  - `시작 버튼 → 카운트다운 3 표시 → 3초 후 러닝 중 화면`
  - `일시정지 화면에서 종료 버튼을 짧게 누르면 종료되지 않는다`
  - `1.5초 길게 누르면 end 호출`
  - `복구할 러닝이 있으면 다이얼로그 표시`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 홈·러닝 중·일시정지 화면`

### Task 9: 요약·기록 화면

**Files:**
- Create: `lib/run/ui/route_painter.dart`, `lib/run/ui/summary_screen.dart`, `lib/run/ui/history_screen.dart`
- Modify: `lib/app.dart`
- Test: `test/run/ui/route_painter_test.dart`, `test/run/ui/summary_screen_test.dart`, `test/run/ui/history_screen_test.dart`

**Interfaces:**
- Consumes: `RunSummary`, `RunDetail`, `RunRepository.listRuns/getRun/weeklyTotal`, `format.dart`
- Produces: `List<Offset> projectRoute(List<(double, double)> route, Size size, {double padding = 16})`

규칙:
- 경로 투영은 등장방형 투영에 경도 × cos(평균 위도) 보정, 가로세로 비율 유지, 여백 16.
- 요약: 이름, 날짜, 거리, 평균 페이스, 시간, 칼로리, 경로 선, 구간 표(km, 페이스). 종료 직후와 기록 상세가 같은 화면을 쓴다.
- 기록 탭: 이번 주 합계(거리, 횟수), 최근 러닝 목록(날짜·이름, 거리·페이스·시간). 항목을 누르면 상세.

- [ ] **Step 1:** 실패하는 테스트
  - `projectRoute 결과가 모두 여백 안쪽에 있다`
  - `점 1개 경로는 중앙 한 점`, `빈 경로는 빈 목록`
  - `요약 화면에 구간 행 수 = splits 수`
  - `기록 탭에 러닝 2개가 최신순으로 보인다`
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 러닝 요약과 기록 화면`

### Task 10: 에뮬레이터 가상 러닝 도구

**Files:**
- Create: `tool/fake_run.dart`
- Modify: `docs/specs/run-engine.md` "검증" 의 에뮬레이터 항목에 사용법 한 줄

**Interfaces:**
- Produces: `dart run tool/fake_run.dart --minutes 5 --speed 3.0 --lat 37.5260 --lng 126.9240` → 1초마다 `adb emu geo fix <lng> <lat>` 를 보내고, 끝나면 보낸 경로의 총 거리(m)를 출력한다.

- [ ] **Step 1:** 실패하는 테스트 `test/tool/fake_run_test.dart`: 경로 생성 함수 `List<(double, double)> buildPath({required int seconds, required double speedMps, required double lat, required double lng})` 가 만든 경로의 하버사인 합 = `seconds × speedMps` ± 1%
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현 (북동 방향 직선, `Process.run('adb', ...)`)
- [ ] **Step 4:** PASS 확인
- [ ] **Step 5:** 커밋 `feat: 에뮬레이터 가상 러닝 도구`

---

## 완료 기준

### 자동 확인
- [x] `flutter test` 전체 통과
- [x] `dart analyze` 경고 0
- [x] `flutter build apk --debug` 성공
- [x] 병합된 AndroidManifest에 `ACCESS_BACKGROUND_LOCATION` 이 없다 (`build/app/intermediates/merged_manifests/` 확인)
- [x] 에뮬레이터에서 `tool/fake_run.dart --minutes 5` 실행 중 `adb shell input keyevent 26` 으로 화면을 끄고 2분 뒤 켰을 때 기록이 이어지고, 앱 거리가 도구 출력 거리의 ±5% 이내
- [x] 에뮬레이터에서 기록 중 `adb shell am force-stop com.dhkim1522.runmagochi` 후 재실행하면 복구 다이얼로그가 뜬다

> 2026-10-16 에뮬레이터 검증: 테스트 151건 통과, 화면 2분 끈 상태 기록 유지, 거리 오차 -1.7% (539.4m 대비 0.53km), 강제 종료 후 복구 다이얼로그 확인.

### 사람 확인
- [ ] Android 실기기로 실제 30분 러닝 3회, 기록 누락 0건
- [ ] 거리를 아는 코스(트랙 400m × 10바퀴)에서 거리 오차 5% 이내
- [ ] 화면을 끄고 주머니에 넣은 채 달린 기록이 끊기지 않음

### 실측 때 함께 볼 것

- 시작 직후 첫 위치가 직전 위치(오래된 위치)로 들어와 거리가 튀는지. 에뮬레이터에서는 약 650m 튐
- 기기 시계와 GPS 시각 차이가 2초를 넘어 시작·재개 직후 점이 버려지는지
- 위치 서비스(정확도 설정)가 꺼져 있으면 "위치 신호를 받지 못하고 있어요" 만 반복된다. 원인별 안내 문구가 필요한지

## 구현 중 결정

- **작업 진행**: 작업마다 `main` 에 커밋·push 했다.
- **구간 단위 기록·복구**: 위치 점에 구간 번호를 붙여 저장하고, 강제 종료 후 구간별로 복원한다. 근거는 [결정 0007](../decisions/0007-segment-restore.md).
  - 구간은 첫 점이 채택될 때 생기며 빈 구간은 없다.
  - 움직인 시간은 저장할 때마다 Run 행에 함께 기록해 복원 시 그대로 쓴다. 최대 10초 손실.
  - 복원한 점에는 필터를 다시 적용하지 않는다.
- **페이스**
  - 평균·현재 페이스는 거리 10m 미만이면 표시하지 않는다(`-'--"`).
  - 현재 페이스는 기기 시계 기준 최근 30초 창으로 계산하고, 일시정지 중과 재개 직후에는 표시하지 않는다. 서 있으면 사라진다.
- **위치 점 필터**: 속도 검사는 직전 채택 점 기준이며 구간 경계를 넘지 않는다. 시작·재개 2초 전보다 오래된 점과 시각이 같거나 이른 점은 버린다. GPS 시각을 그대로 쓴다.
- **구간 기록**: 구간 시간은 점 시각 기준이라 합계가 움직인 시간보다 몇 초 짧을 수 있다. 마지막 부분 구간은 남은 거리 1m 이상일 때만 넣고, 누적 거리(예: 2.5)로 표시한다.
- **저장**: 날짜는 UTC로 저장하고 기기 현지 시각으로 보여준다. 진행 중이 아닌 러닝에는 점 추가·완료를 거부한다.
- **컨트롤러**: 시작·종료 중 중복 호출을 막는다. 저장 실패는 화면에 한국어 문구로 알리고 다음 저장에서 다시 시도한다. 완료 저장이 실패하면 종료만 다시 시도할 수 있다.
- **권한**
  - 정확한 위치를 허용하지 않으면 다시 요청한다.
  - 배터리 최적화 상태는 권한 요청 없이 Android 시스템에서 직접 읽고, 설정 화면으로 안내한다.
  - 백그라운드 위치 수집에 필요한 `WAKE_LOCK` 권한을 둔다.
- **미룬 것**
  - 위치 권한을 영구 거부하면 '권한 허용' 버튼이 동작하지 않는다. 페이즈 3 권한·첫 실행 화면에서 고친다.
  - 복구 다이얼로그에서 '종료하고 저장' 하면 요약 화면 없이 홈에 남는다. 기록 탭에서 볼 수 있다.
