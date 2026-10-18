# 페이즈 3 구현 계획

- 상태: 실행
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 3 완성도 (Android, 결정 0014)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 처음 설치한 사람이 캐릭터를 만나고, 설정·백업·기록 수정까지 혼자 쓸 수 있는 Android 베타 앱을 만든다.

**Architecture:** 새 데이터(체중·첫 실행 완료)는 `Profiles` 테이블(스키마 v3)과 `ProfileRepository` 인터페이스로 둔다. 러닝 삭제는 `deletedAt` 표시(행은 지우지 않음)로 하고, 성장 로직은 삭제·잘라내기 뒤 그 러닝의 경험치와 그 주 목표 판정을 다시 계산한다. 잘라내기는 요약 화면이 들고 있는 원본 점(구간별)으로 기록 엔진을 다시 돌려 계산한다. 백업은 모든 테이블을 JSON 파일 하나로 만들고, 가져오기는 한 트랜잭션으로 기존 데이터를 바꾼다. 새 화면(첫 실행·설정)은 시안 승인 뒤 "말랑 클레이" 디자인 시스템(`docs/design/`)으로 만든다.

**Tech Stack:** Flutter 3.47.7 (FVM), drift(스키마 v3), riverpod, `file_picker`(백업 파일 저장·열기, Android·iOS 지원, 결정 0015)

**Spec:** `docs/roadmap.md` 페이즈 3, `docs/product.md` F12·F16, `docs/specs/run-engine.md`(끝부분 잘라내기·칼로리), `docs/specs/game-rules.md`, `docs/screens.md`(첫 실행·설정), `docs/architecture.md`(데이터 모델·백업), 결정 0011·0012·0014

## Global Constraints

- Android 기준으로 만들고 확인한다. 플랫폼 전용 코드는 인터페이스 뒤에 두고, 새 패키지는 iOS 도 지원하는 것만 쓴다(결정 0014).
- 모든 데이터 접근은 저장소 인터페이스를 거친다(결정 0001). 새 테이블도 `id`·`createdAt`·`updatedAt`·`deletedAt` 를 가진다.
- 삭제는 `deletedAt` 표시로 한다. 목록·합계·성장 계산은 삭제 표시된 행을 뺀다.
- 디자인 값은 `lib/core/theme.dart` 에만 둔다. 화면 코드에 색 리터럴·글자 크기 숫자를 새로 쓰지 않는다.
- 기존 테스트의 문구·동작은 유지한다.
- 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **경험치 정합성**: 삭제·잘라내기·백업 가져오기 뒤 총 경험치 = 남은 러닝의 거리 경험치 + 달성 주 보너스. 같은 보상이 두 번 쌓이지 않는다. 테스트는 Task 6·8·13.
2. **마이그레이션**: v2 DB 를 v3 로 올려도 기존 러닝·경험치·아바타가 그대로다. 테스트는 Task 4.
3. **백업 왕복**: 내보낸 파일을 빈 DB 에 가져오면 모든 테이블이 같다. 잘못된 파일은 기존 데이터를 건드리지 않는다. 테스트는 Task 12·13.
4. **잘라내기 정확성**: 일시정지 구간이 있는 러닝을 잘라도 거리·시간·구간이 엔진 계산과 같다. 테스트는 Task 7.

---

## 작업

- [x] 1. 경쟁 앱 재확인
  - 파일: `docs/research/market.md`
  - 내용: Play 스토어·웹에서 A 범주(GPS 러닝 + 캐릭터 성장, 걸음 펫)를 다시 찾아 새 앱·변경점을 반영한다(결정 0012). 겹치는 앱이 새로 나왔으면 차별점 영향을 적는다.
  - 확인: 문서 갱신일과 새로 본 앱 목록

- [x] 2. 잔여 정리 A: 글자 크기 22 토큰, 탭 키보드 포커스
  - 파일: `lib/core/theme.dart`, `docs/design/tokens.json`, `docs/design/design-system.md`, 22 를 쓰는 화면 5곳(`growth_summary`·`history_screen`·`in_run_screen` 2곳·`summary_screen` 2곳), `lib/app.dart`
  - 테스트: `AppText` 에 22 크기 토큰(`titleS`)이 있고 화면 파일에 `fontSize: 22` 가 없다(grep 테스트). 탭에 키보드 포커스를 주면 포커스 표시가 보이고 Enter·Space 로 탭이 바뀐다(위젯 테스트).
  - 확인: `fvm flutter test test/core test/app_test.dart`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 3. 잔여 정리 B: 홈 로딩 한 줄 점프, 다크 모드 캐릭터 윤곽
  - 파일: `lib/run/ui/home_screen.dart`, `lib/avatar/ui/weekly_goal_bar.dart`, `lib/avatar/ui/avatar_view.dart`, `lib/core/theme.dart`
  - 테스트: 연속 달성 기록이 있는 상태로 홈을 열 때 로딩 전후 목표 카드 높이가 같다. 다크 테마에서 아바타 뒤에 밝은 윤곽(테마 토큰 색)이 그려지고 라이트 테마에서는 없다.
  - 방법: 로딩 중에도 연속 달성 줄 자리를 잡고(지난 상태가 있으면 그 값을 유지), 다크 모드는 스프라이트 실루엣을 1px 밝은 색으로 뒤에 깔아 윤곽을 만든다.
  - 확인: `fvm flutter test test/run/ui/home_screen_test.dart test/avatar/ui`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 4. 프로필 저장소 (스키마 v3)
  - 파일: `lib/run/data/app_database.dart`(+ `.g.dart`), `lib/profile/data/profile_repository.dart`, `lib/profile/data/drift_profile_repository.dart`, `lib/profile/app/providers.dart`, `docs/architecture.md`
  - 테이블: `Profiles`(체중 kg nullable, 첫 실행 완료 시각 nullable, 공통 필드). 행은 하나.
  - 테스트: 행이 없으면 체중 null·첫 실행 미완료. 체중 저장·읽기, 첫 실행 완료 표시. v2 → v3 마이그레이션 뒤 기존 러닝·경험치·아바타 유지(`migration_test` 확장).
  - 확인: `fvm flutter test test/profile test/run/data`

- [x] 5. 체중을 칼로리에 연결
  - 파일: `lib/run/app/run_controller.dart`, `lib/run/app/providers.dart`
  - 테스트: 체중 70kg 저장 후 5km 러닝 종료 → 칼로리 = 70 × 5 × 1.036. 체중이 없으면 65kg 기준.
  - 확인: `fvm flutter test test/run/app`

- [x] 6. 러닝 삭제
  - 파일: `lib/run/data/run_repository.dart`, `lib/run/data/drift_run_repository.dart`, `lib/avatar/data/growth_repository.dart`, `lib/avatar/data/drift_growth_repository.dart`, `lib/avatar/app/growth_service.dart`, `lib/run/ui/summary_screen.dart`(기록에서 연 상세), `lib/run/ui/history_screen.dart`, `docs/specs/game-rules.md`
  - 동작: 기록 상세에서 "삭제" → 확인 창 → `deletedAt` 표시. 목록·주간 합계에서 빠진다. 그 러닝의 거리 경험치를 무르고(경험치 행에 `deletedAt` 표시) 그 주 목표를 다시 판정한다. 목표 미달이 되면 그 주 보너스도 무른다. 레벨이 내려갈 수 있다(결정 0016).
  - 테스트: 저장소(삭제 후 목록·합계·상세에서 빠짐, 구간도 표시), 성장(삭제 후 총 경험치·주 달성 재판정, 다시 sync 해도 그대로), 위젯(확인 창 → 목록으로 돌아가 사라짐, 취소하면 그대로).
  - 확인: `fvm flutter test test/run test/avatar`

- [x] 7. 끝부분 잘라내기 계산
  - 파일: `lib/run/domain/run_trim.dart`, `lib/run/domain/run_summary.dart`(구간별 점 보관), `lib/run/domain/run_engine.dart`(필요하면 재생 함수)
  - 동작: 원본 점(구간별)과 새 끝 시각을 받아, 그 시각 이후 점을 버리고 기록 엔진을 다시 돌려 거리·움직인 시간·평균 페이스·구간·칼로리·경로를 새로 만든다.
  - 테스트: 끝 시각 이후 점이 사라지고 결과가 같은 점으로 처음부터 계산한 값과 같다. 일시정지 구간이 있어도 맞다. 끝 시각이 시작보다 앞이거나 원래 끝보다 뒤면 거부한다.
  - 확인: `fvm flutter test test/run/domain`

- [x] 8. 잘라내기 저장과 경험치 재계산
  - 파일: `lib/run/data/run_repository.dart`, `lib/run/data/drift_run_repository.dart`, `lib/run/app/run_controller.dart`(종료 요약에 runId), `lib/avatar/app/growth_service.dart`, `lib/avatar/data/*`
  - 동작: 완료된 러닝의 요약·구간·경로를 새 값으로 바꾸고, 그 러닝의 거리 경험치를 새 거리로 고친 뒤 그 주 목표를 다시 판정한다. 결과로 새 `GrowthGain` 을 돌려준다.
  - 테스트: 저장소(교체 후 상세·구간·합계), 성장(경험치 감소·주 달성 재판정·레벨 표시가 새 값과 맞음).
  - 확인: `fvm flutter test test/run test/avatar`

- [ ] 9. 잘라내기 화면
  - 파일: `lib/run/ui/summary_screen.dart`, `lib/run/ui/trim_sheet.dart`
  - 동작: 종료 직후 요약에만 "끝부분 잘라내기" 버튼. 시트에서 끝 시각을 슬라이더로 당기면 거리·시간이 미리 보이고, "잘라내기" 를 누르면 저장하고 요약·경험치를 새 값으로 다시 그린다. 기록에서 연 상세에는 버튼이 없다.
  - 테스트: 위젯(슬라이더 이동 시 미리보기 값, 저장 후 요약 값·경험치 갱신, 상세에는 버튼 없음, 글자 1.3배에서 넘치지 않음)
  - 확인: `fvm flutter test test/run/ui`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 10. 종료를 잊은 러닝 자동 종료
  - 파일: `lib/run/app/run_controller.dart`, `lib/run/app/run_guard.dart`(판정 규칙), `lib/run/ui/in_run_screen.dart`, `lib/run/ui/home_screen.dart`(복원), `lib/avatar/data/notification_scheduler.dart`(즉시 알림), `docs/specs/run-engine.md`, `docs/decisions/0016-run-integrity.md`
  - 동작: 기록 중 20분 동안 받아들인 위치 점이 없거나, 시작부터 6시간이 지나면 자동으로 끝낸다. 끝 시각은 마지막으로 받아들인 점으로 당기고(Task 7 잘라내기 사용), "러닝을 자동으로 마쳤어요" 알림을 보낸다. 앱이 열려 있으면 요약 화면으로 간다. 강제 종료 뒤 다시 열었을 때 이미 조건을 넘었으면 이어서 기록을 묻지 않고 자동 종료한다.
  - 테스트: 가짜 시계로 19분 59초엔 계속, 20분엔 종료·끝 시각 = 마지막 점, 일시정지 중엔 20분 규칙 미적용(6시간은 적용), 6시간 상한, 복원 시 자동 종료, 알림 호출.
  - 확인: `fvm flutter test test/run`

- [x] 11. 경험치에서 뺀 구간 표시
  - 파일: `lib/avatar/domain/growth_rules.dart`(뺀 거리 계산), `lib/avatar/domain/growth_state.dart`, `lib/avatar/ui/growth_summary.dart`, `docs/specs/game-rules.md`
  - 동작: 1km 구간이 2분30초보다 빨라 경험치에서 뺀 거리가 있으면 요약에 "빠른 이동 1.2km는 경험치에서 뺐어요" 를 보인다. 없으면 아무것도 안 보인다.
  - 테스트: 도메인(뺀 거리 합), 위젯(문구 있음·없음, 글자 1.3배)
  - 확인: `fvm flutter test test/avatar`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 12. 백업 파일 형식
  - 파일: `lib/backup/domain/backup_codec.dart`, `lib/backup/data/backup_repository.dart`, `lib/backup/data/drift_backup_repository.dart`, `docs/decisions/0015-backup.md`, `docs/architecture.md`
  - 형식: JSON, `{format: "runmagochi-backup", version: 1, schemaVersion: 3, exportedAt, tables: {...}}`. 진행 중 러닝과 RunPoint 는 넣지 않는다. 삭제 표시된 행은 넣는다.
  - 테스트: 내보내기 → 빈 DB 로 가져오기 → 모든 테이블 같음. 형식·버전이 다르거나 깨진 파일은 오류를 내고 기존 데이터가 그대로. 가져오기는 한 트랜잭션.
  - 확인: `fvm flutter test test/backup`

- [x] 13. 백업 내보내기·가져오기 연결
  - 파일: `pubspec.yaml`(`file_picker`), `lib/backup/data/backup_file_store.dart`(파일 저장·열기 인터페이스와 file_picker 구현), `lib/backup/app/backup_service.dart`, `lib/backup/app/providers.dart`
  - 동작: 내보내기는 `runmagochi-backup-YYYYMMDD.json` 이름으로 저장 위치를 고르게 한다. 가져오기는 파일을 고른 뒤 "지금 데이터가 모두 백업 내용으로 바뀌어요" 확인 → 전체를 바꾸고(합치지 않음) 성장 상태·알림 예약을 다시 계산한다. 러닝 중에는 가져오기를 막는다.
  - 테스트: 서비스(가짜 파일 저장소로 내보내기 내용, 가져오기 후 성장 상태 재계산, 러닝 중 거부, 사용자가 파일 선택을 취소하면 아무것도 안 함)
  - 확인: `fvm flutter test test/backup`, `fvm flutter build apk --debug`

- [ ] 14. 첫 실행·설정 화면 시안 (사용자 승인)
  - 파일: `design/mockups/onboarding.dc.html`, `design/mockups/settings.dc.html`, `design/mockups/README.md`, `docs/screens.md`
  - 내용: 첫 실행 3장(캐릭터 소개 → 이름 짓기 → 주간 목표·"걷다 뛰다 OK"), 설정(체중, 주간 목표, 아바타 이름, 백업 내보내기·가져오기, 오픈소스 라이선스). 라이트·다크 둘 다.
  - 확인: 사용자 승인
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [ ] 15. 설정 화면
  - 파일: `lib/settings/ui/settings_screen.dart`, `lib/run/ui/home_screen.dart`(설정 들어가는 버튼), `lib/avatar/data/growth_repository.dart`(이름 바꾸기)
  - 테스트: 위젯(체중 입력 검증 30~200kg, 저장 후 다시 열면 값 유지, 주간 목표 변경이 홈에 반영, 이름 변경이 아바타 탭에 반영, 백업 버튼이 서비스 호출, 가져오기 확인 창, 글자 1.3배)
  - 확인: `fvm flutter test test/settings`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [ ] 16. 첫 실행 화면
  - 파일: `lib/onboarding/ui/onboarding_screen.dart`, `lib/app.dart`(첫 실행 미완료면 첫 실행 화면부터)
  - 동작: 무작위로 정해진 캐릭터(1단계)를 보여 주고, 이름(기본값 종류별 추천, 1~10자)과 주간 목표(5·10·15·20km 중 고르기, 기본 10km)를 정한 뒤 홈으로 간다. 완료는 한 번만 표시하고 다시 켜면 홈부터. 기존 사용자(러닝이 있음)도 한 번 보지만 목표는 지금 값이 기본으로 선택된다.
  - 테스트: 위젯(3장 이동, 빈 이름 거부, 완료 후 저장값, 다시 열면 홈, 뒤로 가기, 글자 1.3배)
  - 확인: `fvm flutter test test/onboarding test/app_test.dart`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 17. 베타 배포 준비
  - 파일: `android/app/build.gradle.kts`(릴리스 서명은 `android/key.properties` 가 있을 때만), `.gitignore`(`key.properties`, `*.jks`), `docs/beta.md`(설치 방법, 확인 부탁할 것, 의견 질문 목록), `HANDOFF.md`
  - 내용: 베타는 릴리스 APK 를 직접 공유한다(Play 내부 테스트는 페이즈 7). 서명 키 만드는 명령과 보관 방법(저장소에 넣지 않음, Mac·Windows 공유)을 적는다. 키가 없으면 디버그 서명으로 빌드된다.
  - 확인: `fvm flutter build apk --release` (키 없을 때도 실패하지 않음)

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 전체 통과
- [ ] `fvm dart analyze` 문제 0
- [ ] `fvm flutter build apk --debug`, `fvm flutter build apk --release` 성공
- [ ] 화면 파일에 색 리터럴·`fontSize: 22` 없음 (grep 테스트)

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 앱 데이터를 지운 첫 실행: 캐릭터 소개 → 이름 짓기 → 주간 목표 → 홈에 정한 이름·목표가 보인다. 다시 켜면 홈부터.
- [ ] 설정에서 체중 70kg 저장 → 가상 러닝 1km 뒤 요약 칼로리가 약 73 kcal.
- [ ] 가상 러닝을 끝낸 뒤 요약에서 끝부분을 잘라내면 거리·경험치가 줄어든 값으로 보인다.
- [ ] 가상 러닝 중 위치 주입을 멈추고 기다리면(테스트용으로 짧게 줄인 기준) 자동 종료 알림과 요약이 나오고, 끝 시각이 마지막 점으로 당겨진다.
- [ ] 기록 상세에서 러닝을 삭제하면 목록·주간 합계에서 빠지고 아바타 경험치가 그만큼 준다.
- [ ] 백업 내보내기 → 앱 데이터 지우기 → 가져오기 → 러닝 목록·레벨·이름이 그대로 돌아온다.
- [ ] 다크 모드에서 도토리 윤곽이 보인다. 탭바를 키보드(Tab·Enter)로 옮길 수 있다.

### 사람 확인
- [ ] Android 실기기 실제 30분 러닝 3회, 기록 누락 0건, 트랙 거리 오차 5% 이내 (페이즈 1 사람 확인 포함)
- [ ] 실기기에서 경험치·레벨업 연출, 금요일 18:00 알림 (페이즈 2 사람 확인)
- [ ] 실기기 최종 모습: 글꼴 굵기, 다크 모드 캐릭터 윤곽, 1px 손목 밴드 (페이즈 2.5 사람 확인)
- [ ] 다른 Android 기기로 백업 복원 성공
- [ ] Android 지인 베타 배포와 의견 수집(아바타 때문에 다시 달리고 싶은지 포함)

## 승인 때 정한 것

- 러닝 삭제는 경험치를 무른다. 그 주 목표도 다시 판정한다(레벨이 내려갈 수 있음).
- 기록 이상 처리: 자동 종료는 "종료를 잊은 경우"(20분 무이동·6시간)만 한다. 빠른 구간은 기록을 살리고 경험치에서만 빼며 요약에 알린다. 자전거 판별(걸음 센서)·이상 기록 경고는 페이즈 7, 서버 검증은 서버 이전 3단계(결정 0016).
- 백업 가져오기는 전체 바꾸기.
- 베타는 릴리스 APK 직접 공유.

## 자동 결정

없음
