# Stage

마스코트 뒤 사각 무대. 화면에서 가장 큰 그림이 서는 자리.

- 폭 전체, 모서리 `radius-lg` 24(카드 안 `radius-md` 20). `overflow` 를 잘라 땅이 모서리를 따른다.
- 하늘 겹 `stage-sky`, 땅 겹 `stage-ground`, 땅 윗선 `stage-ground-line` 4px(`border-ground-line`).
- 땅 띠 높이(윗선 포함): `stage-ground-height` 56(홈·요약, 8배 캐릭터), `stage-ground-height-compact` 40(러닝 중, 6배).
- 캐릭터 발끝은 윗선 아래로 `stage-foot-sink` 8px 묻힌다. 정수 배율, 보간 없음.
- 배경 아이템(공원·트랙 등)은 하늘·땅 겹을 바꾼다. 겹마다 토큰이 따로 있는 까닭이다.
- 말풍선: 흰 카드 + 꼬리, `radius-md`, 캐릭터를 가리킨다. 기존 문구만.
- 다크: 스프라이트 둘레를 `sprite-rim` 1픽셀로 두른다.
- 무대 위 글자는 `stage-ink`.
