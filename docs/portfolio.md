# 포트폴리오 산출물

> 런마고치 개발 산출물 모음 (2026-10-24 기준). 웹페이지는 GitHub Pages 로 연다: [포트폴리오](https://dhkim1522.github.io/runmagochi/), [화면설계서](https://dhkim1522.github.io/runmagochi/design/screens/), [디자인 시스템](https://dhkim1522.github.io/runmagochi/docs/design/design-system/), [UI 후보 비교](https://dhkim1522.github.io/runmagochi/design/mockups/phase-6/compare/), [캐릭터 에셋](https://dhkim1522.github.io/runmagochi/design/character/asset-catalog.html). 다이어그램이 있는 문서(ERD·시퀀스·흐름)는 GitHub 이 mermaid 를 그려 주는 md 로 둔다.

## 숫자

9일(2026-10-16 ~ 10-24) · 커밋 400여 개 · 자동 테스트 1,387개 · 앱 코드 16,811줄 / 테스트 코드 26,132줄 · 결정 기록 38개 · 화면 컷 64개. 출처와 페이즈별 추이는 [개발 기록](dev-log.md).

## 산출물

| # | 산출물 | 파일 | 내용 |
| --- | --- | --- | --- |
| 1 | 요구사항 정의서(PRD) | [`docs/product.md`](product.md) | 목표, 요구사항 F1~F33(상태·페이즈·결정), 범위 밖, 가정과 위험 |
| 2 | 유저 시나리오·사용자 흐름 | [`docs/user-flows.md`](user-flows.md) | 시나리오 S1~S6, 시나리오마다 흐름도, 예외 흐름, 화면 이동 |
| 3 | 화면설계서 | [`design/screens/`](../design/screens/) · [웹페이지](https://dhkim1522.github.io/runmagochi/design/screens/) | 실제 앱 화면 64컷, 화면별 요소·상태·인터랙션, 촬영 메모 |
| 4 | 와이어프레임 | [`design/wireframes/`](../design/wireframes/README.md) | 초기 콘티와 최종 화면 컷 대응표 |
| 5 | UI 시안·디자인 시스템 | [`docs/design/`](design/design-system.md) · [디자인 시스템 웹페이지](https://dhkim1522.github.io/runmagochi/docs/design/design-system/) · [UI 후보 비교](https://dhkim1522.github.io/runmagochi/design/mockups/phase-6/compare/) | 토큰·컴포넌트, 디자인 의사결정 기록. 토큰 값은 테스트가 앱 코드와 대조 |
| 6 | 시스템 아키텍처 | [`docs/architecture.md`](architecture.md) | 기술 스택, 모듈 지도, 플랫폼 경계, 의존성 주입 |
| 7 | 데이터 모델 ERD | [`docs/data-model.md`](data-model.md) | 테이블 10개 ERD, 스키마 판 이력. 테스트가 코드와 대조 |
| 8 | 시퀀스 다이어그램 | [`docs/sequences.md`](sequences.md) | 기록~보상, 알림 버튼, 자동 일시정지·종료, 백업 4종 |
| 9 | 결정 기록 모음 | [`docs/decisions/README.md`](decisions/README.md) | 결정 38개 색인과 흐름도 |
| 10 | 개발 기록 | [`docs/dev-log.md`](dev-log.md) | 페이즈별 테스트 수 추이, 검증에서 잡은 결함 |
| 11 | README 소개 | [`README.md`](../README.md), `design/readme/` | 앱 소개, 스크린샷 6장 |
| 12 | 플레이북·스킬 | [`docs/playbook.md`](playbook.md), `.claude/skills/playbook/` | 다음 프로젝트용 진행 순서와 규칙 |
| 13 | 캐릭터 에셋 | [`design/character/`](../design/character/) · [에셋 카탈로그](https://dhkim1522.github.io/runmagochi/design/character/asset-catalog.html) | 캐릭터 3종 × 4단계, 아이템 6개, 배지 12개, 앱 아이콘 |
