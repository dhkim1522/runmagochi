# 페이즈 8 구현 계획

- 상태: 실행
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 8 산출물 정리 (결정 0022·0026·0035)

> 이 페이즈는 **코드가 아니라 문서·그림을 만든다**. 원본은 코드와 `docs/` 이므로, 문서를 쓰기 전에 코드에서 값을 읽어 와서 맞춘다(추측으로 쓰지 않는다). 앱 동작은 바꾸지 않는다. 문서를 쓰다 코드 결함을 찾으면 고치지 않고 `HANDOFF.md` 백로그에 적는다(페이즈 9 에서 다룸).
> 실기기 실측 결과로 달라질 수 있는 값(기준값·화면)은 페이즈 9 에서 해당 문서만 고친다.

## 도구

- 플러그인: superpowers(켜짐)만 쓴다. 디자인 플러그인은 새 시안을 만들지 않으므로 쓰지 않는다.
- 플레이북을 스킬로 만들 때 `skill-creator`. claude.ai 계정에 동기화돼 있으면 켜지 않아도 된다(`docs/tooling.md`).
- 다이어그램은 mermaid(GitHub 이 바로 그린다). 문법 검사는 `npx -y @mermaid-js/mermaid-cli` (Chrome 필요, 없으면 사람 확인으로 넘김).
- 포트폴리오 모음 페이지는 아티팩트로 게시한다(메모리: 산출물은 아티팩트 보드).

## 기준값 (작업 0에서 채운다)

문서에 쓰는 숫자는 모두 여기서 가져온다. 작업 0이 아래 표를 실제 명령 출력으로 채운다.

| 항목 | 값 | 얻는 법 |
| --- | --- | --- |
| 테스트 수 | 1369 통과 (2026-10-23) | `fvm flutter test` |
| DB 테이블·스키마 판 | 10개(Runs·RunPoints·Splits·Avatars·WeeklyGoals·Profiles·XpTxns·CoinTxns·OwnedItems·Badges), 스키마 7판 | `lib/run/data/app_database.dart` |
| 화면 수·컷 수 | MVP 화면 7개, 컷 PNG 64개 | `docs/screens.md`, `design/screens/` |
| 결정 기록 수 | 35 (0001~0035) | `ls docs/decisions` |
| 앱 버전 | 0.4.0+4 | `pubspec.yaml` |
| 코드 줄 수(lib / test) | 16,657 / 25,693 (`.g.dart` 제외) | `find ... \| xargs wc -l` |

## 작업

- [x] 0. 기준값 수집과 산출물 현황표
  - 파일: 이 파일의 기준값 표, `docs/portfolio.md`(산출물 목록과 상태 표만 먼저. 작업 11에서 완성)
  - 내용: 위 표를 채우고, 산출물 12종마다 "있음/낡음/없음"과 만들 파일을 적는다
  - 테스트: 없음(문서)
  - 확인: `fvm flutter test`, `fvm dart analyze` 통과 출력으로 숫자 확인

- [x] 1. 요구사항 정의서(PRD) 정리
  - 파일: `docs/product.md`
  - 내용: F1~F25 요구사항 표에 상태(구현·부분·백로그)와 구현 페이즈·결정 번호 열을 붙인다. 주간 목표 제거(결정 0018)처럼 바뀐 요구는 옛 문구를 지우고 바뀐 이유를 한 줄 남긴다. 범위 밖(서버·API·수동 입력), 성공 기준, 가정·위험(시장조사 요약 링크)을 한 장으로 모은다. 비기능(오프라인·배터리·정확도)은 수치로 쓴다
  - 확인: 표의 F번호가 `docs/roadmap.md`·`docs/decisions/` 의 F번호와 겹치거나 빠지지 않는다(grep 대조)

- [x] 2. 유저 시나리오와 사용자 흐름 다이어그램
  - 파일: `docs/user-flows.md`(새로), `docs/product.md` 시나리오 절은 링크만 남김, `docs/screens.md` "화면 이동 흐름" 갱신
  - 내용: S1~S5 를 현재 앱 기준으로 다시 쓰고(목표 시트·탈것·신호 끊김·권한 거부·1km 미만 종료 같은 예외 흐름 포함), 시나리오마다 mermaid flowchart 한 장. 전체 화면 이동도(온보딩·권한·홈 4탭·러닝·요약·설정·공유) 현재 라우팅과 맞춘다
  - 확인: 흐름의 화면 이름이 `design/screens/` 컷 이름과 대응한다. mermaid 문법 검사

- [x] 3. 화면설계서·와이어프레임 최종화
  - 파일: `design/screens/`(재촬영한 PNG·`web/`·`index.html`), `design/wireframes/README.md`, `docs/screens.md`
  - 내용: 알려진 낡은 컷(HANDOFF "다음 할 일" 3번: 캐릭터 2~4단계 모양, 알림 37·39, iOS 52, 버튼 테두리 제거 전체)을 에뮬레이터·시뮬레이터에서 다시 찍는다. 와이어프레임은 "초기 콘티"로 표시하고 콘티 10개와 최종 컷의 대응표를 `design/wireframes/README.md` 에 둔다. `docs/screens.md` 컷 목록을 실제 파일과 맞춘다. 화면설계서 아티팩트를 갱신해 새 판으로 올린다
  - 확인: `ls design/screens` 와 `docs/screens.md` 컷 목록이 일치(누락·고아 파일 0). 컷 수는 기준값 표
  - 주의: 사용자가 정한 순서(HANDOFF 3번)는 "아이템 에셋 검토 때 한꺼번에"였다. 이 페이즈에서 재촬영하면 아이템 에셋을 나중에 바꿀 때 상점·꾸미기 컷만 다시 찍는다. **승인 때 확인**
  - 결과(2026-10-24, 사용자 승인으로 전체 재촬영): Android 라이트 51·다크 8·iPhone 5 = 64컷 + 390px 사본 64 + 무대 조각 2. 39d·39e 는 10-23 컷 유지(작은 아이콘 반영 뒤 촬영이라 새 것과 같음). `tool/capture/`(cap·ring_run·vm_ui·make_web 등)와 `design/screens/index.html` 숫자·설명을 맞춤. 와이어프레임은 초기 콘티로 표시하고 대응표를 `design/wireframes/README.md` 에 둠. 컷 목록 일치 검사: index.html 참조 이름 ↔ 파일 이름 대조(누락·고아 0). 주의: 에뮬레이터 기준 페이스가 3~4분대(가상 GPS 속도), iPhone 52 경로는 한 색, 앱 결함 후보는 index.html "찍으면서 본 것"(13c 버튼 테두리 일시 표시)
- [x] 4. UI 시안·디자인 시스템 정리
  - 파일: `docs/design/design-system.md`, `docs/design/tokens.json`, `design/mockups/README.md`
  - 내용: 토큰 값이 `lib/core/theme.dart`·`lib/core/stage` 실제 값과 같은지 대조해 고친다. 페이즈 6-2 과정(후보 3방향×2트랙 → 비교 → 선택 → 관문 3 수정)을 한 페이지 "디자인 의사결정 기록"으로 쓰고 비교·시안·디자인 시스템 아티팩트 링크를 모은다
  - 테스트: 토큰 일치 확인은 기존 테스트가 있으면 그대로 통과, 없으면 대조 결과만 문서에 적는다
  - 확인: tokens.json 의 색 개수·이름이 theme.dart 와 같다(스크립트 또는 grep 대조 출력)

- [x] 5. 시스템 아키텍처 구성도 보강
  - 파일: `docs/architecture.md`
  - 내용: 지금 구성도(레이어 한 장)에 더한다. (a) 실제 모듈 지도: `lib/` 폴더별 책임·의존 방향 (b) 플랫폼 경계 그림: 포그라운드 서비스·위치 플러그인·알림·TTS·공유·파일 선택·iOS 백그라운드 위치 (c) 상태 관리·저장소 주입 방식 (d) 패키지 표를 `pubspec.yaml` 과 일치시킨다
  - 확인: 표의 패키지·폴더가 `pubspec.yaml`·`ls lib` 와 일치(grep 대조). mermaid 문법 검사

- [x] 6. 데이터 모델 ERD
  - 파일: `docs/data-model.md`(새로), `docs/architecture.md` 데이터 모델 절은 요약과 링크
  - 내용: Drift 테이블(`app_database.dart`)에서 읽은 mermaid `erDiagram` 하나. 관계(Run–RunPoint·Split·XpTxn·CoinTxn·Badge, Avatar–OwnedItem), 공통 필드(id·createdAt·updatedAt·deletedAt), 고유 키, 스키마 판 이력(1~7판 변화)을 표로
  - 테스트: 테이블 이름 일치 검사 — 새 테스트 `test/docs/data_model_doc_test.dart` 가 `docs/data-model.md` 의 엔티티 이름 목록과 `AppDatabase.allTables` 이름 목록이 같은지 본다. 먼저 실패(문서 없음) 확인
  - 확인: `fvm flutter test test/docs/`, mermaid 문법 검사

- [x] 7. 시퀀스 다이어그램 4종
  - 파일: `docs/sequences.md`(새로)
  - 내용: mermaid `sequenceDiagram` 4개. (a) 러닝 기록: 시작→카운트다운→위치 수신→엔진→10초 저장→종료→요약→경험치·코인·배지 (b) 알림 버튼: 알림 액션→백그라운드 isolate→컨트롤러 일시정지·재개 (c) 자동 일시정지·재개·종료 예고·무활동 종료, 빠른 이동 자동 종료 (d) 백업 내보내기·가져오기. 각 그림 옆에 근거 코드 파일을 적는다
  - 확인: 그림의 참여자·메시지 이름이 실제 클래스·메서드 이름(`grep` 으로 존재 확인). mermaid 문법 검사

- [x] 8. 결정 기록 모음과 페이즈별 개발 기록
  - 파일: `docs/decisions/README.md`(새로), `docs/dev-log.md`(새로)
  - 내용: 결정 색인(번호·제목·상태·페이즈·한 줄 요약, 바뀐 결정은 대체 관계 표시). 개발 기록은 페이즈 1~7 마다 기간(git 날짜), 작업 수, 테스트 수 추이, 리뷰에서 잡은 결함, 막힌 점과 해법을 계획 파일·git 로그에서 뽑아 쓴다
  - 확인: 색인 항목 수 = `ls docs/decisions` 항목 수 − 1. 테스트 수는 계획 파일 기록과 일치

- [x] 9. README 소개
  - 파일: `README.md`, `design/readme/`(스크린샷·GIF)
  - 내용: 한 화면에 앱 소개(문제·해법), 스크린샷 4~6장, 러닝 GIF 1개(에뮬레이터 `fake_run` 녹화), 기능, 기술 스택, 구조 한 장, 산출물 목록 링크, 개발 방식(Claude Code 페이즈 흐름), 빌드·실행. 기존 "시작하기" 절은 아래로 내린다
  - 확인: README 의 상대 링크가 모두 실제 파일을 가리킨다(링크 검사 한 줄 스크립트). GIF 2MB 이하
  - 막히면: GIF 녹화 도구(adb screenrecord·ffmpeg)가 없으면 스크린샷만으로 두고 GIF 는 사람 확인에 남긴다
  - 결과: 스크린샷 6장(`design/readme/`, 390px)·기능·기술·산출물 표·개발 방법을 넣고 링크 검사 통과. GIF 는 ffmpeg·adb 가 PATH 에 없어 만들지 못했다 → 사람 확인

- [x] 10. 다음 프로젝트용 플레이북과 스킬
  - 파일: `docs/playbook.md`, `.claude/skills/playbook/SKILL.md`
  - 내용: 이 프로젝트에서 얻은 순서(기획→시장조사→PRD→화면 콘티→아키텍처·ERD→기술 결정→코어 먼저→디자인 후속→산출물→실기기→출시)를 단계·산출물·완료 기준·이 프로젝트에서 겪은 실수 표로 쓴다. 같은 내용을 스킬(`skill-creator` 형식)로 만들어 다른 프로젝트에서 부를 수 있게 한다
  - 확인: 스킬 프런트매터(name·description) 형식 검증. 플레이북의 단계마다 이 저장소의 실제 예시 파일 링크가 있다

- [ ] 11. 포트폴리오 모음 페이지
  - 파일: `docs/portfolio.md` 완성, 아티팩트 1개
  - 내용: 산출물 12종을 순서대로 한 페이지에 모아 보여 주고(요약 한두 줄 + 그림 + 원본 링크), 기술적으로 어려웠던 점·수치(테스트 수·결정 수·페이즈 수)를 위에 둔다. 아티팩트 보드로 게시하고 주소를 `docs/portfolio.md`·README 에 적는다
  - 확인: 아티팩트 열림, 모든 링크 작동. 게시 전 `artifact-design` 스킬 규칙을 따른다

- [ ] 12. 정합성 점검과 문서 지도 갱신
  - 파일: `CLAUDE.md`, `README.md`, `docs/roadmap.md`, `docs/tooling.md`(스킬·도구 기록)
  - 내용: 새 문서(`user-flows`·`data-model`·`sequences`·`dev-log`·`playbook`·`portfolio`·결정 색인)를 문서 지도에 넣는다. 산출물끼리 숫자·이름이 서로 맞는지 마지막으로 대조한다(기준값 표 기준)
  - 확인: 문서 지도의 모든 경로가 존재한다. 이전 작업에서 쓴 숫자가 기준값 표와 같다

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 통과(기준값 표의 수 이상, 새 문서 검사 테스트 포함)
- [ ] `fvm dart analyze` 문제 없음
- [ ] `fvm flutter build apk --debug` 통과
- [ ] 산출물 12종이 모두 있다(작업 0 현황표가 전부 "있음")
- [ ] 새·고친 문서의 mermaid 블록이 문법 검사를 통과한다
- [ ] 문서 지도·README 의 상대 링크가 모두 실제 파일을 가리킨다
- [ ] 문서의 숫자(테스트 수·테이블 수·결정 수·컷 수)가 기준값 표와 같다

### E2E (에뮬레이터, `/e2e` 가 확인)
- [x] 화면 재촬영(작업 3) 중 앱이 정상 실행되고, `design/screens/` 목록의 화면을 모두 조작해 찍을 수 있다(누락 컷 0)
- [ ] README 러닝 GIF 녹화(작업 9)에서 가상 러닝 시작→기록→요약까지 진행된다

### 사람 확인
- [ ] 산출물 12종을 포트폴리오로 쓸 수 있는 수준으로 사용자가 승인 (페이즈 8 완료 기준)
- [ ] 문서 내용이 앱 동작과 맞는지 사용자가 표본으로 확인(시퀀스·ERD 중 한 가지)

## 자동 결정
없음
