# StatsCard

흰 카드 하나에 지표 칸 여러 개를 같은 폭으로 늘어놓는다. 러닝 중·일시정지·요약의 지표 3칸.

- 판은 `surface`, 모서리 `radius-lg` 24, 안쪽 여백 위아래 `space-5` 20 · 좌우 `space-3` 12. 칸 사이 `space-1` 4, 칸 사이 선 없음.
- 칸(`StatCard.cell`): 라벨 `label` 14/600 `ink-muted` 위, 값 `stat` 22/800 고정폭 숫자 아래, 사이 `space-1`.
- 칸이 좁으면 글자를 줄 바꾸지 않고 칸 안에서 줄인다(큰 글자 설정에서도 잘리지 않게).
- 따로 선 작은 지표 카드(`StatCard`)는 `radius-md` 20.
