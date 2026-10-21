# 페이즈 5 구현 계획

- 상태: 실행
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 5 확장 (F5-2·F6-2·F14·F19·F21, 이름 후보, 결정 0023)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기간별 기록 통계와 구간 페이스 그래프를 보고, 거리 대신 시간 목표로도 달리며, 음성 안내를 듣고, 개인 기록·배지로 코인을 받고, 요약을 이미지로 공유한다. 출시 이름 후보를 상표 검색으로 좁힌다.

**Architecture:** 작업은 기능별 일곱 묶음이다(A 통계, B 시간 목표, C 음성 안내, D 업적, E 공유, F 이름, G 문서). 목표는 `RunGoal`(거리 m 또는 시간 초) 하나로 묶어 `Runs.goalM`·`Runs.goalSec` 두 열에 저장한다(스키마 v6). 음성 안내는 기록 엔진 이벤트(구간·목표·자동 일시정지)를 듣는 별도 서비스가 말한다. 배지는 저장된 완료 러닝으로 판정해 `Badges` 테이블과 코인(`CoinTxns.reason = badge`)에 쓰고, 경험치 동기화(`GrowthService.sync`) 뒤에 이어서 돈다. 공유 카드는 화면 밖에서 그린 위젯을 PNG 로 만들어 OS 공유 창으로 보낸다.

**Tech Stack:** Flutter 3.47.7 (FVM), drift(스키마 v6), riverpod, flutter_local_notifications 22, 새 패키지 `flutter_tts`·`share_plus`(결정 0024)

**Spec:** `docs/product.md` F5-2·F6-2·F14·F19·F21, 결정 0018·0020·0023, `docs/specs/game-rules.md`, `docs/specs/run-engine.md`, `docs/screens.md`, `docs/architecture.md`, 와이어프레임 `design/wireframes/png/09-activity.png`·`10-badges.png`

## Global Constraints

- 새 패키지는 `flutter_tts`·`share_plus` 둘만 넣는다. 결정 0024 에 근거를 적는다. 그래프는 패키지 없이 `CustomPainter` 로 그린다.
- 시간 목표: 20·30·60분 칩 또는 직접 입력 15~180분(1분 단위 정수). 달성 = 움직인 시간 ≥ 목표(자동 일시정지·일시정지 시간 제외).
- 시간 목표 달성 보너스(초안): 경험치 = 목표 분 ÷ 6 을 반올림 × 5 (20분 15, 30분 25, 60분 50). 코인도 같은 값. 거리 경험치·거리 코인은 지금 그대로.
- 목표는 거리 또는 시간 중 하나다. 목표 없이 달리는 선택지는 없다. 홈 기본값은 지난번 목표(종류 포함), 처음은 거리 3km.
- 배지는 코인만 준다(배지마다 50~300, 경험치 없음). 한 번 받은 배지는 러닝을 지워도 남는다.
- 음성 안내는 기본으로 켜져 있고 설정에서 끈다. 한국어(`ko-KR`). 다른 앱 소리는 줄였다가 되돌린다(덕킹).
- 레이스·건강 연동은 만들지 않는다(결정 0023).
- 모든 데이터 접근은 저장소 인터페이스를 거친다(결정 0001). 디자인 값은 `lib/core/theme.dart` 토큰만 쓴다. 문구는 한국어 존댓말 `-요` 체. 화면 다듬기는 페이즈 6 에서 한다.
- Android 기준으로 만들고 확인한다. 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **업그레이드 사용자**: v5 DB 를 v6 으로 올리면 러닝·목표(거리)·경험치·코인·장착이 그대로고, 예전 러닝은 시간 목표가 없다. v5 백업 파일도 가져온다. 테스트는 Task 3.
2. **시간 목표와 일시정지**: 30분 목표에서 자동 일시정지·사용자 일시정지 시간은 세지 않는다. 강제 종료 뒤 복원한 러닝도 같은 목표·같은 판정이다. 끝부분 잘라내기로 움직인 시간이 목표 밑으로 내려가면 보너스를 무른다. 테스트는 Task 4·5.
3. **배지 소급과 중복**: 업데이트 직후 첫 동기화에서 기존 기록으로 받을 배지를 한 번만 준다. 같은 배지가 두 번 생기지 않고, 러닝을 지워도 배지·코인은 남는다. 테스트는 Task 8.
4. **음성 안내가 기록을 막지 않음**: TTS 초기화 실패·말하기 실패·끈 상태에서도 러닝은 이어진다. 화면을 끈 상태에서도 구간 안내가 나온다(E2E 로그). 테스트는 Task 6.
5. **빈 기간·긴 기간 통계**: 러닝이 없는 주·월·년은 0 과 빈 막대로, 기록이 몇 년치여도 연·전체 탭이 느려지지 않는다(한 번 읽고 메모리에서 묶음). 테스트는 Task 1.

---

## 작업

### A. 기록 통계 (F5-2)

- [x] 1. 기간별 통계
  - 파일: `lib/run/domain/run_stats.dart`(새 파일), `lib/run/ui/history_screen.dart`, `lib/run/ui/stats_chart.dart`(새 파일), `lib/run/data/run_repository.dart`(필요하면)
  - 인터페이스:
    - `enum StatsPeriod { week, month, year, all }`
    - `RunStats statsFor(List<RunListItem> runs, StatsPeriod period, DateTime anchor)` — 순수 함수. `RunStats { double distanceM; int count; Duration movingTime; double? avgPaceSecPerKm; List<StatsBar> bars; DateTime start; DateTime end; }`, `StatsBar { String label; double distanceM; }`
    - 막대: 주 = 월~일 7개, 월 = 그달 날짜 수, 년 = 1~12월, 전체 = 첫 러닝 해부터 올해까지 연도별
    - 주는 월요일 시작(현지 시각, 지금 "이번 주" 와 같은 기준)
  - 화면: 기록 탭 위에 `주`·`월`·`년`·`전체` 고르기, 그 아래 `◀ 2026년 10월 ▶`(전체는 화살표 없음, 미래로는 못 감), 거리(큰 숫자)·러닝 횟수·평균 페이스·시간, 막대 그래프(`StatsChart`, `CustomPainter`, 막대 색 `primary`). 지금 "이번 주" 카드를 이 영역으로 바꾼다. 아래 최근 러닝 목록은 그대로.
  - 테스트: 기간 경계(일요일 23:59·월요일 00:00, 월말, 연말), 빈 기간 0, 지운 러닝 제외, 평균 페이스 = 시간 ÷ 거리, 년 막대 12개, 전체 막대 연도 수. 화면: 탭 전환·화살표 이동·미래 막힘, 360×640·글자 1.3배 넘침 없음, 다크 테마.
  - 확인: `fvm flutter test test/run`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [ ] 2. 구간 페이스 그래프
  - 파일: `lib/run/ui/split_pace_chart.dart`(새 파일), `lib/run/ui/summary_screen.dart`
  - 동작: 요약·기록 상세의 구간 표 위에 1km 구간별 페이스 막대(빠를수록 길게). 평균 페이스 가로선. 1km 미만 마지막 구간은 흐리게. 빠른 구간(경험치 제외 구간)은 `ink-muted` 로. 구간이 1개 이하면 그래프를 숨긴다.
  - 테스트: 막대 수 = 구간 수, 구간 0·1개면 숨김, 마지막 짧은 구간 표시, 360×640·글자 1.3배, 다크 테마.
  - 확인: `fvm flutter test test/run/ui`

### B. 시간 목표 (F6-2)

- [ ] 3. 저장 구조 v6
  - 파일: `lib/run/data/app_database.dart`(+ `.g.dart`), `lib/run/data/run_repository.dart`, `lib/run/data/drift_run_repository.dart`, `lib/run/domain/run_goal.dart`(새 파일), `lib/profile/data/*`, `lib/backup/domain/backup_codec.dart`, `lib/backup/data/drift_backup_repository.dart`, 호출부
  - 스키마 v6:
    - `Runs.goalSec` (int nullable)
    - `Badges`: id, badgeId(고유), runId(nullable, Runs 참조), earnedAt, createdAt, updatedAt, deletedAt
    - `Profiles.voiceGuide` (bool, 기본 true)
    - `from < 6` 이면 열 두 개와 테이블 하나를 더한다
  - 인터페이스:
    - `sealed class RunGoal` — `DistanceGoal(double meters)`, `TimeGoal(Duration time)`. `RunGoal.fromColumns(double? goalM, int? goalSec)` (둘 다 null 이면 null)
    - `createActiveRun(DateTime startedAt, {required RunGoal goal})`, `Future<RunGoal?> lastGoal()`(`lastGoalM` 대신), `RunListItem.goal`·`ActiveRun.goal`(`RunGoal?`, 기존 `goalM` 대신)
    - `ProfileRepository.voiceGuide()`·`setVoiceGuide(bool)`
  - 백업: `currentSchemaVersion` 6, `badges` 테이블, `decode` 는 3~6 을 받는다(6 미만은 배지 없음, 프로필 음성 안내 true).
  - 테스트: v5 → v6 마이그레이션(러닝·목표·코인·장착 유지, `goalSec` null, 음성 안내 true). 시간 목표 러닝 저장·목록·복원 왕복. `lastGoal` 이 종류까지 돌려준다. v5 백업 가져오기, v6 왕복.
  - 확인: `fvm flutter test test/run/data test/backup test/profile`

- [ ] 4. 시간 목표 판정과 보너스
  - 파일: `lib/avatar/domain/growth_rules.dart`, `lib/avatar/app/growth_service.dart`, `lib/run/app/run_controller.dart`, `docs/specs/game-rules.md`
  - 규칙:
    - `bool goalAchieved({required RunDetail-like 값, required RunGoal goal})` — 거리 목표는 지금 그대로, 시간 목표는 `movingTime >= goal.time`
    - `int goalBonusXp(RunGoal goal)` — 거리 = 목표 km × 5, 시간 = (목표 분 ÷ 6 반올림) × 5. `goalBonusCoins` 도 같은 값
  - 컨트롤러: `start({required RunGoal goal})`. 기록 중 `goalReached` 는 시간 목표면 움직인 시간으로 판정하고, 닿는 첫 순간에 알림 `목표 달성!` / `30분 목표를 채웠어요. 종료할 때까지 기록은 이어져요` 를 한 번 보낸다. 복원한 러닝이 이미 넘었으면 다시 알리지 않는다.
  - 문서: `game-rules.md` 오늘 목표 절에 시간 목표 판정·보너스를 더한다.
  - 테스트: 30분 목표 29:59 미달·30:00 달성, 일시정지·자동 일시정지 시간 제외, 보너스 20분 15·30분 25·60분 50, 잘라내 29분이 되면 보너스·코인 무름, 거리 목표 기존 테스트 그대로 통과.
  - 확인: `fvm flutter test test/avatar test/run/app`

- [ ] 5. 시간 목표 화면
  - 파일: `lib/run/ui/run_goal_picker.dart`, `lib/run/ui/home_screen.dart`, `lib/run/ui/in_run_screen.dart`, `lib/avatar/ui/growth_summary.dart`, `lib/run/data/run_progress_notifier.dart`(`runProgressContent`)
  - 홈: 오늘 목표 카드 위쪽에 `거리`·`시간` 고르기, 아래 칩이 `3km·5km·10km·직접` 또는 `20분·30분·60분·직접`. 직접 입력 창은 시간이면 `15~180분 사이 정수로 입력해 주세요`.
  - 러닝 중: 시간 목표면 `목표 30분` 과 시간 진행 막대, 달성 뒤 `목표 달성!`. 알림 본문 `목표 30분까지 12:34`.
  - 요약: 달성 `목표 30분 달성` / `보너스 +25`, 미달 `목표 30분까지 4:12 남았어요`.
  - 테스트: 종류 전환·칩·직접 입력 범위(14·181 거부), 지난번 시간 목표가 기본으로 골라짐, 러닝 중·요약·알림 문구, 360×640·글자 1.3배, 다크 테마.
  - 확인: `fvm flutter test test/run test/avatar/ui`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

### C. 음성 안내 (F14)

- [ ] 6. 음성 안내
  - 파일: `pubspec.yaml`(`flutter_tts`), `lib/run/app/voice_guide.dart`(새 파일), `lib/run/data/tts_speaker.dart`(새 파일), `lib/run/app/run_controller.dart`(이벤트 연결), `lib/settings/ui/settings_screen.dart`, `docs/decisions/0024-voice-share-packages.md`(새 결정, Task 10 의 share_plus 도 함께 적는다)
  - 인터페이스: `abstract interface class Speaker { Future<void> speak(String text); }`, `String? voiceLine(VoiceEvent e)` 순수 함수, `VoiceGuide` 가 켜짐 여부를 보고 `Speaker` 를 부른다(실패는 로그만).
  - 말하는 때와 문구:
    - 시작: `러닝을 시작해요`
    - 1km 마다: `3킬로미터. 시간 18분 40초. 평균 페이스 6분 13초.`
    - 목표 달성: `목표 5킬로미터를 채웠어요` / `목표 30분을 채웠어요`
    - 자동 일시정지·재개: `일시정지했어요` / `다시 기록해요`
    - 종료 예고: `움직이지 않으면 30초 뒤 러닝을 마쳐요`
  - 설정: `음성 안내` 켜고 끄기(프로필 `voiceGuide`).
  - 테스트: 각 이벤트 문구, 끈 상태에서 말하지 않음, 말하기 실패가 러닝을 멈추지 않음, 같은 구간 안내가 두 번 나오지 않음, 설정 토글이 저장됨.
  - 확인: `fvm flutter test test/run test/settings`

### D. 업적 (F19)

- [ ] 7. 개인 기록과 배지 규칙
  - 파일: `lib/achievement/domain/personal_records.dart`(새 파일), `lib/achievement/domain/badges.dart`(새 파일)
  - 개인 기록(지운 러닝 제외): 최장 거리, 최장 시간, 최고 1km(빠른 구간 제외 1km 구간 중 가장 빠름), 최고 5km(연속한 1km 구간 5개 합이 가장 짧음).
  - 배지 목록(초안, `const badgeCatalog`):

    | id | 이름 | 조건 | 코인 |
    | --- | --- | --- | --- |
    | `first_run` | 첫 러닝 | 러닝 1회 | 50 |
    | `first_goal` | 첫 목표 달성 | 목표 달성 1회 | 50 |
    | `dist_5k` | 첫 5km | 한 번에 5km | 100 |
    | `dist_10k` | 첫 10km | 한 번에 10km | 150 |
    | `dist_half` | 하프 완주 | 한 번에 21.1km | 300 |
    | `total_50` | 누적 50km | 누적 50km | 100 |
    | `total_100` | 누적 100km | 누적 100km | 200 |
    | `total_300` | 누적 300km | 누적 300km | 300 |
    | `goals_10` | 목표 달성 10번 | 목표 달성 10회 | 100 |
    | `goals_30` | 목표 달성 30번 | 목표 달성 30회 | 200 |
    | `streak_3` | 3일 연속 | 서로 다른 3일 연속 러닝 | 50 |
    | `dawn` | 새벽 러너 | 오전 6시 전에 시작 | 50 |

    - 거리는 경험치 거리(빠른 구간 제외)로 잰다.
  - 인터페이스: `PersonalRecords recordsFor(List<RunDetail> runs)`, `List<String> earnedBadgeIds(List<RunDetail> runs, {required Set<String> already})` (새로 받을 id 만, 받은 순서), `BadgeProgress? nextBadge(...)`(가장 가까운 미획득 배지와 진행률).
  - 테스트: 경계값(4.99/5.00km, 05:59/06:00 시작, 날짜가 바뀌는 3일 연속), 빠른 구간 제외, 이미 받은 배지 제외, 최고 5km 계산.
  - 확인: `fvm flutter test test/achievement`

- [ ] 8. 배지 지급
  - 파일: `lib/achievement/data/badge_repository.dart`·`drift_badge_repository.dart`(새 파일), `lib/achievement/app/achievement_service.dart`(새 파일), `lib/avatar/app/growth_service.dart` 또는 동기화 호출부, `lib/avatar/domain/growth_state.dart`(`GrowthGain.newBadges`)
  - 동작: 경험치 동기화 뒤 완료 러닝 전체로 `earnedBadgeIds` 를 돌리고, 새 배지마다 한 트랜잭션으로 `Badges` 행과 `CoinTxns(reason badge, itemId = 배지 id)` 를 쓴다. 업데이트 직후 첫 동기화에서 기존 기록으로 받을 배지를 모두 준다(소급, 확인 필요). 지운 러닝은 새 판정에서 빠지지만 받은 배지·코인은 남는다. 코인 내역 문구 `배지: 첫 5km`.
  - 테스트: 첫 러닝 뒤 `first_run` 1개·코인 50, 같은 동기화 두 번 불러도 한 번, 소급 판정, 지운 뒤 유지, 백업 왕복(Task 3) 뒤 중복 없음.
  - 확인: `fvm flutter test test/achievement test/avatar`

- [ ] 9. 업적 화면과 새 배지 표시
  - 파일: `lib/achievement/ui/achievement_screen.dart`(새 파일), `lib/avatar/ui/avatar_screen.dart`(들어가는 버튼), `lib/avatar/ui/growth_summary.dart`, `lib/shop/ui/coin_history_screen.dart`(배지 문구)
  - 화면: 아바타 탭에 `업적` 버튼 → 업적 화면. `개인 기록`(최장 거리·최장 시간·최고 1km·최고 5km, 없으면 `-`), `배지 7 / 12` 그리드(받은 것 `primary` 원, 못 받은 것 흐린 원 + 이름), `다음 배지`(이름·코인·진행 막대). 그림은 임시 아이콘(페이즈 6-1 에서 도트로 다시 그린다).
  - 요약: 이번 러닝에서 받은 배지가 있으면 `배지 획득: 첫 5km` / `코인 +100` 줄.
  - 테스트: 개인 기록 표시·빈 상태, 배지 수·그리드, 다음 배지 진행률, 요약 배지 줄, 360×640·글자 1.3배, 다크 테마.
  - 확인: `fvm flutter test test/achievement test/avatar/ui`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

### E. 공유 (F21)

- [ ] 10. 요약 공유 카드
  - 파일: `pubspec.yaml`(`share_plus`), `lib/run/ui/share_card.dart`(새 파일), `lib/run/app/share_service.dart`(새 파일), `lib/run/ui/summary_screen.dart`
  - 동작: 요약 오른쪽 위 `공유` 버튼 → 화면 밖에서 `ShareCard`(1080×1350, 아바타(장착 포함) + 날짜 + 거리 + 시간 + 평균 페이스 + 목표 달성 + 레벨업 + 앱 이름 자리 `runmagochi`)를 PNG 로 만들어 임시 폴더에 쓰고 OS 공유 창을 연다. 만드는 중에는 버튼을 막고, 실패하면 `공유하지 못했어요`.
  - 인터페이스: `abstract interface class Sharer { Future<void> shareImage(String path, {String? text}); }`(테스트에서 가짜로 바꾼다)
  - 테스트: 카드에 거리·시간·페이스·목표 문구가 그려진다, 버튼 → 가짜 Sharer 가 PNG 경로를 받는다, 실패 문구, 두 번 눌러도 한 번.
  - 확인: `fvm flutter test test/run/ui`

### F. 이름 (결정 0012)

- [ ] 11. 이름 후보와 상표 검색
  - 파일: `docs/research/naming.md`(새 파일)
  - 내용: 콘셉트(펫 러너, 도트, 달릴수록 자람)에 맞는 이름 후보 5~6개(한글·영문 표기). 후보마다 KIPRIS 상표 검색(9류 앱·41류 운동 서비스), Google Play·App Store 같은 이름 앱, 도메인·패키지 이름 충돌을 표로 적는다. 검색하지 못한 칸은 `미확인` 으로 두고 사람 확인으로 넘긴다. 추천 1~2개와 근거.
  - 확인: 문서에 후보 5개 이상과 검색 결과 표가 있다.

### G. 문서

- [ ] 12. 문서·시안 반영
  - 파일: `docs/architecture.md`(Run.goalSec·Badge·Profile.voiceGuide, 패키지), `docs/screens.md`(기록 통계·업적 화면·공유·시간 목표), `docs/specs/run-engine.md`(음성 안내 이벤트), `docs/product.md`(F5-2·F14·F19·F21 포함), `design/mockups/README.md`(구현 메모), `HANDOFF.md`
  - 확인: 문서 설명이 코드와 맞고, 레이스·건강 연동은 백로그로만 남아 있다.

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 통과
- [ ] `fvm dart analyze` 오류·경고 0
- [ ] `fvm flutter build apk --debug` 성공

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 기록 탭에서 `주`·`월`·`년`·`전체` 를 바꾸면 합계·막대가 바뀌고, 러닝 요약에 구간 페이스 그래프가 보인다.
- [ ] 시간 목표 15분(직접 입력)으로 16분 가상 러닝: 러닝 중 `목표 15분` 진행 막대, 15분에 `목표 달성!` 알림, 요약 `목표 15분 달성` / `보너스 +15`(15 ÷ 6 = 2.5 → 3 × 5).
- [ ] 음성 안내: 1km 를 지나면 TTS 가 말한다(`logcat` 의 TextToSpeech 로그). 설정에서 끄면 말하지 않는다.
- [ ] 첫 러닝 뒤 요약에 `배지 획득: 첫 러닝` / `코인 +50`, 업적 화면에 개인 기록과 배지 1개.
- [ ] 요약 `공유` 를 누르면 OS 공유 창이 열린다.

### 사람 확인
- [ ] 시간 목표 보너스(분 ÷ 6 × 5), 직접 입력 범위(15~180분), 배지 목록·코인 승인
- [ ] 배지 소급 지급(업데이트 전 기록으로도 배지·코인을 줌) 승인
- [ ] 이름 후보 중 출시 이름 결정(상표 검색에서 `미확인` 칸 직접 확인 포함)
- [ ] 실기기에서 음성 안내(이어폰·화면 꺼짐) 확인(페이즈 8)

## 자동 결정

없음
