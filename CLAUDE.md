# runmagochi

> 실제 러닝 기록(GPS·페이스)에 도트 아바타 육성을 더한 Android·iOS 러닝 앱. 앱 이름은 런마고치(`runmagochi`)이며, 출시 전 상표 충돌을 확인한다(결정 0025).

## 세션 시작 시

1. `HANDOFF.md` 를 읽고 현재 상태와 다음 할 일을 파악한다.
2. 작업 범위에 해당하는 `docs/` 문서를 읽는다.
3. 새 PC이거나 플러그인 설정이 안 돼 있으면 `/kickoff` 실행을 권한다.

## 문서 지도

원천 문서는 `docs/` 다. 결정이 바뀌면 해당 문서를 고치고, 이 파일에는 문서 위치만 둔다.

- `docs/product.md` — 기획서(PRD): 목표, 요구사항(F1~F25, 상태·페이즈·결정), 범위 밖, 가정과 위험
- `docs/user-flows.md` — 유저 시나리오 S1~S6과 예외 흐름·화면 이동 다이어그램
- `docs/roadmap.md` — 페이즈별 범위·완료 기준, 현재 위치, 미결정 항목
- `docs/architecture.md` — 기술 스택, 구조, 데이터 모델, 서버 이전 경로
- `docs/data-model.md` — 데이터 모델 ERD, 스키마 판 이력 (`test/docs/data_model_doc_test.dart` 가 코드와 대조)
- `docs/sequences.md` — 시퀀스 다이어그램 4종: 러닝 기록~보상, 알림 버튼, 자동 일시정지·종료, 백업
- `docs/screens.md` — MVP 화면 7개, 이동 흐름, UX 원칙
- `docs/specs/run-engine.md` — 기록 엔진 규칙
- `docs/specs/game-rules.md` — 게임 규칙과 수치
- `docs/specs/sprite-spec.md` — 스프라이트 규격: 프레임·레이어·파일 이름
- `docs/design/design-system.md` — 디자인 시스템(색·글꼴·간격·컴포넌트 규칙), 값은 `docs/design/tokens.json`. 정적 페이지 `docs/design/design-system/index.html` 은 `python3 tool/export_design_system.py` 로 만든다
- `docs/design/design-process.md` — 디자인 의사결정 기록(페이즈 2.5~6 비교·선택·근거)
- `docs/decisions/` — 결정 기록 (번호순). 색인과 흐름도는 `docs/decisions/README.md`
- `docs/dev-log.md` — 페이즈별 개발 기록(테스트 수 추이, 검증에서 잡은 결함)
- `docs/playbook.md` — 다음 프로젝트용 진행 순서. 같은 내용의 스킬 `.claude/skills/playbook`
- `docs/portfolio.md` — 포트폴리오 산출물 모음과 현황
- `docs/plans/` — 페이즈별 구현 계획과 진행 상태 (`/phase` 가 작성)
- `docs/research/nrc-analysis.md` — Nike Run Club 분석 요약
- `docs/research/market.md` — 시장조사: 유사 앱 전수 조사, 경쟁·타깃·수익화·위험, 제안
- `docs/research/naming.md` — 앱 이름 대안 후보 6개와 상표·스토어·도메인 검색 결과
- `docs/beta.md` — 베타 배포: 서명 키, 릴리스 APK 만들기, 테스터 안내문, 의견 질문
- `docs/ios.md` — iOS 빌드, 무료 Apple ID 로 iPhone 설치(7일 재설치), iOS 설정과 이유
- `docs/field-test.md` — 실기기 실측 안내: 30분 러닝 3회 기록표, 기기별 확인 항목, 기준값 조정 표(페이즈 7)
- `docs/tooling.md` — Claude Code 추천 플러그인 목록, 사용 시점, 기본값
- `design/wireframes/` — 화면 콘티 10개 (MVP 6개 + 후속 범위, HTML 원본·PNG)
- `design/mockups/` — 화면 시안과 구현 메모. README 가 지금 방향(연두 무드보드, 결정 0029)과 옛 방향(말랑 클레이, 페이즈 2.5)을 나눈다
  - `design/mockups/phase-6/` — 고른 방향 c 규칙(`direction-c.md`), 캔버스 시안(`canvas/c/`), 6안 비교(`critique.md`)
  - `design/mockups/phase-6-screens/` — 페이즈 6 구현 화면 스크린샷(라이트, 화면마다 1장)
- `design/screens/` — 화면설계서: 최종 앱 스크린샷(`<번호>-<이름>.png`, 게시용 390px `web/`)과 [아티팩트](design/screens/index.html) 페이지 원본 `index.html`
- `design/character/` — 캐릭터 콘셉트·3종·아이템·배지 미리보기와 에셋 카탈로그(`asset-catalog.html`). 그림 데이터는 `tool/sprites/`, PNG 생성은 `fvm dart run tool/render_sprites.dart`, 앱 아이콘·스플래시는 `fvm dart run tool/render_app_icon.dart`
- `design/references/` — 디자인 참고 이미지(Pinterest 무드보드). 방향 참고용이며 앱 에셋에 넣지 않는다

## 명령

- `/kickoff` — 현황 브리핑, 이 PC의 플러그인 선택
- `/phase [--auto] [페이즈 번호]` — 현재 페이즈를 계획부터 구현·검증·문서 갱신까지 진행. 중단된 지점부터 이어간다
- `/e2e [페이즈 번호]` — 에뮬레이터에서 계획의 E2E 시나리오 확인. 에뮬레이터가 없으면 설치를 묻는다. `/phase` 검증 단계가 마지막에 부른다

## 작업 규칙

- 로컬 우선: 서버 없이 기기에서 동작하게 만든다. 데이터 접근은 저장소 인터페이스를 거친다 (결정 0001).
- 새 결정은 `docs/decisions/` 에 다음 번호로 파일을 추가한다.
- Nike Run Club 분석은 구조·UX 참고용이다. Nike 코드·리소스를 이 저장소에 넣지 않는다.
- 작업을 마칠 때마다 `HANDOFF.md` 를 갱신하고 push한다. Mac과 Windows PC를 오가며 작업한다.
