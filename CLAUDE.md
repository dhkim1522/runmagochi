# runmagochi

> 실제 러닝 기록(GPS·페이스)에 도트 아바타 육성을 더한 Android·iOS 러닝 앱. `runmagochi` 는 개발 코드명이며, 정식 이름은 출시 전 상표 확인 후 정한다.

## 세션 시작 시

1. `HANDOFF.md` 를 읽고 현재 상태와 다음 할 일을 파악한다.
2. 작업 범위에 해당하는 `docs/` 문서를 읽는다.
3. 새 PC이거나 플러그인 설정이 안 돼 있으면 `/kickoff` 실행을 권한다.

## 문서 지도

원천 문서는 `docs/` 다. 결정이 바뀌면 해당 문서를 고치고, 이 파일에는 문서 위치만 둔다.

- `docs/product.md` — 기획서: 목표, 요구사항(F1~F19), 사용자 시나리오
- `docs/roadmap.md` — 페이즈별 범위·완료 기준, 현재 위치, 미결정 항목
- `docs/architecture.md` — 기술 스택, 구조, 데이터 모델, 서버 이전 경로
- `docs/screens.md` — MVP 화면 6개, 이동 흐름, UX 원칙
- `docs/specs/run-engine.md` — 기록 엔진 규칙
- `docs/specs/game-rules.md` — 게임 규칙과 수치
- `docs/specs/sprite-spec.md` — 스프라이트 규격: 프레임·레이어·파일 이름
- `docs/decisions/` — 결정 기록 (번호순)
- `docs/plans/` — 페이즈별 구현 계획과 진행 상태 (`/phase` 가 작성)
- `docs/research/nrc-analysis.md` — Nike Run Club 분석 요약
- `docs/tooling.md` — Claude Code 추천 플러그인 목록, 사용 시점, 기본값
- `design/wireframes/` — 화면 콘티 10개 (MVP 6개 + 후속 범위, HTML 원본·PNG)

## 명령

- `/kickoff` — 현황 브리핑, 이 PC의 플러그인 선택
- `/phase [--auto] [페이즈 번호]` — 현재 페이즈를 계획부터 구현·검증·문서 갱신까지 진행. 중단된 지점부터 이어간다

## 작업 규칙

- 로컬 우선: 서버 없이 기기에서 동작하게 만든다. 데이터 접근은 저장소 인터페이스를 거친다 (결정 0001).
- 새 결정은 `docs/decisions/` 에 다음 번호로 파일을 추가한다.
- Nike Run Club 분석은 구조·UX 참고용이다. Nike 코드·리소스를 이 저장소에 넣지 않는다.
- 작업을 마칠 때마다 `HANDOFF.md` 를 갱신하고 push한다. 회사 Mac과 집 Windows PC를 오가며 작업한다.
