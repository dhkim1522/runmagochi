# Stage

마스코트 뒤 사각 무대. 화면에서 가장 큰 그림이 서는 자리이고, 기본 배경은 공원 산책로다.

- 폭 전체, 모서리 `radius-lg` 24(카드 안 `radius-md` 20). `overflow` 를 잘라 배경이 모서리를 따른다. 정수 배율, 보간 없음.
- 공원 산책로: 소실점이 펫 몸 뒤 지평선(발끝 위 `stage-horizon` 13 스프라이트 줄)에 있는 한 점 투시 도트 그림. 배경 도트 1칸 `stage-dot` 4px(6배 이상, 작으면 `2·배율/3` 내림).
- 겹(아래 → 위): 1 하늘 `stage-sky` + 도트 구름 2~3개 `park-cloud`(멈춤, 오른쪽 위 96px 말풍선 자리 비움, 3배 미만 무대는 구름 없음) → 2 먼 풍경 `park-far2`·`park-far` → 3 풀밭 `stage-ground`·풀잎 `stage-ground-line`·흙길 `park-path`·`park-edge`·자갈 `park-pebble`·`park-pebble-hi`·꽃 `park-flower` → 4 길가 나무·덤불 `park-canopy`·`park-canopy-hi`·`park-trunk`(3배 이상) → 펫과 발밑 그림자 `stage-shadow` → 말풍선.
- 발끝은 무대 아래에서 `땅 높이 − stage-foot-sink`: `stage-ground-height` 56(홈·요약 8배) → 48, `stage-ground-height-compact` 40(러닝 중 6배) → 32, `stage-ground-height-mini` 24(카드 안 2~3배, 모서리 `radius-sm` 12) → 16. 옛 땅 띠·윗선은 없다.
- 무대 높이를 펫에 맞출 때는 펫 상자(32 × 배율) + 펫 아래(땅 − 묻힘 8 − 발 아래 빈 줄 2 × 배율). 앱은 `PetStage.fitHeight`.
- 러닝 중(기록 중)에만 3·4 겹이 소실점 쪽으로 0.5칸/초 물러난다: 한 장 `duration-stage-frame` 125ms, 주기 2칸 = 32장. 하늘·구름·먼 풍경은 멈춤. 일시정지·자동 일시정지·탈것 의심·신호 끊김이면 그 자리에 멈춘다. 홈·요약·아바타·상점·첫 실행·공유 카드는 늘 멈춤. 애니메이션 줄이기면 0번 장.
- 배경 아이템·날씨는 다른 겹 묶음(`StageScene`)을 `PetStage.scene` 에 준다.
- 말풍선은 SpeechBubble(`bubble` 판), 무대 오른쪽 위. 러닝 중 탈것 의심·신호 끊김 안내도 같은 말풍선.
- 다크: `park-*` 다크 값(어두운 흙길·나무). 스프라이트 둘레를 `sprite-rim` 으로 `max(1, round(배율/4))` 화면 px(8배·6배 2px, 3배 1px) 두른다. 라이트는 그리지 않는다.
- 무대 위 글자는 `stage-ink`. 연두 `primary` 는 배경에 쓰지 않는다.
- 앱: `PetStage`·`StageBackdrop`(`lib/core/ui/components.dart`), `StageScene`(`lib/core/stage/stage_scene.dart`), 공원 산책로 색 `ParkPalette`(`lib/core/stage/park_scene.dart`).
