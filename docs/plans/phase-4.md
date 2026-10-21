# 페이즈 4 구현 계획

- 상태: 실행
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 4 보상 (결정 0019·0020, F4·F9·F10·F11·F20)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 화면을 켜지 않고 알림으로 러닝 진행을 보고 멈출 수 있고, 멈추면 자동 일시정지된다. 달린 만큼 코인을 받아 상점에서 모자·소품을 사서 아바타에 입힌다.

**Architecture:** 작업은 기능별 다섯 묶음(A 러닝 알림, B 자동 일시정지, C 코인, D 아이템, E 상점·꾸미기)과 문서 정리(F)다. 러닝 알림은 위치 패키지의 포그라운드 서비스 알림(번호 75415)을 같은 번호의 우리 알림으로 덮어써 하나만 보인다. 자동 일시정지는 기록 엔진의 새 상태 `autoPaused` 이고, 오래 멈춘 러닝은 자동 종료 규칙(`checkAutoEnd`)이 예고 뒤 끝낸다. 코인은 경험치와 같은 자리(`GrowthService._rate`)에서 같은 트랜잭션으로 매기고(스키마 v5 `CoinTxns`), 상점은 별도 저장소(`ShopRepository`)가 잔액·구매·보유·장착을 맡는다. 아이템 그림은 머리에 붙는 부위(모자·소품)만 종류별 한 벌로 그려 face 처럼 머리 움직임을 따라간다.

**Tech Stack:** Flutter 3.47.7 (FVM), drift(스키마 v5), riverpod, flutter_local_notifications 22, geolocator 14, `dart:isolate`·`dart:ui` `IsolateNameServer`

**Spec:** 결정 0018·0019·0020, `docs/product.md` F4·F9·F10·F11·F20, `docs/specs/game-rules.md`(코인), `docs/specs/run-engine.md`(상태·자동 종료), `docs/specs/sprite-spec.md`, `docs/screens.md`, `docs/architecture.md`(데이터 모델), 와이어프레임 `design/wireframes/png/06-reward.png`·`08-shop.png`

## Global Constraints

- 새 패키지는 넣지 않는다. 알림 버튼은 flutter_local_notifications 의 `AndroidNotificationAction` 으로 만든다.
- 러닝 알림 번호는 geolocator 의 포그라운드 서비스 알림 번호 `75415` 와 같다. 채널은 우리 채널 `run_progress`(중요도 낮음, 소리·진동 없음, `onlyAlertOnce`).
- 자동 일시정지 기준(초안): 10초 동안 이동 5m 미만이면 멈춤. 10초 안에 받은 점이 3개 이상이고 그 첫 점과 마지막 점이 10m 이상 떨어지면 움직임.
- 자동 종료: 자동 일시정지 5분, 사용자 일시정지 1시간이 지나면 30초 예고 뒤 끝낸다. 끝 시각은 기록이 멈춘 시각. 시작부터 6시간·빠른 이동(시속 30km 30초)은 그대로. 기록 중 10분 무점 규칙은 없앤다.
- 코인: 거리 코인 = 거리 경험치 ÷ 2(소수점 버림, 1km당 5), 달성 코인 = 목표 km × 5. 러닝 삭제는 코인을 무르지 않고, 끝부분 잘라내기는 다시 매긴다.
- 이 업데이트 전에 경험치를 받은 러닝은 코인을 받지 않는다(잘라내도 받지 않는다).
- 아이템: 모자·소품 두 부위, 각 3개. 가격 100~400 코인. 실제 돈 결제는 없다(페이즈 7).
- 하단 탭은 러닝·기록·아바타·상점 4개.
- 모든 데이터 접근은 저장소 인터페이스를 거친다(결정 0001). 디자인 값은 `lib/core/theme.dart` 토큰만 쓴다. 문구는 한국어 존댓말 `-요` 체.
- Android 기준으로 만들고 확인한다. 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **업그레이드 사용자**: v4 DB 를 v5 로 올리면 러닝·경험치·레벨이 그대로고 잔액은 0이다. 예전 러닝을 잘라내도 코인이 생기지 않는다. 테스트는 Task 5·6.
2. **제자리 GPS 흔들림**: 서 있는데 정확도 10~20m 점이 4~8m 씩 흔들리면 자동 일시정지가 풀리지 않는다. 시속 3.6km(초속 1m) 로 걸으면 자동 일시정지되지 않는다. 테스트는 Task 3.
3. **앱이 죽은 뒤 알림 버튼**: 프로세스가 없거나 메인 isolate 포트가 없으면 버튼은 아무 일도 하지 않고 오류가 나지 않는다. 테스트는 Task 2.
4. **구매 두 번 누름·잔액 부족**: 같은 아이템을 빠르게 두 번 사도 한 번만 빠지고, 잔액이 모자라면 아무 행도 생기지 않는다. 테스트는 Task 5·10.
5. **백업 호환**: v4 백업 파일을 가져오면 코인·아이템 없이 열린다. v5 파일은 코인·보유·장착이 왕복한다. 테스트는 Task 5.
6. **자동 일시정지 중 사용자 일시정지**: 그때부터 1시간 규칙을 세고, 끝 시각은 처음 멈춘 시각이다. 강제 종료 뒤 복원한 러닝은 사용자 일시정지로 열린다. 테스트는 Task 3·4.

---

## 작업

### A. 러닝 알림 (F20, 결정 0019)

- [x] 1. 러닝 진행 알림
  - 파일: `lib/core/local_notifications.dart`(새 파일, 초기화 한 곳), `lib/avatar/data/notification_scheduler.dart`(초기화를 새 파일로), `lib/run/data/run_progress_notifier.dart`(새 파일), `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`, `lib/run/data/geolocator_location_source.dart`(채널 이름), `docs/decisions/0021-run-notification-overwrite.md`(새 결정)
  - 인터페이스:
    - `abstract interface class RunProgressNotifier { Future<void> show(RunProgressContent c); Future<void> cancel(); }`
    - `class RunProgressContent { final String title; final String body; final Duration? elapsed; final RunProgressAction action; }` — `elapsed` 가 있으면 크로노미터를 켠다(`when = now − elapsed`, `usesChronometer: true`). `enum RunProgressAction { pause, resume }`
    - `RunProgressContent runProgressContent({required RunState state, required double distanceM, required Duration movingTime, required double? goalM, required bool goalReached})` — 순수 함수
    - `runProgressNotifierProvider`
  - 문구:
    - 기록 중: 제목 `러닝 중 · 2.31km`, 본문 `목표 5km까지 2.69km`(달성 뒤 `목표 5km 달성!`, 목표 없음 `화면을 꺼도 기록이 이어져요`), 크로노미터 켬, 버튼 `일시정지`
    - 일시정지: 제목 `일시정지 · 2.31km · 12:34`, 본문은 기록 중과 같음, 크로노미터 끔, 버튼 `재개`
    - 자동 일시정지: 제목 `멈춰서 일시정지했어요 · 2.31km`, 본문 `움직이면 이어져요`, 버튼 `재개`
  - 갱신: 상태가 바뀌면 바로, 기록 중에는 화면 거리(10m 단위)가 바뀌었을 때만, 최소 3초 간격. 실패는 로그만 남긴다. 러닝이 끝나면 `cancel()`.
  - 결정 0021: 같은 번호 덮어쓰기를 고른 이유, 패키지 업데이트 때 `GeolocatorLocationService.ONGOING_NOTIFICATION_ID` 확인, 덮어쓰기가 안 되면 별도 알림 두 개로 바꾸는 대안.
  - 테스트: `runProgressContent` 세 상태 문구(목표 있음·달성·없음). 컨트롤러가 시작·거리 변화·일시정지·재개 때 `show` 를 부르고 3초 안의 거리 변화는 한 번으로 묶는다. 끝내면 `cancel`. 알림 실패가 러닝을 멈추지 않는다.
  - 확인: `fvm flutter test test/run`

- [x] 2. 알림 버튼으로 일시정지·재개
  - 파일: `lib/core/local_notifications.dart`, `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`, `lib/main.dart`
  - 동작: 알림 버튼 id 는 `run_pause`·`run_resume`(`showsUserInterface: false`). 앱이 살아 있으면 `onDidReceiveNotificationResponse` 가, 백그라운드 isolate 에서 받으면 최상위 `@pragma('vm:entry-point')` 함수가 `IsolateNameServer.lookupPortByName('run_notification_actions')` 로 메인 isolate 에 보낸다. 메인 isolate 는 시작 때 그 이름으로 포트를 등록하고(있던 이름은 먼저 지운다) `Stream<String> runNotificationActions` 로 내보낸다. 컨트롤러는 기록 중이면 `pause()`, 일시정지·자동 일시정지면 `resume()`. 맞지 않는 상태의 버튼은 무시한다.
  - 테스트: 액션 스트림에 `run_pause` → 일시정지, `run_resume` → 재개, 러닝이 없을 때는 무시. 포트가 없을 때 백그라운드 함수가 예외 없이 끝난다.
  - 확인: `fvm flutter test test/run test/core`

### B. 자동 일시정지와 종료 예고 (F4, 결정 0020)

- [x] 3. 기록 엔진 자동 일시정지·재개
  - 파일: `lib/run/domain/run_engine.dart`, `lib/run/app/run_controller.dart`, `lib/run/ui/in_run_screen.dart`, `lib/backup/app/providers.dart`
  - 인터페이스:
    - `RunState.autoPaused`
    - 상수 `autoPauseStill = Duration(seconds: 10)`, `autoPauseStillM = 5`, `autoResumeWindow = Duration(seconds: 10)`, `autoResumeMoveM = 10`, `autoResumeMinPoints = 3`
    - `bool RunEngine.autoPauseIfStill(DateTime now)`: 기록 중이고 마지막 "움직인 점"(직전 움직인 점에서 5m 이상 떨어져 받아들인 점, 없으면 기록 구간 시작 시각) 뒤 10초가 지나면 그 시각(기록 구간 시작보다 이르지 않게)으로 `autoPaused` 가 되고 true.
    - `addSample` 은 `autoPaused` 에서 정확도 거름만 통과한 점을 10초 창에 모은다. 움직임이면 창의 첫 점 시각으로 `recording` 이 되고 창의 점들을 새 구간에 차례로 넣는다(튀는 값 거름 적용). `List<LocationSample> get lastAppended` 는 마지막 `addSample` 호출이 넣은 점들이다.
    - `pause()` 는 `recording`·`autoPaused` 에서, `resume()` 은 `paused`·`autoPaused` 에서, `end()` 는 `autoPaused` 에서도 된다.
    - `DateTime? get pausedAt`(기록이 멈춘 시각. 자동 일시정지 → 사용자 일시정지면 처음 값 유지), `DateTime? get stateSince`(지금 상태에 들어온 시각)
  - 컨트롤러: 1초 틱에서 `autoPauseIfStill` 을 부른다. `_onSample` 은 `lastAppended` 를 모두 저장 버퍼에 넣는다(구간 번호는 호출 뒤 `segmentIndex`). 자동 일시정지 중에도 위치 구독을 유지한다.
  - 화면: 자동 일시정지면 일시정지 화면에 제목 `멈춰서 일시정지했어요`, 그 아래 `움직이면 이어져요`(caption). `재개`·`길게 눌러 종료` 는 그대로.
  - 테스트: 초속 1m 로 걷는 점(2초 간격)이 이어지면 기록 중 유지. 마지막 점 뒤 10초면 자동 일시정지, 움직인 시간은 마지막 움직인 점까지. 정확도 15m 점이 제자리에서 4~8m 씩 흔들리면 풀리지 않는다. 10초 안에 3점·12m 이동이면 첫 점 시각으로 재개, 그 점들이 거리에 들어가고 자동 일시정지 동안은 움직인 시간에서 빠진다. 자동 일시정지 중 `pause()` → `paused`, `pausedAt` 유지. 화면 제목.
  - 확인: `fvm flutter test test/run`

- [x] 4. 오래 멈추면 예고 뒤 종료
  - 파일: `lib/run/app/run_guard.dart`, `lib/run/app/run_controller.dart`, `lib/run/data/run_progress_notifier.dart`, `lib/main.dart`, `tool/fake_run.dart`, `docs/specs/run-engine.md`
  - 규칙: `autoEndIdle`·`AutoEndReason.idle`·`RUN_AUTO_END_IDLE_SEC` 를 없애고 아래로 바꾼다.
    - 상수 `autoEndStill = Duration(minutes: 5)`, `autoEndPaused = Duration(hours: 1)`, `autoEndWarning = Duration(seconds: 30)`. `RunGuardConfig` 에 `still`·`paused`·`warning`.
    - `enum AutoEndReason { still, paused, maxDuration, fast }`
    - `checkAutoEnd({now, startedAt, required RunState state, pausedAt, stateSince, lastPointAt, recordingSince, fastSince, fastLastAt, beforeFastAt, config})`: 자동 일시정지이고 `now − stateSince ≥ still + warning` 이면 `still` 로 `pausedAt` 에, 사용자 일시정지이고 `≥ paused + warning` 이면 `paused` 로 `pausedAt` 에 끝낸다. 빠른 이동·6시간은 지금 그대로.
    - `DateTime? autoEndWarningDeadline({...같은 인자})`: 예고 구간(`limit ≤ now − stateSince < limit + warning`)이면 끝날 시각, 아니면 null.
  - 컨트롤러: 예고 구간에 들어가면 `RunProgressNotifier.showEndWarning(deadline)` 을 한 번 부르고(채널 `run_end_warning`, 중요도 높음, 진동, 번호 1001, 카운트다운 크로노미터, 제목 `움직이지 않으면 러닝을 마쳐요`, 본문 `30초 안에 움직이거나 재개를 누르세요`, 버튼 `재개`), 재개·종료되면 `cancelEndWarning()`. 끝낸 알림 문구는 지금 자동 종료와 같다.
  - 디버그 dart-define: `RUN_STILL_END_SEC`, `RUN_PAUSE_END_SEC`, `RUN_END_WARNING_SEC` 를 더한다(`RUN_AUTO_END_MAX_SEC`·`RUN_AUTO_END_FAST_SEC` 유지).
  - `tool/fake_run.dart`: `--stop-at <초> --stop-for <초>` 를 더해 그 사이에는 같은 좌표를 보낸다.
  - 문서: `docs/specs/run-engine.md` 자동 종료 표를 새 규칙으로 바꾸고 "구현 전" 문장을 지운다.
  - 테스트: 자동 일시정지 4분 59초엔 예고 없음, 5분에 예고 1회, 5분 29초 계속, 5분 30초에 `pausedAt` 으로 종료. 예고 중 재개하면 예고 취소·계속. 사용자 일시정지 1시간 + 30초 종료. 자동 일시정지 3분 뒤 사용자 일시정지 → 거기서 1시간을 다시 센다. 복원한 러닝은 사용자 일시정지로 1시간 규칙. 빠른 이동·6시간 테스트는 그대로 통과.
  - 확인: `fvm flutter test test/run`

### C. 코인 (F9)

- [x] 5. 저장 구조 v5
  - 파일: `lib/run/data/app_database.dart`(+ `.g.dart`), `lib/avatar/data/growth_repository.dart`, `lib/avatar/data/drift_growth_repository.dart`, `lib/shop/data/shop_repository.dart`(새 파일), `lib/shop/data/drift_shop_repository.dart`(새 파일), `lib/shop/app/providers.dart`(새 파일), `lib/backup/domain/backup_codec.dart`, `lib/backup/data/drift_backup_repository.dart`
  - 스키마 v5:
    - `CoinTxns`: id, amount(int, 지급 +, 구매 −), reason(`distance` | `runGoal` | `purchase`), runId(nullable, Runs 참조), itemId(nullable), createdAt, updatedAt, deletedAt. 고유 `{runId, reason}`.
    - `OwnedItems`: id, itemId(고유), createdAt, updatedAt, deletedAt.
    - `Avatars` 에 `hatItemId`·`accessoryItemId`(text nullable).
    - `from < 5` 이면 두 테이블을 만들고 두 열을 더한다.
  - 인터페이스:
    - `GrowthRepository.setRunXp` 를 `Future<void> setRunRewards(String runId, {required int distanceXp, required int goalBonusXp, required int? distanceCoins, required int? goalCoins})` 로 바꾼다. 한 트랜잭션. 코인이 null 이면 코인 행을 건드리지 않는다. 0이면 그 행에 삭제 표시.
    - `Future<bool> hasRunCoins(String runId)`, `revokeRunXp` 는 코인 행도 삭제 표시한다(이름 `revokeRunRewards`).
    - `ShopRepository`: `Future<int> balance()`, `Future<List<CoinEntry>> coinHistory()`(최신순, `CoinEntry(amount, reason, runId, itemId, at)`), `Future<Set<String>> ownedItemIds()`, `Future<void> purchase(String itemId, int price)`(한 트랜잭션: 이미 보유면 `AlreadyOwned`, 잔액 부족이면 `InsufficientCoins` 를 던지고 아무 행도 쓰지 않음, 아니면 −price 행과 보유 행), `Future<Equipped> equipped()`, `Future<void> equip(ItemSlot slot, String? itemId)`(보유하지 않은 아이템이면 `NotOwned`)
  - 백업: `currentSchemaVersion` 5, `coinTxns`·`ownedItems` 테이블을 담는다. `decode` 는 3·4·5 를 받는다(5 미만은 두 테이블이 빈 목록).
  - 테스트: v4 → v5 마이그레이션 뒤 러닝·경험치 유지, 잔액 0. `setRunRewards` 두 번 불러도 행이 두 개씩 생기지 않는다, 코인 null 이면 코인 행 그대로. 구매: 잔액 100 에 120 짜리 → `InsufficientCoins`, 행 없음. 같은 아이템 두 번 → 두 번째 `AlreadyOwned`, 잔액 한 번만 줄어듦. 미보유 장착 → `NotOwned`. v4 백업 가져오기 성공, v5 왕복에 코인·보유·장착 유지.
  - 확인: `fvm flutter test test/run/data test/avatar/data test/shop test/backup`

- [x] 6. 러닝 코인 지급
  - 파일: `lib/avatar/domain/growth_rules.dart`, `lib/avatar/domain/growth_state.dart`, `lib/avatar/app/growth_service.dart`, `docs/specs/game-rules.md`
  - 규칙: `int distanceCoins(double distanceM, List<Split> splits) => distanceXp(distanceM, splits) ~/ 2`, `int goalBonusCoins(double goalM) => goalBonusXp(goalM)`.
  - 서비스: `_rate(detail, {required bool coins})` 가 `setRunRewards` 를 부른다. `sync` 의 새 러닝(경험치 없는 러닝)은 `coins: true`. 잘라내기·자가 복구 재평가는 `coins: await hasRunCoins(runId)`. `GrowthGain` 에 `distanceCoins`·`goalCoins` 를 더한다(재평가는 차이).
  - 문서: `game-rules.md` 코인 표에서 "초안·(후속)" 을 지우고 지급 시점·업그레이드 규칙을 적는다.
  - 테스트: 5km 목표로 5.02km → 거리 25·달성 25. 10km 목표로 5km → 25·0. 빠른 구간 제외. 업데이트 전 러닝(경험치 있음·코인 없음)은 sync·잘라내기 뒤에도 코인 0. 새 러닝을 잘라내 미달 → 달성 코인 삭제 표시, gain −25. 러닝 삭제 뒤 잔액 그대로.
  - 확인: `fvm flutter test test/avatar`

- [ ] 7. 코인 표시: 요약·홈·내역
  - 파일: `lib/avatar/ui/growth_summary.dart`, `lib/run/ui/home_screen.dart`, `lib/shop/ui/coin_history_screen.dart`(새 파일), `lib/shop/ui/coin_chip.dart`(새 파일)
  - 요약: 거리 줄 오른쪽을 `경험치 +31` 아래 `코인 +15` 두 줄로, 달성 줄은 `보너스 +15` 아래 `코인 +15`. 코인이 0이면 코인 줄을 뺀다(업데이트 전 러닝).
  - 홈: 아바타 무대 왼쪽 위에 `CoinChip`(코인 아이콘 + `1,240`). 누르면 상점 탭으로 간다(Task 10 전에는 내역 화면).
  - 내역: `코인 내역` 화면. 줄마다 날짜(caption) · 사유(`러닝 3.13km`·`목표 3km 달성`·`러닝 캡 구매`) · `+15`(`success`)/`−120`(`ink`). 비면 `달리면 코인이 쌓여요`. 지운 러닝도 줄은 남는다.
  - 테스트: 요약 두 줄 문구, 코인 0이면 코인 줄 없음. 홈 잔액 표시·천 단위 쉼표. 내역 정렬·문구·빈 화면. 360×640, 글자 1.3배에서 넘침 없음. 다크 테마.
  - 확인: `fvm flutter test test/avatar/ui test/run/ui test/shop`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

### D. 아이템 (F11)

- [ ] 8. 아이템 목록과 그림
  - 파일: `lib/shop/domain/catalog.dart`(새 파일), `tool/sprites/items.dart`(새 파일), `tool/sprites/pet_art.dart`, `tool/sprites/chick.dart`·`jelly.dart`·`acorn.dart`(머리 기준점), `tool/sprites/render.dart`, `lib/avatar/ui/sprite_sheet.dart`, `pubspec.yaml`(에셋 폴더), `assets/sprites/<종류>/hat/`·`accessory/`, `design/character/items.png`(미리보기), `docs/specs/sprite-spec.md`
  - 목록(`enum ItemSlot { hat, accessory }`, `class Item { id, slot, name, price }`):

    | id | 부위 | 이름 | 가격 |
    | --- | --- | --- | --- |
    | `cap` | 모자 | 러닝 캡 | 100 |
    | `beanie` | 모자 | 비니 | 200 |
    | `straw_hat` | 모자 | 밀짚모자 | 300 |
    | `sunglasses` | 소품 | 선글라스 | 150 |
    | `headphones` | 소품 | 헤드폰 | 250 |
    | `flower_pin` | 소품 | 꽃 머리핀 | 350 |

  - 그림: 아이템마다 그림 한 장, 종류마다 모자·소품 기준점(`PetKind.hatAnchor`·`accessoryAnchor`). 프레임은 face 와 같은 `headOffsets` 로 움직인다. 4단계가 같은 그림을 쓴다. 팔레트는 `petPalette` 에 색을 더한다.
  - 파일 이름: `assets/sprites/<종류>/<hat|accessory>/<id>_<동작>.png`, 경로 함수 `itemSheet(AvatarKind, Item, AvatarAction)`.
  - 테스트(`test/tool/sprite_data_test.dart` 확장): 아이템 프레임 형식, 프레임마다 아이템 세로 이동 = face 세로 이동, 6개 × 3종 × 3동작 에셋 파일이 모두 있다(`sprite_assets_test`). 목록 id 고유, 가격 100~400.
  - 확인: `fvm dart run tool/render_sprites.dart`, `fvm flutter test test/tool test/avatar/ui/sprite_assets_test.dart`
  - 스킬: 도트는 코드로 그린다(페이즈 2.5 방식). pixel-plugin 은 쓰지 않는다.

### E. 상점·꾸미기 (F10·F11)

- [ ] 9. 아바타에 아이템 겹쳐 그리기
  - 파일: `lib/avatar/ui/avatar_view.dart`, `lib/shop/app/providers.dart`, 아바타를 그리는 곳(`home_screen`, `in_run_screen`, `growth_summary`, `avatar_screen`)
  - 인터페이스: `AvatarView({..., String? hatItemId, String? accessoryItemId})`, `equippedProvider`(`FutureProvider<Equipped>`). 첫 실행 화면은 아이템을 그리지 않는다.
  - 테스트: 장착한 아이템 레이어 경로가 순서(`body, face, …, hat, accessory`)대로 들어간다. 장착을 바꾸면 홈 아바타가 다시 그려진다. 없는 id 는 무시.
  - 확인: `fvm flutter test test/avatar/ui test/run/ui`

- [ ] 10. 상점 탭: 미리보기·구매·장착
  - 파일: `lib/shop/ui/shop_screen.dart`(새 파일), `lib/app.dart`(탭 4개), `lib/shop/ui/coin_chip.dart`(홈 칩 → 상점 탭)
  - 화면: 제목 `상점`, 오른쪽 위 `CoinChip`(누르면 코인 내역). 위쪽 미리보기 무대에 장착 + 고른 아이템을 입힌 아바타(idle). `모자`·`소품` 고르기. 아이템 카드 2열: 작은 미리보기, 이름, 가격 또는 `보유`·`장착 중`. 아래 버튼:
    - 미보유: `120 코인으로 구매하고 장착`, 잔액 부족이면 비활성 + `코인이 20 부족해요`
    - 보유: `장착하기`, 장착 중: `벗기`
    - 구매는 확인 창(`러닝 캡을 120 코인에 살까요?` / `취소`·`구매`) 뒤에 사고 바로 장착한다. 진행 중에는 버튼을 막는다.
  - 테스트: 잔액 부족 문구·비활성. 구매 → 잔액 감소·보유·장착·홈 아바타 반영. 두 번 빠르게 눌러도 한 번 구매. 벗기. 360×640, 글자 1.3배에서 넘침 없음. 다크 테마. 탭 4개.
  - 확인: `fvm flutter test`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

### F. 문서

- [ ] 11. 문서·시안 반영
  - 파일: `docs/architecture.md`(데이터 모델 CoinTxn·OwnedItem·장착, 로컬 알림 줄), `docs/screens.md`(상점 화면·탭 4개·코인), `docs/specs/game-rules.md`, `docs/specs/sprite-spec.md`, `design/mockups/README.md`(구현 메모), `design/mockups/phase-4-screens/*.png`(E2E 스크린샷), `HANDOFF.md`
  - 확인: 문서에 "코인 (후속)"·"10분" 무점 종료 설명이 남아 있지 않다.

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 통과
- [ ] `fvm dart analyze` 오류·경고 0
- [ ] `fvm flutter build apk --debug` 성공

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 러닝 중 화면을 끄면 알림이 하나만 있고 제목의 거리가 바뀐다(`dumpsys notification`). 알림 `일시정지` 버튼으로 일시정지, `재개` 로 재개된다.
- [ ] `fake_run --stop-at 60 --stop-for 40`: 멈춘 뒤 약 10초에 `멈춰서 일시정지했어요`, 다시 움직이면 자동 재개되고 거리가 이어진다.
- [ ] `RUN_STILL_END_SEC=20 RUN_END_WARNING_SEC=10` 빌드에서 멈춘 채 두면 예고 알림 뒤 러닝이 끝나고 요약이 열린다. 끝 시각은 멈춘 시각이다.
- [ ] 목표 3km 로 3.2km 가상 러닝: 요약에 `경험치 +32`·`코인 +16`, `보너스 +15`·`코인 +15`. 홈 잔액 31.
- [ ] 위 러닝 뒤(잔액 31) 상점에서 러닝 캡(100)은 `코인이 69 부족해요` 로 살 수 없다. 코인 지급 행을 넣은 v5 백업 파일(잔액 400)을 설정에서 가져온 뒤 러닝 캡을 사면 잔액 300, 홈·러닝 중 아바타가 모자를 쓰고, 코인 내역에 `러닝 캡 구매 −100` 이 있다.
- [ ] 빠른 이동 자동 종료(`RUN_AUTO_END_FAST_SEC=10`)는 페이즈 3.5 와 같이 에뮬레이터 한계가 있으면 사람 확인으로 둔다.

### 사람 확인
- [ ] 상점·코인 표시·아이템 그림 디자인 승인(출시 수준 다듬기는 6-1·6-2)
- [ ] 아이템 목록과 가격 승인
- [ ] 실기기에서 알림 덮어쓰기·버튼·자동 일시정지 기준값 확인(페이즈 7)

## 자동 결정

없음
