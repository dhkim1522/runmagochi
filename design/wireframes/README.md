# 와이어프레임

> MVP 화면 10개의 콘티. 화면 역할과 이동 흐름은 [화면설계](../../docs/screens.md)에 있다.

- `*.html` — 원본. 브라우저로 열면 하단 탭과 버튼으로 화면 사이를 이동할 수 있다.
- `png/` — 화면 이미지 (390×844, 2배 해상도).
- 편집용 캔버스: [claude.ai 디자인 캔버스](https://claude.ai/artifact/GGgUf6VGKuK3AkSRxrEnoQ)

| 1 홈 | 2 목표 고르기(옛 직접 입력) | 3 러닝 중 | 4 일시정지 | 5 러닝 요약 |
| --- | --- | --- | --- | --- |
| ![](png/01-main.png) | ![](png/02-goal.png) | ![](png/03-inrun.png) | ![](png/04-paused.png) | ![](png/05-summary.png) |

> 1 홈·2 목표는 처음 콘티 그대로 둔다(`Main.html` 의 값 칩 줄, `Goal.html` 의 숫자 직접 입력). 지금 앱은 홈에 `오늘 목표 5km ›` 한 줄만 두고, 누르면 아래 시트에서 거리·시간 분할, 자주 쓰는 값 칩(3·5·10km / 20·30·60분), 휠(3~42km 1km 단위, 15~180분 5분 단위), `확인` 으로 고른다. 직접 입력 창은 없다(페이즈 6 작업 21, [화면설계](../../docs/screens.md)).

| 6 보상 | 7 아바타 | 8 상점 | 9 기록 | 10 업적 |
| --- | --- | --- | --- | --- |
| ![](png/06-reward.png) | ![](png/07-avatar.png) | ![](png/08-shop.png) | ![](png/09-activity.png) | ![](png/10-badges.png) |
