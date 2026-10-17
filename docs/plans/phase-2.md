# 페이즈 2 구현 계획

- 상태: 계획
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 달린 거리로 경험치·레벨·외형 단계가 자라는 도트 아바타를 홈·러닝 중·요약·아바타 화면에 붙이고, 주간 목표와 금요일 알림을 더한다.

**Architecture:** 성장 규칙은 Flutter 에 의존하지 않는 순수 Dart 함수(`lib/avatar/domain/`)다. `GrowthService.sync` 가 완료된 러닝 중 경험치를 받지 않은 것을 찾아 XpTxn 을 쓰고 주간 목표 보너스를 판정한다. 같은 러닝은 두 번 받지 않으므로 러닝 종료 직후와 앱 시작 때 모두 부른다. 기록 코드(`lib/run/`)는 성장 코드를 모른다. 아바타는 32×32 레이어 스프라이트 시트를 Ticker 로 넘기는 위젯으로 그린다.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13 (FVM), drift, flutter_riverpod, flutter_local_notifications, timezone, flutter_timezone, image(개발용)

**Spec:** `docs/specs/game-rules.md`, `docs/architecture.md`, `docs/screens.md`, `docs/roadmap.md` 페이즈 2, 와이어프레임 `design/wireframes/png/01-main.png`, `03-inrun.png`, `06-reward.png`, `07-avatar.png`

## Global Constraints

- 페이즈 1 제약을 그대로 따른다: 서버 없음, 한국어 문구, 페이스 `6'25"`, 거리 km 소수 둘째 자리, 모든 테이블에 `id`·`createdAt`·`updatedAt`·`deletedAt`, 화면·도메인은 저장소 인터페이스만 거친다.
- 명령은 `fvm flutter ...`, `fvm dart ...` 로 실행한다.
- 경험치: 1km당 10 = **100m당 1, 소수점 버림**. 주간 목표 달성 시 +50 (주마다 한 번).
- 레벨: n → n+1 에 50 × n. 레벨 L 까지 누적 경험치 = 25 × L × (L − 1). 시작 레벨 1.
- 외형 단계: 레벨 1~4 → 1, 5~9 → 2, 10~19 → 3, 20 이상 → 4.
- 표정: 마지막 러닝 시작일과 오늘의 **현지 달력 날짜 차이** 0~2 기본, 3~6 졸림, 7 이상 잠듦. 러닝이 없으면 기본.
- 속도 검사: 1km 구간 페이스가 150초/km 보다 빠르면 그 구간 거리는 경험치에서 뺀다. 1km 미만 마지막 구간은 검사하지 않는다.
- 주는 월요일 0시(현지) 시작. 러닝이 속한 주는 **시작 시각** 기준(페이즈 1 `weeklyTotal` 과 같다).
- 주간 목표 기본값 10km. 홈에서 바꾼다. 첫 실행·설정 화면은 페이즈 3.
- 러닝 중 동작: 일시정지 → idle, 현재 페이스가 없거나 540초/km(9'00") 보다 느리면 walk, 540 이하면 run.
- 주간 목표 알림: 금요일 18:00(현지). 이번 주 목표가 남았으면 이번 주 금요일, 그리고 이후 3주의 금요일까지 예약한다.
- 스프라이트 규격 (확정, `docs/specs/sprite-spec.md` 에 기록)
  - 프레임 32×32px, 동작별 가로 한 줄 시트. idle 2프레임 4fps, walk 4프레임 6fps, run 4프레임 10fps
  - 레이어 아래→위: body(외형 단계 1~4), face(normal·sleepy·asleep), bottom, top, shoes, hat, accessory. 페이즈 2는 body·face 만
  - 파일: `assets/sprites/<레이어>/<이름>_<동작>.png` 예: `body/stage1_run.png`, `face/sleepy_idle.png`
  - 화면에서는 정수 배율로 키우고 `FilterQuality.none` 으로 그린다
- 아바타 이름 기본값 `러니`. 이름 바꾸기는 페이즈 3.
- 성장 코드는 `lib/avatar/` 아래에 둔다. `lib/run/` 의 기록 엔진·RunController 는 고치지 않는다.

## Review Focus

1. **경험치 반영 전 앱 종료**: 러닝은 저장됐지만 경험치를 쓰기 전에 앱이 죽으면, 다음 시작 때 `sync` 가 한 번만 준다. `sync` 를 여러 번 불러도 경험치가 늘지 않는다. 테스트는 Task 5.
2. **주 경계 러닝**: 일요일 23:50 에 시작해 월요일에 끝난 러닝은 시작한 주의 거리·목표에 들어간다. 테스트는 Task 1·5.
3. **목표를 바꾼 주**: 이미 달성한 주에 목표를 올려도 보너스는 회수하지 않는다. 이번 주 거리보다 낮게 내리면 바로 달성되고 보너스가 한 번 붙는다. 테스트는 Task 5.
4. **경험치 0 러닝**: 100m 미만이거나 모든 구간이 속도 검사에 걸린 러닝은 경험치 0 이고 음수가 되지 않는다. 테스트는 Task 1.
5. **최고 단계**: 레벨 20 이상이면 "다음 성장 단계까지" 대신 `최고 단계` 를 보이고 0으로 나누지 않는다. 테스트는 Task 1·9.

---

## 파일 구조

```
lib/
  core/week.dart                        weekStartOf (run 저장소와 공용)
  avatar/domain/growth_rules.dart       경험치·레벨·단계·표정·동작 계산
  avatar/domain/growth_state.dart       화면이 보는 성장 상태 값 객체
  avatar/domain/reminder_plan.dart      알림 예약 시각 계산
  avatar/data/growth_repository.dart    GrowthRepository 인터페이스
  avatar/data/drift_growth_repository.dart
  avatar/data/notification_scheduler.dart        인터페이스 + flutter_local_notifications 구현
  avatar/app/growth_service.dart        sync, 목표 변경, 상태 조회
  avatar/app/providers.dart
  avatar/ui/sprite_sheet.dart           스프라이트 규격 상수, 경로
  avatar/ui/avatar_view.dart            레이어 합성·프레임 애니메이션
  avatar/ui/avatar_screen.dart          아바타 탭
  avatar/ui/growth_summary.dart         요약 화면의 경험치·레벨업 영역
  avatar/ui/weekly_goal_bar.dart        홈의 주간 목표 막대·수정 창
  run/data/app_database.dart            테이블 추가, 스키마 2
  run/app/providers.dart                appDatabaseProvider 분리
  run/ui/home_screen.dart, in_run_screen.dart, summary_screen.dart, app.dart  연결
assets/sprites/body/, assets/sprites/face/
tool/gen_placeholder_sprites.dart       임시 스프라이트 생성
docs/specs/sprite-spec.md, docs/decisions/0009-phase2-packages.md
```

---

## 작업

- [ ] 1. 성장 규칙
- [ ] 2. 스프라이트 규격과 임시 스프라이트
- [ ] 3. 아바타 위젯
- [ ] 4. 성장 데이터 저장
- [ ] 5. GrowthService
- [ ] 6. 홈: 아바타·레벨·주간 목표
- [ ] 7. 러닝 중 아바타
- [ ] 8. 요약 화면 경험치·레벨업 연출
- [ ] 9. 아바타 탭
- [ ] 10. 주간 목표 알림
- [ ] 11. 실제 도트 스프라이트 (Aseprite 준비 뒤)

### Task 1: 성장 규칙

**Files:**
- Create: `lib/core/week.dart`, `lib/avatar/domain/growth_rules.dart`
- Modify: `lib/run/data/drift_run_repository.dart` (`weeklyTotal` 이 `weekStartOf` 사용), `docs/specs/game-rules.md`
- Test: `test/core/week_test.dart`, `test/avatar/domain/growth_rules_test.dart`

**Interfaces:**
- Produces:
  - `DateTime weekStartOf(DateTime t)` — 현지 월요일 0시 (현지 DateTime)
  - `int distanceXp(double distanceM, List<Split> splits)` — 속도 검사 뒤 100m당 1, 버림, 0 이상
  - `const int weeklyGoalBonusXp = 50;`
  - `class LevelProgress { final int level; final int xpIntoLevel; final int xpForNext; }` / `LevelProgress levelFor(int totalXp)`
  - `int xpToReachLevel(int level)` = 25 × level × (level − 1)
  - `int stageForLevel(int level)` (1~4), `const stageStartLevels = [1, 5, 10, 20];`
  - `int? xpToNextStage(int totalXp)` — 최고 단계면 null
  - `enum AvatarMood { normal, sleepy, asleep }` / `AvatarMood moodFor(DateTime? lastRunStartedAt, DateTime now)`
  - `enum AvatarAction { idle, walk, run }` / `AvatarAction actionFor({required bool paused, required double? currentPaceSecPerKm})`

- [ ] **Step 1:** 실패하는 테스트

```dart
test('5.02km 는 50', () => expect(distanceXp(5020, []), 50));
test('99m 는 0', () => expect(distanceXp(99, []), 0));
test('149초 구간은 빼고 150초 구간은 넣는다', () {
  final splits = [Split(index: 0, distanceM: 1000, duration: Duration(seconds: 149)),
                  Split(index: 1, distanceM: 1000, duration: Duration(seconds: 150))];
  expect(distanceXp(2500, splits), 15);
});
test('모든 구간이 너무 빠르면 남은 거리만', () {
  final s = [Split(index: 0, distanceM: 1000, duration: Duration(seconds: 100))];
  expect(distanceXp(1000, s), 0);
});
test('레벨 경계', () {
  expect(levelFor(0).level, 1);
  expect(levelFor(49).level, 1);
  expect(levelFor(50).level, 2);
  expect(levelFor(500).level, 5);
  expect(levelFor(9500).level, 20);
  expect(levelFor(120).xpIntoLevel, 70);
  expect(levelFor(120).xpForNext, 100);
});
test('단계 경계', () {
  expect([1, 4, 5, 9, 10, 19, 20, 99].map(stageForLevel), [1, 1, 2, 2, 3, 3, 4, 4]);
  expect(xpToNextStage(0), 500);
  expect(xpToNextStage(9500), isNull);
});
test('표정은 달력 날짜 차이', () {
  final now = DateTime(2026, 10, 20, 0, 10);
  expect(moodFor(null, now), AvatarMood.normal);
  expect(moodFor(DateTime(2026, 10, 18, 23, 59), now), AvatarMood.normal);
  expect(moodFor(DateTime(2026, 10, 17, 9), now), AvatarMood.sleepy);
  expect(moodFor(DateTime(2026, 10, 13, 9), now), AvatarMood.asleep);
});
test('동작', () {
  expect(actionFor(paused: true, currentPaceSecPerKm: 300), AvatarAction.idle);
  expect(actionFor(paused: false, currentPaceSecPerKm: null), AvatarAction.walk);
  expect(actionFor(paused: false, currentPaceSecPerKm: 541), AvatarAction.walk);
  expect(actionFor(paused: false, currentPaceSecPerKm: 540), AvatarAction.run);
});
test('일요일 23:50 은 그 주 월요일', () {
  expect(weekStartOf(DateTime(2026, 10, 18, 23, 50)), DateTime(2026, 10, 12));
});
```

- [ ] **Step 2:** `fvm flutter test test/avatar test/core` → FAIL
- [ ] **Step 3:** 구현. `weeklyTotal` 의 월요일 계산을 `weekStartOf` 로 바꾸고 기존 저장소 테스트가 그대로 통과하는지 본다.
- [ ] **Step 4:** `docs/specs/game-rules.md` 에 위 Global Constraints 의 확정 값(100m당 1 버림, 마지막 구간 검사 없음, 달력 날짜 기준 표정, 시작 시각 기준 주, 기본 목표 10km, 걷기·달리기 9'00", 알림 금요일 18:00)을 반영한다.
- [ ] **Step 5:** `fvm flutter test`, `fvm dart analyze` PASS
- [ ] **Step 6:** 커밋 `feat: 경험치·레벨·외형 단계·표정 규칙`

### Task 2: 스프라이트 규격과 임시 스프라이트

**Files:**
- Create: `docs/specs/sprite-spec.md`, `tool/gen_placeholder_sprites.dart`, `assets/sprites/body/stage{1..4}_{idle,walk,run}.png`, `assets/sprites/face/{normal,sleepy,asleep}_{idle,walk,run}.png`, `lib/avatar/ui/sprite_sheet.dart`, `docs/decisions/0009-phase2-packages.md`
- Modify: `pubspec.yaml` (dev `image`, `flutter: assets:`), `CLAUDE.md` 문서 지도에 sprite-spec 추가
- Test: `test/avatar/ui/sprite_assets_test.dart`

**Interfaces:**
- Produces (`sprite_sheet.dart`):
  - `const int spriteFramePx = 32;`
  - `int frameCount(AvatarAction a)` (idle 2, walk 4, run 4), `double fps(AvatarAction a)` (4, 6, 10)
  - `String bodySheet(int stage, AvatarAction a)` → `assets/sprites/body/stage<stage>_<action>.png`
  - `String faceSheet(AvatarMood m, AvatarAction a)` → `assets/sprites/face/<mood>_<action>.png`
  - `const spriteLayerOrder = ['body', 'face', 'bottom', 'top', 'shoes', 'hat', 'accessory'];`

- [ ] **Step 1:** 실패하는 테스트: 모든 body·face 조합 파일이 있고, `image` 패키지로 읽은 크기가 `(frameCount × 32) × 32` 이다.
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** `sprite-spec.md` 작성: 위 규격, 레이어 기준점(발끝이 프레임 아래에서 2px 위), 투명 배경, 팔레트 제한 없음, 실제 에셋은 파일만 교체.
- [ ] **Step 4:** `tool/gen_placeholder_sprites.dart` 작성. 단계마다 몸 크기·색을 다르게(단계가 오를수록 키 +3px), 프레임마다 다리·팔 위치를 바꿔 움직임이 보이게, face 는 눈 모양으로 표정 구분(기본 네모, 졸림 가로줄, 잠듦 가로줄 + `z`). `fvm dart run tool/gen_placeholder_sprites.dart` 로 PNG 를 만든다.
- [ ] **Step 5:** 결정 0009 작성: `image`(개발 의존성, 임시 스프라이트 생성), 이후 Task 10 의 알림 패키지도 이 문서에 추가한다.
- [ ] **Step 6:** PASS, 커밋 `feat: 스프라이트 규격과 임시 스프라이트`

### Task 3: 아바타 위젯

**Files:**
- Create: `lib/avatar/ui/avatar_view.dart`
- Test: `test/avatar/ui/avatar_view_test.dart`

**Interfaces:**
- Consumes: Task 1 `AvatarMood`, `AvatarAction`, Task 2 경로·프레임 함수
- Produces: `AvatarView({required int stage, required AvatarMood mood, required AvatarAction action, int scale = 4})` — 크기 `32 × scale` 정사각형. 레이어를 `spriteLayerOrder` 순서로 겹치고 `fps` 로 프레임을 넘긴다. 테스트용 `@visibleForTesting int get frameIndex`(State) 또는 `ValueKey('frame-<n>')` 를 노출한다.

- [ ] **Step 1:** 실패하는 테스트: `run` 에서 0ms → 프레임 0, 100ms → 1, 400ms → 0 (10fps, 4프레임). `action` 이 run → idle 로 바뀌면 프레임 0부터 2프레임 순환. 크기는 scale 4 일 때 128×128. body·face 두 레이어가 그려진다.
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현. `AnimationController.repeat` 로 Ticker 를 쓰고, 시트 이미지를 `CustomPainter` 의 `drawImageRect` 로 그린다(`FilterQuality.none`). 이미지 로딩 전에는 빈 영역.
- [ ] **Step 4:** PASS, 커밋 `feat: 레이어 스프라이트 아바타 위젯`

### Task 4: 성장 데이터 저장

**Files:**
- Modify: `lib/run/data/app_database.dart` (테이블 추가, `schemaVersion` 2, `migration`), `lib/run/app/providers.dart` (`appDatabaseProvider` 분리)
- Create: `lib/avatar/data/growth_repository.dart`, `lib/avatar/data/drift_growth_repository.dart`
- Modify: `docs/architecture.md` 데이터 모델 (WeeklyGoal 필드, XpTxn 고유 조건)
- Test: `test/avatar/data/drift_growth_repository_test.dart`, `test/run/data/migration_test.dart`

**Interfaces:**
- 테이블
  - `Avatars`: name, kind(`default`)
  - `WeeklyGoals`: weekStart(현지 날짜 `YYYY-MM-DD` 문자열, 고유), targetM, achievedAt(nullable)
  - `XpTxns`: amount, reason(`distance` | `weeklyGoal`), runId(nullable), weekStart(nullable). (runId, reason) 와 (weekStart, reason) 은 겹치지 않는다
- Produces:

```dart
abstract interface class GrowthRepository {
  Future<String> avatarName();                       // 행이 없으면 '러니' 로 만든다
  Future<int> totalXp();
  Future<Set<String>> runIdsWithDistanceXp();
  Future<void> addDistanceXp(String runId, int amount);        // 이미 있으면 무시
  Future<double> weeklyTarget(DateTime weekStart);   // 그 주 행, 없으면 이전 주 중 최근 행, 없으면 10000
  Future<void> setWeeklyTarget(DateTime weekStart, double targetM);
  Future<bool> isWeekAchieved(DateTime weekStart);
  Future<void> markWeekAchieved(DateTime weekStart, DateTime at, int bonusXp);  // 한 트랜잭션, 이미 달성이면 무시
  Future<List<DateTime>> achievedWeeks();            // 최신순
}
```

- `final appDatabaseProvider = Provider<AppDatabase>(...)`; `runRepositoryProvider` 는 이것을 쓴다.

- [ ] **Step 1:** 실패하는 테스트(인메모리 `NativeDatabase`): 기본 이름 `러니`, 같은 runId 로 두 번 넣어도 합계 한 번, 목표 이어받기(10/12 주 12km → 10/19 주 조회 12km), `markWeekAchieved` 두 번 불러도 보너스 50 한 번.
- [ ] **Step 2:** 마이그레이션 테스트: 페이즈 1 스키마(runs·run_points·splits, `PRAGMA user_version = 1`)에 러닝 1건을 넣은 DB 를 열면 새 테이블이 생기고 러닝이 남아 있다.
- [ ] **Step 3:** FAIL 확인
- [ ] **Step 4:** 구현, `fvm dart run build_runner build`
- [ ] **Step 5:** PASS, 커밋 `feat: 경험치·주간 목표 저장과 스키마 2`

### Task 5: GrowthService

**Files:**
- Create: `lib/avatar/domain/growth_state.dart`, `lib/avatar/app/growth_service.dart`, `lib/avatar/app/providers.dart`
- Test: `test/avatar/app/growth_service_test.dart`

**Interfaces:**
- Consumes: `RunRepository.listRuns()`, `getRun(id)`, `weeklyTotal(now)`; Task 4 `GrowthRepository`; Task 1 규칙; `clockProvider`
- Produces:

```dart
class GrowthState {
  final String name; final int totalXp; final LevelProgress level; final int stage;
  final int? xpToNextStage; final AvatarMood mood;
  final double weekTargetM; final double weekDistanceM; final bool weekAchieved;
  final int streakWeeks; final double totalDistanceM; final int runCount;
}
class GrowthGain {          // 이번 sync 에서 새로 받은 것
  final int distanceXp; final int goalBonusXp; final int levelBefore; final int levelAfter;
  final int stageBefore; final int stageAfter;
  bool get leveledUp; bool get stageUp; bool get isEmpty;
}
class GrowthService {
  Future<GrowthGain> sync();
  Future<GrowthState> load();
  Future<GrowthGain> setWeeklyTarget(double targetM);   // 바꾼 뒤 sync
}
final growthServiceProvider = Provider<GrowthService>(...);
final growthStateProvider = FutureProvider<GrowthState>(...);  // sync 뒤 load
```

- 연속 달성 주수: 이번 주가 달성이면 이번 주부터, 아니면 지난주부터 거꾸로 이어진 달성 주 수.
- `sync`: 경험치가 없는 완료 러닝마다 `getRun` 으로 구간을 읽어 `distanceXp` 를 쓰고, 그 러닝이 속한 주의 거리 합계가 목표 이상이면 `markWeekAchieved`. 이번 주도 매번 판정한다(목표를 내린 경우).

- [ ] **Step 1:** 실패하는 테스트(가짜 RunRepository + 인메모리 GrowthRepository)
  - 5.02km 러닝 1건 → gain.distanceXp 50, 레벨 1→2
  - `sync` 두 번째 호출은 `isEmpty`, totalXp 그대로
  - 목표 10km, 이번 주 6km + 5km → 두 번째 러닝 sync 에서 goalBonusXp 50
  - 일요일 23:50 시작 러닝은 그 주에 들어간다
  - 달성 뒤 목표를 20km 로 올려도 weekAchieved 유지·보너스 그대로
  - 이번 주 6km 에서 목표를 5km 로 내리면 setWeeklyTarget 의 gain.goalBonusXp 50
  - 달성 주가 이번 주·지난주·3주 전이면 streakWeeks 2, 이번 주 미달성·지난주·2주 전 달성이면 2
  - 마지막 러닝 4일 전 → mood sleepy
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS, 커밋 `feat: 성장 동기화와 상태`

### Task 6: 홈 — 아바타·레벨·주간 목표

**Files:**
- Create: `lib/avatar/ui/weekly_goal_bar.dart`
- Modify: `lib/run/ui/home_screen.dart`, `test/run/ui/fakes.dart`(가짜 GrowthService)
- Test: `test/run/ui/home_screen_test.dart`, `test/avatar/ui/weekly_goal_bar_test.dart`

**Interfaces:**
- Consumes: `growthStateProvider`, `growthServiceProvider`, `AvatarView`
- Produces: `WeeklyGoalBar({required double targetM, required double distanceM, required int streakWeeks, required ValueChanged<double> onChangeTarget})`

화면(와이어프레임 01): 위 `이번 주 목표 10km` / `6.20km 달성` + 진행 막대, 그 아래 `N주 연속 달성`(0이면 숨김). 가운데 `AvatarView(action: idle)`, `러니 Lv.3`, 레벨 진행 막대, `다음 레벨까지 8.4km`(남은 경험치 ÷ 10, 소수 첫째 자리). 아래 시작 버튼. 기존 `이번 주 ... km · N회` 문구는 목표 막대로 대체한다.

- [ ] **Step 1:** 실패하는 테스트: 위 문구들이 보인다. 목표 막대를 탭하면 수정 창(숫자 입력, km, 1~200)이 열리고 `15` 저장 시 `setWeeklyTarget(15000)` 이 불린다. 0이나 빈 값은 저장 버튼이 꺼진다. 기존 홈 테스트가 그대로 통과한다(문구가 바뀐 테스트는 새 문구로 고친다).
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현. 러닝이 끝나 홈으로 돌아오면 `growthStateProvider` 를 다시 읽는다. 복구 다이얼로그에서 "종료하고 저장" 뒤에도 다시 읽는다.
- [ ] **Step 4:** PASS, 커밋 `feat: 홈에 아바타·레벨·주간 목표`

### Task 7: 러닝 중 아바타

**Files:**
- Modify: `lib/run/ui/in_run_screen.dart`
- Test: `test/run/ui/in_run_screen_test.dart`

**Interfaces:**
- Consumes: `runControllerProvider` 스냅샷, `actionFor`, `growthStateProvider`(단계·표정. 로딩 중이면 단계 1·기본)

- [ ] **Step 1:** 실패하는 테스트: 기록 중 현재 페이스 300 → `AvatarView.action == run`, 600 → walk, null → walk, 일시정지 → idle. 거리 숫자는 여전히 가장 크게 보인다.
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 거리 아래, 지표 위에 `AvatarView(scale: 3)` 를 둔다(와이어프레임 03). 표정은 러닝 중이므로 항상 기본.
- [ ] **Step 4:** PASS, 커밋 `feat: 러닝 중 달리는 아바타`

### Task 8: 요약 화면 경험치·레벨업 연출

**Files:**
- Create: `lib/avatar/ui/growth_summary.dart`
- Modify: `lib/run/ui/summary_screen.dart`(`fromSummary` 에 `GrowthGain? gain` 추가), `lib/run/ui/home_screen.dart`(`_openInRun` 에서 `sync` 후 gain 전달)
- Test: `test/avatar/ui/growth_summary_test.dart`, `test/run/ui/summary_screen_test.dart`, `test/run/ui/home_screen_test.dart`

**Interfaces:**
- Produces: `GrowthSummary({required GrowthGain gain, required String name})`

화면(와이어프레임 05 + 06, 코인 줄 없음): 요약 위쪽에 `경험치 +50` 행(`달린 거리 5.02km`), 주간 목표 달성이면 `이번 주 목표 10km 달성 · 경험치 +50` 행. 레벨업이면 `레벨 업!` / `Lv.3 에서 Lv.4 로` 와 아바타가 커졌다 돌아오는 연출(0.6초). 단계가 올랐으면 `새 외형 단계!` 문구와 이전 단계 → 새 단계 아바타가 바뀌는 연출. 기록 목록에서 연 상세(`forRun`)에는 성장 영역이 없다.

- [ ] **Step 1:** 실패하는 테스트: gain(50, 0, 1→2) → `경험치 +50`, `레벨 업!`, `Lv.1 에서 Lv.2 로`. 레벨업 없는 gain → `레벨 업!` 없음. gain 비어 있음(경험치 0) → `경험치 +0` 표시. 홈에서 러닝 종료 → `sync` 한 번 호출 후 요약에 gain 이 들어간다. `sync` 가 실패해도 요약은 열리고 성장 영역만 빠진다.
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS, 커밋 `feat: 요약 화면 경험치 획득·레벨업 연출`

### Task 9: 아바타 탭

**Files:**
- Create: `lib/avatar/ui/avatar_screen.dart`
- Modify: `lib/app.dart`(세 번째 탭), 삭제: `lib/avatar/ui/avatar_placeholder.dart`
- Test: `test/avatar/ui/avatar_screen_test.dart`, `test/app_test.dart`

화면(와이어프레임 07, 옷장·업적 버튼 없음): `AvatarView(idle, 현재 표정)`, `러니 Lv.4`, `누적 34.80km · 러닝 12회`, 단계 진행 막대와 `다음 성장 단계까지 15.2km`(최고 단계면 `최고 단계`). `성장 단계` 목록 4행: `1단계 알·새싹 · Lv.1~4`, `2단계 어린 러너 · Lv.5~9`, `3단계 러너 · Lv.10~19`, `4단계 마라토너 · Lv.20~`. 현재 단계는 `현재`, 위 단계는 `잠김`, 아래 단계는 `달성`. 각 행에 그 단계 아바타 미리보기(잠김은 흐리게).

- [ ] **Step 1:** 실패하는 테스트: 위 문구, 단계 상태 표시, totalXp 9500 이면 `최고 단계`.
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현
- [ ] **Step 4:** PASS, 커밋 `feat: 아바타 탭`

### Task 10: 주간 목표 알림

**Files:**
- Create: `lib/avatar/domain/reminder_plan.dart`, `lib/avatar/data/notification_scheduler.dart`
- Modify: `pubspec.yaml`, `android/app/build.gradle.kts`(core library desugaring), `android/app/src/main/AndroidManifest.xml`(예약 알림 receiver, `RECEIVE_BOOT_COMPLETED`), `lib/avatar/app/growth_service.dart`(sync 뒤 재예약), `docs/decisions/0009-phase2-packages.md`
- Test: `test/avatar/domain/reminder_plan_test.dart`, `test/avatar/app/growth_service_test.dart`

**Interfaces:**
- Produces:
  - `class PlannedReminder { final DateTime at; final String body; }`
  - `List<PlannedReminder> planReminders({required DateTime now, required double weekTargetM, required double weekDistanceM, required bool weekAchieved})`
  - `abstract interface class NotificationScheduler { Future<void> replaceAll(List<PlannedReminder> reminders); }` — 이전 예약을 모두 지우고 새로 예약. 구현은 `flutter_local_notifications` 의 `zonedSchedule`(`AndroidScheduleMode.inexactAllowWhileIdle`), 시간대는 `flutter_timezone` + `timezone`. 처음 예약할 때 Android 13 알림 권한을 요청한다.
- 문구: 이번 주 `이번 주 목표까지 3.80km 남았어요`, 이후 주 `이번 주 목표 10km, 러니와 달려 볼까요?` (제목 `러니`)

- [ ] **Step 1:** 실패하는 테스트
  - 수요일, 목표 10km, 6.2km → 이번 주 금 18:00(본문 `3.80km 남았어요`) + 다음 3주 금 18:00, 총 4개
  - 이번 주 달성 → 다음 3주만
  - 금요일 18:01 → 이번 주 것 없음, 다음 3주
  - `sync` 뒤 `replaceAll` 이 한 번 불린다(가짜 스케줄러)
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현. 결정 0009 에 `flutter_local_notifications`, `timezone`, `flutter_timezone` 추가 근거와 inexact 예약(정확한 알람 권한 불필요)을 적는다.
- [ ] **Step 4:** `fvm flutter test`, `fvm dart analyze`, `fvm flutter build apk --debug` PASS
- [ ] **Step 5:** 커밋 `feat: 주간 목표 잔여 금요일 알림`

### Task 11: 실제 도트 스프라이트 (Aseprite 준비 뒤)

선행 조건: Aseprite 1.3 이상 설치, `/pixel-plugin:pixel-setup` 으로 aseprite MCP 연결. 준비 전이면 이 작업만 남기고 검증으로 넘어간다.

**Files:**
- Modify: `assets/sprites/body/*.png`, `assets/sprites/face/*.png`
- Create: `design/sprites/*.aseprite` (원본)
- Test: Task 2 의 `sprite_assets_test.dart` 가 그대로 통과해야 한다

- 스킬: `pixel-plugin:pixel-art-creator`, `pixel-plugin:pixel-art-animator`, `pixel-plugin:pixel-art-exporter`

- [ ] **Step 1:** `docs/specs/sprite-spec.md` 규격으로 외형 4단계(알·새싹, 어린 러너, 러너, 마라토너) body 를 그린다. 단계마다 idle 2·walk 4·run 4 프레임.
- [ ] **Step 2:** face 레이어 3종(기본·졸림·잠듦)을 body 동작 프레임에 맞춰 그린다.
- [ ] **Step 3:** 동작별 가로 시트 PNG 로 내보내 같은 경로에 덮어쓴다.
- [ ] **Step 4:** `fvm flutter test` PASS, 에뮬레이터에서 홈·러닝 중·아바타 탭 확인
- [ ] **Step 5:** 커밋 `feat: 기본 캐릭터 도트 스프라이트`

---

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 전체 통과
- [ ] `fvm dart analyze` 경고 0
- [ ] `fvm flutter build apk --debug` 성공
- [ ] 에뮬레이터 가상 러닝(`fvm dart run tool/fake_run.dart --minutes 6 --speed 3.0`)으로 1km 이상 달리면 요약에 경험치가 붙고, 홈 레벨 막대가 늘어난다

### 사람 확인
- [ ] Aseprite 설치와 `/pixel-plugin:pixel-setup` 연결 (Task 11 선행 조건)
- [ ] 실제 러닝 1회로 경험치 획득부터 레벨업 연출까지 확인 (레벨 1 에서 5km 이상이면 레벨업)
- [ ] 금요일 18:00 에 주간 목표 알림이 오는지 실기기 확인
- [ ] 지인 베타에서 아바타 때문에 다시 달리고 싶은지 의견 수집

## 자동 결정

없음
