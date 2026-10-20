# 페이즈 3.5 구현 계획

- 상태: 실행
- 모드: 자동
- 범위: docs/roadmap.md 페이즈 3.5 오늘 목표와 보상 규칙 (결정 0018)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈에서 오늘 목표 거리를 고르고 바로 달리며, 목표를 채운 러닝은 달성 보너스를 받는다. 주간 목표는 빼고, 차량 같은 빠른 이동은 자동으로 끝낸다.

**Architecture:** 목표는 `Runs.goalM`(스키마 v4)에 러닝마다 저장한다. 경험치는 러닝마다 거리 행과 달성 보너스 행(`XpTxns.reason = runGoal`)을 한 트랜잭션으로 맞추는 `setRunXp` 로 쌓고, 러닝 삭제는 경험치를 건드리지 않는다. 주간 목표 계산·화면·알림은 지우되 저장된 행(WeeklyGoals, weeklyGoal 경험치)은 남긴다. 빠른 이동은 기록 엔진이 연속한 원시 점 사이 속도로 재고, 자동 종료 규칙(`checkAutoEnd`)에 세 번째 사유로 들어간다.

**Tech Stack:** Flutter 3.47.7 (FVM), drift(스키마 v4), riverpod, flutter_local_notifications

**Spec:** 결정 0018, `docs/specs/game-rules.md`(경험치·오늘 목표·기록 삭제·끝부분 잘라내기), `docs/specs/run-engine.md`(자동 종료), `docs/screens.md`, `docs/product.md` F6·F18, `docs/architecture.md`(데이터 모델)

## Global Constraints

- 오늘 목표: 3·5·10km 또는 직접 입력 3~100km(1km 단위 정수). 기본값은 가장 최근에 시작한 러닝의 목표, 없으면 3km.
- 거리 경험치 = `distanceXp` (기존 그대로). 달성 보너스 = 목표 km × 5. 달성 = (거리 − 빠른 구간 거리) ≥ 목표.
- 빠른 이동: 연속한 두 점(정확도 거름 통과) 사이 속도 > 초속 8.33m(시속 30km) 가 30초 이어지면 자동 종료. 끝 시각 = 빨라지기 전 마지막으로 받아들인 점, 없으면 이번 기록 구간 시작·재개 시각.
- 러닝 삭제는 경험치를 무르지 않는다. 끝부분 잘라내기는 거리 경험치·달성 보너스를 다시 매긴다.
- 기존 데이터는 지우지 않는다: WeeklyGoals 행, `weeklyGoal` 경험치 행은 남고 총 경험치에 그대로 들어간다.
- 모든 데이터 접근은 저장소 인터페이스를 거친다(결정 0001). 디자인 값은 `lib/core/theme.dart` 토큰만 쓴다.
- Android 기준으로 만들고 확인한다. 새 패키지는 넣지 않는다.
- 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **기존 사용자 업그레이드**: v3 DB(목표 없는 러닝, 주간 보너스 경험치, 예약된 금요일 알림)를 v4 로 올리면 러닝·경험치·레벨이 그대로고, 목표 없는 러닝은 보너스를 받지 않으며, 예약된 주간 알림은 지워진다. 테스트는 Task 1·2.
2. **강제 종료 복원**: 앱이 죽었다 살아나 복원한 러닝도 시작 때 고른 목표를 쓴다. 테스트는 Task 4.
3. **잘라내기로 달성 → 미달**: 보너스를 무르고 요약이 줄어든 경험치·레벨을 보여 준다. 다시 늘리면(같은 끝) 결과가 같다. 테스트는 Task 3.
4. **빠른 구간 때문에 미달**: 기록 거리는 목표 이상인데 빠른 구간을 빼면 미달이면 보너스가 없고 요약이 이유를 보여 준다. 테스트는 Task 3·6.
5. **GPS 튐 한 번**: 빠른 점 한두 개 뒤 정상 속도 점이 오면 빠른 이동 시간이 0으로 돌아가 러닝이 끝나지 않는다. 일시정지 동안에도 세지 않는다. 테스트는 Task 7.
6. **백업 호환**: 스키마 v3 백업 파일도 가져올 수 있고(목표 없음), v4 파일은 목표까지 왕복한다. 테스트는 Task 1.

---

## 작업

- [x] 1. 러닝 목표 저장 (스키마 v4)
  - 파일: `lib/run/data/app_database.dart`(+ `.g.dart`), `lib/run/data/run_repository.dart`, `lib/run/data/drift_run_repository.dart`, `lib/backup/domain/backup_codec.dart`, `lib/run/app/run_controller.dart`(호출부만), 관련 테스트
  - 스키마: `Runs.goalM` real nullable. `schemaVersion` 4, `from < 4` 이면 `addColumn(runs, runs.goalM)`.
  - 인터페이스:
    - `Future<String> createActiveRun(DateTime startedAt, {required double goalM})`
    - `RunListItem.goalM` (`double?`), `ActiveRun.goalM` (`double?`)
    - `Future<double?> lastGoalM()`: 시작 시각이 가장 늦은 러닝(진행 중·완료·삭제 표시 모두)의 목표. 러닝이 없거나 목표가 없으면 null
  - 백업: `currentSchemaVersion` 4. `decode` 는 3·4 를 받는다(3 이면 러닝에 목표가 없다). 내보내기는 4.
  - 컨트롤러는 이 작업에서 `start()` 가 임시로 3000 을 넘긴다(Task 4 가 바꾼다).
  - 테스트: 목표를 저장한 러닝이 목록·상세·진행 중 복원에 같은 목표로 나온다. `lastGoalM` 이 없음 → null, 여러 러닝 → 가장 최근 시작 러닝 값(지운 러닝 포함). v3 → v4 마이그레이션 뒤 기존 러닝 유지·목표 null(`migration_test` 확장). v3 백업 파일 가져오기 성공, v4 왕복에 목표 유지, v2 는 거부.
  - 확인: `fvm flutter test test/run/data test/backup`

- [x] 2. 주간 목표 제거
  - 파일: `lib/avatar/app/growth_service.dart`, `lib/avatar/domain/growth_state.dart`, `lib/avatar/data/growth_repository.dart`, `lib/avatar/data/drift_growth_repository.dart`, `lib/avatar/data/notification_scheduler.dart`, `lib/avatar/app/providers.dart`, `lib/run/ui/home_screen.dart`, `lib/run/ui/summary_screen.dart`, `lib/avatar/ui/growth_summary.dart`, `lib/onboarding/ui/onboarding_screen.dart`, `lib/settings/ui/settings_screen.dart`, `lib/app.dart` 또는 `lib/main.dart`(시작 때 알림 취소)
  - 지우는 파일: `lib/avatar/ui/weekly_goal_bar.dart`, `lib/avatar/ui/weekly_target_change.dart`, `lib/avatar/domain/reminder_plan.dart` 와 그 테스트
  - 지우는 것: `GrowthState` 의 `weekTargetM`·`weekDistanceM`·`weekAchieved`·`streakWeeks`, `GrowthService.setWeeklyTarget`·주 판정(`_rejudgeWeek`·`_awardWeekIfReached`)·재예약, 저장소의 `weeklyTarget`·`setWeeklyTarget`·`isWeekAchieved`·`markWeekAchieved`·`unmarkWeekAchieved`·`achievedWeeks`, `weeklyGoalBonusXp`
  - 알림: `NotificationScheduler` 를 `Future<void> cancelScheduled()`(예약된 알림 모두 취소, 즉시 알림은 그대로) 하나로 바꾸고, 앱 시작 때 한 번 부른다. 실패는 로그만 남긴다. `InstantNotifier` 는 그대로다.
  - 화면: 홈의 주간 목표 카드를 뺀다(그 자리는 Task 4 가 채운다). 첫 실행은 캐릭터 소개·이름 짓기 2장으로, 2장의 버튼이 첫 실행을 마친다. 설정에서 주간 목표 줄을 뺀다. 요약의 주간 목표 문구를 뺀다.
  - 테스트: 기존 주간 목표 테스트를 지우고, 남은 테스트를 새 구조로 고친다. 총 경험치에 기존 `weeklyGoal` 행이 들어간다. 시작 때 `cancelScheduled` 를 한 번 부른다(가짜 스케줄러). 첫 실행이 2장으로 끝난다. 설정에 "주간 목표" 글자가 없다.
  - 확인: `fvm dart analyze`, `fvm flutter test`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 3. 러닝 보상: 달성 보너스, 삭제 유지, 잘라내기 재계산
  - 파일: `lib/avatar/domain/growth_rules.dart`, `lib/avatar/data/growth_repository.dart`, `lib/avatar/data/drift_growth_repository.dart`, `lib/avatar/app/growth_service.dart`, `lib/run/ui/summary_screen.dart`(삭제 흐름), `lib/run/data/run_repository.dart`(주석)
  - 규칙:
    - `const int goalBonusXpPerKm = 5`
    - `bool goalAchieved({required double distanceM, required List<Split> splits, required double goalM})`: `distanceM − excludedFastDistanceM(splits) >= goalM`
    - `int goalBonusXp(double goalM)`: `(goalM / 1000).round() * goalBonusXpPerKm`
  - 저장소: `addDistanceXp`·`revokeDistanceXp` 를 아래로 바꾼다.
    - `Future<void> setRunXp(String runId, {required int distanceXp, required int goalBonusXp})`: 한 트랜잭션. 거리 행을 그 값으로 만들거나 살린다. 보너스가 0보다 크면 `runGoal` 행을 만들거나 살리고, 0이면 그 행에 삭제 표시를 한다.
    - `Future<void> revokeRunXp(String runId)`: 그 러닝의 거리·보너스 행에 삭제 표시.
    - `runIdsWithDistanceXp`·`distanceXpUpdatedAts` 는 그대로.
  - 서비스:
    - `sync`: 거리 경험치가 없는 러닝마다 `setRunXp(거리, 달성이면 보너스)`. gain 의 `goalBonusXp` 는 이번에 받은 달성 보너스 합.
    - `runRemoved` 를 지운다. 자가 복구에서 삭제 표시된 러닝은 경험치를 그대로 둔다. 저장소에 행이 아예 없는 러닝(백업 가져오기)만 `revokeRunXp`.
    - `runRevised`: 그 러닝을 `setRunXp` 로 다시 매기고, 거리 차이·보너스 차이·전후 레벨을 돌려준다.
  - 삭제: 요약 화면의 삭제는 `deleteRun` 만 부른다. 확인 창 문구는 "기록에서 지워요. 받은 경험치는 그대로예요."
  - 테스트: 10km 목표로 5km → +50, 5km 목표로 5km → +75, 5km 목표로 7km → +95. 목표 없는 예전 러닝은 보너스 0. 빠른 구간을 빼면 미달 → 보너스 0. 지운 러닝은 경험치·레벨 유지, 다음 sync 도 유지. 잘라내 미달이 되면 보너스 행 삭제 표시와 gain 의 보너스 −25, 다시 같은 끝으로 부르면 차이 0. `setRunXp` 두 번 불러도 행이 두 개씩 생기지 않는다.
  - 확인: `fvm flutter test test/avatar test/run/ui/summary_screen_test.dart`

- [x] 4. 홈: 오늘 목표 고르고 시작
  - 파일: `lib/run/ui/run_goal_picker.dart`(새 파일), `lib/run/ui/home_screen.dart`, `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`
  - 인터페이스:
    - `RunController.start({required double goalM})`, `RunViewState.goalM` (`double?`, 러닝 중·복원 때 채움)
    - `lastRunGoalProvider`: `FutureProvider.autoDispose<double>` = `lastGoalM() ?? 3000`
    - `RunGoalPicker({required double goalM, required ValueChanged<double> onChanged})`: "오늘 목표" 라벨, 3·5·10km 알약 칩, "직접" 칩. 직접은 숫자 입력 창(3~100, 범위 밖이면 저장 버튼 비활성과 안내). 고른 값이 3·5·10 이 아니면 "직접" 칩에 "12km" 처럼 값을 보인다.
  - 배치: 홈 주간 목표 카드 자리(위쪽)에 놓는다. 시작 버튼은 그대로 하나이고, 누르면 고른 목표로 시작한다. 칩 높이 48 이상, 선택 칩은 `primary` 바탕.
  - 복원: `restoreIfAny` 가 `ActiveRun.goalM` 을 상태에 넣는다(없으면 null).
  - 테스트: 러닝이 없으면 3km 가 골라져 있다. 최근 러닝 목표가 5km 면 5km 가 골라져 있다. 10km 를 누르고 시작하면 저장된 진행 중 러닝의 목표가 10000. 직접 입력 12 → 12km 로 시작, 2·101·빈 값은 저장 불가. 복원한 러닝의 상태 `goalM` 이 저장된 값과 같다. 360×640, 글자 1.3배에서 넘침 없음. 다크 테마로 그려진다.
  - 확인: `fvm flutter test test/run`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 5. 러닝 중: 목표 진행과 달성 알림
  - 파일: `lib/run/app/run_controller.dart`, `lib/run/ui/in_run_screen.dart`
  - 동작: 컨트롤러가 기록 거리가 목표 이상이 되는 첫 순간에 `RunViewState.goalReached = true` 로 바꾸고 `InstantNotifier.showNow(title: '목표 달성!', body: '<목표>km 목표를 채웠어요. 종료할 때까지 기록은 이어져요')` 를 한 번 부른다(실패는 버린다). 화면은 거리 아래에 "목표 5km" 와 진행 막대(`ClayBar`)를 보이고, 달성 뒤에는 "목표 달성!"(`success`)으로 바꾸며 `HapticFeedback.mediumImpact()` 를 한 번 한다.
  - 테스트: 목표 3km, 2.99km 까지 알림 0회·막대 진행, 3.00km 에서 알림 1회·상태 달성, 더 달려도 알림 1회 그대로. 복원한 러닝이 이미 목표를 넘었으면 다시 알리지 않는다. 360×640, 글자 1.3배에서 넘침 없음.
  - 확인: `fvm flutter test test/run`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [ ] 6. 요약: 달성·미달 표시
  - 파일: `lib/avatar/ui/growth_summary.dart`, `lib/run/ui/summary_screen.dart`, `lib/run/ui/home_screen.dart`(요약 여는 곳)
  - 인터페이스: `GrowthSummary({..., required double? goalM, required bool achieved, ...})`(주간 목표 인자 대신). `SummaryScreen.fromSummary(summary, gain:, goalM:)`, 기록에서 여는 요약은 `RunListItem.goalM` 을 쓴다.
  - 표시:
    - 달성: 거리 줄 "경험치 +N" 아래 "목표 5km 달성" / "보너스 +25" 줄(`success`).
    - 미달: "목표 10km까지 4.98km 남았어요" 안내(보조 글자색, 빨강 금지).
    - 기록 거리는 목표 이상인데 빠른 구간 때문에 미달: "빠른 이동을 빼면 목표에 못 미쳤어요".
    - 목표 없는 예전 러닝: 목표 줄 없음.
    - 잘라내기 뒤에는 바뀐 달성·미달로 다시 그린다.
  - 테스트: 위 네 경우 문구. 잘라내 미달이 되면 보너스 줄이 사라지고 남은 거리 안내가 보인다. 360×640, 글자 1.3배에서 넘침 없음.
  - 확인: `fvm flutter test test/avatar/ui test/run/ui`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [ ] 7. 빠른 이동 자동 종료
  - 파일: `lib/run/domain/run_engine.dart`, `lib/run/app/run_guard.dart`, `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`(dart-define), `docs/specs/run-engine.md`(검증 줄), `tool/fake_run.dart`(필요하면)
  - 엔진: 정확도 거름을 통과한 원시 점끼리 속도를 잰다. 시속 30km 초과 점이 오면 `fastSince`(그 연속의 첫 빠른 점 시각)와 `lastAcceptedBeforeFast`(그 순간의 마지막 받아들인 점 시각)를 잡고, 이하인 점이 오거나 일시정지·재개하면 둘 다 null 로 돌린다. 거리 계산은 바꾸지 않는다.
  - 규칙: `autoEndFast = Duration(seconds: 30)`, `RunGuardConfig.fast`, `AutoEndReason.fast`. `checkAutoEnd` 에 `fastSince`·`beforeFastAt` 인자를 더하고, 기록 중이고 `now − fastSince ≥ fast` 면 `beforeFastAt ?? recordingSince ?? startedAt` 에 끝낸다. 판정 순서는 빠른 이동 → 20분 → 6시간.
  - 컨트롤러: 빠른 이동으로 끝나면 알림 제목 "빠른 이동이 감지돼 러닝을 마쳤어요", 본문은 지금 자동 종료와 같다. 디버그 빌드 `--dart-define=RUN_AUTO_END_FAST_SEC` 로 기준을 줄일 수 있다.
  - 테스트: 초속 10m 점이 30초 이어지면 끝, 끝 시각은 빨라지기 전 마지막 점. 29초면 계속. 빠른 점 2개 뒤 초속 3m 점이 오면 다시 0부터. 일시정지 중에는 세지 않는다. 끝난 요약의 거리에 빠른 구간이 없다. 알림 제목.
  - 확인: `fvm flutter test test/run`

- [ ] 8. 시안·문서 반영
  - 파일: `design/mockups/README.md`, `docs/screens.md`, `docs/specs/run-engine.md`, `HANDOFF.md`
  - 내용: 구현한 홈(오늘 목표)·러닝 중(목표 진행)·요약(달성·미달) 화면을 에뮬레이터 스크린샷으로 떠 `design/mockups/README.md` 에 구현 메모를 더한다. 첫 실행 2장, 설정 변경을 반영한다. 시안 승인은 사람 확인으로 남긴다.
  - 확인: 문서에 주간 목표 화면 설명이 남아 있지 않다(`grep -rn "주간 목표" docs/screens.md design/mockups/README.md` 결과는 후속 범위 안내만).

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 통과
- [ ] `fvm dart analyze` 오류·경고 0
- [ ] `fvm flutter build apk --debug` 성공

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 데이터를 지운 첫 실행이 2장(캐릭터 소개·이름)으로 끝나고 홈에 주간 목표 카드가 없다. 오늘 목표 3km 가 골라져 있다.
- [ ] 5km 를 고르고 시작하면 러닝 중 화면에 "목표 5km" 와 진행 막대가 보인다.
- [ ] 목표 3km 로 가상 러닝 3.2km(`fake_run --minutes 18 --speed 3`): 3km 에서 "목표 달성!" 알림과 화면 표시, 종료 뒤 요약에 "목표 3km 달성 / 보너스 +15".
- [ ] 목표 10km 로 가상 러닝 1km 뒤 종료: 요약에 남은 거리 안내가 있고 보너스 줄이 없다.
- [ ] 다시 홈에 오면 마지막 목표가 골라져 있다.
- [ ] 기록에서 러닝을 지워도 홈의 레벨·다음 레벨까지 거리가 그대로다.
- [ ] `RUN_AUTO_END_FAST_SEC=10` 디버그 빌드에서 `fake_run --speed 10`: 10초 뒤 "빠른 이동이 감지돼 러닝을 마쳤어요" 알림, 요약이 열리고 빠른 구간 거리가 없다.
- [ ] 설정에 주간 목표 줄이 없다.

### 사람 확인
- [ ] 홈(오늘 목표)·러닝 중(목표 진행)·요약(달성·미달) 디자인 승인
- [ ] 결정 0018 초안 수치 확인: 달성 보너스 목표 1km당 5, 직접 입력 3~100km
- [ ] 실기기 확인은 페이즈 7 에서 한다

## 자동 결정

- 계획 승인 단계를 건너뛰었다(자동 모드, 사용자가 퇴근 전 진행 요청).
- 홈·러닝 중·요약 화면은 새 시안 없이 기존 디자인 시스템으로 바로 구현하고, 시안 승인은 사람 확인으로 남겼다.
- 목표 달성 진동은 즉시 알림(`InstantNotifier`)의 기본 진동과 화면이 켜져 있을 때 `HapticFeedback` 으로 한다. 진동 전용 패키지는 넣지 않는다.
- 예약된 금요일 알림은 앱 시작 때 한 번 모두 취소한다.
