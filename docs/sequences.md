# 시퀀스 다이어그램

> 핵심 흐름 네 가지를 시간 순서로 그린다. 참여자와 메시지 이름은 실제 클래스·메서드 이름이며, 근거 파일을 그림마다 적었다 (코드 기준 2026-10-23, 앱 0.4.0). 구조는 [설계서](architecture.md), 규칙은 [기록 엔진 명세](specs/run-engine.md)·[게임 규칙](specs/game-rules.md).

## 1. 러닝 기록부터 종료·보상까지

시작 → 위치 수신 → 10초 저장 → 종료 → 요약·보상. 위치 점 하나가 거름(정확도·튀는 값·탈것)을 거쳐 거리에 더해지는 규칙은 엔진 명세에 있다.

```mermaid
sequenceDiagram
    actor U as 사용자
    participant H as HomeScreen
    participant C as RunController
    participant E as RunEngine
    participant L as LocationSource
    participant R as RunRepository
    participant G as GrowthService
    participant S as SummaryScreen

    U->>H: 시작 (오늘 목표 선택됨)
    H->>C: start(goal)
    C->>R: createActiveRun(now, goal)
    C->>E: RunEngine(clock).start()
    C->>L: 위치 구독 (포그라운드 서비스 시작)
    loop 위치 점마다
        L-->>C: LocationSample
        C->>E: addSample(sample)
        E-->>C: 거리·페이스·구간 갱신
    end
    loop 10초마다
        C->>R: appendPoints(runId, 점들)
    end
    loop 1초마다 (tick)
        C->>E: autoPauseIfStill(now), signalLostIfSilent(now)
        C->>C: _checkAutoEnd()
    end
    U->>C: 길게 눌러 종료 → end()
    C->>R: 남은 점 저장 (_flush)
    C->>E: end(weightKg) → RunSummary
    alt 거리 < 1km (minSavedDistanceM)
        C->>R: discardActiveRun(runId)
        C-->>H: discardedShortRun (저장 안 함 안내)
    else 1km 이상
        C->>R: completeRun(runId, summary)
        C-->>H: lastSummary
        H->>G: sync()
        G->>R: listRuns() / getRun()
        G->>G: 거리 경험치·달성 보너스·코인 계산 후 XpTxns·CoinTxns 기록
        G->>G: AchievementService.awardNew() 새 배지
        G-->>H: GrowthGain (레벨업·단계 포함)
        H->>S: SummaryScreen.fromSummary(summary, gain)
    end
```

근거: `lib/run/app/run_controller.dart` (`start`, `_finish`, `_flushInterval`, `_tickInterval`), `lib/run/ui/home_screen.dart` (`_openSummary`), `lib/avatar/app/growth_service.dart` (`sync`), `lib/achievement/app/achievement_service.dart` (`awardNew`).

## 2. 알림 버튼으로 일시정지·재개

알림 버튼 응답은 앱 화면과 다른 isolate 에서 오므로, 이름을 붙인 포트를 거쳐 메인 isolate 의 컨트롤러가 받는다.

```mermaid
sequenceDiagram
    actor U as 사용자
    participant OS as 안드로이드 알림창
    participant BG as 백그라운드 isolate
    participant P as IsolateNameServer 포트
    participant M as 메인 isolate (스트림)
    participant C as RunController
    participant E as RunEngine
    participant N as RunProgressNotifier

    U->>OS: 알림의 일시정지 버튼
    OS->>BG: onRunNotificationBackgroundResponse(response)
    BG->>P: forwardRunNotificationAction → 'run_pause' 전송
    P-->>M: registerRunNotificationActionPort 의 스트림
    M-->>C: runNotificationActionsProvider → _onNotificationAction('run_pause')
    alt 기록 중이거나 자동 정지 상태 (recording · autoPaused · vehicle · signalLost)
        C->>E: pause()
        C->>N: 진행 알림 갱신 (재개 버튼으로 바뀜)
    else 러닝 없음·종료 중·상태에 안 맞음
        C->>C: 무시
    end
    U->>OS: 재개 버튼
    OS->>BG: onRunNotificationBackgroundResponse
    BG->>P: 'run_resume'
    P-->>C: _onNotificationAction('run_resume')
    C->>E: resume()
    C->>N: 진행 알림 갱신 (일시정지 버튼)
```

근거: `lib/core/local_notifications.dart` (`onRunNotificationBackgroundResponse`, `forwardRunNotificationAction`, `registerRunNotificationActionPort`), `lib/run/app/run_controller.dart` (`_onNotificationAction`), `lib/main.dart` (포트 등록). 앱 프로세스가 없으면 포트가 없어 버튼을 무시한다.

## 3. 자동 일시정지와 자동 종료

1초 tick 이 상태를 판정한다. 시간 기준은 `lib/run/app/run_guard.dart` 의 값이다: 제자리 5분(`autoEndStill`)·사용자 일시정지 1시간(`autoEndPaused`)·탈것 합계 2분(`autoEndVehicle`)·시작 6시간(`autoEndMax`), 끝나기 30초 전(`autoEndWarning`)에 예고한다.

```mermaid
sequenceDiagram
    participant T as tick (1초)
    participant C as RunController
    participant E as RunEngine
    participant G as run_guard (checkAutoEnd)
    participant N as RunProgressNotifier
    participant V as VoiceGuide
    participant R as RunRepository

    T->>C: 주기 호출
    C->>G: checkAutoEnd(now, state, stateSince, ...)
    G-->>C: null (아직 기준 미달)
    C->>E: autoPauseIfStill(now)
    E-->>C: true → state = autoPaused
    C->>V: 음성 VoiceAutoPaused "일시정지했어요"
    Note over C,E: 움직임이 다시 잡히면 addSample 이 recording 으로 되돌린다
    loop 제자리가 이어지면
        T->>C: 주기 호출
        C->>C: _syncEndWarning(engine)
        C->>N: showEndWarning(deadline) · 음성 VoiceEndWarning (종료 30초 전)
    end
    T->>C: 주기 호출
    C->>G: checkAutoEnd(...)
    G-->>C: AutoEndDecision(reason, endAt)
    C->>C: _autoEnd(decision) → _finish(decision)
    C->>E: end() 후 _endAt 으로 끝을 앞당김 (멈춘 시각 이후 시간은 뺌)
    C->>R: completeRun 또는 discardActiveRun (1km 미만)
    C->>N: 자동 종료 알림 (_notifyAutoEnd)
```

탈것 의심(30초 평균 시속 22km 초과)이 되면 구간을 기록에서 빼고, 의심 시간 합이 2분(`autoEndVehicle`)이 되면 같은 `checkAutoEnd` 가 판정해 같은 종료 흐름을 탄다(결정 0033, 예전 "시속 30km 30초" 규칙을 대체). 종료 시각은 첫 의심 구간이 시작되기 전 마지막 정상 점이다. 신호 끊김도 5분 뒤 같은 흐름으로 끝난다.

근거: `lib/run/app/run_controller.dart` (`_startTick`, `_checkAutoEnd`, `_autoEnd`, `_syncEndWarning`, `_endAt`), `lib/run/app/run_guard.dart`, `lib/run/domain/run_engine.dart` (`autoPauseIfStill`, `signalLostIfSilent`).

## 4. 백업 내보내기와 가져오기

러닝 중에는 막는다. 가져오기는 성장 계산과 같은 줄(`exclusive`)에서 DB 를 통째로 바꾼 뒤 성장을 다시 계산한다.

```mermaid
sequenceDiagram
    actor U as 사용자
    participant S as 설정 화면
    participant B as BackupService
    participant F as BackupFileStore
    participant BR as BackupRepository
    participant G as GrowthService

    U->>S: 백업 내보내기
    S->>B: export()
    B->>B: _isRunActive() 러닝 중이면 BackupBlockedByRun
    B->>BR: exportJson(now)
    BR-->>B: JSON (스키마 7판)
    B->>F: save('runmagochi-backup-YYYYMMDD.json', bytes)
    F-->>B: 저장됨 / 취소
    B-->>S: BackupDone · BackupCancelled · BackupFailed

    U->>S: 백업 가져오기 → 덮어쓰기 확인
    S->>B: import()
    B->>F: pickJson()
    F-->>B: JSON 문자열 (취소면 null → BackupCancelled)
    B->>G: exclusive(() => importJson(json))
    G->>BR: importJson(json) (기존 데이터 모두 교체, 이전 판은 채워서 가져옴)
    BR-->>B: 성공 / BackupFormatException
    B->>G: sync() 성장·코인·배지 다시 계산 (실패해도 가져오기는 성공)
    B-->>S: BackupDone (화면 새로 읽기: refresh_after_import)
```

근거: `lib/backup/app/backup_service.dart`, `lib/backup/data/backup_repository.dart`, `lib/backup/data/backup_file_store.dart`, `lib/backup/ui/refresh_after_import.dart`. 형식 판 이력은 [데이터 모델](data-model.md#스키마-판-이력).
