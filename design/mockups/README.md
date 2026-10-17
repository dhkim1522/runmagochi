# 화면 시안 (페이즈 2.5 승인본)

- 원본 캔버스: https://claude.ai/artifact/9XWdBkvcoJe1DmjXsbYAaC (2026-10-18 승인)
- 디자인 시스템: `docs/design/design-system.md`, 값은 `docs/design/tokens.json`
- 각 `*.dc.html` 은 캔버스 아트보드 원본이다(390px 폭 폰 화면). 색·크기 값은 토큰 HEX 그대로이니, 구현 때는 HEX 대신 같은 값의 토큰을 `lib/core/theme.dart` 에서 쓴다.
- 시안 속 도트 아바타는 자리표시다. 실제 캐릭터는 `design/character/` (작업 3·8).
- 문구는 현재 앱 그대로다. 아래 "달라지는 점" 만 새로 생긴다.

## 공통

- 바탕 `cream`, 화면 좌우 여백 `space-5`(20), 화면 제목 `title`(Jua 28).
- 카드: `surface` + 3px `line` 테두리 + 아래 6px `line-strong` 립, 지표 카드 `radius-md`(20), 큰 카드 `radius-lg`(24), 아바타 무대 `surface-soft` + `radius-xl`(32).
- 주요 버튼: 높이 64 알약, `primary` + `on-primary` 글자 + 6px `primary-deep` 립. 보조(일시정지·재개): `accent` + `on-accent` + `accent-deep` 립.
- 탭바: 아이콘(선 아이콘) + 라벨 13, 선택 `primary-deep` 굵게, 나머지 `ink-muted`, 위 2px `line` 구분선.
- 숫자는 모두 Jua.

## 화면별

| 파일 | 화면 | 달라지는 점 |
| --- | --- | --- |
| `Main.dc.html` | 홈 | 주간 목표 카드 안에 `N주 연속 달성`(caption) 포함. 아바타 무대 안에 아바타·`러니 Lv.N`(title)·레벨 막대(`accent`, 높이 10, 트랙 `surface`)·`다음 레벨까지`. 주간 목표 막대 높이 14 `primary`. |
| `Run.dc.html` | 러닝 중 | 제목 `러닝 중`. 위에 지표 카드 3개(평균 페이스·현재 페이스·시간, 값 `stat` 26). 가운데 거리 `distance-xl` 120 + `km`(primary-deep). 그 아래 160×120 아바타 무대. 하단 `일시정지` accent 버튼. 위치 오류 문구는 제목 아래 `danger` 로. |
| `Paused.dc.html` | 일시정지 | 제목 `일시정지`. 거리 `number-l` 64. 지표 카드 3개(평균 페이스·시간·칼로리). 아바타 무대(idle). `재개` accent 버튼, 그 아래 `길게 눌러 종료` 흰 카드형 버튼 — 누르는 동안 왼쪽부터 `surface-soft` 로 차오른다. |
| `Summary.dc.html` | 러닝 요약 | 맨 위 성장 무대(`surface-soft`, radius-xl): 레벨업이면 `레벨 업!`(title, primary-deep) + `Lv.A 에서 Lv.B 로` + 아바타. 경험치 행은 카드(값 `success`, Jua 22). 레벨업이 아니면 무대 대신 경험치 행만. 이어서 날짜(caption)·이름·거리 64·지표 카드 3개·경로 카드(선 `primary` 6px, 시작점 `accent`, 끝점 `ink`)·구간 표 카드·`확인` primary 버튼. |
| `History.dc.html` | 기록 | `이번 주` 카드: 거리 64 + `러닝 N회`. `최근 러닝` 제목 아래 러닝 카드(날짜·이름 caption, `거리 · 페이스 · 시간` Jua 20). |
| `Avatar.dc.html` | 아바타 | 상단 무대에 아바타·이름 Lv·`누적 · 러닝 N회`·단계 막대(primary, 14)·`다음 성장 단계까지`/`최고 단계`. `성장 단계` 행 카드: 56px 미리보기 칸 + 단계 이름(Jua 18)·레벨 범위(caption) + 상태. 현재 단계는 테두리 `primary`·립 `primary-deep`, 잠김은 미리보기 흐리게(투명도 0.45). |

## 다크 모드

같은 토큰의 dark 값으로 바꾼다. 시안은 밝은 모드만 그렸다.
