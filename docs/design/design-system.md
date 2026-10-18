# 디자인 시스템

> 원본: [Claude 디자인 시스템 아티팩트](https://claude.ai/artifact/FPihTBfX2CJserHVwUQ514) (2026-10-17 승인, 방향 A 말랑 클레이). 값은 `docs/design/tokens.json` 이 기준이다. 방향 3안 비교: [디자인 방향 캔버스](https://claude.ai/artifact/EpHsu6T6PxcgRunwUHp4mL).

앱은 `lib/core/theme.dart` 에서 이 토큰만 읽는다(페이즈 2.5 작업 4).

달릴수록 자라는 도트 친구와 함께 뛰는 러닝 앱의 디자인 시스템. 방향은 **말랑 클레이**: 다마고치처럼 손에 잡힐 듯 말랑하고, 러닝 앱답게 한눈에 읽힌다.

## 원칙

- **한눈에**: 러닝 중에는 거리 숫자 하나가 화면에서 가장 크다(`distance-xl`). 야외 햇빛 아래에서도 읽히도록 밝은 `cream` 바탕에 짙은 `ink` 글자를 쓴다.
- **말랑하게**: 모서리는 둥글게(`radius-lg`·`radius-pill`), 카드와 버튼은 `border-thick` 테두리와 아래쪽 립(`lip`)으로 장난감처럼 도톰하다. 그림자 번짐(blur)은 쓰지 않는다.
- **벌주지 않게**: 쉬어도 혼내는 빨강을 쓰지 않는다. `danger` 는 위치 신호 오류 같은 진짜 문제에만.
- **한 화면 한 행동**: 화면마다 주요 버튼은 하나(`primary`). 보조 행동은 `accent` 또는 글자 버튼.

## 색

| 역할 | 토큰 | 규칙 |
| --- | --- | --- |
| 바탕 | `cream` | 모든 화면 배경 |
| 카드 | `surface` + `line` 테두리 + `line-strong` 립 | 주간 목표, 지표, 기록 행 |
| 아바타 무대 | `surface-soft` | 아바타 뒤 둥근 판 |
| 주요 행동 | `primary` 바탕 + `on-primary` 글자 + `primary-deep` 립 | 시작, 확인. 흰 글자 금지(대비 부족) |
| 보조 행동 | `accent` + `on-accent` + `accent-deep` 립 | 일시정지, 재개 |
| 진행 막대 | 트랙 `surface-soft`, 주간 목표 채움 `primary`, 레벨 채움 `accent` | 두 막대가 색으로 구분된다 |
| 달성 | `success` | 목표 달성 문구, 경험치 + |

## 글자

- 제목·숫자: **Jua** (둥근 한글 글꼴, SIL OFL). 숫자는 모두 Jua.
- 본문·라벨: **Noto Sans KR** (SIL OFL).
- 앱에서는 두 글꼴 파일을 함께 넣어 오프라인에서도 같은 모양으로 보인다.
- 크기: `distance-xl` 120 (러닝 중 거리), `number-l` 64 (요약 거리·카운트다운), `title` 28 (아바타 이름·레벨), `title-s` 22 (요약 이름·km 단위·경험치 +·종료 안내), `stat` 26 (페이스·시간), `button` 24, `heading` 18 (카드 제목), `body` 16, `label` 14, `caption` 13. 13 아래로 쓰지 않는다.

## 컴포넌트 규칙

- **버튼**: 높이 64, `radius-pill`, 글자 `button`. 아래 립 `lip`(6px) 을 버튼 색의 deep 토큰으로. 누르면 4px 내려가고 립은 2px. 길게 눌러 종료 버튼은 채워지는 진행을 `primary-deep` 으로 보여 준다.
- **카드**: `surface`, `border-thick` `line`, `radius-lg`(지표는 `radius-md`), 아래 립 `lip` `line-strong`. 안쪽 여백 `space-4` × `space-5`.
- **진행 막대**: 높이 14(주간 목표)·10(레벨), `radius-pill`, 트랙 `surface-soft`.
- **탭바**: 3개(러닝·기록·아바타). 선택 탭 `primary-deep` 굵게, 나머지 `ink-muted`. 위 구분선 `line` 2px.
- **탭 포커스**: 탭은 키보드 Tab 으로 포커스를 받고 Enter·Space 로 선택한다. 포커스 표시는 `primary-deep` `border-thick` 윤곽(`radius-sm`).
- **다이얼로그**: `surface`, `radius-lg`, 제목 `title`, 확인 버튼은 primary.
- **아바타**: 정수 배율 확대, 보간 없음(`FilterQuality.none`). 무대는 `surface-soft` + `radius-xl`.

## 다크 모드

같은 토큰 이름의 dark 값을 쓴다. 바탕은 짙은 갈색(`cream` dark), 글자는 크림색. 주요 버튼 글자는 다크에서도 `on-primary`(짙은 색).

캐릭터 윤곽: 다크에서는 스프라이트 실루엣을 `sprite-rim` 색으로 1픽셀(스프라이트 기준) 번지게 뒤에 깔아, 어두운 캐릭터(도토리 등)가 무대 `surface-soft` 에 묻히지 않게 한다. 라이트는 윤곽을 그리지 않는다(토큰 투명).

## 접근성

- 글자 대비는 모든 테마에서 4.5:1 이상(24px 이상은 3:1). `ink-muted` 는 `cream`·`surface` 위에서만 쓴다.
- 누를 수 있는 것은 48×48 이상.
- 시스템 글자 크기를 키워도 잘리지 않게, 고정 높이 안에 글자를 가두지 않는다.
