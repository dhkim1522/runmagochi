# Stage

마스코트 뒤 사각 무대. 화면에서 가장 큰 그림이 서는 자리.

- 폭 전체, 모서리 `radius-lg` 24(카드 안 `radius-md` 20). `overflow` 를 잘라 땅이 모서리를 따른다.
- 하늘 겹 `stage-sky`, 땅 겹 `stage-ground`, 땅 윗선 `stage-ground-line` 4px(`border-ground-line`).
- 땅 띠 높이(윗선 포함): `stage-ground-height` 56(홈·요약, 8배 캐릭터), `stage-ground-height-compact` 40(러닝 중·상점, 6배), `stage-ground-height-mini` 24(카드 안 작은 무대, 2~3배, 모서리 `radius-sm` 12: 상점 아이템 카드·성장 단계 줄).
- 무대 높이를 펫에 맞출 때는 펫 상자(32 × 배율) + 펫 아래(땅 − 묻힘 8 − 발 아래 빈 줄 2 × 배율). 앱은 `PetStage.fitHeight`.
- 캐릭터 발끝은 윗선 아래로 `stage-foot-sink` 8px 묻힌다. 정수 배율, 보간 없음.
- 배경 아이템(공원·트랙 등)은 하늘·땅 겹을 바꾼다. 겹마다 토큰이 따로 있는 까닭이다.
- 말풍선은 SpeechBubble(`bubble` 판), 무대 오른쪽 위에 둔다.
- 다크: 스프라이트 둘레를 `sprite-rim` 1픽셀로 두른다.
- 무대 위 글자는 `stage-ink`.
