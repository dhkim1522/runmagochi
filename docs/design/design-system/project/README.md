달릴수록 자라는 도트 친구와 함께 뛰는 러닝 앱의 디자인 시스템. 연두 바탕에 사각 무대, 가볍고 친절하게.

## 원칙

- **마스코트가 주인공**: 캐릭터가 사각 무대 위에서 화면의 가장 큰 그림이다.
- **한눈에**: 러닝 중에는 거리 숫자 하나가 가장 크다.
- **연두는 형광펜**: `primary` 는 "지금 누를 것" 과 "선택된 것" 에만 쓴다.
- **테두리 대신 톤**: 카드는 바탕과의 톤 차이로, 버튼은 옅은 그림자로 뜬다.
- **한 화면 한 행동**: 화면마다 연두 버튼은 하나.

## 색

- 바탕 `background`, 카드 `surface`, 빈 트랙 `surface-soft`, 글자 `ink`·`ink-muted`.
- 주요 행동 `primary` + `on-primary`, 강조·채움 `primary-deep`, 어두운 판 `panel`.
- 문제 알림 `danger`(진짜 문제에만), 코인 `coin`. 라이트·다크 모두 글자 대비 4.5:1 이상.

## 글꼴

Pretendard 한 가족(앱은 같은 모양의 `RunmagochiSans`), 대체는 sans-serif. 숫자는 800 굵기 고정폭.
`distance-xl` 128 · `number-l` 64 · `title` 26 · `button` 22 · `body` 17 · `label` 14 · `caption` 13 (13 아래 없음).

## 간격·모서리·그림자

- 간격: `space-1` 4 · 2 8 · 3 12 · 4 16 · 5 20 · 6 24 · 7 28 · 8 32. 화면 좌우 20, 카드 사이 12.
- 모서리: `radius-sm` 12 · `md` 20 · `lg` 24 · `xl` 28 · 알약 `pill`.
- 그림자: `elevation-float` 하나(연두·보조 버튼, 선택 칩).

## 컴포넌트

Button · CircleIconButton · Chip · Card · StatsCard · ProgressBar · Coin · Stage · SpeechBubble · GoalSheet · EmptyState · NoticeCard · RoutePace · TabBar
